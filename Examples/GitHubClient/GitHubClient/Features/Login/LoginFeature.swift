import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct LoginFeature {
  @ObservableState
  struct State: Equatable {
    var token = ""
    var isLoading = false
    @Presents var alert: AlertState<Action.Alert>?
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case loginButtonTapped
    case loginResponse(Result<User, Error>)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable {}

    enum Delegate: Equatable {
      case loginSuccess(User)
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient
  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .onAppear:
        return .none

      case .loginButtonTapped:
        guard !state.token.isEmpty else {
          state.alert = AlertState {
            TextState("Invalid Token")
          } message: {
            TextState("Please enter your GitHub personal access token.")
          }
          return .none
        }

        state.isLoading = true

        return .run { [token = state.token] send in
          do {
            let user = try await gitHubClient.authenticate(token: token)
            await send(.loginResponse(.success(user)))
          } catch {
            await send(.loginResponse(.failure(error)))
          }
        }

      case .loginResponse(.success(let user)):
        state.isLoading = false

        // Save auth state
        UserDefaults.standard.set(state.token, forKey: "github_token")
        if let userData = try? JSONEncoder().encode(user.authUser) {
          UserDefaults.standard.set(userData, forKey: "github_user")
        }

        return .send(.delegate(.loginSuccess(user)))

      case .loginResponse(.failure(let error)):
        state.isLoading = false
        state.alert = AlertState {
          TextState("Login Failed")
        } message: {
          TextState(error.localizedDescription)
        }
        return .none

      case .alert:
        return .none

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}
