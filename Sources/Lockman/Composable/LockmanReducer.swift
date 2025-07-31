import CasePaths
import ComposableArchitecture
import Foundation

/// A reducer wrapper that applies Lockman locking to effects produced by actions conforming to `LockmanAction`.
///
/// ## Effect-Level Locking
///
/// **This reducer applies locking at the effect level**: Due to TCA's architectural constraints,
/// state mutations in the base reducer occur synchronously before lock acquisition. However,
/// effects are locked, ensuring exclusive control over async operations.
///
/// ## Lock Execution Flow
/// 1. **State Mutation**: Base reducer executes synchronously (state changes occur)
/// 2. **Lock Acquisition**: Attempt to acquire lock for the returned effect
/// 3. **Effect Execution**: Run effects ONLY if lock acquisition succeeds
/// 4. **Automatic Unlock**: Release lock when effects complete
///
/// ## When Lock Fails
/// - State mutations have already occurred (TCA limitation)
/// - Effects are cancelled (`.none` is returned)
/// - Lock failure handler is invoked if provided
///
/// ## For True Lock-First Behavior
/// Use `LockmanDynamicConditionReducer` with explicit `.lock()` calls for scenarios
/// requiring lock acquisition before any state changes.
///
/// ## Example
/// ```swift
/// @Reducer
/// struct Feature {
///   struct State: Equatable {
///     var counter = 0  // ⚠️ This will be mutated before lock acquisition
///   }
///
///   enum Action: LockmanSingleExecutionAction {
///     case increment
///     case decrement
///
///     var lockmanInfo: LockmanSingleExecutionInfo {
///       switch self {
///       case .increment, .decrement:
///         return LockmanSingleExecutionInfo(actionId: "counter", mode: .boundary)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .increment:
///         state.counter += 1  // ⚠️ Executes BEFORE lock acquisition
///         return .run { send in
///           // This effect executes AFTER lock acquisition
///           await performSideEffect()
///         }
///       case .decrement:
///         state.counter -= 1  // ⚠️ Executes BEFORE lock acquisition
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
      // Extract LockmanAction using the provided extractor
      guard let lockmanAction = self.extractLockmanAction(action) else {
        // Not a LockmanAction, execute base reducer normally
        return self.base.reduce(into: &state, action: action)
      }

      // Execute base reducer to get the effect (state mutations happen here)
      let baseEffect = self.base.reduce(into: &state, action: action)
      
      // Apply lock to the effect - lock acquisition will happen before effect executes
      // If lock cannot be acquired, the effect will not execute (returns .none)
      return baseEffect.lock(
        action: lockmanAction,
        boundaryId: boundaryId,
        unlockOption: unlockOption,
        lockFailure: lockFailure
      )
    }
  }
}
