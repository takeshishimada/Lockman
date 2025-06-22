import ComposableArchitecture

@Reducer
struct TabContainerFeature {
  enum Tab: String, CaseIterable {
    case home
    case search
    case issues
    case profile

    var title: String {
      switch self {
      case .home: return "Home"
      case .search: return "Search"
      case .issues: return "Issues"
      case .profile: return "Profile"
      }
    }

    var systemImage: String {
      switch self {
      case .home: return "house"
      case .search: return "magnifyingglass"
      case .issues: return "exclamationmark.circle"
      case .profile: return "person.circle"
      }
    }
  }

  @ObservableState
  struct State: Equatable {
    var selectedTab: Tab = .home
    var home = HomeFeature.State()
    var search = SearchFeature.State()
    var issues = IssuesFeature.State()
    var profile = ProfileFeature.State()
  }

  enum Action {
    case tabSelected(Tab)
    case home(HomeFeature.Action)
    case search(SearchFeature.Action)
    case issues(IssuesFeature.Action)
    case profile(ProfileFeature.Action)
    case delegate(Delegate)

    enum Delegate: Equatable {
      case repositoryTapped(String)
      case userTapped(String)
      case issueTapped(String)
      case createIssueTapped
      case settingsTapped
      case authenticationError
      case repositoriesTapped
      case followersTapped(username: String)
      case followingTapped(username: String)
    }
  }

  var body: some ReducerOf<Self> {
    Scope(state: \.home, action: \.home) {
      HomeFeature()
    }

    Scope(state: \.search, action: \.search) {
      SearchFeature()
    }

    Scope(state: \.issues, action: \.issues) {
      IssuesFeature()
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }

    Reduce { state, action in
      switch action {
      case .tabSelected(let tab):
        state.selectedTab = tab
        return .none

      case .home(.delegate(let action)):
        switch action {
        case .repositoryTapped(let id):
          return .send(.delegate(.repositoryTapped(id)))
        case .authenticationError:
          return .send(.delegate(.authenticationError))
        }

      case .search(.delegate(let action)):
        switch action {
        case .repositoryTapped(let id):
          return .send(.delegate(.repositoryTapped(id)))
        case .userTapped(let username):
          return .send(.delegate(.userTapped(username)))
        case .authenticationError:
          return .send(.delegate(.authenticationError))
        }

      case .issues(.delegate(let action)):
        switch action {
        case .issueTapped(let id):
          return .send(.delegate(.issueTapped(id)))
        case .createIssueTapped:
          return .send(.delegate(.createIssueTapped))
        case .authenticationError:
          return .send(.delegate(.authenticationError))
        }

      case .profile(.delegate(let action)):
        switch action {
        case .settingsTapped:
          return .send(.delegate(.settingsTapped))
        case .authenticationError:
          return .send(.delegate(.authenticationError))
        case .repositoriesTapped:
          return .send(.delegate(.repositoriesTapped))
        case .followersTapped(let username):
          return .send(.delegate(.followersTapped(username: username)))
        case .followingTapped(let username):
          return .send(.delegate(.followingTapped(username: username)))
        }

      case .home, .search, .issues, .profile:
        return .none

      case .delegate:
        return .none
      }
    }
  }
}
