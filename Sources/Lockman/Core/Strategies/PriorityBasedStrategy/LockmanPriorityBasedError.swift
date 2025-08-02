import Foundation

// MARK: - LockmanPriorityBasedError

/// An error that occurs when priority-based strategy prevents or cancels an action.
///
/// This error covers both scenarios:
/// - When a new action is blocked due to priority conflicts
/// - When an existing action is cancelled by preemption
///
/// ## Breaking Change
/// All cases now include complete `LockmanInfo` and `boundaryId` parameters
/// to support the `LockmanPrecedingCancellationError` protocol.
public enum LockmanPriorityBasedError: LockmanError {
  /// A higher priority action is already running, blocking the new action.
  case higherPriorityExists(
    requestedInfo: LockmanPriorityBasedInfo,
    lockmanInfo: LockmanPriorityBasedInfo,
    boundaryId: any LockmanBoundaryId
  )

  /// Same priority conflict based on the existing action's concurrency behavior.
  case samePriorityConflict(
    requestedInfo: LockmanPriorityBasedInfo,
    lockmanInfo: LockmanPriorityBasedInfo,
    boundaryId: any LockmanBoundaryId
  )

  /// The existing action was cancelled by a higher priority action.
  case precedingActionCancelled(
    lockmanInfo: LockmanPriorityBasedInfo,
    boundaryId: any LockmanBoundaryId
  )
}

// MARK: - LocalizedError Conformance

extension LockmanPriorityBasedError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .higherPriorityExists(let requestedInfo, let lockmanInfo, _):
      return
        "Cannot acquire lock: Current priority \(lockmanInfo.priority) is higher than requested priority \(requestedInfo.priority)."
    case .samePriorityConflict(_, let lockmanInfo, _):
      return
        "Cannot acquire lock: Another action with priority \(lockmanInfo.priority) is already running with exclusive behavior."
    case .precedingActionCancelled(let lockmanInfo, _):
      return "Lock acquired, preceding action '\(lockmanInfo.actionId)' will be cancelled."
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

// MARK: - LockmanPrecedingCancellationError Conformance

extension LockmanPriorityBasedError: LockmanPrecedingCancellationError {
  public var lockmanInfo: any LockmanInfo {
    switch self {
    case .higherPriorityExists(let requestedInfo, _, _):
      return requestedInfo
    case .samePriorityConflict(let requestedInfo, _, _):
      return requestedInfo
    case .precedingActionCancelled(let lockmanInfo, _):
      return lockmanInfo
    }
  }

  public var boundaryId: any LockmanBoundaryId {
    switch self {
    case .higherPriorityExists(_, _, let boundaryId):
      return boundaryId
    case .samePriorityConflict(_, _, let boundaryId):
      return boundaryId
    case .precedingActionCancelled(_, let boundaryId):
      return boundaryId
    }
  }
}
