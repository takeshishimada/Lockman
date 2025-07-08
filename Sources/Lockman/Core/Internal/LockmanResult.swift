/// The result of attempting to acquire a lock.
///
/// This enum represents the possible outcomes when a strategy attempts
/// to acquire a lock for a given boundary and lock information. The result
/// determines how the calling code should proceed with the requested operation.
public enum LockmanResult: Sendable {
  /// Lock acquisition succeeded without conflicts.
  ///
  /// The requested lock was successfully acquired and no existing locks
  /// were affected. The operation can proceed immediately without any
  /// additional cleanup or cancellation steps.
  case success

  /// Lock acquisition succeeded but requires canceling a preceding operation.
  ///
  /// The requested lock was acquired, but an existing operation needs to be
  /// canceled to make way for the new one. This typically occurs in priority-based
  /// strategies where a higher-priority action preempts a lower-priority one.
  ///
  /// When this result is returned, the calling code should:
  /// 1. Cancel the existing operation (usually via Effect cancellation)
  /// 2. Proceed with the new operation
  ///
  /// - Parameter error: An error describing the failure state of the preceding
  ///   action that will be canceled. This error should be handled appropriately,
  ///   such as notifying error handlers before proceeding with cancellation.
  case successWithPrecedingCancellation(error: any Error)

  /// Lock acquisition failed due to conflicts.
  ///
  /// The requested lock could not be acquired because a conflicting operation
  /// is already running. This typically occurs when:
  /// - A higher-priority operation is already active (priority-based strategy)
  /// - The same action is already running (single-execution strategy)
  /// - Strategy-specific conflict conditions are met
  ///
  /// When this result is returned, the requesting operation should not proceed.
  ///
  /// - Parameter error: An error conforming to `LockmanError` that provides
  ///   detailed information about why the lock acquisition failed. All cancellation
  ///   errors conform to `LockmanCancellationError` which provides consistent
  ///   access to cancelled action info and the boundary where cancellation occurred.
  case failure(any Error)
}

// MARK: - Equatable Conformance

extension LockmanResult: Equatable {
  public static func == (lhs: LockmanResult, rhs: LockmanResult) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case (.successWithPrecedingCancellation, .successWithPrecedingCancellation):
      return true
    case (.failure(let lhsError), .failure(let rhsError)):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}
