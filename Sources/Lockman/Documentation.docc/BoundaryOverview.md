# Boundary

Understand the concept of boundaries in Lockman.

## Overview

A Boundary is the **exclusive control boundary** in Lockman. Lockman uses TCA's CancelID as this boundary to control action execution.

```swift
// Specify CancelID as boundary with withLock
return .withLock(
    operation: { send in
        // Processing
    },
    lockFailure: { error, send in
        // Processing when already running within the same boundary
    },
    action: action,
    boundaryId: CancelID.userAction  // This CancelID functions as a Boundary
)
```

Using CancelID as a boundary provides the following benefits:

1. **Natural integration with TCA** - Leverages existing TCA mechanisms
2. **Clear boundary definition** - CancelID clearly defines the scope of exclusive control

## Boundary Specifications

### 1. No exclusive control across boundaries

Exclusive control between different Boundaries is not possible:

```swift
// ❌ Not possible: Control save and load simultaneously
case .saveButtonTapped:
    // Control only within CancelID.save boundary
    return .withLock(..., boundaryId: CancelID.save)
    
case .loadButtonTapped:
    // Control only within CancelID.load boundary (independent from save)
    return .withLock(..., boundaryId: CancelID.load)
```

Since these are treated as separate boundaries, load can be executed even while save is running.

### 2. Only one Boundary per action

You cannot specify multiple Boundaries for a single action:

```swift
// ❌ Not possible: Specify multiple Boundaries simultaneously
return .withLock(
    operation: { send in /* ... */ },
    lockFailure: { error, send in /* ... */ },
    action: action,
    boundaryId: [CancelID.save, CancelID.validate]  // Multiple specification not allowed
)
```

If you want to control multiple processes simultaneously, you need to define a common Boundary:

```swift
// ✅ Correct approach: Use a common boundary
enum CancelID {
    case fileOperation  // Common boundary including save, load, validate
}

case .saveButtonTapped, .loadButtonTapped, .validateButtonTapped:
    return .withLock(..., boundaryId: CancelID.fileOperation)
```

## Summary

By setting appropriate boundaries, you can achieve both application stability and responsiveness.

