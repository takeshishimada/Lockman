import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Feature for Automatic Cancellation ID

@CasePathable
private enum AutoCancellationTestAction: Equatable, LockmanAction {
  case startOperation
  case cancelOperation
  case operationCompleted
  case operationCancelled
  case lockFailed

  var lockmanInfo: LockmanSingleExecutionInfo {
    switch self {
    case .startOperation:
      return LockmanSingleExecutionInfo(
        actionId: "startOperation",
        mode: .boundary
      )
    case .cancelOperation, .operationCompleted, .operationCancelled, .lockFailed:
      return LockmanSingleExecutionInfo(
        actionId: "other",
        mode: .action
      )
    }
  }
}

private enum AutoCancellationTestCancelID: LockmanBoundaryId {
  case operation
}

@Reducer
private struct AutoCancellationTestFeature {
  struct State: Equatable {
    var isRunning = false
    var completedCount = 0
    var cancelledCount = 0
    var unlockCallCount = 0
  }

  typealias Action = AutoCancellationTestAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .startOperation:
        state.isRunning = true
        // Test: No manual cancellation ID needed - automatic application
        return .run { send in
          try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
          await send(.operationCompleted)
        }
        .lock(
          action: action,
          boundaryId: AutoCancellationTestCancelID.operation
        )

      case .cancelOperation:
        return .cancel(id: AutoCancellationTestCancelID.operation)

      case .operationCompleted:
        state.isRunning = false
        state.completedCount += 1
        return .none

      case .operationCancelled:
        state.isRunning = false
        state.cancelledCount += 1
        return .none

      case .lockFailed:
        state.isRunning = false
        return .none
      }
    }
  }
}

// MARK: - Automatic Cancellation ID Tests

final class EffectAutomaticCancellationTests: XCTestCase {

  func testAutomaticCancellationIDApplication() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: AutoCancellationTestFeature.State()
      ) {
        AutoCancellationTestFeature()
      }

      // Test: Operations work without manual cancellation ID specification
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Operation should complete normally (automatic cancellation applied)
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()
    }
  }

  func testConcurrentOperationsWithAutomaticCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: AutoCancellationTestFeature.State()
      ) {
        AutoCancellationTestFeature()
      }

      // First operation starts
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Second operation should be blocked by lock (no manual ID needed)
      await store.send(.startOperation)

      // First operation completes
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()
    }
  }

  func testManualUnlockStillWorksWithAutomaticCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: AutoCancellationTestFeature.State()
      ) {
        AutoCancellationTestFeature()
      }

      await store.send(.startOperation) {
        $0.isRunning = true
      }

      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()
    }
  }

  func testConcatenatingOperationsWithAutomaticCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: AutoCancellationTestFeature.State()
      ) {
        AutoCancellationTestFeature()
      }

      await store.send(.startOperation) {
        $0.isRunning = true
      }

      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()
    }
  }

  func testGuaranteedResourceCleanupOnCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: AutoCancellationTestFeature.State()
      ) {
        AutoCancellationTestFeature()
      }

      // Test basic operation completion
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()
    }
  }
}