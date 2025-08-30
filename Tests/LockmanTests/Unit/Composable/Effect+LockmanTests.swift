import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - Effect+Lockman Tests

final class EffectLockmanTests: XCTestCase {

  // MARK: - Phase 1: Basic Happy Path Tests with TestStore

  func testLockConcatenatingOperations_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()
      }
      
      // Test concatenating operations
      await store.send(.performConcatenatedOperations) {
        $0.isProcessing = true
      }
      
      // Verify step effects are executed
      await store.receive(\.step1Completed) {
        $0.stepCount = 1
      }
      await store.receive(\.step2Completed) {
        $0.isProcessing = false
        $0.stepCount = 2
      }
      
      await store.finish()
    }
  }

  func testLockSingleOperation_BasicSuccess() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()
      }
      
      // Test single operation
      await store.send(.performSingleOperation) {
        $0.isProcessing = true
      }
      
      await store.receive(\.operationCompleted) {
        $0.isProcessing = false
        $0.result = 42
      }
      
      await store.finish()
    }
  }

}

// MARK: - Test Support Types

@CasePathable
private enum TestAction: Equatable, LockmanAction {
  case performConcatenatedOperations
  case performSingleOperation
  case step1Completed
  case step2Completed
  case operationCompleted

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    switch self {
    case .performConcatenatedOperations, .performSingleOperation:
      return LockmanSingleExecutionInfo(
        actionId: "lockableAction",
        mode: .boundary
      )
    case .step1Completed, .step2Completed, .operationCompleted:
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

private enum TestBoundaryID: LockmanBoundaryId {
  case feature
}

@Reducer
private struct TestFeature {
  struct State: Equatable {
    var isProcessing = false
    var stepCount = 0
    var result: Int?
  }
  
  typealias Action = TestAction
  
  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .performConcatenatedOperations:
        state.isProcessing = true
        
        // Use Effect.lock with concatenating operations
        return Effect.lock(
          concatenating: [
            .send(.step1Completed),
            .send(.step2Completed)
          ],
          action: action,
          boundaryId: TestBoundaryID.feature
        )
        
      case .performSingleOperation:
        state.isProcessing = true
        
        // Use Effect.lock with single operation  
        return Effect.lock(
          operation: .send(.operationCompleted),
          action: action,
          boundaryId: TestBoundaryID.feature
        )
        
      case .step1Completed:
        state.stepCount = 1
        return .none
        
      case .step2Completed:
        state.isProcessing = false
        state.stepCount = 2
        return .none
        
      case .operationCompleted:
        state.isProcessing = false
        state.result = 42
        return .none
      }
    }
  }
}