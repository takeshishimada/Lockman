import ComposableArchitecture
import Dependencies

@Reducer
struct FollowingListFeature {
  @ObservableState
  struct State: Equatable {
    let username: String
    var following: [User] = []
    var isLoading = false
    var isRefreshing = false
    @Presents var alert: AlertState<Action.ViewAction.Alert>?
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    case delegate(Delegate)

    @CasePathable
    enum ViewAction {
      case onAppear
      case refreshButtonTapped
      case pullToRefresh
      case userTapped(User)
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case followingResponse([User])
      case handleError(Error)
    }

    enum Delegate: Equatable {
      case userTapped(String)
      case authenticationError
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          guard state.following.isEmpty else { return .none }
          state.isLoading = true
          return .run { [username = state.username] send in
            let following = try await gitHubClient.getFollowing(username: username)
            await send(.internal(.followingResponse(following)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { [username = state.username] send in
            let following = try await gitHubClient.getFollowing(username: username)
            await send(.internal(.followingResponse(following)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .pullToRefresh:
          state.isRefreshing = true
          return .run { [username = state.username] send in
            let following = try await gitHubClient.getFollowing(username: username)
            await send(.internal(.followingResponse(following)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .userTapped(let user):
          return .send(.delegate(.userTapped(user.login)))

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case let .followingResponse(following):
          state.following = following
          state.isLoading = false
          state.isRefreshing = false
          return .none

        case let .handleError(error):
          state.isLoading = false
          state.isRefreshing = false

          if case GitHubClientError.notAuthenticated = error {
            return .send(.delegate(.authenticationError))
          }

          state.alert = AlertState {
            TextState("Error")
          } message: {
            TextState(error.localizedDescription)
          }
          return .none
        }

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.view.alert)
  }
}
