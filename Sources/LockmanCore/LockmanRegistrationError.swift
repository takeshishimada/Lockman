import Foundation

// MARK: - LockmanRegistrationError

/// Errors that can occur during strategy registration and resolution.
///
/// This error type specifically handles issues related to registering and resolving
/// strategies within the Lockman container.
public enum LockmanRegistrationError: LockmanError {
  /// Indicates that a strategy type is already registered in the container.
  ///
  /// Each strategy type can only be registered once to ensure deterministic behavior.
  case strategyAlreadyRegistered(String)

  /// Indicates that a requested strategy type is not registered in the container.
  ///
  /// Ensure the strategy is registered before attempting to resolve it.
  case strategyNotRegistered(String)

  /// A localized message describing what error occurred.
  public var errorDescription: String? {
    switch self {
    case let .strategyAlreadyRegistered(strategyType):
      return "Strategy '\(strategyType)' is already registered. Each strategy type can only be registered once."

    case let .strategyNotRegistered(strategyType):
      return "Strategy '\(strategyType)' is not registered. Please register the strategy before attempting to resolve it."
    }
  }

  /// A localized message describing the reason for the failure.
  public var failureReason: String? {
    switch self {
    case .strategyAlreadyRegistered:
      return "The container enforces unique strategy type registration to prevent conflicts and ensure deterministic behavior."

    case .strategyNotRegistered:
      return "Strategy resolution requires that the strategy type has been previously registered in the container."
    }
  }

  /// A localized message describing how one might recover from the failure.
  public var recoverySuggestion: String? {
    switch self {
    case let .strategyAlreadyRegistered(strategyType):
      return "Check if '\(strategyType)' is being registered multiple times. Use container.isRegistered(_:) to check before registration, or ensure registration happens only once during app startup."

    case let .strategyNotRegistered(strategyType):
      return "Add 'try Lockman.container.register(\(strategyType).shared)' to your app startup code, or verify that registration is happening before this resolution attempt."
    }
  }

  /// The help anchor that should be made available to the user.
  public var helpAnchor: String? {
    switch self {
    case .strategyAlreadyRegistered,
         .strategyNotRegistered:
      return "LockmanStrategyContainer"
    }
  }
}
