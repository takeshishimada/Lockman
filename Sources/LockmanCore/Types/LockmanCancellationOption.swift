import Foundation

/// Controls how lock acquisition conflicts are handled when a new action attempts to acquire a lock
/// that conflicts with an existing action.
///
/// This enum provides different options for handling lock conflicts, allowing
/// developers to control whether existing actions should be cancelled or new actions should be blocked.
///
/// ## Usage Examples
/// ```swift
/// // Cancel existing action and allow new one to proceed
/// .withLock(cancellationOption: .cancelExisting, ...)
///
/// // Block new action and let existing one continue
/// .withLock(cancellationOption: .blockNew, ...)
///
/// // Use the strategy's default behavior
/// .withLock(cancellationOption: .useStrategyDefault, ...)
/// ```
public enum CancellationOption: Sendable, Equatable {
  /// Cancel the existing action and allow the new action to proceed.
  ///
  /// When a lock conflict occurs, the existing action will be cancelled
  /// and the new action will be allowed to acquire the lock. This is useful
  /// for scenarios where the latest request should take precedence.
  ///
  /// ## Use Cases
  /// - Search queries where the latest input is most relevant
  /// - Live updates that should replace stale requests
  /// - User-initiated actions that should supersede background tasks
  case cancelExisting
  
  /// Block the new action and let the existing action continue.
  ///
  /// When a lock conflict occurs, the new action will be blocked (fail to acquire lock)
  /// and the existing action will continue execution. This is useful for scenarios
  /// where ongoing operations should complete without interruption.
  ///
  /// ## Use Cases
  /// - Critical operations that must complete (payments, file saves)
  /// - Operations with side effects that cannot be safely cancelled
  /// - Expensive computations that should not be restarted
  case blockNew
  
  /// Use the strategy's default behavior for handling conflicts.
  ///
  /// The behavior depends on the specific strategy and lock information being used.
  /// For example, `LockmanPriorityBasedStrategy` uses the `ConcurrencyBehavior`
  /// specified in the lock info to determine whether to cancel or block.
  ///
  /// ## Strategy-Specific Behaviors
  /// - **SingleExecutionStrategy**: Always blocks new actions
  /// - **PriorityBasedStrategy**: Uses the `ConcurrencyBehavior` from lock info
  /// - **GroupCoordinationStrategy**: Blocks based on role and group state
  /// - **DynamicConditionStrategy**: Determined by the condition closure
  case useStrategyDefault
}