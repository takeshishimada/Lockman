# Getting Started

Learn how to integrate Lockman into your TCA application.

## Overview

This guide will teach you how to integrate Lockman into your The Composable Architecture (TCA) project and implement your first feature.

## Adding Lockman as a dependency

To use Lockman in a Swift Package Manager project, add it to the dependencies in your `Package.swift` file:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.13.0")
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

- Applying the [`@LockmanSingleExecution`](<doc:SingleExecutionStrategy>) macro to the Action enum makes it conform to the `LockmanSingleExecutionAction` protocol
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

Implement processing with exclusive control using the [`withLock`](<doc:Lock>) method:

```swift
var body: some Reducer<State, Action> {
    Reduce { state, action in
        switch action {
        case .startProcessButtonTapped:
            return .withLock(
                operation: { send in
                    await send(.processStart)
                    // Simulate heavy processing
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await send(.processCompleted)
                },
                lockFailure: { error, send in
                    // When processing is already in progress
                    state.message = "Processing is already in progress"
                },
                action: action,
                cancelID: CancelID.userAction
            )
            
        case .processStart:
            state.isProcessing = true
            state.message = "Processing started..."
            return .none
            
        case .processCompleted:
            state.isProcessing = false
            state.message = "Processing completed"
            return .none
        }
    }
}
```

Key points about the [`withLock`](<doc:Lock>) method:

- `operation`: Defines the processing to be executed under exclusive control
- `lockFailure`: Handler called when the same processing is already in progress
- `action`: Passes the currently processing action
- `cancelID`: Specifies the identifier for Effect cancellation and lock boundary

With this implementation, the `startProcessButtonTapped` action will not be executed again while processing, making it safe even if the user accidentally taps the button multiple times.

