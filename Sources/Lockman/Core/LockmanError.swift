import Foundation

// MARK: - LockmanError Protocol

/// A protocol that all Lockman-related errors must conform to.
///
/// This protocol serves as the base for all error types within the Lockman framework,
/// ensuring consistent error handling across different components.
///
/// ## Error Types
/// Each strategy defines its own error type conforming to this protocol:
/// - `LockmanSingleExecutionError`: Errors from single execution strategy
/// - `LockmanPriorityBasedError`: Errors from priority-based strategy
/// - `LockmanGroupCoordinationError`: Errors from group coordination strategy
/// - `LockmanRegistrationError`: Errors from strategy registration and resolution
/// 
/// For dynamic condition strategy, users define their own error types.
///
/// ## Usage
/// When a lock acquisition fails, strategies return `.failure(error)` where
/// the error conforms to this protocol, providing detailed information about
/// why the lock could not be acquired.
public protocol LockmanError: Error, LocalizedError {
  // Intentionally empty - serves as a marker protocol
}
