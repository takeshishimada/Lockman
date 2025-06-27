import Foundation

// MARK: - LockmanSingleExecutionError

/// Errors that can occur when attempting to acquire a lock using SingleExecutionStrategy.
///
/// These errors provide detailed information about why a single execution lock
/// could not be acquired.
public enum LockmanSingleExecutionError: LockmanError {
  /// Indicates that the specified boundary already has an active lock.
  ///
  /// This occurs when attempting to acquire a boundary-scoped lock while
  /// another operation is already holding a lock in the same boundary.
  case boundaryAlreadyLocked(boundaryId: String, existingInfo: LockmanSingleExecutionInfo)

  /// Indicates that an action with the same ID is already running.
  ///
  /// This occurs when attempting to execute an action while another instance
  /// of the same action is already in progress.
  case actionAlreadyRunning(existingInfo: LockmanSingleExecutionInfo)

  public var errorDescription: String? {
    switch self {
    case let .boundaryAlreadyLocked(boundaryId, existingInfo):
      return
        "Cannot acquire lock: boundary '\(boundaryId)' already has an active lock for action '\(existingInfo.actionId)'."
    case let .actionAlreadyRunning(existingInfo):
      return "Cannot acquire lock: action '\(existingInfo.actionId)' is already running."
    }
  }

  public var failureReason: String? {
    switch self {
    case .boundaryAlreadyLocked:
      return
        "SingleExecutionStrategy with boundary mode prevents multiple operations in the same boundary."
    case .actionAlreadyRunning:
      return "SingleExecutionStrategy with action mode prevents duplicate action execution."
    }
  }
}
