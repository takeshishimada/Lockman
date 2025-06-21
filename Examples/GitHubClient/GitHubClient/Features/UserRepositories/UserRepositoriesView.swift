import ComposableArchitecture
import SwiftUI

struct UserRepositoriesView: View {
    @Bindable var store: StoreOf<UserRepositoriesFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Group {
                if viewStore.isLoading && viewStore.repositories.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewStore.repositories) { repository in
                            RepositoryRow(repository: repository) {
                                store.send(.view(.repositoryTapped(repository)))
                            }
                        }
                    }
                    .refreshable {
                        await store.send(.view(.pullToRefresh)).finish()
                    }
                }
            }
            .navigationTitle("Repositories")
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