import ComposableArchitecture
import LockmanComposable
import LockmanCore
import SwiftUI

enum CompositeStrategyInjection {
  static func inject() {
    let strategy = LockmanCompositeStrategy2(
      strategy1: LockmanSingleExecutionStrategy(),
      strategy2: LockmanDynamicConditionStrategy()
    )
    try! Lockman.container.register(strategy)
  }
}

@Reducer
struct CompositeStrategyFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.appStorage("isLoggined")) var isLoggined = false
    var count = 0
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case state(StateAction)

    @LockmanCompositeStrategy(
      LockmanSingleExecutionStrategy.self, LockmanDynamicConditionStrategy.self)
    enum ViewAction {
      case decrementButtonTapped
      case incrementButtonTapped

      var actionId: String {
        actionName
      }

      var lockmanInfo:
        LockmanCompositeInfo2<LockmanSingleExecutionStrategy.I, LockmanDynamicConditionStrategy.I>
      {
        LockmanCompositeInfo2<LockmanSingleExecutionStrategy.I, LockmanDynamicConditionStrategy.I>(
          actionId: actionId,
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
            actionId: actionName, mode: .boundary),
          lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
            actionId: actionName,
            condition: {
              @Shared(.appStorage("isLoggined")) var isLoggined = false
              if isLoggined {
                return true
              } else {
                return false
              }
            })
        )
      }
    }

    enum StateAction {
      case decrement
      case increment
    }
  }

  enum CancelID {
    case userAction
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case .decrementButtonTapped:
          return .withLock(
            operation: { send in
              try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
              await send(.state(.decrement))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
        case .incrementButtonTapped:
          state.$isLoggined.withLock { $0 = true }
          return .withLock(
            operation: { send in
              try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
              await send(.state(.increment))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
        }

      case let .state(stateAction):
        switch stateAction {
        case .decrement:
          state.count -= 1
          return .none
        case .increment:
          state.count += 1
          return .none
        }
      }
    }
  }
}

@ViewAction(for: CompositeStrategyFeature.self)
struct CompositeStrategyView: View {
  let store: StoreOf<CompositeStrategyFeature>

  var body: some View {
    VStack(spacing: 30) {
      // Overview
      VStack(alignment: .leading, spacing: 10) {
        Text("CompositeStrategy")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "A composite strategy that combines multiple strategies.\nCombines SingleExecutionStrategy and DynamicConditionStrategy."
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.leading)
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)

      // Login Status Display
      HStack {
        Label(
          store.isLoggined ? "Logged In" : "Not Logged In",
          systemImage: store.isLoggined ? "checkmark.circle.fill" : "xmark.circle"
        )
        .foregroundColor(store.isLoggined ? .green : .red)
        .font(.caption)
        .fontWeight(.semibold)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(store.isLoggined ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
      .cornerRadius(20)

      // Counter Section
      HStack {
        Button {
          send(.decrementButtonTapped)
        } label: {
          Image(systemName: "minus")
        }

        Text("\(store.count)")
          .monospacedDigit()
          .frame(minWidth: 50)

        Button {
          send(.incrementButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .font(.largeTitle)

      // Button Behavior Description
      VStack(alignment: .leading, spacing: 8) {
        Label("Both buttons: SingleExecutionStrategy", systemImage: "lock.circle")
          .font(.caption)
          .fontWeight(.medium)
        Label(
          "→ Rapid taps on the same button are disabled while processing",
          systemImage: "arrow.right"
        )
        .font(.caption)
        .foregroundColor(.blue)
        .padding(.leading, 20)

        Divider()

        Label("Dynamic condition: DynamicConditionStrategy", systemImage: "gearshape.circle")
          .font(.caption)
          .fontWeight(.medium)
        Label("→ Actions are executed only when logged in", systemImage: "arrow.right")
          .font(.caption)
          .foregroundColor(.purple)
          .padding(.leading, 20)

        Divider()

        Label("Plus button: Sets login status to true", systemImage: "plus.circle")
          .font(.caption)
          .foregroundColor(.green)
        Label("Minus button: Does not change login status", systemImage: "minus.circle")
          .font(.caption)

        Label("When not logged in, button taps won't work", systemImage: "info.circle")
          .font(.caption)
          .foregroundColor(.orange)
          .padding(.top, 4)
      }
      .padding()
      .background(Color.blue.opacity(0.05))
      .cornerRadius(8)

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (CompositeStrategy):")
        Lockman.debug.printCurrentLocks(options: .compact)
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
    .padding()
    .navigationTitle("Composite")
  }
}
