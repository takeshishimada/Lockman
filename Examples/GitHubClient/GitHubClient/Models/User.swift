import Foundation

struct User: Equatable, Identifiable, Codable {
    let id: Int
    let login: String
    let name: String?
    let avatarURL: String
    let bio: String?
    let createdAt: Date
    let updatedAt: Date
}