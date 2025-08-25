import ComposableArchitecture
import XCTest

@testable import Lockman

//// MARK: - Test Support Types
//// Shared test support types are defined in TestSupport.swift
//
///// Unit tests for LockmanReducer
/////
///// Tests LockmanReducer functionality using TestStore pattern for realistic TCA integration scenarios.
//final class LockmanReducerTests: XCTestCase {
//
//  override func setUp() {
//    super.setUp()
//    // Setup test environment
//  }
//
//  override func tearDown() {
//    super.tearDown()
//    // Cleanup after each test
//    LockmanManager.cleanup.all()
//  }
//
//  // MARK: - Test State and Actions
//
//  struct LockmanTestState: Equatable {
//    var counter = 0
//    var lastActionId = ""
//    var isProcessing = false
//    var operations: [String] = []
//    var errors: [String] = []
//  }
//
//  enum LockmanTestAction: Equatable {
//    case increment
//    case decrement
//    case setProcessing(Bool)
//    case lockOperation(String)
//    case operationCompleted(String)
//    case lockFailed(String)
//    case reset
//  }
//
//  // MARK: - Lock-First Behavior Tests with TestStore
//
//  @MainActor
//  func testLockFirstBehaviorWithSuccessfulLock() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      // Create base reducer that handles LockmanTestAction
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .increment:
//          state.counter += 1
//          state.lastActionId = "increment"
//          return .none
//
//        case .decrement:
//          state.counter -= 1
//          state.lastActionId = "decrement"
//          return .none
//
//        case .setProcessing(let isProcessing):
//          state.isProcessing = isProcessing
//          state.lastActionId = "setProcessing"
//          return .none
//
//        case .operationCompleted(let operation):
//          state.operations.append(operation)
//          return .none
//
//        case .lockFailed(let error):
//          state.errors.append(error)
//          return .none
//
//        case .reset:
//          state = LockmanTestState()
//          return .none
//
//        default:
//          return .none
//        }
//      }
//
//      // Wrap with LockmanReducer using action mapping
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          // Map LockmanTestAction to SharedTestAction
//          switch action {
//          case .increment: return SharedTestAction.increment
//          case .decrement: return SharedTestAction.decrement
//          case .setProcessing: return SharedTestAction.setProcessing(true)
//          default: return nil  // Non-lockman actions
//          }
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test successful lock acquisition and state mutation
//      await store.send(.increment) {
//        $0.counter = 1
//        $0.lastActionId = "increment"
//      }
//    }
//  }
//
//  @MainActor
//  func testLockFirstBehaviorWithFailedLock() async {
//    // Use empty container to force lock failure
//    let emptyContainer = LockmanStrategyContainer()
//
//    await LockmanManager.withTestContainer(emptyContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .increment:
//          state.counter += 1
//          state.lastActionId = "increment"
//          return .none
//        case .lockFailed(let error):
//          state.errors.append(error)
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: { error, send in
//          await send(.lockFailed("strategy_not_found"))
//        },
//        extractLockmanAction: { action in
//          switch action {
//          case .increment: return SharedTestAction.increment
//          default: return nil
//          }
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test lock failure scenario
//      await store.send(.increment)  // State should not change due to lock failure
//
//      await store.receive(.lockFailed("strategy_not_found")) {
//        $0.errors.append("strategy_not_found")
//      }
//    }
//  }
//
//  @MainActor
//  func testLockFirstBehaviorWithNonLockmanAction() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .reset:
//          state = LockmanTestState()
//          state.lastActionId = "reset"
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          // reset action is not a lockman action
//          return nil
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test non-lockman action (should execute without locking)
//      await store.send(.reset) {
//        $0.lastActionId = "reset"
//      }
//    }
//  }
//
//  @MainActor
//  func testProcessingStatePattern() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .setProcessing(let isProcessing):
//          state.isProcessing = isProcessing
//          state.lastActionId = "setProcessing"
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          switch action {
//          case .setProcessing(let value): return SharedTestAction.setProcessing(value)
//          default: return nil
//          }
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test setting processing state
//      await store.send(.setProcessing(true)) {
//        $0.isProcessing = true
//        $0.lastActionId = "setProcessing"
//      }
//
//      await store.send(.setProcessing(false)) {
//        $0.isProcessing = false
//        $0.lastActionId = "setProcessing"
//      }
//    }
//  }
//
//  @MainActor
//  func testMultipleBoundaryIds() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .increment:
//          state.counter += 1
//          state.lastActionId = "increment"
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      // Create reducers with different boundary IDs
//      let lockmanReducer1 = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          switch action {
//          case .increment: return SharedTestAction.increment
//          default: return nil
//          }
//        }
//      )
//
//      let lockmanReducer2 = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.secondary,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          switch action {
//          case .increment: return SharedTestAction.increment
//          default: return nil
//          }
//        }
//      )
//
//      let store1 = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer1
//      }
//
//      let store2 = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer2
//      }
//
//      // Both should succeed since they use different boundaries
//      await store1.send(.increment) {
//        $0.counter = 1
//        $0.lastActionId = "increment"
//      }
//
//      await store2.send(.increment) {
//        $0.counter = 1
//        $0.lastActionId = "increment"
//      }
//    }
//  }
//
//  @MainActor
//  func testCounterIncrementDecrementPattern() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .increment:
//          state.counter += 1
//          state.lastActionId = "increment"
//          return .none
//        case .decrement:
//          state.counter -= 1
//          state.lastActionId = "decrement"
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          switch action {
//          case .increment: return SharedTestAction.increment
//          case .decrement: return SharedTestAction.decrement
//          default: return nil
//          }
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test increment/decrement pattern
//      await store.send(.increment) {
//        $0.counter = 1
//        $0.lastActionId = "increment"
//      }
//
//      await store.send(.increment) {
//        $0.counter = 2
//        $0.lastActionId = "increment"
//      }
//
//      await store.send(.decrement) {
//        $0.counter = 1
//        $0.lastActionId = "decrement"
//      }
//
//      await store.send(.decrement) {
//        $0.counter = 0
//        $0.lastActionId = "decrement"
//      }
//    }
//  }
//
//  @MainActor
//  func testRealWorldUsagePattern() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .lockOperation(let operation):
//          state.lastActionId = operation
//          // Simulate async operation
//          return .run { send in
//            try await Task.sleep(nanoseconds: 1_000_000)  // 1ms
//            await send(.operationCompleted(operation))
//          }
//
//        case .operationCompleted(let operation):
//          state.operations.append(operation)
//          return .none
//
//        case .lockFailed(let error):
//          state.errors.append(error)
//          return .none
//
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: { error, send in
//          await send(.lockFailed("async_operation_failed"))
//        },
//        extractLockmanAction: { action in
//          switch action {
//          case .lockOperation: return SharedTestAction.test
//          default: return nil
//          }
//        }
//      )
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        lockmanReducer
//      }
//
//      // Test real-world async operation pattern
//      await store.send(.lockOperation("async_task")) {
//        $0.lastActionId = "async_task"
//      }
//
//      await store.receive(.operationCompleted("async_task")) {
//        $0.operations.append("async_task")
//      }
//    }
//  }
//
//  @MainActor
//  func testReducerComposition() async {
//    let strategy = TestSingleExecutionStrategy()
//    let testContainer = LockmanStrategyContainer()
//    try! testContainer.register(strategy)
//
//    await LockmanManager.withTestContainer(testContainer) { @Sendable in
//      // Test that LockmanReducer can be composed with other reducers
//      let baseReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .increment:
//          state.counter += 1
//          return .none
//        case .reset:
//          state.counter = 0
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      // Create additional reducer for composition
//      let additionalReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        switch action {
//        case .reset:
//          state.lastActionId = "reset_composed"
//          return .none
//        default:
//          return .none
//        }
//      }
//
//      let lockmanReducer = LockmanReducer(
//        base: baseReducer,
//        boundaryId: TestBoundaryId.test,
//        unlockOption: .immediate,
//        lockFailure: nil,
//        extractLockmanAction: { action in
//          switch action {
//          case .increment: return SharedTestAction.increment
//          default: return nil
//          }
//        }
//      )
//
//      // Create composed reducer manually
//      let composedReducer = Reduce<LockmanTestState, LockmanTestAction> { state, action in
//        let lockmanEffect = lockmanReducer.reduce(into: &state, action: action)
//        let additionalEffect = additionalReducer.reduce(into: &state, action: action)
//        return .merge(lockmanEffect, additionalEffect)
//      }
//
//      let store = await TestStore(initialState: LockmanTestState()) {
//        composedReducer
//      }
//
//      await store.send(.increment) {
//        $0.counter = 1
//      }
//
//      await store.send(.reset) {
//        $0.counter = 0
//        $0.lastActionId = "reset_composed"
//      }
//    }
//  }
//}
