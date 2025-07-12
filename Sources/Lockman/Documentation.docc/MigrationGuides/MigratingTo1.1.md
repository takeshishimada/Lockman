# Migrating to 1.1

Update your code from Lockman 1.0 to take advantage of Lockman 1.1's improved resource management and enhanced error handling.

## Overview

Lockman 1.1 introduces important improvements to prevent resource leaks and provide better type safety for cancellation handling. The main focus is on immediate unlock functionality that ensures locks are released as soon as actions are cancelled, preventing false lock conflicts.

The key changes include:
- New `LockmanPrecedingCancellationError` protocol for type-safe cancellation handling
- Enhanced `LockmanPriorityBasedError` with complete action information
- Immediate unlock mechanism to prevent resource leaks

## Updating dependencies

To upgrade to Lockman 1.1, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.1.0"
  )
]
```

## Breaking changes

### `LockmanResult.successWithPrecedingCancellation` type change

The `successWithPrecedingCancellation` case now requires errors conforming to `LockmanPrecedingCancellationError` protocol instead of generic `LockmanError`.

🚫 Before (1.0):
```swift
case successWithPrecedingCancellation(LockmanError)
```

✅ After (1.1):
```swift
case successWithPrecedingCancellation(any LockmanPrecedingCancellationError)
```

### `LockmanPriorityBasedError` enhanced with action information

All `LockmanPriorityBasedError` cases now include complete `lockmanInfo` and `boundaryId` parameters, providing better context about the cancelled action.

🚫 Before (1.0):
```swift
enum LockmanPriorityBasedError: LockmanError {
    case precedingActionCancelled(precedingActionName: String, precedingPriority: LockmanPriority)
    case higherPriorityExists(existingActionName: String, existingPriority: LockmanPriority)
    case samePriorityConflict(existingActionName: String)
}
```

✅ After (1.1):
```swift
enum LockmanPriorityBasedError: LockmanError {
    case precedingActionCancelled(
        precedingActionName: String,
        precedingPriority: LockmanPriority,
        lockmanInfo: any LockmanInfo,
        boundaryId: any LockmanBoundaryId
    )
    case higherPriorityExists(
        existingActionName: String,
        existingPriority: LockmanPriority,
        lockmanInfo: any LockmanInfo,
        boundaryId: any LockmanBoundaryId
    )
    case samePriorityConflict(
        existingActionName: String,
        lockmanInfo: any LockmanInfo,
        boundaryId: any LockmanBoundaryId
    )
}
```

## New features

### `LockmanPrecedingCancellationError` protocol

This new protocol provides a type-safe way to access information about cancelled actions:

```swift
public protocol LockmanPrecedingCancellationError: LockmanError {
    var lockmanInfo: any LockmanInfo { get }
    var boundaryId: any LockmanBoundaryId { get }
}
```

All strategy cancellation errors now conform to this protocol:
- `LockmanSingleExecutionCancellationError`
- `LockmanPriorityBasedCancellationError`
- `LockmanGroupCoordinationCancellationError`
- `LockmanDynamicConditionCancellationError`
- `LockmanConcurrencyLimitedCancellationError`
- `LockmanCompositeCancellationError`

### Immediate unlock functionality

Lockman 1.1 automatically releases locks immediately when actions are cancelled, preventing resource leaks and false lock conflicts. This happens transparently without any code changes required.

## Migration guide

### Handling cancellation errors

If you're explicitly handling `successWithPrecedingCancellation` cases, update your code to use the new protocol:

🚫 Before (1.0):
```swift
switch result {
case .successWithPrecedingCancellation(let error):
    // Generic error handling
    print("Action was cancelled: \(error)")
}
```

✅ After (1.1):
```swift
switch result {
case .successWithPrecedingCancellation(let cancellationError):
    // Type-safe access to cancellation information
    let cancelledAction = cancellationError.lockmanInfo.actionName
    let boundaryId = cancellationError.boundaryId
    print("Action '\(cancelledAction)' was cancelled at boundary '\(boundaryId)'")
}
```

### Updating priority-based error handling

If you're handling specific `LockmanPriorityBasedError` cases, update to use the new parameters:

🚫 Before (1.0):
```swift
catch let error as LockmanPriorityBasedError {
    switch error {
    case .precedingActionCancelled(let actionName, let priority):
        print("Cancelled \(actionName) with priority \(priority)")
    }
}
```

✅ After (1.1):
```swift
catch let error as LockmanPriorityBasedError {
    switch error {
    case .precedingActionCancelled(let actionName, let priority, let lockmanInfo, let boundaryId):
        print("Cancelled \(actionName) with priority \(priority)")
        print("Full action info: \(lockmanInfo.actionName)")
        print("Boundary: \(boundaryId)")
    }
}
```

## Benefits of upgrading

1. **Prevents resource leaks**: Immediate unlock ensures locks are released as soon as actions are cancelled
2. **Better debugging**: Enhanced error information provides complete context about cancelled actions
3. **Type safety**: The new protocol ensures compile-time safety when accessing cancellation information
4. **Improved performance**: Eliminates false lock conflicts caused by delayed unlock operations

## Complete example

Here's a complete example showing how to migrate error handling code:

🚫 Before (1.0):
```swift
.withLock(
    operation: { send in
        // Long-running operation
    },
    action: action,
    boundaryId: CancelID.operation,
    lockFailure: { error, send in
        if let cancellationError = error as? LockmanCancellationError,
           case .precedingActionCancelled = cancellationError.reason as? LockmanPriorityBasedError {
            await send(.showMessage("Previous action was cancelled"))
        }
    }
)
```

✅ After (1.1):
```swift
.withLock(
    operation: { send in
        // Long-running operation
    },
    action: action,
    boundaryId: CancelID.operation,
    lockFailure: { error, send in
        if let cancellationError = error as? LockmanCancellationError,
           case .precedingActionCancelled(_, _, let lockmanInfo, let boundaryId) = cancellationError.reason as? LockmanPriorityBasedError {
            await send(.showMessage("Cancelled '\(lockmanInfo.actionName)' at '\(boundaryId)'"))
        }
    }
)
```

## Summary

Lockman 1.1 is a minor version update that includes breaking changes to improve resource management and type safety. While these changes require some code updates, they provide significant benefits in preventing resource leaks and improving debugging capabilities.

The immediate unlock functionality works transparently, ensuring your application's locks are properly managed without any additional code changes.