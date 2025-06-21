import ComposableArchitecture
import SwiftUI

@ViewAction(for: ProfileFeature.self)
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    
    var body: some View {
        NavigationStack {
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
                        ProfileHeaderView(
                            user: user,
                            followersCount: store.followersCount,
                            followingCount: store.followingCount,
                            onFollowersTapped: { send(.followersTapped) },
                            onFollowingTapped: { send(.followingTapped) }
                        )
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Stats Section
                        StatsSection(repositoryCount: store.repositories.count) {
                            send(.repositoriesTapped)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                        
                        // Recent Repositories
                        if !store.repositories.isEmpty {
                            RecentRepositoriesSection(repositories: Array(store.repositories.prefix(5)))
                                .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .refreshable {
                await send(.pullToRefresh).finish()
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        send(.settingsButtonTapped)
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.view.alert))
        .onAppear {
            send(.onAppear)
        }
    }
}

// MARK: - Profile Header View
struct ProfileHeaderView: View {
    let user: User
    let followersCount: Int
    let followingCount: Int
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
            }
            
            // Bio
            if let bio = user.bio {
                Text(bio)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Stats Section
struct StatsSection: View {
    let repositoryCount: Int
    let onRepositoriesTapped: () -> Void
    
    var body: some View {
        Button(action: onRepositoriesTapped) {
            HStack {
                Label("\(repositoryCount) Repositories", systemImage: "folder")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Repositories Section
struct RecentRepositoriesSection: View {
    let repositories: [Repository]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Repositories")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(repositories) { repository in
                    RecentRepositoryRow(repository: repository)
                }
            }
        }
    }
}

// MARK: - Recent Repository Row
struct RecentRepositoryRow: View {
    let repository: Repository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repository.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if repository.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .labelStyle(.iconOnly)
                }
                
                Spacer()
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
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}