import ComposableArchitecture
import SwiftUI

struct FollowingListView: View {
  @Bindable var store: StoreOf<FollowingListFeature>

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      Group {
        if viewStore.isLoading && viewStore.following.isEmpty {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewStore.following.isEmpty {
          ContentUnavailableView(
            "Not Following Anyone",
            systemImage: "person.3",
            description: Text("\(viewStore.username) isn't following anyone yet")
          )
        } else {
          List {
            ForEach(viewStore.following) { user in
              UserRow(user: user) {
                store.send(.view(.userTapped(user)))
              }
            }
          }
          .refreshable {
            await store.send(.view(.pullToRefresh)).finish()
          }
        }
      }
      .navigationTitle("Following")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            store.send(.view(.refreshButtonTapped))
          } label: {
            Image(systemName: "arrow.clockwise")
          }
          .disabled(viewStore.isLoading)
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert($store.scope(state: \.alert, action: \.view.alert))
    }
  }
}
