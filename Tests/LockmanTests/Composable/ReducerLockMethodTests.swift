//import ComposableArchitecture
//import XCTest
//
//@testable import Lockman
//
//// MARK: - Test Feature
//
//@CasePathable
//private enum TestReducerAction: Equatable, LockmanAction {
//  case lockableAction
//  case lockableResponse(Int)
//  case nonLockableAction
//  case nonLockableResponse(String)
//  case lockFailureAction
//
//  func createLockmanInfo() -> LockmanSingleExecutionInfo {
//    switch self {
//    case .lockableAction:
//      return LockmanSingleExecutionInfo(
//        actionId: "lockable",
//        mode: .boundary
//      )
//    case .lockFailureAction:
//      return LockmanSingleExecutionInfo(
//        actionId: "failure",
//        mode: .boundary
//      )
//    default:
//      return LockmanSingleExecutionInfo(
//        actionId: "other",
//        mode: .none
//      )
//    }
//  }
//}
//
//private enum TestReducerCancelID: LockmanBoundaryId {
//  case feature
//}
//
//@Reducer
//private struct TestReducerFeature {
//  struct State: Equatable {
//    var count = 0
//    var text = ""
//    var lockFailureCount = 0
//  }
//
//  typealias Action = TestReducerAction
//
//  var body: some ReducerOf<Self> {
//    Reduce { state, action in
//      switch action {
//      case .lockableAction:
//        return .run { send in
//          try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
//          await send(.lockableResponse(42))
//        }
//
//      case .lockableResponse(let value):
//        state.count = value
//        return .none
//
//      case .nonLockableAction:
//        return .run { send in
//          await send(.nonLockableResponse("done"))
//        }
//
//      case .nonLockableResponse(let text):
//        state.text = text
//        return .none
//
//      case .lockFailureAction:
//        return .run { send in
//          try await Task.sleep(nanoseconds: 100_000_000)
//          await send(.lockableResponse(99))
//        }
//      }
//    }
//  }
//}
//
//// MARK: - Tests
//
//final class ReducerLockMethodTests: XCTestCase {
//
//  // MARK: - Basic Functionality Tests
//
//  func testLockMethodAppliesLockToLockmanActions() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    await LockmanManager.withTestContainer(container) {
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(boundaryId: TestReducerCancelID.feature)
//      }
//
//      // Lockable action should work normally
//      await store.send(.lockableAction)
//      await store.receive(\.lockableResponse) {
//        $0.count = 42
//      }
//    }
//  }
//
//  func testNonLockmanActionsPassThrough() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    await LockmanManager.withTestContainer(container) {
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(boundaryId: TestReducerCancelID.feature)
//      }
//
//      // Non-lockable action should pass through without locking
//      await store.send(.nonLockableAction)
//      await store.receive(\.nonLockableResponse) {
//        $0.text = "done"
//      }
//    }
//  }
//
//  func testLockFailureCallback() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    let lockFailureExpectation = expectation(description: "Lock failure")
//    lockFailureExpectation.isInverted = false
//
//    await LockmanManager.withTestContainer(container) {
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(
//            boundaryId: TestReducerCancelID.feature,
//            lockFailure: { error, send in
//              lockFailureExpectation.fulfill()
//              // Could send an action here if needed, e.g.:
//              // await send(.lockFailureAction)
//            }
//          )
//      }
//
//      // Pre-lock the boundary
//      let info = LockmanSingleExecutionInfo(
//        actionId: "lockable",
//        mode: .boundary
//      )
//      _ = strategy.canLock(boundaryId: TestReducerCancelID.feature, info: info)
//      strategy.lock(boundaryId: TestReducerCancelID.feature, info: info)
//
//      // This should trigger lock failure
//      await store.send(.lockableAction)
//
//      // Wait for expectation
//      await fulfillment(of: [lockFailureExpectation], timeout: 1.0)
//
//      // Clean up
//      strategy.unlock(boundaryId: TestReducerCancelID.feature, info: info)
//    }
//  }
//
//  func testMultipleLockmanActionsWithSameBoundary() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    await LockmanManager.withTestContainer(container) {
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(boundaryId: TestReducerCancelID.feature)
//      }
//
//      // First lockable action
//      await store.send(.lockableAction)
//
//      // Second lockable action should be blocked (different action ID but same boundary)
//      await store.send(.lockFailureAction)
//
//      // First action completes
//      await store.receive(\.lockableResponse) {
//        $0.count = 42
//      }
//
//      // After first completes, another can execute
//      await store.send(.lockableAction)
//      await store.receive(\.lockableResponse)
//      // Count is already 42, so no state change expected
//    }
//  }
//
//  func testUnlockOptionIsRespected() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    await LockmanManager.withTestContainer(container) {
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(
//            boundaryId: TestReducerCancelID.feature,
//            unlockOption: .delayed(0.1)
//          )
//      }
//
//      // Send action with delayed unlock option
//      await store.send(.lockableAction)
//      await store.receive(\.lockableResponse) {
//        $0.count = 42
//      }
//
//      // Wait for delay to ensure unlock happens
//      try? await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
//
//      // Verify subsequent actions can execute
//      // (This tests that the lock was properly released)
//      await store.send(.lockableAction)
//      await store.receive(\.lockableResponse)
//      // Count is already 42, so no state change expected
//    }
//  }
//
//  func testReducerChaining() async {
//    let container = LockmanStrategyContainer()
//    let strategy = LockmanSingleExecutionStrategy()
//    try? container.register(strategy)
//
//    await LockmanManager.withTestContainer(container) {
//      // Test that LockmanReducer can be chained with other reducers
//      let store = await TestStore(
//        initialState: TestReducerFeature.State()
//      ) {
//        TestReducerFeature()
//          .lock(boundaryId: TestReducerCancelID.feature)
//          ._printChanges()  // Example of chaining
//      }
//
//      await store.send(.lockableAction)
//      await store.receive(\.lockableResponse) {
//        $0.count = 42
//      }
//    }
//  }
//}
