import CasePaths
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
  let extractLockmanAction: (Action) -> (any LockmanAction)?

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Get the base effect
      let baseEffect = self.base.reduce(into: &state, action: action)

      // Extract LockmanAction using the provided extractor
      guard let lockmanAction = self.extractLockmanAction(action) else {
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
