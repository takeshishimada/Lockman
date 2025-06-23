import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    var user: User?
    var repositories: [Repository] = []
    var followersCount = 0
    var followingCount = 0
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
      case settingsButtonTapped
      case repositoriesTapped
      case followersTapped
      case followingTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case profileResponse(User)
      case repositoriesResponse([Repository])
      case countsResponse(followers: Int, following: Int)
      case handleError(Error)
    }

    enum Delegate: Equatable {
      case settingsTapped
      case authenticationError
      case repositoriesTapped
      case followersTapped(username: String)
      case followingTapped(username: String)
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          guard state.user == nil else { return .none }
          state.isLoading = true
          return .run { send in
            let user = try await gitHubClient.getCurrentUser()
            await send(.internal(.profileResponse(user)))

            // Load repositories in parallel
            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { send in
            let user = try await gitHubClient.getCurrentUser()
            await send(.internal(.profileResponse(user)))

            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .pullToRefresh:
          state.isRefreshing = true
          return .run { send in
            let user = try await gitHubClient.getCurrentUser()
            await send(.internal(.profileResponse(user)))

            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .settingsButtonTapped:
          return .send(.delegate(.settingsTapped))

        case .repositoriesTapped:
          return .send(.delegate(.repositoriesTapped))

        case .followersTapped:
          guard let username = state.user?.login else { return .none }
          return .send(.delegate(.followersTapped(username: username)))

        case .followingTapped:
          guard let username = state.user?.login else { return .none }
          return .send(.delegate(.followingTapped(username: username)))

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case .profileResponse(let user):
          state.user = user
          state.isLoading = false
          state.isRefreshing = false

          // Load follower/following counts
          return .run { [username = user.login] send in
            async let followers = try await gitHubClient.getFollowers(username: username)
            async let following = try await gitHubClient.getFollowing(username: username)

            await send(
              .internal(
                .countsResponse(
                  followers: (try? await followers)?.count ?? 0,
                  following: (try? await following)?.count ?? 0
                )))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .repositoriesResponse(let repositories):
          state.repositories = repositories
          return .none

        case .countsResponse(let followers, let following):
          state.followersCount = followers
          state.followingCount = following
          return .none

        case .handleError(let error):
          state.isLoading = false
          state.isRefreshing = false

          // Check if it's an authentication error
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
