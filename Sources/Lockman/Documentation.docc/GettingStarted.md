# Getting Started

Learn how to integrate Lockman into your TCA application.

## Prerequisites

Before using Lockman, you should be familiar with:
- **The Composable Architecture (TCA)** fundamentals
- Basic Swift concurrency (`async/await`)
- TCA's Effect system

If you're new to TCA, start with the [official TCA tutorial](https://pointfreeco.github.io/swift-composable-architecture/main/tutorials/composablearchitecture/) first.

## 30-Second Solution

**Problem**: Your save button can be tapped multiple times, causing duplicate network requests.

**Solution**: Add one line to prevent duplicate executions:

```swift
@LockmanSingleExecution
enum ViewAction {
    case saveButtonTapped
    var lockmanInfo: LockmanSingleExecutionInfo { 
        .init(actionId: actionName, mode: .boundary) 
    }
}

// Add this one line to your reducer:
.lock(boundaryId: CancelID.userAction, for: \.view)
```

**Result**: The save button becomes "smart" - it won't execute again until the current save completes.

## Overview

This guide will teach you how to integrate Lockman into your The Composable Architecture (TCA) project step by step, starting with the simplest case and building up to more complex scenarios.

## Adding Lockman as a dependency

To use Lockman in a Swift Package Manager project, add it to the dependencies in your `Package.swift` file:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "x.x.x")
]
```

And add `Lockman` as a dependency of your package's target:

```swift
.target(
  name: "YourTarget",
  dependencies: [
    "Lockman",
    .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
  ]
)
```

## Step-by-Step Tutorial

Let's build a simple save feature that prevents duplicate executions. We'll start minimal and add complexity gradually.

### Step 1: Basic Setup

Create a minimal TCA feature with a save action:

```swift
import ComposableArchitecture
import Lockman

@Reducer
struct SaveFeature {
    @ObservableState
    struct State: Equatable {
        var isSaving = false
        var message = ""
    }
    
    enum Action {
        case saveButtonTapped
        case saveStarted
        case saveCompleted
    }
}
```

**What we have**: A basic save feature with three simple actions.

### Step 2: Add Basic Logic

Implement the basic save functionality:

```swift
@Reducer
struct SaveFeature {
    // ... State from Step 1 ...
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .saveButtonTapped:
                state.isSaving = true
                state.message = "Saving..."
                return .run { send in
                    // Simulate save operation
                    try await Task.sleep(for: .seconds(2))
                    await send(.saveCompleted)
                }
                
            case .saveStarted:
                state.isSaving = true
                state.message = "Starting save..."
                return .none
                
            case .saveCompleted:
                state.isSaving = false
                state.message = "Saved successfully!"
                return .none
            }
        }
    }
}
```

**Problem**: If users tap the save button multiple times, multiple save operations will run simultaneously.

### Step 3: Add Lockman Protection

Now let's prevent duplicate saves by adding Lockman protection:

```swift
@LockmanSingleExecution
enum Action {
    case saveButtonTapped
    case saveStarted  
    case saveCompleted
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .saveButtonTapped:
            return .init(actionId: actionName, mode: .boundary)
        case .saveStarted, .saveCompleted:
            return .init(actionId: actionName, mode: .none) // No protection needed
        }
    }
}
```

**What changed**: 
- Added `@LockmanSingleExecution` macro to the Action enum
- Implemented `lockmanInfo` property to configure protection per action

### Step 4: Enable Lock Management

Finally, add lock management to your reducer:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        // ... same switch statement from Step 2 ...
    }
    .lock(
        boundaryId: CancelID.save,
        lockFailure: { error, send in
            if error is LockmanSingleExecutionError {
                print("Save already in progress")
            }
        }
    )
}

enum CancelID {
    case save
}
```

**What changed**:
- Added `.lock()` modifier to the reducer
- Provided a `boundaryId` to identify this lock boundary
- Added error handling for when lock acquisition fails

**Result**: Now when users tap save multiple times, only the first tap executes. Additional taps are safely ignored until the save completes.

## Complete Example

Here's the complete, working example:

```swift
import ComposableArchitecture
import Lockman

@Reducer
struct SaveFeature {
    @ObservableState
    struct State: Equatable {
        var isSaving = false
        var message = ""
    }
    
    @LockmanSingleExecution
    enum Action {
        case saveButtonTapped
        case saveCompleted
        
        var lockmanInfo: LockmanSingleExecutionInfo {
            switch self {
            case .saveButtonTapped:
                return .init(actionId: actionName, mode: .boundary)
            case .saveCompleted:
                return .init(actionId: actionName, mode: .none)
            }
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .saveButtonTapped:
                state.isSaving = true
                state.message = "Saving..."
                return .run { send in
                    try await Task.sleep(for: .seconds(2))
                    await send(.saveCompleted)
                }
                
            case .saveCompleted:
                state.isSaving = false
                state.message = "Saved successfully!"
                return .none
            }
        }
        .lock(
            boundaryId: CancelID.save,
            lockFailure: { error, send in
                if error is LockmanSingleExecutionError {
                    print("Save already in progress")
                }
            }
        )
    }
    
    enum CancelID {
        case save
    }
}
```

## Next Steps

Congratulations! You've successfully implemented your first Lockman feature. Here's what to explore next:

### Learn Other Strategies
- **Priority-based control**: [`PriorityBasedStrategy`](<doc:PriorityBasedStrategy>) - Cancel existing operations for higher priority ones
- **Concurrency limits**: [`ConcurrencyLimitedStrategy`](<doc:ConcurrencyLimitedStrategy>) - Limit how many operations run simultaneously  
- **Group coordination**: [`GroupCoordinationStrategy`](<doc:GroupCoordinationStrategy>) - Coordinate related operations
- **Custom logic**: [`DynamicConditionStrategy`](<doc:DynamicConditionStrategy>) - Create your own rules

### Strategy Selection Guide
Not sure which strategy to use? Check out [Choosing Strategy](<doc:ChoosingStrategy>) for guidance on picking the right approach.

### Advanced Topics
- [Boundary Overview](<doc:BoundaryOverview>) - Understanding lock boundaries
- [Error Handling](<doc:ErrorHandling>) - Comprehensive error management
- [Configuration](<doc:Configuration>) - Global settings and customization

## Alternative API: Effect.lock()

If you prefer method chaining on individual effects, you can use `Effect.lock()`:

```swift
case .saveButtonTapped:
    return .run { send in
        try await Task.sleep(for: .seconds(2))
        await send(.saveCompleted)
    }
    .lock(
        action: action,
        boundaryId: CancelID.save,
        lockFailure: { error, send in
            if error is LockmanSingleExecutionError {
                print("Save already in progress")
            }
        }
    )
```

This approach gives you the same protection but applies to individual effects rather than the entire reducer.

