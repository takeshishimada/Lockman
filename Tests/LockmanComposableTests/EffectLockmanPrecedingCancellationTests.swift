import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - Preceding Action Cancellation Error Tests

final class EffectWithLockPrecedingCancellationTests: XCTestCase {
  @Sendable func testPrecedingCancellationError_CallsLockFailureHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestPriorityFeature.State()
      ) {
        TestPriorityFeature()
      }

      // Start a low priority action
      await store.send(.startLowPriority) {
        $0.lowPriorityRunning = true
      }

      // Then start a high priority action that should cancel the low priority one
      await store.send(.startHighPriority) {
        $0.highPriorityRunning = true
      }

      // Should receive the failure handler notification for the cancelled action
      await store.receive(.lockFailureOccurred("lowPriorityTask")) {
        $0.lastCancelledActionId = "lowPriorityTask"
        $0.lockFailureCallCount += 1
      }

      // High priority task completes
      await store.receive(.taskCompleted(.high)) {
        $0.highPriorityRunning = false
      }

      await store.finish()
    }
  }

  @Sendable func testReplaceableBehavior_CallsLockFailureHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestPriorityFeature.State()
      ) {
        TestPriorityFeature()
      }

      // Start a replaceable medium priority action
      await store.send(.startMediumReplaceable) {
        $0.mediumPriorityRunning = true
      }

      // Start another medium priority action that should replace the first one
      await store.send(.startMediumExclusive) {
        $0.mediumPriorityRunning = true
      }

      // Should receive the failure handler notification for the replaced action
      await store.receive(.lockFailureOccurred("mediumReplaceableTask")) {
        $0.lastCancelledActionId = "mediumReplaceableTask"
        $0.lockFailureCallCount += 1
      }

      // New medium priority task completes
      await store.receive(.taskCompleted(.medium)) {
        $0.mediumPriorityRunning = false
      }

      await store.finish()
    }
  }

  // Test feature for priority-based cancellation
  @Reducer
  struct TestPriorityFeature {
    struct State: Equatable {
      var lowPriorityRunning = false
      var mediumPriorityRunning = false
      var highPriorityRunning = false
      var lastCancelledActionId: String?
      var lockFailureCallCount = 0
    }

    enum Action: Equatable {
      case startLowPriority
      case startMediumReplaceable
      case startMediumExclusive
      case startHighPriority
      case taskCompleted(Priority)
      case lockFailureOccurred(String)
    }

    enum Priority: Equatable {
      case low, medium, high
    }

    enum CancelID: LockmanCancelId {
      case task
    }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .startLowPriority:
          state.lowPriorityRunning = true
          return Effect<Action>.run { send in
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            await send(.taskCompleted(.low))
          }
          .withLock(
            strategy: LockmanPriorityBasedStrategy.self,
            info: LockmanPriorityBasedInfo(
              actionId: "lowPriorityTask",
              priority: .low(.exclusive)
            ),
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let actionId) = priorityError
              {
                await send(.lockFailureOccurred(actionId))
              }
            },
            action: action,
            cancelID: CancelID.task
          )

        case .startMediumReplaceable:
          state.mediumPriorityRunning = true
          return Effect<Action>.run { send in
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
            await send(.taskCompleted(.medium))
          }
          .withLock(
            strategy: LockmanPriorityBasedStrategy.self,
            info: LockmanPriorityBasedInfo(
              actionId: "mediumReplaceableTask",
              priority: .medium(.replaceable)
            ),
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let actionId) = priorityError
              {
                await send(.lockFailureOccurred(actionId))
              }
            },
            action: action,
            cancelID: CancelID.task
          )

        case .startMediumExclusive:
          state.mediumPriorityRunning = true
          return Effect<Action>.run { send in
            try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 second
            await send(.taskCompleted(.medium))
          }
          .withLock(
            strategy: LockmanPriorityBasedStrategy.self,
            info: LockmanPriorityBasedInfo(
              actionId: "mediumExclusiveTask",
              priority: .medium(.exclusive)
            ),
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let actionId) = priorityError
              {
                await send(.lockFailureOccurred(actionId))
              }
            },
            action: action,
            cancelID: CancelID.task
          )

        case .startHighPriority:
          state.highPriorityRunning = true
          return Effect<Action>.run { send in
            try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 second
            await send(.taskCompleted(.high))
          }
          .withLock(
            strategy: LockmanPriorityBasedStrategy.self,
            info: LockmanPriorityBasedInfo(
              actionId: "highPriorityTask",
              priority: .high(.exclusive)
            ),
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let actionId) = priorityError
              {
                await send(.lockFailureOccurred(actionId))
              }
            },
            action: action,
            cancelID: CancelID.task
          )

        case let .taskCompleted(priority):
          switch priority {
          case .low:
            state.lowPriorityRunning = false
          case .medium:
            state.mediumPriorityRunning = false
          case .high:
            state.highPriorityRunning = false
          }
          return .none

        case let .lockFailureOccurred(actionId):
          state.lastCancelledActionId = actionId
          state.lockFailureCallCount += 1
          return .none
        }
      }
    }
  }
}
