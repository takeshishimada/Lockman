/// A `LockmanAction` subtype that enforces priority-based locking semantics.
///
/// Conforming types must provide:
/// - `createLockmanInfo()`: A method that creates `LockmanPriorityBasedInfo` instances containing priority and lock information.
/// - `actionName`: A unique identifier used for naming locks.
///
/// The priority-based locking system ensures that higher priority actions can preempt or override
/// lower priority actions when lock conflicts occur.
///
/// Example implementation:
/// ```swift
/// struct LoginAction: LockmanPriorityBasedAction {
///   let actionName = "login"
///
///   func createLockmanInfo() -> LockmanPriorityBasedInfo {
///     priority(.high(.exclusive))
///   }
/// }
/// ```
public protocol LockmanPriorityBasedAction: LockmanAction
where I == LockmanPriorityBasedInfo {
  /// Creates lock information, including the priority level, for this action.
  ///
  /// The priority level determines the action's precedence in lock conflict resolution.
  /// Higher priority actions can cancel lower priority ones, and equal priority actions
  /// follow the configured `SamePriorityPolicy`.
  func createLockmanInfo() -> LockmanPriorityBasedInfo

  /// A unique name identifying this action, used as part of the lock's identifier.
  ///
  /// This name should be consistent across instances of the same action type to ensure
  /// proper lock management and conflict resolution. Typically implemented as a
  /// string literal that describes the action (e.g., "login", "logout", "fetchData").
  var actionName: String { get }
}

// MARK: - Default Implementation

extension LockmanPriorityBasedAction {
}

// MARK: - Priority Helper Methods

extension LockmanPriorityBasedAction {
  /// Creates a new `LockmanPriorityBasedInfo` using the action's name and a specified priority.
  ///
  /// This is a convenience method that combines the action name with a priority level
  /// to create the required lock information.
  ///
  /// - Parameter priority: The priority level to assign to this action.
  /// - Returns: A `LockmanPriorityBasedInfo` instance combining `actionName` and `priority`.
  ///
  /// Example usage:
  /// ```swift
  /// func createLockmanInfo() -> LockmanPriorityBasedInfo {
  ///   priority(.high(.exclusive))
  /// }
  /// ```
  public func priority(_ priority: LockmanPriorityBasedInfo.Priority) -> LockmanPriorityBasedInfo {
    .init(actionId: actionName, priority: priority)
  }

  /// Creates a new `LockmanPriorityBasedInfo` using the action's name concatenated with
  /// an additional identifier and a specified priority.
  ///
  /// This method is useful when you need to create multiple locks for the same action
  /// type but with different identifiers (e.g., per-user actions, per-resource actions).
  ///
  /// - Parameters:
  ///   - id: An extra string appended to `actionName`, forming a composite identifier.
  ///   - priority: The priority level to assign to this action.
  /// - Returns: A `LockmanPriorityBasedInfo` instance combining `actionName + id` and `priority`.
  ///
  /// Example usage:
  /// ```swift
  /// func createLockmanInfo() -> LockmanPriorityBasedInfo {
  ///   priority("_user123", .high(.exclusive))
  /// }
  /// ```
  public func priority(
    _ id: String,
    _ priority: LockmanPriorityBasedInfo.Priority
  ) -> LockmanPriorityBasedInfo {
    .init(actionId: actionName + id, priority: priority)
  }
}
