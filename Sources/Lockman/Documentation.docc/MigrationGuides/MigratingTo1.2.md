# Migrating to 1.2

Update your code from Lockman 1.1 to take advantage of Lockman 1.2's automatic cancellation ID management and enhanced safety features.

## Overview

Lockman 1.2 introduces a major developer experience improvement by automatically handling cancellation IDs for all Effect.lock operations. This eliminates the need to manually specify `.cancellable(id: boundaryId)` when using `.run()` methods with Lockman's lock functionality, resulting in cleaner, more maintainable code.

The key improvements include:
- Automatic cancellation ID management for all Effect.lock methods
- "Guaranteed Resource Cleanup" design principle implementation
- Enhanced safety with improved cancellation scope control
- Comprehensive documentation with before/after examples

## Updating dependencies

To upgrade to Lockman 1.2, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.2.0"
  )
]
```

## Non-breaking changes

**Important:** Lockman 1.2 is **100% backward compatible**. All existing code will continue to work without any modifications. However, you can now simplify your code significantly by removing manual cancellation ID specifications.

## Major improvements

### Automatic cancellation ID management

All Effect.lock methods now automatically apply `.cancellable(id: boundaryId)` to operations, eliminating the need for manual specification.

### Enhanced cancellation scope control

The "Guaranteed Resource Cleanup" principle ensures that:
- **Operations are cancellable**: Business logic can be cancelled using the boundaryId
- **Resource cleanup is guaranteed**: Lock release always executes regardless of cancellation
- **Deadlock prevention**: Fixed potential deadlock scenarios in concatenated operations

## Migration opportunities

While no changes are required, you can simplify your existing code to take advantage of the new automatic cancellation features.

### Method chain style (.lock)

🟡 Before (1.1 - still works):
```swift
return .run { send in
  await performAsyncWork()
  await send(.completed)
}
.cancellable(id: boundaryId)  // Manual specification
.lock(action: action, boundaryId: boundaryId)
```

✅ After (1.2 - simplified):
```swift
return .run { send in
  await performAsyncWork()
  await send(.completed)
}
.lock(action: action, boundaryId: boundaryId)  // Automatic application!
```

### Static method style (.withLock)

🟡 Before (1.1 - still works):
```swift
return .withLock(
  operation: { send in
    try await Task.sleep(nanoseconds: 100_000_000)
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
// Additional .cancellable(id:) was not needed here in 1.1
```

✅ After (1.2 - enhanced safety):
```swift
return .withLock(
  operation: { send in
    try await Task.sleep(nanoseconds: 100_000_000)
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
// Now with enhanced "Guaranteed Resource Cleanup" safety
```

### Concatenated operations

🟡 Before (1.1 - potential deadlock risk):
```swift
return .withLock(
  concatenating: [
    .run { send in await send(.stepOne) },
    .run { send in await send(.stepTwo) },
    .run { send in await send(.stepThree) }
  ],
  action: action,
  boundaryId: CancelID.operation
)
```

✅ After (1.2 - deadlock prevention):
```swift
return .withLock(
  concatenating: [
    .run { send in await send(.stepOne) },
    .run { send in await send(.stepTwo) },
    .run { send in await send(.stepThree) }
  ],
  action: action,
  boundaryId: CancelID.operation
)
// Enhanced with proper cancellation scope management
```

### Manual unlock operations

🟡 Before (1.1):
```swift
return .withLock(
  operation: { send, unlock in
    defer { unlock() }
    try await performCriticalWork()
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
```

✅ After (1.2 - with automatic cancellation):
```swift
return .withLock(
  operation: { send, unlock in
    defer { unlock() }
    try await performCriticalWork()
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
// Now includes automatic cancellation ID management
```

## Code cleanup recommendations

### Remove redundant .cancellable(id:) calls

You can now remove manual `.cancellable(id:)` specifications when using `.lock()`:

🟡 Before (can be simplified):
```swift
@Reducer
struct MyFeature {
  // ... state and action definitions ...
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .fetchData:
        return .run { send in
          let data = try await apiClient.fetchData()
          await send(.dataReceived(data))
        }
        .cancellable(id: CancelID.fetch)  // ← Remove this line
        .lock(action: action, boundaryId: CancelID.fetch)
        
      case .dataReceived(let data):
        state.data = data
        return .none
      }
    }
  }
}
```

✅ After (simplified):
```swift
@Reducer
struct MyFeature {
  // ... state and action definitions ...
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .fetchData:
        return .run { send in
          let data = try await apiClient.fetchData()
          await send(.dataReceived(data))
        }
        .lock(action: action, boundaryId: CancelID.fetch)  // Automatic cancellation!
        
      case .dataReceived(let data):
        state.data = data
        return .none
      }
    }
  }
}
```

### Simplify complex effect chains

🟡 Before (verbose):
```swift
return .merge(
  .run { send in
    await send(.started)
  },
  .run { send in
    try await performWork()
    await send(.workCompleted)
  }
  .cancellable(id: boundaryId)  // ← Remove this
  .lock(action: action, boundaryId: boundaryId),
  
  .run { send in
    await send(.monitoring)
  }
)
```

✅ After (clean):
```swift
return .merge(
  .run { send in
    await send(.started)
  },
  .run { send in
    try await performWork()
    await send(.workCompleted)
  }
  .lock(action: action, boundaryId: boundaryId),  // Clean and automatic!
  
  .run { send in
    await send(.monitoring)
  }
)
```

## Enhanced safety features

### Guaranteed resource cleanup

Lockman 1.2 implements the "Guaranteed Resource Cleanup" principle:

```swift
// This operation can be cancelled, but the unlock will ALWAYS execute
return .withLock(
  operation: { send in
    try await riskyOperation()  // ← Can be cancelled
    await send(.completed)
  },
  action: action,
  boundaryId: CancelID.operation
)
// unlock() is guaranteed to execute even if operation is cancelled
```

### Improved concatenated operations

Concatenated operations now have safer cancellation scope management:

```swift
return .withLock(
  concatenating: [
    .run { send in await step1(send) },    // ← These operations are cancellable
    .run { send in await step2(send) },    // ← as a group
    .run { send in await step3(send) }     // ← 
  ],
  action: action,
  boundaryId: CancelID.workflow
)
// The unlock effect is NOT cancellable - guaranteed cleanup
```

## Benefits of upgrading

1. **Cleaner code**: Remove boilerplate `.cancellable(id:)` calls
2. **Enhanced safety**: "Guaranteed Resource Cleanup" prevents resource leaks
3. **Deadlock prevention**: Improved cancellation scope management
4. **Better maintainability**: Less manual cancellation ID management
5. **Improved developer experience**: More intuitive API usage
6. **Zero performance impact**: Automatic features add no runtime overhead

## Testing your migration

After removing manual `.cancellable(id:)` calls, verify that:

1. **Cancellation still works**: Test that operations can be properly cancelled
2. **Resource cleanup**: Ensure locks are properly released
3. **No deadlocks**: Verify concatenated operations work correctly
4. **Error handling**: Check that error handlers still receive proper errors

## Complete migration example

Here's a complete example showing a typical migration:

🟡 Before (1.1):
```swift
@Reducer
struct PaymentFeature {
  struct State: Equatable {
    var isProcessing = false
    var result: PaymentResult?
  }
  
  @CasePathable
  enum Action: Equatable, LockmanAction {
    case processPayment(amount: Decimal)
    case paymentCompleted(PaymentResult)
    case paymentFailed
    
    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: "payment", mode: .boundary)
    }
  }
  
  enum CancelID: LockmanBoundaryId {
    case payment
  }
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .processPayment(let amount):
        state.isProcessing = true
        return .run { send in
          do {
            let result = try await paymentService.process(amount)
            await send(.paymentCompleted(result))
          } catch {
            await send(.paymentFailed)
          }
        }
        .cancellable(id: CancelID.payment)  // ← Manual specification
        .lock(action: action, boundaryId: CancelID.payment)
        
      case .paymentCompleted(let result):
        state.isProcessing = false
        state.result = result
        return .none
        
      case .paymentFailed:
        state.isProcessing = false
        return .none
      }
    }
  }
}
```

✅ After (1.2):
```swift
@Reducer
struct PaymentFeature {
  struct State: Equatable {
    var isProcessing = false
    var result: PaymentResult?
  }
  
  @CasePathable
  enum Action: Equatable, LockmanAction {
    case processPayment(amount: Decimal)
    case paymentCompleted(PaymentResult)
    case paymentFailed
    
    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: "payment", mode: .boundary)
    }
  }
  
  enum CancelID: LockmanBoundaryId {
    case payment
  }
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .processPayment(let amount):
        state.isProcessing = true
        return .run { send in
          do {
            let result = try await paymentService.process(amount)
            await send(.paymentCompleted(result))
          } catch {
            await send(.paymentFailed)
          }
        }
        .lock(action: action, boundaryId: CancelID.payment)  // ← Automatic cancellation!
        
      case .paymentCompleted(let result):
        state.isProcessing = false
        state.result = result
        return .none
        
      case .paymentFailed:
        state.isProcessing = false
        return .none
      }
    }
  }
}
```

## Summary

Lockman 1.2 represents a significant improvement in developer experience while maintaining complete backward compatibility. The automatic cancellation ID management eliminates boilerplate code and reduces the chance of errors, while the enhanced safety features provide better resource management.

**Key takeaways:**
- **No breaking changes**: All existing code continues to work
- **Simplification opportunity**: Remove manual `.cancellable(id:)` calls where appropriate  
- **Enhanced safety**: Benefit from "Guaranteed Resource Cleanup" principle
- **Better maintainability**: Cleaner, more intuitive code patterns

The automatic features work transparently, ensuring your application's operations are properly managed with improved safety guarantees.