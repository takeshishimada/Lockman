import ComposableArchitecture
import Foundation
import XCTest
@testable import LockmanComposable
@testable import LockmanCore

// MARK: - Effect+withLock Tests

final class EffectWithLockSingleExecutionStrategyTests: XCTestCase {
  // MARK: - Basic Functionality Tests

  func testNormalActionExecution() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      // When: Normal action execution without any pre-existing locks
      await store.send(.tapIncrement)
      await store.receive(.increment) {
        $0.count = 1
      }
      await store.finish()
    }
  }

  func testActionBlockedByExistingLock() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      // Given: Pre-existing lock with same ID and action name
      let id = TestSingleExecutionFeature.CancelID.userAction
      let info = LockmanSingleExecutionInfo(
        actionId: TestSingleExecutionFeature.Action.tapIncrement.actionName,
        mode: .boundary
      )

      // Use correct API for locking
      let result = strategy.canLock(id: id, info: info)
      XCTAssertEqual(result, .success)
      strategy.lock(id: id, info: info)

      // When: Attempting to execute the same action
      await store.send(.tapIncrement)

      // Then: Action should be blocked (no increment action received)
      await store.finish()
      // State remains unchanged (count is still 0)

      // Clean up: Release the lock for next tests
      strategy.unlock(id: id, info: info)
    }
  }

  func testActionExecutionAfterLockRelease() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      let id = TestSingleExecutionFeature.CancelID.userAction
      let info = LockmanSingleExecutionInfo(
        actionId: TestSingleExecutionFeature.Action.tapIncrement.actionName,
        mode: .boundary
      )

      // Given: Pre-existing lock
      let lockResult = strategy.canLock(id: id, info: info)
      XCTAssertEqual(lockResult, .success)
      strategy.lock(id: id, info: info)

      // When: First attempt is blocked
      await store.send(.tapIncrement)
      await store.finish()
      // State remains unchanged at this point

      // And: Lock is released
      strategy.unlock(id: id, info: info)

      // When: Second attempt after unlock
      await store.send(.tapIncrement)
      await store.receive(.increment) {
        $0.count = 1
      }
      await store.finish()
    }
  }

  // MARK: - Different Action Tests

  func testDifferentActionsWithSameCancelId() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      // Given: Lock for tapIncrement action
      let id = TestSingleExecutionFeature.CancelID.userAction
      let incrementInfo = LockmanSingleExecutionInfo(
        actionId: TestSingleExecutionFeature.Action.tapIncrement.actionName,
        mode: .boundary
      )
      let lockResult = strategy.canLock(id: id, info: incrementInfo)
      XCTAssertEqual(lockResult, .success)
      strategy.lock(id: id, info: incrementInfo)

      // When: tapIncrement is blocked
      await store.send(.tapIncrement)
      await store.finish()
      // State remains unchanged (count is still 0)

      // Clean up: Release the lock
      strategy.unlock(id: id, info: incrementInfo)

      // But: tapDecrement should work (different action name)
      await store.send(.tapDecrement)
      await store.receive(.decrement) {
        $0.count = -1
      }
      await store.finish()
    }
  }

  // MARK: - Lock Failure Tests

  func testLockFailureReturnsNoneEffect() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      // Given: Pre-existing lock
      let id = TestSingleExecutionFeature.CancelID.userAction
      let info = LockmanSingleExecutionInfo(actionId: "tapIncrement", mode: .boundary)
      let lockResult = strategy.canLock(id: id, info: info)
      XCTAssertEqual(lockResult, .success)
      strategy.lock(id: id, info: info)

      // When: Attempting action that will fail to acquire lock
      await store.send(.tapIncrement)

      // Then: Lock failure should result in .none effect (no further actions)
      await store.finish()
      // State remains unchanged (count is still 0)

      // Clean up: Release the lock
      strategy.unlock(id: id, info: info)
    }
  }

  // MARK: - Concurrent Execution Tests

  func testConcurrentActionsWithDifferentIds() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestMultiIdFeature.State(count: 0)
      ) {
        TestMultiIdFeature()
      }

      // When: Actions with different cancel IDs are executed concurrently
      await store.send(.actionWithId1)
      await store.receive(.increment) { $0.count = 1 }

      // Both should execute successfully
      await store.send(.actionWithId2)
      await store.receive(.increment) { $0.count = 2 }

      await store.finish()
    }
  }

//  // MARK: - Error Handling Tests
//
//  func testwithLock handles strategy not registered error() async throws {
//  func testWithLockHandlesStrategyNotRegisteredError() async {
//    let emptyContainer = LockmanStrategyContainer()
//
//    await Lockman.withTestContainer(emptyContainer) {
//      let store = await TestStore(
//        initialState: TestSingleExecutionFeature.State(count: 0)
//      ) {
//        TestSingleExecutionFeature()
//      }
//
//      // When: Action is sent with unregistered strategy
//      await store.send(.tapIncrement)
//
//      // Then: Action should fail gracefully (no increment action received)
//      await store.finish()
//      // State remains unchanged (count is still 0)
//    }
//  }

  func testWithLockAutomaticUnlockOnCompletion() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestSingleExecutionFeature.State(count: 0)
      ) {
        TestSingleExecutionFeature()
      }

      // First execution should complete and automatically unlock
      await store.send(.tapIncrement)
      await store.receive(.increment) {
        $0.count = 1
      }
      await store.finish()

      // Second execution should succeed (proving first was unlocked)
      await store.send(.tapIncrement)
      await store.receive(.increment) {
        $0.count = 2
      }
      await store.finish()
    }
  }
}

final class EffectConcatenateWithLockTests: XCTestCase {
  // MARK: - Basic Functionality Tests

  func testNormalConcatenateWithLockExecution() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestConcatenateWithLockFeature.State(count: 0, isLocked: false)
      ) {
        TestConcatenateWithLockFeature()
      }

      // When: Normal action execution without any pre-existing locks
      await store.send(.executeConcatenateWithLock)
      await store.receive(\.increment) {
        $0.count = 1
      }
      await store.receive(\.increment) {
        $0.count = 2
      }
      await store.finish()

      // もう一度アクションを送信してアンロックされていることを確認
      await store.send(.executeConcatenateWithLock)
      await store.receive(\.increment) {
        $0.count = 3
      }
      await store.receive(\.increment) {
        $0.count = 4
      }
      await store.finish()
    }
  }

  func testConcatenateWithLockHandlesCancellationWithAutoUnlock() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestConcatenateWithLockFeature.State(count: 0, isLocked: false)
      ) {
        TestConcatenateWithLockFeature()
      }

      // When: Execute concatenateWithLock with cancelling operation
      await store.send(.executeConcatenateWithLockWithCancel)
      await store.receive(\.operationCanceled)

      // Then: Should handle the cancellation (no actions received due to cancellation)
      await store.finish()

      // Verify that lock is released and subsequent actions can execute
      await store.send(.executeConcatenateWithLock)
      await store.receive(\.increment) {
        $0.count = 1
      }
      await store.receive(\.increment) {
        $0.count = 2
      }
      await store.finish()
    }
  }

  func testConcatenateWithLockPreventsCurrentExecution() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestConcatenateWithLockFeature.State(count: 0, isLocked: false)
      ) {
        TestConcatenateWithLockFeature()
      }

      // Given: Pre-existing lock with same ID and action name
      let id = TestConcatenateWithLockFeature.CancelID.userAction
      let info = LockmanSingleExecutionInfo(
        actionId: TestConcatenateWithLockFeature.Action.executeConcatenateWithLock.actionName,
        mode: .boundary
      )
      let result = strategy.canLock(id: id, info: info)
      XCTAssertEqual(result, .success)
      strategy.lock(id: id, info: info)

      // When: Attempting to execute the same action
      await store.send(.executeConcatenateWithLock)

      // Then: Action should be blocked (no increment actions received)
      await store.finish()
      // State remains unchanged (count is still 0)

      // Clean up: Release the lock for next tests
      strategy.unlock(id: id, info: info)

      // Verify that after unlock, action can execute normally
      await store.send(.executeConcatenateWithLock)
      await store.receive(\.increment) {
        $0.count = 1
      }
      await store.receive(\.increment) {
        $0.count = 2
      }
      await store.finish()
    }
  }

  func testConcatenateWithLockWithEmptyOperations() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestConcatenateWithLockFeature.State(count: 0, isLocked: false)
      ) {
        TestConcatenateWithLockFeature()
      }

      // When: Execute concatenateWithLock with empty operations
      await store.send(.executeConcatenateWithLockEmpty)

      // Then: Should complete without issues
      await store.finish()

      // Verify that subsequent actions can execute (lock was properly released)
      await store.send(.executeConcatenateWithLock)
      await store.receive(\.increment) {
        $0.count = 1
      }
      await store.receive(\.increment) {
        $0.count = 2
      }
      await store.finish()
    }
  }
}

// MARK: - withLock with Manual Unlock Tests

final class EffectWithLockManualUnlockTests: XCTestCase {
  func testManualUnlockInOperation() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestMultiIdFeature.State(count: 0)
      ) {
        TestMultiIdFeature()
      }

      // When: Action with manual unlock
      await store.send(.actionWithId2)
      await store.receive(.increment) {
        $0.count = 1
      }
      await store.finish()

      // Verify that subsequent actions can execute (manual unlock worked)
      await store.send(.actionWithId2)
      await store.receive(.increment) {
        $0.count = 2
      }
      await store.finish()
    }
  }
}

// MARK: - Test Helper Feature

@Reducer
private struct TestConcatenateWithLockFeature {
  struct State: Equatable {
    var count: Int = 0
    var isLocked: Bool = false
    var executionOrder: [String] = []

    init(count: Int = 0, isLocked: Bool = false, executionOrder: [String] = []) {
      self.count = count
      self.isLocked = isLocked
      self.executionOrder = executionOrder
    }
  }

  @CasePathable
  enum Action: LockmanSingleExecutionAction {
    case executeConcatenateWithLock
    case executeConcatenateWithLockWithFailure
    case executeConcatenateWithLockWithCancel
    case executeConcatenateWithLockEmpty
    case increment
    case operationFailed
    case operationCanceled

    var actionName: String {
      switch self {
      case .executeConcatenateWithLock: return "executeConcatenateWithLock"
      case .executeConcatenateWithLockWithFailure: return "executeConcatenateWithLockWithFailure"
      case .executeConcatenateWithLockWithCancel: return "executeConcatenateWithLockWithCancel"
      case .executeConcatenateWithLockEmpty: return "executeConcatenateWithLockEmpty"
      case .increment: return "increment"
      case .operationFailed: return "operationFailed"
      case .operationCanceled: return "operationCanceled"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }

    var strategyType: LockmanSingleExecutionStrategy.Type {
      LockmanSingleExecutionStrategy.self
    }
  }

  enum CancelID: Hashable {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .executeConcatenateWithLock:
        return .concatenateWithLock(
          unlockOption: .immediate,
          operations: [
            .send(.increment),
            .send(.increment),
          ],
          action: action,
          cancelID: CancelID.userAction
        )

      case .executeConcatenateWithLockWithFailure:
        return .concatenateWithLock(
          unlockOption: .immediate,
          operations: [
            .send(.operationFailed),
          ],
          action: action,
          cancelID: CancelID.userAction
        )

      case .executeConcatenateWithLockWithCancel:
        return .concatenateWithLock(
          unlockOption: .immediate,
          operations: [
            .send(.operationCanceled),
          ],
          action: action,
          cancelID: CancelID.userAction
        )

      case .executeConcatenateWithLockEmpty:
        return .concatenateWithLock(
          unlockOption: .immediate,
          operations: [],
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none

      case .operationFailed:
        return .run { _ in
          throw LockmanError.strategyNotRegistered("TestError")
        }

      case .operationCanceled:
        return .run { _ in
          throw CancellationError()
        }
      }
    }
  }
}

// MARK: - Test Helpers

@Reducer
private struct TestSingleExecutionFeature {
  struct State: Equatable {
    var count: Int = 0
    init(count: Int = 0) { self.count = count }
  }

  @CasePathable
  enum Action: LockmanSingleExecutionAction {
    case tapIncrement
    case tapDecrement
    case increment
    case decrement

    var actionName: String {
      switch self {
      case .tapIncrement: return "tapIncrement"
      case .tapDecrement: return "tapDecrement"
      case .increment: return "increment"
      case .decrement: return "decrement"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }

    var strategyType: LockmanSingleExecutionStrategy.Type {
      LockmanSingleExecutionStrategy.self
    }
  }

  enum CancelID: Hashable {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .tapIncrement:
        return .withLock(
          unlockOption: .immediate,
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .tapDecrement:
        return .withLock(
          unlockOption: .immediate,
          operation: { send in
            await send(.decrement)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none

      case .decrement:
        state.count -= 1
        return .none
      }
    }
  }
}

// Helper feature for testing multiple cancel IDs
@Reducer
private struct TestMultiIdFeature {
  struct State: Equatable {
    var count: Int = 0
  }

  @CasePathable
  enum Action: LockmanSingleExecutionAction {
    case actionWithId1
    case actionWithId2
    case increment

    var actionName: String {
      switch self {
      case .actionWithId1: return "actionWithId1"
      case .actionWithId2: return "actionWithId2"
      case .increment: return "increment"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }

    var strategyType: LockmanSingleExecutionStrategy.Type {
      LockmanSingleExecutionStrategy.self
    }
  }

  enum CancelID: Hashable {
    case id1
    case id2
  }

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .actionWithId1:
        return .withLock(
          unlockOption: .immediate,
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.id1
        )

      case .actionWithId2:
        return .withLock(
          unlockOption: .immediate,
          operation: { send, unlock in
            await send(.increment)
            unlock()
          },
          action: action,
          cancelID: CancelID.id2
        )

      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}
