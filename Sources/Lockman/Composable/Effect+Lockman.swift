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
    return buildEffect(
      concatenating: operations,
      unlockOption: unlockOption,
      handleCancellationErrors: handleCancellationErrors,
      lockFailure: lockFailure,
      action: action,
      boundaryId: boundaryId,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
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
    // This is essentially a wrapper around buildEffect
    // that provides a method chain style API

    return Effect.buildEffect(
      concatenating: [self],
      unlockOption: unlockOption,
      handleCancellationErrors: handleCancellationErrors,
      lockFailure: lockFailure,
      action: action,
      boundaryId: boundaryId,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )
  }
}

// MARK: - Internal Implementation

extension Effect {
  /// Builds an effect with lock management for concatenated operations.
  ///
  /// This method contains the shared logic for both public lock APIs:
  /// - `Effect.lock(concatenating:)` for multiple operations
  /// - `Effect.lock(action:boundaryId:)` for single effect chains
  ///
  /// ## Shared Logic
  /// 1. **Strategy Resolution**: Resolves the lock strategy from the container
  /// 2. **Unlock Token Creation**: Creates unlock token with proper configuration
  /// 3. **Lock Acquisition**: Attempts to acquire the lock using the resolved strategy
  /// 4. **Effect Building**: Constructs the final effect based on lock acquisition result
  ///
  /// - Parameters:
  ///   - operations: Array of effects to execute sequentially while lock is held
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - fileID: Source file ID for debugging
  ///   - filePath: Source file path for debugging
  ///   - line: Source line number for debugging
  ///   - column: Source column number for debugging
  /// - Returns: Effect with lock management, or `.none` if lock acquisition fails
  private static func buildEffect<B: LockmanBoundaryId, A: LockmanAction>(
    concatenating operations: [Effect<Action>],
    unlockOption: LockmanUnlockOption?,
    handleCancellationErrors: Bool?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    action: A,
    boundaryId: B,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) -> Effect<Action> {
    return buildLockEffect(
      action: action,
      boundaryId: boundaryId,
      unlockOption: unlockOption ?? action.unlockOption,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column,
      handler: lockFailure
    ) { unlockToken in
      // Create auto-unlock manager for guaranteed cleanup
      let autoUnlock = LockmanAutoUnlock<B, A.I>(unlockToken: unlockToken)

      // Create unlock effect that will be executed last
      let unlockEffect = Effect<Action>.run { _ in
        await autoUnlock.manualUnlock()  // Uses the configured option
      }

      // Build the complete effect sequence with proper cancellation scope
      // Only operations are cancellable - unlockEffect must always execute
      return Effect<Action>.concatenate([
        .concatenate(operations).cancellable(id: boundaryId),  // Only operations are cancellable
        unlockEffect,  // Resource cleanup always executes (not cancellable)
      ])
    }
  }
}
