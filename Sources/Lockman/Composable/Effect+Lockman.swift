import ComposableArchitecture

// MARK: - Effect Extensions for Lockman Integration

extension Effect {
  // MARK: - Public Lock Operations

  /// Creates an effect that executes multiple operations sequentially while holding a lock.
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
  /// Effects execute sequentially. If any effect fails, subsequent effects are cancelled,
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
      // Create concatenated effect from operations array
      let concatenatedEffect = Effect.concatenate(operations)

      let lockmanInfo = action.lockmanInfo

      // Acquire lock using the concatenated effect instance
      let lockResult = try concatenatedEffect.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )

      // Build lock effect using the same concatenated effect instance
      return concatenatedEffect.buildLockEffect(
        lockResult: lockResult,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: unlockOption ?? action.unlockOption,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        handler: lockFailure
      )
    } catch {
      // Handle and report strategy resolution errors
      Effect.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      if let lockFailure = lockFailure {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }
  }
}

// MARK: - Effect.lock() Method Chain API

extension Effect {
  /// Applies lock management to this effect using a method chain style.
  ///
  /// This method provides a method chain style API for applying lock management to effects.
  /// The lock strategy is automatically resolved from the container using the action's strategy ID.
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
    // This method provides a method chain style API by combining acquireLock and buildLockEffect

    do {
      let lockmanInfo = action.lockmanInfo

      // Acquire lock using instance method
      let lockResult = try acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )

      return buildLockEffect(
        lockResult: lockResult,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: unlockOption ?? action.unlockOption,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: lockFailure
      )
    } catch {
      // Handle and report strategy resolution errors
      Effect.handleError(
        error: error,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
      if let lockFailure = lockFailure {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }
  }

}
