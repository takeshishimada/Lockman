import ComposableArchitecture
import LockmanComposable
import LockmanCore
import SwiftUI

@Reducer
struct PriorityBasedStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var count = 0
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case state(StateAction)

    @LockmanPriorityBased
    enum ViewAction {
      case decrementButtonTapped
      case incrementButtonTapped

      internal var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .decrementButtonTapped:
          .init(actionId: actionName, priority: .high(.replaceable))
        case .incrementButtonTapped:
          .init(actionId: actionName, priority: .high(.exclusive))
        }
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

@ViewAction(for: PriorityBasedStrategyFeature.self)
struct PriorityBasedStrategyView: View {
  let store: StoreOf<PriorityBasedStrategyFeature>

  var body: some View {
    VStack(spacing: 30) {
      // Overview
      VStack(alignment: .leading, spacing: 10) {
        Text("PriorityBasedStrategy")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "A strategy that controls action execution based on priority levels.\nHigh-priority actions can replace low-priority ones or execute exclusively."
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
        Label("Minus button: Priority .high(.replaceable)", systemImage: "minus.circle")
          .font(.caption)
        Label("→ Rapid taps will replace the old process with new ones", systemImage: "arrow.right")
          .font(.caption)
          .foregroundColor(.orange)
          .padding(.leading, 20)

        Label("Plus button: Priority .high(.exclusive)", systemImage: "plus.circle")
          .font(.caption)
        Label(
          "→ Won't accept other operations until processing is complete", systemImage: "arrow.right"
        )
        .font(.caption)
        .foregroundColor(.red)
        .padding(.leading, 20)

        Label("Each has a 2-second delay so you can see the difference", systemImage: "info.circle")
          .font(.caption)
          .foregroundColor(.blue)
          .padding(.top, 4)
      }
      .padding()
      .background(Color.blue.opacity(0.05))
      .cornerRadius(8)

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (PriorityBasedStrategy):")
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
    .navigationTitle("Priority Based")
  }
}
