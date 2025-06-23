import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct SingleExecutionStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case state(StateAction)

    @LockmanSingleExecution
    enum ViewAction {
      case decrementButtonTapped
      case incrementButtonTapped

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
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

@ViewAction(for: SingleExecutionStrategyFeature.self)
struct SingleExecutionStrategyView: View {
  let store: StoreOf<SingleExecutionStrategyFeature>

  var body: some View {
    VStack(spacing: 30) {
      // Overview
      VStack(alignment: .leading, spacing: 10) {
        Text("SingleExecutionStrategy")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "A strategy that prevents duplicate execution of the same action.\nWhile processing, tapping the same button again will be ignored."
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.leading)
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)

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
        Label("Minus button: Decreases count after 2 seconds", systemImage: "minus.circle")
          .font(.caption)
        Label("Plus button: Increases count after 2 seconds", systemImage: "plus.circle")
          .font(.caption)
        Label(
          "Rapid taps on the same button are disabled while processing", systemImage: "info.circle"
        )
        .font(.caption)
        .foregroundColor(.blue)
      }
      .padding()
      .background(Color.blue.opacity(0.05))
      .cornerRadius(8)

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
    .padding()
    .navigationTitle("Single Execution")
  }
}
