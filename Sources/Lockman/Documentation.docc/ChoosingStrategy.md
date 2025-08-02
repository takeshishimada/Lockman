# Choosing a Strategy

Learn how to select the right strategy for your use case.

## Overview

Lockman's strategy system has three main features: declarative strategy selection through annotations, combining multiple strategies, and implementing custom strategies.

## Strategy Selection

Developers can select appropriate strategies based on the nature of operations using annotations.

```swift
@LockmanSingleExecution
enum ViewAction {

@LockmanPriorityBased  
enum ViewAction {

@LockmanGroupCoordination
enum ViewAction {
```

## Combining Strategies

For complex requirements that cannot be addressed by a single strategy, you can achieve more advanced exclusive control by combining multiple strategies. Using the [`@LockmanCompositeStrategy`](<doc:CompositeStrategy>) annotation, you can combine up to 5 strategies.

```swift
@LockmanCompositeStrategy(
  LockmanSingleExecutionStrategy.self,
  LockmanPriorityBasedStrategy.self
)
enum ViewAction {
```

## Available Strategies

Lockman provides the following 5 standard strategies:

### [SingleExecutionStrategy](<doc:SingleExecutionStrategy>) - Preventing Duplicate Execution

- Prevents the same operation from being executed multiple times
- Applied to prevent users from tapping buttons repeatedly

### [PriorityBasedStrategy](<doc:PriorityBasedStrategy>) - Priority-Based Control

- High-priority operations can interrupt and execute over low-priority operations
- Applied to emergency operations or importance-based operation control

### [GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>) - Group Coordination Control

- Coordinates control of multiple related processes as a group
- Applied to operation management in leader-member relationships

### [ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>) - Limiting Concurrent Execution

- Allows concurrent execution up to a specified number, with excess being queued or rejected
- Applied to resource usage control and performance optimization

### [DynamicConditionStrategy](<doc:DynamicConditionStrategy>) - Dynamic Conditional Control

- Performs dynamic control based on runtime conditions
- Applied to custom control based on business logic

For detailed specifications and usage of each strategy, please refer to their respective dedicated pages.

