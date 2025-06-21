import Foundation

/// A locking strategy that enforces priority-based execution semantics.
///
/// This strategy implements a sophisticated priority system that allows higher-priority
/// actions to preempt lower-priority ones, while providing configurable concurrency
/// behavior for actions of the same priority level.
///
/// ## Priority System Overview
/// The strategy maintains a per-boundary collection of active `LockmanPriorityBasedInfo`
/// instances and uses the priority hierarchy to determine execution precedence:
///
/// - **High Priority** (.high): Can cancel low/none priority actions
/// - **Low Priority** (.low): Can cancel none priority actions, yields to high priority
/// - **No Priority** (.none): Yields to all priority actions, simple conflict handling
///
/// ## Concurrency Behavior Logic
/// When `canLock` is called for same-priority actions, the strategy evaluates conflicts
/// using the existing action's concurrency behavior:
///
/// 1. **No Priority Actions**: Always succeed (bypass priority system)
/// 2. **Priority vs Non-Priority**: Priority actions always win
/// 3. **Different Priority Levels**: Higher priority wins
/// 4. **Same Priority Level**: Apply existing action's `ConcurrencyBehavior`
///    - **Exclusive**: Existing action continues, new action fails
///    - **Replaceable**: Existing action is canceled, new action succeeds
///
/// ## Thread Safety
/// This strategy is thread-safe through the underlying `LockmanState` which provides
/// synchronized access to the per-boundary lock collections.
///
/// ## Usage Examples
/// ```swift
/// let strategy = LockmanPriorityBasedStrategy.shared
///
/// // High priority exclusive action
/// let payment = LockmanPriorityBasedInfo(actionId: "payment", priority: .high(.exclusive))
/// let result = strategy.canLock(id: .payment, info: payment)
/// // Result: .success or .failure based on existing actions
///
/// // High priority replaceable action
/// let search = LockmanPriorityBasedInfo(actionId: "search", priority: .high(.replaceable))
/// let result = strategy.canLock(id: .search, info: search)
/// // Result: .success or .successWithPrecedingCancellation
/// ```
public final class LockmanPriorityBasedStrategy: LockmanStrategy, @unchecked Sendable {
  // MARK: - Associated Types

  public typealias I = LockmanPriorityBasedInfo

  // MARK: - Shared Instance

  /// Shared singleton instance for coordinating priority-based locks across the application.
  ///
  /// Using the shared instance ensures that all priority-based actions throughout
  /// the application coordinate through the same strategy state, enabling proper
  /// priority-based preemption and conflict resolution across different features.
  public static let shared = LockmanPriorityBasedStrategy()

  // MARK: - Private State

  /// Thread-safe state container that tracks active priority-based locks per boundary.
  ///
  /// Each boundary maintains an ordered collection of active lock infos, allowing
  /// the strategy to evaluate priority conflicts and determine the highest-priority
  /// active action for each boundary.
  private let state = LockmanState<LockmanPriorityBasedInfo>()

  /// The unique identifier for this strategy instance.
  public let strategyId: LockmanStrategyId

  // MARK: - Initialization

  /// Creates a new priority-based strategy instance.
  ///
  /// - Note: In most cases, use the `shared` singleton instance instead of creating
  ///         new instances to ensure proper coordination across the application.
  public init() {
    self.strategyId = Self.makeStrategyId()
  }

  /// Creates a strategy identifier for the priority-based strategy.
  ///
  /// This method provides a consistent way to generate strategy IDs that can be used
  /// both during strategy initialization and in macro-generated code.
  ///
  /// - Returns: A `LockmanStrategyId` with the name "priorityBased"
  public static func makeStrategyId() -> LockmanStrategyId {
    .priorityBased
  }

  // MARK: - LockmanStrategy Protocol Implementation

  /// Evaluates whether a priority-based lock can be acquired.
  ///
  /// This method implements the core priority-based conflict resolution logic:
  ///
  /// ## Decision Process
  /// 1. **No Priority Bypass**: Actions with `.none` priority always succeed
  /// 2. **Same Action Blocking**: Check if any existing action blocks the same actionId
  /// 3. **Current State Check**: Examines existing non-none priority actions
  /// 4. **Priority Comparison**: Compares requested priority with current highest
  /// 5. **Behavior Application**: Applies existing action's concurrency behavior when levels match
  ///
  /// ## Return Values
  /// - `.success`: No conflicts, lock can be acquired immediately
  /// - `.successWithPrecedingCancellation`: Lock acquired, but existing operation must be canceled
  /// - `.failure`: Cannot acquire lock due to higher/equal priority conflicts or same-action blocking
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Priority-based lock information containing action ID and priority
  /// - Returns: A `LockmanResult` indicating the outcome of the lock evaluation
  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanPriorityBasedInfo
  ) -> LockmanResult {
    let requestedInfo = info
    let result: LockmanResult
    var failureReason: String?
    var cancelledInfo: (actionId: String, uniqueId: UUID)?

    // No priority actions bypass the priority system entirely
    if requestedInfo.priority == .none {
      result = .success

      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "PriorityBased",
        boundaryId: String(describing: id),
        info: info
      )
      return result
    }

    // Get all current locks for this boundary
    let currentLocks = state.currents(id: id)

    // Check blocksSameAction bidirectional blocking logic:
    // 1. If the requested action has blocksSameAction=true, it cannot execute if any action with the same actionId exists
    // 2. If any existing action with the same actionId has blocksSameAction=true, the requested action cannot execute
    // This ensures bidirectional blocking between actions with the same actionId
    if requestedInfo.blocksSameAction || currentLocks.contains(where: {
      $0.actionId == requestedInfo.actionId && $0.blocksSameAction
    }) {
      // Check if any action with the same actionId already exists
      let hasSameActionConflict = currentLocks.contains {
        $0.actionId == requestedInfo.actionId
      }
      if hasSameActionConflict {
        result = .failure(LockmanPriorityBasedError.blockedBySameAction(actionId: requestedInfo.actionId))
        failureReason = "Same action '\(requestedInfo.actionId)' is blocked by policy"

        LockmanLogger.shared.logCanLock(
          result: result,
          strategy: "PriorityBased",
          boundaryId: String(describing: id),
          info: info,
          reason: failureReason
        )
        return result
      }
    }

    // Filter out non-priority actions for priority comparison
    let priorityLocks = currentLocks.filter { $0.priority != .none }

    // If no priority-based locks exist, we can proceed
    guard let currentHighestPriorityInfo = priorityLocks.last else {
      result = .success

      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "PriorityBased",
        boundaryId: String(describing: id),
        info: info
      )
      return result
    }

    let currentPriority = currentHighestPriorityInfo.priority
    let requestedPriority = requestedInfo.priority

    // Compare priority levels using the Comparable implementation
    if currentPriority > requestedPriority {
      // Current action has higher priority - request fails
      result = .failure(LockmanPriorityBasedError.higherPriorityExists(requested: requestedPriority, currentHighest: currentPriority))
      failureReason = "Higher priority action '\(currentHighestPriorityInfo.actionId)' (priority: \(currentPriority)) is currently locked"
    } else if currentPriority == requestedPriority {
      // Same priority level - apply existing action's concurrency behavior
      let behaviorResult = applySamePriorityBehavior(
        current: currentHighestPriorityInfo,
        requested: requestedInfo
      )
      result = behaviorResult

      if case .failure = behaviorResult {
        failureReason = "Same priority action '\(currentHighestPriorityInfo.actionId)' with exclusive behavior is already running"
      } else if behaviorResult == .successWithPrecedingCancellation {
        cancelledInfo = (currentHighestPriorityInfo.actionId, currentHighestPriorityInfo.uniqueId)
      }
    } else {
      // Requested action has higher priority - can preempt current
      result = .successWithPrecedingCancellation
      cancelledInfo = (currentHighestPriorityInfo.actionId, currentHighestPriorityInfo.uniqueId)
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "PriorityBased",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason,
      cancelledInfo: cancelledInfo
    )

    return result
  }

  /// Registers a priority-based lock for the specified boundary and action.
  ///
  /// Adds the lock information to the internal state tracking system.
  /// The lock will remain active until a corresponding `unlock` call is made.
  ///
  /// ## Implementation Notes
  /// - Should only be called after `canLock` returns a success result
  /// - Multiple locks can be active on the same boundary with different action IDs
  /// - The strategy maintains insertion order for same-priority conflict resolution
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Priority-based lock information to register as active
  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanPriorityBasedInfo
  ) {
    state.add(id: id, info: info)
  }

  /// Releases a previously acquired priority-based lock.
  ///
  /// Removes the specified lock information from the internal state, allowing
  /// lower-priority actions to potentially proceed. The unlock operation uses
  /// the lock info's unique ID for precise identification and removal.
  ///
  /// ## Implementation Notes
  /// - Uses `info.uniqueId` for exact instance matching
  /// - Safe to call even if the lock doesn't exist (idempotent)
  /// - May allow queued lower-priority actions to proceed after removal
  ///
  /// - Parameters:
  ///   - id: The boundary identifier whose lock should be released
  ///   - info: The same lock information that was used when acquiring the lock
  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanPriorityBasedInfo
  ) {
    state.remove(id: id, info: info)
  }

  /// Removes all priority-based locks across all boundaries.
  ///
  /// Clears all internal lock state, effectively resetting the strategy to its
  /// initial state. This operation affects all boundaries simultaneously.
  ///
  /// ## Use Cases
  /// - Application shutdown sequences
  /// - Global system resets during development
  /// - Test suite cleanup between test cases
  /// - Emergency cleanup scenarios
  public func cleanUp() {
    state.removeAll()
  }

  /// Removes all priority-based locks for the specified boundary identifier.
  ///
  /// Provides targeted cleanup for specific boundaries while preserving
  /// lock state for other boundaries. This allows fine-grained control
  /// over which priority contexts to reset.
  ///
  /// ## Use Cases
  /// - Feature-specific cleanup when components are deallocated
  /// - User session cleanup when users log out
  /// - Scoped cleanup for temporary contexts or workflows
  /// - Partial system resets during development
  ///
  /// - Parameter id: The boundary identifier whose locks should be removed
  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    state.removeAll(id: id)
  }

  /// Returns current locks information for debugging.
  ///
  /// Provides a snapshot of all currently held locks across all boundaries.
  /// The returned dictionary maps boundary identifiers to their active lock information.
  ///
  /// - Returns: Dictionary of boundary IDs to their active locks
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Get all boundaries and their locks from the state
    let allLocks = state.getAllLocks()

    for (boundaryId, lockInfos) in allLocks {
      result[boundaryId] = lockInfos.map { $0 as any LockmanInfo }
    }

    return result
  }
}

// MARK: - Private Implementation

private extension LockmanPriorityBasedStrategy {
  /// Applies same-priority concurrency behavior between two actions.
  ///
  /// When two actions have the same priority level, this method determines
  /// the outcome based on the existing action's concurrency behavior.
  ///
  /// ## Behavior Application (Existing Action's Behavior)
  /// The existing action's concurrency behavior determines what happens when
  /// a new same-priority action arrives:
  ///
  /// - **Existing is Exclusive**: "I run exclusively" → new action blocked
  /// - **Existing is Replaceable**: "I can be replaced" → existing gets canceled
  ///
  /// ## Examples
  /// ```swift
  /// // Existing payment (.exclusive) blocks new search
  /// existing(.exclusive) + new(.replaceable) → .failure
  ///
  /// // Existing search (.replaceable) yields to new search
  /// existing(.replaceable) + new(.exclusive) → .successWithPrecedingCancellation
  /// ```
  ///
  /// ## Design Rationale
  /// This approach ensures that each action declares its own concurrency
  /// characteristics when created, and those characteristics determine how
  /// it interacts with future actions. This makes the behavior predictable
  /// and aligns with the principle that existing actions control their
  /// own lifecycle.
  ///
  /// - Parameters:
  ///   - current: The currently active priority-based lock info
  ///   - requested: The requested priority-based lock info (behavior ignored)
  /// - Returns: A `LockmanResult` based on the existing action's concurrency behavior
  func applySamePriorityBehavior(
    current: LockmanPriorityBasedInfo,
    requested _: LockmanPriorityBasedInfo
  ) -> LockmanResult {
    // Use the existing action's behavior to determine the outcome
    guard let currentBehavior = current.priority.behavior else {
      // This shouldn't happen since we filtered out .none priorities,
      // but we handle it defensively
      return .success
    }

    switch currentBehavior {
    case .exclusive:
      // Existing action: "I run exclusively, block new same-priority actions"
      // → New action must wait or fail
      return .failure(LockmanPriorityBasedError.samePriorityConflict(priority: current.priority))

    case .replaceable:
      // Existing action: "I am replaceable, allow new same-priority actions to take over"
      // → Existing action gets canceled, new action succeeds
      return .successWithPrecedingCancellation
    }
  }
}
