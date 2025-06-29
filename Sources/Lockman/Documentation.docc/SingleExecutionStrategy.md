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

- Executes all processing concurrently without exclusive control
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
enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    
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
    
    enum InternalAction {
        case saveCompleted
        case saveError(String)
        case saveBusy(String)
    }
}
```

### Usage within Effects

```swift
case let .view(viewAction):
    switch viewAction {
    case .save:
        return .withLock(
            operation: { send in
                try await saveUserData()
                await send(.internal(.saveCompleted))
            },
            catch handler: { error, send in
                await send(.internal(.saveError(error.localizedDescription)))
            },
            lockFailure: { error, send in
                state.message = "Save process is currently running"
            },
            action: viewAction,
            cancelID: CancelID.userAction
        )
    case .load:
        // load action implementation
        return .none
    }
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

**boundaryAlreadyLocked** - Boundary is already locked
- `boundaryId`: ID of the locked boundary
- `existingInfo`: Existing lock information

**actionAlreadyRunning** - Same action is already running  
- `existingInfo`: Running action information

```swift
lockFailure: { error, send in
    switch error as? LockmanSingleExecutionError {
    case .boundaryAlreadyLocked(_, let existingInfo):
        state.busyMessage = "Another process is running: \(existingInfo.actionId)"
    case .actionAlreadyRunning(let existingInfo):
        state.busyMessage = "\(existingInfo.actionId) is running"
    default:
        state.busyMessage = "Cannot start processing"
    }
}
```

