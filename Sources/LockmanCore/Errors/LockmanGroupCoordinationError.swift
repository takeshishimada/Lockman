import Foundation

// MARK: - LockmanGroupCoordinationError

/// Errors that can occur when attempting to acquire a lock using GroupCoordinationStrategy.
///
/// These errors provide information about group coordination conflicts and
/// role-based restrictions.
public enum LockmanGroupCoordinationError: LockmanError {
  /// Indicates that a leader cannot join a group that already has members.
  ///
  /// Leaders must be the first to join a group to establish coordination.
  case leaderCannotJoinNonEmptyGroup(groupIds: Set<String>)
  
  /// Indicates that a member cannot join a group that has no participants.
  ///
  /// Members require an existing leader or other members to coordinate with.
  case memberCannotJoinEmptyGroup(groupIds: Set<String>)
  
  /// Indicates that an action with the same ID is already in the group.
  ///
  /// Each action ID must be unique within a coordination group.
  case actionAlreadyInGroup(actionId: String, groupIds: Set<String>)
  
  /// Indicates that an action is blocked by an exclusive leader.
  ///
  /// Exclusive leaders can prevent other actions from executing based on their exclusion mode.
  case blockedByExclusiveLeader(leaderActionId: String, groupId: String, exclusionMode: GroupCoordinationRole.ExclusionMode)
  
  public var errorDescription: String? {
    switch self {
    case let .leaderCannotJoinNonEmptyGroup(groupIds):
      return "Cannot acquire lock: leader cannot join non-empty groups \(groupIds.sorted())."
    case let .memberCannotJoinEmptyGroup(groupIds):
      return "Cannot acquire lock: member cannot join empty groups \(groupIds.sorted())."
    case let .actionAlreadyInGroup(actionId, groupIds):
      return "Cannot acquire lock: action '\(actionId)' is already in groups \(groupIds.sorted())."
    case let .blockedByExclusiveLeader(leaderActionId, groupId, exclusionMode):
      return "Cannot acquire lock: blocked by exclusive leader '\(leaderActionId)' in group '\(groupId)' (mode: \(exclusionMode))."
    }
  }
  
  public var failureReason: String? {
    switch self {
    case .leaderCannotJoinNonEmptyGroup:
      return "Leaders must be the first to join a coordination group."
    case .memberCannotJoinEmptyGroup:
      return "Members require existing participants in the group for coordination."
    case .actionAlreadyInGroup:
      return "Each action must have a unique ID within its coordination groups."
    case .blockedByExclusiveLeader(_, _, let exclusionMode):
      switch exclusionMode {
      case .all:
        return "Exclusive leader with 'all' mode blocks all other actions."
      case .membersOnly:
        return "Exclusive leader with 'membersOnly' mode blocks member actions."
      case .leadersOnly:
        return "Exclusive leader with 'leadersOnly' mode blocks other leader actions."
      case .none:
        return "This should not happen with 'none' mode."
      }
    }
  }
}