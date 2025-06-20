import ComposableArchitecture

@Reducer
struct IssueEditFeature {
    @ObservableState
    struct State: Equatable {
        let issueId: String
    }
    
    enum Action {
        case onAppear
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            }
        }
    }
}