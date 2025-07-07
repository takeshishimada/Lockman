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

  public var errorDescription: String? {
    switch self {
    case .higherPriorityExists(let requested, let currentHighest):
      return
        "Cannot acquire lock: requested priority \(requested) is lower than current highest priority \(currentHighest)."
    case .samePriorityConflict(let priority):
      return "Cannot acquire lock: another action with priority \(priority) is already running."
    }
  }

  public var failureReason: String? {
    switch self {
    case .higherPriorityExists:
      return
        "PriorityBasedStrategy only allows higher priority actions to preempt lower priority ones."
    case .samePriorityConflict:
      return "Actions with the same priority and exclusive behavior cannot run concurrently."
    }
  }
}
