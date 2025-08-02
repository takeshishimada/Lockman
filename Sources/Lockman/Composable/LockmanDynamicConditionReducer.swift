import CasePaths
import ComposableArchitecture
import Foundation

// MARK: - LockmanDynamicConditionReducer

/// A reducer that wraps another reducer with dynamic condition evaluation capabilities.
///
/// `LockmanDynamicConditionReducer` provides unified condition evaluation for both
/// reducer-level and action-level exclusive processing with simplified API.
///
/// ## Overview
/// This reducer provides two independent levels of exclusive processing:
/// - **Reducer-level**: Automatic condition evaluation for all actions in the reducer
/// - **Action-level**: Individual lock method calls with their own conditions
///
/// Both levels use the same simple pattern: condition evaluation + cancellable effect control.
///
/// ## Usage Examples
///
/// ### Basic Usage
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
///           await send(.purchaseCompleted)
///         },
///         boundaryId: CancelID.payment,
///         lockCondition: { state, action in
///           // Action-level condition
///           guard state.balance >= amount else {
///             return .cancel(MyError.insufficientBalance)
///           }
///           return .success
///         }
///       )
///     default:
///       return .none
///     }
///   }
///   .lock(
///     condition: { state, action in
///       // Reducer-level condition
///       switch action {
///       case .purchase, .withdraw:
///         guard state.isLoggedIn else {
///           return .cancel(MyError.notAuthenticated)
///         }
///         return .success
///       default:
///         return .cancel(MyError.noLockRequired)  // Skip exclusive processing
///       }
///     },
///     boundaryId: CancelID.auth
///   )
/// }
/// ```
public struct LockmanDynamicConditionReducer<State: Sendable, Action: Sendable>: Reducer {
  @usableFromInline
  internal let _base: Reduce<State, Action>

  /// Reducer-level condition for automatic exclusive processing (required)
  @usableFromInline
  internal let _condition: @Sendable (_ state: State, _ action: Action) -> LockmanResult

  /// Boundary ID for reducer-level exclusive processing (required)
  @usableFromInline
  internal let _boundaryId: any LockmanBoundaryId

  /// Lock failure handler for reducer-level processing (optional)
  @usableFromInline
  internal let _lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?

  @usableFromInline
  var base: Reduce<State, Action> { _base }

  /// Initializes a reducer with required condition evaluation and boundary ID.
  ///
  /// - Parameters:
  ///   - reduce: The base reducer function to be executed.
  ///   - condition: Function that evaluates the current state and action
  ///                to determine if exclusive processing should be applied.
  ///   - boundaryId: Boundary identifier for exclusive processing.
  ///   - lockFailure: Optional handler for condition evaluation failures.
  public init(
    _ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>,
    condition: @escaping @Sendable (_ state: State, _ action: Action) -> LockmanResult,
    boundaryId: any LockmanBoundaryId,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) {
    self._base = Reduce { state, action in
      reduce(&state, action)
    }
    self._condition = condition
    self._boundaryId = boundaryId
    self._lockFailure = lockFailure
  }

  /// Initializes the reducer with an existing Reduce instance.
  ///
  /// - Parameters:
  ///   - base: An existing Reduce instance.
  ///   - condition: Function that evaluates the current state and action
  ///                to determine if exclusive processing should be applied.
  ///   - boundaryId: Boundary identifier for exclusive processing.
  ///   - lockFailure: Optional handler for condition evaluation failures.
  public init(
    base: Reduce<State, Action>,
    condition: @escaping @Sendable (_ state: State, _ action: Action) -> LockmanResult,
    boundaryId: any LockmanBoundaryId,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) {
    self._base = base
    self._condition = condition
    self._boundaryId = boundaryId
    self._lockFailure = lockFailure
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    // Reducer-level condition evaluation
    let conditionResult = self._condition(state, action)

    switch conditionResult {
    case .cancel(let error):
      // Exclusive processing not required - do not execute base reducer
      if let lockFailure = self._lockFailure {
        return .run { send in
          await lockFailure(error, send)
        }
      } else {
        return .none
      }

    case .success, .successWithPrecedingCancellation:
      // Exclusive processing required - execute base reducer with cancellable control
      let baseEffect = self.base.reduce(into: &state, action: action)
      return baseEffect.cancellable(id: self._boundaryId)
    }
  }
}

// MARK: - Action-Level Lock Method

extension LockmanDynamicConditionReducer {
  /// Creates an effect with action-level condition evaluation and simplified exclusive processing.
  ///
  /// This method provides independent action-level exclusive processing using condition evaluation
  /// and cancellable effect control. It operates independently from reducer-level processing.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for condition evaluation failures
  ///   - boundaryId: Unique identifier for effect cancellation boundary
  ///   - lockCondition: Optional action-level condition for exclusive processing control
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate exclusive processing based on condition
  public func lock<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    boundaryId: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {

    // Action-level condition evaluation
    if let lockCondition = lockCondition {
      let conditionResult = lockCondition(state, action)

      switch conditionResult {
      case .cancel(let error):
        // Condition not met - call lockFailure handler
        if let lockFailure = lockFailure {
          return .run { send in
            await lockFailure(error, send)
          }
        } else {
          return .none
        }

      case .success, .successWithPrecedingCancellation:
        // Condition met - execute operation with cancellable control
        let baseEffect = Effect<Action>.run(priority: priority) { send in
          try await operation(send)
        } catch: { error, send in
          await handler?(error, send)
        }

        return baseEffect.cancellable(id: boundaryId)
      }
    } else {
      // No condition - always execute operation with cancellable control
      let baseEffect = Effect<Action>.run(priority: priority) { send in
        try await operation(send)
      } catch: { error, send in
        await handler?(error, send)
      }

      return baseEffect.cancellable(id: boundaryId)
    }
  }
}
