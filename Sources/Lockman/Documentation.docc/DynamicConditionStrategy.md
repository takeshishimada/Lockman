# DynamicConditionStrategy

Control actions based on runtime conditions.

## Overview

DynamicConditionStrategy is a strategy that dynamically controls locks based on runtime state and conditions. Through condition evaluation with custom logic, it enables flexible exclusive control according to business rules.

This strategy is used in situations where complex business conditions that cannot be expressed with standard strategies or dynamic control based on application state is required.

## Condition Evaluation System

### Basic Condition Specification

```swift
LockmanDynamicConditionInfo(
    actionId: "payment",
    condition: {
        // Custom condition logic
        guard userIsAuthenticated else {
            return .failure(AuthenticationError.notLoggedIn)
        }
        guard accountBalance >= requiredAmount else {
            return .failure(PaymentError.insufficientFunds)
        }
        return .success
    }
)
```

### Advanced Control with Reducer.withLock

Using the method chain API enables more advanced condition evaluation based on current state and action:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .makePayment(let amount):
            // Create a temporary reducer with dynamic conditions
            let tempReducer = Reduce<State, Action> { _, _ in .none }
                .withLock { state, _ in
                    // Reducer-level condition
                    guard state.isAuthenticated else {
                        return .failure(AuthenticationError.notLoggedIn)
                    }
                    return .success
                }
            
            return tempReducer.withLock(
                state: state,
                action: action,
                operation: { send in
                    try await processPayment(amount)
                    await send(.paymentCompleted)
                },
                lockAction: PaymentAction(),
                boundaryId: CancelID.payment,
                lockCondition: { state, _ in
                    // Action-level condition
                    guard state.balance >= amount else {
                        return .failure(PaymentError.insufficientFunds(
                            required: amount,
                            available: state.balance
                        ))
                    }
                    return .success
                }
            )
        }
    }
}
```

## Usage

### Basic Usage Example

```swift
@LockmanDynamicCondition
enum ViewAction {
    case transfer(amount: Double)
    case withdraw(amount: Double)
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        switch self {
        case .transfer(let amount):
            return LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: {
                    // Business hours check
                    guard BusinessHours.isOpen else {
                        return .failure(BankError.outsideBusinessHours)
                    }
                    // Amount limit check
                    guard amount <= transferLimit else {
                        return .failure(BankError.transferLimitExceeded)
                    }
                    return .success
                }
            )
        case .withdraw(let amount):
            return LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: {
                    // ATM availability check
                    guard ATMService.isAvailable else {
                        return .failure(BankError.atmUnavailable)
                    }
                    return .success
                }
            )
        }
    }
}
```

### Multi-Stage Condition Evaluation

The method chain API provides three stages of condition evaluation:

1. **Action-level conditions**: Conditions for specific operations
2. **Reducer-level conditions**: Overall prerequisite conditions
3. **Traditional lock strategies**: Standard exclusive control

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .criticalOperation:
            let tempReducer = Reduce<State, Action> { _, _ in .none }
                .withLock { state, _ in
                    // 2. Reducer-level condition
                    guard state.maintenanceMode == false else {
                        return .failure(SystemError.maintenanceMode)
                    }
                    return .success
                }
            
            return tempReducer.withLock(
                state: state,
                action: action,
                operation: { send in
                    try await performCriticalOperation()
                    await send(.operationCompleted)
                },
                lockAction: CriticalAction(), // 3. Traditional strategy (SingleExecution, etc.)
                boundaryId: CancelID.critical,
                lockCondition: { state, _ in
                    // 1. Action-level condition
                    guard state.systemStatus == .ready else {
                        return .failure(SystemError.notReady)
                    }
                    return .success
                }
            )
        }
    }
}
```

## Operation Examples

### Basic Condition Evaluation

```
Time: 9:00  - transfer($1000) request
  Condition 1: Business hours check → ✅ Open
  Condition 2: Amount limit check → ✅ Within limit
  Result: ✅ Execute

Time: 18:00 - transfer($1000) request  
  Condition 1: Business hours check → ❌ Outside hours
  Result: ❌ Reject (BankError.outsideBusinessHours)

Time: 10:00 - transfer($50000) request
  Condition 1: Business hours check → ✅ Open
  Condition 2: Amount limit check → ❌ Exceeds limit
  Result: ❌ Reject (BankError.transferLimitExceeded)
```

### Multi-Stage Evaluation Operation

```
criticalOperation request:

Step 1: Reducer-level condition
  maintenanceMode == false → ✅ Pass

Step 2: Action-level condition  
  systemStatus == .ready → ✅ Pass

Step 3: Traditional strategy (e.g., SingleExecution)
  Duplicate execution check → ✅ Pass

Result: ✅ All stages passed, start execution
```

## Error Handling

For errors that may occur with DynamicConditionStrategy and their solutions, please also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### Utilizing Custom Errors

```swift
enum BusinessError: Error {
    case insufficientFunds(required: Double, available: Double)
    case dailyLimitExceeded(limit: Double)
    case accountSuspended(reason: String)
    case outsideBusinessHours
}

lockFailure: { error, send in
    switch error as? BusinessError {
    case .insufficientFunds(let required, let available):
        send(.showError("Insufficient funds: Required ¥\(required), Available ¥\(available)"))
        
    case .dailyLimitExceeded(let limit):
        send(.showError("Daily limit of ¥\(limit) exceeded"))
        
    case .accountSuspended(let reason):
        send(.showError("Account suspended: \(reason)"))
        
    case .outsideBusinessHours:
        send(.showError("Outside business hours (Weekdays 9:00-17:00)"))
        
    default:
        send(.showError("Cannot perform operation"))
    }
}
```

