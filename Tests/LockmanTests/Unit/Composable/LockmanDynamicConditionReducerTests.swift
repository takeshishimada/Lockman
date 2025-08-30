import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - LockmanDynamicConditionReducer Tests

final class LockmanDynamicConditionReducerTests: XCTestCase {

  // MARK: - Phase 1: Basic Happy Path Tests

  func testConditionCancel_BlocksExecution() async throws {
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      LockmanDynamicConditionReducer(
        { (state: inout TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            state.counter = 1
            return .none
          case .blockedAction:
            state.counter = 999  // Should never be executed due to condition
            return .none
          case .completed:
            return .none
          }
        },
        condition: { (state: TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            return .success
          case .blockedAction:
            return .cancel(DynamicConditionError.blocked)
          case .completed:
            return .success
          }
        },
        boundaryId: TestBoundaryID.feature
      )
    }
    
    // Blocked action should not modify state or produce effects
    await store.send(TestAction.blockedAction)
    // State should remain unchanged (counter = 0)
    
    await store.finish()
  }

  func testConditionSuccess_AllowsExecution() async throws {
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      LockmanDynamicConditionReducer(
        { (state: inout TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            state.counter = 1
            return .none
          case .blockedAction:
            state.counter = 999  // Should never be executed due to condition
            return .none
          case .completed:
            return .none
          }
        },
        condition: { (state: TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            return .success
          case .blockedAction:
            return .cancel(DynamicConditionError.blocked)
          case .completed:
            return .success
          }
        },
        boundaryId: TestBoundaryID.feature
      )
    }
    
    // Allowed action should modify state
    await store.send(TestAction.allowedAction) {
      $0.counter = 1
    }
    
    await store.finish()
  }

  func testInitWithReduceInstance_BasicSuccess() async throws {
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      LockmanDynamicConditionReducer(
        base: Reduce { (state: inout TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            state.counter = 2
            return .none
          case .blockedAction:
            state.counter = 999  // Should never be executed due to condition
            return .none
          case .completed:
            return .none
          }
        },
        condition: { (state: TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            return .success
          case .blockedAction:
            return .cancel(DynamicConditionError.blocked)
          case .completed:
            return .success
          }
        },
        boundaryId: TestBoundaryID.feature
      )
    }
    
    // Test the Reduce instance initialization path
    await store.send(TestAction.allowedAction) {
      $0.counter = 2  // Different value to distinguish from function init
    }
    
    await store.finish()
  }

  func testLockFailureHandler_CalledOnCancel() async throws {
    var handlerCalled = false
    var capturedError: Error?
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      LockmanDynamicConditionReducer(
        { (state: inout TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            state.counter = 1
            return .none
          case .blockedAction:
            state.counter = 999  // Should never be executed
            return .none
          case .completed:
            return .none
          }
        },
        condition: { (state: TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            return .success
          case .blockedAction:
            return .cancel(DynamicConditionError.blocked)
          case .completed:
            return .success
          }
        },
        boundaryId: TestBoundaryID.feature,
        lockFailure: { error, send in
          handlerCalled = true
          capturedError = error
        }
      )
    }
    
    // Send blocked action - should trigger lockFailure handler
    await store.send(TestAction.blockedAction)
    
    await store.finish()
    
    // Verify handler was called with correct error
    XCTAssertTrue(handlerCalled)
    XCTAssertTrue(capturedError is DynamicConditionError)
  }

  func testSuccessWithPrecedingCancellation() async throws {
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      LockmanDynamicConditionReducer(
        { (state: inout TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            state.counter = 3
            return .none
          case .blockedAction:
            state.counter = 999  // Should never be executed
            return .none
          case .completed:
            return .none
          }
        },
        condition: { (state: TestState, action: TestAction) in
          switch action {
          case .allowedAction:
            let error = TestPrecedingCancellationError(
              actionId: LockmanActionId("previousAction"),
              boundaryId: TestBoundaryID.feature
            )
            return .successWithPrecedingCancellation(error: error)  // Different success variant
          case .blockedAction:
            return .cancel(DynamicConditionError.blocked)
          case .completed:
            return .success
          }
        },
        boundaryId: TestBoundaryID.feature
      )
    }
    
    // Test successWithPrecedingCancellation case
    await store.send(TestAction.allowedAction) {
      $0.counter = 3
    }
    
    await store.finish()
  }

  // MARK: - Action-Level Lock Method Tests

  func testActionLevelLock_WithCondition_Success() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              await send(TestAction.completed)
            },
            boundaryId: TestBoundaryID.actionLevel,
            lockCondition: { _, _ in .success }  // Action-level condition
          )
        case .completed:
          state.counter = 10
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.receive(TestAction.completed) {
      $0.counter = 10
    }
    
    await store.finish()
  }

  func testActionLevelLock_WithCondition_Cancel() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    var lockFailureCalled = false
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              await send(TestAction.completed)  // Should not be executed
            },
            lockFailure: { error, send in
              lockFailureCalled = true
            },
            boundaryId: TestBoundaryID.actionLevel,
            lockCondition: { _, _ in .cancel(DynamicConditionError.actionBlocked) }  // Reject condition
          )
        case .completed:
          state.counter = 20  // Should not be reached
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.finish()
    
    // Verify lock failure was called and operation didn't execute
    XCTAssertTrue(lockFailureCalled)
    XCTAssertEqual(store.state.counter, 0)  // Should remain unchanged
  }

  func testActionLevelLock_WithoutCondition_Success() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              await send(TestAction.completed)
            },
            boundaryId: TestBoundaryID.actionLevel
            // No lockCondition - should always execute
          )
        case .completed:
          state.counter = 30
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.receive(TestAction.completed) {
      $0.counter = 30
    }
    
    await store.finish()
  }

  func testActionLevelLock_WithErrorHandling() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    var errorHandlerCalled = false
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              throw DynamicConditionError.actionBlocked  // Simulate error
            },
            catch: { error, send in
              errorHandlerCalled = true
              await send(TestAction.completed)
            },
            boundaryId: TestBoundaryID.actionLevel,
            lockCondition: { _, _ in .success }
          )
        case .completed:
          state.counter = 40
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.receive(TestAction.completed) {
      $0.counter = 40
    }
    
    await store.finish()
    
    // Verify error handler was called
    XCTAssertTrue(errorHandlerCalled)
  }

  // MARK: - Additional Coverage Tests for 100%

  func testActionLevelLock_WithCondition_CancelWithoutLockFailureHandler() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              await send(TestAction.completed)  // Should not be executed
            },
            // No lockFailure handler provided - testing the .none return path
            boundaryId: TestBoundaryID.actionLevel,
            lockCondition: { _, _ in .cancel(DynamicConditionError.actionBlocked) }
          )
        case .completed:
          state.counter = 50  // Should not be reached
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.finish()
    
    // Verify operation didn't execute (counter remains 0)
    XCTAssertEqual(store.state.counter, 0)
  }

  func testActionLevelLock_WithoutCondition_OperationError() async throws {
    let dynamicReducer = LockmanDynamicConditionReducer(
      { (state: inout TestState, action: TestAction) in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryID.feature
    )
    
    var errorHandlerCalled = false
    
    let store = await TestStore<TestState, TestAction>(
      initialState: TestState()
    ) {
      Reduce { (state: inout TestState, action: TestAction) in
        switch action {
        case .allowedAction:
          return dynamicReducer.lock(
            state: state,
            action: action,
            operation: { send in
              throw DynamicConditionError.actionBlocked  // Simulate error in no-condition path
            },
            catch: { error, send in
              errorHandlerCalled = true
              await send(TestAction.completed)
            },
            boundaryId: TestBoundaryID.actionLevel
            // No lockCondition - testing the no-condition error handler path
          )
        case .completed:
          state.counter = 60
          return .none
        case .blockedAction:
          return .none
        }
      }
    }
    
    await store.send(TestAction.allowedAction)
    
    await store.receive(TestAction.completed) {
      $0.counter = 60
    }
    
    await store.finish()
    
    // Verify error handler was called in no-condition path
    XCTAssertTrue(errorHandlerCalled)
  }

}

// MARK: - Test Support Types

private enum TestBoundaryID: LockmanBoundaryId {
  case feature
  case actionLevel
}

private enum DynamicConditionError: LockmanError {
  case blocked
  case actionBlocked
  
  var errorDescription: String? {
    switch self {
    case .blocked:
      return "Action blocked by condition"
    case .actionBlocked:
      return "Action level block"
    }
  }
}

private struct TestPrecedingCancellationError: LockmanPrecedingCancellationError {
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId
  
  init(actionId: LockmanActionId, boundaryId: any LockmanBoundaryId) {
    self.lockmanInfo = TestLockmanInfo(actionId: actionId, strategyId: LockmanStrategyId("test"))
    self.boundaryId = boundaryId
  }
  
  var errorDescription: String? {
    return "Preceding action cancelled: \(lockmanInfo.actionId)"
  }
}

@CasePathable
private enum TestAction: Equatable {
  case allowedAction
  case blockedAction
  case completed
}

private struct TestState: Equatable {
  var counter = 0
  var isProcessing = false
}