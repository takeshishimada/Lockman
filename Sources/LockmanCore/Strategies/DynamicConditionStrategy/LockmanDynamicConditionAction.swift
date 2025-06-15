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
///     return priority > 3
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
  /// - Parameter condition: A closure that returns true to allow the lock, false to deny
  /// - Returns: Lock info with the specified condition
  func with(
    condition: @escaping @Sendable () -> Bool
  ) -> LockmanDynamicConditionInfo
}

// MARK: - Default Implementation

extension LockmanDynamicConditionAction {
  /// Default implementation that creates lock info with the provided condition.
  public func with(
    condition: @escaping @Sendable () -> Bool
  ) -> LockmanDynamicConditionInfo {
    LockmanDynamicConditionInfo(
      actionId: actionName,
      condition: condition
    )
  }

  // MARK: - LockmanAction

  /// The strategy identifier for dynamic condition strategy.
  public var strategyId: LockmanStrategyId {
    .dynamicCondition
  }

  /// Provides default lock info with always-success condition.
  public var lockmanInfo: LockmanDynamicConditionInfo {
    LockmanDynamicConditionInfo(actionId: actionName)
  }
}
