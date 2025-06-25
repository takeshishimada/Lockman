import ComposableArchitecture
import Foundation

/// A reducer that wraps another reducer with dynamic lock evaluation capabilities.
///
/// `ReduceWithLock` enables dynamic lock condition evaluation based on the current state and action,
/// allowing for fine-grained control over when locks should be acquired.
///
/// ## Overview
/// This reducer provides two levels of lock condition control:
/// - **Reducer-level**: Optional condition specified at initialization that applies to all actions
/// - **Action-level**: Optional condition specified per `withLock` call for specific actions
///
/// ## Usage Examples
///
/// ### Reducer-level condition
/// ```swift
/// ReduceWithLock { state, action in
///   switch action {
///   case .fetchData:
///     return self.withLock(
///       state: state,
///       action: action,
///       operation: { send in
///         // Async operation
///       },
///       lockAction: LockmanSingleExecutionAction(actionName: "fetch"),
///       cancelID: CancelID()
///     )
///   default:
///     return .none
///   }
/// } lockCondition: { state, action in
///   // Evaluate state to determine if lock should be acquired
///   guard state.isEnabled else {
///     return .failure(LockmanDynamicConditionError.conditionNotMet(actionId: "fetch", hint: "Not enabled"))
///   }
///   return .success
/// }
/// ```
///
/// ### Combined conditions
/// ```swift
/// ReduceWithLock { state, action in
///   switch action {
///   case .purchase(let amount):
///     return self.withLock(
///       state: state,
///       action: action,
///       operation: { send in
///         // Purchase operation
///       },
///       lockAction: LockmanSingleExecutionAction(actionName: "purchase"),
///       cancelID: CancelID(),
///       lockCondition: { state, _ in
///         // Action-level condition
///         guard state.balance >= amount else {
///           return .failure(LockmanDynamicConditionError.conditionNotMet(actionId: "purchase", hint: "Insufficient balance"))
///         }
///         return .success
///       }
///     )
///   default:
///     return .none
///   }
/// } lockCondition: { state, _ in
///   // Reducer-level condition
///   guard state.isLoggedIn else {
///     return .failure(LockmanDynamicConditionError.conditionNotMet(actionId: "auth", hint: "Not logged in"))
///   }
///   return .success
/// }
/// ```
public struct ReduceWithLock<State: Sendable, Action: Sendable>: Reducer {
  @usableFromInline
  internal let _base: Reduce<State, Action>

  /// The lock condition that will be evaluated for all actions in this reducer.
  /// This is made internal to allow the extension methods to access it.
  @usableFromInline
  internal let _lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?

  @usableFromInline
  var base: Reduce<State, Action> { _base }

  @usableFromInline
  var lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? {
    _lockCondition
  }

  /// Initializes a reducer with optional lock condition evaluation.
  ///
  /// - Parameters:
  ///   - reduce: The base reducer function to be executed.
  ///   - lockCondition: Optional function that evaluates the current state and action
  ///                    to determine if a lock should be acquired. If nil, no reducer-level
  ///                    condition is applied.
  public init(
    _ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil
  ) {
    self._base = Reduce { state, action in
      reduce(&state, action)
    }
    self._lockCondition = lockCondition
  }

  /// Initializes with an existing Reduce instance.
  ///
  /// - Parameters:
  ///   - base: An existing Reduce instance.
  ///   - lockCondition: Optional function that evaluates the current state and action
  ///                    to determine if a lock should be acquired.
  public init(
    base: Reduce<State, Action>,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil
  ) {
    self._base = base
    self._lockCondition = lockCondition
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    // Simply execute the base reducer
    // Lock evaluation happens in withLock methods
    self.base.reduce(into: &state, action: action)
  }
}

// MARK: - WithLock Extensions

extension ReduceWithLock {
  /// Executes Step 1 and Step 2: Dynamic condition evaluation for action-level and reducer-level conditions
  @usableFromInline
  func withLockStep1Step2<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    actionId: LockmanActionId,
    cancelID: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    reducerCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    executeStep3: (LockmanUnlock<B, LockmanDynamicConditionInfo>) -> Effect<Action>
  ) -> Effect<Action> {
    // Create dynamic strategy and unlock token first
    let strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>
    let unlockToken: LockmanUnlock<B, LockmanDynamicConditionInfo>
    do {
      strategy = try LockmanManager.container.resolve(
        id: .dynamicCondition,
        expecting: LockmanDynamicConditionInfo.self
      )
      // Create unlock token inline
      unlockToken = LockmanUnlock(
        id: cancelID,
        info: LockmanDynamicConditionInfo(actionId: actionId),
        strategy: strategy,
        unlockOption: .immediate
      )
    } catch {
      // If we can't create unlock token, report error
      Effect<Action>.handleError(
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

    // Step 1: Action-level dynamic condition (if provided)
    let (step1Success, step1Error) = lock(
      state: state,
      action: action,
      condition: lockCondition,
      strategy: strategy,
      actionId: actionId,
      cancelID: cancelID
    )

    if !step1Success {
      // Step 1 failed - return without unlocking
      if let lockFailure = lockFailure, let error = step1Error {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }

    // Step 2: Reducer-level dynamic condition (if exists)
    let (step2Success, step2Error) = lock(
      state: state,
      action: action,
      condition: reducerCondition,
      strategy: strategy,
      actionId: actionId,
      cancelID: cancelID
    )

    if !step2Success {
      // Step 2 failed - unlock Step 1 if it was acquired
      unlockToken()
      if let lockFailure = lockFailure, let error = step2Error {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }

    // Step 3: Execute the provided closure with the unlock token
    return executeStep3(unlockToken)
  }

  /// Executes Step 3: Traditional withLock (automatic or manual unlock)
  @usableFromInline
  func withLockStep3<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority?,
    unlockOption: UnlockOption?,
    handleCancellationErrors: Bool?,
    action: A,
    cancelID: B,
    unlockToken: LockmanUnlock<B, LockmanDynamicConditionInfo>,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    automaticUnlock: Bool,
    operation: Any,
    handler: Any?
  ) -> Effect<Action> {
    // Wrap the lockFailure handler to clean up dynamic locks if step 3 fails
    let wrappedLockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void) = {
      error, send in
      // Clean up all dynamic condition locks if step 3 lock acquisition fails
      unlockToken()

      // Call original handler if provided
      if let lockFailure = lockFailure {
        await lockFailure(error, send)
      }
    }

    let lockAction = action

    if automaticUnlock {
      // Automatic unlock case
      let operation = operation as! @Sendable (Send<Action>) async throws -> Void
      let handler = handler as? @Sendable (any Error, Send<Action>) async -> Void

      // Create wrapped operation that cleans up dynamic locks after completion
      let wrappedOperation: @Sendable (Send<Action>) async throws -> Void = { send in
        defer {
          // Clean up dynamic locks after operation completes (success or failure)
          unlockToken()
        }
        try await operation(send)
      }

      return Effect<Action>.withLock(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        operation: wrappedOperation,
        catch: handler,
        lockFailure: wrappedLockFailure,
        action: lockAction,
        cancelID: cancelID,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    } else {
      // Manual unlock case
      let operation =
        operation as! @Sendable (Send<Action>, LockmanUnlock<B, A.I>) async throws -> Void
      let handler =
        handler as? @Sendable (any Error, Send<Action>, LockmanUnlock<B, A.I>) async -> Void

      // Create wrapped operation that manages dynamic locks and provides manual unlock
      let wrappedOperation: @Sendable (Send<Action>, LockmanUnlock<B, A.I>) async throws -> Void = {
        send, unlock in
        do {
          try await operation(send, unlock)
          // Clean up dynamic locks after successful operation
          unlockToken()
        } catch {
          // Clean up dynamic locks on error
          unlockToken()
          throw error
        }
      }

      return Effect<Action>.withLock(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        operation: wrappedOperation,
        catch: handler,
        lockFailure: wrappedLockFailure,
        action: lockAction,
        cancelID: cancelID,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }
  }

  /// Helper function to evaluate a dynamic condition and acquire lock if successful
  @usableFromInline
  func lock<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    condition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionId: LockmanActionId,
    cancelID: B
  ) -> (success: Bool, error: (any Error)?) {
    // If no condition provided, consider it successful
    guard let condition = condition else {
      return (true, nil)
    }

    // Create dynamic condition info
    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: actionId,
      condition: { condition(state, action) }
    )

    // Check condition and acquire lock if successful
    let result = Effect<Action>.lock(
      lockmanInfo: dynamicInfo,
      strategy: strategy,
      cancelID: cancelID
    )

    // Handle result
    switch result {
    case .failure(let error):
      return (false, error)
    case .successWithPrecedingCancellation(let error):
      // Lock acquired but with preceding cancellation - return success with error
      return (true, error)
    case .success:
      return (true, nil)
    @unknown default:
      return (true, nil)
    }
  }

  /// Creates an effect with automatic lock management and dynamic condition evaluation.
  ///
  /// This method implements a multi-stage locking mechanism:
  /// 1. Action-level condition (if specified in this call)
  /// 2. Reducer-level condition (if specified at initialization)
  /// 3. Traditional lock strategy (specified by lockAction)
  ///
  /// All conditions must pass for the operation to execute. Locks are automatically
  /// released when the operation completes.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - lockAction: LockmanAction providing lock information and strategy type
  ///   - cancelID: Unique identifier for effect cancellation and lock boundary
  ///   - lockCondition: Optional action-level condition that supplements the reducer-level condition
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate locking based on all conditions
  public func withLock<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    unlockOption: UnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockAction: some LockmanAction,
    cancelID: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    let actionId = lockAction.lockmanInfo.actionId
    // Capture the reducer-level condition to avoid type inference issues
    let reducerLevelCondition = self.lockCondition

    return withLockStep1Step2(
      state: state,
      action: action,
      actionId: actionId,
      cancelID: cancelID,
      lockCondition: lockCondition,
      reducerCondition: reducerLevelCondition,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    ) { unlockToken in
      // Step 3: Traditional withLock using the specified strategy
      return withLockStep3(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        action: lockAction,
        cancelID: cancelID,
        unlockToken: unlockToken,
        lockFailure: lockFailure,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        automaticUnlock: true,
        operation: operation,
        handler: handler
      )
    }
  }

  /// Creates an effect with manual unlock control and dynamic condition evaluation.
  ///
  /// This method provides explicit control over when locks are released, giving you
  /// flexibility for complex scenarios where automatic unlock isn't sufficient.
  ///
  /// **Warning**: The caller MUST call `unlock()` in ALL code paths to avoid
  /// permanent lock acquisition. Consider using the automatic version unless you
  /// specifically need manual control.
  ///
  /// This method implements a multi-stage locking mechanism:
  /// 1. Action-level condition (if specified in this call)
  /// 2. Reducer-level condition (if specified at initialization)
  /// 3. Traditional lock strategy (specified by lockAction)
  ///
  /// All conditions must pass for the operation to execute. Once passed, the final
  /// unlock token is provided to the operation and error handlers.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler
  ///   - operation: Async closure receiving `send` and `unlock` functions
  ///   - handler: Optional error handler receiving error, send, and unlock functions
  ///   - lockFailure: Optional handler for lock acquisition failures (no unlock token)
  ///   - lockAction: LockmanAction providing lock information and strategy type
  ///   - cancelID: Unique identifier for effect cancellation and lock boundary
  ///   - lockCondition: Optional action-level condition that supplements the reducer-level condition
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate locking based on all conditions
  public func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    unlockOption: UnlockOption? = nil,
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
    lockAction: A,
    cancelID: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    let actionId = lockAction.lockmanInfo.actionId
    // Capture the reducer-level condition to avoid type inference issues
    let reducerLevelCondition = self.lockCondition

    return withLockStep1Step2(
      state: state,
      action: action,
      actionId: actionId,
      cancelID: cancelID,
      lockCondition: lockCondition,
      reducerCondition: reducerLevelCondition,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    ) { unlockToken in
      // Step 3: Traditional withLock using the specified strategy with manual unlock
      return withLockStep3(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        action: lockAction,
        cancelID: cancelID,
        unlockToken: unlockToken,
        lockFailure: lockFailure,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        automaticUnlock: false,
        operation: operation,
        handler: handler
      )
    }
  }
}
