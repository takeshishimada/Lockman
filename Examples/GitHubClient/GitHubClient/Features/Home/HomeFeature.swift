import ComposableArchitecture
import Dependencies

@Reducer
struct HomeFeature {
  enum RepositoryType: String, CaseIterable {
    case myRepositories = "My Repositories"
    case starred = "Starred"

    var systemImage: String {
      switch self {
      case .myRepositories: return "folder"
      case .starred: return "star"
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    var selectedType: RepositoryType = .myRepositories
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
      case segmentChanged(RepositoryType)
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
          return .run { [selectedType = state.selectedType] send in
            let repositories = try await self.loadRepositories(for: selectedType)
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .segmentChanged(let type):
          state.selectedType = type
          state.isLoading = true
          return .run { send in
            let repositories = try await self.loadRepositories(for: type)
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { [selectedType = state.selectedType] send in
            let repositories = try await self.loadRepositories(for: selectedType)
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .pullToRefresh:
          state.isRefreshing = true
          return .run { [selectedType = state.selectedType] send in
            let repositories = try await self.loadRepositories(for: selectedType)
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
        case .repositoriesResponse(let repositories):
          state.repositories = repositories
          state.isLoading = false
          state.isRefreshing = false
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

  private func loadRepositories(for type: RepositoryType) async throws -> [Repository] {
    switch type {
    case .myRepositories:
      return try await gitHubClient.getMyRepositories()
    case .starred:
      return try await gitHubClient.getStarredRepositories()
    }
  }
}
