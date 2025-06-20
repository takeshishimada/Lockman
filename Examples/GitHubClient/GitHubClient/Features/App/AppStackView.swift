import ComposableArchitecture
import SwiftUI

struct AppStackView: View {
    @Bindable var store: StoreOf<AppStackFeature>
    
    var body: some View {
        NavigationStack(
            path: $store.scope(state: \.path, action: \.path)
        ) {
            TabContainerView(store: store.scope(state: \.tabContainer, action: \.tabContainer))
        } destination: { store in
            switch store.state {
            case .login:
                if let store = store.scope(state: \.login, action: \.login) {
                    LoginView(store: store)
                }
                
            case .repositoryDetail:
                if let store = store.scope(state: \.repositoryDetail, action: \.repositoryDetail) {
                    RepositoryDetailView(store: store)
                }
                
            case .userProfile:
                if let store = store.scope(state: \.userProfile, action: \.userProfile) {
                    UserProfileView(store: store)
                }
                
            case .followerList:
                if let store = store.scope(state: \.followerList, action: \.followerList) {
                    FollowerListView(store: store)
                }
                
            case .followingList:
                if let store = store.scope(state: \.followingList, action: \.followingList) {
                    FollowingListView(store: store)
                }
                
            case .issueDetail:
                if let store = store.scope(state: \.issueDetail, action: \.issueDetail) {
                    IssueDetailView(store: store)
                }
                
            case .issueCreate:
                if let store = store.scope(state: \.issueCreate, action: \.issueCreate) {
                    IssueCreateView(store: store)
                }
                
            case .issueEdit:
                if let store = store.scope(state: \.issueEdit, action: \.issueEdit) {
                    IssueEditView(store: store)
                }
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