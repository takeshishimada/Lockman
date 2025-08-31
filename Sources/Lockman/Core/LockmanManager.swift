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
    /// This value is used by all lock methods
    /// when the `unlockOption` parameter is not provided.
    ///
    /// Default value is `.immediate` for immediate unlock behavior.
    var defaultUnlockOption: LockmanUnlockOption = .immediate

    /// Controls whether CancellationError should be passed to error handlers in lock operations.
    ///
    /// When `true`, CancellationError is passed to the catch handler if provided.
    /// When `false`, CancellationError is silently ignored and not passed to handlers.
    ///
    /// Default value is `false` to silently ignore cancellation errors.
    var handleCancellationErrors: Bool = false

    /// The issue reporter to use for reporting diagnostic messages.
    ///
    /// This reporter is used throughout the framework for error reporting and diagnostics.
    /// Can be customized for different environments or testing scenarios.
    ///
    /// Default value is `LockmanDefaultIssueReporter` for console output in debug builds.
    var issueReporter: any LockmanIssueReporter.Type = LockmanDefaultIssueReporter.self

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
    /// This value is used by all lock methods
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

    /// Controls whether CancellationError should be passed to error handlers in lock operations.
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

    /// The issue reporter to use for reporting diagnostic messages.
    ///
    /// This reporter is used throughout the framework for error reporting and diagnostics.
    /// Can be customized for different environments or testing scenarios.
    ///
    /// ```swift
    /// // Set custom issue reporter
    /// LockmanManager.config.issueReporter = LockmanComposableIssueReporter.self
    /// ```
    public static var issueReporter: any LockmanIssueReporter.Type {
      get { _configuration.withCriticalRegion { $0.issueReporter } }
      set {
        _configuration.withCriticalRegion { $0.issueReporter = newValue }
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

// MARK: - Core Lock Operations (TCA-Independent)

extension LockmanManager {
  /// Handles errors that occur during lock operations and provides appropriate diagnostic messages.
  ///
  /// ## Error Analysis and Reporting
  /// This method examines the error type and generates context-aware diagnostic messages
  /// that help developers identify and resolve issues with lock management operations.
  /// The diagnostics include:
  /// - **Source Location**: Exact file, line, and column where error occurred
  /// - **Error Context**: Specific action type and strategy type involved
  /// - **Resolution Guidance**: Concrete steps to fix the issue
  /// - **Code Examples**: Sample code showing correct usage
  ///
  /// ## Supported Error Types
  /// Currently handles `LockmanError` types with specific guidance:
  /// - **Strategy Not Registered**: Provides registration example
  /// - **Strategy Already Registered**: Explains registration constraints
  /// - **Future Extensions**: Framework for additional error types
  ///
  /// ## Development vs Production
  /// In development builds, detailed diagnostics are provided to help developers
  /// identify and fix issues quickly. In production, error handling is minimal
  /// to avoid exposing internal details.
  ///
  /// ## Integration with Xcode
  /// The `reportIssue` function integrates with Xcode's issue navigator,
  /// providing clickable error messages that jump directly to the problematic code.
  ///
  /// - Parameters:
  ///   - error: Error that was thrown during lock operation
  ///   - fileID: File identifier where error originated (auto-populated)
  ///   - filePath: Full file path where error originated (auto-populated)
  ///   - line: Line number where error originated (auto-populated)
  ///   - column: Column number where error originated (auto-populated)
  ///   - reporter: Issue reporter to use (defaults to LockmanManager.config.issueReporter)
  public static func handleError(
    error: any Error,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column,
    reporter: any LockmanIssueReporter.Type = LockmanManager.config.issueReporter
  ) {
    // Check if the error is a known LockmanRegistrationError type
    if let error = error as? LockmanRegistrationError {
      switch error {
      case .strategyNotRegistered(let strategyType):
        reporter.reportIssue(
          "Lockman strategy '\(strategyType)' not registered. Register before use.",
          file: fileID,
          line: line
        )

      case .strategyAlreadyRegistered(let strategyType):
        reporter.reportIssue(
          "Lockman strategy '\(strategyType)' already registered.",
          file: fileID,
          line: line
        )
      @unknown default:
        break
      }
    }
  }

  /// Attempts to acquire a lock using pre-captured lockmanInfo for consistent uniqueId handling.
  ///
  /// ## Lock Acquisition Protocol with UniqueId Consistency
  /// This method implements the core lock acquisition logic with guaranteed uniqueId consistency:
  /// 1. **Pre-captured LockmanInfo**: Uses lockmanInfo captured once at entry points
  /// 2. **Feasibility Check**: Call `canLock` to determine if lock can be acquired
  /// 3. **Early Exit**: Return appropriate result if lock acquisition is not possible
  /// 4. **Lock Acquisition**: Call `lock` to actually acquire the lock
  /// 5. **Consistent UniqueId**: Same lockmanInfo instance ensures unlock will succeed
  ///
  /// ## Boundary Lock Protection
  /// The entire lock acquisition process is protected by a boundary-specific lock
  /// to ensure atomicity and prevent race conditions between:
  /// - Multiple lock acquisition attempts
  /// - Lock acquisition and release operations
  /// - Cleanup and acquisition operations
  ///
  /// ## Cancellation Strategy
  /// When `canLock` returns `.successWithPrecedingCancellation`:
  /// 1. A cancellation effect is created for the specified boundaryId
  /// 2. The cancellation effect is concatenated BEFORE the main effect
  /// 3. This ensures proper ordering: cancel existing → execute new
  ///
  /// ## Performance Notes
  /// - Lock feasibility check is typically O(1) hash lookup
  /// - Boundary lock acquisition is brief (microseconds)
  /// - Effect concatenation has minimal overhead
  ///
  /// - Parameters:
  ///   - lockmanInfo: Pre-captured lock information ensuring consistent uniqueId throughout lifecycle
  ///   - boundaryId: Boundary identifier for this lock and cancellation
  /// - Returns: LockmanResult indicating lock acquisition status
  public static func acquireLock<B: LockmanBoundaryId, I: LockmanInfo>(
    lockmanInfo: I,
    boundaryId: B
  ) throws -> LockmanResult {
    // Resolve the strategy from the container using lockmanInfo.strategyId
    let strategy: AnyLockmanStrategy<I> = try LockmanManager.container.resolve(
      id: lockmanInfo.strategyId,
      expecting: I.self
    )

    // Acquire lock with boundary protection
    return LockmanManager.withBoundaryLock(for: boundaryId) {
      // Check if lock can be acquired
      let result = strategy.canLock(
        boundaryId: boundaryId,
        info: lockmanInfo
      )

      // Handle immediate unlock for preceding cancellation
      if case .successWithPrecedingCancellation(let cancellationError) = result {
        // Immediately unlock the cancelled action to prevent resource leaks
        // Only unlock if the cancelled action has compatible lock info type
        if let cancelledInfo = cancellationError.lockmanInfo as? I {
          strategy.unlock(boundaryId: cancellationError.boundaryId, info: cancelledInfo)
        }
      }

      // Early exit if lock cannot be acquired
      if case .cancel = result {
        return result
      }

      // Actually acquire the lock
      strategy.lock(
        boundaryId: boundaryId,
        info: lockmanInfo
      )

      // Return the result
      return result
    }
  }
}
