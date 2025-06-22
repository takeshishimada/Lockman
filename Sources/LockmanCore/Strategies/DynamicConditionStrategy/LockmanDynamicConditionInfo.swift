import Foundation

/// Lock information for dynamic condition-based execution control.
///
/// This structure allows you to define custom locking conditions using closures
/// that are evaluated at runtime.
///
/// ## Example
/// ```swift
/// let info = LockmanDynamicConditionInfo(
///     actionId: "fetchData",
///     condition: {
///         // Custom business logic to determine if lock can be acquired
///         return userCount < maxUsers
///     }
/// )
/// ```
public struct LockmanDynamicConditionInfo: LockmanInfo, Sendable {
  // MARK: - Properties

  /// The action identifier for this lock.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific lock instance.
  public let uniqueId: UUID

  /// The condition that determines whether this lock can be acquired.
  ///
  /// This closure returns `true` to allow the lock, or `false` to deny it.
  public let condition: @Sendable () -> Bool

  // MARK: - Initialization

  /// Creates a new dynamic condition lock info with a custom condition.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - condition: A closure that evaluates whether the lock can be acquired
  public init(
    actionId: LockmanActionId,
    condition: @escaping @Sendable () -> Bool
  ) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.condition = condition
  }

  /// Creates a new dynamic condition lock info with default condition (always success).
  ///
  /// This initializer is useful when you want to use the lock without any restrictions.
  ///
  /// - Parameter actionId: The identifier for this action
  public init(
    actionId: LockmanActionId
  ) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.condition = { true }  // Default: always allow
  }

  // MARK: - Equatable

  /// Compares two instances based on their unique identifiers.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.uniqueId == rhs.uniqueId
  }

  // MARK: - CustomDebugStringConvertible

  public var debugDescription: String {
    "LockmanDynamicConditionInfo(actionId: '\(actionId)', uniqueId: \(uniqueId), condition: <closure>)"
  }
}
