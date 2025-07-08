import ComposableArchitecture

// MARK: - Effect Extensions for Lockman Integration

extension Effect {
  // MARK: - Public Lock Operations

  /// Creates an Effect that automatically manages lock lifecycle without requiring manual unlock.
  ///
  /// Provides automatic lock management that ensures locks are always released regardless
  /// of how the operation completes (normal, exception, cancellation, early return).
  ///
  /// - Parameters:
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed (default: configuration value)
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler (default: global config)
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - fileID: Source file ID for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes under lock protection, or `.none` if lock acquisition fails
  ///
  /// ## Error Handling
  /// This method supports two types of error handlers:
  /// - `catch handler`: For errors that occur during operation execution
  /// - `lockFailure`: For lock acquisition failures
  ///
  /// Lock acquisition error types include:
  /// - `LockmanSingleExecutionCancellationError`: Single execution conflicts
  /// - `LockmanPriorityBasedCancellationError`: Priority-based preemption
  /// - `LockmanPriorityBasedBlockedError`: Priority-based blocking
  /// - `LockmanGroupCoordinationCancellationError`: Group coordination conflicts
  /// - `LockmanConcurrencyLimitedCancellationError`: Concurrency limit reached
  /// - User-defined errors from dynamic conditions
  public static func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    action: A,
    boundaryId: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Self {
    withLockCommon(
      action: action,
      boundaryId: boundaryId,
      unlockOption: unlockOption ?? action.unlockOption,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column,
      handler: lockFailure  // Use lockFailure for lock acquisition errors
    ) { unlockToken in
      .run(
        priority: priority,
        operation: { send in
          do {
            // Ensure unlock happens after operation completes successfully
            defer { unlockToken() }

            // Execute operation with cancellation support
            try await withTaskCancellation(id: boundaryId) {
              try await operation(send)
            }
          } catch {
            // Handle cancellation specially to ensure proper cleanup order
            if error is CancellationError {
              defer { unlockToken() }
              let shouldHandle =
                handleCancellationErrors ?? LockmanManager.config.handleCancellationErrors
              if shouldHandle {
                await handler?(error, send)
              }
              return
            }
            // For non-cancellation errors, let the catch block handle it
            throw error
          }
        },
        catch: { error, send in
          // Ensure unlock happens before error handler
          defer { unlockToken() }
          await handler?(error, send)
        },
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      .cancellable(id: boundaryId)
    }
  }

  /// Creates an Effect that provides manual unlock control through a callback.
  ///
  /// Gives explicit control over when the lock is released.
  ///
  /// **Warning**: The caller MUST call `unlock()` in ALL code paths to avoid
  /// permanent lock acquisition.
  ///
  ///
  /// - Parameters:
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed (default: configuration value)
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler (default: global config)
  ///   - operation: Async closure receiving `send` and `unlock` functions
  ///   - handler: Optional error handler receiving error, send, and unlock functions
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - fileID: Source file ID for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes under lock protection, or `.none` if lock acquisition fails
  ///
  /// ## Error Handling
  /// This method supports two types of error handlers:
  /// - `catch handler`: For errors that occur during operation execution (receives unlock token)
  /// - `lockFailure`: For lock acquisition failures (no unlock token available)
  public static func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    operation: @escaping @Sendable (
      _ send: Send<Action>, _ unlock: LockmanUnlock<B, A.I>
    ) async throws -> Void,
    catch handler: (
      @Sendable (
        _ error: any Error, _ send: Send<Action>,
        _ unlock: LockmanUnlock<B, A.I>
      ) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    action: A,
    boundaryId: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Self {
    // Pass the lockFailure handler to withLockCommon for lock acquisition errors
    withLockCommon(
      action: action,
      boundaryId: boundaryId,
      unlockOption: unlockOption ?? action.unlockOption,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column,
      handler: lockFailure  // Use the dedicated lock failure handler
    ) { unlockToken in
      .run(
        priority: priority,
        operation: { send in
          do {
            // Execute operation with manual unlock control
            try await withTaskCancellation(id: boundaryId) {
              try await operation(send, unlockToken)
            }
          } catch {
            // Handle cancellation with unlock token available
            if error is CancellationError {
              let shouldHandle =
                handleCancellationErrors ?? LockmanManager.config.handleCancellationErrors
              if shouldHandle {
                await handler?(error, send, unlockToken)
              }
              return
            }
            // For non-cancellation errors, let the catch block handle it
            throw error
          }
        },
        catch: { error, send in
          // Provide unlock token to error handler for cleanup
          await handler?(error, send, unlockToken)
        },
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      .cancellable(id: boundaryId)
    }
  }

  /// Creates an Effect that executes multiple operations sequentially while holding a lock.
  ///
  /// This overload of `withLock` allows multiple effects to be concatenated and executed
  /// sequentially while maintaining the same lock throughout the entire sequence.
  ///
  /// ## Purpose
  /// - **Multi-step Operations**: Complex workflows requiring multiple async steps
  /// - **Transactional Behavior**: Ensuring atomicity across multiple operations
  /// - **Resource Coordination**: Maintaining exclusive access during complex state changes
  /// - **Migration Scenarios**: Gradual transition from multiple effects to single withLock
  ///
  /// ## Lock Lifecycle
  /// 1. Lock is acquired before the first effect starts
  /// 2. Lock is held during execution of all concatenated effects
  /// 3. Lock is automatically released after all effects complete (using configured option)
  /// 4. If any effect fails, lock is still properly released
  ///
  /// Effects execute sequentially. If any fails, subsequent effects are cancelled
  /// but the unlock still executes to ensure proper cleanup.
  ///
  /// - Parameters:
  ///   - concatenating: Array of effects to execute sequentially while lock is held
  ///   - priority: Task priority for the operation (optional, used only for internal run effects)
  ///   - unlockOption: Controls when the unlock operation is executed (default: configuration value)
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler (default: global config)
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - fileID: Source file ID for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Concatenated effect with automatic lock management, or `.none` if lock acquisition fails
  public static func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    concatenating operations: [Effect<Action>],
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    action: A,
    boundaryId: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    do {
      // Resolve strategy and prepare unlock mechanism
      let strategy: AnyLockmanStrategy<A.I> = try LockmanManager.container.resolve(
        id: action.lockmanInfo.strategyId,
        expecting: A.I.self
      )
      let lockmanInfo = action.lockmanInfo
      let unlockToken = LockmanUnlock(
        id: boundaryId,
        info: lockmanInfo,
        strategy: strategy,
        unlockOption: unlockOption ?? action.unlockOption
      )

      // Create auto-unlock manager for guaranteed cleanup
      let autoUnlock = LockmanAutoUnlock<B, A.I>(unlockToken: unlockToken)

      // Create unlock effect that will be executed last
      let unlockEffect = Effect<Action>.run { _ in
        await autoUnlock.manualUnlock()  // Uses the configured option
      }

      // Build the complete effect sequence
      let builtEffect = Effect<Action>.concatenate([
        .concatenate(operations),  // Execute all provided operations
        unlockEffect,  // Ensure unlock happens last (with option)
      ])

      // Attempt to acquire lock
      let lockResult = lock(
        lockmanInfo: lockmanInfo,
        strategy: strategy,
        boundaryId: boundaryId
      )

      // Handle lock acquisition result
      switch lockResult {
      case .success:
        // Lock acquired successfully, execute effects immediately
        return builtEffect

      case .successWithPrecedingCancellation(let error):
        // Lock acquired but need to cancel existing operation first
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        if let lockFailure = lockFailure {
          return .concatenate(
            .run { send in await lockFailure(cancellationError, send) },
            .cancel(id: boundaryId),
            builtEffect
          )
        }
        return .concatenate(.cancel(id: boundaryId), builtEffect)

      case .cancel(let error):
        // Lock acquisition failed
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        if let lockFailure = lockFailure {
          return .run { send in
            await lockFailure(cancellationError, send)
          }
        }
        return .none
      @unknown default:
        return .none
      }

    } catch {
      // Handle strategy resolution or other setup errors
      handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return .none
    }
  }
}

// MARK: - Effect.lock() Method Chain API

extension Effect {
  /// Applies lock management to this effect using a method chain style.
  ///
  /// This method provides an alternative API to `withLock` that works as a method chain.
  /// The lock strategy is automatically obtained from the provided action.
  ///
  /// ## Usage
  /// ```swift
  /// return .run { send in
  ///   // async operation
  /// }
  /// .lock(action: action, boundaryId: Feature.self)
  /// ```
  ///
  /// ## Requirements
  /// - The action must implement `LockmanAction` to provide lock information
  ///
  /// - Parameters:
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - unlockOption: Controls when the unlock operation is executed (default: uses action's option)
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler (default: global config)
  ///   - lockFailure: Optional handler for lock acquisition failures
  /// - Returns: Effect with automatic lock management
  public func lock<B: LockmanBoundaryId, A: LockmanAction>(
    action: A,
    boundaryId: B,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) -> Effect<Action> {
    // This is essentially a wrapper around withLock(concatenating:)
    // that provides a method chain style API

    return Effect.withLock(
      concatenating: [self],
      priority: nil,
      unlockOption: unlockOption,
      handleCancellationErrors: handleCancellationErrors,
      lockFailure: lockFailure,
      action: action,
      boundaryId: boundaryId
    )
  }
}

// MARK: - Internal Implementation

extension Effect {
  /// Core logic that attempts to acquire a lock and builds the effect.
  ///
  /// ## Purpose
  /// This internal method contains the common logic shared by all `withLock` variants:
  /// 1. Strategy resolution from the container
  /// 2. Lock information extraction from the action
  /// 3. Unlock token creation with unlock option configuration
  /// 4. Effect building through the provided closure
  ///
  /// ## Error Handling Strategy
  /// This method uses a do-catch pattern to handle strategy resolution errors.
  /// If strategy resolution fails, it calls `handleError` to provide detailed
  /// diagnostic information and optionally calls the provided handler before
  /// returning `.none` to prevent effect execution.
  ///
  /// ## Type Safety
  /// The method maintains type safety through generic constraints:
  /// - `B: LockmanBoundaryId`: Ensures valid boundary identifier
  /// - `A: LockmanAction`: Ensures valid action with lock information
  /// - `A.I`: Preserves lock information type relationship
  ///
  /// ## Unlock Token Lifecycle
  /// The unlock token created here encapsulates:
  /// - Boundary identifier for proper isolation
  /// - Lock information for precise instance tracking
  /// - Type-erased strategy for actual unlock operations
  /// - Unlock option configuration for unlock execution
  ///
  /// - Parameters:
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for cancellation and lock boundary
  ///   - unlockOption: Unlock option configuration for when to execute the unlock
  ///   - fileID, filePath, line, column: Source location for error reporting
  ///   - effectBuilder: Closure that receives unlock token and returns built effect
  /// - Returns: Built effect, or `.none` if setup fails
  static func withLockCommon<B: LockmanBoundaryId, A: LockmanAction>(
    action: A,
    boundaryId: B,
    unlockOption: LockmanUnlockOption,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    effectBuilder: @escaping (LockmanUnlock<B, A.I>) -> Effect<Action>
  ) -> Effect<Action> {
    do {
      // Resolve the strategy from the container using strategyId
      let strategy: AnyLockmanStrategy<A.I> = try LockmanManager.container.resolve(
        id: action.lockmanInfo.strategyId,
        expecting: A.I.self
      )
      let lockmanInfo = action.lockmanInfo

      // Create unlock token for this specific lock acquisition with option
      let unlockToken = LockmanUnlock(
        id: boundaryId,
        info: lockmanInfo,
        strategy: strategy,
        unlockOption: unlockOption
      )

      // Attempt to acquire lock
      let lockResult = lock(
        lockmanInfo: lockmanInfo,
        strategy: strategy,
        boundaryId: boundaryId
      )

      // Handle lock acquisition result
      switch lockResult {
      case .success:
        // Lock acquired successfully, execute effect immediately
        return effectBuilder(unlockToken)

      case .successWithPrecedingCancellation(let error):
        // Lock acquired but need to cancel existing operation first
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        if let handler = handler {
          return .concatenate(
            .run { send in await handler(cancellationError, send) },
            .cancel(id: boundaryId),
            effectBuilder(unlockToken)
          )
        }
        return .concatenate(.cancel(id: boundaryId), effectBuilder(unlockToken))

      case .cancel(let error):
        // Lock acquisition failed
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        if let handler = handler {
          return .run { send in
            await handler(cancellationError, send)
          }
        }
        return .none
      @unknown default:
        return .none
      }

    } catch {
      // Handle and report strategy resolution errors
      handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return .none
    }
  }

  /// Attempts to acquire a lock using the provided strategy and executes the effect if successful.
  ///
  /// ## Lock Acquisition Protocol
  /// This method implements the core lock acquisition and effect execution logic:
  /// 1. **Feasibility Check**: Call `canLock` to determine if lock can be acquired
  /// 2. **Early Exit**: Return `.none` if lock acquisition is not possible
  /// 3. **Lock Acquisition**: Call `lock` to actually acquire the lock
  /// 4. **Cancellation Handling**: If existing operation needs cancellation, handle appropriately
  /// 5. **Effect Execution**: Execute the provided effect with lock held
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
  ///   - lockmanInfo: Lock information for the strategy (action ID, unique ID, etc.)
  ///   - strategy: Type-erased strategy to use for lock operations
  ///   - boundaryId: Boundary identifier for this lock and cancellation
  ///   - effect: Effect to execute if lock acquisition succeeds
  /// - Returns: Effect to execute, or `.none` if lock acquisition fails
  static func lock<B: LockmanBoundaryId, I: LockmanInfo>(
    lockmanInfo: I,
    strategy: AnyLockmanStrategy<I>,
    boundaryId: B
  ) -> LockmanResult {
    LockmanManager.withBoundaryLock(for: boundaryId) {
      // Check if lock can be acquired
      let result = strategy.canLock(
        boundaryId: boundaryId,
        info: lockmanInfo
      )

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
  static func handleError(
    error: any Error,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    // Check if the error is a known LockmanRegistrationError type
    if let error = error as? LockmanRegistrationError {
      switch error {
      case .strategyNotRegistered(let strategyType):
        reportIssue(
          "Effect.withLock strategy '\(strategyType)' not registered. Register before use.",
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )

      case .strategyAlreadyRegistered(let strategyType):
        reportIssue(
          "Effect.withLock strategy '\(strategyType)' already registered.",
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
      @unknown default:
        break
      }
    }
  }
}
