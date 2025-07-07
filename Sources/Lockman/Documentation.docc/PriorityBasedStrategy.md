# PriorityBasedStrategy

Control action execution based on priority levels.

## Overview

PriorityBasedStrategy is a strategy that performs execution control based on priority. High-priority processing can interrupt low-priority processing to execute, allowing important processing to be handled preferentially.

This strategy is used in situations where high-urgency processing or control based on importance is required.

## Priority System

### Priority Levels

**high** - High Priority
- Can interrupt all other priority processing
- System-level emergency processing or important user operations

**low** - Low Priority
- Can interrupt none priority processing
- Interrupted by high priority
- Regular background processing

**none** - No Priority
- Bypasses priority system
- Not interrupted by other processing
- Basic processing or temporary disabling

### Exclusive Execution Control

Within the same priority level, control is based on the exclusive execution behavior setting of existing processing:

**exclusive** - Exclusive Execution

```swift
LockmanPriorityBasedInfo(
    actionId: "payment",
    priority: .high(.exclusive)
)
```

- Rejects new processing of the same priority
- Protects important processing from interruption

**replaceable** - Replaceable Execution

```swift
LockmanPriorityBasedInfo(
    actionId: "search", 
    priority: .high(.replaceable)
)
```

- Can be interrupted by new processing of the same priority
- Applied to search or update processing

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

### LockmanPriorityBasedError

**higherPriorityExists** - Higher priority is running

```swift
lockFailure: { error, send in
    if case .higherPriorityExists(let requested, let current) = error as? LockmanPriorityBasedError {
        await send(.priorityConflict("Waiting due to high priority process running"))
    }
}
```

**samePriorityConflict** - Conflict at same priority

```swift
lockFailure: { error, send in
    if case .samePriorityConflict(let priority) = error as? LockmanPriorityBasedError {
        await send(.busyMessage("Process with same priority is running"))
    }
}
```

**LockmanPriorityBasedCancellationError** - Preceding action cancelled

```swift
catch handler: { error, send in
    if let cancellationError = error as? LockmanPriorityBasedCancellationError {
        await send(.processCancelled("Interrupted by high priority process: \(cancellationError.cancelledInfo.actionId)"))
    }
}
```

