import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct PriorityBasedStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var currentOperation: String = ""
    var operationHistory: [OperationRecord] = []
    let maxHistoryCount = 10
  }

  struct OperationRecord: Equatable, Identifiable {
    let id = UUID()
    let operation: String
    let priority: String
    let result: Result
    let timestamp: Date

    enum Result: Equatable {
      case completed
      case cancelled
      case replaced
    }
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanCompositeStrategy(
      LockmanPriorityBasedStrategy.self,
      LockmanSingleExecutionStrategy.self
    )
    enum ViewAction {
      // High priority actions
      case highExclusiveButtonTapped
      case highReplaceableButtonTapped

      // Medium priority actions
      case mediumExclusiveButtonTapped
      case mediumReplaceableButtonTapped

      // Low priority actions
      case lowExclusiveButtonTapped
      case lowReplaceableButtonTapped

      var actionId: String {
        switch self {
        case .highExclusiveButtonTapped: return "high-exclusive"
        case .highReplaceableButtonTapped: return "high-replaceable"
        case .mediumExclusiveButtonTapped: return "medium-exclusive"
        case .mediumReplaceableButtonTapped: return "medium-replaceable"
        case .lowExclusiveButtonTapped: return "low-exclusive"
        case .lowReplaceableButtonTapped: return "low-replaceable"
        }
      }

      var operationName: String {
        switch self {
        case .highExclusiveButtonTapped: return "High (Exclusive)"
        case .highReplaceableButtonTapped: return "High (Replaceable)"
        case .mediumExclusiveButtonTapped: return "Low (Exclusive)"
        case .mediumReplaceableButtonTapped: return "Low (Replaceable)"
        case .lowExclusiveButtonTapped: return "None (Action 1)"
        case .lowReplaceableButtonTapped: return "None (Action 2)"
        }
      }

      var priority: LockmanPriorityBasedInfo.Priority {
        switch self {
        case .highExclusiveButtonTapped: return .high(.exclusive)
        case .highReplaceableButtonTapped: return .high(.replaceable)
        case .mediumExclusiveButtonTapped: return .low(.exclusive)  // Medium maps to low priority
        case .mediumReplaceableButtonTapped: return .low(.replaceable)  // Medium maps to low priority
        case .lowExclusiveButtonTapped: return .none  // Low maps to none priority
        case .lowReplaceableButtonTapped: return .none  // Low maps to none priority
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
      case operationStarted(String, String)
      case operationCompleted(String, String)
      case operationCancelled(String, String)
      case operationReplaced(String, String)
      case lockFailure(operation: String, priority: String, error: Error)
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
    let operationName = action.operationName
    let priorityName = priorityDescription(action.priority)

    return .withLock(
      operation: { send in
        await send(.internal(.operationStarted(operationName, priorityName)))

        // Different execution times based on priority
        let sleepTime: UInt64
        switch action.priority {
        case .high: sleepTime = 3_000_000_000  // 3 seconds
        case .low: sleepTime = 4_000_000_000  // 4 seconds
        case .none: sleepTime = 5_000_000_000  // 5 seconds
        }

        try await Task.sleep(nanoseconds: sleepTime)
        await send(.internal(.operationCompleted(operationName, priorityName)))
      },
      catch: { error, send in
        if error is CancellationError {
          await send(.internal(.operationCancelled(operationName, priorityName)))
        } else {
          await send(.internal(.operationCancelled(operationName, priorityName)))
        }
      },
      lockFailure: { error, send in
        await send(
          .internal(.lockFailure(operation: operationName, priority: priorityName, error: error)))
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
    case let .operationStarted(operation, _):
      state.currentOperation = "\(operation) is running..."
      return .none

    case let .operationCompleted(operation, priority):
      state.currentOperation = ""
      addHistory(&state, operation: operation, priority: priority, result: .completed)
      return .none

    case let .operationCancelled(operation, priority):
      addHistory(&state, operation: operation, priority: priority, result: .cancelled)
      return .none

    case let .operationReplaced(operation, priority):
      addHistory(&state, operation: operation, priority: priority, result: .replaced)
      return .none

    case let .lockFailure(operation: operation, priority: priority, error: error):
      // Handle different types of lock failures
      if let priorityError = error as? LockmanPriorityBasedError {
        switch priorityError {
        case .higherPriorityExists:
          print("❌ \(operation) blocked by higher priority operation")
        case .samePriorityConflict:
          print("❌ \(operation) blocked by same priority exclusive operation")
        case .blockedBySameAction:
          print("❌ \(operation) blocked by same action already running")
        case .precedingActionCancelled:
          addHistory(&state, operation: operation, priority: priority, result: .replaced)
          print("🔄 \(operation) will replace preceding action")
        }
      } else if error is LockmanSingleExecutionError {
        print("🚫 \(operation) already running (duplicate prevention)")
      }
      return .none
    }
  }

  private func addHistory(
    _ state: inout State, operation: String, priority: String, result: OperationRecord.Result
  ) {
    let record = OperationRecord(
      operation: operation,
      priority: priority,
      result: result,
      timestamp: Date()
    )
    state.operationHistory.insert(record, at: 0)

    // Keep only recent history
    if state.operationHistory.count > state.maxHistoryCount {
      state.operationHistory.removeLast()
    }
  }

  private func priorityDescription(_ priority: LockmanPriorityBasedInfo.Priority) -> String {
    switch priority {
    case .none:
      return "None"
    case .high(let behavior):
      return "High(\(behavior == .exclusive ? "Exclusive" : "Replaceable"))"
    case .low(let behavior):
      return "Low(\(behavior == .exclusive ? "Exclusive" : "Replaceable"))"
    }
  }
}

@ViewAction(for: PriorityBasedStrategyFeature.self)
struct PriorityBasedStrategyView: View {
  let store: StoreOf<PriorityBasedStrategyFeature>

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Overview
        VStack(alignment: .leading, spacing: 10) {
          Text("PriorityBasedStrategy")
            .font(.title2)
            .fontWeight(.bold)

          Text(
            "Controls action execution based on priority levels. Higher priority actions can block or replace lower priority ones."
          )
          .font(.caption)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(10)

        // Current Operation Status
        if !store.currentOperation.isEmpty {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text(store.currentOperation)
              .font(.subheadline)
              .fontWeight(.medium)
          }
          .padding()
          .frame(maxWidth: .infinity)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(10)
        }

        // Priority Buttons Grid
        VStack(spacing: 15) {
          // High Priority
          PrioritySection(
            title: "High Priority",
            color: .red,
            description: "Can block or replace lower priority operations"
          ) {
            Button(action: { send(.highExclusiveButtonTapped) }) {
              PriorityButton(
                title: "Exclusive",
                subtitle: "Blocks all others",
                color: .red,
                icon: "lock.fill"
              )
            }

            Button(action: { send(.highReplaceableButtonTapped) }) {
              PriorityButton(
                title: "Replaceable",
                subtitle: "Can be replaced",
                color: .red.opacity(0.8),
                icon: "arrow.triangle.2.circlepath"
              )
            }
          }

          // Low Priority
          PrioritySection(
            title: "Low Priority",
            color: .orange,
            description: "Blocked by high priority operations"
          ) {
            Button(action: { send(.mediumExclusiveButtonTapped) }) {
              PriorityButton(
                title: "Exclusive",
                subtitle: "Blocks same priority",
                color: .orange,
                icon: "lock.fill"
              )
            }

            Button(action: { send(.mediumReplaceableButtonTapped) }) {
              PriorityButton(
                title: "Replaceable",
                subtitle: "Can be replaced",
                color: .orange.opacity(0.8),
                icon: "arrow.triangle.2.circlepath"
              )
            }
          }

          // No Priority
          PrioritySection(
            title: "No Priority",
            color: .gray,
            description: "Simple operations without priority conflicts"
          ) {
            Button(action: { send(.lowExclusiveButtonTapped) }) {
              PriorityButton(
                title: "Simple Action 1",
                subtitle: "No priority rules",
                color: .gray,
                icon: "play.fill"
              )
            }

            Button(action: { send(.lowReplaceableButtonTapped) }) {
              PriorityButton(
                title: "Simple Action 2",
                subtitle: "No priority rules",
                color: .gray.opacity(0.8),
                icon: "play.fill"
              )
            }
          }
        }

        // Operation History
        if !store.operationHistory.isEmpty {
          VStack(alignment: .leading, spacing: 10) {
            Text("Operation History")
              .font(.headline)
              .padding(.horizontal)

            ForEach(store.operationHistory) { record in
              HistoryRow(record: record)
            }
          }
          .padding(.vertical)
          .background(Color.gray.opacity(0.05))
          .cornerRadius(10)
        }

        // Info Section
        VStack(alignment: .leading, spacing: 8) {
          Label("How it works", systemImage: "info.circle")
            .font(.headline)

          VStack(alignment: .leading, spacing: 4) {
            BulletPoint("High > Low > None priority order")
            BulletPoint("Exclusive: Blocks same or lower priority operations")
            BulletPoint("Replaceable: Can be replaced by same or higher priority")
            BulletPoint("None priority: No priority conflicts, simple execution")
            BulletPoint("Same button taps prevented by SingleExecutionStrategy")
            BulletPoint("Execution time: High=3s, Low=4s, None=5s")
          }
          .font(.caption)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)

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
        .padding(.top, 10)
      }
      .padding()
    }
    .navigationTitle("Priority Based")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Supporting Views

struct PrioritySection<Content: View>: View {
  let title: String
  let color: Color
  let description: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Circle()
            .fill(color)
            .frame(width: 12, height: 12)
          Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
        }
        Text(description)
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      HStack(spacing: 12) {
        content()
      }
    }
    .padding()
    .background(color.opacity(0.05))
    .cornerRadius(10)
  }
}

struct PriorityButton: View {
  let title: String
  let subtitle: String
  let color: Color
  let icon: String

  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: icon)
        .font(.title3)
      Text(title)
        .font(.caption)
        .fontWeight(.medium)
      Text(subtitle)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .background(color.opacity(0.2))
    .foregroundColor(color)
    .cornerRadius(8)
  }
}

struct HistoryRow: View {
  let record: PriorityBasedStrategyFeature.OperationRecord

  var body: some View {
    HStack {
      resultIcon(for: record.result)
        .foregroundColor(resultColor(for: record.result))

      VStack(alignment: .leading, spacing: 2) {
        Text(record.operation)
          .font(.caption)
          .fontWeight(.medium)
        Text("\(record.priority) - \(timeString(from: record.timestamp))")
          .font(.caption2)
          .foregroundColor(.secondary)
      }

      Spacer()

      Text(resultText(for: record.result))
        .font(.caption2)
        .foregroundColor(resultColor(for: record.result))
    }
    .padding(.horizontal)
    .padding(.vertical, 6)
  }

  private func resultIcon(for result: PriorityBasedStrategyFeature.OperationRecord.Result) -> Image
  {
    switch result {
    case .completed: return Image(systemName: "checkmark.circle.fill")
    case .cancelled: return Image(systemName: "xmark.circle.fill")
    case .replaced: return Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
    }
  }

  private func resultColor(for result: PriorityBasedStrategyFeature.OperationRecord.Result) -> Color
  {
    switch result {
    case .completed: return .green
    case .cancelled: return .red
    case .replaced: return .orange
    }
  }

  private func resultText(for result: PriorityBasedStrategyFeature.OperationRecord.Result) -> String
  {
    switch result {
    case .completed: return "Completed"
    case .cancelled: return "Cancelled"
    case .replaced: return "Replaced"
    }
  }

  private func timeString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter.string(from: date)
  }
}

struct BulletPoint: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Text("•")
      Text(text)
    }
  }
}
