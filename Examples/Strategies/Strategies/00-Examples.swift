import ComposableArchitecture
import Lockman
import SwiftUI

// MARK: - Examples Feature
@Reducer
struct ExamplesFeature {
  @ObservableState
  struct State: Equatable {
    var path = StackState<Path.State>()
  }

  @CasePathable
  enum Action {
    case path(StackAction<Path.State, Path.Action>)
    case concurrencyLimitedStrategyTapped
    case dynamicConditionStrategyTapped
    case groupCoordinationStrategyTapped
    case priorityBasedStrategyTapped
    case singleExecutionStrategyTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .concurrencyLimitedStrategyTapped:
        state.path.append(.concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.State()))
        return .none

      case .dynamicConditionStrategyTapped:
        state.path.append(.dynamicConditionStrategy(DynamicConditionStrategyFeature.State()))
        return .none

      case .groupCoordinationStrategyTapped:
        state.path.append(.groupCoordinationStrategy(GroupCoordinationStrategyFeature.State()))
        return .none

      case .priorityBasedStrategyTapped:
        state.path.append(.priorityBasedStrategy(PriorityBasedStrategyFeature.State()))
        return .none

      case .singleExecutionStrategyTapped:
        state.path.append(.singleExecutionStrategy(SingleExecutionStrategyFeature.State()))
        return .none

      case .path:
        return .none
      }
    }
    .forEach(\.path, action: \.path) {
      Path()
    }
  }
}

// MARK: - Path Reducer
@Reducer
struct Path {
  @ObservableState
  enum State: Equatable {
    case concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.State)
    case dynamicConditionStrategy(DynamicConditionStrategyFeature.State)
    case groupCoordinationStrategy(GroupCoordinationStrategyFeature.State)
    case priorityBasedStrategy(PriorityBasedStrategyFeature.State)
    case singleExecutionStrategy(SingleExecutionStrategyFeature.State)
  }

  enum Action {
    case concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.Action)
    case dynamicConditionStrategy(DynamicConditionStrategyFeature.Action)
    case groupCoordinationStrategy(GroupCoordinationStrategyFeature.Action)
    case priorityBasedStrategy(PriorityBasedStrategyFeature.Action)
    case singleExecutionStrategy(SingleExecutionStrategyFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.concurrencyLimitedStrategy, action: \.concurrencyLimitedStrategy) {
      ConcurrencyLimitedStrategyFeature()
    }
    Scope(state: \.dynamicConditionStrategy, action: \.dynamicConditionStrategy) {
      DynamicConditionStrategyFeature()
    }
    Scope(state: \.groupCoordinationStrategy, action: \.groupCoordinationStrategy) {
      GroupCoordinationStrategyFeature()
    }
    Scope(state: \.priorityBasedStrategy, action: \.priorityBasedStrategy) {
      PriorityBasedStrategyFeature()
    }
    Scope(state: \.singleExecutionStrategy, action: \.singleExecutionStrategy) {
      SingleExecutionStrategyFeature()
    }
  }
}

struct ExamplesView: View {
  @Bindable var store: StoreOf<ExamplesFeature>

  var body: some View {
    NavigationStack(
      path: $store.scope(state: \.path, action: \.path)
    ) {
      List {
        // Overview Section
        Section {
          VStack(alignment: .leading, spacing: 10) {
            Text("Lockman Strategy Examples")
              .font(.headline)
            Text(
              "Lockman is a Swift library for controlling concurrent action execution. These examples demonstrate how to manage action execution using different strategy patterns."
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
          .padding(.vertical, 8)
        }

        Section("Strategy Examples") {
          // SingleExecutionStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("SingleExecutionStrategy") {
              store.send(.singleExecutionStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text("The most basic strategy that prevents duplicate execution of the same action")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

          // PriorityBasedStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("PriorityBasedStrategy") {
              store.send(.priorityBasedStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text(
              "Controls action execution order and replacement based on priority levels\n(Uses CompositeStrategy with SingleExecutionStrategy)"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

          // ConcurrencyLimitedStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("ConcurrencyLimitedStrategy") {
              store.send(.concurrencyLimitedStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text(
              "Limits the number of concurrent executions for resource-intensive operations\n(Uses CompositeStrategy with SingleExecutionStrategy)"
            )
            .font(.caption)
            .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

          // GroupCoordinationStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("GroupCoordinationStrategy") {
              store.send(.groupCoordinationStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text("Coordinates actions within groups with leader/member roles")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

          // DynamicConditionStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("DynamicConditionStrategy") {
              store.send(.dynamicConditionStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text("Controls execution based on dynamic runtime conditions")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

        }
      }
      .listStyle(.grouped)
      .navigationTitle("Examples")
    } destination: { store in
      switch store.state {
      case .concurrencyLimitedStrategy:
        if let store = store.scope(
          state: \.concurrencyLimitedStrategy, action: \.concurrencyLimitedStrategy)
        {
          ConcurrencyLimitedStrategyView(store: store)
        }
      case .dynamicConditionStrategy:
        if let store = store.scope(
          state: \.dynamicConditionStrategy, action: \.dynamicConditionStrategy)
        {
          DynamicConditionStrategyView(store: store)
        }
      case .groupCoordinationStrategy:
        if let store = store.scope(
          state: \.groupCoordinationStrategy, action: \.groupCoordinationStrategy)
        {
          GroupCoordinationStrategyView(store: store)
        }
      case .priorityBasedStrategy:
        if let store = store.scope(state: \.priorityBasedStrategy, action: \.priorityBasedStrategy)
        {
          PriorityBasedStrategyView(store: store)
        }
      case .singleExecutionStrategy:
        if let store = store.scope(
          state: \.singleExecutionStrategy, action: \.singleExecutionStrategy)
        {
          SingleExecutionStrategyView(store: store)
        }
      }
    }
  }
}
