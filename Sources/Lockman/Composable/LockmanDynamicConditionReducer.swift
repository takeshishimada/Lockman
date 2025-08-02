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

  /// Initializes the reducer with an existing Reduce instance.
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

// MARK: - Main Lock Method

extension LockmanDynamicConditionReducer {
  /// Creates an effect with automatic lock management and dynamic condition evaluation.
  ///
  /// This method implements a Pure Dynamic Condition architecture with two-stage evaluation:
  /// 1. Reducer-level condition (if specified at initialization)
  /// 2. Action-level condition (if specified in this call)
  ///
  /// Both conditions must pass for the operation to execute. Dynamic condition locks are automatically
  /// released when the operation completes.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the dynamic condition unlock operation is executed (defaults to .immediate)
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for dynamic condition lock acquisition failures
  ///   - lockAction: LockmanAction providing action information (not used for lock strategy in Pure Dynamic Condition mode)
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - lockCondition: Optional action-level condition that supplements the reducer-level condition
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate locking based on all conditions
  public func lock<B: LockmanBoundaryId, LA: LockmanAction>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockAction: LA,
    boundaryId: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    let lockmanInfo = lockAction.lockmanInfo
    let actionId = lockmanInfo.actionId
    let dynamicLockCondition = self.lockCondition

    // Step 1: Resolve strategies
    let dynamicStrategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>
    let actionStrategy: AnyLockmanStrategy<LA.I>
    do {
      dynamicStrategy = try LockmanManager.container.resolve(
        id: .dynamicCondition,
        expecting: LockmanDynamicConditionInfo.self
      )
      actionStrategy = try LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: LA.I.self
      )
    } catch {
      // Failed to resolve strategies (configuration error)
      Effect<Action>.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return .none
    }

    // Step 2: Evaluate conditions (dynamic lock condition and lock call)
    let conditionResult = evaluateConditions(
      dynamicLockCondition: dynamicLockCondition,
      lockCondition: lockCondition,
      state: state,
      action: action,
      dynamicStrategy: dynamicStrategy,
      actionStrategy: actionStrategy,
      lockmanInfo: lockmanInfo,
      lockmanAction: lockAction,
      actionId: actionId,
      boundaryId: boundaryId
    )

    // Step 3: Build effect and handle condition evaluation result
    return buildLockEffect(
      conditionResult: conditionResult,
      dynamicStrategy: dynamicStrategy,
      actionStrategy: actionStrategy,
      actionId: actionId,
      unlockOption: unlockOption ?? .immediate,
      lockmanInfo: lockmanInfo,
      lockAction: lockAction,
      boundaryId: boundaryId,
      priority: priority,
      operation: operation,
      handler: handler,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )
  }
}
