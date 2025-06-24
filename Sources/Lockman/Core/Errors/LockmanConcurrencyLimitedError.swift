import Foundation

/// Errors specific to concurrency-limited locking.
public enum LockmanConcurrencyLimitedError: LockmanError {
  /// The concurrency limit has been reached.
  case concurrencyLimitReached(concurrencyId: String, limit: Int, current: Int)

  public var errorDescription: String? {
    switch self {
    case let .concurrencyLimitReached(concurrencyId, limit, current):
      return "Concurrency limit reached for '\(concurrencyId)': \(current)/\(limit)"
    }
  }

  public var failureReason: String? {
    switch self {
    case .concurrencyLimitReached:
      return
        "Cannot execute action because the maximum number of concurrent executions has been reached"
    }
  }
}
