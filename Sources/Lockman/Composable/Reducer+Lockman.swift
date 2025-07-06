import ComposableArchitecture
import Foundation

/// A reducer wrapper that applies Lockman locking to effects produced by actions conforming to `LockmanAction`.
///
/// `LockmanReducer` intercepts effects from the base reducer and automatically applies
/// locking behavior to actions that implement the `LockmanAction` protocol. Actions that
/// don't conform to `LockmanAction` pass through unchanged.
///
/// ## Example
/// ```swift
/// @Reducer
/// struct Feature {
///   struct State: Equatable { }
///
///   enum Action: LockmanAction {
///     case fetch
///     case fetchResponse(Result<Data, Error>)
///
///     var lockmanInfo: LockmanSingleExecutionInfo {
///       switch self {
///       case .fetch:
///         return LockmanSingleExecutionInfo(actionId: "fetch", mode: .boundary)
///       default:
///         return LockmanSingleExecutionInfo(actionId: "other", mode: .none)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .fetch:
///         return .run { send in
///           // This effect will be automatically locked
///           let data = try await fetchData()
///           await send(.fetchResponse(.success(data)))
///         }
///       case .fetchResponse:
///         return .none
///       }
///     }
///     .lock(boundaryId: CancelID.feature)
///   }
/// }
/// ```
public struct LockmanReducer<Base: Reducer>: Reducer {
  public typealias State = Base.State
  public typealias Action = Base.Action

  let base: Base
  let boundaryId: any LockmanBoundaryId
  let unlockOption: LockmanUnlockOption
  let lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Get the base effect
      let baseEffect = self.base.reduce(into: &state, action: action)

      // Check if action implements LockmanAction
      guard let lockmanAction = action as? any LockmanAction else {
        // Not a LockmanAction, return effect as-is
        return baseEffect
      }

      // Apply lock to the effect using Effect.lock()
      return baseEffect.lock(
        action: lockmanAction,
        boundaryId: boundaryId,
        unlockOption: unlockOption,
        lockFailure: lockFailure
      )
    }
  }
}

// MARK: - Reducer Extension

extension Reducer {
  /// Applies Lockman locking to effects produced by this reducer.
  ///
  /// This method wraps the reducer to automatically apply locking to any effects
  /// produced by actions that conform to `LockmanAction`. Actions that don't
  /// conform to `LockmanAction` pass through unchanged.
  ///
  /// The locking behavior is determined by the `lockmanInfo` property of each action.
  /// When an effect is locked:
  /// - If the lock is acquired successfully, the effect executes normally
  /// - If the lock fails, the `lockFailure` callback is invoked (if provided)
  /// - The lock is automatically released based on the `unlockOption`
  ///
  /// ## Usage
  /// ```swift
  /// var body: some ReducerOf<Self> {
  ///   Reduce { state, action in
  ///     // Your reducer logic
  ///   }
  ///   .lock(
  ///     boundaryId: CancelID.feature,
  ///     unlockOption: .immediate,
  ///     lockFailure: { error, send in
  ///       print("Lock failed: \(error)")
  ///       await send(.lockFailureHandled)
  ///     }
  ///   )
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking. All actions within this
  ///     boundary will be subject to the locking rules defined in their `lockmanInfo`.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///     Receives the error and a send function to dispatch actions.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) -> LockmanReducer<Self> {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure
    )
  }
}
