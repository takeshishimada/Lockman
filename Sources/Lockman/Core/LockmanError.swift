import Foundation

// MARK: - LockmanError Protocol

/// A protocol that all Lockman-related errors must conform to.
///
/// This protocol serves as the base for all error types within the Lockman framework,
/// ensuring consistent error handling across different components.
///
/// ## Error Types
/// All cancellation errors conform to `LockmanCancellationError` protocol:
/// - `LockmanSingleExecutionCancellationError`: When single execution blocks new actions
/// - `LockmanPriorityBasedCancellationError`: When actions are preempted by priority
/// - `LockmanPriorityBasedBlockedError`: When actions are blocked by priority
/// - `LockmanGroupCoordinationCancellationError`: When group coordination blocks actions
/// - `LockmanConcurrencyLimitedCancellationError`: When concurrency limit is reached
/// - `LockmanRegistrationError`: Errors from strategy registration and resolution
///
/// For dynamic condition strategy, users define their own error types.
///
/// ## Usage
/// When a lock acquisition fails, strategies return `.cancel(error)` where
/// the error conforms to this protocol, providing detailed information about
/// why the lock could not be acquired.
public protocol LockmanError: Error, LocalizedError {
  // Intentionally empty - serves as a marker protocol
}
