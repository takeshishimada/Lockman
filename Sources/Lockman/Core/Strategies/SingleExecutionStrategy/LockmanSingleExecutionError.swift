import Foundation

// MARK: - LockmanSingleExecutionError

/// An error that occurs when single execution strategy prevents a new action.
///
/// This error is returned when a new action cannot proceed because:
/// - The boundary already has an active lock (boundary mode)
/// - An action with the same ID is already running (action mode)
public enum LockmanSingleExecutionError: LockmanStrategyError {
  /// The boundary already has an active lock.
  case boundaryAlreadyLocked(
    boundaryId: any LockmanBoundaryId, lockmanInfo: LockmanSingleExecutionInfo)

  /// An action with the same ID is already running.
  case actionAlreadyRunning(
    boundaryId: any LockmanBoundaryId, lockmanInfo: LockmanSingleExecutionInfo)
}

// MARK: - LocalizedError Conformance

extension LockmanSingleExecutionError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .boundaryAlreadyLocked(let boundaryId, let lockmanInfo):
      return
        "Cannot acquire lock: boundary '\(boundaryId)' already has an active lock for action '\(lockmanInfo.actionId)'."
    case .actionAlreadyRunning(_, let lockmanInfo):
      return "Cannot acquire lock: action '\(lockmanInfo.actionId)' is already running."
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

// MARK: - LockmanStrategyError Conformance

extension LockmanSingleExecutionError {
  public var lockmanInfo: any LockmanInfo {
    switch self {
    case .boundaryAlreadyLocked(_, let lockmanInfo):
      return lockmanInfo
    case .actionAlreadyRunning(_, let lockmanInfo):
      return lockmanInfo
    }
  }

  public var boundaryId: any LockmanBoundaryId {
    switch self {
    case .boundaryAlreadyLocked(let boundaryId, _):
      return boundaryId
    case .actionAlreadyRunning(let boundaryId, _):
      return boundaryId
    }
  }
}
