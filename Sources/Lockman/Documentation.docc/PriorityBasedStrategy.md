# PriorityBasedStrategy

Control action execution based on priority levels.

## Overview

PriorityBasedStrategy is a strategy that performs execution control based on priority. High-priority operations can interrupt low-priority operations to execute, allowing important operations to be handled preferentially.

This strategy is used in situations where high-urgency operations or control based on importance is required.

## Priority System

### Priority Levels

**high** - High Priority
- Can interrupt all other priority operations
- System-level emergency operations or important user operations

**low** - Low Priority
- Can interrupt none priority operations
- Interrupted by high priority
- Regular background operations

**none** - No Priority
- Bypasses priority system
- Not interrupted by other operations
- Basic operations or temporary disabling

### Exclusive Execution Control

Within the same priority level, control is based on the exclusive execution behavior setting of existing operations:

**exclusive** - Exclusive Execution

```swift
LockmanPriorityBasedInfo(
    actionId: "payment",
    priority: .high(.exclusive)
)
```

- Rejects new operations of the same priority
- Protects important operations from interruption

**replaceable** - Replaceable Execution

```swift
LockmanPriorityBasedInfo(
    actionId: "search", 
    priority: .high(.replaceable)
)
```

- Can be interrupted by new operations of the same priority
- Applied to search or update operations

## Usage

### Basic Usage Example

```swift
@LockmanPriorityBased
enum ViewAction {
    case emergencySync
    case normalSync
    case backgroundTask
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .emergencySync:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        case .normalSync:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .low(.replaceable)
            )
        case .backgroundTask:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .none
            )
        }
    }
}
```


## Operation Examples

### Interruption by Priority

```
Time: 0s  - Low priority process starts    → ✅ Execute
Time: 2s  - High priority process request  → ✅ Execute (interrupts low process)
Time: 2s  - Low priority process           → 🛑 Cancel
Time: 5s  - High priority process complete → ✅ Complete
```

### Control at Same Priority

```
// Exclusive setting case
Time: 0s  - high(.exclusive) starts  → ✅ Execute
Time: 1s  - high(.exclusive) request → ❌ Reject
Time: 3s  - First process completes  → ✅ Complete
Time: 4s  - high(.exclusive) request → ✅ Execute

// Replaceable setting case
Time: 0s  - high(.replaceable) starts  → ✅ Execute
Time: 1s  - high(.replaceable) request → ✅ Execute (interrupts previous)
Time: 1s  - First process              → 🛑 Cancel
```

## Error Handling

For errors that may occur with PriorityBasedStrategy and their solutions, please also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### Error Types

PriorityBasedStrategy uses two error types, both conforming to `LockmanCancellationError` protocol:

#### LockmanPriorityBasedBlockedError

Occurs when a new action is blocked due to priority conflicts.

**BlockedReason cases:**
- **higherPriorityExists** - Higher priority is running
- **samePriorityConflict** - Conflict at same priority

```swift
lockFailure: { error, send in
    if let blockedError = error as? LockmanPriorityBasedBlockedError {
        switch blockedError.reason {
        case .higherPriorityExists(let requested, let current):
            await send(.priorityConflict("Waiting due to high priority process running"))
        case .samePriorityConflict(let priority):
            await send(.busyMessage("Process with same priority is running"))
        }
    }
}
```

#### LockmanPriorityBasedCancellationError

Occurs when an existing action is cancelled by preemption.

```swift
catch handler: { error, send in
    if let cancellationError = error as? LockmanPriorityBasedCancellationError {
        await send(.processCancelled("Interrupted by high priority process: \(cancellationError.cancelledInfo.actionId)"))
    }
}
```

