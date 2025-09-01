<img src="Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftakeshishimada%2FLockman%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/takeshishimada/Lockman)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Ftakeshishimada%2FLockman%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/takeshishimada/Lockman)

Lockman is a Swift library that solves exclusive action control issues in The Composable Architecture (TCA) applications, with responsiveness, transparency, and declarative design in mind.

* [Design Philosophy](#design-philosophy)
* [Overview](#overview)
* [Basic Example](#basic-example)
* [Installation](#installation)
* [Community](#community)

## Design Philosophy

### Principles from Designing Fluid Interfaces

WWDC18's "Designing Fluid Interfaces" presented principles for exceptional interfaces:

* **Immediate Response and Continuous Redirection** - Responsiveness that doesn't allow even 10ms of delay
* **One-to-One Touch and Content Movement** - Content follows the finger during drag operations
* **Continuous Feedback** - Immediate reaction to all interactions
* **Parallel Gesture Detection** - Recognizing multiple gestures simultaneously
* **Spatial Consistency** - Maintaining position consistency during animations
* **Lightweight Interactions, Amplified Output** - Large effects from small inputs

### Traditional Challenges

Traditional UI development has solved problems by simply prohibiting simultaneous button presses and duplicate executions. These approaches have become factors that hinder user experience in modern fluid interface design.

Users expect some form of feedback even when pressing buttons simultaneously. It's crucial to clearly separate immediate response at the UI layer from appropriate mutual exclusion control at the business logic layer.

## Overview

Lockman provides the following control strategies to address common problems in app development:

* **Single Execution**: Prevents duplicate execution of the same action
* **Priority Based**: Action control and cancellation based on priority
* **Group Coordination**: Group control through leader/member roles
* **Dynamic Condition**: Runtime condition evaluation with unified reducer API
* **Concurrency Limited**: Limits the number of concurrent executions per group
* **Composite Strategy**: Combination of multiple strategies

## Examples

| Single Execution Strategy | Priority Based Strategy | Concurrency Limited Strategy |
|--------------------------|------------------------|------------------------------|
| ![Single Execution Strategy](Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Priority Based Strategy](Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Concurrency Limited Strategy](Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## Code Example

Here's how to implement a feature that prevents duplicate execution of processes using the `@LockmanSingleExecution` macro:

```swift
import CasePaths
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
    @CasePathable
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case startProcessButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(actionId: actionName, mode: .boundary)
            }
        }
        
        enum InternalAction {
            case processStart
            case processCompleted
            case updateMessage(String)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .startProcessButtonTapped:
                    return .run { send in
                        await send(.internal(.processStart))
                        // Simulate heavy processing
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.internal(.processCompleted))
                    }
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "Processing started..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "Processing completed"
                    return .none
                    
                case .updateMessage(let message):
                    state.message = message
                    return .none
                }
            }
        }
        .lock(
            boundaryId: CancelID.userAction,
            lockFailure: { error, send in
                // When processing is already in progress
                if error is LockmanSingleExecutionError {
                    // Update message through an action instead of direct state mutation
                    await send(.internal(.updateMessage("Processing is already in progress")))
                }
            },
            for: \.view
        )
    }
}
```

The `Reducer.lock` modifier automatically applies lock management to actions that conform to `LockmanAction`. Since the `ViewAction` enum is marked with `@LockmanSingleExecution`, the `startProcessButtonTapped` action won't execute while processing is in progress. The `for: \.view` parameter tells Lockman to check actions nested in the `view` case for `LockmanAction` conformance.

### Debug Output Example

```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7BFC785A-3D25-4722-B9BC-A3A63A7F49FC, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 1EBA9632-DE39-43B6-BE75-7C754476CD4E, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 6C5C569F-4534-40D7-98F6-B4F4B0EE1293, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: C6779CD1-F8FE-46EB-8605-109F7C8DCEA8, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: A54E7748-A3DE-451A-BF06-56224A5C94DA, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7D4D67A7-1A8C-4521-BB16-92E0D551451A, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 08CC1862-136F-4643-A796-F63156D8BF56, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: DED418D1-4A10-4EF8-A5BC-9E93D04188CA, mode: boundary), Reason: Boundary 'process' already has an active lock

📊 Current Lock State (SingleExecutionStrategy):
┌─────────────────┬──────────────────┬──────────────────────────────────────┬─────────────────┐
│ Strategy        │ BoundaryId       │ ActionId/UniqueId                    │ Additional Info │
├─────────────────┼──────────────────┼──────────────────────────────────────┼─────────────────┤
│ SingleExecution │ CancelID.process │ startProcessButtonTapped             │ mode: boundary  │
│                 │                  │ 08CC1862-136F-4643-A796-F63156D8BF56 │                 │
└─────────────────┴──────────────────┴──────────────────────────────────────┴─────────────────┘
```

## Documentation

The documentation for releases and `main` are available here:

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [1.5.0](https://takeshishimada.github.io/Lockman/1.5.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.5.0/documentation/lockman/migratingto1.5))
* [1.4.0](https://takeshishimada.github.io/Lockman/1.4.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.4.0/documentation/lockman/migratingto1.4))
* [1.3.0](https://takeshishimada.github.io/Lockman/1.3.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.3.0/documentation/lockman/migratingto1.3))
* [1.2.0](https://takeshishimada.github.io/Lockman/1.2.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.2.0/documentation/lockman/migratingto1.2))
* [1.1.0](https://takeshishimada.github.io/Lockman/1.1.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.1.0/documentation/lockman/migratingto1.1))

<details>
<summary>Other versions</summary>

* [1.0.0](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/) ([migration guide](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/migratingto1.0))
* [0.13.0](https://takeshishimada.github.io/Lockman/0.13.0/documentation/lockman/)
* [0.12.0](https://takeshishimada.github.io/Lockman/0.12.0/documentation/lockman/)
* [0.11.0](https://takeshishimada.github.io/Lockman/0.11.0/documentation/lockman/)
* [0.10.0](https://takeshishimada.github.io/Lockman/0.10.0/documentation/lockman/)
* [0.9.0](https://takeshishimada.github.io/Lockman/0.9.0/documentation/lockman/)
* [0.8.0](https://takeshishimada.github.io/Lockman/0.8.0/documentation/lockman/)
* [0.7.0](https://takeshishimada.github.io/Lockman/0.7.0/documentation/lockman/)
* [0.6.0](https://takeshishimada.github.io/Lockman/0.6.0/documentation/lockman/)
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)
* [0.4.0](https://takeshishimada.github.io/Lockman/0.4.0/documentation/lockman/)
* [0.3.0](https://takeshishimada.github.io/Lockman/0.3.0/documentation/lockman/)

</details>

There are a number of articles in the documentation that you may find helpful as you become more comfortable with the library:

### Essentials
* [Getting Started](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - Learn how to integrate Lockman into your TCA application
* [Boundary Overview](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Understand the concept of boundaries in Lockman
* [Lock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - Understanding the locking mechanism
* [Unlock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - Understanding the unlocking mechanism
* [Choosing a Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - Select the right strategy for your use case
* [Configuration](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - Configure Lockman for your application's needs
* [Error Handling](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - Learn about common error handling patterns
* [Debugging](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - Debug Lockman-related issues in your application

### Strategies
* [Single Execution Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - Prevent duplicate execution
* [Priority Based Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - Control based on priority
* [Concurrency Limited Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - Limit concurrent executions
* [Group Coordination Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - Coordinate related actions
* [Dynamic Condition Evaluation](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - Unified condition evaluation API
* [Composite Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - Combine multiple strategies

## Installation

Lockman can be installed using [Swift Package Manager](https://swift.org/package-manager/).

### Xcode

In Xcode, select File → Add Package Dependencies and enter the following URL:

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Add the dependency to your Package.swift file:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "1.7.3")
]
```

Add the dependency to your target:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### Requirements

| Platform | Minimum Version | CI Testing |
|----------|----------------|------------|
| iOS      | 13.0           | ✅         |
| macOS    | 10.15          | ✅         |
| tvOS     | 13.0           | Local only |
| watchOS  | 6.0            | Local only |
| Mac Catalyst | 13.0       | Local only |

**Note**: While Lockman supports all Apple platforms, CI testing is focused on iOS and macOS for faster feedback. Other platforms can be tested locally using the provided Makefile.

### Version Compatibility

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.7.3   | 1.22.1                     |
| 1.7.2   | 1.22.1                     |
| 1.7.1   | 1.22.0                     |
| 1.7.0   | 1.22.0                     |
| 1.6.1   | 1.21.1                     |
| 1.6.0   | 1.21.0                     |
| 1.5.0   | 1.20.2                     |

<details>
<summary>Other versions</summary>

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.4.0   | 1.20.2                     |
| 1.3.2   | 1.20.2                     |
| 1.3.1   | 1.20.2                     |
| 1.3.0   | 1.20.2                     |
| 1.2.0   | 1.20.2                     |
| 1.1.0   | 1.20.2                     |
| 1.0.0   | 1.20.2                     |
| 0.13.4  | 1.20.2                     |
| 0.13.3  | 1.20.2                     |
| 0.13.2  | 1.20.2                     |
| 0.13.1  | 1.20.2                     |
| 0.13.0  | 1.20.2                     |
| 0.12.0  | 1.20.1                     |
| 0.11.0  | 1.19.1                     |
| 0.10.0  | 1.19.0                     |
| 0.9.0   | 1.18.0                     |
| 0.8.0   | 1.17.1                     |
| 0.7.0   | 1.17.1                     |
| 0.6.0   | 1.17.1                     |
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

</details>


## Community

### Discussion and Help

Questions and discussions can be held on [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Bug Reports

If you find a bug, please report it on [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contributing

If you'd like to contribute to the library, please open a PR with a link to it!

## License

This library is released under the MIT License. See the [LICENSE](./LICENSE) file for details.
