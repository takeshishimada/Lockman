import SwiftUI

struct UserRow: View {
  let user: User
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        AsyncImage(url: URL(string: user.avatarURL)) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          Circle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
              Image(systemName: "person.fill")
                .foregroundColor(.gray)
            )
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())

        VStack(alignment: .leading, spacing: 4) {
          Text(user.login)
            .font(.headline)
            .foregroundColor(.primary)

          if let name = user.name {
            Text(name)
              .font(.subheadline)
              .foregroundColor(.secondary)
          }

          if let bio = user.bio, !bio.isEmpty {
            Text(bio)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(2)
          }
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 4)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
