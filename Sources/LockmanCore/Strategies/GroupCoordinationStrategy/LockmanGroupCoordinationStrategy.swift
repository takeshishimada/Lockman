import Foundation

/// A strategy that coordinates actions within groups based on their roles.
///
/// This strategy manages group-based locking where:
/// - **Leaders** can only execute when their group is empty (no other members)
/// - **Members** can only execute when their group has active participants
///
/// This creates a coordination pattern where leaders start group activities
/// and members can only join existing group activities.
///
/// ## Key Features
/// - Groups are identified by string IDs and operate independently
/// - Multiple members can execute concurrently within the same group
/// - Prevents duplicate execution of the same action within a group
/// - Groups automatically dissolve when the last member completes
///
/// ## Usage Example
/// ```swift
/// let strategy = LockmanGroupCoordinationStrategy()
/// let boundaryId = "mainScreen"
///
/// // Normal leader starts the group
/// let leaderInfo = LockmanGroupCoordinatedInfo(
///   actionId: "loadData",
///   groupId: "dataLoading",
///   coordinationRole: .leader(.none)
/// )
///
/// // Can lock when group is empty
/// strategy.canLock(id: boundaryId, info: leaderInfo) // .success
///
/// // Members can join active group
/// let memberInfo = LockmanGroupCoordinatedInfo(
///   actionId: "showProgress",
///   groupId: "dataLoading",
///   coordinationRole: .member
/// )
///
/// // Exclusive leader example
/// let exclusiveNav = LockmanGroupCoordinatedInfo(
///   actionId: "navigate",
///   groupId: "navigation",
///   coordinationRole: .leader(.all)  // Blocks all other actions
/// )
/// ```
public final class LockmanGroupCoordinationStrategy: LockmanStrategy, @unchecked Sendable {
  public typealias I = LockmanGroupCoordinatedInfo

  /// The identifier for this strategy.
  public let strategyId: LockmanStrategyId

  /// Thread-safe storage for group states per boundary.
  private let storage = ManagedCriticalState<[AnyLockmanBoundaryId: GroupBoundaryState]>([:])

  /// State for all groups within a boundary.
  private struct GroupBoundaryState {
    /// Group states keyed by group ID.
    var groups: [String: GroupState] = [:]
  }

  /// State of a single group.
  private struct GroupState {
    /// Active members in the group, keyed by action ID.
    /// Prevents duplicate actions with the same ID.
    var activeMembers: [LockmanActionId: GroupMember] = [:]

    /// Whether the group has any active members.
    var isEmpty: Bool {
      activeMembers.isEmpty
    }

    /// Whether the group has an active leader.
    var hasLeader: Bool {
      activeMembers.values.contains { member in
        if case .leader = member.role {
          return true
        }
        return false
      }
    }

    /// Information about a group member.
    struct GroupMember {
      let info: LockmanGroupCoordinatedInfo
      var role: GroupCoordinationRole { info.coordinationRole }
    }
  }

  /// The shared singleton instance.
  public static let shared = LockmanGroupCoordinationStrategy()

  /// Creates a new group coordination strategy instance.
  public init() {
    self.strategyId = Self.makeStrategyId()
  }

  /// Creates a strategy identifier for the group coordination strategy.
  ///
  /// This method provides a consistent way to generate strategy IDs that can be used
  /// both during strategy initialization and in macro-generated code.
  ///
  /// - Returns: A `LockmanStrategyId` with the name "groupCoordination"
  public static func makeStrategyId() -> LockmanStrategyId {
    .groupCoordination
  }

  // MARK: - LockmanStrategy

  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanGroupCoordinatedInfo
  ) -> LockmanResult {
    let result: LockmanResult
    var failureReason: String?

    result = storage.withCriticalRegion { storage in
      let anyBoundaryId = AnyLockmanBoundaryId(id)
      let boundaryState = storage[anyBoundaryId]

      // Check all groups (AND condition - must satisfy conditions in all groups)
      for groupId in info.groupIds {
        let groupState = boundaryState?.groups[groupId]

        // Check if this specific action is already active in this group
        if groupState?.activeMembers[info.actionId] != nil {
          // Same action ID cannot be executed twice in the same group
          failureReason = "Action '\(info.actionId)' is already active in group '\(groupId)'"
          return .failure(LockmanGroupCoordinationError.actionAlreadyInGroup(actionId: info.actionId, groupIds: Set([groupId])))
        }

        // Check for exclusive leader blocking
        if let groupState = groupState {
          for (_, member) in groupState.activeMembers {
            if case .leader(let mode) = member.role {
              // Skip if it's the same action
              if member.info.actionId == info.actionId { continue }
              
              // Check if this leader blocks the new action
              let shouldBlock: Bool
              switch mode {
              case .none:
                shouldBlock = false
              case .all:
                shouldBlock = true
              case .membersOnly:
                shouldBlock = (info.coordinationRole == .member)
              case .leadersOnly:
                if case .leader = info.coordinationRole {
                  shouldBlock = true
                } else {
                  shouldBlock = false
                }
              }
              
              if shouldBlock {
                failureReason = "Blocked by exclusive leader '\(member.info.actionId)' in group '\(groupId)'"
                return .failure(LockmanGroupCoordinationError.blockedByExclusiveLeader(
                  leaderActionId: member.info.actionId,
                  groupId: groupId,
                  exclusionMode: mode
                ))
              }
            }
          }
        }
        
        // Apply role-based rules
        switch info.coordinationRole {
        case .leader:
          // Leaders can only start when group is empty
          if groupState != nil, !groupState!.isEmpty {
            failureReason = "Leader cannot start: group '\(groupId)' already has active members"
            return .failure(LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(groupIds: Set([groupId])))
          }

        case .member:
          // Members can only join when group has active participants
          if groupState == nil || groupState!.isEmpty {
            failureReason = "Member cannot join: group '\(groupId)' has no active participants"
            return .failure(LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(groupIds: Set([groupId])))
          }
        }
      }

      // All groups satisfied the conditions
      return .success
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "GroupCoordination",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason
    )

    return result
  }

  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanGroupCoordinatedInfo
  ) {
    storage.withCriticalRegion { storage in
      let anyBoundaryId = AnyLockmanBoundaryId(id)

      // Ensure boundary state exists
      if storage[anyBoundaryId] == nil {
        storage[anyBoundaryId] = GroupBoundaryState()
      }

      // Add member to all groups
      for groupId in info.groupIds {
        // Ensure group state exists
        if storage[anyBoundaryId]!.groups[groupId] == nil {
          storage[anyBoundaryId]!.groups[groupId] = GroupState()
        }

        // Add member to group
        let member = GroupState.GroupMember(info: info)
        storage[anyBoundaryId]!.groups[groupId]!.activeMembers[info.actionId] = member
      }
    }
  }

  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanGroupCoordinatedInfo
  ) {
    storage.withCriticalRegion { storage in
      let anyBoundaryId = AnyLockmanBoundaryId(id)

      // Remove member from all groups
      for groupId in info.groupIds {
        // Remove member from group
        storage[anyBoundaryId]?.groups[groupId]?.activeMembers.removeValue(forKey: info.actionId)

        // Clean up empty groups
        if storage[anyBoundaryId]?.groups[groupId]?.isEmpty == true {
          storage[anyBoundaryId]?.groups.removeValue(forKey: groupId)
        }
      }

      // Clean up empty boundaries
      if storage[anyBoundaryId]?.groups.isEmpty == true {
        storage.removeValue(forKey: anyBoundaryId)
      }
    }
  }

  public func cleanUp() {
    storage.withCriticalRegion { storage in
      storage.removeAll()
    }
  }

  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    storage.withCriticalRegion { storage in
      let anyBoundaryId = AnyLockmanBoundaryId(id)
      storage.removeValue(forKey: anyBoundaryId)
    }
  }

  /// Returns current locks information for debugging.
  ///
  /// Provides a snapshot of all currently held locks across all boundaries.
  /// The returned dictionary maps boundary identifiers to their active lock information.
  ///
  /// - Returns: Dictionary of boundary IDs to their active locks
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    storage.withCriticalRegion { storage in
      var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

      for (boundaryId, boundaryState) in storage {
        var lockInfos: [any LockmanInfo] = []

        // Collect all active members from all groups
        for (_, groupState) in boundaryState.groups {
          for (_, member) in groupState.activeMembers {
            lockInfos.append(member.info)
          }
        }

        if !lockInfos.isEmpty {
          result[boundaryId] = lockInfos
        }
      }

      return result
    }
  }
}
