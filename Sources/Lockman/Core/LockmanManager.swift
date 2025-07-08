import Foundation

// MARK: - Lockman Facade

/// A facade providing static access to the shared `LockmanStrategyContainer` and core framework functionality.
///
/// Provides centralized access to lock management with pre-configured strategies and test isolation support.
///
public enum LockmanManager {
  // MARK: - Configuration

  /// Configuration settings for Lockman behavior.
  struct Configuration: Sendable {
    /// The default unlock option to use when not explicitly specified.
    ///
    /// This value is used by all `withLock` methods
    /// when the `unlockOption` parameter is not provided.
    ///
    /// Default value is `.immediate` for immediate unlock behavior.
    var defaultUnlockOption: LockmanUnlockOption = .immediate

    /// Controls whether CancellationError should be passed to error handlers in withLock operations.
    ///
    /// When `true`, CancellationError is passed to the catch handler if provided.
    /// When `false`, CancellationError is silently ignored and not passed to handlers.
    ///
    /// Default value is `false` to silently ignore cancellation errors.
    var handleCancellationErrors: Bool = false

    /// Creates a new configuration with default values.
    init() {}
  }

  /// Thread-safe storage for the global configuration.
  private static let _configuration = ManagedCriticalState(Configuration())

  // MARK: - Config Namespace

  /// Configuration namespace for Lockman settings.
  public enum config {
    /// The default unlock option to use when not explicitly specified.
    ///
    /// This value is used by all `withLock` methods
    /// when the `unlockOption` parameter is not provided.
    ///
    /// Default value is `.immediate` for immediate unlock behavior.
    ///
    /// ```swift
    /// // In AppDelegate or App initialization
    /// // Change to immediate unlock if UI transitions are not a concern
    /// LockmanManager.config.defaultUnlockOption = .immediate
    /// ```
    public static var defaultUnlockOption: LockmanUnlockOption {
      get { _configuration.withCriticalRegion { $0.defaultUnlockOption } }
      set {
        _configuration.withCriticalRegion { $0.defaultUnlockOption = newValue }
      }
    }

    /// Controls whether CancellationError should be passed to error handlers in withLock operations.
    ///
    /// When `true`, CancellationError is passed to the catch handler if provided.
    /// When `false`, CancellationError is silently ignored and not passed to handlers.
    ///
    /// ```swift
    /// // Disable CancellationError handling globally
    /// LockmanManager.config.handleCancellationErrors = false
    /// ```
    public static var handleCancellationErrors: Bool {
      get { _configuration.withCriticalRegion { $0.handleCancellationErrors } }
      set {
        _configuration.withCriticalRegion { $0.handleCancellationErrors = newValue }
      }
    }

    /// Resets configuration to default values.
    /// Used primarily for testing to ensure clean state between tests.
    internal static func reset() {
      _configuration.withCriticalRegion { $0 = Configuration() }
    }
  }

  // MARK: - Core Implementation

  /// The shared container instance for registering and resolving lock strategies.
  ///
  /// Returns the default container in production or the task-local test container when available.
  public static var container: LockmanStrategyContainer {
    if let testContainerStorage {
      return testContainerStorage
    } else {
      return _defaultContainer
    }
  }

  /// The default container instance, lazily initialized with pre-registered strategies.
  private static let _defaultContainer: LockmanStrategyContainer = {
    let container = LockmanStrategyContainer()

    // Register essential strategies using the protocol-based approach
    do {
      try container.register(LockmanSingleExecutionStrategy.shared)
      try container.register(LockmanPriorityBasedStrategy.shared)
      try container.register(LockmanGroupCoordinationStrategy.shared)
      try container.register(LockmanConcurrencyLimitedStrategy.shared)
    } catch {
      // Registration failure is silently ignored as it's handled gracefully
    }

    return container
  }()

  // MARK: - Cleanup Namespace

  /// Cleanup operations namespace.
  public enum cleanup {
    /// Invokes global cleanup on all registered strategies.
    ///
    /// Clears all lock states across all strategies and boundaries.
    /// Useful for application shutdown, test cleanup, and development resets.
    ///
    /// ```swift
    /// // Clean up all locks
    /// LockmanManager.cleanup.all()
    /// ```
    public static func all() {
      container.cleanUp()
    }

    /// Invokes targeted cleanup for a specific boundary.
    ///
    /// Clears lock states only for the specified boundary across all strategies.
    ///
    /// ```swift
    /// // Clean up locks for a specific boundary
    /// LockmanManager.cleanup.boundary(CancelID.userAction)
    /// ```
    public static func boundary<B: LockmanBoundaryId>(_ id: B) {
      LockmanManager.withBoundaryLock(for: id) {
        container.cleanUp(boundaryId: id)
      }
    }
  }

  /// Task-local storage for test container injection.
  @TaskLocal private static var testContainerStorage: LockmanStrategyContainer?

  /// Executes the given operation with a custom container for testing purposes.
  public static func withTestContainer<T>(
    _ testContainer: LockmanStrategyContainer,
    operation: () async throws -> T
  ) async rethrows -> T {
    try await $testContainerStorage.withValue(testContainer) {
      try await operation()
    }
  }
}

// MARK: - Boundary Lock Management

extension LockmanManager {
  /// Thread-safe storage for boundary-specific locks.
  private static let boundaryLocks: ManagedCriticalState<[AnyLockmanBoundaryId: NSLock]> =
    ManagedCriticalState([:])

  /// Retrieves or creates an NSLock for the specified boundary ID.
  private static func getLock<B: LockmanBoundaryId>(for boundaryId: B) -> NSLock {
    let anyId = AnyLockmanBoundaryId(boundaryId)
    return boundaryLocks.withCriticalRegion { locks in
      if let existingLock = locks[anyId] {
        return existingLock
      } else {
        let newLock = NSLock()
        locks[anyId] = newLock
        return newLock
      }
    }
  }

  /// Executes the given operation while holding the boundary-specific lock.
  public static func withBoundaryLock<B: LockmanBoundaryId, T>(
    for boundaryId: B,
    operation: () throws -> T
  ) rethrows -> T {
    let nsLock = getLock(for: boundaryId)
    nsLock.lock()
    defer { nsLock.unlock() }
    return try operation()
  }
}
