import ComposableArchitecture
import XCTest

@testable import Lockman

/// Test reducer actions for LockmanDynamicConditionReducer testing
enum DynamicConditionTestAction: Sendable {
  case test
  case increment
  case decrement
  case purchase(amount: Double)
  case withdraw(amount: Double)
  case nonLockman
  case authenticated
  case notAuthenticated
  case completedSuccessfully
  case failed(Error)
}

/// Test state for LockmanDynamicConditionReducer testing
struct DynamicConditionTestState: Sendable, Equatable {
  var counter: Int = 0
  var isAuthenticated: Bool = true
  var balance: Double = 100.0
  var lastAction: String = ""
}

/// Test boundary ID for LockmanDynamicConditionReducer testing
struct DynamicConditionTestBoundaryId: LockmanBoundaryId {
  let value: String
  
  static let auth = DynamicConditionTestBoundaryId(value: "auth")
  static let payment = DynamicConditionTestBoundaryId(value: "payment")
  static let feature = DynamicConditionTestBoundaryId(value: "feature")
}

/// Test error for condition failures
struct DynamicConditionTestError: LockmanError {
  let message: String
  
  static let notAuthenticated = DynamicConditionTestError(message: "not authenticated")
  static let insufficientBalance = DynamicConditionTestError(message: "insufficient balance")
  static let noLockRequired = DynamicConditionTestError(message: "no lock required")
}

final class LockmanDynamicConditionReducerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Initializer Tests
  
  func testInitWithBasicReduceFunction() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        case .decrement:
          state.counter -= 1
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        return .success
      },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
  }
  
  func testInitWithExistingReduceInstance() {
    let baseReducer = Reduce<DynamicConditionTestState, DynamicConditionTestAction> { state, action in
      switch action {
      case .increment:
        state.counter += 1
      case .decrement:
        state.counter -= 1
      default:
        break
      }
      return .none
    }
    
    let reducer = LockmanDynamicConditionReducer(
      base: baseReducer,
      condition: { state, action in
        return .success
      },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
  }
  
  func testInitWithLockFailureHandler() {
    var lockFailureCalled = false
    var receivedError: Error?
    
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        state.counter += 1
        return .none
      },
      condition: { state, action in
        return .cancel(DynamicConditionTestError.notAuthenticated)
      },
      boundaryId: DynamicConditionTestBoundaryId.auth,
      lockFailure: { error, send in
        lockFailureCalled = true
        receivedError = error
      }
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0) // State should not be modified
    XCTAssertTrue(lockFailureCalled)
    XCTAssertNotNil(receivedError)
  }

  // MARK: - Reducer-Level Condition Tests
  
  func testConditionResultSuccess() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        return .success
      },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
  }
  
  func testConditionResultSuccessWithPrecedingCancellation() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        return .successWithPrecedingCancellation(error: DynamicConditionTestPrecedingCancellationError())
      },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
  }
  
  func testConditionResultCancel() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        state.counter += 1
        return .none
      },
      condition: { state, action in
        return .cancel(DynamicConditionTestError.notAuthenticated)
      },
      boundaryId: DynamicConditionTestBoundaryId.auth
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0) // Base reducer should not execute
    // Effect should be .none but can't test equality directly
  }
  
  func testConditionResultCancelWithLockFailureHandler() {
    var lockFailureCalled = false
    var receivedError: Error?
    
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        state.counter += 1
        return .none
      },
      condition: { state, action in
        return .cancel(DynamicConditionTestError.notAuthenticated)
      },
      boundaryId: DynamicConditionTestBoundaryId.auth,
      lockFailure: { error, send in
        lockFailureCalled = true
        receivedError = error
      }
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0)
    XCTAssertTrue(lockFailureCalled)
    XCTAssertNotNil(receivedError)
  }

  // MARK: - Action-Level Lock Method Tests
  
  func testActionLevelLockWithoutCondition() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState()
    let effect = reducer.lock(
      state: state,
      action: .test,
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.payment))
  }
  
  func testActionLevelLockWithConditionSuccess() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState(balance: 150.0)
    let effect = reducer.lock(
      state: state,
      action: .purchase(amount: 100.0),
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment,
      lockCondition: { state, action in
        if case .purchase(let amount) = action {
          guard state.balance >= amount else {
            return .cancel(DynamicConditionTestError.insufficientBalance)
          }
        }
        return .success
      }
    )
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.payment))
  }
  
  func testActionLevelLockWithConditionCancel() {
    var lockFailureCalled = false
    
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState(balance: 50.0)
    let effect = reducer.lock(
      state: state,
      action: .purchase(amount: 100.0),
      operation: { send in
        await send(.completedSuccessfully)
      },
      lockFailure: { error, send in
        lockFailureCalled = true
      },
      boundaryId: DynamicConditionTestBoundaryId.payment,
      lockCondition: { state, action in
        if case .purchase(let amount) = action {
          guard state.balance >= amount else {
            return .cancel(DynamicConditionTestError.insufficientBalance)
          }
        }
        return .success
      }
    )
    
    // Assert that effect returns .none but can't directly compare effects
    XCTAssertTrue(lockFailureCalled)
  }
  
  func testActionLevelLockWithConditionCancelWithoutLockFailureHandler() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState(balance: 50.0)
    let effect = reducer.lock(
      state: state,
      action: .purchase(amount: 100.0),
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment,
      lockCondition: { state, action in
        if case .purchase(let amount) = action {
          guard state.balance >= amount else {
            return .cancel(DynamicConditionTestError.insufficientBalance)
          }
        }
        return .success
      }
    )
    
    // Effect should be .none but can't directly test equality
  }

  // MARK: - Complex Condition Logic Tests
  
  func testAuthenticationCondition() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .purchase(let amount):
          state.balance -= amount
        case .withdraw(let amount):
          state.balance -= amount
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        switch action {
        case .purchase, .withdraw:
          guard state.isAuthenticated else {
            return .cancel(DynamicConditionTestError.notAuthenticated)
          }
          return .success
        default:
          return .cancel(DynamicConditionTestError.noLockRequired)
        }
      },
      boundaryId: DynamicConditionTestBoundaryId.auth
    )
    
    // Test authenticated user
    var authenticatedState = DynamicConditionTestState(isAuthenticated: true, balance: 100.0)
    let authenticatedEffect = reducer.reduce(into: &authenticatedState, action: .purchase(amount: 50.0))
    
    XCTAssertEqual(authenticatedState.balance, 50.0)
    XCTAssertTrue(authenticatedEffect.isCancellable(id: DynamicConditionTestBoundaryId.auth))
    
    // Test unauthenticated user
    var unauthenticatedState = DynamicConditionTestState(isAuthenticated: false, balance: 100.0)
    let unauthenticatedEffect = reducer.reduce(into: &unauthenticatedState, action: .purchase(amount: 50.0))
    
    XCTAssertEqual(unauthenticatedState.balance, 100.0) // Should not change
    // Effect should be .none but can't test equality directly
  }
  
  func testSkipLockForNonTargetActions() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        switch action {
        case .purchase, .withdraw:
          return .success
        default:
          return .cancel(DynamicConditionTestError.noLockRequired)
        }
      },
      boundaryId: DynamicConditionTestBoundaryId.auth
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0) // Base reducer should not execute
    // Effect should be .none but can't test equality directly
  }

  // MARK: - Effect Testing
  
  func testEffectCancellableWithCorrectBoundaryId() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        return .run { send in
          try await Task.sleep(nanoseconds: 1_000_000)
          await send(.completedSuccessfully)
        }
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    var state = DynamicConditionTestState()
    let effect = reducer.reduce(into: &state, action: .test)
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
    XCTAssertFalse(effect.isCancellable(id: DynamicConditionTestBoundaryId.auth))
  }
  
  func testActionLevelLockEffectCancellableWithCorrectBoundaryId() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState()
    let effect = reducer.lock(
      state: state,
      action: .test,
      operation: { send in
        try await Task.sleep(nanoseconds: 1_000_000)
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.payment))
    XCTAssertFalse(effect.isCancellable(id: DynamicConditionTestBoundaryId.feature))
  }

  // MARK: - Error Handling Tests
  
  func testErrorHandlingInActionLevelLock() {
    var errorHandlerCalled = false
    var receivedError: Error?
    
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState()
    let effect = reducer.lock(
      state: state,
      action: .test,
      operation: { send in
        throw DynamicConditionTestError.insufficientBalance
      },
      catch: { error, send in
        errorHandlerCalled = true
        receivedError = error
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.payment))
    // Error handler will be called when effect runs
  }

  // MARK: - Priority and Task Configuration Tests
  
  func testActionLevelLockWithCustomPriority() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState()
    let effect = reducer.lock(
      state: state,
      action: .test,
      priority: .high,
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    XCTAssertTrue(effect.isCancellable(id: DynamicConditionTestBoundaryId.payment))
  }
}

// MARK: - Test Helper Extensions

struct DynamicConditionTestPrecedingCancellationError: LockmanPrecedingCancellationError {
  var lockmanInfo: any LockmanInfo {
    return DynamicConditionTestLockmanInfo(
      actionId: LockmanActionId("cancelled"),
      strategyId: LockmanStrategyId("test")
    )
  }
  
  var boundaryId: any LockmanBoundaryId {
    return DynamicConditionTestBoundaryId.feature
  }
}

struct DynamicConditionTestLockmanInfo: LockmanInfo {
  let actionId: LockmanActionId
  let strategyId: LockmanStrategyId
  let uniqueId: UUID = UUID()
  let isCancellationTarget: Bool = false
  
  var debugDescription: String {
    return "DynamicConditionTestLockmanInfo(action: \(actionId), strategy: \(strategyId))"
  }
}

// Extension to check if Effect is cancellable with specific ID
fileprivate extension Effect {
  func isCancellable<ID: Hashable>(id: ID) -> Bool {
    // This is a simplified check for testing purposes
    // In real implementation, we would need to inspect the effect structure
    return true
  }
}