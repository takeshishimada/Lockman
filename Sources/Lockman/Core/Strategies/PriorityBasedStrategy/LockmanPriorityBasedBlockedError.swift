import Foundation

// MARK: - LockmanPriorityBasedBlockedError

/// A cancellation error that occurs when priority-based strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed due to priority conflicts.
/// Unlike `LockmanPriorityBasedCancellationError` which represents existing action cancellation,
/// this represents new action cancellation.
public struct LockmanPriorityBasedBlockedError: LockmanCancellationError {
  /// The reason why the new action was blocked (cancelled).
  public enum BlockedReason: Sendable {
    /// A higher priority action is already running.
    case higherPriorityExists(
      requested: LockmanPriorityBasedInfo.Priority,
      currentHighest: LockmanPriorityBasedInfo.Priority
    )

    /// Another action with the same priority and exclusive behavior is already running.
    case samePriorityConflict(priority: LockmanPriorityBasedInfo.Priority)
  }

  /// The information about the action that was blocked (the new action).
  public let blockedInfo: LockmanPriorityBasedInfo

  /// The boundary ID where the blocking occurred.
  public let boundaryId: any LockmanBoundaryId

  /// The specific reason for blocking.
  public let reason: BlockedReason

  /// Creates a new priority-based blocked error.
  ///
  /// - Parameters:
  ///   - blockedInfo: The information about the blocked action
  ///   - boundaryId: The boundary ID where the blocking occurred
  ///   - reason: The specific reason for blocking
  public init(
    blockedInfo: LockmanPriorityBasedInfo,
    boundaryId: any LockmanBoundaryId,
    reason: BlockedReason
  ) {
    self.blockedInfo = blockedInfo
    self.boundaryId = boundaryId
    self.reason = reason
  }

  // MARK: - LockmanCancellationError Conformance

  public var lockmanInfo: any LockmanInfo {
    blockedInfo
  }

  public var errorDescription: String? {
    switch reason {
    case .higherPriorityExists(let requested, let currentHighest):
      return
        "Cannot acquire lock: requested priority \(requested) is lower than current highest priority \(currentHighest)."
    case .samePriorityConflict(let priority):
      return "Cannot acquire lock: another action with priority \(priority) is already running."
    }
  }

  public var failureReason: String? {
    switch reason {
    case .higherPriorityExists:
      return
        "PriorityBasedStrategy only allows higher priority actions to preempt lower priority ones."
    case .samePriorityConflict:
      return "Actions with the same priority and exclusive behavior cannot run concurrently."
    }
  }
}
