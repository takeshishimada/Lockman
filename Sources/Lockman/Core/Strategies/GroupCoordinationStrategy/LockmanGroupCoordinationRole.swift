/// Role definition for group coordination strategy.
///
/// Defines how an action participates in a group's lifecycle.
public enum LockmanGroupCoordinationRole: Sendable, Hashable {
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
