import Foundation

// MARK: - LockmanPriorityBasedCancellationError

/// A cancellation error that occurs when a higher priority action preempts a lower priority action.
///
/// This error provides detailed information about which action was cancelled and why.
/// It conforms to `LockmanCancellationError` to provide a consistent interface for
/// handling cancellation scenarios across different strategies.
public struct LockmanPriorityBasedCancellationError: LockmanCancellationError {
  /// The information about the action that was cancelled.
  public let cancelledInfo: LockmanPriorityBasedInfo

  /// The boundary ID where the cancellation occurred.
  public let boundaryId: any LockmanBoundaryId

  /// Creates a new priority-based cancellation error.
  ///
  /// - Parameters:
  ///   - cancelledInfo: The information about the action that was cancelled
  ///   - boundaryId: The boundary ID where the cancellation occurred
  public init(cancelledInfo: LockmanPriorityBasedInfo, boundaryId: any LockmanBoundaryId) {
    self.cancelledInfo = cancelledInfo
    self.boundaryId = boundaryId
  }

  // MARK: - LockmanCancellationError Conformance

  public var lockmanInfo: any LockmanInfo {
    cancelledInfo
  }

  public var errorDescription: String? {
    "Lock acquired, preceding action '\(cancelledInfo.actionId)' will be cancelled."
  }

  public var failureReason: String? {
    "A lower priority action was preempted by a higher priority action."
  }
}
