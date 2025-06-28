import Foundation

/// Information required for single-execution locking behavior.
///
/// This structure encapsulates the necessary data for `LockmanSingleExecutionStrategy`
/// to enforce execution control within a boundary. The execution behavior is determined
/// by the `mode` property, which can be `.none`, `.boundary`, or `.action`.
///
/// ## Key Properties
/// - **actionId**: The identifier used for lock conflict detection
/// - **uniqueId**: A unique instance identifier for equality comparison
/// - **mode**: The execution mode that determines locking behavior
///
/// ## Usage Examples
/// ```swift
/// // Boundary mode - only one action per boundary
/// let info1 = LockmanSingleExecutionInfo(mode: .boundary)
///
/// // Action mode - only one instance of same actionId
/// let info2 = LockmanSingleExecutionInfo(mode: .action)
///
/// // None mode - no exclusive execution
/// let info3 = LockmanSingleExecutionInfo(mode: .none)
/// ```
///
/// ## Thread Safety
/// This struct is `Sendable` and can be safely passed across concurrent contexts.
/// All properties are immutable after initialization.
public struct LockmanSingleExecutionInfo: LockmanInfo, Sendable, Equatable {
  // MARK: - LockmanInfo Protocol Properties

  /// The strategy identifier for this lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier used for lock conflict detection.
  ///
  /// This identifier determines which actions are considered conflicting:
  /// - In `.action` mode: Only actions with the same actionId conflict
  /// - In `.boundary` mode: All actions conflict regardless of actionId
  /// - In `.none` mode: No actions conflict (actionId is ignored)
  ///
  /// ## Examples
  /// - `"login"` - All login actions share the same lock
  /// - `"fetchUser_123"` - User-specific action (won't conflict with `"fetchUser_456"`)
  /// - `"saveDocument_\(documentId)"` - Document-specific action
  public let actionId: LockmanActionId

  /// A unique identifier for this specific lock info instance.
  ///
  /// Used for equality comparison and to distinguish between different instances
  /// of lock information, even when they have the same `actionId`. This ensures
  /// that each lock acquisition has a unique identity in the system.
  public let uniqueId: UUID

  /// The execution mode that determines locking behavior.
  ///
  /// Controls how the strategy evaluates lock conflicts:
  /// - `.none`: No exclusive execution - all actions can run concurrently
  /// - `.boundary`: Only one action per boundary - strictest concurrency control
  /// - `.action`: Only one instance of the same action - allows different actions to run concurrently
  ///
  /// Performance note: `.action` mode uses O(1) hash-based lookups for optimal performance
  public let mode: LockmanSingleExecutionStrategy.ExecutionMode

  // MARK: - Initialization

  /// Creates a new single-execution lock information instance.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this lock (defaults to .singleExecution)
  ///   - actionId: The action identifier for conflict detection. Defaults to empty string,
  ///     which is suitable for `.boundary` and `.none` modes where the specific action
  ///     identity doesn't affect locking behavior
  ///   - mode: The execution mode that determines locking behavior
  ///
  /// ## Design Considerations
  /// The `uniqueId` is automatically generated to ensure each instance is unique,
  /// even when multiple instances share the same `actionId`. This allows the
  /// system to track individual lock acquisitions while still enforcing
  /// execution semantics based on the mode.
  public init(
    strategyId: LockmanStrategyId = .singleExecution,
    actionId: LockmanActionId = LockmanActionId(""),
    mode: LockmanSingleExecutionStrategy.ExecutionMode
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.mode = mode
    self.uniqueId = UUID()
  }

  // MARK: - Equatable Implementation

  /// Compares two instances for equality based on their unique identifiers.
  ///
  /// Two `LockmanSingleExecutionInfo` instances are considered equal only if
  /// they have the same `uniqueId`, regardless of their `actionId` values.
  /// This ensures that each lock info instance has a distinct identity.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side instance to compare
  ///   - rhs: The right-hand side instance to compare
  /// - Returns: `true` if both instances have the same `uniqueId`, `false` otherwise
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.uniqueId == rhs.uniqueId
  }

  // MARK: - CustomDebugStringConvertible

  public var debugDescription: String {
    "LockmanSingleExecutionInfo(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), mode: \(mode))"
  }

  // MARK: - Debug Additional Info

  public var debugAdditionalInfo: String {
    "mode: \(mode)"
  }
}
