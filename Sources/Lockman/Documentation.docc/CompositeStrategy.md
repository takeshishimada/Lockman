# CompositeStrategy

Combine multiple strategies for complex control scenarios.

## Overview

CompositeStrategy is a strategy that combines multiple strategies to achieve more complex and advanced exclusive control. For complex requirements that cannot be addressed by a single strategy, you can build flexible and powerful control logic by combining 2 to 5 strategies.

This strategy is used in advanced use cases that require satisfying multiple control conditions simultaneously.

## Combination System

### Number of Strategy Combinations

Lockman supports combinations of 2 to 5 strategies:

### Combination Control Logic

**Success required in all strategies**:
- Success only when lock acquisition is possible in all component strategies
- If even one fails, the entire operation fails

**Coordination of preceding cancellation**:
- When any strategy requires preceding cancellation, execute preceding cancellation for all
- Use the first cancellation error found

**LIFO (Last In, First Out) release**:
- Lock release is executed in reverse order of acquisition
- Release from the last acquired lock in order

## Usage

### Basic Usage Example

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self
)
enum ViewAction {
    case criticalSave
    case normalSave
    
    var lockmanInfo: LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> {
        LockmanCompositeInfo2(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: switch self {
                    case .criticalSave: .high(.exclusive)
                    case .normalSave: .low(.replaceable)
                }
            )
        )
    }
}
```

### Combining 3 Strategies

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self,
    LockmanConcurrencyLimitedStrategy.self
)
enum Action {
    case downloadFile
    
    var lockmanInfo: LockmanCompositeInfo3<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanConcurrencyLimitedInfo> {
        LockmanCompositeInfo3(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action // Prevent duplication
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .low(.replaceable) // Priority control
            ),
            lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "downloads",
                limit: .limited(3) // Concurrent execution limit
            )
        )
    }
}
```

## Operation Examples

### Operation with 2 Strategy Combination

```
Strategy 1: SingleExecution(.action)
Strategy 2: PriorityBased(varies by action)

Time: 0s  - normalSave request (.low(.replaceable))
  Strategy 1: ✅ Success (no duplication)
  Strategy 2: ✅ Success (no priority issue)
  Result: ✅ Start execution

Time: 1s  - normalSave request (duplicate)
  Strategy 1: ❌ Fail (same action running)
  Strategy 2: No check (failed at strategy 1)
  Result: ❌ Overall failure

Time: 2s  - criticalSave request (.high(.exclusive))
  Strategy 1: ✅ Success (different action)
  Strategy 2: ✅ Success (with preceding cancellation)
  Result: ✅ Start execution (cancel normalSave)
```

### Operation with 3 Strategy Combination

```
Strategy 1: SingleExecution(.action)
Strategy 2: PriorityBased(.low(.replaceable))  
Strategy 3: ConcurrencyLimited(.limited(3))

Current situation: 3 download processes running

Time: 0s  - New downloadFile request
  Strategy 1: ✅ Success (no duplication)
  Strategy 2: ✅ Success (no priority issue)
  Strategy 3: ❌ Fail (concurrent execution limit reached)
  Result: ❌ Overall failure
```

## Error Handling

For errors that may occur with CompositeStrategy and their solutions, please also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### Error Handling in Composite Strategy

In composite strategies, errors from each component strategy are integrated and reported. Since the error from the first failed strategy is returned, check the error type and handle appropriately:

```swift
lockFailure: { error, send in
    switch error {
    case let singleError as LockmanSingleExecutionError:
        send(.singleExecutionConflict("Duplicate execution detected"))
        
    case let priorityError as LockmanPriorityBasedError:
        send(.priorityConflict("Priority conflict occurred"))
        
    case let concurrencyError as LockmanConcurrencyLimitedError:
        send(.concurrencyLimitReached("Concurrent execution limit reached"))
        
    default:
        send(.unknownLockFailure("Failed to acquire lock"))
    }
}
```

## Design Guidelines

### Strategy Selection Order

1. **Start with basic control**: Begin with SingleExecution
2. **Add if priority is needed**: Combine PriorityBased
3. **Add if resource control is needed**: Combine ConcurrencyLimited
4. **Add if coordination control is needed**: Combine GroupCoordination
5. **Add if custom logic is needed**: Combine DynamicCondition

