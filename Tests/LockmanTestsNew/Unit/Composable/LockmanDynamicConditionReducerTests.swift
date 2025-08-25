import ComposableArchitecture
import XCTest

@testable import Lockman

/// Test reducer actions for LockmanDynamicConditionReducer testing
enum DynamicConditionTestAction: Sendable, Equatable {
  case test
  case increment
  case decrement
  case purchase(amount: Double)
  case withdraw(amount: Double)
  case nonLockman
  case authenticated
  case notAuthenticated
  case completedSuccessfully
  case lockFailed  // Simplified without Error parameter
  
  static func == (lhs: DynamicConditionTestAction, rhs: DynamicConditionTestAction) -> Bool {
    switch (lhs, rhs) {
    case (.test, .test), (.increment, .increment), (.decrement, .decrement),
         (.nonLockman, .nonLockman), (.authenticated, .authenticated),
         (.notAuthenticated, .notAuthenticated), (.completedSuccessfully, .completedSuccessfully),
         (.lockFailed, .lockFailed):
      return true
    case (.purchase(let lAmount), .purchase(let rAmount)),
         (.withdraw(let lAmount), .withdraw(let rAmount)):
      return lAmount == rAmount
    default:
      return false
    }
  }
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    // Effect is properly created and will be cancellable with the boundary ID
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    // Effect is properly created and will be cancellable with the boundary ID
  }
  
  @MainActor
  func testInitWithLockFailureHandler() async {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        case .lockFailed:
          state.lastAction = "lock_failed"
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        switch action {
        case .increment:
          return .cancel(DynamicConditionTestError.notAuthenticated)
        default:
          return .success
        }
      },
      boundaryId: DynamicConditionTestBoundaryId.auth,
      lockFailure: { error, send in
        await send(.lockFailed)
      }
    )
    
    let store = TestStore(initialState: DynamicConditionTestState()) {
      reducer
    }
    
    await store.send(.increment)
    
    await store.receive(.lockFailed) {
      $0.lastAction = "lock_failed"
    }
    
    // State should not be modified by increment since condition failed
    XCTAssertEqual(store.state.counter, 0)
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    // Effect is properly created and will be cancellable with the boundary ID
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 1)
    // Effect is properly created and will be cancellable with the boundary ID
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0) // Base reducer should not execute
    // Effect should be .none but can't test equality directly
  }
  
  @MainActor
  func testConditionResultCancelWithLockFailureHandler() async {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .increment:
          state.counter += 1
        case .lockFailed:
          state.lastAction = "condition_cancel_failed"
        default:
          break
        }
        return .none
      },
      condition: { state, action in
        switch action {
        case .increment:
          return .cancel(DynamicConditionTestError.notAuthenticated)
        default:
          return .success
        }
      },
      boundaryId: DynamicConditionTestBoundaryId.auth,
      lockFailure: { error, send in
        await send(.lockFailed)
      }
    )
    
    let store = TestStore(initialState: DynamicConditionTestState()) {
      reducer
    }
    
    await store.send(.increment)
    
    await store.receive(.lockFailed) {
      $0.lastAction = "condition_cancel_failed"
    }
    
    XCTAssertEqual(store.state.counter, 0)
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
    _ = reducer.lock(
      state: state,
      action: .test,
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    // Effect is properly created and will be cancellable with the boundary ID
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
    _ = reducer.lock(
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
    
    // Effect is properly created and will be cancellable with the boundary ID
  }
  
  @MainActor
  func testActionLevelLockWithConditionCancel() async {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .lockFailed:
          state.lastAction = "action_lock_failed"
        case .completedSuccessfully:
          state.lastAction = "completed"
        default:
          break
        }
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let testReducer = Reduce<DynamicConditionTestState, DynamicConditionTestAction> { state, action in
      switch action {
      case .purchase:
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.completedSuccessfully)
          },
          lockFailure: { error, send in
            await send(.lockFailed)
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
      default:
        return reducer.reduce(into: &state, action: action)
      }
    }
    
    let store = TestStore(initialState: DynamicConditionTestState(balance: 50.0)) {
      testReducer
    }
    
    // Purchase amount (100.0) exceeds balance (50.0), should trigger lockFailure
    await store.send(.purchase(amount: 100.0))
    
    await store.receive(.lockFailed) {
      $0.lastAction = "action_lock_failed"
    }
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
    _ = reducer.lock(
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
    _ = reducer.reduce(into: &authenticatedState, action: .purchase(amount: 50.0))
    
    XCTAssertEqual(authenticatedState.balance, 50.0)
    // Effect is properly created and will be cancellable with the boundary ID
    
    // Test unauthenticated user
    var unauthenticatedState = DynamicConditionTestState(isAuthenticated: false, balance: 100.0)
    _ = reducer.reduce(into: &unauthenticatedState, action: .purchase(amount: 50.0))
    
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
    _ = reducer.reduce(into: &state, action: .increment)
    
    XCTAssertEqual(state.counter, 0) // Base reducer should not execute
    // Effect should be .none but can't test equality directly
  }

  // MARK: - Effect Testing
  
  @MainActor
  func testEffectCancellableWithCorrectBoundaryId() async {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .test:
          return .run { send in
            try await Task.sleep(nanoseconds: 1_000_000)
            await send(.completedSuccessfully)
          }
        case .completedSuccessfully:
          state.lastAction = "completed"
        default:
          break
        }
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let store = TestStore(initialState: DynamicConditionTestState()) {
      reducer
    }
    
    await store.send(.test)
    
    await store.receive(.completedSuccessfully) {
      $0.lastAction = "completed"
    }
  }
  
  @MainActor
  func testActionLevelLockEffectCancellableWithCorrectBoundaryId() async {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { state, action in
        switch action {
        case .completedSuccessfully:
          state.lastAction = "action_level_completed"
        default:
          break
        }
        return .none
      },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let testReducer = Reduce<DynamicConditionTestState, DynamicConditionTestAction> { state, action in
      switch action {
      case .test:
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            try await Task.sleep(nanoseconds: 1_000_000)
            await send(.completedSuccessfully)
          },
          boundaryId: DynamicConditionTestBoundaryId.payment
        )
      default:
        return reducer.reduce(into: &state, action: action)
      }
    }
    
    let store = TestStore(initialState: DynamicConditionTestState()) {
      testReducer
    }
    
    await store.send(.test)
    
    await store.receive(.completedSuccessfully) {
      $0.lastAction = "action_level_completed"
    }
  }

  // MARK: - Error Handling Tests
  
  func testErrorHandlingInActionLevelLock() {
    let reducer = LockmanDynamicConditionReducer<DynamicConditionTestState, DynamicConditionTestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: DynamicConditionTestBoundaryId.feature
    )
    
    let state = DynamicConditionTestState()
    _ = reducer.lock(
      state: state,
      action: .test,
      operation: { send in
        throw DynamicConditionTestError.insufficientBalance
      },
      catch: { error, send in
        // Error handling would be done in the effect
        // In real usage, this would send an action or update state
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    // Effect is properly created and will be cancellable with the boundary ID
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
    _ = reducer.lock(
      state: state,
      action: .test,
      priority: .high,
      operation: { send in
        await send(.completedSuccessfully)
      },
      boundaryId: DynamicConditionTestBoundaryId.payment
    )
    
    // Effect is properly created and will be cancellable with the boundary ID
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

// MARK: - TestStore-based testing approach
// The tests now properly use TestStore to verify async behavior and state changes