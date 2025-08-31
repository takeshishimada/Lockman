import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - Reducer+Lockman Tests

final class ReducerLockmanTests: XCTestCase {

  // MARK: - Phase 1: Basic Happy Path Tests with TestStore

  func testLockWithCondition_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()
          .lock(
            condition: { state, _ in .success },
            boundaryId: TestBoundaryID.feature
          )
      }

      await store.send(.performOperation) {
        $0.isProcessing = true
      }

      await store.receive(\.operationCompleted) {
        $0.isProcessing = false
        $0.result = 42
      }

      await store.finish()
    }
  }

  func testLockWithBoundaryId_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeatureWithAction.State()
      ) {
        TestFeatureWithAction()
          .lock(boundaryId: TestBoundaryID.feature)
      }

      await store.send(.performLockableOperation) {
        $0.isProcessing = true
      }

      await store.receive(\.completed) {
        $0.isProcessing = false
        $0.value = 100
      }

      await store.finish()
    }
  }

  func testLockWithCaseKeyPath_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestCompositeFeature.State()
      ) {
        TestCompositeFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.subAction1
          )
      }

      await store.send(.subAction1(.performAction)) {
        $0.result1 = 1
      }

      await store.finish()
    }
  }

  func testLockWithTwoCaseKeyPaths_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestCompositeFeature.State()
      ) {
        TestCompositeFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.subAction1,
            \.subAction2
          )
      }

      await store.send(.subAction2(.performAction)) {
        $0.result2 = 2
      }

      await store.finish()
    }
  }

  func testLockWithThreeCaseKeyPaths_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestCompositeFeature.State()
      ) {
        TestCompositeFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.subAction1,
            \.subAction2,
            \.subAction3
          )
      }

      await store.send(.subAction3(.performAction)) {
        $0.result3 = 3
      }

      await store.finish()
    }
  }

  func testLockWithFourCaseKeyPaths_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestCompositeFeature.State()
      ) {
        TestCompositeFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.subAction1,
            \.subAction2,
            \.subAction3,
            \.subAction4
          )
      }

      await store.send(.subAction4(.performAction)) {
        $0.result4 = 4
      }

      await store.finish()
    }
  }

  func testLockWithFiveCaseKeyPaths_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestCompositeFeature.State()
      ) {
        TestCompositeFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.subAction1,
            \.subAction2,
            \.subAction3,
            \.subAction4,
            \.subAction5
          )
      }

      await store.send(.subAction5(.performAction)) {
        $0.result5 = 5
      }

      await store.finish()
    }
  }

  // MARK: - Phase 2.5: Fallback Logic Coverage Tests

  func testLockWithCaseKeyPath_FallbackToRootAction() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFallbackFeature.State()
      ) {
        TestFallbackFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction  // This path exists but TestViewAction doesn't implement LockmanAction
          )
      }

      await store.send(.rootLockmanAction) {  // Root action implements LockmanAction
        $0.executed = true
      }

      await store.finish()
    }
  }

  func testLockWithTwoCaseKeyPaths_FallbackToRootAction() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFallbackFeature.State()
      ) {
        TestFallbackFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // These paths exist but don't return LockmanAction
            \.other
          )
      }

      await store.send(.rootLockmanAction) {  // Root action implements LockmanAction
        $0.executed = true
      }

      await store.finish()
    }
  }

  func testLockWithThreeCaseKeyPaths_FallbackToRootAction() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFallbackFeature.State()
      ) {
        TestFallbackFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // These paths exist but don't return LockmanAction
            \.other,
            \.viewAction
          )
      }

      await store.send(.rootLockmanAction) {  // Root action implements LockmanAction
        $0.executed = true
      }

      await store.finish()
    }
  }

  func testLockWithFourCaseKeyPaths_FallbackToRootAction() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFallbackFeature.State()
      ) {
        TestFallbackFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // These paths exist but don't return LockmanAction
            \.other,
            \.viewAction,
            \.other
          )
      }

      await store.send(.rootLockmanAction) {  // Root action implements LockmanAction
        $0.executed = true
      }

      await store.finish()
    }
  }

  func testLockWithFiveCaseKeyPaths_FallbackToRootAction() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFallbackFeature.State()
      ) {
        TestFallbackFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // These paths exist but don't return LockmanAction
            \.other,
            \.viewAction,
            \.other,
            \.viewAction
          )
      }

      await store.send(.rootLockmanAction) {  // Root action implements LockmanAction
        $0.executed = true
      }

      await store.finish()
    }
  }

  // MARK: - Phase 2.9: Return Nil Path Coverage Tests

  func testLockWithCaseKeyPath_ReturnNil() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestNonLockmanFeature.State()
      ) {
        TestNonLockmanFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction  // Path exists but doesn't return LockmanAction
          )
      }

      await store.send(.normalAction) {  // Root action doesn't implement LockmanAction either
        $0.normalActionExecuted = true
      }

      await store.finish()
    }
  }

  func testLockWithTwoCaseKeyPaths_ReturnNil() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestNonLockmanFeature.State()
      ) {
        TestNonLockmanFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // Paths exist but don't return LockmanAction
            \.other
          )
      }

      await store.send(.normalAction) {  // Root action doesn't implement LockmanAction either
        $0.normalActionExecuted = true
      }

      await store.finish()
    }
  }

  func testLockWithThreeCaseKeyPaths_ReturnNil() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestNonLockmanFeature.State()
      ) {
        TestNonLockmanFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // Paths exist but don't return LockmanAction
            \.other,
            \.viewAction
          )
      }

      await store.send(.normalAction) {  // Root action doesn't implement LockmanAction either
        $0.normalActionExecuted = true
      }

      await store.finish()
    }
  }

  func testLockWithFourCaseKeyPaths_ReturnNil() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestNonLockmanFeature.State()
      ) {
        TestNonLockmanFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // Paths exist but don't return LockmanAction
            \.other,
            \.viewAction,
            \.other
          )
      }

      await store.send(.normalAction) {  // Root action doesn't implement LockmanAction either
        $0.normalActionExecuted = true
      }

      await store.finish()
    }
  }

  func testLockWithFiveCaseKeyPaths_ReturnNil() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestNonLockmanFeature.State()
      ) {
        TestNonLockmanFeature()
          .lock(
            boundaryId: TestBoundaryID.feature,
            for: \.viewAction,  // Paths exist but don't return LockmanAction
            \.other,
            \.viewAction,
            \.other,
            \.viewAction
          )
      }

      await store.send(.normalAction) {  // Root action doesn't implement LockmanAction either
        $0.normalActionExecuted = true
      }

      await store.finish()
    }
  }

}

// MARK: - Test Support Types

private enum TestBoundaryID: LockmanBoundaryId {
  case feature
}

// For condition-based locking (doesn't require LockmanAction)
@CasePathable
private enum TestAction: Equatable {
  case performOperation
  case operationCompleted
}

@Reducer
private struct TestFeature {
  struct State: Equatable {
    var isProcessing = false
    var result: Int?
  }

  typealias Action = TestAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .performOperation:
        state.isProcessing = true
        return .send(.operationCompleted)

      case .operationCompleted:
        state.isProcessing = false
        state.result = 42
        return .none
      }
    }
  }
}

// For LockmanAction-based locking
@CasePathable
private enum TestLockmanAction: Equatable, LockmanAction {
  case performLockableOperation
  case completed

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    switch self {
    case .performLockableOperation:
      return LockmanSingleExecutionInfo(
        actionId: "performLockableOperation",
        mode: .boundary
      )
    case .completed:
      return LockmanSingleExecutionInfo(
        actionId: "other",
        mode: .action
      )
    }
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@Reducer
private struct TestFeatureWithAction {
  struct State: Equatable {
    var isProcessing = false
    var value: Int?
  }

  typealias Action = TestLockmanAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .performLockableOperation:
        state.isProcessing = true
        return .send(.completed)

      case .completed:
        state.isProcessing = false
        state.value = 100
        return .none
      }
    }
  }
}

// For composite feature testing with case key paths
@CasePathable
private enum TestSubAction1: Equatable, LockmanAction {
  case performAction

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "subAction1",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@CasePathable
private enum TestSubAction2: Equatable, LockmanAction {
  case performAction

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "subAction2",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@CasePathable
private enum TestSubAction3: Equatable, LockmanAction {
  case performAction

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "subAction3",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@CasePathable
private enum TestSubAction4: Equatable, LockmanAction {
  case performAction

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "subAction4",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@CasePathable
private enum TestSubAction5: Equatable, LockmanAction {
  case performAction

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "subAction5",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@CasePathable
private enum TestCompositeAction: Equatable {
  case subAction1(TestSubAction1)
  case subAction2(TestSubAction2)
  case subAction3(TestSubAction3)
  case subAction4(TestSubAction4)
  case subAction5(TestSubAction5)
  case other
}

@Reducer
private struct TestCompositeFeature {
  struct State: Equatable {
    var result1: Int?
    var result2: Int?
    var result3: Int?
    var result4: Int?
    var result5: Int?
  }

  typealias Action = TestCompositeAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .subAction1(.performAction):
        state.result1 = 1
        return .none

      case .subAction2(.performAction):
        state.result2 = 2
        return .none

      case .subAction3(.performAction):
        state.result3 = 3
        return .none

      case .subAction4(.performAction):
        state.result4 = 4
        return .none

      case .subAction5(.performAction):
        state.result5 = 5
        return .none

      case .other:
        return .none
      }
    }
  }
}

// For fallback logic testing - Root action implements LockmanAction but case paths won't match
@CasePathable
private enum TestFallbackAction: Equatable, LockmanAction {
  case rootLockmanAction
  case viewAction(TestViewAction)  // This exists but we'll use wrong paths
  case other

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "rootLockmanAction",
      mode: .boundary
    )
  }

  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

// Non-LockmanAction nested type
@CasePathable
private enum TestViewAction: Equatable {
  case performViewAction
}

@Reducer
private struct TestFallbackFeature {
  struct State: Equatable {
    var executed = false
  }

  typealias Action = TestFallbackAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .rootLockmanAction:
        state.executed = true
        return .none

      case .viewAction(.performViewAction):
        return .none

      case .other:
        return .none
      }
    }
  }
}

// For final return nil testing - Neither root action nor case paths return LockmanAction
@CasePathable
private enum TestNonLockmanAction: Equatable {
  case normalAction
  case viewAction(TestViewAction)  // case path exists but returns non-LockmanAction
  case other
}

@Reducer
private struct TestNonLockmanFeature {
  struct State: Equatable {
    var normalActionExecuted = false
  }

  typealias Action = TestNonLockmanAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .normalAction:
        state.normalActionExecuted = true
        return .none

      case .viewAction(.performViewAction):
        return .none

      case .other:
        return .none
      }
    }
  }
}
