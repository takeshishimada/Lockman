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
  /// ## Lock Lifecycle & UniqueId Consistency
  /// 1. **LockmanInfo Capture**: Action's lockmanInfo is captured once at the beginning to ensure consistent uniqueId
  /// 2. **Lock Acquisition**: Lock is acquired before the first effect starts using the captured lockmanInfo
  /// 3. **Effect Execution**: Lock is held during execution of all concatenated effects
  /// 4. **Guaranteed Unlock**: Lock is automatically released after all effects complete using the same lockmanInfo instance
  /// 5. **Error Handling**: If any effect fails, lock is still properly released with matching uniqueId
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
  ///   - priority: Task priority for the operation (optional, currently unused but reserved for future use)
  ///   - unlockOption: Controls when the unlock operation is executed (default: uses action's unlockOption)
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
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    action: A,
    boundaryId: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    // Create concatenated effect from operations array
    let concatenatedEffect = Effect.concatenate(operations)

    // Delegate to the unified internal implementation
    return Effect.lock(
      reducer: { concatenatedEffect },
      action: action,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }

  /// Creates an effect that executes a single operation while holding a lock.
  ///
  /// This method provides a factory-style API for applying lock management to a single effect.
  /// It serves as a conceptually correct alternative to method chaining, maintaining proper
  /// dependency relationships where the Action defines the locking behavior rather than the Effect.
  ///
  /// ## Design Philosophy
  /// This method follows the principle that Actions should control Effects, not the reverse.
  /// By using a static factory method, we maintain clear separation of concerns:
  /// - **Action**: Defines what should be locked and how
  /// - **Effect**: Defines what work should be performed
  /// - **Factory**: Combines them with proper lock management
  ///
  /// ## Lock Lifecycle & UniqueId Consistency
  /// 1. **LockmanInfo Capture**: Action's lockmanInfo is captured once at the beginning to ensure consistent uniqueId
  /// 2. **Lock Acquisition**: Lock is acquired before the operation starts using the captured lockmanInfo
  /// 3. **Effect Execution**: Lock is held during execution of the single operation
  /// 4. **Guaranteed Unlock**: Lock is automatically released after operation completes using the same lockmanInfo instance
  /// 5. **Error Handling**: If operation fails, lock is still properly released with matching uniqueId
  ///
  /// ## Automatic Cancellation Management
  /// This method automatically applies `.cancellable(id: boundaryId)` to the operation
  /// while ensuring the unlock effect is never cancelled. This follows the
  /// "Guaranteed Resource Cleanup" principle:
  /// - **Operation is cancellable**: The operation can be cancelled via boundaryId
  /// - **Resource cleanup is guaranteed**: Unlock always executes to prevent resource leaks
  ///
  /// ## Example Usage
  /// ```swift
  /// // Single async operation with lock
  /// return Effect.lock(
  ///   operation: .run { send in
  ///     let result = await fetchUserData()
  ///     await send(.userDataLoaded(result))
  ///   },
  ///   action: action,
  ///   boundaryId: Feature.self
  /// )
  ///
  /// // Send action with lock
  /// return Effect.lock(
  ///   operation: .send(.startLoading),
  ///   action: action,
  ///   boundaryId: Feature.self
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - operation: Single effect to execute while lock is held
  ///   - unlockOption: Controls when the unlock operation is executed (default: uses action's unlockOption)
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - fileID: Source file ID for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect with automatic lock management, or `.none` if lock acquisition fails
  public static func lock<B: LockmanBoundaryId, A: LockmanAction>(
    operation: Effect<Action>,
    unlockOption: LockmanUnlockOption? = nil,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    action: A,
    boundaryId: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    // Delegate to the unified internal implementation
    return Effect.lock(
      reducer: { operation },
      action: action,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }
}
