import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct RepositoryDetailFeature {
  @ObservableState
  struct State: Equatable {
    let repositoryId: String
    var repository: Repository?
    var isStarred = false
    var issues: [Issue] = []
    var isLoading = false
    var isLoadingStarStatus = false
    @Presents var alert: AlertState<Action.ViewAction.Alert>?

    var repositoryOwner: String? {
      repository?.owner.login
    }

    var repositoryName: String? {
      repository?.name
    }
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    case delegate(Delegate)

    @CasePathable
    enum ViewAction {
      case onAppear
      case refreshButtonTapped
      case starButtonTapped
      case viewWebButtonTapped
      case viewIssuesButtonTapped
      case viewOwnerButtonTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case repositoryResponse(Repository)
      case starStatusResponse(Bool)
      case issuesResponse([Issue])
      case starToggleResponse(Bool)
      case handleError(Error)
    }

    enum Delegate: Equatable {
      case viewIssuesTapped(String)
      case viewOwnerTapped(String)
      case openURL(URL)
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          guard state.repository == nil else { return .none }
          state.isLoading = true
          state.isLoadingStarStatus = true

          // Parse repository ID (format: owner/repo)
          let components = state.repositoryId.split(separator: "/")
          guard components.count == 2 else {
            state.alert = AlertState {
              TextState("Invalid Repository")
            } message: {
              TextState("Repository ID format should be owner/repo")
            }
            return .none
          }

          let owner = String(components[0])
          let repo = String(components[1])

          return .run { send in
            // Load repository details
            let repository = try await gitHubClient.getRepository(owner: owner, repo: repo)
            await send(.internal(.repositoryResponse(repository)))

            // Check star status
            let isStarred = try await gitHubClient.checkIfStarred(owner: owner, repo: repo)
            await send(.internal(.starStatusResponse(isStarred)))

            // Load issues
            let issues = try await gitHubClient.getRepositoryIssues(owner: owner, repo: repo)
            await send(.internal(.issuesResponse(issues)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          guard let owner = state.repositoryOwner,
            let repo = state.repositoryName
          else { return .none }

          state.isLoading = true
          return .run { send in
            let repository = try await gitHubClient.getRepository(owner: owner, repo: repo)
            await send(.internal(.repositoryResponse(repository)))

            let issues = try await gitHubClient.getRepositoryIssues(owner: owner, repo: repo)
            await send(.internal(.issuesResponse(issues)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .starButtonTapped:
          guard let owner = state.repositoryOwner,
            let repo = state.repositoryName
          else { return .none }

          state.isLoadingStarStatus = true
          let newStarState = !state.isStarred

          return .run { send in
            if newStarState {
              try await gitHubClient.starRepository(owner: owner, repo: repo)
            } else {
              try await gitHubClient.unstarRepository(owner: owner, repo: repo)
            }
            await send(.internal(.starToggleResponse(newStarState)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .viewWebButtonTapped:
          guard let urlString = state.repository?.htmlURL,
            let url = URL(string: urlString)
          else { return .none }
          return .send(.delegate(.openURL(url)))

        case .viewIssuesButtonTapped:
          return .send(.delegate(.viewIssuesTapped(state.repositoryId)))

        case .viewOwnerButtonTapped:
          guard let owner = state.repositoryOwner else { return .none }
          return .send(.delegate(.viewOwnerTapped(owner)))

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case let .repositoryResponse(repository):
          state.repository = repository
          state.isLoading = false
          return .none

        case let .starStatusResponse(isStarred):
          state.isStarred = isStarred
          state.isLoadingStarStatus = false
          return .none

        case let .issuesResponse(issues):
          state.issues = Array(issues.prefix(5))  // Show only first 5 issues
          return .none

        case let .starToggleResponse(isStarred):
          state.isStarred = isStarred
          state.isLoadingStarStatus = false
          return .none

        case let .handleError(error):
          state.isLoading = false
          state.isLoadingStarStatus = false
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
