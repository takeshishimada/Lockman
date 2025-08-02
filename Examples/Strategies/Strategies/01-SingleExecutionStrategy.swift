import CasePaths
import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct SingleExecutionStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var taskStatus: TaskStatus = .idle
  }

  @CasePathable
  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanSingleExecution
    enum ViewAction {
      case startProcessButtonTapped

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        return .init(actionId: actionName, mode: .boundary)
      }
    }

    enum InternalAction {
      case processStart
      case processCompleted
      case handleError(Error)
      case handleLockFailure(Error)
      case clearTemporaryMessage
    }
  }

  enum CancelID {
    case process
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(viewAction, state: &state)

      case .internal(let internalAction):
        return handleInternalAction(internalAction, state: &state)
      }
    }
    .lock(
      boundaryId: CancelID.process,
      lockFailure: { error, send in
        print("🔒 Lock failure detected: \(error)")
        print("  Error type: \(type(of: error))")
        print("  Error description: \(error.localizedDescription)")
        await send(.internal(.handleLockFailure(error)))
      },
      for: \.view
    )
  }

  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .startProcessButtonTapped:
      return .run { send in
        await send(.internal(.processStart))
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds
        await send(.internal(.processCompleted))
      } catch: { error, send in
        await send(.internal(.handleError(error)))
      }
      .cancellable(id: CancelID.process)
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .processStart:
      state.taskStatus = .running
      return .none

    case .processCompleted:
      state.taskStatus = .completed
      return .none

    case .handleError(let error):
      state.taskStatus = .failed("Error: \(error.localizedDescription)")
      return .none

    case .handleLockFailure(let error):
      if let cancellationError = error as? LockmanCancellationError {
        // Handle cancellation errors that contain the actual strategy errors
        if cancellationError.reason is LockmanSingleExecutionError {
          state.taskStatus = .blocked
        } else {
          state.taskStatus = .failed("Lock acquisition failed")
        }
      } else if error is LockmanSingleExecutionError {
        state.taskStatus = .blocked
      } else {
        state.taskStatus = .failed("Lock acquisition failed")
      }
      return .none

    case .clearTemporaryMessage:
      return .none
    }
  }
}

@ViewAction(for: SingleExecutionStrategyFeature.self)
struct SingleExecutionStrategyView: View {
  let store: StoreOf<SingleExecutionStrategyFeature>

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 10) {
        Text("Single Execution Strategy")
          .font(.title2)
          .fontWeight(.bold)

        Text("Prevents duplicate executions while processing")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.systemGray6))
      .cornerRadius(10)

      // Process list
      List {
        HStack {
          // Button (left column)
          Button(action: { send(.startProcessButtonTapped) }) {
            HStack {
              Image(systemName: store.taskStatus.iconName)
                .foregroundColor(store.taskStatus.iconColor)
              Text("Start Process")
            }
          }
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.taskStatus.displayText)
            .font(.caption)
            .foregroundColor(store.taskStatus.displayColor)
        }
        .padding(.vertical, 8)
      }
      .listStyle(.insetGrouped)

      Spacer()

      // Debug Button
      DebugButton(strategyName: "SingleExecutionStrategy")
    }
    .navigationTitle("SingleExecutionStrategy")
    .navigationBarTitleDisplayMode(.inline)
  }

}
