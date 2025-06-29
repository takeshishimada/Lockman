import Foundation

// MARK: - LockmanPriorityBasedError

/// Errors that can occur when attempting to acquire a lock using PriorityBasedStrategy.
///
/// These errors provide information about priority conflicts and why a lock
/// could not be acquired based on priority rules.
public enum LockmanPriorityBasedError: LockmanError {
  /// Indicates that a higher priority action is already running.
  ///
  /// This occurs when attempting to acquire a lock with a lower priority
  /// than an existing lock.
  case higherPriorityExists(
    requested: LockmanPriorityBasedInfo.Priority, currentHighest: LockmanPriorityBasedInfo.Priority)

  /// Indicates that another action with the same priority is already running.
  ///
  /// This occurs when two actions have the same priority level and the
  /// existing one has exclusive behavior.
  case samePriorityConflict(priority: LockmanPriorityBasedInfo.Priority)

  /// Indicates that a preceding action will be cancelled due to preemption.
  ///
  /// This occurs when a higher priority action preempts a lower priority action.
  /// The lower priority action will be cancelled to allow the higher priority
  /// action to proceed.
  case precedingActionCancelled(cancelledInfo: LockmanPriorityBasedInfo)

  public var errorDescription: String? {
    switch self {
    case let .higherPriorityExists(requested, currentHighest):
      return
        "Cannot acquire lock: requested priority \(requested) is lower than current highest priority \(currentHighest)."
    case let .samePriorityConflict(priority):
      return "Cannot acquire lock: another action with priority \(priority) is already running."
    case let .precedingActionCancelled(cancelledInfo):
      return
        "Lock acquired, preceding action '\(cancelledInfo.actionId)' will be cancelled."
    }
  }

  public var failureReason: String? {
    switch self {
    case .higherPriorityExists:
      return
        "PriorityBasedStrategy only allows higher priority actions to preempt lower priority ones."
    case .samePriorityConflict:
      return "Actions with the same priority and exclusive behavior cannot run concurrently."
    case .precedingActionCancelled:
      return "A lower priority action was preempted by a higher priority action."
    }
  }
}
