import ComposableArchitecture

// MARK: - Effect Extensions for Lockman Integration

extension Effect {
  // MARK: - Public Lock Operations

  /// Creates an Effect that executes multiple operations sequentially while holding a lock.
  ///
  /// This method allows multiple effects to be concatenated and executed
  /// sequentially while maintaining the same lock throughout the entire sequence.
  ///
  /// ## Purpose
  /// - **Multi-step Operations**: Complex workflows requiring multiple async steps
  /// - **Transactional Behavior**: Ensuring atomicity across multiple operations
  /// - **Resource Coordination**: Maintaining exclusive access during complex state changes
  /// - **Migration Scenarios**: Gradual transition from multiple effects to single concatenated operation
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
  /// ## Automatic Cancellation Management
  /// This method automatically applies `.cancellable(id: boundaryId)` to the concatenated
  /// operations while ensuring the unlock effect is never cancelled. This follows the
  /// "Guaranteed Resource Cleanup" principle:
  /// - **Operations are cancellable**: All concatenated effects can be cancelled as a group
  /// - **Resource cleanup is guaranteed**: Unlock always executes to prevent resource leaks
  ///
  /// ## Example Usage
  /// ```swift
  /// return Effect.lock(
  ///   concatenating: [
  ///     .send(.stepOne),
  ///     .send(.stepTwo),
  ///     .run { send in await performAsyncWork(send) }
  ///   ],
  ///   action: action,
  ///   boundaryId: boundaryId
  /// )
  /// // All operations are automatically cancellable with boundaryId
  /// // No manual .cancellable(id:) specification required
  /// ```
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
  public static func lock<B: LockmanBoundaryId, A: LockmanAction>(
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

      // Build the complete effect sequence with proper cancellation scope
      // Only operations are cancellable - unlockEffect must always execute
      let builtEffect = Effect<Action>.concatenate([
        .concatenate(operations).cancellable(id: boundaryId),  // Only operations are cancellable
        unlockEffect,  // Resource cleanup always executes (not cancellable)
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
  /// This method provides a method chain style API for applying lock management to effects.
  /// The lock strategy is automatically obtained from the provided action.
  ///
  /// ## Automatic Cancellation Management
  /// This method automatically applies `.cancellable(id: boundaryId)` to the chained effect,
  /// eliminating the need to manually specify cancellation IDs. This provides a clean,
  /// method-chain style API with automatic cancellation handling.
  ///
  /// ## Usage Examples
  /// ```swift
  /// // Simple operation with automatic cancellation
  /// return .run { send in
  ///   await performAsyncWork()
  ///   await send(.completed)
  /// }
  /// .lock(action: action, boundaryId: Feature.self)
  /// // No need for .cancellable(id:) - applied automatically
  ///
  /// // Method chaining with other effects
  /// return .merge(
  ///   .run { send in await send(.started) },
  ///   .run { send in
  ///     await performWork()
  ///     await send(.finished)
  ///   }
  ///   .lock(action: action, boundaryId: MyFeature.self)
  /// )
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
    // This is essentially a wrapper around lock(concatenating:)
    // that provides a method chain style API

    return Effect.lock(
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

      // Handle immediate unlock for preceding cancellation
      if case .successWithPrecedingCancellation(let cancellationError) = result {
        // Immediately unlock the cancelled action to prevent resource leaks
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
          "Effect.lock strategy '\(strategyType)' not registered. Register before use.",
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )

      case .strategyAlreadyRegistered(let strategyType):
        reportIssue(
          "Effect.lock strategy '\(strategyType)' already registered.",
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
