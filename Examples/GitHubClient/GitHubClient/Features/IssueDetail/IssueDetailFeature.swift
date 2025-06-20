import ComposableArchitecture

@Reducer
struct IssueDetailFeature {
    @ObservableState
    struct State: Equatable {
        let issueId: String
    }
    
    enum Action {
        case onAppear
        case editButtonTapped
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case editTapped(String)
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .editButtonTapped:
                return .send(.delegate(.editTapped(state.issueId)))
                
            case .delegate:
                return .none
            }
        }
    }
}