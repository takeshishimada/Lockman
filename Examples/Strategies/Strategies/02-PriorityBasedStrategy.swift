import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct PriorityBasedStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var highButtonResult: String = ""
    var lowExclusiveResult: String = ""
    var lowReplaceableResult: String = ""
    var noneButtonResult: String = ""
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
      case lowExclusiveTapped
      case lowReplaceableTapped
      case noneButtonTapped

      var actionId: String {
        switch self {
        case .highButtonTapped: return "high-priority"
        case .lowExclusiveTapped: return "low-exclusive"
        case .lowReplaceableTapped: return "low-replaceable"
        case .noneButtonTapped: return "none-priority"
        }
      }

      var priority: LockmanPriorityBasedInfo.Priority {
        switch self {
        case .highButtonTapped: return .high(.exclusive)
        case .lowExclusiveTapped: return .low(.exclusive)
        case .lowReplaceableTapped: return .low(.replaceable)
        case .noneButtonTapped: return .none
        }
      }

      var lockmanInfo: LockmanCompositeInfo2<LockmanPriorityBasedInfo, LockmanSingleExecutionInfo> {
        LockmanCompositeInfo2(
          strategyId: strategyId,
          actionId: actionId,
          lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
            actionId: actionId,
            priority: priority
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
    }

    enum ButtonType {
      case high, lowExclusive, lowReplaceable, none
    }
  }

  enum CancelID {
    case priorityOperation
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
      boundaryId: CancelID.priorityOperation,
      lockFailure: { error, send in
        // Handle different types of lock failures at reducer level
        if let priorityError = error as? LockmanPriorityBasedError {
          switch priorityError {
          case .precedingActionCancelled(let cancelledInfo):
            // Update the cancelled task's button to show it was cancelled
            let cancelledButton: Action.ButtonType
            switch cancelledInfo.actionId {
            case "high-priority":
              cancelledButton = .high
            case "low-exclusive":
              cancelledButton = .lowExclusive
            case "low-replaceable":
              cancelledButton = .lowReplaceable
            case "none-priority":
              cancelledButton = .none
            default:
              cancelledButton = .lowExclusive
            }
            await send(
              .internal(
                .updateResult(button: cancelledButton, result: "Cancelled by higher priority")))
          default:
            break
          }
        }
      }
    )
  }

  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    let buttonType: Action.ButtonType

    switch action {
    case .highButtonTapped:
      buttonType = .high
    case .lowExclusiveTapped:
      buttonType = .lowExclusive
    case .lowReplaceableTapped:
      buttonType = .lowReplaceable
    case .noneButtonTapped:
      buttonType = .none
    }

    return .run { send in
      await send(.internal(.updateResult(button: buttonType, result: "Running...")))

      // Simulate operation with different durations
      let sleepTime: UInt64
      switch action.priority {
      case .high: sleepTime = 3_000_000_000  // 3 seconds
      case .low: sleepTime = 4_000_000_000  // 4 seconds
      case .none: sleepTime = 2_000_000_000  // 2 seconds
      }

      try await Task.sleep(nanoseconds: sleepTime)
      await send(.internal(.updateResult(button: buttonType, result: "Success")))
    } catch: { error, send in
      await send(.internal(.updateResult(button: buttonType, result: "Cancelled")))
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .updateResult(let button, let result):
      switch button {
      case .high:
        state.highButtonResult = result
      case .lowExclusive:
        state.lowExclusiveResult = result
      case .lowReplaceable:
        state.lowReplaceableResult = result
      case .none:
        state.noneButtonResult = result
      }
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

        Text(
          "High priority cancels lower ones. Same priority: Exclusive blocks, Replaceable cancels and replaces."
        )
        .font(.caption)
        .foregroundColor(.secondary)
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
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.highButtonResult.isEmpty ? "Ready" : store.highButtonResult)
            .font(.caption)
            .foregroundColor(statusColor(store.highButtonResult))
        }
        .padding(.vertical, 8)

        // Low Priority (Exclusive)
        HStack {
          // Button (left column)
          Button(action: { send(.lowExclusiveTapped) }) {
            HStack {
              Image(systemName: "minus.circle.fill")
                .foregroundColor(.orange)
              Text("Low Priority (Exclusive)")
            }
          }
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.lowExclusiveResult.isEmpty ? "Ready" : store.lowExclusiveResult)
            .font(.caption)
            .foregroundColor(statusColor(store.lowExclusiveResult))
        }
        .padding(.vertical, 8)

        // Low Priority (Replaceable)
        HStack {
          // Button (left column)
          Button(action: { send(.lowReplaceableTapped) }) {
            HStack {
              Image(systemName: "arrow.2.circlepath.circle.fill")
                .foregroundColor(.orange)
              Text("Low Priority (Replaceable)")
            }
          }
          .frame(width: 140, alignment: .leading)

          Spacer()

          // Status display (right column)
          Text(store.lowReplaceableResult.isEmpty ? "Ready" : store.lowReplaceableResult)
            .font(.caption)
            .foregroundColor(statusColor(store.lowReplaceableResult))
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
    } else if result == "Success" || result == "Replaced lower priority" {
      return .green
    } else if result.contains("Blocked") || result.contains("Failed")
      || result.contains("Cancelled") || result == "Already running"
      || result == "Same priority running"
    {
      return .red
    } else if result == "Running..." {
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
