import ComposableArchitecture
import Lockman
import XCTest

@testable import Lockman

/// Tests for Reducer.lock method chain API and LockmanDynamicConditionReducer with unified condition evaluation
final class LockmanDynamicConditionReducerMethodChainTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Types

  @ObservableState
  struct TestState: Equatable, Sendable {
    var count: Int = 0
    var isEnabled: Bool = true
    var isAuthenticated: Bool = true
    var balance: Double = 1000.0
    var lastError: String?
  }

  enum TestAction: Equatable, Sendable {
    case increment
    case purchase(amount: Double)
    case setEnabled(Bool)
    case setAuthenticated(Bool)
    case setBalance(Double)
    case setError(String)
    case incrementResponse
    case purchaseResponse(amount: Double)
  }

  enum CancelID: LockmanBoundaryId {
    case auth
    case payment
    case increment
  }

  struct FeatureDisabledError: LockmanError, LocalizedError {
    var errorDescription: String? { "Feature is disabled" }
  }

  struct NotAuthenticatedError: LockmanError, LocalizedError {
    var errorDescription: String? { "Not authenticated" }
  }

  struct InsufficientFundsError: LockmanError, LocalizedError {
    let required: Double
    let available: Double
    var errorDescription: String? {
      "Insufficient funds: Required \(required), Available \(available)"
    }
  }

  // MARK: - Method Chain Tests

  @MainActor
  func testReducerWithLockMethodChain() async {
    // Create a reducer using the method chain API with unified condition evaluation
    let baseReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1  // Execute immediately in reducer
        return .run { send in
          await send(.incrementResponse)
        }

      case .incrementResponse:
        // Additional response processing if needed
        return .none

      case .setEnabled(let value):
        state.isEnabled = value
        return .none

      case .setError(let error):
        state.lastError = error
        return .none

      default:
        return .none
      }
    }
    .lock(
      condition: { state, action in
        // Reducer-level condition: Check if feature is enabled for increment
        switch action {
        case .increment:
          return state.isEnabled ? .success : .cancel(FeatureDisabledError())
        default:
          return .success  // Allow other actions
        }
      },
      boundaryId: CancelID.increment,
      lockFailure: { error, send in
        await send(.setError(error.localizedDescription))
      }
    )

    let store = TestStore(initialState: TestState()) {
      baseReducer
    }

    // Test successful operation
    await store.send(.increment) {
      $0.count = 1
    }
    await store.receive(.incrementResponse)

    // Disable feature and test condition failure
    await store.send(.setEnabled(false)) {
      $0.isEnabled = false
    }

    await store.send(.increment)
    await store.receive(.setError("Feature is disabled")) {
      $0.lastError = "Feature is disabled"
    }
  }

  @MainActor
  func testCombinedConditionsWithMethodChain() async {
    let baseReducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .purchase(let amount):
          return .run { send in
            await send(.purchaseResponse(amount: amount))
          }

        case .purchaseResponse(let amount):
          state.balance -= amount
          return .none

        case .setAuthenticated(let value):
          state.isAuthenticated = value
          return .none

        case .setBalance(let value):
          state.balance = value
          return .none

        case .setError(let error):
          state.lastError = error
          return .none

        default:
          return .none
        }
      },
      condition: { state, action in
        // Reducer-level condition: Check authentication
        switch action {
        case .purchase:
          return state.isAuthenticated ? .success : .cancel(NotAuthenticatedError())
        default:
          return .success
        }
      },
      boundaryId: CancelID.auth,
      lockFailure: { error, send in
        await send(.setError(error.localizedDescription))
      }
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .purchase(let amount):
        // Action-level condition using lock method
        return baseReducer.lock(
          state: state,
          action: action,
          operation: { send in
            // Override the base reducer operation for this specific case
            await send(.purchaseResponse(amount: amount))
          },
          lockFailure: { error, send in
            await send(.setError(error.localizedDescription))
          },
          boundaryId: CancelID.payment,
          lockCondition: { state, _ in
            // Action-level condition: Check funds
            guard state.balance >= amount else {
              return .cancel(
                InsufficientFundsError(
                  required: amount,
                  available: state.balance
                ))
            }
            return .success
          }
        )

      default:
        return baseReducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Test successful purchase
    await store.send(.purchase(amount: 500))
    await store.receive(.purchaseResponse(amount: 500)) {
      $0.balance = 500
    }

    // Test insufficient funds (action-level condition failure)
    await store.send(.purchase(amount: 600))
    await store.receive(.setError("Insufficient funds: Required 600.0, Available 500.0")) {
      $0.lastError = "Insufficient funds: Required 600.0, Available 500.0"
    }

    // Test not authenticated (reducer-level condition failure)
    await store.send(.setAuthenticated(false)) {
      $0.isAuthenticated = false
    }

    await store.send(.purchase(amount: 100))
    await store.receive(.setError("Not authenticated")) {
      $0.lastError = "Not authenticated"
    }
  }

  @MainActor
  func testActionLevelLockWithoutReducerCondition() async {
    // Test using action-level lock without reducer-level conditions
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .none

      case .incrementResponse:
        // Mark operation as completed
        return .none

      default:
        return .none
      }
    }

    // Create a temporary LockmanDynamicConditionReducer for action-level lock
    let lockableReducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        return reducer.reduce(into: &state, action: action)
      },
      condition: { _, _ in .success },  // Always allow at reducer level
      boundaryId: CancelID.auth
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        // Use action-level lock for this specific action
        return lockableReducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.incrementResponse)
          },
          boundaryId: CancelID.increment,
          lockCondition: { state, _ in
            // Action-level condition
            return state.isEnabled ? .success : .cancel(FeatureDisabledError())
          }
        )

      default:
        return lockableReducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Should work normally when enabled
    await store.send(.increment) {
      $0.count = 1
    }
    await store.receive(.incrementResponse)

    // Test with disabled condition
    await store.send(.setEnabled(false)) {
      $0.isEnabled = false
    }

    // This should fail at action level now
    await store.send(.increment) {
      $0.count = 2  // Reducer still executes
    }
    // No incrementResponse should be received due to action-level failure
  }

  @MainActor
  func testReducerWithLockAsPropertyWrapper() async {
    // Test using the method chain API with a Reducer struct
    let store = TestStore(initialState: TestState()) {
      TestFeatureWithCondition()
    }

    // Test the feature works as expected
    await store.send(.increment) {
      $0.count = 1
    }
    await store.receive(.incrementResponse)

    // Test with disabled condition
    await store.send(.setEnabled(false)) {
      $0.isEnabled = false
    }

    await store.send(.increment)
    await store.receive(.setError("Feature is disabled")) {
      $0.lastError = "Feature is disabled"
    }
  }

  @MainActor
  func testCancellableEffectsWithMethodChain() async {
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          return .run { send in
            await send(.setError("Long operation started"))
            try await Task.sleep(nanoseconds: 200_000_000)  // 200ms
            await send(.incrementResponse)
          }
        case .incrementResponse:
          state.count += 1
          return .none
        case .setError(let error):
          state.lastError = error
          return .none
        default:
          return .none
        }
      },
      condition: { _, _ in .success },
      boundaryId: CancelID.increment
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Start long operation
    await store.send(.increment)
    await store.receive(.setError("Long operation started")) {
      $0.lastError = "Long operation started"
    }

    // Start another operation that should cancel the first
    await store.send(.increment)
    await store.receive(.setError("Long operation started")) {
      $0.lastError = "Long operation started"
    }

    // Wait for completion of the second operation
    await store.receive(.incrementResponse) {
      $0.count = 1
    }
  }

  @MainActor
  func testNestedConditionEvaluation() async {
    // Test multiple levels of condition evaluation
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .purchase(let amount):
          return .run { send in
            await send(.purchaseResponse(amount: amount))
          }
        case .purchaseResponse(let amount):
          state.balance -= amount
          return .none
        case .setError(let error):
          state.lastError = error
          return .none
        default:
          return .none
        }
      },
      condition: { state, action in
        // Reducer-level: Authentication check
        switch action {
        case .purchase:
          return state.isAuthenticated ? .success : .cancel(NotAuthenticatedError())
        default:
          return .success
        }
      },
      boundaryId: CancelID.auth,
      lockFailure: { error, send in
        await send(.setError("Auth: \(error.localizedDescription)"))
      }
    )

    let testReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .purchase(let amount):
        // Action-level: Balance check
        return reducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.purchaseResponse(amount: amount))
          },
          lockFailure: { error, send in
            await send(.setError("Balance: \(error.localizedDescription)"))
          },
          boundaryId: CancelID.payment,
          lockCondition: { state, _ in
            guard state.balance >= amount else {
              return .cancel(InsufficientFundsError(required: amount, available: state.balance))
            }
            return .success
          }
        )
      default:
        return reducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      testReducer
    }

    // Test auth failure (reducer-level)
    await store.send(.setAuthenticated(false)) {
      $0.isAuthenticated = false
    }

    await store.send(.purchase(amount: 100))
    await store.receive(.setError("Auth: Not authenticated")) {
      $0.lastError = "Auth: Not authenticated"
    }

    // Test balance failure (action-level)
    await store.send(.setAuthenticated(true)) {
      $0.isAuthenticated = true
    }

    await store.send(.purchase(amount: 2000))
    await store.receive(.setError("Balance: Insufficient funds: Required 2000.0, Available 1000.0"))
    {
      $0.lastError = "Balance: Insufficient funds: Required 2000.0, Available 1000.0"
    }

    // Test success (both conditions pass)
    await store.send(.purchase(amount: 500))
    await store.receive(.purchaseResponse(amount: 500)) {
      $0.balance = 500
    }
  }
}

// MARK: - Test Feature for Property Wrapper Test

@Reducer
struct TestFeatureWithCondition {
  typealias State = LockmanDynamicConditionReducerMethodChainTests.TestState
  typealias Action = LockmanDynamicConditionReducerMethodChainTests.TestAction

  var body: some ReducerOf<Self> {
    Reduce<State, Action> { state, action in
      switch action {
      case .increment:
        state.count += 1
        return .run { send in
          await send(.incrementResponse)
        }

      case .incrementResponse:
        return .none

      case .setEnabled(let value):
        state.isEnabled = value
        return .none

      case .setError(let error):
        state.lastError = error
        return .none

      default:
        return .none
      }
    }
    .lock(
      condition: { state, action in
        switch action {
        case .increment:
          return state.isEnabled
            ? .success
            : .cancel(LockmanDynamicConditionReducerMethodChainTests.FeatureDisabledError())
        default:
          return .success
        }
      },
      boundaryId: LockmanDynamicConditionReducerMethodChainTests.CancelID.increment,
      lockFailure: { error, send in
        await send(.setError(error.localizedDescription))
      }
    )
  }
}
