import Foundation

// MARK: - LockmanSingleExecutionError

/// An error that occurs when single execution strategy prevents a new action.
///
/// This error is returned when a new action cannot proceed because:
/// - The boundary already has an active lock (boundary mode)
/// - An action with the same ID is already running (action mode)
public enum LockmanSingleExecutionError: LockmanError {
  /// The boundary already has an active lock.
  case boundaryAlreadyLocked(
    boundaryId: any LockmanBoundaryId, existingInfo: LockmanSingleExecutionInfo)

  /// An action with the same ID is already running.
  case actionAlreadyRunning(existingInfo: LockmanSingleExecutionInfo)
}

// MARK: - LocalizedError Conformance

extension LockmanSingleExecutionError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .boundaryAlreadyLocked(let boundaryId, let existingInfo):
      return
        "Cannot acquire lock: boundary '\(boundaryId)' already has an active lock for action '\(existingInfo.actionId)'."
    case .actionAlreadyRunning(let existingInfo):
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
