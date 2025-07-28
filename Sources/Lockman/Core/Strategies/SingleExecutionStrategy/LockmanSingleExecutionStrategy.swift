import Foundation

/// A locking strategy that provides flexible execution control within a boundary.
///
/// `LockmanSingleExecutionStrategy` supports three execution modes:
/// - `.none`: No exclusive execution (allows all concurrent actions)
/// - `.boundary`: Only one action can execute per boundary (strictest mode)
/// - `.action`: Only one instance of the same action can execute (allows different actions concurrently)
///
/// Choose the mode based on your concurrency requirements:
/// - Use `.boundary` for UI screens where only one action should run at a time
/// - Use `.action` for operations that can run in parallel with different actions
/// - Use `.none` to temporarily disable locking without changing code structure
///
/// ## Thread Safety
/// This strategy is thread-safe and uses `LockmanState` for managing concurrent access
/// to lock information across multiple boundaries.
///
public final class LockmanSingleExecutionStrategy: LockmanStrategy, @unchecked Sendable {
  /// Execution mode for single execution strategy
  public enum ExecutionMode: Sendable, Equatable {
    /// No exclusive execution (essentially disables the strategy)
    case none
    /// Exclusive per boundary - only one action can execute per boundary
    case boundary
    /// Exclusive per action - only one instance of the same action can execute
    case action
  }

  // MARK: - Configuration

  public typealias I = LockmanSingleExecutionInfo

  /// Shared singleton instance.
  public static let shared = LockmanSingleExecutionStrategy()

  /// Thread-safe state container that tracks active locks per boundary ID.
  /// Uses actionId as the key for indexing locks.
  private let state = LockmanState<LockmanSingleExecutionInfo, LockmanActionId>(
    keyExtractor: { $0.actionId }
  )

  /// The unique identifier for this strategy instance.
  public let strategyId: LockmanStrategyId

  /// Creates a new strategy instance.
  public init() {
    self.strategyId = Self.makeStrategyId()
  }

  /// Creates a strategy identifier for the single execution strategy.
  ///
  /// This method provides a consistent way to generate strategy IDs that can be used
  /// both during strategy initialization and in macro-generated code.
  ///
  /// - Returns: A `LockmanStrategyId` with the name "singleExecution"
  public static func makeStrategyId() -> LockmanStrategyId {
    .singleExecution
  }

  // MARK: - LockmanStrategy Protocol Implementation

  /// Checks if a lock can be acquired for the given boundary and action.
  ///
  /// The behavior depends on the execution mode specified in the info:
  /// - `.none`: Always returns `.success`
  /// - `.boundary`: Returns `.failure` if any lock exists in the boundary
  /// - `.action`: Returns `.failure` if a lock with the same action ID exists
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: The lock information containing the action ID and execution mode
  /// - Returns: `.success` if the lock can be acquired, `.cancel` if a lock conflict exists based on the execution mode
  ///
  /// ## Example
  /// ```swift
  /// let strategy = LockmanSingleExecutionStrategy()
  /// let info1 = LockmanSingleExecutionInfo(mode: .boundary)
  /// let info2 = LockmanSingleExecutionInfo(mode: .action)
  ///
  /// strategy.lock(boundaryId: boundary, info: info1)
  /// strategy.canLock(boundaryId: boundary, info: info2) // Result depends on mode and actionId
  /// ```
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) -> LockmanResult {
    let result: LockmanResult
    var failureReason: String?

    switch info.mode {
    case .none:
      // No exclusive execution - bypasses lock checking and always returns success
      result = .success

    case .boundary:
      // Exclusive per boundary - check if any lock exists
      let currentLocks = state.currents(id: boundaryId)
      if currentLocks.isEmpty {
        result = .success
      } else {
        let existingInfo = currentLocks.first!
        result = .cancel(
          LockmanSingleExecutionError.boundaryAlreadyLocked(
            boundaryId: boundaryId,
            existingInfo: existingInfo
          )
        )
        failureReason = "Boundary '\(boundaryId)' already has an active lock"
      }

    case .action:
      // Exclusive per action - check if same actionId exists
      if state.contains(id: boundaryId, key: info.actionId) {
        let existingInfo = state.currents(id: boundaryId, key: info.actionId).first!
        result = .cancel(
          LockmanSingleExecutionError.actionAlreadyRunning(
            existingInfo: existingInfo
          )
        )
        failureReason = "Action '\(info.actionId)' is already locked"
      } else {
        result = .success
      }
    }

    // Log the result
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "SingleExecution",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: failureReason
    )

    return result
  }

  /// Acquires a single-execution lock for the specified boundary and action.
  ///
  /// Adds the lock information to the internal state. This method should only be called
  /// after `canLock` returns `.success` to ensure proper lock coordination.
  ///
  /// ## Instance Tracking
  /// The exact `info` instance (with its `uniqueId`) is stored, allowing for
  /// precise removal during unlock operations.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: The lock information to register as active
  ///
  /// ## Example
  /// ```swift
  /// let info = LockmanSingleExecutionInfo(actionId: "processPayment")
  ///
  /// if strategy.canLock(boundaryId: boundary, info: info) == .success {
  ///   strategy.lock(boundaryId: boundary, info: info)
  ///   // info is now tracked with its specific uniqueId
  /// }
  /// ```
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) {
    state.add(id: boundaryId, info: info)
  }

  /// Releases a previously acquired lock for the specified boundary and action.
  ///
  /// Removes the specific lock information from the internal state using the
  /// instance's `uniqueId`. This provides precise lock management and prevents
  /// unintended removal of other locks with the same `actionId`.
  ///
  /// ## Instance-Specific Removal
  /// Only the exact `info` instance that was passed to `lock()` is removed.
  /// Other instances with the same `actionId` but different `uniqueId` values
  /// remain unaffected.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier whose lock should be released
  ///   - info: The exact lock information that was used when acquiring the lock
  ///
  /// ## Rationale for uniqueId-based Removal
  /// Using `uniqueId` instead of `actionId` for removal provides:
  /// - **Precision**: Only removes the specific lock instance that was acquired
  /// - **Safety**: Prevents accidental removal of other locks with the same actionId
  /// - **Consistency**: Maintains 1:1 correspondence between lock() and unlock() calls
  /// - **Flexibility**: Allows multiple lock instances with the same actionId in different scenarios
  ///
  /// ## Example
  /// ```swift
  /// let info1 = LockmanSingleExecutionInfo(actionId: "sync")
  /// let info2 = LockmanSingleExecutionInfo(actionId: "sync")  // Same actionId, different uniqueId
  ///
  /// // Hypothetical scenario where both could be locked on different boundaries
  /// strategy.lock(boundaryId: boundary1, info: info1)
  /// strategy.lock(boundaryId: boundary2, info: info2)
  ///
  /// // Unlock only removes the specific instance
  /// strategy.unlock(boundaryId: boundary1, info: info1)  // Only removes info1
  /// // info2 remains locked on boundary2
  /// ```
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) {
    state.remove(id: boundaryId, info: info)
  }

  /// Removes all active locks across all boundaries and execution modes.
  public func cleanUp() {
    state.removeAll()
  }

  /// Removes all active locks for the specified boundary across all execution modes.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    state.removeAll(id: boundaryId)
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
    let allLocks = state.getAllLocks()

    for (boundaryId, lockInfos) in allLocks {
      result[boundaryId] = lockInfos.map { $0 as any LockmanInfo }
    }

    return result
  }
}
