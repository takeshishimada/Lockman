import Foundation

// MARK: - LockmanGroupCoordinationError

/// An error that occurs when group coordination strategy blocks a new action.
///
/// This error is returned when a new action cannot proceed due to group coordination rules.
public enum LockmanGroupCoordinationError: LockmanStrategyError {
  /// Leader cannot join a non-empty group.
  case leaderCannotJoinNonEmptyGroup(
    lockmanInfo: LockmanGroupCoordinatedInfo,
    boundaryId: any LockmanBoundaryId,
    groupIds: Set<AnyLockmanGroupId>
  )

  /// Member cannot join an empty group.
  case memberCannotJoinEmptyGroup(
    lockmanInfo: LockmanGroupCoordinatedInfo,
    boundaryId: any LockmanBoundaryId,
    groupIds: Set<AnyLockmanGroupId>
  )

  /// Action with the same ID is already in the group.
  case actionAlreadyInGroup(
    lockmanInfo: LockmanGroupCoordinatedInfo,
    boundaryId: any LockmanBoundaryId,
    groupIds: Set<AnyLockmanGroupId>
  )

  /// Action is blocked by an exclusive leader.
  case blockedByExclusiveLeader(
    lockmanInfo: LockmanGroupCoordinatedInfo,
    boundaryId: any LockmanBoundaryId,
    groupId: AnyLockmanGroupId,
    entryPolicy: LockmanGroupCoordinationRole.LeaderEntryPolicy
  )
}

// MARK: - LocalizedError Conformance

extension LockmanGroupCoordinationError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .leaderCannotJoinNonEmptyGroup(let lockmanInfo, _, let groupIds):
      return
        "Cannot acquire lock: leader '\(lockmanInfo.actionId)' cannot join non-empty groups \(groupIds.map { "\($0)" }.sorted())."
    case .memberCannotJoinEmptyGroup(let lockmanInfo, _, let groupIds):
      return
        "Cannot acquire lock: member '\(lockmanInfo.actionId)' cannot join empty groups \(groupIds.map { "\($0)" }.sorted())."
    case .actionAlreadyInGroup(let lockmanInfo, _, let groupIds):
      return
        "Cannot acquire lock: action '\(lockmanInfo.actionId)' is already in groups \(groupIds.map { "\($0)" }.sorted())."
    case .blockedByExclusiveLeader(let lockmanInfo, _, let groupId, let entryPolicy):
      return
        "Cannot acquire lock: blocked by exclusive leader '\(lockmanInfo.actionId)' in group '\(groupId)' (policy: \(entryPolicy))."
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
    case .blockedByExclusiveLeader(_, _, _, let entryPolicy):
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

// MARK: - LockmanStrategyError Conformance

extension LockmanGroupCoordinationError {
  public var lockmanInfo: any LockmanInfo {
    switch self {
    case .leaderCannotJoinNonEmptyGroup(let lockmanInfo, _, _):
      return lockmanInfo
    case .memberCannotJoinEmptyGroup(let lockmanInfo, _, _):
      return lockmanInfo
    case .actionAlreadyInGroup(let lockmanInfo, _, _):
      return lockmanInfo
    case .blockedByExclusiveLeader(let lockmanInfo, _, _, _):
      return lockmanInfo
    }
  }

  public var boundaryId: any LockmanBoundaryId {
    switch self {
    case .leaderCannotJoinNonEmptyGroup(_, let boundaryId, _):
      return boundaryId
    case .memberCannotJoinEmptyGroup(_, let boundaryId, _):
      return boundaryId
    case .actionAlreadyInGroup(_, let boundaryId, _):
      return boundaryId
    case .blockedByExclusiveLeader(_, let boundaryId, _, _):
      return boundaryId
    }
  }
}
