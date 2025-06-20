import ComposableArchitecture
import SwiftUI

struct UserProfileView: View {
    @Bindable var store: StoreOf<UserProfileFeature>
    
    var body: some View {
        ScrollView {
            if store.isLoading && store.user == nil {
                VStack {
                    Spacer(minLength: 100)
                    ProgressView("Loading profile...")
                    Spacer(minLength: 100)
                }
            } else if let user = store.user {
                VStack(spacing: 20) {
                    // Profile Header
                    UserProfileHeaderView(
                        user: user,
                        followersCount: store.followersCount,
                        followingCount: store.followingCount,
                        isCurrentUser: store.isCurrentUser,
                        onFollowersTapped: { store.send(.followersButtonTapped) },
                        onFollowingTapped: { store.send(.followingButtonTapped) }
                    )
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Repositories Section
                    if !store.repositories.isEmpty {
                        UserRepositoriesSection(
                            repositories: store.repositories,
                            onRepositoryTapped: { repository in
                                store.send(.repositoryTapped(repository))
                            },
                            onViewAllTapped: {
                                store.send(.viewAllRepositoriesButtonTapped)
                            }
                        )
                        .padding(.horizontal)
                    } else if store.isLoadingRepos {
                        VStack {
                            ProgressView("Loading repositories...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("No public repositories")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(store.user?.login ?? store.username)
        .navigationBarTitleDisplayMode(.inline)
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
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear {
            store.send(.onAppear)
        }
    }
}

// MARK: - User Profile Header View
struct UserProfileHeaderView: View {
    let user: User
    let followersCount: Int
    let followingCount: Int
    let isCurrentUser: Bool
    let onFollowersTapped: () -> Void
    let onFollowingTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar
            AsyncImage(url: URL(string: user.avatarURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray4)
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
            
            // Name and Username
            VStack(spacing: 4) {
                if let name = user.name {
                    Text(name)
                        .font(.title2)
                        .bold()
                }
                Text("@\(user.login)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                if isCurrentUser {
                    Label("You", systemImage: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }
            
            // Bio
            if let bio = user.bio {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Member Since
            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Member since \(user.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Followers/Following
            HStack(spacing: 40) {
                Button(action: onFollowersTapped) {
                    VStack(spacing: 4) {
                        Text("\(followersCount)")
                            .font(.headline)
                        Text("Followers")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: onFollowingTapped) {
                    VStack(spacing: 4) {
                        Text("\(followingCount)")
                            .font(.headline)
                        Text("Following")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - User Repositories Section
struct UserRepositoriesSection: View {
    let repositories: [Repository]
    let onRepositoryTapped: (Repository) -> Void
    let onViewAllTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Public Repositories")
                    .font(.headline)
                Spacer()
                Button("View All", action: onViewAllTapped)
                    .font(.caption)
            }
            
            VStack(spacing: 8) {
                ForEach(repositories.prefix(3)) { repository in
                    Button(action: { onRepositoryTapped(repository) }) {
                        UserRepositoryRow(repository: repository)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - User Repository Row
struct UserRepositoryRow: View {
    let repository: Repository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repository.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                if repository.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.iconOnly)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let description = repository.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                if let language = repository.language {
                    Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Label("\(repository.stargazersCount)", systemImage: "star")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if repository.isFork {
                    Label("Fork", systemImage: "arrow.triangle.branch")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}