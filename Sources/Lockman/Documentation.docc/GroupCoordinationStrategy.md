# GroupCoordinationStrategy

Coordinate actions through leader/member group roles.

## Overview

GroupCoordinationStrategy is a strategy that coordinates related processing as a group. Through leader-member role assignment, it ensures that multiple processes execute in appropriate order and conditions.

This strategy is used in situations where multiple related processes need to work cooperatively.

## Group System

### Coordination Roles

**none** - Non-exclusive Participant

```swift
LockmanGroupCoordinatedInfo(
    actionId: "showProgress",
    groupIds: ["dataLoading"],
    coordinationRole: .none
)
```

- Can participate regardless of group state
- Does not hinder execution of other participants
- Auxiliary processing such as UI updates or logging

**leader** - Group Leader

```swift
LockmanGroupCoordinatedInfo(
    actionId: "startSync",
    groupIds: ["syncGroup"],
    coordinationRole: .leader(.emptyGroup)
)
```

- Role to start group activities
- Controls participation conditions according to entry policy
- Enables member participation

**member** - Group Member

```swift
LockmanGroupCoordinatedInfo(
    actionId: "processData", 
    groupIds: ["syncGroup"],
    coordinationRole: .member
)
```

- Can only participate in active groups
- Executes when leader or other participants are present
- Responsible for coordinated processing

### Leader Entry Policy

**emptyGroup** - Start only in empty group

```swift
.leader(.emptyGroup)
```

- Can only participate when group is completely empty
- Starts new activity cycle
- Most strict control

**withoutMembers** - Start without members

```swift
.leader(.withoutMembers)
```

- Can participate when no members are present
- Other leaders are allowed
- Enables coordination between leaders

**withoutLeader** - Start without leader

```swift
.leader(.withoutLeader)
```

- Can participate when no other leaders are present
- Members are allowed
- Exclusive control of leader authority

## Usage

### Basic Usage Example

```swift
enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    
    @LockmanGroupCoordination
    enum ViewAction {
        case startDataSync
        case processChunk
        case showProgress
        
        var lockmanInfo: LockmanGroupCoordinatedInfo {
            switch self {
            case .startDataSync:
                return LockmanGroupCoordinatedInfo(
                    actionId: actionName,
                    groupIds: ["dataSync"],
                    coordinationRole: .leader(.emptyGroup)
                )
            case .processChunk:
                return LockmanGroupCoordinatedInfo(
                    actionId: actionName,
                    groupIds: ["dataSync"],
                    coordinationRole: .member
                )
            case .showProgress:
                return LockmanGroupCoordinatedInfo(
                    actionId: actionName,
                    groupIds: ["dataSync"],
                    coordinationRole: .none
                )
            }
        }
    }
    
    enum InternalAction {
        case syncCompleted
        case chunkProcessed
        case alreadyActive(String)
        case groupBusy(String)
        case noActiveGroup(String)
    }
}
```

### Coordination with Multiple Groups

```swift
LockmanGroupCoordinatedInfo(
    actionId: "crossGroupOperation",
    groupIds: ["group1", "group2", "group3"],
    coordinationRole: .leader(.emptyGroup)
)
```

## Operation Examples

### Leader-Member Coordination

```
Time: 0s  - leader(.emptyGroup) starts     → ✅ Execute (group empty)
Time: 1s  - member join request            → ✅ Execute (leader exists)
Time: 1s  - member join request            → ✅ Execute (group active)
Time: 2s  - leader(.emptyGroup) request    → ❌ Reject (group active)
Time: 5s  - All participants complete      → 🔓 Group dissolves
Time: 6s  - leader(.emptyGroup) request    → ✅ Execute (group empty)
```

### Entry Policy Differences

```
// .emptyGroup case
Group state: [empty] → leader request → ✅ Allow
Group state: [member] → leader request → ❌ Reject

// .withoutMembers case
Group state: [leader] → leader request → ✅ Allow
Group state: [member] → leader request → ❌ Reject

// .withoutLeader case
Group state: [member] → leader request → ✅ Allow
Group state: [leader] → leader request → ❌ Reject
```

## Error Handling

For errors that may occur with GroupCoordinationStrategy and their solutions, please also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### LockmanGroupCoordinationError

**actionAlreadyInGroup** - Action already in group

```swift
lockFailure: { error, send in
    if case .actionAlreadyInGroup(let existingInfo, let groupIds) = error as? LockmanGroupCoordinationError {
        state.message = "Process is already running"
    }
}
```

**leaderCannotJoinNonEmptyGroup** - Leader cannot join non-empty group

```swift
lockFailure: { error, send in
    if case .leaderCannotJoinNonEmptyGroup(let groupIds) = error as? LockmanGroupCoordinationError {
        state.message = "Cannot start because other processing is running"
    }
}
```

**memberCannotJoinEmptyGroup** - Member cannot join empty group

```swift
lockFailure: { error, send in
    if case .memberCannotJoinEmptyGroup(let groupIds) = error as? LockmanGroupCoordinationError {
        state.message = "No active group"
    }
}
```

