import Foundation

/// A thread-safe, Sendable dependency injection container for registering and resolving
/// lock strategies using type erasure and flexible identifiers.
///
/// This container manages a collection of heterogeneous locking strategies, allowing
/// runtime strategy selection and resolution while maintaining type safety through
/// type erasure. Strategies are identified by `LockmanStrategyId` instead of types,
/// enabling multiple configurations of the same strategy type.
///
/// ## Thread Safety
/// All operations are protected by `ManagedCriticalState` using `os_unfair_lock`
/// for efficient synchronization. Multiple threads can safely register and resolve
/// strategies concurrently.
///
/// ## Flexible Identification
/// Strategies are identified by `LockmanStrategyId` values, allowing:
/// - Multiple configurations of the same strategy type
/// - User-defined strategy identifiers
/// - Runtime strategy selection
///
/// ## Usage Examples
/// ```swift
/// let container = LockmanStrategyContainer()
///
/// // Register built-in strategies
/// try container.register(
///   id: .singleExecution,
///   strategy: LockmanSingleExecutionStrategy.shared
/// )
///
/// // Register configured strategies
/// try container.register(
///   id: LockmanStrategyId("MyApp.RateLimit:100"),
///   strategy: RateLimitStrategy(limit: 100)
/// )
///
/// // Resolve strategies
/// let strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> =
///   try container.resolve(id: .singleExecution)
/// ```
public final class LockmanStrategyContainer: @unchecked Sendable {
  // MARK: - Private Types

  /// Metadata about a registered strategy for enhanced functionality.
  private struct StrategyEntry {
    /// The type-erased strategy instance
    let strategy: Any

    /// The strategy type name for debugging and diagnostics
    let typeName: String

    /// Registration timestamp for debugging and analysis
    let registeredAt: Date

    /// Cleanup closure that doesn't require specific type knowledge
    let cleanUp: @Sendable () -> Void

    /// Boundary-specific cleanup closure
    let cleanUpById: @Sendable (any LockmanBoundaryId) -> Void

    init<S: LockmanStrategy>(strategy: S) {
      let anyStrategy = AnyLockmanStrategy(strategy)

      self.strategy = anyStrategy
      self.typeName = String(describing: S.self)
      self.registeredAt = Date()
      self.cleanUp = { anyStrategy.cleanUp() }
      self.cleanUpById = { id in anyStrategy.cleanUp(id: id) }
    }
  }

  // MARK: - Private Properties

  /// Internal storage mapping strategy identifiers to their entries.
  /// Uses `LockmanStrategyId` for flexible strategy identification.
  private let storage: ManagedCriticalState<[LockmanStrategyId: StrategyEntry]>

  // MARK: - Initialization

  /// Creates an empty `LockmanStrategyContainer`.
  ///
  /// The container starts with no registered strategies. Strategies must be
  /// explicitly registered before they can be resolved.
  public init() {
    storage = ManagedCriticalState([:])
  }

  // MARK: - Strategy Registration

  /// Registers a concrete strategy instance with a specific identifier.
  ///
  /// The strategy is wrapped in `AnyLockmanStrategy<I>` for type-safe storage
  /// while allowing heterogeneous strategy types to coexist in the container.
  /// Each strategy ID can only be registered once to prevent conflicts.
  ///
  /// - Parameters:
  ///   - id: The unique identifier for this strategy configuration
  ///   - strategy: A concrete strategy conforming to `LockmanStrategy<I>`
  /// - Throws: `LockmanError.strategyAlreadyRegistered` if this ID is already registered
  ///
  /// ## Complexity
  /// O(1) - Direct hash map insertion with conflict detection
  ///
  /// ## Thread Safety
  /// Safe to call concurrently from multiple threads. Registration is atomic.
  ///
  /// ## Example
  /// ```swift
  /// let container = LockmanStrategyContainer()
  /// try container.register(id: .singleExecution, strategy: LockmanSingleExecutionStrategy.shared)
  /// try container.register(id: "MyApp.RateLimit:100", strategy: RateLimitStrategy(limit: 100))
  /// ```
  public func register<S: LockmanStrategy>(id: LockmanStrategyId, strategy: S) throws {
    let entry = StrategyEntry(strategy: strategy)

    try storage.withCriticalRegion { storage in
      if storage[id] != nil {
        throw LockmanRegistrationError.strategyAlreadyRegistered(id.value)
      } else {
        storage[id] = entry
      }
    }
  }

  /// Registers a concrete strategy instance using its own strategyId.
  ///
  /// Convenience method that uses the strategy's built-in ID property.
  /// This is the preferred method for registering strategies as it ensures
  /// consistency between the strategy's identity and its registration.
  ///
  /// - Parameter strategy: A concrete strategy conforming to `LockmanStrategy<I>`
  /// - Throws: `LockmanError.strategyAlreadyRegistered` if this ID is already registered
  ///
  /// ## Example
  /// ```swift
  /// try container.register(LockmanSingleExecutionStrategy.shared)
  /// // Uses strategy.strategyId automatically
  /// ```
  public func register<S: LockmanStrategy>(_ strategy: S) throws {
    try register(id: strategy.strategyId, strategy: strategy)
  }

  /// Registers multiple strategies with their IDs in a single atomic operation.
  ///
  /// This method allows bulk registration of strategies while ensuring that
  /// either all strategies are registered successfully or none are registered
  /// (all-or-nothing semantics).
  ///
  /// - Parameter strategies: Array of (id, strategy) pairs to register
  /// - Throws: `LockmanError.strategyAlreadyRegistered` if any ID is already registered
  ///
  /// ## Error Behavior
  /// If any strategy ID in the array conflicts with an existing registration,
  /// the entire operation fails and no strategies are registered.
  ///
  /// ## Example
  /// ```swift
  /// try container.registerAll([
  ///   (.singleExecution, LockmanSingleExecutionStrategy.shared),
  ///   (.priorityBased, LockmanPriorityBasedStrategy.shared),
  ///   ("MyApp.Custom", MyCustomStrategy())
  /// ])
  /// ```
  public func registerAll<S: LockmanStrategy>(_ strategies: [(LockmanStrategyId, S)]) throws {
    // Pre-validate all strategies to ensure atomic registration
    let entries: [(LockmanStrategyId, StrategyEntry)] = strategies.map { id, strategy in
      let entry = StrategyEntry(strategy: strategy)
      return (id, entry)
    }

    // Check for duplicates within the input array
    var seenIds = Set<LockmanStrategyId>()
    for (id, _) in entries {
      if !seenIds.insert(id).inserted {
        throw LockmanRegistrationError.strategyAlreadyRegistered(id.value)
      }
    }

    try storage.withCriticalRegion { storage in
      // Check for conflicts with existing registrations
      for (id, _) in entries {
        if storage[id] != nil {
          throw LockmanRegistrationError.strategyAlreadyRegistered(id.value)
        }
      }

      // Register all strategies atomically
      for (id, entry) in entries {
        storage[id] = entry
      }
    }
  }

  /// Registers multiple strategies using their own strategyIds in a single atomic operation.
  ///
  /// Convenience method that uses each strategy's built-in ID property.
  /// Either all strategies are registered successfully or none are registered.
  ///
  /// - Parameter strategies: Array of strategies to register
  /// - Throws: `LockmanError.strategyAlreadyRegistered` if any ID is already registered
  ///
  /// ## Example
  /// ```swift
  /// try container.registerAll([
  ///   LockmanSingleExecutionStrategy.shared,
  ///   LockmanPriorityBasedStrategy.shared,
  ///   MyCustomStrategy()
  /// ])
  /// ```
  public func registerAll<S: LockmanStrategy>(_ strategies: [S]) throws {
    let pairs = strategies.map { strategy in
      (strategy.strategyId, strategy)
    }
    try registerAll(pairs)
  }

  // MARK: - Strategy Resolution

  /// Resolves a registered strategy by its identifier.
  ///
  /// Returns the type-erased strategy instance that was registered with the given ID.
  /// The returned `AnyLockmanStrategy<I>` provides the same interface as the original
  /// strategy but with erased concrete type information.
  ///
  /// - Parameters:
  ///   - id: The strategy identifier to look up
  ///   - expecting: The expected `LockmanInfo` type (for type inference)
  /// - Returns: An `AnyLockmanStrategy<I>` wrapping the registered strategy instance
  /// - Throws: `LockmanError.strategyNotRegistered` if no strategy with this ID is registered
  ///
  /// ## Complexity
  /// O(1) - Direct hash map lookup by ID
  ///
  /// ## Thread Safety
  /// Safe to call concurrently from multiple threads. Resolution is atomic.
  ///
  /// ## Example
  /// ```swift
  /// let strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> =
  ///   try container.resolve(id: .singleExecution)
  /// let result = strategy.canLock(id: boundaryId, info: lockInfo)
  /// ```
  public func resolve<I: LockmanInfo>(
    id: LockmanStrategyId,
    expecting _: I.Type = I.self
  ) throws -> AnyLockmanStrategy<I> {
    try storage.withCriticalRegion { storage in
      guard let entry = storage[id],
        let anyStrategy = entry.strategy as? AnyLockmanStrategy<I>
      else {
        throw LockmanRegistrationError.strategyNotRegistered(id.value)
      }
      return anyStrategy
    }
  }

  /// Resolves a registered strategy by its concrete type.
  ///
  /// Convenience method that uses the type to generate the ID.
  /// Useful for built-in strategies registered without custom IDs.
  ///
  /// - Parameter strategyType: The concrete strategy type to look up
  /// - Returns: An `AnyLockmanStrategy<I>` wrapping the registered strategy instance
  /// - Throws: `LockmanError.strategyNotRegistered` if no strategy of this type is registered
  ///
  /// ## Example
  /// ```swift
  /// let strategy = try container.resolve(LockmanSingleExecutionStrategy.self)
  /// ```
  public func resolve<S: LockmanStrategy>(_ strategyType: S.Type) throws -> AnyLockmanStrategy<S.I>
  {
    let id = LockmanStrategyId(type: strategyType)
    return try resolve(id: id, expecting: S.I.self)
  }

  // MARK: - Strategy Information

  /// Checks if a strategy with the specified ID is registered.
  ///
  /// - Parameter id: The strategy ID to check
  /// - Returns: `true` if the strategy is registered, `false` otherwise
  ///
  /// ## Complexity
  /// O(1) - Direct hash map existence check
  public func isRegistered(id: LockmanStrategyId) -> Bool {
    storage.withCriticalRegion { storage in
      storage[id] != nil
    }
  }

  /// Checks if a strategy of the specified type is registered.
  ///
  /// Convenience method that checks using the type-based ID.
  ///
  /// - Parameter strategyType: The strategy type to check
  /// - Returns: `true` if the strategy is registered, `false` otherwise
  public func isRegistered<S: LockmanStrategy>(_ strategyType: S.Type) -> Bool {
    let id = LockmanStrategyId(type: strategyType)
    return isRegistered(id: id)
  }

  /// Returns the IDs of all registered strategies.
  ///
  /// Useful for debugging, monitoring, and validation purposes.
  ///
  /// - Returns: Array of strategy IDs in registration order
  ///
  /// ## Complexity
  /// O(n log n) where n is the number of registered strategies (due to sorting)
  public func registeredStrategyIds() -> [LockmanStrategyId] {
    storage.withCriticalRegion { storage in
      storage.keys.map { $0 }
        .sorted { $0.value < $1.value }
    }
  }

  /// Returns detailed information about all registered strategies.
  ///
  /// - Returns: Array of tuples containing (id, typeName, registeredAt) in registration order
  ///
  /// ## Complexity
  /// O(n log n) where n is the number of registered strategies
  public func registeredStrategyInfo() -> [(
    id: LockmanStrategyId, typeName: String, registeredAt: Date
  )] {
    storage.withCriticalRegion { storage in
      storage.map { id, entry in
        (id: id, typeName: entry.typeName, registeredAt: entry.registeredAt)
      }
      .sorted { $0.registeredAt < $1.registeredAt }
    }
  }

  /// Returns the total number of registered strategies.
  ///
  /// - Returns: Count of registered strategies
  ///
  /// ## Complexity
  /// O(1) - Direct count access
  public func strategyCount() -> Int {
    storage.withCriticalRegion { storage in
      storage.count
    }
  }

  /// Returns all registered strategies for debugging purposes.
  ///
  /// This method provides access to all registered strategies as type-erased instances.
  /// Since strategies can have different info types, they are returned as `Any` type.
  /// Use this method carefully and only for debugging/inspection purposes.
  ///
  /// - Returns: Dictionary mapping strategy IDs to their type-erased instances
  ///
  /// ## Complexity
  /// O(n) where n is the number of registered strategies
  @_spi(Debugging)
  public func getAllStrategies() -> [(LockmanStrategyId, any LockmanStrategy)] {
    storage.withCriticalRegion { storage in
      storage.compactMap { id, entry in
        // Since we store AnyLockmanStrategy<some I> as Any, we need to cast it back
        // We don't know the specific I type, so we return it as existential
        if let strategy = entry.strategy as? any LockmanStrategy {
          return (id, strategy)
        }
        return nil
      }
    }
  }

  // MARK: - Cleanup Operations

  /// Invokes `cleanUp()` on all registered strategies.
  ///
  /// This method iterates through all registered strategies and calls their
  /// `cleanUp()` method to clear any internal state. Useful for application
  /// shutdown or global reset scenarios.
  ///
  /// ## Error Handling
  /// If any strategy's cleanup operation fails, the error is logged but
  /// cleanup continues for remaining strategies to ensure best-effort cleanup.
  ///
  /// ## Complexity
  /// O(n) where n is the number of registered strategies
  public func cleanUp() {
    storage.withCriticalRegion { storage in
      for (_, entry) in storage {
        entry.cleanUp()
      }
    }
  }

  /// Invokes `cleanUp(id:)` on all registered strategies for a specific boundary.
  ///
  /// This method iterates through all registered strategies and calls their
  /// `cleanUp(id:)` method to clear state associated with the given boundary identifier.
  /// Useful when a feature or component is being deallocated.
  ///
  /// - Parameter id: The `LockmanBoundaryId` whose associated lock state should be cleared
  ///
  /// ## Error Handling
  /// Similar to `cleanUp()`, errors in individual strategy cleanup are logged
  /// but don't prevent cleanup of other strategies.
  ///
  /// ## Complexity
  /// O(n) where n is the number of registered strategies
  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    storage.withCriticalRegion { storage in
      for (_, entry) in storage {
        entry.cleanUpById(id)
      }
    }
  }

  // MARK: - Container Management

  /// Removes a specific strategy from the container by its ID.
  ///
  /// This method allows unregistering a strategy that is no longer needed.
  /// The strategy's cleanup method is called before removal.
  ///
  /// - Parameter id: The strategy ID to unregister
  /// - Returns: `true` if the strategy was found and removed, `false` if it wasn't registered
  ///
  /// ## Use Cases
  /// - Dynamic strategy replacement
  /// - Memory management in long-running applications
  /// - Test cleanup
  ///
  /// ## Example
  /// ```swift
  /// let wasRemoved = container.unregister(id: "MyApp.Custom:v1")
  /// if wasRemoved {
  ///   print("Strategy successfully unregistered")
  /// }
  /// ```
  @discardableResult
  public func unregister(id: LockmanStrategyId) -> Bool {
    storage.withCriticalRegion { storage in
      guard let entry = storage.removeValue(forKey: id) else {
        return false
      }
      entry.cleanUp()
      return true
    }
  }

  /// Removes a specific strategy type from the container.
  ///
  /// Convenience method that uses the type to generate the ID.
  ///
  /// - Parameter strategyType: The strategy type to unregister
  /// - Returns: `true` if the strategy was found and removed, `false` if it wasn't registered
  @discardableResult
  public func unregister<S: LockmanStrategy>(_ strategyType: S.Type) -> Bool {
    let id = LockmanStrategyId(type: strategyType)
    return unregister(id: id)
  }

  /// Removes all registered strategies from the container.
  ///
  /// This method calls `cleanUp()` on all strategies before removing them,
  /// ensuring proper cleanup. The container returns to its initial empty state.
  ///
  /// ## Use Cases
  /// - Application shutdown
  /// - Test suite reset
  /// - Memory management
  ///
  /// ## Complexity
  /// O(n) where n is the number of registered strategies
  public func removeAllStrategies() {
    storage.withCriticalRegion { storage in
      // Clean up all strategies first
      for (_, entry) in storage {
        entry.cleanUp()
      }

      // Clear the storage
      storage.removeAll(keepingCapacity: true)
    }
  }
}
