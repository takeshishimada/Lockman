import Foundation

// MARK: - LockmanSingleExecutionCancellationError

/// A cancellation error that occurs when single execution strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed because:
/// - The boundary already has an active lock (boundary mode)
/// - An action with the same ID is already running (action mode)
public struct LockmanSingleExecutionCancellationError: LockmanCancellationError {
  /// The reason why the new action was cancelled.
  public enum CancellationReason: Sendable {
    /// The boundary already has an active lock.
    case boundaryAlreadyLocked(existingInfo: LockmanSingleExecutionInfo)

    /// An action with the same ID is already running.
    case actionAlreadyRunning(existingInfo: LockmanSingleExecutionInfo)
  }

  /// The information about the action that was cancelled (the new action).
  public let cancelledInfo: LockmanSingleExecutionInfo

  /// The boundary ID where the cancellation occurred.
  public let boundaryId: any LockmanBoundaryId

  /// The specific reason for cancellation.
  public let reason: CancellationReason

  /// Creates a new single execution cancellation error.
  ///
  /// - Parameters:
  ///   - cancelledInfo: The information about the cancelled action
  ///   - boundaryId: The boundary ID where the cancellation occurred
  ///   - reason: The specific reason for cancellation
  public init(
    cancelledInfo: LockmanSingleExecutionInfo,
    boundaryId: any LockmanBoundaryId,
    reason: CancellationReason
  ) {
    self.cancelledInfo = cancelledInfo
    self.boundaryId = boundaryId
    self.reason = reason
  }

  // MARK: - LockmanCancellationError Conformance

  public var lockmanInfo: any LockmanInfo {
    cancelledInfo
  }

  public var errorDescription: String? {
    switch reason {
    case .boundaryAlreadyLocked(let existingInfo):
      return
        "Cannot acquire lock: boundary '\(boundaryId)' already has an active lock for action '\(existingInfo.actionId)'."
    case .actionAlreadyRunning(let existingInfo):
      return "Cannot acquire lock: action '\(existingInfo.actionId)' is already running."
    }
  }

  public var failureReason: String? {
    switch reason {
    case .boundaryAlreadyLocked:
      return
        "SingleExecutionStrategy with boundary mode prevents multiple operations in the same boundary."
    case .actionAlreadyRunning:
      return "SingleExecutionStrategy with action mode prevents duplicate action execution."
    }
  }
}
