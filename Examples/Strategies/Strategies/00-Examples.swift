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
    case compositeStrategyTapped
    case concurrencyLimitedStrategyTapped
    case priorityBasedStrategyTapped
    case singleExecutionStrategyTapped
    case showCurrentLocksTapped
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .compositeStrategyTapped:
        state.path.append(.compositeStrategy(CompositeStrategyFeature.State()))
        return .none

      case .concurrencyLimitedStrategyTapped:
        state.path.append(.concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.State()))
        return .none

      case .priorityBasedStrategyTapped:
        state.path.append(.priorityBasedStrategy(PriorityBasedStrategyFeature.State()))
        return .none

      case .singleExecutionStrategyTapped:
        state.path.append(.singleExecutionStrategy(SingleExecutionStrategyFeature.State()))
        return .none

      case .showCurrentLocksTapped:
        // Print current locks to console with compact formatting
        print("\n📊 Current Lock State:")
        LockmanManager.debug.printCurrentLocks(options: .compact)
        print("")
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
    case compositeStrategy(CompositeStrategyFeature.State)
    case concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.State)
    case priorityBasedStrategy(PriorityBasedStrategyFeature.State)
    case singleExecutionStrategy(SingleExecutionStrategyFeature.State)
  }

  enum Action {
    case compositeStrategy(CompositeStrategyFeature.Action)
    case concurrencyLimitedStrategy(ConcurrencyLimitedStrategyFeature.Action)
    case priorityBasedStrategy(PriorityBasedStrategyFeature.Action)
    case singleExecutionStrategy(SingleExecutionStrategyFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.compositeStrategy, action: \.compositeStrategy) {
      CompositeStrategyFeature()
    }
    Scope(state: \.concurrencyLimitedStrategy, action: \.concurrencyLimitedStrategy) {
      ConcurrencyLimitedStrategyFeature()
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

            Text("Controls action execution order and replacement based on priority levels")
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

            Text("Limits the number of concurrent executions for resource-intensive operations")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)

          // CompositeStrategy
          VStack(alignment: .leading, spacing: 4) {
            Button("CompositeStrategy") {
              store.send(.compositeStrategyTapped)
            }
            .foregroundColor(.primary)
            .font(.headline)

            Text("Combines multiple strategies to achieve complex control logic")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .padding(.vertical, 4)
        }

        // Debug Section
        Section("Debug Tools") {
          Button(action: {
            store.send(.showCurrentLocksTapped)
          }) {
            HStack {
              Image(systemName: "lock.doc")
                .foregroundColor(.blue)
              Text("Show Current Locks")
                .foregroundColor(.primary)
              Spacer()
              Text("Console")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .padding(.vertical, 4)
        }
      }
      .listStyle(.grouped)
      .navigationTitle("Examples")
    } destination: { store in
      switch store.state {
      case .compositeStrategy:
        if let store = store.scope(state: \.compositeStrategy, action: \.compositeStrategy) {
          CompositeStrategyView(store: store)
        }
      case .concurrencyLimitedStrategy:
        if let store = store.scope(state: \.concurrencyLimitedStrategy, action: \.concurrencyLimitedStrategy) {
          ConcurrencyLimitedStrategyView(store: store)
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
