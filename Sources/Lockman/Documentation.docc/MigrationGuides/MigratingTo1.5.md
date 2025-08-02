# Migrating to 1.5

Update your code from Lockman 1.4 to take advantage of Lockman 1.5's unified dynamic condition evaluation API.

## Overview

Lockman 1.5 introduces a major architectural improvement with the unified `LockmanDynamicConditionReducer` API. This change simplifies dynamic condition evaluation by eliminating the complex strategy-based approach in favor of a clean, two-level processing system.

The key changes include:
- **Unified API**: Replace complex `LockmanDynamicConditionStrategy` with simplified `LockmanDynamicConditionReducer`
- **Two-level processing**: Independent reducer-level and action-level condition evaluation
- **Simplified architecture**: Direct condition evaluation + cancellable effect control
- **Removed macros**: No more `@LockmanDynamicCondition` macro needed

## Updating dependencies

To upgrade to Lockman 1.5, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.5.0"
  )
]
```

## Breaking changes

### `LockmanDynamicConditionStrategy` removed

The entire strategy-based approach has been removed and replaced with a unified reducer-based API.

🚫 **Removed in 1.5:**
```swift
// These are no longer available
LockmanDynamicConditionStrategy
LockmanDynamicConditionInfo
LockmanDynamicConditionAction
@LockmanDynamicCondition macro
```

✅ **New in 1.5:**
```swift
// Unified condition evaluation
LockmanDynamicConditionReducer
Reducer.lock(condition:boundaryId:lockFailure:)
reducer.lock(state:action:operation:boundaryId:lockCondition:)
```

### Macro-based action definition removed

The `@LockmanDynamicCondition` macro is no longer available.

🚫 **Before (1.4):**
```swift
@LockmanDynamicCondition
enum Action {
  case transfer(amount: Double)
  case withdraw(amount: Double)
  
  var lockmanInfo: LockmanDynamicConditionInfo {
    switch self {
    case .transfer(let amount):
      return LockmanDynamicConditionInfo(
        actionId: actionName,
        condition: { /* condition logic */ }
      )
    }
  }
}
```

✅ **After (1.5):**
```swift
// No macro needed - use regular enum
enum Action {
  case transfer(amount: Double)
  case withdraw(amount: Double)
}

// Apply conditions directly in reducer
.lock(
  condition: { state, action in
    switch action {
    case .transfer(let amount):
      // Your condition logic here
      return state.balance >= amount ? .success : .cancel(InsufficientFundsError())
    default:
      return .success
    }
  },
  boundaryId: CancelID.financial
)
```

## Migration guide

### Step 1: Remove macro usage

Remove `@LockmanDynamicCondition` and `lockmanInfo` implementations:

🚫 **Before:**
```swift
@LockmanDynamicCondition
enum ViewAction {
  case makePayment(amount: Double)
  
  var lockmanInfo: LockmanDynamicConditionInfo {
    switch self {
    case .makePayment(let amount):
      return LockmanDynamicConditionInfo(
        actionId: actionName,
        condition: {
          // Condition logic was isolated here
          return .success
        }
      )
    }
  }
}
```

✅ **After:**
```swift
// Simple enum - no macro needed
enum ViewAction {
  case makePayment(amount: Double)
}
```

### Step 2: Choose your condition evaluation level

#### Option A: Reducer-level conditions (Recommended for global constraints)

For conditions that apply to multiple actions or need to be checked automatically:

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    // Your reducer logic
    switch action {
    case .makePayment(let amount):
      state.balance -= amount
      return .run { send in
        await send(.paymentCompleted)
      }
    default:
      return .none
    }
  }
  .lock(
    condition: { state, action in
      // Automatic condition evaluation for all actions
      switch action {
      case .makePayment(let amount):
        guard state.isAuthenticated else {
          return .cancel(AuthError.notAuthenticated)
        }
        guard state.balance >= amount else {
          return .cancel(PaymentError.insufficientFunds)
        }
        return .success
      default:
        return .success
      }
    },
    boundaryId: CancelID.payment,
    lockFailure: { error, send in
      await send(.showError(error.localizedDescription))
    }
  )
}
```

#### Option B: Action-level conditions (For specific operations)

For conditions that apply to specific operations only:

```swift
let reducer = LockmanDynamicConditionReducer<State, Action>(
  { state, action in
    // Base reducer logic
    switch action {
    case .makePayment(let amount):
      return .run { send in
        await processPayment(amount)
        await send(.paymentCompleted)
      }
    default:
      return .none
    }
  },
  condition: { _, _ in .success },  // Allow all at reducer level
  boundaryId: CancelID.operations
)

// Use action-level lock for specific conditions
func handlePayment(amount: Double, state: State) -> Effect<Action> {
  return reducer.lock(
    state: state,
    action: .makePayment(amount),
    operation: { send in
      await processPayment(amount)
      await send(.paymentCompleted)
    },
    lockFailure: { error, send in
      await send(.showError(error.localizedDescription))
    },
    boundaryId: CancelID.payment,
    lockCondition: { state, _ in
      // Specific condition for this operation
      guard state.balance >= amount else {
        return .cancel(PaymentError.insufficientFunds)
      }
      return .success
    }
  )
}
```

### Step 3: Update strategy registration

Remove `LockmanDynamicConditionStrategy` registration:

🚫 **Before:**
```swift
try LockmanManager.container.register(LockmanDynamicConditionStrategy.shared)
```

✅ **After:**
```swift
// No registration needed - conditions are evaluated directly in reducers
```

### Step 4: Update error handling

Error handling is now done through the `lockFailure` parameter:

🚫 **Before:**
```swift
// Error handling was done in strategy
condition: {
  guard someCondition else {
    // Error handling was complex
    return .cancel(error)
  }
  return .success
}
```

✅ **After:**
```swift
.lock(
  condition: { state, action in
    guard someCondition else {
      return .cancel(MyError.conditionFailed)
    }
    return .success
  },
  boundaryId: CancelID.operations,
  lockFailure: { error, send in
    // Clean error handling
    await send(.showError(error.localizedDescription))
  }
)
```

## Complete migration example

Here's a complete before/after example:

### Before (1.4)
```swift
@Reducer
struct PaymentFeature {
  @ObservableState
  struct State {
    var balance: Double = 1000
    var isAuthenticated: Bool = true
  }
  
  @LockmanDynamicCondition
  enum Action {
    case makePayment(amount: Double)
    case paymentCompleted
    
    var lockmanInfo: LockmanDynamicConditionInfo {
      switch self {
      case .makePayment(let amount):
        return LockmanDynamicConditionInfo(
          actionId: actionName,
          condition: {
            // Isolated condition logic
            return .success
          }
        )
      default:
        return LockmanDynamicConditionInfo(actionId: actionName)
      }
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .makePayment(let amount):
        // Manual condition checking
        guard state.isAuthenticated else {
          return .none
        }
        guard state.balance >= amount else {
          return .none
        }
        
        state.balance -= amount
        return .run { send in
          await send(.paymentCompleted)
        }
      case .paymentCompleted:
        return .none
      }
    }
    .lock(boundaryId: CancelID.payment, for: \.self)
  }
}
```

### After (1.5)
```swift
@Reducer
struct PaymentFeature {
  @ObservableState
  struct State {
    var balance: Double = 1000
    var isAuthenticated: Bool = true
  }
  
  enum Action {
    case makePayment(amount: Double)
    case paymentCompleted
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .makePayment(let amount):
        state.balance -= amount
        return .run { send in
          await send(.paymentCompleted)
        }
      case .paymentCompleted:
        return .none
      }
    }
    .lock(
      condition: { state, action in
        switch action {
        case .makePayment(let amount):
          guard state.isAuthenticated else {
            return .cancel(AuthError.notAuthenticated)
          }
          guard state.balance >= amount else {
            return .cancel(PaymentError.insufficientFunds)
          }
          return .success
        default:
          return .success
        }
      },
      boundaryId: CancelID.payment,
      lockFailure: { error, send in
        await send(.showError(error.localizedDescription))
      }
    )
  }
}
```

## Benefits of upgrading

1. **Simplified architecture**: No more complex strategy registration and macro usage
2. **Better separation of concerns**: Clear distinction between reducer-level and action-level conditions
3. **Improved readability**: Condition logic is co-located with reducer logic
4. **Enhanced flexibility**: Mix reducer-level and action-level conditions as needed
5. **Better testability**: Easier to test condition logic directly in reducers
6. **Reduced boilerplate**: No macro setup or protocol conformance required

## Common migration patterns

### Pattern 1: Authentication + Operation-specific checks
```swift
// Reducer-level: Authentication
// Action-level: Operation-specific validation
.lock(
  condition: { state, action in
    switch action {
    case .makePayment, .withdraw, .transfer:
      return state.isAuthenticated ? .success : .cancel(AuthError.notAuthenticated)
    default:
      return .success
    }
  },
  boundaryId: CancelID.auth
)

// Then use action-level locks for specific checks
reducer.lock(
  // ... operation-specific condition
  lockCondition: { state, action in
    // Specific validation
  }
)
```

### Pattern 2: Time-based + Amount-based validation
```swift
.lock(
  condition: { state, action in
    switch action {
    case .makeTransaction:
      // Time-based check
      let currentHour = Calendar.current.component(.hour, from: Date())
      guard (9...17).contains(currentHour) else {
        return .cancel(BusinessError.outsideBusinessHours)
      }
      
      // Amount-based check
      if case .makeTransaction(let amount) = action {
        guard amount <= state.dailyLimit else {
          return .cancel(BusinessError.dailyLimitExceeded)
        }
      }
      
      return .success
    default:
      return .success
    }
  },
  boundaryId: CancelID.businessRules
)
```

## Summary

Lockman 1.5 represents a major architectural improvement that simplifies dynamic condition evaluation while maintaining all the flexibility of the previous approach. The new unified API provides better separation of concerns, improved testability, and reduced boilerplate code.

The migration requires updating your condition logic from strategy-based to reducer-based, but the result is a cleaner, more maintainable codebase with the same powerful exclusive control capabilities.