# SingleExecutionStrategy

Prevent duplicate execution of the same action.

## Overview

SingleExecutionStrategy is a strategy for preventing duplicate execution. It prevents the same processing from being executed redundantly, maintaining data consistency and application stability.

This is the most frequently used basic strategy for preventing continuous user operations and duplicate execution of automatic processing.

## Execution Modes

SingleExecutionStrategy supports three execution modes:

### none - No Control

```swift
LockmanSingleExecutionInfo(
    actionId: "save",
    mode: .none
)
```

- Executes all processing without exclusive control
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
- Applied when wanting to control only specific processing

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
            }
            .catch { error, send in
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
            if let singleError = error as? LockmanSingleExecutionCancellationError,
               case .actionAlreadyRunning(let info) = singleError.reason {
                await send(.showBusyMessage("\(info.actionId) is currently running"))
            }
        }
    )
}
```

### Advanced Usage with withLock

For cases requiring fine-grained control:

```swift
case .saveButtonTapped:
    return .withLock(
        operation: { send in
            try await saveUserData()
            await send(.saveCompleted)
        },
        catch handler: { error, send in
            await send(.saveError(error.localizedDescription))
        },
        lockFailure: { error, send in
            await send(.saveBusy("Save process is currently running"))
        },
        action: action,
        boundaryId: CancelID.userAction
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

### LockmanSingleExecutionCancellationError

This error conforms to `LockmanCancellationError` protocol and provides:
- `cancelledInfo`: Information about the cancelled action
- `boundaryId`: Where the cancellation occurred
- `reason`: Specific reason for cancellation

**CancellationReason cases:**
- **boundaryAlreadyLocked** - Boundary is already locked
  - `existingInfo`: Existing lock information
- **actionAlreadyRunning** - Same action is already running
  - `existingInfo`: Running action information

```swift
lockFailure: { error, send in
    if let singleError = error as? LockmanSingleExecutionCancellationError {
        switch singleError.reason {
        case .boundaryAlreadyLocked(let existingInfo):
            send(.showBusyMessage("Another process is running: \(existingInfo.actionId)"))
        case .actionAlreadyRunning(let existingInfo):
            send(.showBusyMessage("\(existingInfo.actionId) is running"))
        }
    } else {
        send(.showBusyMessage("Cannot start processing"))
    }
}
```

