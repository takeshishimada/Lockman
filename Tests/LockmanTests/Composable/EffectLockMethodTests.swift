import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Feature

@CasePathable
private enum TestFeatureAction: Equatable, LockmanAction {
  case fetch
  case fetchCompleted(Int)
  case lockFailed

  var lockmanInfo: LockmanSingleExecutionInfo {
    switch self {
    case .fetch:
      return LockmanSingleExecutionInfo(
        actionId: "fetch",
        mode: .boundary
      )
    case .fetchCompleted, .lockFailed:
      return LockmanSingleExecutionInfo(
        actionId: "other",
        mode: .action
      )
    }
  }
}

private enum TestFeatureCancelID: LockmanBoundaryId {
  case fetch
}

@Reducer
private struct TestFeature {
  struct State: Equatable {
    var count = 0
    var isLoading = false
  }

  typealias Action = TestFeatureAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .fetch:
        state.isLoading = true
        return .run { send in
          try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
          await send(.fetchCompleted(42))
        }
        .lock(
          action: action,
          boundaryId: TestFeatureCancelID.fetch
        )

      case .fetchCompleted(let value):
        state.isLoading = false
        state.count = value
        return .none

      case .lockFailed:
        state.isLoading = false
        return .none
      }
    }
  }
}

// MARK: - Tests

final class EffectLockMethodTests: XCTestCase {

  // MARK: - Basic Functionality Tests

  func testLockMethodAppliesLockToEffect() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()
      }

      // First fetch should succeed
      await store.send(.fetch) {
        $0.isLoading = true
      }

      await store.receive(\.fetchCompleted) {
        $0.isLoading = false
        $0.count = 42
      }
    }
  }

  func testLockMethodPreventsDoubleExecution() async {
    // Create a feature with lock failure handling
    struct TestFeatureWithLockFailure: Reducer {
      typealias State = TestFeature.State
      typealias Action = TestFeature.Action

      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .fetch:
            state.isLoading = true
            return .run { send in
              try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
              await send(.fetchCompleted(42))
            }
            .lock(
              action: action,
              boundaryId: TestFeatureCancelID.fetch,
              lockFailure: { _, send in
                await send(.lockFailed)
              }
            )

          case .fetchCompleted(let value):
            state.isLoading = false
            state.count = value
            return .none

          case .lockFailed:
            // Second fetch was blocked
            return .none
          }
        }
      }
    }

    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeatureWithLockFailure()
      }

      // First fetch starts
      await store.send(.fetch) {
        $0.isLoading = true
      }

      // Second fetch should be blocked
      await store.send(.fetch)

      // Should receive lock failed for second attempt
      await store.receive(\.lockFailed)

      // First fetch completes
      await store.receive(\.fetchCompleted) {
        $0.isLoading = false
        $0.count = 42
      }
    }
  }

}
