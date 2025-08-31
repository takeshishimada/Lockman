import CasePaths
import ComposableArchitecture
import Foundation

/// A reducer wrapper that applies Lockman locking with true lock-first behavior.
///
/// ## Lock-First Behavior
///
/// **This reducer implements true lock-first behavior**: Lock acquisition feasibility is checked
/// BEFORE the base reducer executes, preventing state mutations when locks cannot be acquired.
/// This ensures complete exclusive control over both state changes and effects.
///
/// ## Lock Execution Flow & UniqueId Consistency
/// 1. **LockmanInfo Capture**: Capture action's lockmanInfo once to ensure consistent uniqueId
/// 2. **Lock Feasibility Check**: Determine if lock can be acquired using strategy's `canLock`
/// 3. **Conditional State Mutation**: Base reducer executes ONLY if lock acquisition succeeded
/// 4. **Effect Execution**: Run effects with the already-acquired lock using same lockmanInfo
/// 5. **Guaranteed Unlock**: Release lock when effects complete using matching uniqueId
///
/// ## When Lock Fails
/// - No state mutations occur (true lock-first behavior)
/// - Base reducer is never called
/// - Lock failure handler is invoked if provided
/// - Effect returns `.none` (operation is completely cancelled)
///
/// ## Strategy Resolution
/// The reducer uses Effect-based strategy resolution to work around Swift's existential type
/// limitations, allowing type-safe strategy resolution before reducer execution.
///
/// ## Example
/// ```swift
/// @Reducer
/// struct Feature {
///   struct State: Equatable {
///     var counter = 0  // ✅ Only mutated when lock can be acquired
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
///         state.counter += 1  // ✅ Executes ONLY after lock feasibility check
///         return .run { send in
///           // This effect executes with the acquired lock
///           await performSideEffect()
///         }
///       case .decrement:
///         state.counter -= 1  // ✅ Executes ONLY after lock feasibility check
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

      // ✨ LOCK-FIRST IMPLEMENTATION: Use unified Effect.lock implementation
      // The unified lock implementation handles inout state parameters via non-escaping closures
      return Effect.lock(
        reducer: { self.base.reduce(into: &state, action: action) },
        action: lockmanAction,
        boundaryId: boundaryId,
        unlockOption: unlockOption,
        lockFailure: lockFailure,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }
  }
}
