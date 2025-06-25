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
}

// MARK: - Default Implementation

extension LockmanInfo {
  /// Default implementation returns an empty string.
  public var debugAdditionalInfo: String { "" }
}
