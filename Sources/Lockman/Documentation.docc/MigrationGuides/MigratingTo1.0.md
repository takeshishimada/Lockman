# Migrating to 1.0

Update your code from Lockman 0.13.4 to take advantage of Lockman 1.0's improved APIs and enhanced error handling.

## Overview

Lockman 1.0 brings significant improvements to API consistency, error handling, and overall developer experience. This guide will help you migrate your existing Lockman 0.13.4+ code to the new 1.0 APIs.

The most significant changes include:
- Renamed APIs for better Swift naming conventions
- Enhanced error handling with the new `LockmanCancellationError` protocol
- Unified parameter naming across all APIs
- Improved reducer integration with the new `Reducer.lock` method

## Updating dependencies

To upgrade to Lockman 1.0, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.0.0"
  )
]
```

## API renames and replacements

### `concatenateWithLock` → `withLock(concatenating:)`

The `concatenateWithLock` method has been renamed to `withLock(concatenating:)` to follow Swift's parameter labeling conventions and create a more consistent API surface.

🚫 Before:
```swift
return .concatenateWithLock(
  unlockOption: .immediate,
  operations: [
    .run { send in await fetchData() },
    .run { send in await processData() },
    .run { send in await saveData() }
  ],
  action: action,
  boundaryId: CancelID.operation
)
```

✅ After:
```swift
return .withLock(
  concatenating: [
    .run { send in await fetchData() },
    .run { send in await processData() },
    .run { send in await saveData() }
  ],
  unlockOption: .immediate,
  action: action,
  boundaryId: CancelID.operation
)
```

Note that the parameter order has changed: `concatenating` is now the first parameter with a label, making the API more readable.

### `Reducer.withLock` → `Reducer.lock`

The reducer modifier has been simplified from `withLock` to `lock` for better clarity and consistency.

🚫 Before:
```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // reducer logic
  }
  .withLock(
    boundaryId: CancelID.feature,
    for: \.view
  )
}
```

✅ After:
```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // reducer logic
  }
  .lock(
    boundaryId: CancelID.feature,
    for: \.view
  )
}
```

### Parameter rename: `id` → `boundaryId`

All APIs that previously used the parameter name `id` now use `boundaryId` for clarity.

🚫 Before:
```swift
.withLock(
  operation: { send in /* ... */ },
  action: action,
  id: CancelID.operation
)
```

✅ After:
```swift
.withLock(
  operation: { send in /* ... */ },
  action: action,
  boundaryId: CancelID.operation
)
```

This change affects all lock-related APIs including `withLock`, `Effect.lock`, and `Reducer.lock`.

## Error handling improvements

### New `LockmanCancellationError` wrapper

Lockman 1.0 introduces a new error handling model where all lock acquisition failures are wrapped in `LockmanCancellationError`. This provides better context about which action failed and why.

🚫 Before:
```swift
.lock(
  boundaryId: CancelID.operation,
  lockFailure: { error, send in
    if let singleExecutionError = error as? LockmanSingleExecutionError {
      // Handle single execution error
    } else if let priorityError = error as? LockmanPriorityBasedError {
      // Handle priority-based error
    }
  }
)
```

✅ After:
```swift
.lock(
  boundaryId: CancelID.operation,
  lockFailure: { error, send in
    guard let cancellationError = error as? LockmanCancellationError else { return }
    
    // Access the action that caused the error
    let failedAction = cancellationError.action
    
    // Access the underlying strategy error
    switch cancellationError.reason {
    case let singleExecutionError as LockmanSingleExecutionError:
      // Handle single execution error
    case let priorityError as LockmanPriorityBasedError:
      // Handle priority-based error
    default:
      break
    }
  }
)
```

### Error type renames

Several error types have been renamed for consistency:

- `LockmanSingleExecutionError` → `LockmanSingleExecutionCancellationError` (for cancellation cases)
- `LockmanPriorityBasedError` has specific cases:
  - `.precedingActionCancelled` → `LockmanPriorityBasedCancellationError`
  - `.higherPriorityExists` → `LockmanPriorityBasedBlockedError`
  - `.samePriorityConflict` → `LockmanPriorityBasedBlockedError`

### `LockmanResult` enum changes

The `LockmanResult` enum case has been renamed for clarity:

🚫 Before:
```swift
switch result {
case .success:
  // Handle success
case .successWithPrecedingCancellation:
  // Handle cancellation
case .failure:
  // Handle failure
}
```

✅ After:
```swift
switch result {
case .success:
  // Handle success
case .successWithPrecedingCancellation:
  // Handle cancellation
case .cancel:  // Renamed from .failure
  // Handle cancellation
}
```

## Complete migration example

Here's a complete example showing how to migrate a typical Lockman integration:

🚫 Before (0.13.4):
```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var data: [Item] = []
    var isLoading = false
  }
  
  enum Action: ViewAction {
    case view(View)
    
    @CasePathable
    enum View: LockmanAction {
      case refreshTapped
      case loadMore
      
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: "\(self)",
          mode: .action
        )
      }
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.refreshTapped):
        return .concatenateWithLock(
          unlockOption: .immediate,
          operations: [
            .send(.setLoading(true)),
            .run { send in 
              let data = try await api.fetchData()
              await send(.dataLoaded(data))
            },
            .send(.setLoading(false))
          ],
          action: action,
          id: CancelID.refresh
        )
      }
    }
    .withLock(
      id: CancelID.feature,
      lockFailure: { error, send in
        if error is LockmanSingleExecutionError {
          await send(.showError("Already refreshing"))
        }
      },
      for: \.view
    )
  }
}
```

✅ After (1.0):
```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable {
    var data: [Item] = []
    var isLoading = false
  }
  
  enum Action: ViewAction {
    case view(View)
    
    @CasePathable
    enum View: LockmanAction {
      case refreshTapped
      case loadMore
      
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: "\(self)",
          mode: .action
        )
      }
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.refreshTapped):
        return .withLock(
          concatenating: [
            .send(.setLoading(true)),
            .run { send in 
              let data = try await api.fetchData()
              await send(.dataLoaded(data))
            },
            .send(.setLoading(false))
          ],
          unlockOption: .immediate,
          action: action,
          boundaryId: CancelID.refresh  // Renamed from 'id'
        )
      }
    }
    .lock(  // Renamed from 'withLock'
      boundaryId: CancelID.feature,  // Renamed from 'id'
      lockFailure: { error, send in
        guard let cancellationError = error as? LockmanCancellationError,
              cancellationError.reason is LockmanSingleExecutionCancellationError else {
          return
        }
        await send(.showError("Already refreshing"))
      },
      for: \.view
    )
  }
}
```

## Quick reference

| Old API | New API |
|---------|---------|
| `concatenateWithLock(operations:...)` | `withLock(concatenating:...)` |
| `Reducer.withLock` | `Reducer.lock` |
| `id:` parameter | `boundaryId:` parameter |
| Direct strategy errors | Wrapped in `LockmanCancellationError` |
| `LockmanResult.failure` | `LockmanResult.cancel` |

## Tips for migration

1. **Use Xcode's Find and Replace**: Many of these changes can be automated using Xcode's find and replace feature with regular expressions.

2. **Update error handling first**: Start by updating your error handling code to work with `LockmanCancellationError`, as this will help you identify all the places where lock failures are handled.

3. **Test incrementally**: After making each set of changes, run your tests to ensure everything still works as expected.

4. **Review lock failure handlers**: The new error wrapping provides more context, so consider whether you can improve your error handling logic.

## Need help?

If you encounter any issues during migration, please:
- Check the [API documentation](<doc:Lockman>) for detailed information about each API
- Review the [example projects](https://github.com/takeshishimada/Lockman/tree/main/Examples) for working code samples
- [Open an issue](https://github.com/takeshishimada/Lockman/issues) if you find any problems

## Conclusion

Lockman 1.0's changes improve API consistency and provide better error handling capabilities. While the migration requires some code changes, the improvements in developer experience and code clarity make it worthwhile. The new APIs follow Swift conventions more closely and provide better integration with The Composable Architecture.