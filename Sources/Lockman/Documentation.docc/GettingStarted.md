# Getting Started

Learn how to integrate Lockman into your TCA application.

## Overview

This guide will teach you how to integrate Lockman into your The Composable Architecture (TCA) project and implement your first feature.

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

## Writing your first feature

Let's implement a feature that prevents duplicate execution of processes using the [`@LockmanSingleExecution`](<doc:SingleExecutionStrategy>) macro.

### Step 1: Define the Reducer

First, define the basic Reducer structure:

```swift
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
}
```

### Step 2: Define State and Action

Define the State to manage the processing status and the available actions:

```swift
@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
    enum Action: ViewAction {
        case view(View)
        case internal(Internal)
        
        @LockmanSingleExecution
        enum View {
            case startProcessButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                return .init(actionId: actionName, mode: .boundary)
            }
        }
        
        enum Internal {
            case processStart
            case processCompleted
        }
    }
}
```

Key points:

- This example uses TCA's ViewAction pattern, where view-related actions are nested under the `view` case
- Applying the [`@LockmanSingleExecution`](<doc:SingleExecutionStrategy>) macro to the nested View enum makes it conform to the `LockmanSingleExecutionAction` protocol
- The `lockmanInfo` property defines how each action is controlled for locking:
  - Control parameter configuration: Specifies strategy-specific behavior settings (priority, concurrency limits, group coordination rules, etc.)
  - Action identification: Provides the action identifier within the lock management system
  - Inter-strategy coordination: Defines parameters to pass to each strategy when using composite strategies

### Step 3: Define CancelID

Define a `CancelID` to use as the cancellation identifier for Effects:

```swift
extension ProcessFeature {
    enum CancelID {
        case userAction
    }
}
```

`CancelID` is used for Effect cancellation and lock boundary identification.

### Step 4: Implement the Reducer body

Implement processing with exclusive control using the [`Reducer.lock`](<doc:Lock>) modifier:

```swift
var body: some ReducerOf<Self> {
    Reduce { state, action in
        switch action {
        case .view(.startProcessButtonTapped):
            return .run { send in
                await send(.internal(.processStart))
                // Simulate heavy processing
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await send(.internal(.processCompleted))
            }
            
        case .internal(.processStart):
            state.isProcessing = true
            state.message = "Processing started..."
            return .none
            
        case .internal(.processCompleted):
            state.isProcessing = false
            state.message = "Processing completed"
            return .none
        }
    }
    .lock(
        boundaryId: CancelID.userAction,
        lockFailure: { error, send in
            // When processing is already in progress
            if let singleError = error as? LockmanSingleExecutionError {
                // Handle the lock failure appropriately
                print("Lock failed: \(singleError.localizedDescription)")
            }
        },
        for: \.view
    )
}
```

Key points about the [`Reducer.lock`](<doc:Lock>) modifier:

- Automatically applies lock management to all actions that implement `LockmanAction`
- `boundaryId`: Specifies the identifier for Effect cancellation and lock boundary
- `lockFailure`: Common handler for lock acquisition failures across all actions
- `for`: Case paths to check for nested LockmanAction conformance (in this example, `\.view` checks actions nested in the view case)
- Effects from non-LockmanAction actions pass through unchanged

With this implementation, the `startProcessButtonTapped` action will not be executed again while processing, making it safe even if the user accidentally taps the button multiple times.

## Alternative APIs

### Using Effect.lock() Method Chain

For individual effects that need locking, you can use the method chain API:

```swift
case .view(.startProcessButtonTapped):
    return .run { send in
        await send(.internal(.processStart))
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await send(.internal(.processCompleted))
    }
    .lock(
        action: action,
        boundaryId: CancelID.userAction,
        lockFailure: { error, send in
            // Handler for lock acquisition failure
            if let singleError = error as? LockmanSingleExecutionError {
                print("Lock failed: \(singleError.localizedDescription)")
            }
        }
    )
```

### Using Effect.run with Lock

When you need traditional Effect.run behavior with lock management:

```swift
case .view(.startProcessButtonTapped):
    return .run { send in
        await send(.internal(.processStart))
        // Simulate heavy processing
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await send(.internal(.processCompleted))
    }
    .lock(
        action: action,
        boundaryId: CancelID.userAction,
        lockFailure: { error, send in
            // When processing is already in progress
            if let singleError = error as? LockmanSingleExecutionError {
                print("Lock failed: \(singleError.localizedDescription)")
            }
        }
    )
```

This approach provides:
- Simple async operation handling
- Lock failure handling
- Clean method chain syntax

