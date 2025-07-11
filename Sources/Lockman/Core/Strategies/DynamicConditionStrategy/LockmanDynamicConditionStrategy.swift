import Foundation

/// A strategy that evaluates custom conditions at runtime to determine lock availability.
///
/// `LockmanDynamicConditionStrategy` allows you to define arbitrary locking conditions
/// using closures that are evaluated when the lock is requested. This provides maximum
/// flexibility for complex business logic scenarios.
///
/// ## Example
/// ```swift
/// // Business logic condition with custom error
/// struct PriorityTooLowError: Error {
///     let priority: Int
/// }
///
/// let action = MyAction.fetchData(userId: "123", priority: 5)
/// let conditionalAction = action.with {
///     guard priority > 3 else {
///         return .cancel(PriorityTooLowError(priority: priority))
///     }
///     return .success
/// }
/// ```
///
/// ## Thread Safety
/// This strategy is thread-safe and uses `LockmanState` for managing concurrent access.
public final class LockmanDynamicConditionStrategy: LockmanStrategy, @unchecked Sendable {
  // MARK: - Types

  public typealias I = LockmanDynamicConditionInfo

  // MARK: - Properties

  /// Shared singleton instance.
  public static let shared = LockmanDynamicConditionStrategy()

  /// Thread-safe state container that tracks active locks per boundary.
  /// Uses actionId as the key for indexing locks.
  private let state = LockmanState<LockmanDynamicConditionInfo, LockmanActionId>(
    keyExtractor: { $0.actionId }
  )

  /// The unique identifier for this strategy instance.
  public let strategyId: LockmanStrategyId

  // MARK: - Initialization

  /// Creates a new dynamic condition strategy instance.
  public init() {
    self.strategyId = Self.makeStrategyId()
  }

  /// Creates a strategy identifier for the dynamic condition strategy.
  ///
  /// - Returns: A `LockmanStrategyId` with the name "dynamicCondition"
  public static func makeStrategyId() -> LockmanStrategyId {
    .dynamicCondition
  }

  // MARK: - LockmanStrategy Protocol Implementation

  /// Evaluates the dynamic condition to determine if a lock can be acquired.
  ///
  /// The condition closure is evaluated to determine lock availability based on
  /// business logic defined at runtime.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock information containing the dynamic condition
  /// - Returns: The result from evaluating the dynamic condition
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanDynamicConditionInfo
  ) -> LockmanResult {
    // Evaluate the condition and get the result directly
    let result = info.condition()
    let failureReason: String? =
      if case .cancel(let error) = result {
        "Dynamic condition failed: \(error.localizedDescription)"
      } else {
        nil
      }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "DynamicCondition",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: failureReason
    )

    return result
  }

  /// Acquires a lock for the specified boundary and action.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock information to register
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanDynamicConditionInfo
  ) {
    state.add(id: boundaryId, info: info)
  }

  /// Releases all locks with the same actionId.
  ///
  /// This method removes all locks that have the same actionId as the provided info,
  /// regardless of their uniqueId. This is useful when multiple locks with the same
  /// actionId exist (e.g., from LockmanDynamicConditionReducer's multi-step locking).
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock information containing the actionId to remove
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanDynamicConditionInfo
  ) {
    // Remove all locks with the same actionId
    state.removeAll(id: boundaryId, key: info.actionId)
  }

  /// Removes all active locks across all boundaries.
  public func cleanUp() {
    state.removeAll()
  }

  /// Removes all active locks for the specified boundary.
  ///
  /// - Parameter boundaryId: The boundary identifier whose locks should be removed
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    state.removeAll(id: boundaryId)
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
