import ComposableArchitecture
import Lockman
import XCTest

@testable import Lockman

// Test-specific error for dynamic condition tests
private struct ComposableTestDynamicConditionError: LockmanError, LocalizedError {
  let actionId: String
  let hint: String?

  var errorDescription: String? {
    "Dynamic condition not met for action '\(actionId)'" + (hint.map { ". Hint: \($0)" } ?? "")
  }

  var failureReason: String? {
    "The condition for action '\(actionId)' was not met" + (hint.map { ": \($0)" } ?? "")
  }

  static func conditionNotMet(actionId: String, hint: String?)
    -> ComposableTestDynamicConditionError
  {
    ComposableTestDynamicConditionError(actionId: actionId, hint: hint)
  }
}

/// Integration tests for LockmanDynamicConditionReducer with unified condition evaluation
final class LockmanDynamicConditionReducerIntegrationTests: XCTestCase {

  // MARK: - Test Types

  struct TestState: Equatable, Sendable {
    var count: Int = 0
    var isLoggedIn: Bool = false
    var operationResult: String = ""
    var reducerConditionChecked: Bool = false
    var actionConditionChecked: Bool = false
  }

  enum TestAction: Equatable, Sendable {
    case increment
    case login
    case performOperation
    case setOperationResult(String)
    case setReducerConditionChecked(Bool)
    case setActionConditionChecked(Bool)
  }

  enum TestBoundaryId: String, LockmanBoundaryId {
    case auth
    case operation
    case increment
  }

  override func tearDown() {
    super.tearDown()
    // Clean up all locks
    LockmanManager.cleanup.all()
  }

  // MARK: - Reducer-Level Condition Tests

  @MainActor
  func testReducerLevelConditionEvaluation() async {
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none
      case .login:
        state.isLoggedIn = true
        return .none
      case .performOperation:
        return .run { send in
          await send(.setOperationResult("Operation completed"))
        }
      case .setOperationResult(let result):
        state.operationResult = result
        return .none
      case .setReducerConditionChecked(let value):
        state.reducerConditionChecked = value
        return .none
      case .setActionConditionChecked(let value):
        state.actionConditionChecked = value
        return .none
      }
    }
    .lock(
      condition: { state, action in
        // Reducer-level condition: Only allow operations when logged in
        switch action {
        case .performOperation:
          if state.isLoggedIn {
            return .success
          } else {
            return .cancel(
              ComposableTestDynamicConditionError.conditionNotMet(
                actionId: "performOperation",
                hint: "User must be logged in"
              ))
          }
        default:
          return .success  // Allow other actions
        }
      },
      boundaryId: TestBoundaryId.auth,
      lockFailure: { error, send in
        await send(.setOperationResult("❌ \(error.localizedDescription)"))
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Test without login - should trigger reducer-level condition failure
    await store.send(.performOperation)

    await store.receive(
      .setOperationResult(
        "❌ Dynamic condition not met for action 'performOperation'. Hint: User must be logged in")
    ) {
      $0.operationResult =
        "❌ Dynamic condition not met for action 'performOperation'. Hint: User must be logged in"
    }

    // Login first
    await store.send(.login) {
      $0.isLoggedIn = true
    }

    // Now operation should succeed
    await store.send(.performOperation)

    await store.receive(.setOperationResult("Operation completed")) {
      $0.operationResult = "Operation completed"
    }
  }

  @MainActor
  func testReducerLevelConditionSkipsNonTargetActions() async {
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none
      case .login:
        state.isLoggedIn = true
        return .none
      default:
        return .none
      }
    }
    .lock(
      condition: { state, action in
        // Reducer-level condition: Only check performOperation
        switch action {
        case .performOperation:
          return state.isLoggedIn
            ? .success
            : .cancel(
              ComposableTestDynamicConditionError.conditionNotMet(
                actionId: "performOperation",
                hint: "Login required"
              ))
        default:
          return .success  // Skip lock for other actions
        }
      },
      boundaryId: TestBoundaryId.auth
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // These actions should work normally (no lock applied)
    await store.send(.increment) {
      $0.count = 1
    }

    await store.send(.login) {
      $0.isLoggedIn = true
    }
  }

  // MARK: - Action-Level Condition Tests

  @MainActor
  func testActionLevelConditionEvaluation() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          return .none
        case .performOperation:
          return .run { send in
            await send(.setOperationResult("Operation started"))
            try await Task.sleep(nanoseconds: 100_000_000)  // 100ms
            await send(.setOperationResult("Operation completed"))
          }
        case .setOperationResult(let result):
          state.operationResult = result
          return .none
        default:
          return .none
        }
      },
      condition: { _, action in
        // Skip reducer-level processing for login action
        switch action {
        case .login:
          return .cancel(
            ComposableTestDynamicConditionError.conditionNotMet(
              actionId: "login", hint: "No reducer processing needed"))
        default:
          return .success
        }
      },
      boundaryId: TestBoundaryId.auth
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .performOperation:
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.setOperationResult("Action-level operation completed"))
          },
          lockFailure: { error, send in
            await send(.setOperationResult("❌ \(error.localizedDescription)"))
          },
          boundaryId: TestBoundaryId.operation,
          lockCondition: { state, _ in
            // Action-level condition
            if state.isLoggedIn {
              return .success
            } else {
              return .cancel(
                ComposableTestDynamicConditionError.conditionNotMet(
                  actionId: "performOperation",
                  hint: "Action-level login check failed"
                ))
            }
          }
        )
      case .login:
        // Handle login manually since reducer-level skips it
        state.isLoggedIn = true
        return .none
      default:
        return reducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Test without login - action-level condition should fail
    await store.send(.performOperation)

    await store.receive(
      .setOperationResult(
        "❌ Dynamic condition not met for action 'performOperation'. Hint: Action-level login check failed"
      )
    ) {
      $0.operationResult =
        "❌ Dynamic condition not met for action 'performOperation'. Hint: Action-level login check failed"
    }

    // Update state to logged in
    await store.send(.login) {
      $0.isLoggedIn = true
    }

    // Now action-level operation should succeed
    await store.send(.performOperation)

    await store.receive(.setOperationResult("Action-level operation completed")) {
      $0.operationResult = "Action-level operation completed"
    }
  }

  // MARK: - Independent Level Processing Tests

  @MainActor
  func testReducerAndActionLevelIndependentProcessing() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          return .none
        case .performOperation:
          return .run { send in
            await send(.setOperationResult("Reducer-level operation"))
          }
        case .setOperationResult(let result):
          state.operationResult = result
          return .none
        default:
          return .none
        }
      },
      condition: { state, action in
        // Reducer-level condition
        switch action {
        case .performOperation:
          return state.isLoggedIn
            ? .success
            : .cancel(
              ComposableTestDynamicConditionError.conditionNotMet(
                actionId: "performOperation",
                hint: "Reducer-level auth failed"
              ))
        case .increment:
          // Skip reducer-level processing for increment - let action-level handle it
          return .cancel(
            ComposableTestDynamicConditionError.conditionNotMet(
              actionId: "increment",
              hint: "Skip reducer processing"
            ))
        default:
          return .success
        }
      },
      boundaryId: TestBoundaryId.auth,
      lockFailure: { error, send in
        await send(.setOperationResult("Reducer error: \(error.localizedDescription)"))
      }
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        // Action-level condition independent of reducer-level
        return reducer.lock(
          state: state,
          action: action,
          operation: { [state] send in
            // Increment count as part of action-level operation
            await send(.setOperationResult("Action-level increment"))
          },
          lockFailure: { error, send in
            await send(.setOperationResult("Action error: \(error.localizedDescription)"))
          },
          boundaryId: TestBoundaryId.increment,
          lockCondition: { state, _ in
            // Different condition than reducer-level
            return state.count < 5
              ? .success
              : .cancel(
                ComposableTestDynamicConditionError.conditionNotMet(
                  actionId: "increment",
                  hint: "Count limit reached"
                ))
          }
        )
      case .setOperationResult(let result):
        // Handle state updates manually since reducer-level may be skipped
        state.operationResult = result
        // If it's an increment operation, also increment count
        if result == "Action-level increment" {
          state.count += 1
        }
        return .none
      default:
        return reducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Test reducer-level failure (not logged in)
    await store.send(.performOperation)

    await store.receive(
      .setOperationResult(
        "Reducer error: Dynamic condition not met for action 'performOperation'. Hint: Reducer-level auth failed"
      )
    ) {
      $0.operationResult =
        "Reducer error: Dynamic condition not met for action 'performOperation'. Hint: Reducer-level auth failed"
    }

    // Test action-level success (count < 5)
    await store.send(.increment) {
      $0.count = 1
    }

    await store.receive(.setOperationResult("Action-level increment")) {
      $0.operationResult = "Action-level increment"
    }

    // Update count to trigger action-level failure
    await store.send(.increment) { $0.count = 2 }
    await store.receive(.setOperationResult("Action-level increment")) {
      $0.operationResult = "Action-level increment"
    }
    await store.send(.increment) { $0.count = 3 }
    await store.receive(.setOperationResult("Action-level increment")) {
      $0.operationResult = "Action-level increment"
    }
    await store.send(.increment) { $0.count = 4 }
    await store.receive(.setOperationResult("Action-level increment")) {
      $0.operationResult = "Action-level increment"
    }
    await store.send(.increment) { $0.count = 5 }
    await store.receive(.setOperationResult("Action-level increment")) {
      $0.operationResult = "Action-level increment"
    }

    // Now action-level should fail (count >= 5)
    await store.send(.increment) {
      $0.count = 6  // Reducer level still executes
    }

    await store.receive(
      .setOperationResult(
        "Action error: Dynamic condition not met for action 'increment'. Hint: Count limit reached")
    ) {
      $0.operationResult =
        "Action error: Dynamic condition not met for action 'increment'. Hint: Count limit reached"
    }
  }

  // MARK: - Cancellable Effect Tests

  @MainActor
  func testReducerLevelCancellableEffects() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .performOperation:
          return .run { send in
            await send(.setOperationResult("Long operation started"))
            try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            await send(.setOperationResult("Long operation completed"))
          }
        case .setOperationResult(let result):
          state.operationResult = result
          return .none
        default:
          return .none
        }
      },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryId.operation
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Start long operation
    await store.send(.performOperation)

    await store.receive(.setOperationResult("Long operation started")) {
      $0.operationResult = "Long operation started"
    }

    // Start another operation that should cancel the first
    await store.send(.performOperation)

    // Should receive the second operation's start message (first is cancelled)
    await store.receive(.setOperationResult("Long operation started")) {
      $0.operationResult = "Long operation started"
    }

    // Wait for completion
    await store.receive(.setOperationResult("Long operation completed")) {
      $0.operationResult = "Long operation completed"
    }
  }

  @MainActor
  func testActionLevelCancellableEffects() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryId.auth
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .performOperation:
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.setOperationResult("Action operation started"))
            try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            await send(.setOperationResult("Action operation completed"))
          },
          boundaryId: TestBoundaryId.operation,
          lockCondition: { _, _ in .success }
        )
      case .setOperationResult(let result):
        state.operationResult = result
        return .none
      default:
        return .none
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Start long operation
    await store.send(.performOperation)

    await store.receive(.setOperationResult("Action operation started")) {
      $0.operationResult = "Action operation started"
    }

    // Start another operation that should cancel the first
    await store.send(.performOperation)

    // Should receive the second operation's start message
    await store.receive(.setOperationResult("Action operation started")) {
      $0.operationResult = "Action operation started"
    }

    // Wait for completion
    await store.receive(.setOperationResult("Action operation completed")) {
      $0.operationResult = "Action operation completed"
    }
  }

  // MARK: - No Condition Tests

  @MainActor
  func testActionLevelWithoutCondition() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { _, _ in .none },
      condition: { _, _ in .success },
      boundaryId: TestBoundaryId.auth
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .performOperation:
        // No lockCondition specified - should always apply cancellable control
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.setOperationResult("No condition operation"))
          },
          boundaryId: TestBoundaryId.operation
        )
      case .setOperationResult(let result):
        state.operationResult = result
        return .none
      default:
        return .none
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Should always execute when no condition is provided
    await store.send(.performOperation)

    await store.receive(.setOperationResult("No condition operation")) {
      $0.operationResult = "No condition operation"
    }
  }
}
