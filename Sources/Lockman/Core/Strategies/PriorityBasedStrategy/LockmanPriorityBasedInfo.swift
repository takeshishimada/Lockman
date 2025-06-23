import Foundation

/// Information required for priority-based locking behavior.
///
/// This structure encapsulates the data needed by `LockmanPriorityBasedStrategy`
/// to make priority-based locking decisions. It combines action identification
/// with priority levels and concurrency behavior policies.
///
/// ## Priority System
/// The priority system supports three levels with configurable concurrency behavior:
/// - **High Priority**: Critical operations (login, payment, etc.)
/// - **Low Priority**: Background operations (analytics, caching, etc.)
/// - **No Priority**: Simple operations that don't participate in priority conflicts
///
/// ## Concurrency Behavior
/// When actions have the same priority level, the `ConcurrencyBehavior` determines
/// how concurrent execution is handled:
/// - **Exclusive**: This action runs exclusively, blocking new actions
/// - **Replaceable**: This action can be replaced by new actions
///
/// ## Usage Examples
/// ```swift
/// // High priority payment (exclusive - must complete)
/// let paymentInfo = LockmanPriorityBasedInfo(
///   actionId: "payment",
///   priority: .high(.exclusive)
/// )
///
/// // High priority search (replaceable - newer search cancels older)
/// let searchInfo = LockmanPriorityBasedInfo(
///   actionId: "search",
///   priority: .high(.replaceable)
/// )
///
/// // Simple operation without priority conflicts
/// let alertInfo = LockmanPriorityBasedInfo(
///   actionId: "showAlert",
///   priority: .none
/// )
/// ```
public struct LockmanPriorityBasedInfo: LockmanInfo, Sendable, Equatable {
  // MARK: - LockmanInfo Protocol Properties

  /// The action identifier used for lock conflict detection.
  ///
  /// This identifier, combined with the priority level, determines how this
  /// action interacts with other priority-based actions. Actions with the
  /// same ID will be subject to priority-based conflict resolution.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific lock info instance.
  ///
  /// Used for equality comparison and instance tracking within the locking system.
  /// Each instance gets a unique UUID regardless of shared action IDs or priorities.
  public let uniqueId: UUID

  /// The priority level and concurrency behavior for this action.
  ///
  /// This property determines:
  /// - How this action competes with other priority-based actions
  /// - What happens when new actions of the same priority are requested
  /// - Whether this action participates in priority conflicts at all
  ///
  /// See `Priority` enum for detailed information about priority levels and behaviors.
  public let priority: Priority

  /// Whether this action blocks other actions with the same actionId.
  ///
  /// When set to `true`, this action will prevent any other action with the same
  /// `actionId` from being locked, regardless of priority levels. This is useful
  /// for operations that must be unique per action type.
  ///
  /// When set to `false`, actions with the same `actionId` follow the
  /// normal priority rules and can coexist based on their priority levels.
  ///
  /// ## Use Cases
  /// - **true**: Payment processing, file saves, or any operation where only one
  ///   instance of a specific action should run at a time
  /// - **false**: Search queries, UI updates, or operations that can have multiple
  ///   instances with different priorities
  ///
  /// ## Example
  /// ```swift
  /// // Only one payment can process at a time
  /// let payment = LockmanPriorityBasedInfo(
  ///   actionId: "payment",
  ///   priority: .high(.exclusive),
  ///   blocksSameAction: true
  /// )
  ///
  /// // Multiple searches can coexist based on priority
  /// let search = LockmanPriorityBasedInfo(
  ///   actionId: "search",
  ///   priority: .high(.replaceable),
  ///   blocksSameAction: false
  /// )
  /// ```
  public let blocksSameAction: Bool

  // MARK: - Initialization

  /// Creates a new priority-based lock information instance.
  ///
  /// - Parameters:
  ///   - actionId: A unique identifier for the action
  ///   - priority: The priority level and concurrency behavior for this action
  ///   - blocksSameAction: Whether to block other actions with the same actionId (default: true)
  ///
  /// ## Design Note
  /// The `uniqueId` is automatically generated to ensure each instance has
  /// a distinct identity, even when multiple instances share the same
  /// `actionId` and `priority`.
  public init(
    actionId: LockmanActionId,
    priority: Priority,
    blocksSameAction: Bool = true
  ) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.priority = priority
    self.blocksSameAction = blocksSameAction
  }

  // MARK: - Equatable Implementation

  /// Compares two instances for equality based on their unique identifiers.
  ///
  /// Two `LockmanPriorityBasedInfo` instances are considered equal only if
  /// they have the same `uniqueId`. This ensures each lock info instance
  /// maintains a distinct identity regardless of shared action IDs or priorities.
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
    let priorityStr: String
    switch priority {
    case .none:
      priorityStr = ".none"
    case let .high(behavior):
      priorityStr = ".high(.\(behavior))"
    case let .low(behavior):
      priorityStr = ".low(.\(behavior))"
    }

    return
      "LockmanPriorityBasedInfo(actionId: '\(actionId)', uniqueId: \(uniqueId), priority: \(priorityStr), blocksSameAction: \(blocksSameAction))"
  }
}

// MARK: - Priority Definition

extension LockmanPriorityBasedInfo {
  /// Priority levels with configurable concurrency behavior.
  ///
  /// This enum defines the priority hierarchy and how concurrent execution
  /// of same-priority actions should be handled.
  public enum Priority: Sendable, Equatable {
    /// No priority level - exempt from priority-based conflicts.
    ///
    /// Actions with `.none` priority do not participate in priority-based
    /// conflict resolution. They follow simple flow handling similar to
    /// non-priority operations.
    ///
    /// ## Use Cases
    /// - Simple UI updates (showing alerts, updating labels)
    /// - Non-critical operations that should never conflict
    /// - Operations that should run independently of priority system
    case none

    /// High priority level with concurrency behavior specification.
    ///
    /// High priority actions can preempt lower priority actions and take
    /// precedence in the execution queue. Use for critical user operations
    /// that should not be delayed.
    ///
    /// - Parameter behavior: How to handle concurrent same-priority actions
    ///
    /// ## Use Cases
    /// - User authentication (login, logout)
    /// - Payment processing
    /// - Critical data updates
    /// - Navigation operations
    case high(ConcurrencyBehavior)

    /// Low priority level with concurrency behavior specification.
    ///
    /// Low priority actions yield to high priority actions but can compete
    /// among themselves based on the specified behavior. Use for background
    /// operations that shouldn't interfere with user interactions.
    ///
    /// - Parameter behavior: How to handle concurrent same-priority actions
    ///
    /// ## Use Cases
    /// - Background data synchronization
    /// - Analytics reporting
    /// - Cache management
    /// - File uploads or downloads
    case low(ConcurrencyBehavior)
  }

  /// Behavior for handling concurrent actions of the same priority level.
  ///
  /// When two actions have the same priority and compete for the same resource,
  /// this behavior determines how the conflict is resolved.
  public enum ConcurrencyBehavior: Sendable, Equatable {
    /// Exclusive execution - this action blocks new same-priority actions.
    ///
    /// When this action is running and a new same-priority action is requested,
    /// the new action will be blocked (receive `.failure` from `canLock`).
    /// This action continues execution until completion.
    ///
    /// ## Use Cases
    /// - File operations that must complete (save, upload)
    /// - Payment processing that cannot be interrupted
    /// - Database transactions
    /// - Critical operations where completion is essential
    ///
    /// ## Example
    /// ```swift
    /// let saveFile = LockmanPriorityBasedInfo(
    ///   actionId: "saveDocument",
    ///   priority: .high(.exclusive)
    /// )
    /// // Any other same-priority action will be blocked until save completes
    /// ```
    case exclusive

    /// Replaceable execution - this action yields to new same-priority actions.
    ///
    /// When this action is running and a new same-priority action is requested,
    /// this action will be canceled (triggering `.successWithPrecedingCancellation`)
    /// and the new action will take its place.
    ///
    /// ## Use Cases
    /// - Search queries where latest input is most relevant
    /// - Live previews that should update with new data
    /// - Real-time UI updates
    /// - Operations where newest request has the highest value
    ///
    /// ## Example
    /// ```swift
    /// let searchQuery = LockmanPriorityBasedInfo(
    ///   actionId: "search",
    ///   priority: .high(.replaceable)
    /// )
    /// // New search queries will cancel this one and take over
    /// ```
    case replaceable
  }
}

// MARK: - Priority Helpers

extension LockmanPriorityBasedInfo.Priority {
  /// Returns the concurrency behavior for this priority level.
  ///
  /// - Returns: The `ConcurrencyBehavior` if this is a `.high` or `.low` priority,
  ///            or `nil` if this is `.none` priority (which doesn't use behaviors)
  public var behavior: LockmanPriorityBasedInfo.ConcurrencyBehavior? {
    switch self {
    case .none:
      return nil
    case let .high(behavior),
      let .low(behavior):
      return behavior
    }
  }
}

// MARK: - Priority Comparison

extension LockmanPriorityBasedInfo.Priority: Comparable {
  /// Compares two priorities based on their hierarchical levels.
  ///
  /// Priority ordering: `.none` < `.low` < `.high`
  ///
  /// This comparison is used by the priority strategy to determine which
  /// actions should take precedence over others.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side priority to compare
  ///   - rhs: The right-hand side priority to compare
  /// - Returns: `true` if `lhs` has lower priority than `rhs`
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.priorityValue < rhs.priorityValue
  }

  /// Checks if two priorities have the same hierarchical level.
  ///
  /// Priorities are equal if they have the same priority value, regardless
  /// of their concurrency behaviors. This is used to determine when
  /// same-priority behaviors should be applied.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side priority
  ///   - rhs: The right-hand side priority
  /// - Returns: `true` if both priorities have the same hierarchical level
  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.priorityValue == rhs.priorityValue
  }

  /// Internal priority value for hierarchical comparison.
  ///
  /// Maps priority levels to integers for easy comparison:
  /// - `.none` = 0 (lowest priority)
  /// - `.low(_)` = 1 (medium priority)
  /// - `.high(_)` = 2 (highest priority)
  private var priorityValue: Int {
    switch self {
    case .none: return 0
    case .low: return 1
    case .high: return 2
    }
  }
}
