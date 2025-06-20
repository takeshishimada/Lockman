import ComposableArchitecture
import SwiftUI

struct HomeView: View {
    @Bindable var store: StoreOf<HomeFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segment Control
                Picker("Repository Type", selection: $store.selectedType.sending(\.segmentChanged)) {
                    ForEach(HomeFeature.RepositoryType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Repository List
                if store.isLoading && store.repositories.isEmpty {
                    Spacer()
                    ProgressView("Loading repositories...")
                    Spacer()
                } else if store.repositories.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No repositories found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.repositories) { repository in
                            RepositoryRow(repository: repository) {
                                store.send(.repositoryTapped(repository))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await store.send(.pullToRefresh).finish()
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        store.send(.refreshButtonTapped)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - Repository Row
struct RepositoryRow: View {
    let repository: Repository
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(repository.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if repository.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    }
                    
                    Spacer()
                    
                    if repository.isFork {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let description = repository.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 16) {
                    if let language = repository.language {
                        Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Label("\(repository.stargazersCount)", systemImage: "star")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

