import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - LockmanReducer Tests

final class LockmanReducerTests: XCTestCase {

  // MARK: - Phase 1: Basic Happy Path Tests

  func testLockmanReducer_WithLockmanAction_Success() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()  // Already has .lock() applied in body
      }
      
      await store.send(.lockableAction(.performAction)) {
        $0.counter = 1
        $0.isProcessing = true
      }
      
      await store.receive(\.completed) {
        $0.isProcessing = false
      }
      
      await store.finish()
    }
  }

  func testLockmanReducer_WithNonLockmanAction_PassThrough() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()  // Already has .lock() applied in body
      }
      
      await store.send(.nonLockableAction) {
        $0.counter = 100  // Should execute without lock
      }
      
      await store.finish()
    }
  }

  func testLockmanReducer_LockFirstBehavior() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()  // Already has .lock() applied in body
      }
      
      // Send lockable action - should succeed and change state
      await store.send(.lockableAction(.performAction)) {
        $0.counter = 1  // State change happens because lock was acquired
        $0.isProcessing = true
      }
      
      await store.receive(\.completed) {
        $0.isProcessing = false
      }
      
      await store.finish()
    }
  }

}

// MARK: - Test Support Types

private enum TestBoundaryID: LockmanBoundaryId {
  case feature
}

// Test action with mixed types - some conform to LockmanAction, others don't
@CasePathable
private enum TestAction: Equatable {
  case lockableAction(TestLockableAction)
  case nonLockableAction
  case completed
}

// Only this nested action implements LockmanAction
@CasePathable
private enum TestLockableAction: Equatable, LockmanAction {
  case performAction
  
  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    return LockmanSingleExecutionInfo(
      actionId: "lockableAction",
      mode: .boundary
    )
  }
  
  var unlockOption: LockmanUnlockOption {
    return .immediate
  }
}

@Reducer
private struct TestFeature {
  struct State: Equatable {
    var counter = 0
    var isProcessing = false
  }
  
  typealias Action = TestAction
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .lockableAction(.performAction):
        state.counter = 1
        state.isProcessing = true
        return .send(.completed)
        
      case .nonLockableAction:
        state.counter = 100  // Different value to distinguish behavior
        return .none
        
      case .completed:
        state.isProcessing = false
        return .none
      }
    }
    .lock(boundaryId: TestBoundaryID.feature, for: \.lockableAction)
  }
}