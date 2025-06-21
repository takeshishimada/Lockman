import ComposableArchitecture
import SwiftUI

@ViewAction(for: SearchFeature.self)
struct SearchView: View {
    @Bindable var store: StoreOf<SearchFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search GitHub...", text: $store.searchQuery.sending(\.view.searchQueryChanged))
                            .textFieldStyle(.plain)
                            .onSubmit {
                                send(.searchButtonTapped)
                            }
                        
                        if !store.searchQuery.isEmpty {
                            Button(action: {
                                send(.clearButtonTapped)
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    if !store.searchQuery.isEmpty {
                        Button("Search") {
                            send(.searchButtonTapped)
                        }
                        .disabled(store.isSearching)
                    }
                }
                .padding()
                
                // Search Type Picker
                Picker("Search Type", selection: Binding(
                    get: { store.selectedType },
                    set: { send(.searchTypeChanged($0)) }
                )) {
                    ForEach(SearchFeature.SearchType.allCases, id: \.self) { type in
                        Label(type.rawValue, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom)
                
                // Results
                if store.isSearching {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if !store.hasSearched {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("Search for repositories or users")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else if store.repositories.isEmpty && store.users.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No results found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Try a different search term")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        if store.selectedType == .repositories {
                            ForEach(store.repositories) { repository in
                                RepositorySearchRow(repository: repository) {
                                    send(.repositoryTapped(repository))
                                }
                            }
                        } else {
                            ForEach(store.users) { user in
                                UserSearchRow(user: user) {
                                    send(.userTapped(user))
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
        }
        .alert($store.scope(state: \.alert, action: \.view.alert))
        .onAppear {
            send(.onAppear)
        }
    }
}

// MARK: - Repository Search Row
struct RepositorySearchRow: View {
    let repository: Repository
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(repository.fullName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if repository.isPrivate {
                        Label("Private", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    }
                    
                    Spacer()
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
                    
                    if repository.isFork {
                        Label("Fork", systemImage: "arrow.triangle.branch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - User Search Row
struct UserSearchRow: View {
    let user: User
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: user.avatarURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray4)
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.login)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let name = user.name {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let bio = user.bio {
                        Text(bio)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}