import Foundation

/// Role definition for group coordination strategy.
///
/// Defines how an action participates in a group's lifecycle.
public enum GroupCoordinationRole: Sendable, Hashable {
  /// No group coordination - participates in the group without exclusion.
  ///
  /// Actions with this role can execute concurrently without blocking others.
  /// They participate in the group for coordination purposes but don't enforce
  /// any exclusion rules.
  case none

  /// Leader role - can only execute based on the entry policy.
  ///
  /// Acts as the group leader. Entry policy determines when a new leader can join.
  case leader(LeaderEntryPolicy)

  /// Member role - can only execute when the group has active participants.
  ///
  /// Requires an existing group participant (leader or other members) to be active.
  case member

  /// Policy for when a leader can enter a group.
  ///
  /// Determines the group state requirements for a new leader to join.
  public enum LeaderEntryPolicy: String, Sendable, Hashable, CaseIterable {
    /// Leader can only enter when the group is completely empty.
    case emptyGroup

    /// Leader can enter when there are no members (but other leaders are allowed).
    case withoutMembers

    /// Leader can enter when there are no other leaders (but members are allowed).
    case withoutLeader
  }
}

/// Lock information for group coordination strategy.
///
/// Used with `LockmanGroupCoordinationStrategy` to coordinate actions within groups.
/// Actions can belong to a single group or multiple groups (up to 5) and coordinate
/// their execution based on their assigned roles.
///
/// ## Usage Example
/// ```swift
/// // Using String as group ID (backward compatible)
/// let navigationInfo = LockmanGroupCoordinatedInfo(
///   actionId: "navigate",
///   groupId: "mainNavigation",
///   coordinationRole: .none
/// )
///
/// // Using enum as group ID
/// enum AppGroup: String, LockmanGroupId {
///   case navigation, dataLoading, animation
/// }
///
/// let exclusiveNavigation = LockmanGroupCoordinatedInfo(
///   actionId: "exclusiveNavigate",
///   groupId: AppGroup.navigation,
///   coordinationRole: .leader(.emptyGroup)
/// )
///
/// // Member action with enum
/// let animationInfo = LockmanGroupCoordinatedInfo(
///   actionId: "animate",
///   groupId: AppGroup.navigation,
///   coordinationRole: .member
/// )
///
/// // Multiple groups example with enum
/// let complexAction = LockmanGroupCoordinatedInfo(
///   actionId: "complexOperation",
///   groupIds: Set([AppGroup.navigation, AppGroup.dataLoading, AppGroup.animation]),
///   coordinationRole: .member
/// )
/// ```
public struct LockmanGroupCoordinatedInfo: LockmanInfo, Sendable {
  /// The identifier for this specific action.
  public let actionId: LockmanActionId

  /// Unique identifier for this action instance.
  public let uniqueId: UUID

  /// The group identifiers this action belongs to.
  ///
  /// Can contain one or multiple groups (up to 5).
  /// Actions coordinate their execution within all specified groups.
  public let groupIds: Set<AnyLockmanGroupId>

  /// The coordination role of this action within the group(s).
  ///
  /// Determines when this action can acquire a lock based on the group's state.
  /// The same role applies to all groups when using multiple groups.
  public let coordinationRole: GroupCoordinationRole

  /// Creates a new group coordinated lock information with a single group.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - groupId: The group identifier for coordination
  ///   - coordinationRole: The role this action plays in the group
  public init<G: LockmanGroupId>(
    actionId: LockmanActionId,
    groupId: G,
    coordinationRole: GroupCoordinationRole
  ) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.groupIds = [AnyLockmanGroupId(groupId)]
    self.coordinationRole = coordinationRole
  }

  /// Creates a new group coordinated lock information with multiple groups.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - groupIds: The set of group identifiers for coordination (maximum 5)
  ///   - coordinationRole: The role this action plays in all groups
  public init<G: LockmanGroupId>(
    actionId: LockmanActionId,
    groupIds: Set<G>,
    coordinationRole: GroupCoordinationRole
  ) {
    precondition(!groupIds.isEmpty, "At least one group ID must be provided")
    precondition(groupIds.count <= 5, "Maximum 5 groups allowed, got \(groupIds.count)")

    self.actionId = actionId
    self.uniqueId = UUID()
    self.groupIds = Set(groupIds.map(AnyLockmanGroupId.init))
    self.coordinationRole = coordinationRole
  }
}

// MARK: - Equatable

extension LockmanGroupCoordinatedInfo: Equatable {
  public static func == (lhs: LockmanGroupCoordinatedInfo, rhs: LockmanGroupCoordinatedInfo) -> Bool
  {
    // Equality is based on unique ID, not action ID or group ID
    lhs.uniqueId == rhs.uniqueId
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanGroupCoordinatedInfo: CustomDebugStringConvertible {
  public var debugDescription: String {
    let groupIdsStr = groupIds.map { "\($0)" }.sorted().joined(separator: ", ")
    return
      "LockmanGroupCoordinatedInfo(actionId: '\(actionId)', uniqueId: \(uniqueId), groupIds: [\(groupIdsStr)], coordinationRole: .\(coordinationRole))"
  }
}
