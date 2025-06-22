import Dependencies
import Foundation

// MARK: - GitHubClient Protocol
protocol GitHubClientProtocol {
  func authenticate(token: String) async throws -> User
  func getCurrentUser() async throws -> User
  func getMyRepositories() async throws -> [Repository]
  func getStarredRepositories() async throws -> [Repository]
  func searchRepositories(query: String) async throws -> [Repository]
  func searchUsers(query: String) async throws -> [User]
  func getMyIssues() async throws -> [Issue]
  func getRepositoryIssues(owner: String, repo: String) async throws -> [Issue]
  func getUserProfile(username: String) async throws -> User
  func getFollowers(username: String) async throws -> [User]
  func getFollowing(username: String) async throws -> [User]
  func getRepository(owner: String, repo: String) async throws -> Repository
  func checkIfStarred(owner: String, repo: String) async throws -> Bool
  func starRepository(owner: String, repo: String) async throws
  func unstarRepository(owner: String, repo: String) async throws
  func getUserRepositories(username: String) async throws -> [Repository]
}

// MARK: - GitHubClient Errors
enum GitHubClientError: Error, LocalizedError {
  case notAuthenticated
  case apiError(Error)
  case invalidToken
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .notAuthenticated:
      return "Not authenticated. Please login first."
    case .apiError(let error):
      return "API Error: \(error.localizedDescription)"
    case .invalidToken:
      return "Invalid token. Please check your personal access token."
    case .invalidResponse:
      return "Invalid response from GitHub API."
    }
  }
}

// MARK: - Dependency Value
enum GitHubClientKey: DependencyKey {
  static let liveValue: GitHubClientProtocol = MockGitHubClient()
  static let testValue: GitHubClientProtocol = MockGitHubClient()
}

extension DependencyValues {
  var gitHubClient: GitHubClientProtocol {
    get { self[GitHubClientKey.self] }
    set { self[GitHubClientKey.self] = newValue }
  }
}

// MARK: - Mock Implementation
final class MockGitHubClient: GitHubClientProtocol {
  func authenticate(token: String) async throws -> User {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 1_000_000_000)

    if token == "invalid" {
      throw GitHubClientError.invalidToken
    }

    return User(
      id: 1,
      login: "testuser",
      name: "Test User",
      avatarURL: "https://avatars.githubusercontent.com/u/1?v=4",
      bio: "Test bio",
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  func getCurrentUser() async throws -> User {
    return try await authenticate(token: "mock")
  }

  func getMyRepositories() async throws -> [Repository] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return [
      Repository(
        id: 1,
        name: "awesome-project",
        fullName: "testuser/awesome-project",
        owner: RepositoryOwner(
          id: 1, login: "testuser", avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"),
        description: "An awesome project written in Swift",
        isPrivate: false,
        isFork: false,
        stargazersCount: 42,
        language: "Swift",
        htmlURL: "https://github.com/testuser/awesome-project"
      ),
      Repository(
        id: 2,
        name: "learning-swift",
        fullName: "testuser/learning-swift",
        owner: RepositoryOwner(
          id: 1, login: "testuser", avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"),
        description: "My journey learning Swift",
        isPrivate: true,
        isFork: false,
        stargazersCount: 0,
        language: "Swift",
        htmlURL: "https://github.com/testuser/learning-swift"
      ),
    ]
  }

  func getStarredRepositories() async throws -> [Repository] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return [
      Repository(
        id: 100,
        name: "swift",
        fullName: "apple/swift",
        owner: RepositoryOwner(
          id: 10_742_959, login: "apple",
          avatarURL: "https://avatars.githubusercontent.com/u/10742959?v=4"),
        description: "The Swift Programming Language",
        isPrivate: false,
        isFork: false,
        stargazersCount: 65000,
        language: "C++",
        htmlURL: "https://github.com/apple/swift"
      ),
      Repository(
        id: 101,
        name: "swift-composable-architecture",
        fullName: "pointfreeco/swift-composable-architecture",
        owner: RepositoryOwner(
          id: 1_234_567, login: "pointfreeco",
          avatarURL: "https://avatars.githubusercontent.com/u/1234567?v=4"),
        description: "A library for building applications in a consistent and understandable way",
        isPrivate: false,
        isFork: false,
        stargazersCount: 10000,
        language: "Swift",
        htmlURL: "https://github.com/pointfreeco/swift-composable-architecture"
      ),
    ]
  }

  func searchRepositories(query: String) async throws -> [Repository] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    guard !query.isEmpty else { return [] }

    // Mock search results
    return [
      Repository(
        id: 200,
        name: "search-result-1",
        fullName: "user1/search-result-1",
        owner: RepositoryOwner(
          id: 200, login: "user1", avatarURL: "https://avatars.githubusercontent.com/u/200?v=4"),
        description: "First search result matching: \(query)",
        isPrivate: false,
        isFork: false,
        stargazersCount: 100,
        language: "Swift",
        htmlURL: "https://github.com/user1/search-result-1"
      ),
      Repository(
        id: 201,
        name: "search-result-2",
        fullName: "user2/search-result-2",
        owner: RepositoryOwner(
          id: 201, login: "user2", avatarURL: "https://avatars.githubusercontent.com/u/201?v=4"),
        description: "Second search result for: \(query)",
        isPrivate: false,
        isFork: true,
        stargazersCount: 50,
        language: "JavaScript",
        htmlURL: "https://github.com/user2/search-result-2"
      ),
    ]
  }

  func searchUsers(query: String) async throws -> [User] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    guard !query.isEmpty else { return [] }

    // Mock user search results
    return [
      User(
        id: 300,
        login: "searchuser1",
        name: "Search User 1",
        avatarURL: "https://avatars.githubusercontent.com/u/300?v=4",
        bio: "Developer matching query: \(query)",
        createdAt: Date(),
        updatedAt: Date()
      ),
      User(
        id: 301,
        login: "searchuser2",
        name: "Search User 2",
        avatarURL: "https://avatars.githubusercontent.com/u/301?v=4",
        bio: "Another developer for: \(query)",
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

  func getMyIssues() async throws -> [Issue] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return [
      Issue(
        id: 1,
        number: 42,
        title: "Fix memory leak in HomeView",
        body: "There's a memory leak when navigating away from HomeView",
        state: .open,
        author: IssueAuthor(
          id: 1, login: "testuser", avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"),
        createdAt: Date().addingTimeInterval(-86400),
        updatedAt: Date().addingTimeInterval(-3600),
        closedAt: nil,
        repository: IssueRepository(
          id: 1, name: "awesome-project", fullName: "testuser/awesome-project"),
        labels: [
          IssueLabel(id: 1, name: "bug", color: "d73a4a", description: "Something isn't working"),
          IssueLabel(
            id: 2, name: "high priority", color: "e99695", description: "High priority issue"),
        ],
        commentsCount: 3
      ),
      Issue(
        id: 2,
        number: 43,
        title: "Add dark mode support",
        body: "Users have requested dark mode support for the app",
        state: .open,
        author: IssueAuthor(
          id: 2, login: "contributor", avatarURL: "https://avatars.githubusercontent.com/u/2?v=4"),
        createdAt: Date().addingTimeInterval(-172800),
        updatedAt: Date().addingTimeInterval(-7200),
        closedAt: nil,
        repository: IssueRepository(
          id: 1, name: "awesome-project", fullName: "testuser/awesome-project"),
        labels: [
          IssueLabel(
            id: 3, name: "enhancement", color: "a2eeef", description: "New feature or request")
        ],
        commentsCount: 10
      ),
      Issue(
        id: 3,
        number: 40,
        title: "Update documentation",
        body: "The README needs to be updated with new API changes",
        state: .closed,
        author: IssueAuthor(
          id: 1, login: "testuser", avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"),
        createdAt: Date().addingTimeInterval(-259200),
        updatedAt: Date().addingTimeInterval(-172800),
        closedAt: Date().addingTimeInterval(-172800),
        repository: IssueRepository(
          id: 2, name: "learning-swift", fullName: "testuser/learning-swift"),
        labels: [
          IssueLabel(
            id: 4, name: "documentation", color: "0075ca",
            description: "Improvements or additions to documentation")
        ],
        commentsCount: 1
      ),
    ]
  }

  func getRepositoryIssues(owner: String, repo: String) async throws -> [Issue] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    // Return filtered mock issues based on repo
    let allIssues = try await getMyIssues()
    return allIssues.filter { $0.repository.fullName == "\(owner)/\(repo)" }
  }

  func getUserProfile(username: String) async throws -> User {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return User(
      id: 1,
      login: username,
      name: "Test User",
      avatarURL: "https://avatars.githubusercontent.com/u/1?v=4",
      bio: "Software developer who loves Swift and open source",
      createdAt: Date().addingTimeInterval(-31_536_000),  // 1 year ago
      updatedAt: Date()
    )
  }

  func getFollowers(username: String) async throws -> [User] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return [
      User(
        id: 100,
        login: "follower1",
        name: "Follower One",
        avatarURL: "https://avatars.githubusercontent.com/u/100?v=4",
        bio: "Following \(username)",
        createdAt: Date(),
        updatedAt: Date()
      ),
      User(
        id: 101,
        login: "follower2",
        name: "Follower Two",
        avatarURL: "https://avatars.githubusercontent.com/u/101?v=4",
        bio: "Also following \(username)",
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

  func getFollowing(username: String) async throws -> [User] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    return [
      User(
        id: 200,
        login: "following1",
        name: "Following One",
        avatarURL: "https://avatars.githubusercontent.com/u/200?v=4",
        bio: "\(username) is following this user",
        createdAt: Date(),
        updatedAt: Date()
      ),
      User(
        id: 201,
        login: "following2",
        name: "Following Two",
        avatarURL: "https://avatars.githubusercontent.com/u/201?v=4",
        bio: "\(username) is also following this user",
        createdAt: Date(),
        updatedAt: Date()
      ),
    ]
  }

  func getRepository(owner: String, repo: String) async throws -> Repository {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    // Return a mock repository based on the input
    return Repository(
      id: 1,
      name: repo,
      fullName: "\(owner)/\(repo)",
      owner: RepositoryOwner(
        id: 1, login: owner, avatarURL: "https://avatars.githubusercontent.com/u/1?v=4"),
      description:
        "This is a detailed description of the \(repo) repository. It's an awesome project that does amazing things with Swift.",
      isPrivate: false,
      isFork: false,
      stargazersCount: 1337,
      language: "Swift",
      htmlURL: "https://github.com/\(owner)/\(repo)"
    )
  }

  func checkIfStarred(owner: String, repo: String) async throws -> Bool {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 200_000_000)

    // For mock, check if it's one of our "starred" repos
    let starredRepos = ["apple/swift", "pointfreeco/swift-composable-architecture"]
    return starredRepos.contains("\(owner)/\(repo)")
  }

  func starRepository(owner: String, repo: String) async throws {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 300_000_000)

    // Mock implementation - just succeed
    return
  }

  func unstarRepository(owner: String, repo: String) async throws {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 300_000_000)

    // Mock implementation - just succeed
    return
  }

  func getUserRepositories(username: String) async throws -> [Repository] {
    // Simulate network delay
    try await Task.sleep(nanoseconds: 500_000_000)

    // Return mock repositories for the user
    return [
      Repository(
        id: 1000,
        name: "\(username)-project",
        fullName: "\(username)/\(username)-project",
        owner: RepositoryOwner(
          id: 1000, login: username, avatarURL: "https://avatars.githubusercontent.com/u/1000?v=4"),
        description: "Main project by \(username)",
        isPrivate: false,
        isFork: false,
        stargazersCount: Int.random(in: 10...500),
        language: "Swift",
        htmlURL: "https://github.com/\(username)/\(username)-project"
      ),
      Repository(
        id: 1001,
        name: "\(username)-experiments",
        fullName: "\(username)/\(username)-experiments",
        owner: RepositoryOwner(
          id: 1000, login: username, avatarURL: "https://avatars.githubusercontent.com/u/1000?v=4"),
        description: "Experimental code by \(username)",
        isPrivate: false,
        isFork: false,
        stargazersCount: Int.random(in: 0...50),
        language: "Python",
        htmlURL: "https://github.com/\(username)/\(username)-experiments"
      ),
    ]
  }
}
