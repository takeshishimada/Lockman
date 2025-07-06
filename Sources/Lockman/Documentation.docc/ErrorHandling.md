# Error Handling

Learn about common error handling patterns in Lockman.

## Overview

Lockman provides detailed error information according to each strategy. This page explains error handling patterns common to all strategies and how to implement effective error handling.

## Common Error Handling Patterns

### lockFailure Handler with Reducer.lock()

Basic lockFailure handler structure used in all strategies:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        // Your reducer logic
    }
    .lock(
        boundaryId: CancelID.feature,
        lockFailure: { error, send in
            // Centralized error handling for all locked actions
            switch error {
            case let singleExecError as LockmanSingleExecutionError:
                await send(.showBusyMessage("Process already running"))
            case let priorityError as LockmanPriorityBasedError:
                await send(.showMessage("Higher priority task is running"))
            default:
                await send(.showMessage("Cannot start process"))
            }
        }
    )
}
```

**Benefits of centralized error handling:**
- Consistent error handling across all actions
- Single place to update error messages
- Easier to maintain and test

**Parameters:**
- `error`: The error that occurred (strategy-specific error type)
- `send`: Function for sending feedback to the user

### catch handler Pattern

Handling general errors that occur during processing:

```swift
// With Effect.lock() or individual effects
return .run { send in
    try await performOperation()
    await send(.operationCompleted)
}
.catch { error, send in
    await send(.operationError(error.localizedDescription))
}
.lock(action: action, boundaryId: CancelID.feature)
```

This handler catches errors thrown within the operation and appropriately notifies the user.

## Types of Errors and Solutions

### 1. Lock Acquisition Failure (Already Locked)

**Concept**: Occurs when the same processing or boundary is already running

**Common solutions**:
```swift
lockFailure: { error, send in
    // Notify user that processing is in progress
    send(.showMessage("Processing is in progress"))
    
    // Or provide visual feedback in UI
    send(.setButtonState(.loading))
}
```

### 2. Permission/Priority Conflicts

**Concept**: Occurs due to higher priority processing or group rule constraints

**Common solutions**:
```swift
lockFailure: { error, send in
    // Understand the situation from errors containing detailed information
    if let conflictInfo = extractConflictInfo(from: error) {
        send(.showMessage("Another important process is running: \(conflictInfo.description)"))
    }
}
```

### 3. Cancellation Notification

**Concept**: When existing processing is cancelled by higher priority processing

**Common solutions**:
```swift
catch handler: { error, send in
    if error is CancellationError {
        send(.processCancelled("Interrupted by a more important process"))
    } else {
        send(.processError(error.localizedDescription))
    }
}
```

## Best Practices

### 1. Proper Error Type Casting

```swift
// ✅ Good example: Cast to strategy-specific error type
if case .actionAlreadyRunning(let existingInfo) = error as? LockmanSingleExecutionError {
    // Use existingInfo to provide detailed information
}

// ❌ Bad example: Treat error as string
send(.showError(error.localizedDescription))
```

### 2. User-Friendly Messages

```swift
// ✅ Good example: Specific and easy to understand message
send(.showMessage("Saving data. Please wait a moment."))

// ❌ Bad example: Technical error message
send(.showMessage("LockmanError: boundary locked"))
```

### 3. Utilizing Additional Information

Many errors contain additional information:

```swift
// In Reducer.lock()
.lock(
    boundaryId: CancelID.feature,
    lockFailure: { error, send in
        switch error as? LockmanConcurrencyLimitedError {
        case .concurrencyLimitReached(let current, let limit, _):
            await send(.showMessage("Concurrent execution limit (\(limit)) reached (current: \(current))"))
        default:
            await send(.showMessage("Cannot start processing"))
        }
    }
)
```

## Strategy-Specific Errors

For detailed error information for each strategy, please refer to their respective documentation:

- [SingleExecutionStrategy](<doc:SingleExecutionStrategy>) - Duplicate execution errors
- [PriorityBasedStrategy](<doc:PriorityBasedStrategy>) - Priority conflict errors
- [GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>) - Group rule violation errors
- [ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>) - Concurrent execution limit exceeded errors
- [DynamicConditionStrategy](<doc:DynamicConditionStrategy>) - Condition mismatch errors
- [CompositeStrategy](<doc:CompositeStrategy>) - Composite strategy errors

