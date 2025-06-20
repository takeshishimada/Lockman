import ComposableArchitecture
import SwiftUI

@ViewAction(for: RepositoryDetailFeature.self)
struct RepositoryDetailView: View {
    @Bindable var store: StoreOf<RepositoryDetailFeature>
    
    var body: some View {
        ScrollView {
            if store.isLoading && store.repository == nil {
                VStack {
                    Spacer(minLength: 100)
                    ProgressView("Loading repository...")
                    Spacer(minLength: 100)
                }
            } else if let repository = store.repository {
                VStack(spacing: 20) {
                    // Repository Header
                    RepositoryHeaderSection(
                        repository: repository,
                        isStarred: store.isStarred,
                        isLoadingStarStatus: store.isLoadingStarStatus,
                        onStarTapped: { send(.starButtonTapped) },
                        onOwnerTapped: { send(.viewOwnerButtonTapped) }
                    )
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Repository Stats
                    RepositoryStatsSection(repository: repository)
                        .padding(.horizontal)
                    
                    Divider()
                    
                    // Action Buttons
                    ActionButtonsSection(
                        onViewWeb: { send(.viewWebButtonTapped) },
                        onViewIssues: { send(.viewIssuesButtonTapped) }
                    )
                    .padding(.horizontal)
                    
                    if !store.issues.isEmpty {
                        Divider()
                        
                        // Recent Issues
                        RecentIssuesSection(issues: store.issues) {
                            send(.viewIssuesButtonTapped)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .navigationTitle(store.repository?.name ?? "Repository")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    send(.refreshButtonTapped)
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .alert($store.scope(state: \.alert, action: \.view.alert))
        .onAppear {
            send(.onAppear)
        }
    }
}

// MARK: - Repository Header Section
struct RepositoryHeaderSection: View {
    let repository: Repository
    let isStarred: Bool
    let isLoadingStarStatus: Bool
    let onStarTapped: () -> Void
    let onOwnerTapped: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Repository Name and Owner
            HStack {
                Button(action: onOwnerTapped) {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: repository.owner.avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.systemGray4)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        
                        Text(repository.owner.login)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Text("/")
                    .foregroundStyle(.secondary)
                
                Text(repository.name)
                    .font(.headline)
            }
            
            // Description
            if let description = repository.description {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Language and Privacy
            HStack(spacing: 16) {
                if let language = repository.language {
                    Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if repository.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if repository.isFork {
                    Label("Fork", systemImage: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Star Button
                Button(action: onStarTapped) {
                    if isLoadingStarStatus {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Label(isStarred ? "Starred" : "Star", systemImage: isStarred ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundStyle(isStarred ? .yellow : .primary)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isLoadingStarStatus)
            }
        }
    }
}

// MARK: - Repository Stats Section
struct RepositoryStatsSection: View {
    let repository: Repository
    
    var body: some View {
        HStack(spacing: 40) {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.caption)
                    Text("\(repository.stargazersCount)")
                        .font(.headline)
                }
                Text("Stars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    let onViewWeb: () -> Void
    let onViewIssues: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onViewWeb) {
                Label("View on GitHub", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Button(action: onViewIssues) {
                Label("View All Issues", systemImage: "exclamationmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }
}

// MARK: - Recent Issues Section
struct RecentIssuesSection: View {
    let issues: [Issue]
    let onViewAll: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Issues")
                    .font(.headline)
                Spacer()
                Button("View All", action: onViewAll)
                    .font(.caption)
            }
            
            VStack(spacing: 8) {
                ForEach(issues) { issue in
                    RecentIssueRow(issue: issue)
                }
            }
        }
    }
}

// MARK: - Recent Issue Row
struct RecentIssueRow: View {
    let issue: Issue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: issue.state == .open ? "circle.circle" : "checkmark.circle.fill")
                    .foregroundStyle(issue.state == .open ? .green : .purple)
                    .font(.caption)
                
                Text(issue.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Spacer()
                
                Text("#\(issue.number)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text(issue.author.login)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if issue.commentsCount > 0 {
                    Label("\(issue.commentsCount)", systemImage: "bubble.right")
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