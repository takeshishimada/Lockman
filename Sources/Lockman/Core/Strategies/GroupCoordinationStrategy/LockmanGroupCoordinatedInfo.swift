import Foundation

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
  /// The strategy identifier for this lock info.
  public let strategyId: LockmanStrategyId

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
  public let coordinationRole: LockmanGroupCoordinationRole

  /// Creates a new group coordinated lock information with a single group.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this lock (defaults to .groupCoordination)
  ///   - actionId: The identifier for this action
  ///   - groupId: The group identifier for coordination
  ///   - coordinationRole: The role this action plays in the group
  public init<G: LockmanGroupId>(
    strategyId: LockmanStrategyId = .groupCoordination,
    actionId: LockmanActionId,
    groupId: G,
    coordinationRole: LockmanGroupCoordinationRole
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.groupIds = [AnyLockmanGroupId(groupId)]
    self.coordinationRole = coordinationRole
  }

  /// Creates a new group coordinated lock information with multiple groups.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this lock (defaults to .groupCoordination)
  ///   - actionId: The identifier for this action
  ///   - groupIds: The set of group identifiers for coordination (maximum 5)
  ///   - coordinationRole: The role this action plays in all groups
  public init<G: LockmanGroupId>(
    strategyId: LockmanStrategyId = .groupCoordination,
    actionId: LockmanActionId,
    groupIds: Set<G>,
    coordinationRole: LockmanGroupCoordinationRole
  ) {
    self.strategyId = strategyId
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
      "LockmanGroupCoordinatedInfo(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), groupIds: [\(groupIdsStr)], coordinationRole: .\(coordinationRole))"
  }

  // MARK: - Debug Additional Info

  public var debugAdditionalInfo: String {
    let groupsStr = groupIds.map { "\($0)" }.sorted().joined(separator: ",")
    return "groups: \(groupsStr) r: \(coordinationRole)"
  }
}
