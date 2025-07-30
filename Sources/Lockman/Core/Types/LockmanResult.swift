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
  /// 2. Immediately unlock the cancelled action to prevent resource leaks
  /// 3. Proceed with the new operation
  ///
  /// ## Breaking Change
  /// The error parameter now requires conformance to `LockmanPrecedingCancellationError`
  /// to enable immediate unlock operations and maintain type safety.
  ///
  /// - Parameter error: A strategy-specific error conforming to `LockmanPrecedingCancellationError`
  ///   that describes the preceding action that will be canceled. This error provides
  ///   access to the cancelled action's information for immediate unlock.
  case successWithPrecedingCancellation(error: any LockmanPrecedingCancellationError)

  /// Lock acquisition failed and the new action is cancelled.
  ///
  /// The requested lock could not be acquired because a conflicting operation
  /// is already running. This typically occurs when:
  /// - A higher-priority operation is already active (priority-based strategy)
  /// - The same action is already running (single-execution strategy)
  /// - Strategy-specific conflict conditions are met
  ///
  /// When this result is returned, the requesting operation should not proceed.
  ///
  /// - Parameter error: A strategy-specific error conforming to `LockmanError`
  ///   that provides detailed information about why the lock acquisition failed
  ///   and the new action was cancelled.
  case cancel(any LockmanError)
}
