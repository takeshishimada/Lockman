import ComposableArchitecture
import SwiftUI

struct TabContainerView: View {
  @Bindable var store: StoreOf<TabContainerFeature>

  var body: some View {
    TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
      HomeView(store: store.scope(state: \.home, action: \.home))
        .tabItem {
          Label(
            TabContainerFeature.Tab.home.title,
            systemImage: TabContainerFeature.Tab.home.systemImage)
        }
        .tag(TabContainerFeature.Tab.home)

      SearchView(store: store.scope(state: \.search, action: \.search))
        .tabItem {
          Label(
            TabContainerFeature.Tab.search.title,
            systemImage: TabContainerFeature.Tab.search.systemImage)
        }
        .tag(TabContainerFeature.Tab.search)

      IssuesView(store: store.scope(state: \.issues, action: \.issues))
        .tabItem {
          Label(
            TabContainerFeature.Tab.issues.title,
            systemImage: TabContainerFeature.Tab.issues.systemImage)
        }
        .tag(TabContainerFeature.Tab.issues)

      ProfileView(store: store.scope(state: \.profile, action: \.profile))
        .tabItem {
          Label(
            TabContainerFeature.Tab.profile.title,
            systemImage: TabContainerFeature.Tab.profile.systemImage)
        }
        .tag(TabContainerFeature.Tab.profile)
    }
  }
}
