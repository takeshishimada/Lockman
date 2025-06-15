<img src="Lockman.png" alt="Lockman Logo" width="400">

[![Test](https://github.com/takeshishimada/Lockman/workflows/Test/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ATest)
[![codecov](https://codecov.io/gh/takeshishimada/Lockman/graph/badge.svg?token=YOUR_TOKEN)](https://codecov.io/gh/takeshishimada/Lockman)
[![Swift 5.9](https://img.shields.io/badge/swift-5.9-ED523F.svg?style=flat)](https://swift.org/download/)
[![@takeshishimada](https://img.shields.io/badge/contact-@takeshishimada-1DA1F2.svg?style=flat&logo=twitter)](https://twitter.com/takeshishimada)

A Swift library for action mutual exclusion control in The Composable Architecture applications

* [Overview](#overview)
* [Basic Example](#basic-example)
* [Installation](#installation)
* [Community](#community)

## Overview

Lockman is a Swift library that solves concurrent action control issues in The Composable Architecture (TCA) applications. It addresses common problems in app development such as preventing duplicate API calls when users tap buttons repeatedly, task cancellation based on priority, and coordinated control within groups.

Lockman provides the following control strategies:

* **Single Execution**: Prevents duplicate execution of the same action
* **Priority Based**: Action control and cancellation based on priority
* **Group Coordination**: Group control through leader/member roles
* **Dynamic Condition**: Dynamic control based on runtime conditions
* **Composite Strategy**: Combination of multiple strategies

## Basic Example

Example of preventing duplicate API calls from repeated button taps:

```swift
import ComposableArchitecture
import LockmanComposable

@Reducer
struct UserFeature {
  @ObservableState
  struct State {
    var user: User?
  }
  
  @LockmanSingleExecution
  enum Action {
    case fetchUserTapped
    case userResponse(Result<User, Error>)
  }
  
  enum CancelID {
    case userFetch
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .fetchUserTapped:
        return .withLock(
          operation: { send in
            let user = try await userAPIClient.fetchUser()
            await send(.userResponse(.success(user)))
          },
          catch: { error, send in
            await send(.userResponse(.failure(error)))
          },
          action: action,
          cancelID: CancelID.userFetch
        )
        
      case let .userResponse(result):
        switch result {
        case let .success(user):
          state.user = user
        case .failure:
          break
        }
        return .none
      }
    }
  }
}
```

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
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.1.0")
]
```

Add the dependency to your target:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "LockmanComposable", package: "Lockman"),
  ]
)
```

### Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 13.0           |
| macOS    | 10.15          |
| tvOS     | 13.0           |
| watchOS  | 6.0            |

### Version Compatibility

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.1.0   | 1.7.1                      |

## Community

### Discussion and Help

Questions and discussions can be held on [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Bug Reports

If you find a bug, please report it on [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contributing

If you'd like to contribute to the library, please open a PR with a link to it!

## License

This library is released under the MIT License. See the [LICENSE](./LICENSE) file for details.