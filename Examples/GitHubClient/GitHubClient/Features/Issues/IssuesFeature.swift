import ComposableArchitecture
import Dependencies

@Reducer
struct IssuesFeature {
  enum IssueFilter: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case closed = "Closed"

    func matches(_ issue: Issue) -> Bool {
      switch self {
      case .all:
        return true
      case .open:
        return issue.state == .open
      case .closed:
        return issue.state == .closed
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    var issues: [Issue] = []
    var filteredIssues: [Issue] {
      issues.filter { selectedFilter.matches($0) }
    }
    var selectedFilter: IssueFilter = .all
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
      case filterChanged(IssueFilter)
      case refreshButtonTapped
      case pullToRefresh
      case issueTapped(Issue)
      case createIssueButtonTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case issuesResponse(Result<[Issue], Error>)
    }

    enum Delegate: Equatable {
      case issueTapped(String)
      case createIssueTapped
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
          guard state.issues.isEmpty else { return .none }
          state.isLoading = true
          return .run { send in
            await send(
              .internal(
                .issuesResponse(
                  Result { try await gitHubClient.getMyIssues() }
                )))
          }

        case .filterChanged(let filter):
          state.selectedFilter = filter
          return .none

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { send in
            await send(
              .internal(
                .issuesResponse(
                  Result { try await gitHubClient.getMyIssues() }
                )))
          }

        case .pullToRefresh:
          state.isRefreshing = true
          return .run { send in
            await send(
              .internal(
                .issuesResponse(
                  Result { try await gitHubClient.getMyIssues() }
                )))
          }

        case .issueTapped(let issue):
          return .send(.delegate(.issueTapped(String(issue.id))))

        case .createIssueButtonTapped:
          return .send(.delegate(.createIssueTapped))

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case .issuesResponse(.success(let issues)):
          state.issues = issues
          state.isLoading = false
          state.isRefreshing = false
          return .none

        case .issuesResponse(.failure(let error)):
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
