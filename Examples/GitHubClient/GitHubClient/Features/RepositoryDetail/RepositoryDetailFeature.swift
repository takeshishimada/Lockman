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
        @Presents var alert: AlertState<Action.Alert>?
        
        var repositoryOwner: String? {
            repository?.owner.login
        }
        
        var repositoryName: String? {
            repository?.name
        }
    }
    
    enum Action {
        case onAppear
        case refreshButtonTapped
        case starButtonTapped
        case viewWebButtonTapped
        case viewIssuesButtonTapped
        case viewOwnerButtonTapped
        case repositoryResponse(Result<Repository, Error>)
        case starStatusResponse(Result<Bool, Error>)
        case issuesResponse(Result<[Issue], Error>)
        case starToggleResponse(Result<Bool, Error>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        
        enum Alert: Equatable {}
        
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
                    await send(.repositoryResponse(
                        Result { try await gitHubClient.getRepository(owner: owner, repo: repo) }
                    ))
                    
                    // Check star status
                    await send(.starStatusResponse(
                        Result { try await gitHubClient.checkIfStarred(owner: owner, repo: repo) }
                    ))
                    
                    // Load issues
                    await send(.issuesResponse(
                        Result { try await gitHubClient.getRepositoryIssues(owner: owner, repo: repo) }
                    ))
                }
                
            case .refreshButtonTapped:
                guard let owner = state.repositoryOwner,
                      let repo = state.repositoryName else { return .none }
                
                state.isLoading = true
                return .run { send in
                    await send(.repositoryResponse(
                        Result { try await gitHubClient.getRepository(owner: owner, repo: repo) }
                    ))
                    
                    await send(.issuesResponse(
                        Result { try await gitHubClient.getRepositoryIssues(owner: owner, repo: repo) }
                    ))
                }
                
            case .starButtonTapped:
                guard let owner = state.repositoryOwner,
                      let repo = state.repositoryName else { return .none }
                
                state.isLoadingStarStatus = true
                let newStarState = !state.isStarred
                
                return .run { send in
                    do {
                        if newStarState {
                            try await gitHubClient.starRepository(owner: owner, repo: repo)
                        } else {
                            try await gitHubClient.unstarRepository(owner: owner, repo: repo)
                        }
                        await send(.starToggleResponse(.success(newStarState)))
                    } catch {
                        await send(.starToggleResponse(.failure(error)))
                    }
                }
                
            case .viewWebButtonTapped:
                guard let urlString = state.repository?.htmlURL,
                      let url = URL(string: urlString) else { return .none }
                return .send(.delegate(.openURL(url)))
                
            case .viewIssuesButtonTapped:
                return .send(.delegate(.viewIssuesTapped(state.repositoryId)))
                
            case .viewOwnerButtonTapped:
                guard let owner = state.repositoryOwner else { return .none }
                return .send(.delegate(.viewOwnerTapped(owner)))
                
            case .repositoryResponse(.success(let repository)):
                state.repository = repository
                state.isLoading = false
                return .none
                
            case .repositoryResponse(.failure(let error)):
                state.isLoading = false
                state.alert = AlertState {
                    TextState("Error Loading Repository")
                } message: {
                    TextState(error.localizedDescription)
                }
                return .none
                
            case .starStatusResponse(.success(let isStarred)):
                state.isStarred = isStarred
                state.isLoadingStarStatus = false
                return .none
                
            case .starStatusResponse(.failure):
                // Silently fail star status check
                state.isLoadingStarStatus = false
                return .none
                
            case .issuesResponse(.success(let issues)):
                state.issues = Array(issues.prefix(5)) // Show only first 5 issues
                return .none
                
            case .issuesResponse(.failure):
                // Silently fail issues loading
                return .none
                
            case .starToggleResponse(.success(let isStarred)):
                state.isStarred = isStarred
                state.isLoadingStarStatus = false
                return .none
                
            case .starToggleResponse(.failure(let error)):
                state.isLoadingStarStatus = false
                state.alert = AlertState {
                    TextState("Error")
                } message: {
                    TextState(error.localizedDescription)
                }
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