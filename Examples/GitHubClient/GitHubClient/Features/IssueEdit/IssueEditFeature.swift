import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct IssueEditFeature {
  @ObservableState
  struct State: Equatable {
    let issueId: String
    var originalIssue: Issue?
    var title = ""
    var body = ""
    var selectedLabels: Set<String> = []
    var availableLabels = [
      "bug",
      "enhancement",
      "documentation",
      "question",
      "help wanted",
      "good first issue",
    ]
    var isLoading = false
    var isLoadingIssue = false
    @Presents var alert: AlertState<Action.ViewAction.Alert>?

    var isValid: Bool {
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasChanges: Bool {
      guard let original = originalIssue else { return false }
      return title != original.title || body != (original.body ?? "")
        || Set(original.labels.map { $0.name }) != selectedLabels
    }
  }

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    case delegate(Delegate)

    @CasePathable
    enum ViewAction {
      case onAppear
      case titleChanged(String)
      case bodyChanged(String)
      case labelToggled(String)
      case cancelButtonTapped
      case saveButtonTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case issueResponse(Result<Issue, Error>)
      case updateIssueResponse(Result<Issue, Error>)
    }

    enum Delegate: Equatable {
      case issueUpdated(Issue)
      case cancelled
      case authenticationError
    }
  }

  @Dependency(\.gitHubClient) var gitHubClient
  @Dependency(\.dismiss) var dismiss

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case .onAppear:
          guard state.originalIssue == nil else { return .none }
          state.isLoadingIssue = true
          return .run { [issueId = state.issueId, gitHubClient] send in
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

        case .titleChanged(let title):
          state.title = title
          return .none

        case .bodyChanged(let body):
          state.body = body
          return .none

        case .labelToggled(let label):
          if state.selectedLabels.contains(label) {
            state.selectedLabels.remove(label)
          } else {
            state.selectedLabels.insert(label)
          }
          return .none

        case .cancelButtonTapped:
          return .run { [dismiss] send in
            await send(.delegate(.cancelled))
            await dismiss()
          }

        case .saveButtonTapped:
          guard state.isValid && state.hasChanges else { return .none }
          state.isLoading = true

          let title = state.title
          let body = state.body
          let labels = Array(state.selectedLabels)
          var updatedIssue = state.originalIssue!

          // Update the issue
          updatedIssue.title = title
          updatedIssue.body = body.isEmpty ? nil : body
          updatedIssue.updatedAt = Date()
          updatedIssue.labels = labels.enumerated().map { index, name in
            IssueLabel(
              id: index,
              name: name,
              color: ["d73a4a", "0075ca", "cfd3d7", "a2eeef", "7057ff", "008672"].randomElement()!,
              description: nil
            )
          }

          let issueToUpdate = updatedIssue

          return .run { send in
            // Mock updating issue
            try await Task.sleep(nanoseconds: 1_000_000_000)

            await send(.internal(.updateIssueResponse(.success(issueToUpdate))))
          }

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case .issueResponse(.success(let issue)):
          state.originalIssue = issue
          state.title = issue.title
          state.body = issue.body ?? ""
          state.selectedLabels = Set(issue.labels.map { $0.name })
          state.isLoadingIssue = false
          return .none

        case .issueResponse(.failure(let error)):
          state.isLoadingIssue = false

          if case GitHubClientError.notAuthenticated = error {
            return .send(.delegate(.authenticationError))
          }

          state.alert = AlertState {
            TextState("Error Loading Issue")
          } message: {
            TextState(error.localizedDescription)
          }
          return .none

        case .updateIssueResponse(.success(let issue)):
          state.isLoading = false
          return .run { [dismiss] send in
            await send(.delegate(.issueUpdated(issue)))
            await dismiss()
          }

        case .updateIssueResponse(.failure(let error)):
          state.isLoading = false
          state.alert = AlertState {
            TextState("Error Updating Issue")
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
