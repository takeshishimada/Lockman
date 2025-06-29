# Error Handling

Learn about common error handling patterns in Lockman.

## Overview

Lockman provides detailed error information according to each strategy. This page explains error handling patterns common to all strategies and how to implement effective error handling.

## Common Error Handling Patterns

### lockFailure Handler

Basic lockFailure handler structure used in all strategies:

```swift
.withLock(
    operation: { send in
        // Execute processing
    },
    lockFailure: { error, send in
        // Error handling
        if case .specificError(let info) = error as? StrategySpecificError {
            state.errorMessage = "Error message"
        }
    },
    action: viewAction,
    cancelID: cancelID
)
```

**Parameters:**
- `error`: The error that occurred (strategy-specific error type)
- `send`: Function for sending feedback to the user

### catch handler Pattern

Handling general errors that occur during processing:

```swift
catch handler: { error, send in
    await send(.internal(.operationError(error.localizedDescription)))
}
```

This handler catches errors thrown within the operation and appropriately notifies the user.

## Types of Errors and Solutions

### 1. Lock Acquisition Failure (Already Locked)

**Concept**: Occurs when the same processing or boundary is already running

**Common solutions**:
```swift
lockFailure: { error, send in
    // Notify user that processing is in progress
    state.message = "Processing is in progress"
    
    // Or provide visual feedback in UI
    state.buttonState = .loading
}
```

### 2. Permission/Priority Conflicts

**Concept**: Occurs due to higher priority processing or group rule constraints

**Common solutions**:
```swift
lockFailure: { error, send in
    // Understand the situation from errors containing detailed information
    if let conflictInfo = extractConflictInfo(from: error) {
        state.message = "Another important process is running: \(conflictInfo.description)"
    }
}
```

### 3. Cancellation Notification

**Concept**: When existing processing is cancelled by higher priority processing

**Common solutions**:
```swift
catch handler: { error, send in
    if error is CancellationError {
        await send(.internal(.processCancelled("Interrupted by a more important process")))
    } else {
        await send(.internal(.processError(error.localizedDescription)))
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
state.message = "Saving data. Please wait a moment."

// ❌ Bad example: Technical error message
state.message = "LockmanError: boundary locked"
```

### 3. Utilizing Additional Information

Many errors contain additional information:

```swift
lockFailure: { error, send in
    switch error as? LockmanConcurrencyLimitedError {
    case .concurrencyLimitReached(let current, let limit, _):
        state.message = "Concurrent execution limit (\(limit)) reached (current: \(current))"
    default:
        state.message = "Cannot start processing"
    }
}
```

## Strategy-Specific Errors

For detailed error information for each strategy, please refer to their respective documentation:

- [SingleExecutionStrategy](<doc:SingleExecutionStrategy>) - Duplicate execution errors
- [PriorityBasedStrategy](<doc:PriorityBasedStrategy>) - Priority conflict errors
- [GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>) - Group rule violation errors
- [ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>) - Concurrent execution limit exceeded errors
- [DynamicConditionStrategy](<doc:DynamicConditionStrategy>) - Condition mismatch errors
- [CompositeStrategy](<doc:CompositeStrategy>) - Composite strategy errors

