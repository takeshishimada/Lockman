import CasePaths
import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct SingleExecutionStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var processStatus: ProcessStatus = .idle
    var temporaryMessage: String? = nil

    enum ProcessStatus: Equatable {
      case idle
      case processing
      case completed
      case failed(String)
      case blocked
    }
  }

  @CasePathable
  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanSingleExecution
    enum ViewAction {
      case startProcessButtonTapped

      var lockmanInfo: LockmanSingleExecutionInfo {
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
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .processStart:
      state.processStatus = .processing
      return .none

    case .processCompleted:
      state.processStatus = .completed
      return .none

    case .handleError(let error):
      state.processStatus = .failed("Error: \(error.localizedDescription)")
      return .none

    case .handleLockFailure(let error):
      if error is LockmanSingleExecutionError {
        // Show temporary message when blocked during processing
        if state.processStatus == .processing {
          state.temporaryMessage = "Already running"
          return .run { send in
            try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
            await send(.internal(.clearTemporaryMessage))
          }
        } else {
          state.processStatus = .blocked
        }
      } else {
        state.processStatus = .failed("Lock acquisition failed")
      }
      return .none

    case .clearTemporaryMessage:
      state.temporaryMessage = nil
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
              Image(systemName: iconName(for: store.processStatus))
                .foregroundColor(iconColor(for: store.processStatus))
              Text("Start Process")
            }
          }
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.temporaryMessage ?? statusText(for: store.processStatus))
            .font(.caption)
            .foregroundColor(
              store.temporaryMessage != nil ? .orange : statusColor(for: store.processStatus))
        }
        .padding(.vertical, 8)
      }
      .listStyle(.insetGrouped)

      Spacer()

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (SingleExecutionStrategy):")
        LockmanManager.debug.printCurrentLocks(options: .compact)
        print("")
      }) {
        HStack {
          Image(systemName: "lock.doc")
          Text("Show Current Locks in Console")
        }
        .font(.footnote)
        .foregroundColor(.blue)
      }
      .padding(.top, 20)
    }
    .navigationTitle("SingleExecutionStrategy")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func iconName(for status: SingleExecutionStrategyFeature.State.ProcessStatus) -> String {
    switch status {
    case .idle:
      return "play.circle"
    case .processing:
      return "play.circle.fill"
    case .completed:
      return "checkmark.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    case .blocked:
      return "exclamationmark.circle.fill"
    }
  }

  private func iconColor(for status: SingleExecutionStrategyFeature.State.ProcessStatus) -> Color {
    switch status {
    case .idle:
      return .blue
    case .processing:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .blocked:
      return .yellow
    }
  }

  private func statusText(for status: SingleExecutionStrategyFeature.State.ProcessStatus) -> String
  {
    switch status {
    case .idle:
      return "Ready to start"
    case .processing:
      return "Processing..."
    case .completed:
      return "Completed successfully"
    case .failed(let error):
      return error
    case .blocked:
      return "Already running"
    }
  }

  private func statusColor(for status: SingleExecutionStrategyFeature.State.ProcessStatus) -> Color
  {
    switch status {
    case .idle:
      return .secondary
    case .processing:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .blocked:
      return .orange
    }
  }
}
