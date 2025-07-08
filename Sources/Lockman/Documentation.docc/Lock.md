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

Lockman provides several methods that can be used according to different purposes.

### Reducer.lock (Automatic Lock Management)

The recommended approach for most use cases. Applies automatic lock management to all effects produced by actions implementing `LockmanAction`.

```swift
@Reducer
struct Feature {
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .fetch:
        return .run { send in
          // This effect will be automatically locked
          let data = try await fetchData()
          await send(.fetchResponse(.success(data)))
        }
      case .fetchResponse:
        return .none
      }
    }
    .lock(
      boundaryId: CancelID.feature,
      unlockOption: .immediate, // Optional
      lockFailure: { error, send in // Optional
        await send(.lockFailed)
      }
    )
  }
}
```

**Parameters:**
- `boundaryId`: Boundary identifier for all locked actions
- `unlockOption`: Default lock release timing (optional)
- `lockFailure`: Handler for lock acquisition failures (optional)
- `for`: Case paths to check for nested LockmanAction conformance (optional, up to 5 paths)

**Features:**
- Automatic lock management for LockmanAction effects
- Non-LockmanAction effects pass through unchanged
- Centralized error handling
- Seamless integration with existing reducers
- Support for nested actions via CasePaths

**Nested Action Support:**

When using the ViewAction pattern in TCA, actions may be nested within enum cases. The `lock` method supports checking these nested actions:

```swift
// Root action only (no paths)
.lock(boundaryId: CancelID.feature)

// Check root and view actions
.lock(boundaryId: CancelID.feature, for: \.view)

// Check root, view, and delegate actions
.lock(boundaryId: CancelID.feature, for: \.view, \.delegate)

// Up to 5 paths supported
.lock(
  boundaryId: CancelID.feature,
  for: \.view, \.delegate, \.alert, \.sheet, \.popover
)
```

The method will check actions in the following order:
1. First, it checks if the root action conforms to `LockmanAction`
2. If not, it checks each provided path in order
3. The first action found that conforms to `LockmanAction` will be used for locking

### Effect.lock (Method Chain Style)

A method chain API that applies lock management to an existing effect.

```swift
return .run { send in
  // async operation
  let data = try await fetchData()
  await send(.fetchResponse(data))
}
.lock(
  action: action,
  boundaryId: Feature.self,
  unlockOption: .immediate, // Optional
  lockFailure: { error, send in // Optional
    await send(.lockFailed)
  }
)
```

**Parameters:**
- `action`: Current action implementing LockmanAction
- `boundaryId`: Effect cancellation identifier
- `unlockOption`: Lock release timing (optional)
- `handleCancellationErrors`: Handling of cancellation errors (optional)
- `lockFailure`: Handler for lock acquisition failure (optional)

**Features:**
- Method chain style for natural TCA integration
- Internally uses `withLock(concatenating:)`
- Same lock management guarantees as `withLock`

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
  boundaryId: cancelID
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
  boundaryId: cancelID
)
```

**Features:**
- Explicit lock release control
- Finer control possible
- **Important**: You must call unlock() in all code paths (see [Unlock](<doc:Unlock>) page for details)

### withLock(concatenating:)

Maintains the same lock while executing multiple Effects sequentially.

```swift
.withLock(
  concatenating: [
    .run { send in /* Processing 1 */ },
    .run { send in /* Processing 2 */ },
    .run { send in /* Processing 3 */ }
  ],
  unlockOption: .immediate, // Optional: Lock release timing
  lockFailure: { error, send in /* Lock acquisition failure handling */ }, // Optional
  action: action,
  boundaryId: cancelID
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
     boundaryId: cancelID
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

