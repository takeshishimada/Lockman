import ComposableArchitecture
import Dependencies

@Reducer
struct UserRepositoriesFeature {
  @ObservableState
  struct State: Equatable {
    var repositories: [Repository] = []
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
      case repositoryTapped(Repository)
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case repositoriesResponse([Repository])
      case handleError(Error)
    }

    enum Delegate: Equatable {
      case repositoryTapped(String)
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
          guard state.repositories.isEmpty else { return .none }
          state.isLoading = true
          return .run { send in
            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { send in
            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .pullToRefresh:
          state.isRefreshing = true
          return .run { send in
            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .repositoryTapped(let repository):
          return .send(.delegate(.repositoryTapped(repository.fullName)))

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case let .repositoriesResponse(repositories):
          state.repositories = repositories
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
