import SwiftUI

/// Common task status representation across all strategy examples
public enum TaskStatus: Equatable {
  case idle
  case running
  case completed
  case failed(String)
  case blocked
  case rejected(String)
}

/// Common status display helpers
extension TaskStatus {
  var displayText: String {
    switch self {
    case .idle:
      return "Ready"
    case .running:
      return "Running..."
    case .completed:
      return "Completed"
    case .failed(let error):
      return error
    case .blocked:
      return "Already running"
    case .rejected(let reason):
      return reason
    }
  }

  var displayColor: Color {
    switch self {
    case .idle:
      return .secondary
    case .running:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .blocked:
      return .orange
    case .rejected:
      return .orange
    }
  }

  var iconName: String {
    switch self {
    case .idle:
      return "play.circle"
    case .running:
      return "play.circle.fill"
    case .completed:
      return "checkmark.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    case .blocked:
      return "exclamationmark.circle.fill"
    case .rejected:
      return "exclamationmark.circle.fill"
    }
  }

  var iconColor: Color {
    switch self {
    case .idle:
      return .blue
    case .running:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .blocked:
      return .yellow
    case .rejected:
      return .yellow
    }
  }
}
