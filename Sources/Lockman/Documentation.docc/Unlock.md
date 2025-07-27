# Unlock

Understanding the unlocking mechanism in Lockman.

## Overview

Unlocking in Lockman is a mechanism for properly releasing acquired locks. It ensures resource release and maintains system consistency in all situations, including after processing completion, error occurrence, or cancellation.

## Specifications

### Automatic Release

When using [Reducer.lock](<doc:Lock>) or [Effect.lock](<doc:Lock>), locks are automatically released at the following timings:

- **On normal completion**: When processing completes normally
- **On exception**: When an error occurs
- **On cancellation**: When processing is cancelled
- **On early return**: When processing ends prematurely

Automatic release is implemented using defer blocks, ensuring that locks are reliably released regardless of the termination pattern.

### Manual Release

Manual release functionality has been removed in Lockman v1.3.0. All locks are now automatically managed when using [Reducer.lock](<doc:Lock>) or [Effect.lock](<doc:Lock>).

For cases where you need fine-grained control over lock timing, use the `unlockOption` parameter to control when the automatic unlock occurs.

### Release Options

Unlock execution timing can be controlled with LockmanUnlockOption:

- **immediate**: Release immediately upon processing completion
- **mainRunLoop**: Release in the next main run loop cycle
- **transition**: Release after platform-specific screen transition animation completion
  - iOS: 0.35 seconds (push/pop animation)
  - macOS: 0.25 seconds (window and view animation)
  - tvOS: 0.4 seconds (focus-driven transition)
  - watchOS: 0.3 seconds (page-based navigation)
- **delayed(TimeInterval)**: Release after specified time

## Methods

### Auto-release with Reducer.lock (Recommended)

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .startWork:
            return .run { send in
                try await someAsyncWork()
                await send(.completed)
                // Lock is automatically released here
            }
            .catch { error, send in
                await send(.failed(error))
                // Automatically released after error handling
            }
        }
    }
    .lock(
        boundaryId: CancelID.feature,
        unlockOption: .immediate  // Configure unlock timing
    )
}
```

### Auto-release with Effect.lock

```swift
return .run { send in
    try await someAsyncWork()
    await send(.completed)
    // Lock is automatically released here
}
.catch { error, send in
    await send(.failed(error))
    // Automatically released after error handling
}
.lock(
    action: action,
    boundaryId: CancelID.feature,
    unlockOption: .transition  // Configure unlock timing
)
```


