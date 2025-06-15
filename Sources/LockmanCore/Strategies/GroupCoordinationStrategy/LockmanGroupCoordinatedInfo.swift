import Foundation

/// Role definition for group coordination strategy.
///
/// Defines how an action participates in a group's lifecycle.
public enum GroupCoordinationRole: String, Sendable, Hashable, CaseIterable {
  /// Leader role - can only execute when the group is empty.
  ///
  /// Acts as the group leader. Only one leader can start a group at a time.
  case leader

  /// Member role - can only execute when the group has active participants.
  ///
  /// Requires an existing group participant (leader or other members) to be active.
  case member
}

/// Lock information for group coordination strategy.
///
/// Used with `LockmanGroupCoordinationStrategy` to coordinate actions within groups.
/// Actions can belong to a single group or multiple groups (up to 5) and coordinate
/// their execution based on their assigned roles.
///
/// ## Usage Example
/// ```swift
/// // Single group example
/// let navigationInfo = LockmanGroupCoordinatedInfo(
///   actionId: "navigate",
///   groupId: "mainNavigation",
///   coordinationRole: .leader
/// )
///
/// // Multiple groups example
/// let complexAction = LockmanGroupCoordinatedInfo(
///   actionId: "complexOperation",
///   groupIds: ["navigation", "dataLoading", "animation"],
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
  public let groupIds: Set<String>

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
  public init(
    actionId: LockmanActionId,
    groupId: String,
    coordinationRole: GroupCoordinationRole
  ) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.groupIds = [groupId]
    self.coordinationRole = coordinationRole
  }

  /// Creates a new group coordinated lock information with multiple groups.
  ///
  /// - Parameters:
  ///   - actionId: The identifier for this action
  ///   - groupIds: The set of group identifiers for coordination (maximum 5)
  ///   - coordinationRole: The role this action plays in all groups
  public init(
    actionId: LockmanActionId,
    groupIds: Set<String>,
    coordinationRole: GroupCoordinationRole
  ) {
    precondition(!groupIds.isEmpty, "At least one group ID must be provided")
    precondition(groupIds.count <= 5, "Maximum 5 groups allowed, got \(groupIds.count)")
    precondition(groupIds.allSatisfy { !$0.isEmpty }, "Group IDs cannot be empty strings")

    self.actionId = actionId
    self.uniqueId = UUID()
    self.groupIds = groupIds
    self.coordinationRole = coordinationRole
  }
}

// MARK: - Equatable

extension LockmanGroupCoordinatedInfo: Equatable {
  public static func == (lhs: LockmanGroupCoordinatedInfo, rhs: LockmanGroupCoordinatedInfo) -> Bool {
    // Equality is based on unique ID, not action ID or group ID
    lhs.uniqueId == rhs.uniqueId
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanGroupCoordinatedInfo: CustomDebugStringConvertible {
  public var debugDescription: String {
    let groupIdsStr = groupIds.sorted().joined(separator: ", ")
    return "LockmanGroupCoordinatedInfo(actionId: '\(actionId)', uniqueId: \(uniqueId), groupIds: [\(groupIdsStr)], coordinationRole: .\(coordinationRole))"
  }
}
