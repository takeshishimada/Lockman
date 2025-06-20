import ComposableArchitecture

@Reducer
struct FollowingListFeature {
    @ObservableState
    struct State: Equatable {
        let username: String
    }
    
    enum Action {
        case onAppear
        case userTapped
        case delegate(Delegate)
        
        enum Delegate: Equatable {
            case userTapped(String)
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .userTapped:
                // Placeholder for following username
                return .send(.delegate(.userTapped("following-username")))
                
            case .delegate:
                return .none
            }
        }
    }
}