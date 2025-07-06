# Configuration

Configure Lockman for your application's needs.

## Overview

LockmanManager provides configuration functionality to set Lockman's behavior throughout the application. These settings allow you to customize default lock release timing and error handling behavior.

Once configured, settings apply application-wide and can be overridden at various levels: in individual [`withLock`](<doc:Lock>) calls, [`Effect.lock`](<doc:Lock>) method chains, or when configuring [`Reducer.lock`](<doc:Lock>).

## Configuration Options

### defaultUnlockOption

Sets the default timing for lock release.

```swift
// Configure during application initialization
LockmanManager.config.defaultUnlockOption = .immediate
```

**Available values**:
- **`.immediate`**: Release immediately upon completion (default)
- **`.mainRunLoop`**: Release on the next main loop cycle
- **`.transition`**: Release after platform-specific screen transition animation
- **`.delayed(TimeInterval)`**: Release after the specified time interval

**Priority order**:
1. Explicitly specified in method call (`withLock`, `Effect.lock`, or `Reducer.lock`) (highest priority)
2. Action's `unlockOption` property (if implementing `LockmanAction`)
3. `LockmanManager.config.defaultUnlockOption` (lowest priority)

**Use cases**:
- Unified release timing considering UI transitions
- Consistent behavior settings across the application
- Adjustments for performance optimization

### handleCancellationErrors

Sets how to handle cancellation errors.

```swift
// Ignore cancellation errors (default)
LockmanManager.config.handleCancellationErrors = false

// Pass cancellation errors to error handler
LockmanManager.config.handleCancellationErrors = true
```

**Values**:
- **`false`**: Ignore cancellation errors and don't pass to error handler (default)
- **`true`**: Pass cancellation errors to error handler

**Use cases**:
- Logging cancellation processing
- Tracking cancellation situations during debugging
- Collecting statistical information

## Configuration Examples

### Configuration during Application Initialization

```swift
// Configure in AppDelegate or App struct
func applicationDidFinishLaunching() {
    // Set release timing considering UI transitions
    LockmanManager.config.defaultUnlockOption = .transition
    
    // Log cancellation errors during development
    #if DEBUG
    LockmanManager.config.handleCancellationErrors = true
    #endif
}
```

### Individual Override

```swift
// Override in Reducer.lock()
.lock(
    boundaryId: CancelID.feature,
    unlockOption: .immediate, // Override global setting
    lockFailure: { error, send in
        // Error handling
    }
)

// Override in Effect.lock()
.lock(
    action: action,
    boundaryId: CancelID.feature,
    unlockOption: .delayed(0.5) // Override for this effect
)

// Override in withLock
.withLock(
    unlockOption: .transition, // Override for fine control
    operation: { send in
        // Processing that requires transition timing
    },
    action: action,
    boundaryId: CancelID.feature
)
```

## Notes

- Since configuration changes affect the entire application, it's recommended to configure during initialization
- Runtime configuration changes are possible but should be done carefully to avoid unexpected behavior
- During testing, it's recommended to reset settings to avoid effects between tests

