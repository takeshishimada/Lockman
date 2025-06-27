/// Represents the concurrency limit for an action.
public enum LockmanConcurrencyLimit: Sendable, Equatable {
  /// No limit on concurrent executions.
  case unlimited
  /// Limited to a specific number of concurrent executions.
  case limited(Int)

  /// Returns the maximum number of concurrent executions allowed.
  /// - Returns: `nil` for unlimited, or the specific limit value.
  public var maxConcurrency: Int? {
    switch self {
    case .unlimited:
      return nil
    case .limited(let value):
      return value
    }
  }

  /// Checks if the current count exceeds the limit.
  /// - Parameter currentCount: The current number of concurrent executions.
  /// - Returns: `true` if the limit is exceeded, `false` otherwise.
  public func isExceeded(currentCount: Int) -> Bool {
    switch self {
    case .unlimited:
      return false
    case .limited(let limit):
      return currentCount >= limit
    }
  }
}

extension LockmanConcurrencyLimit: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .unlimited:
      return "unlimited"
    case .limited(let value):
      return "limited(\(value))"
    }
  }
}
