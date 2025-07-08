import Foundation

// MARK: - LockmanConcurrencyLimitedError

/// An error that occurs when concurrency limit strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed because the concurrency
/// limit has been reached for the specified concurrency group.
public enum LockmanConcurrencyLimitedError: LockmanError {
  /// The concurrency limit has been reached.
  case concurrencyLimitReached(
    requestedInfo: LockmanConcurrencyLimitedInfo,
    existingInfos: [LockmanConcurrencyLimitedInfo],
    currentCount: Int
  )
}

// MARK: - LocalizedError Conformance

extension LockmanConcurrencyLimitedError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .concurrencyLimitReached(let requestedInfo, _, let currentCount):
      let limitStr: String
      switch requestedInfo.limit {
      case .unlimited:
        limitStr = "unlimited"
      case .limited(let limit):
        limitStr = String(limit)
      }
      return
        "Concurrency limit reached for '\(requestedInfo.concurrencyId)': \(currentCount)/\(limitStr)"
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
