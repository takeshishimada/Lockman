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
        await send(.internal(.clearCurrentRunning))
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
          case .precedingActionCancelled:
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
    VStack(spacing: 40) {
      // Header
      VStack(spacing: 10) {
        Text("Priority Based Strategy")
          .font(.title2)
          .fontWeight(.bold)

        Text("Tap buttons to see how priority affects execution")
          .font(.caption)
          .foregroundColor(.secondary)

        if !store.currentRunning.isEmpty {
          Text("Currently running: \(store.currentRunning)")
            .font(.caption)
            .foregroundColor(.blue)
            .padding(.top, 5)
        }
      }

      // Buttons with results
      VStack(spacing: 30) {
        // High Priority Button
        VStack(spacing: 8) {
          Button(action: { send(.highButtonTapped) }) {
            HStack {
              Image(systemName: "exclamationmark.circle.fill")
              Text("High Priority")
            }
            .frame(width: 200)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.highButtonResult.isEmpty {
            Text(store.highButtonResult)
              .font(.caption)
              .foregroundColor(resultColor(store.highButtonResult))
          }
        }

        // Low Priority Button
        VStack(spacing: 8) {
          Button(action: { send(.lowButtonTapped) }) {
            HStack {
              Image(systemName: "minus.circle.fill")
              Text("Low Priority")
            }
            .frame(width: 200)
            .padding()
            .background(Color.orange)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.lowButtonResult.isEmpty {
            Text(store.lowButtonResult)
              .font(.caption)
              .foregroundColor(resultColor(store.lowButtonResult))
          }
        }

        // None Priority Button
        VStack(spacing: 8) {
          Button(action: { send(.noneButtonTapped) }) {
            HStack {
              Image(systemName: "circle")
              Text("No Priority")
            }
            .frame(width: 200)
            .padding()
            .background(Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.noneButtonResult.isEmpty {
            Text(store.noneButtonResult)
              .font(.caption)
              .foregroundColor(resultColor(store.noneButtonResult))
          }
        }
      }

      Spacer()

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (PriorityBasedStrategy):")
        LockmanManager.debug.printCurrentLocks(options: .compact)
        print("")
      }) {
        HStack {
          Image(systemName: "lock.doc")
          Text("Show Current Locks")
        }
        .font(.footnote)
        .foregroundColor(.blue)
      }
    }
    .padding()
    .navigationTitle("Priority Based")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func resultColor(_ result: String) -> Color {
    if result.contains("✅") {
      return .green
    } else if result.contains("❌") {
      return .red
    } else if result.contains("🔄") {
      return .blue
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
