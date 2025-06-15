import Foundation

/// The result of a dynamic condition evaluation.
///
/// This enum represents the outcome of evaluating a dynamic condition
/// in the `LockmanDynamicConditionStrategy`.
public enum LockmanResult: Equatable, Sendable {
  /// The condition was satisfied and the lock can be acquired.
  case success

  /// The condition was not satisfied and the lock cannot be acquired.
  ///
  /// - Parameter reason: An optional reason explaining why the condition failed
  case failure(reason: String? = nil)
}
