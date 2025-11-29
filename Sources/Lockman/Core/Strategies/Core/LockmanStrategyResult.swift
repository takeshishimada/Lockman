/// The result of checking lock feasibility (used by strategy canLock methods).
///
/// This enum represents the possible outcomes when a strategy checks whether
/// a lock can be acquired for a given boundary and lock information. This is
/// used internally by strategies during the feasibility assessment phase.
///
/// ## Strategy Level Responsibility
/// This type is specifically designed for strategy-level lock feasibility checks.
/// It serves as the bridge between:
/// - Strategy `canLock` methods (feasibility assessment)
/// - Manager-level lock acquisition with unlock tokens
///
/// ## Design Philosophy
/// - **Strategy Focus**: Pure feasibility assessment without unlock concerns
/// - **Lightweight**: No associated unlock tokens (they don't exist yet)
/// - **Clear Separation**: Distinct from manager-level `LockmanResult<B, I>`
///
/// ## Usage Context
/// ```swift
/// // Strategy level - feasibility check
/// func canLock<B: LockmanBoundaryId>(boundaryId: B, info: I) -> LockmanStrategyResult
///
/// // Manager level - actual acquisition with unlock token
/// func acquireLock<B, I>(...) -> LockmanResult<B, I>
/// ```
public enum LockmanStrategyResult: Sendable, Equatable {
  /// Lock acquisition can succeed without conflicts.
  ///
  /// The strategy has determined that the requested lock can be acquired
  /// without affecting any existing locks or operations.
  case success

  /// Lock acquisition can succeed but requires canceling a preceding operation.
  ///
  /// The strategy can accommodate the new lock request, but an existing
  /// operation must be canceled first. This typically occurs in priority-based
  /// strategies where higher-priority actions preempt lower-priority ones.
  ///
  /// - Parameter error: A strategy-specific error conforming to `LockmanPrecedingCancellationError`
  ///   that describes the preceding action that will be canceled.
  case successWithPrecedingCancellation(error: any LockmanPrecedingCancellationError)

  /// Lock acquisition will fail and the new action should be cancelled.
  ///
  /// The strategy cannot accommodate the new lock request due to conflicting
  /// conditions. The requesting operation should not proceed.
  ///
  /// - Parameter error: A strategy-specific error conforming to `LockmanError`
  ///   that provides details about why the lock acquisition failed.
  case cancel(any LockmanError)
}

// MARK: - Equatable Conformance

extension LockmanStrategyResult {
  /// Equatable conformance for LockmanStrategyResult.
  ///
  /// This implementation handles comparison of existential types by comparing
  /// their underlying error descriptions and types where possible.
  ///
  /// ## Comparison Strategy
  /// - `.success` cases: Always equal
  /// - `.cancel` cases: Compare error descriptions (best-effort equality)
  /// - `.successWithPrecedingCancellation` cases: Compare error descriptions
  /// - Mixed cases: Never equal
  ///
  /// ## Note on Existential Type Equality
  /// Since associated values use existential types (`any LockmanError`, `any LockmanPrecedingCancellationError`),
  /// true structural equality cannot be guaranteed. This implementation provides
  /// best-effort equality based on error descriptions, which is sufficient for testing purposes.
  public static func == (lhs: LockmanStrategyResult, rhs: LockmanStrategyResult) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case (.cancel(let lhsError), .cancel(let rhsError)):
      return String(describing: lhsError) == String(describing: rhsError)
    case (
      .successWithPrecedingCancellation(let lhsError),
      .successWithPrecedingCancellation(let rhsError)
    ):
      return String(describing: lhsError) == String(describing: rhsError)
    default:
      return false
    }
  }
}
