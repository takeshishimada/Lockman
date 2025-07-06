# Lock

Understanding the locking mechanism in Lockman.

## Overview

Locking in Lockman is a strategy-based exclusive control system. Unlike traditional simple ON/OFF control, the selected strategy enables various types of control:

- **Execution Prevention**: Blocking duplicate execution ([SingleExecutionStrategy](<doc:SingleExecutionStrategy>))
- **Execution Priority**: Prioritizing new processing by interrupting existing processing ([PriorityBasedStrategy](<doc:PriorityBasedStrategy>))
- **Execution Coordination**: Coordinating related processing groups ([GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>))
- **Execution Limitation**: Limiting concurrent execution count ([ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>))
- **Conditional Execution Control**: Dynamic conditional control through custom logic ([DynamicConditionStrategy](<doc:DynamicConditionStrategy>))

## Specifications

Lockman determines the success or failure of lock acquisition based on the strategy and executes processing according to the result. The lock acquisition judgment process follows the rules of the specified strategy, and when multiple strategies are specified with [CompositeStrategy](<doc:CompositeStrategy>), lock acquisition succeeds only when all strategies allow it.

## Methods

Lockman provides three main methods that can be used according to different purposes.

### withLock (Auto-release Version)

The most basic and recommended usage. Automatically manages lock acquisition and release.

```swift
.withLock(
  priority: .userInitiated, // Optional: Task priority
  unlockOption: .immediate, // Optional: Lock release timing
  operation: { send in /* Processing */ },
  catch handler: { error, send in /* Error handling */ }, // Optional
  lockFailure: { error, send in /* Lock acquisition failure handling */ }, // Optional
  action: action,
  cancelID: cancelID
)
```

**Parameters:**
- `priority`: Task priority (optional)
- `unlockOption`: Lock release timing (optional, uses priority order: withLock parameter > action's unlockOption > config default)
- `handleCancellationErrors`: Handling of cancellation errors (optional, default is configured value)
- `operation`: Processing to execute under exclusive control
- `catch handler`: Error handler (optional)
- `lockFailure`: Handler for lock acquisition failure (optional)
- `action`: Current action
- `cancelID`: Effect cancellation identifier

**Features:**
- Automatic lock management
- Reliable lock release on normal completion, exception, or cancellation
- Error handling capability

### withLock (Manual Release Version)

Used when you want to manually control the lock release timing. Parameters are the same as the auto-release version, but an unlock parameter is added to `operation` and `catch handler`.

```swift
.withLock(
  operation: { send, unlock in 
    /* Processing */
    unlock() // Manual release
  },
  catch handler: { error, send, unlock in 
    unlock() // Release on error too
  },
  action: action,
  cancelID: cancelID
)
```

**Features:**
- Explicit lock release control
- Finer control possible
- **Important**: You must call unlock() in all code paths (see [Unlock](<doc:Unlock>) page for details)

### concatenateWithLock

Maintains the same lock while executing multiple Effects sequentially.

```swift
.concatenateWithLock(
  unlockOption: .immediate, // Optional: Lock release timing
  operations: [
    .run { send in /* Processing 1 */ },
    .run { send in /* Processing 2 */ },
    .run { send in /* Processing 3 */ }
  ],
  lockFailure: { error, send in /* Lock acquisition failure handling */ }, // Optional
  action: action,
  cancelID: cancelID
)
```

**Features:**
- Maintains the same lock across multiple Effects
- Suitable for transactional processing
- If any one fails, the entire process is interrupted

## UnlockOption Priority

When determining the unlock timing, Lockman follows this priority order:

1. **Explicitly specified in method call** (highest priority)
   ```swift
   .withLock(
     unlockOption: .transition, // This takes precedence
     operation: { send in /* ... */ },
     action: action,
     cancelID: cancelID
   )
   ```

2. **Action's unlockOption property**
   ```swift
   struct MyAction: LockmanAction {
     var unlockOption: LockmanUnlockOption { .mainRunLoop }
     // ...
   }
   ```

3. **Global configuration** (lowest priority)
   ```swift
   LockmanManager.config.defaultUnlockOption = .immediate
   ```

This allows flexible control from global defaults to action-specific and call-specific overrides.

