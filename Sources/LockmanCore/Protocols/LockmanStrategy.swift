/// The result of attempting to acquire a lock.
///
/// This enum represents the possible outcomes when a strategy attempts
/// to acquire a lock for a given boundary and lock information. The result
/// determines how the calling code should proceed with the requested operation.
public enum LockResult: Sendable {
  /// Lock acquisition succeeded without conflicts.
  ///
  /// The requested lock was successfully acquired and no existing locks
  /// were affected. The operation can proceed immediately without any
  /// additional cleanup or cancellation steps.
  case success

  /// Lock acquisition succeeded but requires canceling a preceding operation.
  ///
  /// The requested lock was acquired, but an existing operation needs to be
  /// canceled to make way for the new one. This typically occurs in priority-based
  /// strategies where a higher-priority action preempts a lower-priority one.
  ///
  /// When this result is returned, the calling code should:
  /// 1. Cancel the existing operation (usually via Effect cancellation)
  /// 2. Proceed with the new operation
  case successWithPrecedingCancellation

  /// Lock acquisition failed due to conflicts.
  ///
  /// The requested lock could not be acquired because a conflicting operation
  /// is already running. This typically occurs when:
  /// - A higher-priority operation is already active (priority-based strategy)
  /// - The same action is already running (single-execution strategy)
  /// - Strategy-specific conflict conditions are met
  ///
  /// When this result is returned, the requesting operation should not proceed.
  ///
  /// - Parameter error: An optional error describing why the lock acquisition failed
  case failure((any Error)? = nil)
}

// MARK: - Equatable Conformance

extension LockResult: Equatable {
  public static func == (lhs: LockResult, rhs: LockResult) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case (.successWithPrecedingCancellation, .successWithPrecedingCancellation):
      return true
    case (.failure(let lhsError), .failure(let rhsError)):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError?.localizedDescription == rhsError?.localizedDescription
    default:
      return false
    }
  }
}

/// A protocol defining the core locking operations that all strategies must implement.
///
/// This protocol provides a common interface for different locking strategies,
/// allowing them to be used interchangeably while maintaining type safety for
/// lock information. Each strategy implements specific logic for conflict detection,
/// lock management, and cleanup operations.
///
/// ## Strategy Types
/// - **Single Execution**: Prevents concurrent execution of the same action
/// - **Priority-Based**: Allows higher priority actions to preempt lower priority ones
/// - **Composite**: Combines multiple strategies for complex coordination
///
/// ## Implementation Guidelines
/// Strategies can be implemented as either classes (for stateful strategies) or
/// structs (for stateless strategies). Both can be type-erased using `AnyLockmanStrategy`.
///
/// ## Thread Safety
/// All strategy implementations must be thread-safe as they may be called
/// concurrently from multiple contexts. Use appropriate synchronization
/// mechanisms in your implementation.
///
/// ## Example Implementation
/// ```swift
/// final class MyStrategy: LockmanStrategy {
///   typealias I = MyLockInfo
///
///   func canLock<B: LockmanBoundaryId>(id: B, info: I) -> LockResult {
///     // Check if lock can be acquired
///     return .success
///   }
///
///   func lock<B: LockmanBoundaryId>(id: B, info: I) {
///     // Acquire the lock
///   }
///
///   func unlock<B: LockmanBoundaryId>(id: B, info: I) {
///     // Release the lock
///   }
///
///   func cleanUp() {
///     // Clean up all state
///   }
///
///   func cleanUp<B: LockmanBoundaryId>(id: B) {
///     // Clean up state for specific boundary
///   }
/// }
/// ```
public protocol LockmanStrategy<I>: Sendable {
  /// The type of lock information this strategy handles.
  ///
  /// This associated type constrains the strategy to work with a specific
  /// type of lock information, ensuring type safety and preventing
  /// incompatible information from being passed to the strategy.
  associatedtype I: LockmanInfo

  /// The unique identifier for this strategy instance.
  ///
  /// This property defines how the strategy is identified within the container.
  /// Different instances of the same strategy type can have different IDs,
  /// enabling multiple configurations of the same strategy to coexist.
  ///
  /// ## Built-in Strategies
  /// ```swift
  /// var strategyId: LockmanStrategyId { .singleExecution }
  /// ```
  ///
  /// ## Configured Strategies
  /// ```swift
  /// var strategyId: LockmanStrategyId {
  ///   LockmanStrategyId(
  ///     name: "RateLimit",
  ///     configuration: "limit-\(self.limit)"
  ///   )
  /// }
  /// ```
  var strategyId: LockmanStrategyId { get }

  /// Creates a strategy identifier for this strategy type.
  ///
  /// This static method provides a consistent way to generate strategy IDs
  /// that can be used both during strategy initialization and in macro-generated code.
  ///
  /// ## Implementation Example
  /// ```swift
  /// static func makeStrategyId() -> LockmanStrategyId {
  ///   .init(name: "myStrategy")
  /// }
  /// ```
  ///
  /// ## For Configurable Strategies
  /// ```swift
  /// // Provide a default configuration
  /// static func makeStrategyId() -> LockmanStrategyId {
  ///   makeStrategyId(mode: .default)
  /// }
  ///
  /// // And a parameterized version
  /// static func makeStrategyId(mode: Mode) -> LockmanStrategyId {
  ///   .init(name: "myStrategy", configuration: "mode:\(mode)")
  /// }
  /// ```
  ///
  /// - Returns: A `LockmanStrategyId` that uniquely identifies this strategy type
  static func makeStrategyId() -> LockmanStrategyId

  /// Checks if a lock can be acquired without actually acquiring it.
  ///
  /// This method allows the strategy to evaluate whether a lock acquisition
  /// would succeed without modifying the strategy's internal state. This is
  /// useful for pre-flight checks and decision making in the Effect system.
  ///
  /// ## Implementation Guidelines
  /// - Should not modify internal state
  /// - Should return quickly as this may be called frequently
  /// - Should consider all conflict conditions specific to the strategy
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I` containing action details
  /// - Returns: A `LockResult` indicating whether the lock can be acquired
  ///   and any required actions (such as canceling existing operations)
  func canLock<B: LockmanBoundaryId>(id: B, info: I) -> LockResult

  /// Attempts to acquire a lock for the given boundary and information.
  ///
  /// When this method is called, the strategy should update its internal state
  /// to reflect that the lock has been acquired. The strategy is responsible
  /// for tracking this state until the corresponding `unlock` call.
  ///
  /// ## Implementation Guidelines
  /// - Should only be called after `canLock` returns a success result
  /// - Must update internal state to track the active lock
  /// - Should be idempotent if called multiple times with the same parameters
  ///
  /// ## Thread Safety
  /// This method may be called concurrently and must handle concurrent
  /// access to internal state appropriately.
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I` to be registered as active
  func lock<B: LockmanBoundaryId>(id: B, info: I)

  /// Releases a previously acquired lock.
  ///
  /// This method should update the strategy's internal state to reflect
  /// that the lock is no longer held. The parameters should match those
  /// used in the corresponding `lock` call.
  ///
  /// ## Implementation Guidelines
  /// - Must correctly identify and remove the specific lock instance
  /// - Should handle cases where the lock was already released (idempotent)
  /// - Should not fail if the lock doesn't exist (defensive programming)
  ///
  /// ## Parameter Matching
  /// The strategy typically uses the combination of boundary ID and action ID
  /// (from the lock info) to identify which lock to release. Some strategies
  /// may require exact instance matching.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier for which the lock should be released
  ///   - info: The same lock information of type `I` that was used when acquiring the lock
  func unlock<B: LockmanBoundaryId>(id: B, info: I)

  /// Removes all lock information across all boundaries.
  ///
  /// This method clears all internal lock state managed by the strategy,
  /// effectively resetting it to its initial state. Use this for:
  /// - Application shutdown sequences
  /// - Test suite cleanup between tests
  /// - Global system resets during development
  /// - Emergency cleanup scenarios
  ///
  /// ## Implementation Guidelines
  /// - Should remove all tracked locks regardless of boundary
  /// - Should not fail even if no locks are currently held
  /// - Should be safe to call multiple times
  func cleanUp()

  /// Removes all lock information for the specified boundary identifier.
  ///
  /// This method provides targeted cleanup for specific boundary identifiers,
  /// allowing fine-grained control over which lock state to clear while
  /// leaving other boundaries unaffected.
  ///
  /// ## Use Cases
  /// - Feature-specific cleanup when a component is deallocated
  /// - User session cleanup when a user logs out
  /// - Scoped cleanup for temporary contexts
  /// - Partial system resets during development
  ///
  /// ## Implementation Guidelines
  /// - Should only affect locks associated with the specified boundary
  /// - Should not fail if no locks exist for the boundary
  /// - Should preserve locks for other boundaries
  ///
  /// - Parameter id: The identifier whose lock information should be removed
  func cleanUp<B: LockmanBoundaryId>(id: B)

  /// Returns current locks information for debugging purposes.
  ///
  /// This method provides a snapshot of all currently held locks managed by this strategy.
  /// The returned dictionary maps boundary identifiers to arrays of lock information,
  /// allowing debug tools to display the current lock state.
  ///
  /// ## Implementation Guidelines
  /// - Should return a snapshot of current state (not a live reference)
  /// - Should include all active locks across all boundaries
  /// - The returned lock info should be the same instances passed to `lock`
  ///
  /// ## Thread Safety
  /// This method may be called while locks are being acquired/released,
  /// so implementations must handle concurrent access appropriately.
  ///
  /// - Returns: Dictionary mapping boundary IDs to their active lock information
  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]]
}
