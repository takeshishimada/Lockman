/// A type-erased wrapper for any `LockmanStrategy<I>`, enabling heterogeneous strategy
/// storage and manipulation while preserving type safety for lock information.
///
/// ## Purpose
/// `AnyLockmanStrategy` solves the fundamental problem of storing different concrete
/// strategy implementations in the same collection. Without type erasure, you cannot
/// store `LockmanSingleExecutionStrategy` and `LockmanPriorityBasedStrategy` in the
/// same array, even though they both conform to `LockmanStrategy`.
///
/// ## Key Benefits
/// - **Heterogeneous Collections**: Store different strategy implementations together
/// - **Runtime Strategy Selection**: Choose strategies dynamically based on conditions
/// - **API Boundaries**: Hide concrete strategy types from public interfaces
/// - **Dependency Injection**: Enable flexible strategy registration and resolution
/// - **Universal Compatibility**: Support both class and struct strategy implementations
///
/// ## Type Safety Guarantees
/// While the concrete strategy type is erased, type safety for lock information `I`
/// is preserved at the `AnyLockmanStrategy` level. This means you cannot accidentally
/// use `LockmanSingleExecutionInfo` with a priority-based strategy wrapper.
///
/// ## Performance Considerations
/// Type erasure introduces a small runtime overhead due to function pointer indirection.
/// However, this cost is typically negligible compared to the actual locking operations
/// and is justified by the flexibility gained.
///
public struct AnyLockmanStrategy<I: LockmanInfo>: LockmanStrategy, Sendable {
  // MARK: - Type-Erased Function Storage

  /// Type-erased function for lock feasibility checking.
  ///
  /// This closure encapsulates the `canLock(id:info:)` method of the concrete strategy,
  /// allowing the type-erased wrapper to delegate the call while hiding the concrete type.
  ///
  /// - Performance: Direct function pointer call with minimal overhead
  /// - Thread Safety: Marked as `@Sendable` to ensure concurrent access safety
  private let _canLock: @Sendable (any LockmanBoundaryId, I) -> LockmanResult

  /// Type-erased function for lock acquisition.
  ///
  /// Encapsulates the `lock(id:info:)` method, maintaining the same interface
  /// while hiding the concrete strategy implementation details.
  private let _lock: @Sendable (any LockmanBoundaryId, I) -> Void

  /// Type-erased function for lock release.
  ///
  /// Encapsulates the `unlock(id:info:)` method. The implementation must ensure
  /// that unlock operations are called with the same parameters used for locking.
  private let _unlock: @Sendable (any LockmanBoundaryId, I) -> Void

  /// Type-erased function for global cleanup operations.
  ///
  /// Encapsulates the `cleanUp()` method for removing all locks across all boundaries.
  /// This is typically used during application shutdown or test teardown.
  private let _cleanUp: @Sendable () -> Void

  /// Type-erased function for boundary-specific cleanup operations.
  ///
  /// Encapsulates the `cleanUp(id:)` method for targeted cleanup of specific boundaries.
  /// This enables fine-grained resource management without affecting other boundaries.
  private let _cleanUpById: @Sendable (any LockmanBoundaryId) -> Void

  /// Type-erased storage for the strategy's identifier.
  ///
  /// Preserves the concrete strategy's ID for registration and resolution purposes.
  private let _strategyId: LockmanStrategyId

  /// Type-erased function for getting current locks.
  ///
  /// Encapsulates the `getCurrentLocks()` method for debugging purposes.
  private let _getCurrentLocks: @Sendable () -> [AnyLockmanBoundaryId: [any LockmanInfo]]

  // MARK: - Initialization

  /// Creates a new type-erased strategy wrapper from any concrete strategy implementation.
  ///
  /// This initializer performs type erasure by capturing the concrete strategy's methods
  /// as closures. The concrete strategy's lifetime is preserved through these closures,
  /// ensuring that the strategy remains valid for the lifetime of this wrapper.
  ///
  /// ## Type Safety
  /// The `where S.I == I` constraint ensures that the concrete strategy's lock information
  /// type matches this wrapper's lock information type, maintaining type safety at compile time.
  ///
  /// ## Memory Management
  /// - For class-based strategies: The strategy instance is retained by the closures
  /// - For struct-based strategies: The strategy is copied into the closures
  /// - Both approaches ensure proper lifetime management without memory leaks
  ///
  /// ## Performance Notes
  /// The type erasure process happens once during initialization. Subsequent method calls
  /// have minimal overhead (single function pointer indirection).
  ///
  /// - Parameter strategy: A concrete strategy conforming to `LockmanStrategy<I>`
  public init<S: LockmanStrategy>(_ strategy: S) where S.I == I {
    // Capture each method as a closure, preserving the concrete strategy's behavior
    // while erasing its type information

    _canLock = { [strategy] id, info in
      strategy.canLock(id: id, info: info)
    }

    _lock = { [strategy] id, info in
      strategy.lock(id: id, info: info)
    }

    _unlock = { [strategy] id, info in
      strategy.unlock(id: id, info: info)
    }

    _cleanUp = { [strategy] in
      strategy.cleanUp()
    }

    _cleanUpById = { [strategy] id in
      strategy.cleanUp(id: id)
    }

    _getCurrentLocks = { [strategy] in
      strategy.getCurrentLocks()
    }

    _strategyId = strategy.strategyId
  }

  // MARK: - LockmanStrategy Protocol Implementation

  /// The identifier for this type-erased strategy.
  ///
  /// Returns the same ID as the wrapped concrete strategy, preserving
  /// its identity for registration and resolution purposes.
  public var strategyId: LockmanStrategyId {
    _strategyId
  }

  /// Creates a strategy identifier for the type-erased strategy.
  ///
  /// Note: This method returns a generic identifier as type-erased strategies
  /// don't have their own specific identity. The actual strategy ID comes from
  /// the wrapped concrete strategy instance.
  ///
  /// - Returns: A generic `LockmanStrategyId` for type-erased strategies
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "AnyLockmanStrategy<\(String(describing: I.self))>")
  }

  /// Checks if a lock can be acquired for the given boundary and information.
  ///
  /// This method delegates to the concrete strategy's implementation through the
  /// captured closure, maintaining identical behavior while hiding the concrete type.
  ///
  /// ## Delegation Pattern
  /// The type-erased wrapper acts as a transparent proxy, forwarding all calls to the
  /// underlying concrete strategy without modification. This ensures that the behavior
  /// is identical to calling the concrete strategy directly.
  ///
  /// ## Error Handling
  /// Any errors thrown by the concrete strategy are propagated unchanged through this wrapper.
  /// The wrapper does not add its own error handling or modification.
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I`
  /// - Returns: A `LockmanResult` indicating whether the lock can be acquired
  public func canLock<B: LockmanBoundaryId>(id: B, info: I) -> LockmanResult {
    _canLock(id, info)
  }

  /// Attempts to acquire a lock for the given boundary and information.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// The implementation delegates to the concrete strategy's lock acquisition logic.
  ///
  /// ## Usage Contract
  /// - **Precondition**: `canLock(id:info:)` should return `.success` or `.successWithPrecedingCancellation`
  /// - **Postcondition**: The lock is acquired and tracked by the underlying strategy
  /// - **Thread Safety**: Safe to call concurrently with different boundary IDs
  ///
  /// ## State Management
  /// The concrete strategy is responsible for updating its internal state to track
  /// the acquired lock. This wrapper does not add any additional state management.
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Lock information of type `I` to be registered as active
  public func lock<B: LockmanBoundaryId>(id: B, info: I) {
    _lock(id, info)
  }

  /// Releases a previously acquired lock.
  ///
  /// This method must be called with the exact same parameters that were used
  /// when acquiring the lock. The implementation delegates to the concrete strategy's
  /// unlock logic, which typically uses the lock info's `uniqueId` for precise identification.
  ///
  /// ## Parameter Matching Requirements
  /// - **Boundary ID**: Must match the ID used during lock acquisition
  /// - **Lock Info**: Must be the same instance (same `uniqueId`) used during acquisition
  /// - **Strategy Consistency**: Must be called on the same strategy instance that acquired the lock
  ///
  /// ## Error Recovery
  /// If called with mismatched parameters, the concrete strategy may:
  /// - Silently ignore the unlock request (defensive programming)
  /// - Log a warning for debugging purposes
  /// - Throw an error in debug builds
  ///
  /// The behavior depends on the concrete strategy's implementation.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier for which the lock should be released
  ///   - info: The same lock information of type `I` that was used when acquiring the lock
  public func unlock<B: LockmanBoundaryId>(id: B, info: I) {
    _unlock(id, info)
  }

  /// Removes all lock information across all boundaries.
  ///
  /// This method provides a global reset mechanism by clearing all internal lock state
  /// from the underlying strategy. It's typically used during:
  /// - Application shutdown sequences
  /// - Test suite cleanup between test cases
  /// - Emergency reset scenarios during development
  /// - Memory pressure response
  ///
  /// ## Scope of Operation
  /// This method affects **all boundaries** managed by the underlying strategy,
  /// not just those accessed through this particular wrapper instance.
  ///
  /// ## Thread Safety
  /// The operation is atomic with respect to other strategy operations, but
  /// callers should be aware that concurrent operations may be affected.
  ///
  /// ## Side Effects
  /// - All active locks are immediately released
  /// - Lock state tracking is reset to initial conditions
  /// - Pending operations may receive unexpected unlock notifications
  public func cleanUp() {
    _cleanUp()
  }

  /// Removes all lock information for the specified boundary identifier.
  ///
  /// This method provides targeted cleanup for specific boundary identifiers,
  /// allowing fine-grained control over which lock state to clear while
  /// leaving other boundaries unaffected.
  ///
  /// ## Selective Cleanup Benefits
  /// - **Resource Management**: Clean up specific features without global impact
  /// - **User Sessions**: Clear user-specific locks during logout
  /// - **Feature Lifecycle**: Clean up when components are deallocated
  /// - **Error Recovery**: Reset specific boundary state after errors
  ///
  /// ## Boundary Isolation
  /// This operation only affects locks associated with the specified boundary.
  /// Other boundaries managed by the same strategy instance remain unaffected.
  ///
  /// ## Use Cases
  /// - Feature-specific cleanup when a view controller is deallocated
  /// - User session cleanup when a user logs out
  /// - Scoped cleanup for temporary contexts or workflows
  /// - Partial system resets during development and testing
  ///
  /// - Parameter id: The identifier whose lock information should be removed
  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    _cleanUpById(id)
  }

  /// Returns current locks information for debugging.
  ///
  /// This method provides a snapshot of all currently held locks managed by the
  /// underlying concrete strategy. The implementation delegates to the concrete
  /// strategy's getCurrentLocks method through the type-erased closure.
  ///
  /// ## Type Safety
  /// While the strategy type is erased, the lock information types are preserved
  /// through the protocol's associated type requirement.
  ///
  /// ## Thread Safety
  /// The operation provides a consistent snapshot at the time of the call,
  /// but the actual lock state may change immediately after.
  ///
  /// - Returns: Dictionary mapping boundary IDs to their active lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    _getCurrentLocks()
  }
}

// MARK: - Extensions
