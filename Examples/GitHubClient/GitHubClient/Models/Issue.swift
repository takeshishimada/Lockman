import Foundation

struct Issue: Equatable, Identifiable {
  let id: Int
  let number: Int
  var title: String
  var body: String?
  var state: IssueState
  let author: IssueAuthor
  let createdAt: Date
  var updatedAt: Date
  var closedAt: Date?
  let repository: IssueRepository
  var labels: [IssueLabel]
  let commentsCount: Int
}

enum IssueState: String, Equatable {
  case open
  case closed
}

struct IssueAuthor: Equatable {
  let id: Int
  let login: String
  let avatarURL: String
}

struct IssueRepository: Equatable {
  let id: Int
  let name: String
  let fullName: String
}

struct IssueLabel: Equatable, Identifiable {
  let id: Int
  let name: String
  let color: String
  let description: String?
}
