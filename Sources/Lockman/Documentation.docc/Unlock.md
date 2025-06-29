# Unlock

Understanding the unlocking mechanism in Lockman.

## Overview

Unlocking in Lockman is a mechanism for properly releasing acquired locks. It ensures resource release and maintains system consistency in all situations, including after processing completion, error occurrence, or cancellation.

## Specifications

### Automatic Release

In the auto-release version of [withLock](<doc:Lock>), locks are automatically released at the following timings:

- **On normal completion**: When processing completes normally
- **On exception**: When an error occurs
- **On cancellation**: When processing is cancelled
- **On early return**: When processing ends prematurely

Automatic release is implemented using defer blocks, ensuring that locks are reliably released regardless of the termination pattern.

### Manual Release

In the manual release version of [withLock](<doc:Lock>), developers explicitly call the unlock() function to release locks.

**Important constraints:**
- You must call unlock() in all code paths
- Forgetting to call unlock() causes permanent lock acquisition state
- Proper release is necessary even in conditional branches and error handling

**Unlock object characteristics:**
- Conforms to the Sendable protocol, allowing it to be passed when calling other actions
- Designed for use across multiple screens and actions
- Enables shared lock state and coordinated release between actions

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

### Auto-release Usage Example

```swift
.withLock(
  operation: { send in
    // Execute processing
    try await someAsyncWork()
    send(.completed)
    // Lock is automatically released here
  },
  catch handler: { error, send in
    // Automatically released after error handling
    send(.failed(error))
  },
  action: action,
  cancelID: cancelID
)
```

### Manual Release Usage Example

Basic usage example:

```swift
.withLock(
  operation: { send, unlock in
    try await firstOperation()
    
    if shouldEarlyReturn {
      unlock() // Early release
      return
    }
    
    try await secondOperation()
    unlock() // Required: Final release
  },
  catch handler: { error, send, unlock in
    // Error handling
    unlock() // Release on error too
    send(.failed(error))
  },
  action: action,
  cancelID: cancelID
)
```

Example of release in another screen's delegate:

```swift
.withLock(
  operation: { send, unlock in
    // Pass unlock object to another screen and transition
    send(.delegate(unlock: unlock))
  },
  action: action,
  cancelID: cancelID
)

// Receive and release on the delegate side
case .modal(.delegate(let unlock)):
  return .run { send in
    // Release after modal processing completion
    unlock()
  }
```

