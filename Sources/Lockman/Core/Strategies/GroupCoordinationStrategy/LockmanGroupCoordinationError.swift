import Foundation

// MARK: - LockmanGroupCoordinationError

/// An error that occurs when group coordination strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed due to group coordination rules.
public enum LockmanGroupCoordinationError: LockmanError {
  /// Leader cannot join a non-empty group.
  case leaderCannotJoinNonEmptyGroup(groupIds: Set<AnyLockmanGroupId>)

  /// Member cannot join an empty group.
  case memberCannotJoinEmptyGroup(groupIds: Set<AnyLockmanGroupId>)

  /// Action with the same ID is already in the group.
  case actionAlreadyInGroup(
    existingInfo: LockmanGroupCoordinatedInfo,
    groupIds: Set<AnyLockmanGroupId>
  )

  /// Action is blocked by an exclusive leader.
  case blockedByExclusiveLeader(
    leaderInfo: LockmanGroupCoordinatedInfo,
    groupId: AnyLockmanGroupId,
    entryPolicy: LockmanGroupCoordinationRole.LeaderEntryPolicy
  )
}

// MARK: - LocalizedError Conformance

extension LockmanGroupCoordinationError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .leaderCannotJoinNonEmptyGroup(let groupIds):
      return
        "Cannot acquire lock: leader cannot join non-empty groups \(groupIds.map { "\($0)" }.sorted())."
    case .memberCannotJoinEmptyGroup(let groupIds):
      return
        "Cannot acquire lock: member cannot join empty groups \(groupIds.map { "\($0)" }.sorted())."
    case .actionAlreadyInGroup(let existingInfo, let groupIds):
      return
        "Cannot acquire lock: action '\(existingInfo.actionId)' is already in groups \(groupIds.map { "\($0)" }.sorted())."
    case .blockedByExclusiveLeader(let leaderInfo, let groupId, let entryPolicy):
      return
        "Cannot acquire lock: blocked by exclusive leader '\(leaderInfo.actionId)' in group '\(groupId)' (policy: \(entryPolicy))."
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
    case .blockedByExclusiveLeader(_, _, let entryPolicy):
      switch entryPolicy {
      case .emptyGroup:
        return "Leader with 'emptyGroup' policy requires the group to be completely empty."
      case .withoutMembers:
        return "Leader with 'withoutMembers' policy requires no members in the group."
      case .withoutLeader:
        return "Leader with 'withoutLeader' policy requires no other leaders in the group."
      }
    }
  }
}
