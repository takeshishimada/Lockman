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
///         guard userCount < maxUsers else {
///             return .failure(LockmanDynamicConditionError.conditionNotMet(
///                 actionId: "fetchData",
///                 hint: "User limit exceeded"
///             ))
///         }
///         return .success
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
  /// This closure returns a `LockmanResult` to indicate success, failure with error,
  /// or success with preceding cancellation needed.
  public let condition: @Sendable () -> LockmanResult

  // MARK: - Initialization

  /// Creates a new dynamic condition lock info with a custom condition.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - condition: A closure that evaluates whether the lock can be acquired,
  ///                returning a `LockmanResult`
  public init(
    actionId: LockmanActionId,
    condition: @escaping @Sendable () -> LockmanResult
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
    self.condition = { .success }  // Default: always allow
  }

  /// Creates a new dynamic condition lock info with a specific unique ID.
  ///
  /// This initializer is used when you need to create an instance with
  /// a predetermined unique ID, such as when wrapping existing lock information.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - uniqueId: The specific unique ID to use
  ///   - condition: A closure that evaluates whether the lock can be acquired,
  ///                returning a `LockmanResult`
  public init(
    actionId: LockmanActionId,
    uniqueId: UUID,
    condition: @escaping @Sendable () -> LockmanResult
  ) {
    self.actionId = actionId
    self.uniqueId = uniqueId
    self.condition = condition
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
