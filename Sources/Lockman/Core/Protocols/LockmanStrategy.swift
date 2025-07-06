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
///   func canLock<B: LockmanBoundaryId>(id: B, info: I) -> LockmanResult {
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
  /// would succeed without modifying the strategy's internal state. The actual
  /// lock acquisition happens in the subsequent `lock` method call.
  ///
  /// ## Implementation Guidelines
  /// - Should not modify internal state
  /// - Should return quickly as this may be called frequently
  /// - Should consider all conflict conditions specific to the strategy
  /// - Should return detailed error information when lock acquisition fails
  ///
  /// ## Error Handling
  /// When returning `.failure`, strategies should include a specific error
  /// conforming to `LockmanError` that explains why the lock cannot be acquired.
  /// This helps with debugging and allows callers to handle different failure
  /// scenarios appropriately.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I` containing action details
  /// - Returns: A `LockmanResult` indicating whether the lock can be acquired,
  ///   any required actions (such as canceling existing operations), and
  ///   detailed error information if the lock cannot be acquired
  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: I) -> LockmanResult

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
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I` to be registered as active
  func lock<B: LockmanBoundaryId>(boundaryId: B, info: I)

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
  ///   - boundaryId: The boundary identifier for which the lock should be released
  ///   - info: The same lock information of type `I` that was used when acquiring the lock
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: I)

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
  /// - Parameter boundaryId: The identifier whose lock information should be removed
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B)

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
