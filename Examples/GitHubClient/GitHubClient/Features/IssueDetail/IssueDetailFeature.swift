import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct IssueDetailFeature {
  @ObservableState
  struct State: Equatable {
    let issueId: String
    var issue: Issue?
    var isLoading = false
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
      case editButtonTapped
      case closeIssueButtonTapped
      case reopenIssueButtonTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case issueResponse(Result<Issue, Error>)
      case updateIssueResponse(Result<Issue, Error>)
    }

    enum Delegate: Equatable {
      case editTapped(String)
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
          guard state.issue == nil else { return .none }
          state.isLoading = true
          return .run { [issueId = state.issueId] send in
            await send(
              .internal(
                .issueResponse(
                  Result {
                    // Mock implementation - find issue by ID
                    let issues = try await gitHubClient.getMyIssues()
                    guard let issue = issues.first(where: { String($0.id) == issueId }) else {
                      throw GitHubClientError.invalidResponse
                    }
                    return issue
                  }
                )))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { [issueId = state.issueId] send in
            await send(
              .internal(
                .issueResponse(
                  Result {
                    let issues = try await gitHubClient.getMyIssues()
                    guard let issue = issues.first(where: { String($0.id) == issueId }) else {
                      throw GitHubClientError.invalidResponse
                    }
                    return issue
                  }
                )))
          }

        case .editButtonTapped:
          return .send(.delegate(.editTapped(state.issueId)))

        case .closeIssueButtonTapped:
          guard var issue = state.issue else { return .none }
          state.isLoading = true
          issue.state = .closed
          issue.closedAt = Date()
          let closedIssue = issue
          return .run { send in
            // Mock closing issue
            try await Task.sleep(nanoseconds: 500_000_000)
            await send(.internal(.updateIssueResponse(.success(closedIssue))))
          }

        case .reopenIssueButtonTapped:
          guard var issue = state.issue else { return .none }
          state.isLoading = true
          issue.state = .open
          issue.closedAt = nil
          let reopenedIssue = issue
          return .run { send in
            // Mock reopening issue
            try await Task.sleep(nanoseconds: 500_000_000)
            await send(.internal(.updateIssueResponse(.success(reopenedIssue))))
          }

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case .issueResponse(.success(let issue)):
          state.issue = issue
          state.isLoading = false
          return .none

        case .issueResponse(.failure(let error)):
          state.isLoading = false

          if case GitHubClientError.notAuthenticated = error {
            return .send(.delegate(.authenticationError))
          }

          state.alert = AlertState {
            TextState("Error")
          } message: {
            TextState(error.localizedDescription)
          }
          return .none

        case .updateIssueResponse(.success(let issue)):
          state.issue = issue
          state.isLoading = false
          return .none

        case .updateIssueResponse(.failure(let error)):
          state.isLoading = false
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
