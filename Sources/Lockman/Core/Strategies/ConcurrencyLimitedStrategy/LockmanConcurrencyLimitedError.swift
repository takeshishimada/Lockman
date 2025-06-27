import Foundation

/// Errors specific to concurrency-limited locking.
public enum LockmanConcurrencyLimitedError: LockmanError {
  /// The concurrency limit has been reached.
  /// - Parameters:
  ///   - requestedInfo: The info of the action that was blocked
  ///   - existingInfos: Array of currently active infos in the same concurrency group
  ///   - current: Current number of active concurrent executions
  case concurrencyLimitReached(
    requestedInfo: LockmanConcurrencyLimitedInfo, existingInfos: [LockmanConcurrencyLimitedInfo],
    current: Int)

  public var errorDescription: String? {
    switch self {
    case let .concurrencyLimitReached(requestedInfo, _, current):
      return
        "Concurrency limit reached for '\(requestedInfo.concurrencyId)': \(current)/\(requestedInfo.limit)"
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
