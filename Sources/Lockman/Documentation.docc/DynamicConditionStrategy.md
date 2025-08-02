# Dynamic Condition Evaluation

Control actions based on runtime conditions with unified condition evaluation.

## Overview

The LockmanDynamicConditionReducer provides unified condition evaluation for both reducer-level and action-level exclusive processing. This enables flexible control over when actions should be executed based on dynamic runtime conditions.

Unlike traditional strategies that use fixed rules, dynamic condition evaluation allows you to implement complex business logic that evaluates state and actions at runtime to determine whether exclusive processing should be applied.

## Two-Level Processing Architecture

### Reducer-Level Processing
Automatic condition evaluation that applies to all actions processed by the reducer. This level is ideal for global constraints like authentication checks or system status validation.

### Action-Level Processing  
Independent condition evaluation for specific actions using the `lock` method. This level is perfect for operation-specific constraints like balance checks or business hour validation.

## Basic Usage

### Simple Reducer-Level Condition

```swift
var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
    case .transfer(let amount):
      state.balance -= amount
      return .run { send in
        await send(.transferCompleted)
      }
    case .withdraw(let amount):
      state.balance -= amount
      return .run { send in
        await send(.withdrawCompleted)
      }
    default:
      return .none
    }
  }
  .lock(
    condition: { state, action in
      // Reducer-level condition: Check authentication for financial operations
      switch action {
      case .transfer, .withdraw:
        return state.isAuthenticated ? .success : .cancel(AuthError.notAuthenticated)
      default:
        return .success  // Allow other actions
      }
    },
    boundaryId: CancelID.authentication,
    lockFailure: { error, send in
      await send(.showError(error.localizedDescription))
    }
  )
}
```

### Action-Level Condition Evaluation

```swift
let reducer = LockmanDynamicConditionReducer<State, Action>(
  { state, action in
    // Base reducer implementation
    switch action {
    case .transfer(let amount):
      return .run { send in
        await processTransfer(amount)
        await send(.transferCompleted)
      }
    default:
      return .none
    }
  },
  condition: { _, _ in .success },  // Allow all actions at reducer level
  boundaryId: CancelID.operations
)

// Use action-level conditions for specific operations
func handleTransfer(amount: Double, state: State) -> Effect<Action> {
  return reducer.lock(
    state: state,
    action: .transfer(amount),
    operation: { send in
      await processTransfer(amount)
      await send(.transferCompleted)
    },
    lockFailure: { error, send in
      await send(.showError(error.localizedDescription))
    },
    boundaryId: CancelID.transfer,
    lockCondition: { state, _ in
      // Action-level condition: Check balance
      guard state.balance >= amount else {
        return .cancel(TransferError.insufficientFunds(
          required: amount,
          available: state.balance
        ))
      }
      return .success
    }
  )
}
```

## Independent Level Processing

Both levels operate independently, allowing you to combine global and specific constraints:

```swift
let reducer = LockmanDynamicConditionReducer<State, Action>(
  { state, action in
    switch action {
    case .performOperation:
      return .run { send in
        await send(.operationCompleted)
      }
    default:
      return .none
    }
  },
  condition: { state, action in
    // Reducer-level: Global authentication check
    switch action {
    case .performOperation:
      return state.isAuthenticated ? .success : .cancel(AuthError.notAuthenticated)
    default:
      return .success
    }
  },
  boundaryId: CancelID.auth,
  lockFailure: { error, send in
    await send(.showError("Auth failed: \(error.localizedDescription)"))
  }
)

// Action-level processing with different conditions
func handleSecureOperation(state: State) -> Effect<Action> {
  return reducer.lock(
    state: state,
    action: .performOperation,
    operation: { send in
      await performSecureOperation()
      await send(.operationCompleted)
    },
    lockFailure: { error, send in
      await send(.showError("Operation failed: \(error.localizedDescription)"))
    },
    boundaryId: CancelID.secureOp,
    lockCondition: { state, _ in
      // Action-level: Additional security checks
      guard state.securityLevel >= .high else {
        return .cancel(SecurityError.insufficientPermissions)
      }
      return .success
    }
  )
}
```

## Cancellable Effect Control

Both levels use cancellable effects to ensure proper resource management:

```swift
// Reducer-level cancellation
.lock(
  condition: { _, _ in .success },
  boundaryId: CancelID.operations  // Effects cancelled by this boundary
)

// Action-level cancellation  
reducer.lock(
  // ...
  boundaryId: CancelID.specificOperation  // Independent cancellation boundary
)
```

When multiple operations use the same boundary ID, newer operations will cancel previous ones automatically.

## Condition Evaluation Results

All conditions must return a `LockmanResult`:

```swift
// Allow exclusive processing
return .success

// Skip exclusive processing with error
return .cancel(MyError.conditionNotMet)

// Allow with preceding cancellation (advanced usage)
return .successWithPrecedingCancellation(cancellationError)
```

## Practical Examples

### Business Hours Control

```swift
.lock(
  condition: { state, action in
    switch action {
    case .makeTransaction:
      let currentHour = Calendar.current.component(.hour, from: Date())
      guard (9...17).contains(currentHour) else {
        return .cancel(BusinessError.outsideBusinessHours)
      }
      return .success
    default:
      return .success
    }
  },
  boundaryId: CancelID.businessHours
)
```

### Multi-Condition Validation

```swift
reducer.lock(
  state: state,
  action: action,
  operation: { send in
    await performComplexOperation()
    await send(.completed)
  },
  boundaryId: CancelID.complexOp,
  lockCondition: { state, action in
    // Multiple validation checks
    guard state.systemStatus == .ready else {
      return .cancel(SystemError.notReady)
    }
    
    guard state.userPermissions.contains(.execute) else {
      return .cancel(PermissionError.insufficientRights)
    }
    
    if case .processLargeData(let size) = action {
      guard size <= state.maxAllowedSize else {
        return .cancel(DataError.sizeExceeded)
      }
    }
    
    return .success
  }
)
```

## Error Handling

### Custom Error Types

```swift
enum BusinessError: Error, LocalizedError {
  case outsideBusinessHours
  case insufficientFunds(required: Double, available: Double)
  case dailyLimitExceeded(limit: Double)
  
  var errorDescription: String? {
    switch self {
    case .outsideBusinessHours:
      return "Operations only allowed during business hours (9:00-17:00)"
    case .insufficientFunds(let required, let available):
      return "Insufficient funds: Required $\(required), Available $\(available)"
    case .dailyLimitExceeded(let limit):
      return "Daily transaction limit of $\(limit) exceeded"
    }
  }
}
```

### Structured Error Handling

```swift
lockFailure: { error, send in
  switch error {
  case let businessError as BusinessError:
    switch businessError {
    case .outsideBusinessHours:
      await send(.showBusinessHoursMessage)
    case .insufficientFunds(let required, let available):
      await send(.showInsufficientFundsDialog(required: required, available: available))
    case .dailyLimitExceeded(let limit):
      await send(.showDailyLimitWarning(limit: limit))
    }
  default:
    await send(.showGenericError(error.localizedDescription))
  }
}
```

## Migration from Strategy-Based Approach

If you were previously using the strategy-based DynamicConditionStrategy:

### Before (Strategy-Based)
```swift
// Old approach - no longer available
@LockmanDynamicCondition
enum Action {
  // ...
}
```

### After (Unified Condition Evaluation)
```swift
// New approach - unified API
.lock(
  condition: { state, action in
    // Your condition logic here
    return .success
  },
  boundaryId: YourBoundaryId.dynamicConditions
)
```

The new approach provides the same flexibility with a cleaner, more predictable API that separates reducer-level and action-level concerns.