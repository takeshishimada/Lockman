import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct UserProfileFeature {
  @ObservableState
  struct State: Equatable {
    let username: String
    var user: User?
    var repositories: [Repository] = []
    var followersCount = 0
    var followingCount = 0
    var isLoading = false
    var isLoadingRepos = false
    @Presents var alert: AlertState<Action.Alert>?

    var isCurrentUser: Bool {
      // Check if this is the current logged-in user
      if let userData = UserDefaults.standard.data(forKey: "github_user"),
        let currentUser = try? JSONDecoder().decode(User.self, from: userData)
      {
        return currentUser.login == username
      }
      return false
    }
  }

  enum Action {
    case onAppear
    case refreshButtonTapped
    case repositoryTapped(Repository)
    case followersButtonTapped
    case followingButtonTapped
    case viewAllRepositoriesButtonTapped
    case profileResponse(Result<User, Error>)
    case repositoriesResponse(Result<[Repository], Error>)
    case countsResponse(followers: Int, following: Int)
    case alert(PresentationAction<Alert>)
    case delegate(Delegate)

    enum Alert: Equatable {}

    enum Delegate: Equatable {
      case repositoryTapped(String)
      case followersTapped(String)
      case followingTapped(String)
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        guard state.user == nil else { return .none }
        state.isLoading = true
        state.isLoadingRepos = true

        return .run { [username = state.username] send in
          // Load user profile
          await send(
            .profileResponse(
              Result { try await gitHubClient.getUserProfile(username: username) }
            ))

          // Load repositories
          await send(
            .repositoriesResponse(
              Result {
                try await gitHubClient.getUserRepositories(username: username)
              }
            ))
        }

      case .refreshButtonTapped:
        state.isLoading = true
        state.isLoadingRepos = true

        return .run { [username = state.username] send in
          await send(
            .profileResponse(
              Result { try await gitHubClient.getUserProfile(username: username) }
            ))

          await send(
            .repositoriesResponse(
              Result {
                try await gitHubClient.getUserRepositories(username: username)
              }
            ))
        }

      case .repositoryTapped(let repository):
        return .send(.delegate(.repositoryTapped(repository.fullName)))

      case .followersButtonTapped:
        return .send(.delegate(.followersTapped(state.username)))

      case .followingButtonTapped:
        return .send(.delegate(.followingTapped(state.username)))

      case .viewAllRepositoriesButtonTapped:
        // Navigate to repositories list
        return .none

      case .profileResponse(.success(let user)):
        state.user = user
        state.isLoading = false

        // Load follower/following counts
        return .run { [username = state.username] send in
          async let followers = try await gitHubClient.getFollowers(username: username)
          async let following = try await gitHubClient.getFollowing(username: username)

          await send(
            .countsResponse(
              followers: (try? await followers)?.count ?? 0,
              following: (try? await following)?.count ?? 0
            ))
        }

      case .profileResponse(.failure(let error)):
        state.isLoading = false
        state.alert = AlertState {
          TextState("Error Loading Profile")
        } message: {
          TextState(error.localizedDescription)
        }
        return .none

      case .repositoriesResponse(.success(let repositories)):
        state.repositories = repositories
        state.isLoadingRepos = false
        return .none

      case .repositoriesResponse(.failure):
        // Silently fail for repositories
        state.isLoadingRepos = false
        return .none

      case .countsResponse(let followers, let following):
        state.followersCount = followers
        state.followingCount = following
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
