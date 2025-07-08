import Foundation

// MARK: - LockmanPriorityBasedError

/// An error that occurs when priority-based strategy prevents or cancels an action.
///
/// This error covers both scenarios:
/// - When a new action is blocked due to priority conflicts
/// - When an existing action is cancelled by preemption
public enum LockmanPriorityBasedError: LockmanError {
  /// A higher priority action is already running, blocking the new action.
  case higherPriorityExists(
    requested: LockmanPriorityBasedInfo.Priority,
    currentHighest: LockmanPriorityBasedInfo.Priority
  )

  /// Same priority conflict based on the existing action's concurrency behavior.
  case samePriorityConflict(priority: LockmanPriorityBasedInfo.Priority)

  /// The existing action was cancelled by a higher priority action.
  case precedingActionCancelled(
    cancelledInfo: LockmanPriorityBasedInfo,
    boundaryId: any LockmanBoundaryId
  )
}

// MARK: - LocalizedError Conformance

extension LockmanPriorityBasedError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .higherPriorityExists(let requested, let currentHighest):
      return
        "Cannot acquire lock: Current priority \(currentHighest) is higher than requested priority \(requested)."
    case .samePriorityConflict(let priority):
      return
        "Cannot acquire lock: Another action with priority \(priority) is already running with exclusive behavior."
    case .precedingActionCancelled(let cancelledInfo, _):
      return "Lock acquired, preceding action '\(cancelledInfo.actionId)' will be cancelled."
    }
  }

  public var failureReason: String? {
    switch self {
    case .higherPriorityExists:
      return "A higher priority action is currently executing and cannot be interrupted."
    case .samePriorityConflict:
      return "The existing action with same priority has exclusive concurrency behavior."
    case .precedingActionCancelled:
      return "A lower priority action was preempted by a higher priority action."
    }
  }
}
