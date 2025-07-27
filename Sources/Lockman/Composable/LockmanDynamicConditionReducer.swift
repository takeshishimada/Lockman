import CasePaths
import ComposableArchitecture
import Foundation

// MARK: - LockmanDynamicConditionReducer

/// A reducer that wraps another reducer with dynamic lock evaluation capabilities.
///
/// `LockmanDynamicConditionReducer` enables dynamic lock condition evaluation based on the current state and action,
/// allowing for fine-grained control over when locks should be acquired.
///
/// ## Overview
/// This reducer provides two levels of lock condition control:
/// - **Reducer-level**: Optional condition specified at initialization that applies to all actions
/// - **Action-level**: Optional condition specified per `lock` call for specific actions
///
/// ## Usage Examples
///
/// ### With method chain API
/// ```swift
/// var body: some ReducerOf<Self> {
///   Reduce { state, action in
///     switch action {
///     case .fetchData:
///       return self.lock(
///         state: state,
///         action: action,
///         operation: { send in
///           // Async operation
///         },
///         lockAction: FetchAction(),
///         boundaryId: CancelID.fetch
///       )
///     default:
///       return .none
///     }
///   }
///   .lock { state, action in
///     // Evaluate state to determine if lock should be acquired
///     guard state.isEnabled else {
///       return .cancel(MyError.featureDisabled)
///     }
///     return .success
///   }
/// }
/// ```
///
/// ### Combined conditions with method chain
/// ```swift
/// var body: some ReducerOf<Self> {
///   Reduce { state, action in
///     switch action {
///     case .purchase(let amount):
///       return self.lock(
///         state: state,
///         action: action,
///         operation: { send in
///           // Purchase operation
///         },
///         lockAction: PurchaseAction(),
///         boundaryId: CancelID.payment,
///         lockCondition: { state, _ in
///           // Action-level condition
///           guard state.balance >= amount else {
///             return .cancel(MyError.insufficientBalance(required: amount, available: state.balance))
///           }
///           return .success
///         }
///       )
///     default:
///       return .none
///     }
///   }
///   .lock { state, _ in
///     // Reducer-level condition
///     guard state.isLoggedIn else {
///       return .cancel(MyError.notAuthenticated)
///     }
///     return .success
///   }
/// }
/// ```
public struct LockmanDynamicConditionReducer<State: Sendable, Action: Sendable>: Reducer {
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
    // Lock evaluation happens in lock methods
    self.base.reduce(into: &state, action: action)
  }
}

// MARK: - Lock Implementation Extensions

extension LockmanDynamicConditionReducer {
  /// Executes Step 1 and Step 2: Dynamic condition evaluation for action-level and reducer-level conditions
  @usableFromInline
  func lockStep1Step2<B: LockmanBoundaryId, LA: LockmanAction>(
    state: State,
    action: Action,
    lockAction: LA,
    actionId: LockmanActionId,
    boundaryId: B,
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
        id: boundaryId,
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
      boundaryId: boundaryId
    )

    if !step1Success {
      // Step 1 failed - return without unlocking
      if let lockFailure = lockFailure, let error = step1Error {
        // Wrap the error with action context
        // The error must conform to LockmanError as per dynamic condition requirements
        let cancellationError = LockmanCancellationError(
          action: lockAction,
          boundaryId: boundaryId,
          reason: error as! any LockmanError
        )
        return .run { send in
          await lockFailure(cancellationError, send)
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
      boundaryId: boundaryId
    )

    if !step2Success {
      // Step 2 failed - unlock Step 1 if it was acquired
      unlockToken()
      if let lockFailure = lockFailure, let error = step2Error {
        // Wrap the error with action context
        // The error must conform to LockmanError as per dynamic condition requirements
        let cancellationError = LockmanCancellationError(
          action: lockAction,
          boundaryId: boundaryId,
          reason: error as! any LockmanError
        )
        return .run { send in
          await lockFailure(cancellationError, send)
        }
      }
      return .none
    }

    // Step 3: Execute the provided closure with the unlock token
    return executeStep3(unlockToken)
  }

  /// Executes Step 3: Traditional lock with automatic unlock only
  @usableFromInline
  func lockStep3<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority?,
    unlockOption: LockmanUnlockOption?,
    handleCancellationErrors: Bool?,
    action: A,
    boundaryId: B,
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

      return Effect<Action>.buildLockEffect(
        action: lockAction,
        boundaryId: boundaryId,
        unlockOption: unlockOption ?? lockAction.unlockOption,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        handler: wrappedLockFailure
      ) { step3UnlockToken in
        .run(
          priority: priority,
          operation: { send in
            defer { step3UnlockToken() }  // Step 3 lock cleanup

            // Wrap operation to ensure dynamic lock cleanup
            let wrappedOperation: @Sendable (Send<Action>) async throws -> Void = { send in
              defer { unlockToken() }  // Dynamic condition lock cleanup
              try await operation(send)
            }

            do {
              try await withTaskCancellation(id: boundaryId) {
                try await wrappedOperation(send)
              }
            } catch {
              // Error handling - both defers are already registered
              if error is CancellationError {
                let shouldHandle =
                  handleCancellationErrors ?? LockmanManager.config.handleCancellationErrors
                if shouldHandle {
                  await handler?(error, send)
                }
              } else {
                await handler?(error, send)
              }
            }
          },
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column
        )
        .cancellable(id: boundaryId)
      }
    } else {
      // Manual unlock case - No longer supported
      // All locks are now automatically managed
      assertionFailure("Manual unlock is no longer supported - all locks are automatically managed")
      return .none
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
    boundaryId: B
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
    let result = Effect<Action>.acquireLock(
      lockmanInfo: dynamicInfo,
      strategy: strategy,
      boundaryId: boundaryId
    )

    // Handle result
    switch result {
    case .cancel(let error):
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


}
