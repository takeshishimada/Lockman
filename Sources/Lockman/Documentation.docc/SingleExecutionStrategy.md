# SingleExecutionStrategy

Prevent duplicate execution of the same action.

## Overview

SingleExecutionStrategy is a strategy for preventing duplicate execution. It prevents the same operation from being executed redundantly, maintaining data consistency and application stability.

This is the most frequently used basic strategy for preventing continuous user actions and duplicate execution of automatic operations.

## Execution Modes

SingleExecutionStrategy supports three execution modes:

### none - No Control

```swift
LockmanSingleExecutionInfo(
    actionId: "save",
    mode: .none
)
```

- Executes all operations without exclusive control
- Used when temporarily disabling lock functionality
- Applied for behavior verification during debugging or testing

### boundary - Boundary-level Exclusive Control

```swift
LockmanSingleExecutionInfo(
    actionId: "save", 
    mode: .boundary
)
```

- Only one process can execute within the same boundary
- Exclusive control at screen or component level
- Applied when wanting to control entire UI operations

### action - Action-level Exclusive Control

```swift
LockmanSingleExecutionInfo(
    actionId: "save",
    mode: .action  
)
```

- Prevents only duplicate execution of the same action
- Different actions can execute concurrently
- Applied when wanting to control only specific operations

## Usage

### Basic Usage Example

```swift
@LockmanSingleExecution
enum ViewAction {
    case save
    case load
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .save:
            return LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action
            )
        case .load:
            return LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action
            )
        }
    }
}
```

### Usage with Reducer.lock()

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .saveButtonTapped:
            return .run { send in
                try await saveUserData()
                await send(.saveCompleted)
            } catch: { error, send in
                await send(.saveError(error.localizedDescription))
            }
            
        case .loadButtonTapped:
            return .run { send in
                let data = try await loadUserData()
                await send(.loadCompleted(data))
            }
            // Other cases...
        }
    }
    .lock(
        boundaryId: CancelID.userAction,
        lockFailure: { error, send in
            if let singleError = error as? LockmanSingleExecutionError {
                await send(.showBusyMessage("\(singleError.lockmanInfo.actionId) is currently running"))
            }
        }
    )
}
```

### Advanced Usage with Effect.lock

For cases requiring fine-grained control:

```swift
case .saveButtonTapped:
    return .run { send in
        try await saveUserData()
        await send(.saveCompleted)
    } catch: { error, send in
        await send(.saveError(error.localizedDescription))
    }
    .lock(
        action: action,
        boundaryId: CancelID.userAction,
        lockFailure: { error, send in
            await send(.saveBusy("Save process is currently running"))
        }
    )
```

## Operation Examples

### action mode

```
Time: 0s  - save action starts → ✅ Execute
Time: 1s  - save action request → ❌ Reject (same action running)
Time: 1s  - load action request → ✅ Execute (different action)
Time: 3s  - save action complete → 🔓 Unlock
Time: 4s  - save action request → ✅ Execute (previous process completed)
```

### boundary mode

```
Time: 0s  - save action starts → ✅ Execute
Time: 1s  - save action request → ❌ Reject (running within boundary)
Time: 1s  - load action request → ❌ Reject (running within boundary)
Time: 3s  - save action complete → 🔓 Unlock
Time: 4s  - load action request → ✅ Execute (boundary process completed)
```

## Error Handling

For errors that may occur with SingleExecutionStrategy and their solutions, please also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### LockmanSingleExecutionError

This error conforms to `LockmanStrategyError` protocol and provides:
- `lockmanInfo`: Information about the action that couldn't acquire the lock
- `boundaryId`: Where the lock failure occurred
- `errorDescription`: Human-readable error description
- `failureReason`: Specific reason for the failure

**Error cases:**
- **boundaryAlreadyLocked** - Boundary is already locked by another action
- **actionAlreadyRunning** - Same action ID is already running

```swift
lockFailure: { error, send in
    if let singleError = error as? LockmanSingleExecutionError {
        switch singleError {
        case .boundaryAlreadyLocked(_, let lockmanInfo):
            await send(.showBusyMessage("Another process is running: \(lockmanInfo.actionId)"))
        case .actionAlreadyRunning(_, let lockmanInfo):
            await send(.showBusyMessage("\(lockmanInfo.actionId) is running"))
        }
    } else {
        await send(.showBusyMessage("Cannot start operation"))
    }
}
```

