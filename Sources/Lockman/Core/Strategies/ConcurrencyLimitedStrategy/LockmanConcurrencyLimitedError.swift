import Foundation

// MARK: - LockmanConcurrencyLimitedError

/// An error that occurs when concurrency limit strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed because the concurrency
/// limit has been reached for the specified concurrency group.
public enum LockmanConcurrencyLimitedError: LockmanStrategyError {
  /// The concurrency limit has been reached.
  case concurrencyLimitReached(
    lockmanInfo: LockmanConcurrencyLimitedInfo,
    boundaryId: any LockmanBoundaryId,
    currentCount: Int
  )
}

// MARK: - LocalizedError Conformance

extension LockmanConcurrencyLimitedError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .concurrencyLimitReached(let lockmanInfo, _, let currentCount):
      let limitStr: String
      switch lockmanInfo.limit {
      case .unlimited:
        limitStr = "unlimited"
      case .limited(let limit):
        limitStr = String(limit)
      }
      return
        "Concurrency limit reached for '\(lockmanInfo.concurrencyId)': \(currentCount)/\(limitStr)"
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

// MARK: - LockmanStrategyError Conformance

extension LockmanConcurrencyLimitedError {
  public var lockmanInfo: any LockmanInfo {
    switch self {
    case .concurrencyLimitReached(let lockmanInfo, _, _):
      return lockmanInfo
    }
  }

  public var boundaryId: any LockmanBoundaryId {
    switch self {
    case .concurrencyLimitReached(_, let boundaryId, _):
      return boundaryId
    }
  }
}
