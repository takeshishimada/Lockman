<img src="Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

Lockman is a Swift library that solves concurrent action control issues in The Composable Architecture (TCA) applications through responsive, transparent, and declarative design.

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
* **Dynamic Condition**: Dynamic control based on runtime conditions
* **Composite Strategy**: Combination of multiple strategies

## Basic Example

Example of priority-based action control for profile photo selection:

```swift
import ComposableArchitecture
import LockmanComposable

@Reducer
struct ProfilePhotoFeature {
  @ObservableState
  struct State {
    var photos: [Photo] = []
    var selectedPhotoId: Photo.ID?
  }
  
  enum Action {
    case view(ViewAction)
    case `internal`(InternalAction)
    
    @LockmanPriorityBased
    enum ViewAction {
      case thumbnailTapped(Photo.ID)
      case updateProfilePhoto(Photo.ID)
      
      var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .thumbnailTapped:
          .init(actionId: actionName, priority: .low(.replaceable))
        case .updateProfilePhoto:
          .init(actionId: actionName, priority: .high(.exclusive))
        }
      }
    }
    
    enum InternalAction {
      case photoPreviewLoaded(Photo.ID, UIImage)
      case profilePhotoUpdated(Result<Photo, Error>)
    }
  }
  
  enum CancelID {
    case userAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case let .thumbnailTapped(photoId):
          // Low priority: Show selection immediately and load preview
          state.selectedPhotoId = photoId
          return .withLock(
            operation: { send in
              let image = try await photoClient.loadPreview(photoId)
              await send(.internal(.photoPreviewLoaded(photoId, image)))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
          
        case let .updateProfilePhoto(photoId):
          // High priority (exclusive): Block all other operations
          return .withLock(
            operation: { send in
              let updatedPhoto = try await profileAPI.updatePhoto(photoId)
              await send(.internal(.profilePhotoUpdated(.success(updatedPhoto))))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
        }
        
      case let .internal(internalAction):
        switch internalAction {
        case let .photoPreviewLoaded(photoId, image):
          // Update UI with preview
          return .none
          
        case let .profilePhotoUpdated(.success(photo)):
          // Update successful
          return .none
          
        case .profilePhotoUpdated(.failure):
          // Handle error
          return .none
        }
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