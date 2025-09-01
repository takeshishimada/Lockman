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
/// let result = strategy.canLock(boundaryId: .payment, info: payment)
/// // Result: .success or .failure based on existing actions
///
/// // High priority replaceable action
/// let search = LockmanPriorityBasedInfo(actionId: "search", priority: .high(.replaceable))
/// let result = strategy.canLock(boundaryId: .search, info: search)
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
  /// active action for each boundary. Uses actionId as the key for indexing locks.
  private let state = LockmanState<LockmanPriorityBasedInfo, LockmanActionId>(
    keyExtractor: { $0.actionId }
  )

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
  /// 2. **Current State Check**: Examines existing non-none priority actions
  /// 3. **Priority Comparison**: Compares requested priority with current highest
  /// 4. **Behavior Application**: Applies existing action's concurrency behavior when levels match
  ///
  /// ## Return Values
  /// - `.success`: No conflicts, lock can be acquired immediately
  /// - `.successWithPrecedingCancellation`: Lock acquired, but existing operation must be canceled
  /// - `.cancel`: Cannot acquire lock due to higher/equal priority conflicts or same-action blocking
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Priority-based lock information containing action ID and priority
  /// - Returns: `.success` if the lock can be acquired, `.cancel` if conflicts exist,
  ///   or `.successWithPrecedingCancellation` if the lock can be acquired by canceling existing actions
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanPriorityBasedInfo
  ) -> LockmanStrategyResult {
    let requestedInfo = info
    let result: LockmanStrategyResult
    var failureReason: String?
    var cancelledInfo: (actionId: String, uniqueId: UUID)?

    // No priority actions bypass the priority system entirely
    if requestedInfo.priority == .none {
      result = .success

      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "PriorityBased",
        boundaryId: String(describing: boundaryId),
        info: info
      )
      return result
    }

    // Get all current locks for this boundary
    let currentLocks = state.currentLocks(in: boundaryId)

    // Filter out non-priority actions for priority comparison
    let priorityLocks = currentLocks.filter { $0.priority != .none }

    // Get the most recently added priority action as the behavioral reference
    // OrderedDictionary guarantees insertion order, so .last gives us the latest priority action
    // In same-priority conflict resolution, the most recent action's behavior determines the outcome
    guard let mostRecentPriorityInfo = priorityLocks.last else {
      result = .success

      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "PriorityBased",
        boundaryId: String(describing: boundaryId),
        info: info
      )
      return result
    }

    let currentPriority = mostRecentPriorityInfo.priority
    let requestedPriority = requestedInfo.priority

    // Compare priority levels using the Comparable implementation
    if currentPriority > requestedPriority {
      // Current action has higher priority - request fails
      result = .cancel(
        LockmanPriorityBasedError.higherPriorityExists(
          requestedInfo: info,
          lockmanInfo: mostRecentPriorityInfo,
          boundaryId: boundaryId
        )
      )
      failureReason =
        "Higher priority action '\(mostRecentPriorityInfo.actionId)' (priority: \(currentPriority)) is currently locked"
    } else if currentPriority == requestedPriority {
      // Same priority level - apply existing action's concurrency behavior
      let behaviorResult = applySamePriorityBehavior(
        current: mostRecentPriorityInfo,
        requested: requestedInfo,
        boundaryId: boundaryId
      )
      result = behaviorResult

      if case .cancel = behaviorResult {
        failureReason =
          "Same priority action '\(mostRecentPriorityInfo.actionId)' with exclusive behavior is already running"
      } else if case .successWithPrecedingCancellation(_) = behaviorResult {
        cancelledInfo = (mostRecentPriorityInfo.actionId, mostRecentPriorityInfo.uniqueId)
      }
    } else {
      // Requested action has higher priority - can preempt current
      result = .successWithPrecedingCancellation(
        error: LockmanPriorityBasedError.precedingActionCancelled(
          lockmanInfo: mostRecentPriorityInfo,
          boundaryId: boundaryId
        )
      )
      cancelledInfo = (mostRecentPriorityInfo.actionId, mostRecentPriorityInfo.uniqueId)
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "PriorityBased",
      boundaryId: String(describing: boundaryId),
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
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Priority-based lock information to register as active
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanPriorityBasedInfo
  ) {
    state.add(boundaryId: boundaryId, info: info)
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
  ///   - boundaryId: The boundary identifier whose lock should be released
  ///   - info: The same lock information that was used when acquiring the lock
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanPriorityBasedInfo
  ) {
    state.remove(boundaryId: boundaryId, info: info)
  }

  /// Removes all priority-based locks across all boundaries and priority levels.
  public func cleanUp() {
    state.removeAll()
  }

  /// Removes all priority-based locks for the specified boundary across all priority levels.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    state.removeAll(boundaryId: boundaryId)
  }

  /// Returns current locks information for debugging purposes.
  ///
  /// Provides a snapshot of all currently held locks across all boundaries.
  /// The returned dictionary maps boundary identifiers to their active lock information.
  ///
  /// - Returns: A dictionary mapping boundary identifiers to their associated lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Get all boundaries and their locks from the state
    let allLocks = state.allActiveLocks()

    for (boundaryId, lockInfos) in allLocks {
      result[boundaryId] = lockInfos.map { $0 as any LockmanInfo }
    }

    return result
  }
}

// MARK: - Private Implementation

extension LockmanPriorityBasedStrategy {
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
  /// // Existing action with exclusive behavior blocks new action
  /// current: .high(.exclusive), requested: .high(.replaceable) → .failure
  ///
  /// // Existing action with replaceable behavior yields to new action
  /// current: .high(.replaceable), requested: .high(.exclusive) → .successWithPrecedingCancellation
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
  /// - Returns: A `LockmanStrategyResult` based on the existing action's concurrency behavior
  fileprivate func applySamePriorityBehavior<B: LockmanBoundaryId>(
    current: LockmanPriorityBasedInfo,
    requested: LockmanPriorityBasedInfo,
    boundaryId: B
  ) -> LockmanStrategyResult {
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
      return .cancel(
        LockmanPriorityBasedError.samePriorityConflict(
          requestedInfo: requested,
          lockmanInfo: current,
          boundaryId: boundaryId
        )
      )

    case .replaceable:
      // Existing action: "I am replaceable, allow new same-priority actions to take over"
      // → Existing action gets canceled, new action succeeds
      return .successWithPrecedingCancellation(
        error: LockmanPriorityBasedError.precedingActionCancelled(
          lockmanInfo: current,
          boundaryId: boundaryId
        )
      )
    }
  }
}
