import Foundation

// MARK: - LockmanDynamicConditionError

/// Errors that can occur when attempting to acquire a lock using DynamicConditionStrategy.
///
/// These errors indicate that the custom condition for lock acquisition was not met.
public enum LockmanDynamicConditionError: LockmanError {
  /// Indicates that the dynamic condition evaluated to false.
  ///
  /// The optional hint provides additional context about why the condition failed,
  /// which can be useful for debugging.
  case conditionNotMet(actionId: String, hint: String? = nil)

  public var errorDescription: String? {
    switch self {
    case let .conditionNotMet(actionId, hint):
      if let hint = hint {
        return "Cannot acquire lock for action '\(actionId)': condition not met (\(hint))."
      } else {
        return "Cannot acquire lock for action '\(actionId)': condition not met."
      }
    }
  }

  public var failureReason: String? {
    switch self {
    case .conditionNotMet:
      return "The custom condition closure returned false, preventing lock acquisition."
    }
  }
}
