import ComposableArchitecture
import SwiftUI

struct AppStackView: View {
  @Bindable var store: StoreOf<AppStackFeature>

  var body: some View {
    NavigationStackStore(
      store.scope(state: \.path, action: \.path)
    ) {
      TabContainerView(store: store.scope(state: \.tabContainer, action: \.tabContainer))
    } destination: { store in
      switch store.case {
      case let .login(store):
        LoginView(store: store)

      case let .repositoryDetail(store):
        RepositoryDetailView(store: store)

      case let .userProfile(store):
        UserProfileView(store: store)

      case let .followerList(store):
        FollowerListView(store: store)

      case let .followingList(store):
        FollowingListView(store: store)

      case let .userRepositories(store):
        UserRepositoriesView(store: store)

      case let .issueDetail(store):
        IssueDetailView(store: store)

      case let .issueCreate(store):
        IssueCreateView(store: store)

      case let .issueEdit(store):
        IssueEditView(store: store)
      }
    }
    .sheet(
      item: $store.scope(state: \.settings, action: \.settings)
    ) { store in
      NavigationStack {
        SettingsView(store: store)
      }
    }
    .onAppear {
      store.send(.onAppear)
    }
  }
}
