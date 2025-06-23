import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct IssueCreateFeature {
  @ObservableState
  struct State: Equatable {
    var title = ""
    var body = ""
    var selectedRepository: Repository?
    var repositories: [Repository] = []
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
    var isLoadingRepositories = false
    @Presents var alert: AlertState<Action.ViewAction.Alert>?

    var isValid: Bool {
      !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedRepository != nil
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
      case repositorySelected(Repository?)
      case labelToggled(String)
      case cancelButtonTapped
      case createButtonTapped
      case alert(PresentationAction<Alert>)

      enum Alert: Equatable {}
    }

    enum InternalAction {
      case repositoriesResponse([Repository])
      case createIssueResponse(Issue)
      case handleError(Error)
    }

    enum Delegate: Equatable {
      case issueCreated(Issue)
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
          guard state.repositories.isEmpty else { return .none }
          state.isLoadingRepositories = true
          return .run { [gitHubClient] send in
            let repositories = try await gitHubClient.getMyRepositories()
            await send(.internal(.repositoriesResponse(repositories)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .titleChanged(let title):
          state.title = title
          return .none

        case .bodyChanged(let body):
          state.body = body
          return .none

        case .repositorySelected(let repository):
          state.selectedRepository = repository
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

        case .createButtonTapped:
          guard state.isValid else { return .none }
          state.isLoading = true

          let title = state.title
          let body = state.body
          let repository = state.selectedRepository!
          let labels = Array(state.selectedLabels)

          return .run { send in
            // Mock creating issue
            try await Task.sleep(nanoseconds: 1_000_000_000)

            let newIssue = Issue(
              id: Int.random(in: 1000...9999),
              number: Int.random(in: 100...999),
              title: title,
              body: body.isEmpty ? nil : body,
              state: .open,
              author: IssueAuthor(
                id: 1,
                login: "testuser",
                avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"
              ),
              createdAt: Date(),
              updatedAt: Date(),
              closedAt: nil,
              repository: IssueRepository(
                id: repository.id,
                name: repository.name,
                fullName: repository.fullName
              ),
              labels: labels.enumerated().map { index, name in
                IssueLabel(
                  id: index,
                  name: name,
                  color: ["d73a4a", "0075ca", "cfd3d7", "a2eeef", "7057ff", "008672"]
                    .randomElement()!,
                  description: nil
                )
              },
              commentsCount: 0
            )

            await send(.internal(.createIssueResponse(newIssue)))
          } catch: { error, send in
            await send(.internal(.handleError(error)))
          }

        case .alert:
          return .none
        }

      case let .internal(internalAction):
        switch internalAction {
        case let .repositoriesResponse(repositories):
          state.repositories = repositories
          state.isLoadingRepositories = false
          // Auto-select first repository if only one
          if repositories.count == 1 {
            state.selectedRepository = repositories.first
          }
          return .none

        case let .createIssueResponse(issue):
          state.isLoading = false
          return .run { [dismiss] send in
            await send(.delegate(.issueCreated(issue)))
            await dismiss()
          }

        case let .handleError(error):
          state.isLoading = false
          state.isLoadingRepositories = false

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
