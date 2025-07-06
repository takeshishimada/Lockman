# Boundary

Understand the concept of boundaries in Lockman.

## Overview

A Boundary is the **exclusive control boundary** in Lockman. Lockman uses TCA's CancelID as this boundary to control action execution.

```swift
// Specify CancelID as boundary with Reducer.lock
var body: some ReducerOf<Self> {
    Reduce { state, action in
        // Your reducer logic
    }
    .lock(
        boundaryId: CancelID.userAction,  // This CancelID functions as a Boundary
        lockFailure: { error, send in
            // Processing when already running within the same boundary
        }
    )
}
```

Using CancelID as a boundary provides the following benefits:

1. **Natural integration with TCA** - Leverages existing TCA mechanisms
2. **Clear boundary definition** - CancelID clearly defines the scope of exclusive control

## Boundary Specifications

### 1. No exclusive control across boundaries

Exclusive control between different Boundaries is not possible:

```swift
// ❌ Not possible: Control save and load simultaneously with different boundaries
@Reducer
struct FeatureA {
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Save logic
        }
        .lock(boundaryId: CancelID.save)  // Control only within save boundary
    }
}

@Reducer
struct FeatureB {
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            // Load logic
        }
        .lock(boundaryId: CancelID.load)  // Independent from save boundary
    }
}
```

Since these are treated as separate boundaries, load can be executed even while save is running.

### 2. Only one Boundary per reducer

You cannot specify multiple Boundaries for a single reducer:

```swift
// ❌ Not possible: Specify multiple Boundaries simultaneously
var body: some ReducerOf<Self> {
    Reduce { state, action in
        // Your logic
    }
    .lock(boundaryId: CancelID.save)
    .lock(boundaryId: CancelID.validate)  // This won't work as intended
}
```

If you want to control multiple processes simultaneously, you need to define a common Boundary:

```swift
// ✅ Correct approach: Use a common boundary
enum CancelID {
    case fileOperation  // Common boundary including save, load, validate
}

var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .saveButtonTapped, .loadButtonTapped, .validateButtonTapped:
            // All actions controlled within the same boundary
            return .run { send in
                // Your async operation
            }
        }
    }
    .lock(boundaryId: CancelID.fileOperation)
}
```

## Summary

By setting appropriate boundaries, you can achieve both application stability and responsiveness.

