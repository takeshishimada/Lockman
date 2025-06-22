import ComposableArchitecture
import SwiftUI

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    var appStack = AppStackFeature.State()
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action {
    case appStack(AppStackFeature.Action)
    case alert(PresentationAction<Alert>)

    enum Alert: Equatable {}
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.appStack, action: \.appStack) {
      AppStackFeature()
    }

    Reduce { state, action in
      switch action {
      case .appStack:
        return .none

      case .alert:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
