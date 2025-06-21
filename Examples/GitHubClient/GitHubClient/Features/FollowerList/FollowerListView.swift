import ComposableArchitecture
import SwiftUI

struct FollowerListView: View {
    @Bindable var store: StoreOf<FollowerListFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isLoading && viewStore.followers.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewStore.followers.isEmpty {
                    ContentUnavailableView(
                        "No Followers",
                        systemImage: "person.3",
                        description: Text("\(viewStore.username) doesn't have any followers yet")
                    )
                } else {
                    List {
                        ForEach(viewStore.followers) { user in
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
            .navigationTitle("Followers")
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