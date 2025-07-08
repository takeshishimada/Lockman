import Foundation

/// Lock information for dynamic condition-based execution control.
///
/// This structure allows you to define custom locking conditions using closures
/// that are evaluated at runtime.
///
/// ## Example
/// ```swift
/// // Define custom error for your business logic
/// struct UserLimitExceededError: Error {
///     let currentUsers: Int
///     let maxUsers: Int
/// }
///
/// let info = LockmanDynamicConditionInfo(
///     actionId: "fetchData",
///     condition: {
///         // Custom business logic to determine if lock can be acquired
///         guard userCount < maxUsers else {
///             return .cancel(UserLimitExceededError(
///                 currentUsers: userCount,
///                 maxUsers: maxUsers
///             ))
///         }
///         return .success
///     }
/// )
/// ```
public struct LockmanDynamicConditionInfo: LockmanInfo, Sendable {
  // MARK: - Properties

  /// The strategy identifier for this lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier for this lock.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific lock instance.
  public let uniqueId: UUID

  /// The condition that determines whether this lock can be acquired.
  ///
  /// This closure returns a `LockmanResult` to indicate success or cancellation.
  /// When returning `.cancel`, the error MUST conform to `LockmanError` protocol.
  ///
  /// ## Example
  /// ```swift
  /// LockmanDynamicConditionInfo(
  ///   actionId: "purchase",
  ///   condition: {
  ///     guard userIsAuthenticated else {
  ///       return .cancel(MyAuthError.notAuthenticated) // MyAuthError: LockmanError
  ///     }
  ///     return .success
  ///   }
  /// )
  /// ```
  public let condition: @Sendable () -> LockmanResult

  // MARK: - Initialization

  /// Creates a new dynamic condition lock info with a custom condition.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this lock (defaults to .dynamicCondition)
  ///   - actionId: The identifier for this action
  ///   - condition: A closure that evaluates whether the lock can be acquired.
  ///                When returning `.cancel`, the error MUST conform to `LockmanError`.
  public init(
    strategyId: LockmanStrategyId = .dynamicCondition,
    actionId: LockmanActionId,
    condition: @escaping @Sendable () -> LockmanResult
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.condition = condition
  }

  /// Creates a new dynamic condition lock info with default condition (always success).
  ///
  /// This initializer is useful when you want to use the lock without any restrictions.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this lock (defaults to .dynamicCondition)
  ///   - actionId: The identifier for this action
  public init(
    strategyId: LockmanStrategyId = .dynamicCondition,
    actionId: LockmanActionId
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.condition = { .success }  // Default: always allow
  }

  // MARK: - Equatable

  /// Compares two instances based on their unique identifiers.
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.uniqueId == rhs.uniqueId
  }

  // MARK: - CustomDebugStringConvertible

  public var debugDescription: String {
    "LockmanDynamicConditionInfo(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), condition: <closure>)"
  }

  // MARK: - Debug Additional Info

  public var debugAdditionalInfo: String {
    "condition: <closure>"
  }
}
