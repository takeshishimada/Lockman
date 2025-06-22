import Foundation

struct Repository: Equatable, Identifiable {
  let id: Int
  let name: String
  let fullName: String
  let owner: RepositoryOwner
  let description: String?
  let isPrivate: Bool
  let isFork: Bool
  let stargazersCount: Int
  let language: String?
  let htmlURL: String
}

struct RepositoryOwner: Equatable {
  let id: Int
  let login: String
  let avatarURL: String
}
