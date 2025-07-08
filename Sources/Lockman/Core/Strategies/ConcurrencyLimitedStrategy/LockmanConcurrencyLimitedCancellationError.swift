import Foundation

// MARK: - LockmanConcurrencyLimitedCancellationError

/// A cancellation error that occurs when concurrency limit strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed because the concurrency
/// limit has been reached for the specified concurrency group.
public struct LockmanConcurrencyLimitedCancellationError: LockmanCancellationError {
  /// The information about the action that was cancelled (the new action).
  public let cancelledInfo: LockmanConcurrencyLimitedInfo

  /// The boundary ID where the cancellation occurred.
  public let boundaryId: any LockmanBoundaryId

  /// Array of currently active infos in the same concurrency group.
  public let existingInfos: [LockmanConcurrencyLimitedInfo]

  /// Current number of active concurrent executions.
  public let currentCount: Int

  /// Creates a new concurrency limited cancellation error.
  ///
  /// - Parameters:
  ///   - cancelledInfo: The information about the cancelled action
  ///   - boundaryId: The boundary ID where the cancellation occurred
  ///   - existingInfos: Array of currently active infos
  ///   - currentCount: Current number of active executions
  public init(
    cancelledInfo: LockmanConcurrencyLimitedInfo,
    boundaryId: any LockmanBoundaryId,
    existingInfos: [LockmanConcurrencyLimitedInfo],
    currentCount: Int
  ) {
    self.cancelledInfo = cancelledInfo
    self.boundaryId = boundaryId
    self.existingInfos = existingInfos
    self.currentCount = currentCount
  }

  // MARK: - LockmanCancellationError Conformance

  public var lockmanInfo: any LockmanInfo {
    cancelledInfo
  }

  public var errorDescription: String? {
    let limitStr: String
    switch cancelledInfo.limit {
    case .unlimited:
      limitStr = "unlimited"
    case .limited(let limit):
      limitStr = String(limit)
    }
    return
      "Concurrency limit reached for '\(cancelledInfo.concurrencyId)': \(currentCount)/\(limitStr)"
  }

  public var failureReason: String? {
    "Cannot execute action because the maximum number of concurrent executions has been reached"
  }
}
