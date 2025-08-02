# ``Lockman``

Elegant exclusive control for user actions in The Composable Architecture applications.

## What Problems Does Lockman Solve?

### Common App Issues
- **Double-tap problems**: Users accidentally trigger the same action twice
- **Race conditions**: Multiple network requests competing and overwriting each other  
- **Resource conflicts**: Heavy operations blocking the UI or consuming too much memory
- **Inconsistent state**: Actions completing out of order and corrupting app state

### The Lockman Solution
Lockman provides **strategy-based exclusive control** that lets you:
- Prevent duplicate operations with `SingleExecutionStrategy`
- Prioritize important actions with `PriorityBasedStrategy` 
- Limit resource usage with `ConcurrencyLimitedStrategy`
- Coordinate related operations with `GroupCoordinationStrategy`
- Create custom rules with `DynamicConditionStrategy`

## Quick Example

```swift
@LockmanSingleExecution
enum ViewAction {
    case saveButtonTapped
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
    }
}

// This prevents double-tapping the save button
.lock(boundaryId: CancelID.userAction, for: \.view)
```

## Overview

Lockman provides a comprehensive solution for managing exclusive control over user actions in applications built with The Composable Architecture (TCA). It offers various strategies to handle exclusive operations, prevent duplicate executions, and maintain consistent application state.

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:BoundaryOverview>
- <doc:Lock>
- <doc:Unlock>
- <doc:ChoosingStrategy>
- <doc:Configuration>
- <doc:ErrorHandling>
- <doc:DebuggingGuide>

### Strategies
- <doc:SingleExecutionStrategy>
- <doc:PriorityBasedStrategy>
- <doc:ConcurrencyLimitedStrategy>
- <doc:GroupCoordinationStrategy>
- <doc:DynamicConditionStrategy>
- <doc:CompositeStrategy>

## Design Philosophy

### Principles from Designing Fluid Interfaces

Lockman is inspired by WWDC18's "Designing Fluid Interfaces" principles for exceptional user experiences:

- **Immediate Response and Continuous Redirection** - Responsiveness that doesn't allow even 10ms of delay
- **One-to-One Touch and Content Movement** - Content follows the finger during drag operations
- **Continuous Feedback** - Immediate reaction to all interactions
- **Parallel Gesture Detection** - Recognizing multiple gestures simultaneously
- **Spatial Consistency** - Maintaining position consistency during animations
- **Lightweight Interactions, Amplified Output** - Large effects from small inputs

### Modern UI Challenges

Traditional UI development has solved concurrency problems by simply prohibiting simultaneous button presses and duplicate executions. These approaches have become factors that hinder user experience in modern fluid interface design.

Users expect some form of feedback even when pressing buttons simultaneously. Lockman enables you to provide immediate UI response while implementing appropriate exclusive control at the business logic layer.