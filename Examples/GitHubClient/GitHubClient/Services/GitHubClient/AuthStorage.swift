import Foundation

// MARK: - Auth State
struct AuthState: Codable, Equatable {
  var token: String?
  var user: AuthUser?

  var isAuthenticated: Bool {
    token != nil && user != nil
  }
}

// MARK: - Codable User
struct AuthUser: Codable, Equatable {
  let id: Int
  let login: String
  let name: String?
  let avatarURL: String
}

extension User {
  var authUser: AuthUser {
    AuthUser(
      id: id,
      login: login,
      name: name,
      avatarURL: avatarURL
    )
  }
}
