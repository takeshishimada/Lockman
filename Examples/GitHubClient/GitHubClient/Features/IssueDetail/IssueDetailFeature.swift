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
      case issueResponse(Issue)
      case updateIssueResponse(Issue)
      case handleError(Error)
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
            // Mock implementation - find issue by ID
            let issues = try await gitHubClient.getMyIssues()
            guard let issue = issues.first(where: { String($0.id) == issueId }) else {
              throw GitHubClientError.invalidResponse
            }
            await send(.internal(.issueResponse(issue)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .refreshButtonTapped:
          state.isLoading = true
          return .run { [issueId = state.issueId] send in
            let issues = try await gitHubClient.getMyIssues()
            guard let issue = issues.first(where: { String($0.id) == issueId }) else {
              throw GitHubClientError.invalidResponse
            }
            await send(.internal(.issueResponse(issue)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .editButtonTapped:
          return .send(.delegate(.editTapped(state.issueId)))

        case .closeIssueButtonTapped:
          guard let issue = state.issue else { return .none }
          state.isLoading = true
          return .run { send in
            let closedIssue = try await gitHubClient.closeIssue(issue)
            await send(.internal(.updateIssueResponse(closedIssue)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .reopenIssueButtonTapped:
          guard let issue = state.issue else { return .none }
          state.isLoading = true
          return .run { send in
            let reopenedIssue = try await gitHubClient.reopenIssue(issue)
            await send(.internal(.updateIssueResponse(reopenedIssue)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case let .issueResponse(issue):
          state.issue = issue
          state.isLoading = false
          return .none

        case let .updateIssueResponse(issue):
          state.issue = issue
          state.isLoading = false
          return .none

        case let .handleError(error):
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
        }

      case .delegate:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.view.alert)
  }
}
