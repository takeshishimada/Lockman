import Foundation

/// Represents information required by Lockman locking strategies.
///
/// This protocol defines the essential data that all locking strategies need
/// to make decisions about lock acquisition, conflict detection, and cleanup.
/// Each concrete implementation provides specific information relevant to
/// its particular locking strategy.
///
/// ## Core Properties
/// - **actionId**: The primary identifier for lock conflict detection
/// - **uniqueId**: A unique instance identifier for equality and tracking
/// - **description**: Human-readable representation for debugging
///
/// ## Thread Safety
/// All conforming types must be `Sendable` to ensure safe passage across
/// concurrent contexts in the Lockman locking system.
///
/// ## Examples
/// ```swift
/// // Single execution info
/// let singleInfo = LockmanSingleExecutionInfo(actionId: "login")
///
/// // Priority-based info
/// let priorityInfo = LockmanPriorityBasedInfo(actionId: "sync", priority: .high(.preferLater))
/// ```
public protocol LockmanInfo: Sendable, CustomDebugStringConvertible {
  /// The strategy identifier that created this lock info.
  ///
  /// This identifier helps with debugging by showing which strategy is managing
  /// this particular lock. The format typically follows the pattern:
  /// "ModuleName.StrategyTypeName" or a custom identifier for configured strategies.
  ///
  /// ## Examples
  /// ```swift
  /// strategyId = "Lockman.SingleExecutionStrategy"
  /// strategyId = "Lockman.PriorityBasedStrategy"
  /// strategyId = "CustomApp.RateLimitStrategy"
  /// ```
  var strategyId: LockmanStrategyId { get }

  /// The action identifier used for lock conflict detection.
  ///
  /// This is the primary identifier that locking strategies use to determine
  /// whether two actions should conflict with each other. Actions with the
  /// same `actionId` are typically considered conflicting, though the exact
  /// behavior depends on the specific strategy implementation.
  ///
  /// ## Usage Guidelines
  /// - Should be consistent for the same logical action
  /// - Can include parameters for fine-grained separation (e.g., "fetchUser_123")
  /// - Should be human-readable for debugging purposes
  ///
  /// ## Examples
  /// ```swift
  /// actionId = "login"              // Simple action
  /// actionId = "fetchUser_123"      // Parameter-specific action
  /// actionId = "sync_userProfile"   // Scoped action
  /// ```
  var actionId: LockmanActionId { get }

  /// A unique identifier for this specific lock info instance.
  ///
  /// While `actionId` is used for conflict detection, `uniqueId` provides
  /// a unique identity for each individual lock info instance. This allows
  /// the system to distinguish between different instances even when they
  /// have the same `actionId`.
  ///
  /// ## Implementation Note
  /// This is typically a `UUID` that is automatically generated during
  /// initialization to ensure uniqueness across all instances.
  var uniqueId: UUID { get }

  /// Returns additional debug information specific to this lock info type.
  ///
  /// This method provides a formatted string containing strategy-specific
  /// information that is useful for debugging. The returned string should
  /// be concise and suitable for display in debug output tables.
  ///
  /// ## Default Implementation
  /// Returns an empty string by default. Concrete types should override
  /// this to provide meaningful debug information.
  ///
  /// ## Examples
  /// ```swift
  /// // SingleExecutionInfo
  /// "mode: boundary"
  ///
  /// // PriorityBasedInfo
  /// "priority: high b: .exclusive"
  ///
  /// // ConcurrencyLimitedInfo
  /// "concurrency: api_requests limit: limited(3)"
  /// ```
  var debugAdditionalInfo: String { get }

  /// Indicates whether this action should be cancellable by future actions.
  ///
  /// When `true`, the effect for this action will have a cancellation ID attached,
  /// making it cancellable by future actions in the same boundary.
  /// When `false`, the effect will not have a cancellation ID, protecting it
  /// from being cancelled by other actions.
  ///
  /// ## Strategy-Specific Behavior
  /// Different strategies interpret their `.none` settings as exclusion from cancellation:
  /// - **SingleExecution `.none`**: Strategy disabled → not cancellable
  /// - **Priority `.none`**: Priority system bypassed → not cancellable
  /// - **GroupCoordination `.none`**: Non-exclusive participation → still cancellable
  ///
  /// ## Usage Examples
  /// ```swift
  /// // SingleExecution strategy with .none mode
  /// extension LockmanSingleExecutionInfo {
  ///   var isCancellationTarget: Bool { mode != .none }
  /// }
  ///
  /// // Priority strategy with .none priority
  /// extension LockmanPriorityBasedInfo {
  ///   var isCancellationTarget: Bool { priority != .none }
  /// }
  /// ```
  ///
  /// ## Implementation in buildLockEffect
  /// ```swift
  /// case .success:
  ///   let shouldBeCancellable = action.lockmanInfo.isCancellationTarget
  ///   return shouldBeCancellable ?
  ///     effectBuilder(unlockToken).cancellable(id: boundaryId) :
  ///     effectBuilder(unlockToken)
  /// ```
  ///
  /// - Returns: `true` if this action's effect should be cancellable (default),
  ///   `false` if this action's effect should be protected from cancellation
  var isCancellationTarget: Bool { get }
}

// MARK: - Default Implementation

extension LockmanInfo {
  /// Default implementation returns an empty string.
  public var debugAdditionalInfo: String { "" }

  /// Default implementation assumes actions are cancellation targets.
  ///
  /// Most actions should be subject to cancellation by other actions.
  /// Override this property in specific strategy implementations to provide
  /// custom behavior based on strategy-specific settings (e.g., `.none` modes).
  public var isCancellationTarget: Bool { true }
}
