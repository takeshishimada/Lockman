import ComposableArchitecture
import Dependencies

@Reducer
struct SearchFeature {
    enum SearchType: String, CaseIterable {
        case repositories = "Repositories"
        case users = "Users"
        
        var systemImage: String {
            switch self {
            case .repositories: return "folder"
            case .users: return "person"
            }
        }
    }
    
    @ObservableState
    struct State: Equatable {
        var searchQuery = ""
        var selectedType: SearchType = .repositories
        var repositories: [Repository] = []
        var users: [User] = []
        var isSearching = false
        var hasSearched = false
        @Presents var alert: AlertState<Action.ViewAction.Alert>?
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        case delegate(Delegate)
        
        @CasePathable
        enum ViewAction {
            case onAppear
            case searchQueryChanged(String)
            case searchTypeChanged(SearchType)
            case searchButtonTapped
            case clearButtonTapped
            case repositoryTapped(Repository)
            case userTapped(User)
            case alert(PresentationAction<Alert>)
            
            enum Alert: Equatable {}
        }
        
        enum InternalAction {
            case searchRepositoriesResponse(Result<[Repository], Error>)
            case searchUsersResponse(Result<[User], Error>)
        }
        
        enum Delegate: Equatable {
            case repositoryTapped(String)
            case userTapped(String)
            case authenticationError
        }
    }
    
    @Dependency(\.gitHubClient) var gitHubClient
    
    private enum CancelID {
        case search
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    return .none
                    
                case .searchQueryChanged(let query):
                    state.searchQuery = query
                    return .none
                    
                case .searchTypeChanged(let type):
                    state.selectedType = type
                    // Clear results when switching types
                    if state.hasSearched {
                        return .send(.view(.searchButtonTapped))
                    }
                    return .none
                    
                case .searchButtonTapped:
                    guard !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        return .none
                    }
                    
                    state.isSearching = true
                    state.hasSearched = true
                    
                    switch state.selectedType {
                    case .repositories:
                        return .run { [query = state.searchQuery] send in
                            await send(.internal(.searchRepositoriesResponse(
                                Result { try await gitHubClient.searchRepositories(query: query) }
                            )))
                        }
                        .cancellable(id: CancelID.search)
                        
                    case .users:
                        return .run { [query = state.searchQuery] send in
                            await send(.internal(.searchUsersResponse(
                                Result { try await gitHubClient.searchUsers(query: query) }
                            )))
                        }
                        .cancellable(id: CancelID.search)
                    }
                    
                case .clearButtonTapped:
                    state.searchQuery = ""
                    state.repositories = []
                    state.users = []
                    state.hasSearched = false
                    return .cancel(id: CancelID.search)
                    
                case .repositoryTapped(let repository):
                    return .send(.delegate(.repositoryTapped(repository.fullName)))
                    
                case .userTapped(let user):
                    return .send(.delegate(.userTapped(user.login)))
                    
                case .alert:
                    return .none
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .searchRepositoriesResponse(.success(let repositories)):
                    state.repositories = repositories
                    state.users = []
                    state.isSearching = false
                    return .none
                    
                case .searchRepositoriesResponse(.failure(let error)):
                    state.isSearching = false
                    
                    // Check if it's an authentication error
                    if case GitHubClientError.notAuthenticated = error {
                        return .send(.delegate(.authenticationError))
                    }
                    
                    state.alert = AlertState {
                        TextState("Search Error")
                    } message: {
                        TextState(error.localizedDescription)
                    }
                    return .none
                    
                case .searchUsersResponse(.success(let users)):
                    state.users = users
                    state.repositories = []
                    state.isSearching = false
                    return .none
                    
                case .searchUsersResponse(.failure(let error)):
                    state.isSearching = false
                    
                    // Check if it's an authentication error
                    if case GitHubClientError.notAuthenticated = error {
                        return .send(.delegate(.authenticationError))
                    }
                    
                    state.alert = AlertState {
                        TextState("Search Error")
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