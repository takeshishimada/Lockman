# Migrating to 1.3

Update your code from Lockman 1.2 to take advantage of Lockman 1.3's simplified API and enhanced safety features.

## Overview

Lockman 1.3 introduces a major API simplification by removing the `withLock` methods in favor of the more consistent `Effect.lock` method chain approach. This change eliminates API duplication and provides a cleaner, more maintainable codebase.

The key improvements include:
- Removal of `withLock` methods for API consistency
- Enhanced safety through automatic lock management
- Simplified learning curve with fewer API options
- Better integration with TCA's Effect patterns

## Updating dependencies

To upgrade to Lockman 1.3, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.3.0"
  )
]
```

## Breaking changes

### Removal of withLock methods

All `withLock` methods have been removed. Use `Effect.lock` method chain or `Reducer.lock` instead.

🚫 Before (1.2):
```swift
return .withLock(
  operation: { send in
    try await performWork()
    await send(.completed)
  },
  catch handler: { error, send in
    await send(.failed(error))
  },
  lockFailure: { error, send in
    await send(.lockFailed)
  },
  action: action,
  boundaryId: CancelID.operation
)
```

✅ After (1.3):
```swift
return .run { send in
  try await performWork()
  await send(.completed)
} catch: { error, send in
  await send(.failed(error))
}
.lock(
  action: action,
  boundaryId: CancelID.operation,
  lockFailure: { error, send in
    await send(.lockFailed)
  }
)
```

### Removal of withLock(concatenating:)

The `withLock(concatenating:)` method has been renamed to `Effect.lock(concatenating:)`.

🚫 Before (1.2):
```swift
return .withLock(
  concatenating: [
    .run { send in await step1() },
    .run { send in await step2() },
    .run { send in await step3() }
  ],
  action: action,
  boundaryId: CancelID.workflow
)
```

✅ After (1.3):
```swift
return .lock(
  concatenating: [
    .run { send in await step1() },
    .run { send in await step2() },
    .run { send in await step3() }
  ],
  action: action,
  boundaryId: CancelID.workflow
)
```

### Manual unlock functionality removed

Manual unlock functionality (unlock parameter in operation) has been removed. All locks are now automatically managed.

🚫 Before (1.2):
```swift
return .withLock(
  operation: { send, unlock in
    defer { unlock() }
    try await performWork()
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
```

✅ After (1.3):
```swift
return .run { send in
  try await performWork()
  await send(.completed)
}
.lock(
  action: action,
  boundaryId: CancelID.operation,
  unlockOption: .immediate // Control timing instead
)
```

## Migration strategy

### Step 1: Replace withLock with Effect.lock

For each `withLock` call:

1. Move the operation closure to a `.run { }` effect
2. Move the catch handler to `.catch { }` if present
3. Chain `.lock()` with the action and boundary parameters
4. Move lockFailure to the lock method

### Step 2: Replace withLock(concatenating:) calls

1. Change method name from `.withLock(concatenating:` to `.lock(concatenating:`
2. Parameters remain the same

### Step 3: Remove manual unlock usage

1. Remove `unlock` parameter from operation closures
2. Remove manual `unlock()` calls
3. Use `unlockOption` parameter to control timing if needed

## Complete migration examples

### Basic operation migration

🚫 Before (1.2):
```swift
case .fetchData:
  return .withLock(
    operation: { send in
      let data = try await apiClient.fetchData()
      await send(.dataReceived(data))
    },
    catch handler: { error, send in
      await send(.fetchFailed(error))
    },
    lockFailure: { error, send in
      await send(.fetchBlocked)
    },
    action: action,
    boundaryId: CancelID.fetch
  )
```

✅ After (1.3):
```swift
case .fetchData:
  return .run { send in
    let data = try await apiClient.fetchData()
    await send(.dataReceived(data))
  } catch: { error, send in
    await send(.fetchFailed(error))
  }
  .lock(
    action: action,
    boundaryId: CancelID.fetch,
    lockFailure: { error, send in
      await send(.fetchBlocked)
    }
  )
```

### Concatenated operations migration

🚫 Before (1.2):
```swift
case .processWorkflow:
  return .withLock(
    concatenating: [
      .send(.workflowStarted),
      .run { send in await processStep1() },
      .run { send in await processStep2() },
      .send(.workflowCompleted)
    ],
    unlockOption: .transition,
    action: action,
    boundaryId: CancelID.workflow
  )
```

✅ After (1.3):
```swift
case .processWorkflow:
  return .lock(
    concatenating: [
      .send(.workflowStarted),
      .run { send in await processStep1() },
      .run { send in await processStep2() },
      .send(.workflowCompleted)
    ],
    unlockOption: .transition,
    action: action,
    boundaryId: CancelID.workflow
  )
```

### Complex manual unlock migration

🚫 Before (1.2):
```swift
case .complexOperation:
  return .withLock(
    operation: { send, unlock in
      try await phase1()
      
      if shouldSkipPhase2 {
        unlock()
        await send(.skipped)
        return
      }
      
      try await phase2()
      unlock()
      await send(.completed)
    },
    catch handler: { error, send, unlock in
      unlock()
      await send(.failed(error))
    },
    action: action,
    boundaryId: CancelID.complex
  )
```

✅ After (1.3):
```swift
case .complexOperation:
  return .run { send in
    try await phase1()
    
    if shouldSkipPhase2 {
      await send(.skipped)
      return
    }
    
    try await phase2()
    await send(.completed)
  } catch: { error, send in
    await send(.failed(error))
  }
  .lock(
    action: action,
    boundaryId: CancelID.complex,
    unlockOption: .immediate // Automatic timing control
  )
```

## Benefits of upgrading

1. **Simplified API**: Single consistent method chain approach
2. **Enhanced safety**: Automatic lock management prevents lock leaks
3. **Better TCA integration**: Natural fit with Effect patterns
4. **Reduced learning curve**: Fewer API variants to learn
5. **Improved maintainability**: Cleaner, more predictable code patterns

## API mapping reference

| Old API (1.2) | New API (1.3) |
|----------------|---------------|
| `.withLock(operation:...)` | `.run {...}.lock(...)` |
| `.withLock(concatenating:...)` | `.lock(concatenating:...)` |
| `operation: { send, unlock in }` | `.run { send in }` with `unlockOption` |
| Manual `unlock()` calls | Automatic with `unlockOption` control |

## Testing your migration

After migrating, verify that:

1. **Lock behavior is maintained**: Operations are still properly locked
2. **Error handling works**: Both operation errors and lock failures are handled
3. **Timing is correct**: Use `unlockOption` to adjust timing if needed
4. **Performance is maintained**: No regression in lock performance

## Summary

Lockman 1.3 represents a significant API simplification while maintaining all the functionality and safety guarantees of previous versions. The migration primarily involves moving from `withLock` to `Effect.lock` method chains, which provides a cleaner and more consistent API surface.

**Key takeaways:**
- **Breaking changes**: `withLock` methods removed
- **Consistent API**: Single method chain approach with `Effect.lock`
- **Enhanced safety**: Automatic lock management only
- **Better integration**: Natural fit with TCA Effect patterns

The new API eliminates confusion between different locking approaches and provides a more maintainable codebase going forward.