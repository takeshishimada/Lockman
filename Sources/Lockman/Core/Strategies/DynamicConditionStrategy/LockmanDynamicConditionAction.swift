import Foundation

/// A protocol for actions that support dynamic condition-based locking.
///
/// Conforming types can create lock info with custom conditions that are evaluated at runtime.
///
/// ## Example
/// ```swift
/// @LockmanDynamicCondition
/// enum MyAction {
///     case fetchData(userId: String, priority: Int)
///     case processTask(size: Int)
/// }
///
/// // Usage
/// let action = MyAction.fetchData(userId: "123", priority: 5)
/// let info = action.with {
///     guard priority > 3 else {
///         return .failure(LockmanDynamicConditionError.conditionNotMet(
///             actionId: "fetchData",
///             hint: "Priority too low"
///         ))
///     }
///     return .success
/// }
///
/// try await withLock(info, in: boundary) {
///     // Execute
/// }
/// ```
public protocol LockmanDynamicConditionAction: LockmanAction {
  /// The name of the action, typically the enum case name.
  var actionName: String { get }

  /// Creates lock info with a custom condition.
  ///
  /// - Parameter condition: A closure that returns a `LockmanResult` indicating
  ///                       whether the lock can be acquired
  /// - Returns: Lock info with the specified condition
  func with(
    condition: @escaping @Sendable () -> LockmanResult
  ) -> LockmanDynamicConditionInfo
}

// MARK: - Default Implementation

extension LockmanDynamicConditionAction {
  /// Default implementation that creates lock info with the provided condition.
  public func with(
    condition: @escaping @Sendable () -> LockmanResult
  ) -> LockmanDynamicConditionInfo {
    LockmanDynamicConditionInfo(
      actionId: actionName,
      condition: condition
    )
  }

  // MARK: - LockmanAction

  // Strategy ID is now provided by lockmanInfo

  /// Provides default lock info with always-success condition.
  public var lockmanInfo: LockmanDynamicConditionInfo {
    LockmanDynamicConditionInfo(actionId: actionName)
  }
}
