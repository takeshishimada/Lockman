import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - Preceding Action Cancellation Error Tests

final class EffectWithLockPrecedingCancellationTests: XCTestCase {
  func testPrecedingCancellationError_CallsLockFailureHandler() async {
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
      await store.receive(.lockFailureOccurred("lowPriority")) {
        $0.lastCancelledActionId = "lowPriority"
        $0.lockFailureCallCount += 1
      }

      // High priority task completes
      await store.receive(.taskCompleted(.high)) {
        $0.highPriorityRunning = false
      }

      await store.finish()
    }
  }

  func testHighPriorityPreemptsLowPriority_CallsLockFailureHandler() async {
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

      // Start high priority action that should preempt the low priority one
      await store.send(.startHighPriority) {
        $0.highPriorityRunning = true
      }

      // Should receive the failure handler notification for the preempted action
      await store.receive(.lockFailureOccurred("lowPriority")) {
        $0.lastCancelledActionId = "lowPriority"
        $0.lockFailureCallCount += 1
      }

      // High priority task completes
      await store.receive(.taskCompleted(.high)) {
        $0.highPriorityRunning = false
      }

      await store.finish()
    }
  }

  // Priority-based action for testing
  enum PriorityBasedAction: LockmanPriorityBasedAction {
    case lowPriority
    case lowReplaceable
    case highExclusive
    case highReplaceable

    var actionName: String {
      switch self {
      case .lowPriority: return "lowPriority"
      case .lowReplaceable: return "lowReplaceable"
      case .highExclusive: return "highExclusive"
      case .highReplaceable: return "highReplaceable"
      }
    }

    var lockmanInfo: LockmanPriorityBasedInfo {
      switch self {
      case .lowPriority:
        return LockmanPriorityBasedInfo(actionId: actionName, priority: .low(.exclusive))
      case .lowReplaceable:
        return LockmanPriorityBasedInfo(actionId: actionName, priority: .low(.replaceable))
      case .highExclusive:
        return LockmanPriorityBasedInfo(actionId: actionName, priority: .high(.exclusive))
      case .highReplaceable:
        return LockmanPriorityBasedInfo(actionId: actionName, priority: .high(.replaceable))
      }
    }
  }

  // Test feature for priority-based cancellation
  @Reducer
  struct TestPriorityFeature {
    struct State: Equatable {
      var lowPriorityRunning = false
      var highPriorityRunning = false
      var lastCancelledActionId: String?
      var lockFailureCallCount = 0
    }

    enum Action: Equatable {
      case startLowPriority
      case startHighPriority
      case taskCompleted(Priority)
      case lockFailureOccurred(String)
    }

    enum Priority: Equatable {
      case low, high
    }

    enum CancelID: Hashable {
      case task
    }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .startLowPriority:
          state.lowPriorityRunning = true
          return Effect<Action>.withLock(
            operation: { send, _ in
              try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1 second
              await send(.taskCompleted(.low))
            },
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let cancelledInfo) = priorityError
              {
                await send(.lockFailureOccurred(cancelledInfo.actionId))
              }
            },
            action: PriorityBasedAction.lowPriority,
            boundaryId: CancelID.task
          )

        case .startHighPriority:
          state.highPriorityRunning = true
          return Effect<Action>.withLock(
            operation: { send, _ in
              try? await Task.sleep(nanoseconds: 50_000_000)  // 0.05 second
              await send(.taskCompleted(.high))
            },
            lockFailure: { error, send in
              if let priorityError = error as? LockmanPriorityBasedError,
                case .precedingActionCancelled(let cancelledInfo) = priorityError
              {
                await send(.lockFailureOccurred(cancelledInfo.actionId))
              }
            },
            action: PriorityBasedAction.highExclusive,
            boundaryId: CancelID.task
          )

        case .taskCompleted(let priority):
          switch priority {
          case .low:
            state.lowPriorityRunning = false
          case .high:
            state.highPriorityRunning = false
          }
          return .none

        case .lockFailureOccurred(let actionId):
          state.lastCancelledActionId = actionId
          state.lockFailureCallCount += 1
          return .none
        }
      }
    }
  }
}
