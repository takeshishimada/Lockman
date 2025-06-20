import ComposableArchitecture

@Reducer
struct IssueCreateFeature {
    @ObservableState
    struct State: Equatable {}
    
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