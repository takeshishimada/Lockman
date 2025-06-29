import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct PriorityBasedStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var highButtonResult: String = ""
    var lowButtonResult: String = ""
    var noneButtonResult: String = ""
    var currentRunning: String = ""
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanCompositeStrategy(
      LockmanPriorityBasedStrategy.self,
      LockmanSingleExecutionStrategy.self
    )
    enum ViewAction {
      case highButtonTapped
      case lowButtonTapped
      case noneButtonTapped

      var actionId: String {
        switch self {
        case .highButtonTapped: return "high-priority"
        case .lowButtonTapped: return "low-priority"
        case .noneButtonTapped: return "none-priority"
        }
      }

      var priority: LockmanPriorityBasedInfo.Priority {
        switch self {
        case .highButtonTapped: return .high(.exclusive)
        case .lowButtonTapped: return .low(.exclusive)
        case .noneButtonTapped: return .none
        }
      }

      var lockmanInfo: LockmanCompositeInfo2<LockmanPriorityBasedInfo, LockmanSingleExecutionInfo> {
        LockmanCompositeInfo2(
          strategyId: strategyId,
          actionId: actionId,
          lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
            actionId: actionId,
            priority: priority,
            blocksSameAction: false  // SingleExecutionStrategyに委譲
          ),
          lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
            actionId: actionId,
            mode: .action  // 同じアクションの重複実行を防止
          )
        )
      }
    }

    enum InternalAction {
      case updateResult(button: ButtonType, result: String)
      case setCurrentRunning(String)
      case clearCurrentRunning
    }

    enum ButtonType {
      case high, low, none
    }
  }

  enum CancelID {
    case priorityOperation
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(viewAction, state: &state)

      case let .internal(internalAction):
        return handleInternalAction(internalAction, state: &state)
      }
    }
  }

  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    let buttonType: Action.ButtonType
    let priorityName: String

    switch action {
    case .highButtonTapped:
      buttonType = .high
      priorityName = "High Priority"
    case .lowButtonTapped:
      buttonType = .low
      priorityName = "Low Priority"
    case .noneButtonTapped:
      buttonType = .none
      priorityName = "No Priority"
    }

    return .withLock(
      operation: { send in
        await send(.internal(.setCurrentRunning(priorityName)))
        await send(.internal(.updateResult(button: buttonType, result: "🔄 Running...")))

        // Simulate operation with different durations
        let sleepTime: UInt64
        switch action.priority {
        case .high: sleepTime = 3_000_000_000  // 3 seconds
        case .low: sleepTime = 4_000_000_000  // 4 seconds
        case .none: sleepTime = 2_000_000_000  // 2 seconds
        }

        try await Task.sleep(nanoseconds: sleepTime)
        await send(.internal(.updateResult(button: buttonType, result: "✅ Success")))
        await send(.internal(.clearCurrentRunning))
      },
      catch: { error, send in
        await send(.internal(.updateResult(button: buttonType, result: "❌ Cancelled")))
        // Don't clear current running here if it's not us
      },
      lockFailure: { error, send in
        // Handle different types of lock failures
        let failureMessage: String
        if let priorityError = error as? LockmanPriorityBasedError {
          switch priorityError {
          case .higherPriorityExists:
            failureMessage = "❌ Blocked by higher priority"
          case .samePriorityConflict:
            failureMessage = "❌ Same priority running"
          case .blockedBySameAction:
            failureMessage = "❌ Already running"
          case let .precedingActionCancelled(cancelledInfo):
            // Update the cancelled task's button to show it was cancelled
            let cancelledButton: Action.ButtonType
            switch cancelledInfo.actionId {
            case "high-priority":
              cancelledButton = .high
            case "low-priority":
              cancelledButton = .low
            case "none-priority":
              cancelledButton = .none
            default:
              // Fallback - shouldn't happen with our action IDs
              cancelledButton = .low
            }
            await send(
              .internal(
                .updateResult(button: cancelledButton, result: "❌ Cancelled by higher priority")))
            failureMessage = "✅ Replaced lower priority"
          }
        } else if error is LockmanSingleExecutionError {
          failureMessage = "❌ Already running"
        } else {
          failureMessage = "❌ Failed"
        }
        await send(.internal(.updateResult(button: buttonType, result: failureMessage)))
      },
      action: action,
      cancelID: CancelID.priorityOperation
    )
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case let .updateResult(button: button, result: result):
      switch button {
      case .high:
        state.highButtonResult = result
      case .low:
        state.lowButtonResult = result
      case .none:
        state.noneButtonResult = result
      }
      return .none

    case let .setCurrentRunning(priority):
      state.currentRunning = priority
      return .none

    case .clearCurrentRunning:
      state.currentRunning = ""
      return .none
    }
  }
}

@ViewAction(for: PriorityBasedStrategyFeature.self)
struct PriorityBasedStrategyView: View {
  let store: StoreOf<PriorityBasedStrategyFeature>

  var body: some View {
    VStack(spacing: 0) {
      // Header
      VStack(alignment: .leading, spacing: 10) {
        Text("Priority Based Strategy")
          .font(.title2)
          .fontWeight(.bold)

        Text("Tap buttons to see how priority affects execution")
          .font(.caption)
          .foregroundColor(.secondary)

        HStack {
          Text("Currently running:")
            .font(.caption)
          Text(store.currentRunning.isEmpty ? "None" : store.currentRunning)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(store.currentRunning.isEmpty ? .secondary : .blue)
        }
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(.systemGray6))
      .cornerRadius(10)

      // Priority list
      List {
        // High Priority
        HStack {
          // Button (left column)
          Button(action: { send(.highButtonTapped) }) {
            HStack {
              Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
              Text("High Priority")
            }
          }
          .disabled(store.highButtonResult.contains("🔄"))
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.highButtonResult.isEmpty ? "Ready" : store.highButtonResult)
            .font(.caption)
            .foregroundColor(statusColor(store.highButtonResult))
        }
        .padding(.vertical, 8)

        // Low Priority
        HStack {
          // Button (left column)
          Button(action: { send(.lowButtonTapped) }) {
            HStack {
              Image(systemName: "minus.circle.fill")
                .foregroundColor(.orange)
              Text("Low Priority")
            }
          }
          .disabled(store.lowButtonResult.contains("🔄"))
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.lowButtonResult.isEmpty ? "Ready" : store.lowButtonResult)
            .font(.caption)
            .foregroundColor(statusColor(store.lowButtonResult))
        }
        .padding(.vertical, 8)

        // No Priority
        HStack {
          // Button (left column)
          Button(action: { send(.noneButtonTapped) }) {
            HStack {
              Image(systemName: "circle")
                .foregroundColor(.gray)
              Text("No Priority")
            }
          }
          .disabled(store.noneButtonResult.contains("🔄"))
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.noneButtonResult.isEmpty ? "Ready" : store.noneButtonResult)
            .font(.caption)
            .foregroundColor(statusColor(store.noneButtonResult))
        }
        .padding(.vertical, 8)
      }
      .listStyle(.insetGrouped)

      Spacer()

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (PriorityBasedStrategy):")
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
    .navigationTitle("PriorityBasedStrategy")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func statusColor(_ result: String) -> Color {
    if result.isEmpty {
      return .secondary
    } else if result.contains("✅") {
      return .green
    } else if result.contains("❌") {
      return .red
    } else if result.contains("🔄") {
      return .orange
    } else {
      return .primary
    }
  }
}

#Preview {
  NavigationStack {
    PriorityBasedStrategyView(
      store: Store(
        initialState: PriorityBasedStrategyFeature.State()
      ) {
        PriorityBasedStrategyFeature()
      }
    )
  }
}
