import ComposableArchitecture
import Lockman
import XCTest

@testable import Lockman

/// Tests for Reducer.lock method chain API and LockmanDynamicConditionReducer
final class LockmanDynamicConditionReducerMethodChainTests: XCTestCase {

  override func setUp() {
    super.setUp()
    _ = LockmanManager.container
    do {
      try LockmanManager.container.register(LockmanDynamicConditionStrategy.shared)
    } catch {
      // Already registered
    }
  }

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

  struct IncrementAction: LockmanSingleExecutionAction {
    var actionName: String { "increment" }
    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }
  }

  struct PurchaseAction: LockmanSingleExecutionAction {
    var actionName: String { "purchase" }
    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }
  }

  enum CancelID: LockmanBoundaryId {
    case test
    case payment
  }

  struct FeatureDisabledError: LockmanError {
    var errorDescription: String? { "Feature is disabled" }
  }

  struct NotAuthenticatedError: LockmanError {
    var errorDescription: String? { "Not authenticated" }
  }

  struct InsufficientFundsError: LockmanError {
    let required: Double
    let available: Double
    var errorDescription: String? {
      "Insufficient funds: Required \(required), Available \(available)"
    }
  }

  // MARK: - Method Chain Tests

  @MainActor
  func testReducerWithLockMethodChain() async {
    // Create a reducer using the method chain API
    let baseReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        // Here we create a temporary LockmanDynamicConditionReducer to use dynamic conditions
        let tempReducer = Reduce<TestState, TestAction> { _, _ in .none }
          .lock { state, _ in
            guard state.isEnabled else {
              return .cancel(FeatureDisabledError())
            }
            return .success
          }

        return tempReducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.incrementResponse)
          },
          lockFailure: { error, send in
            await send(.setError(error.localizedDescription))
          },
          lockAction: IncrementAction(),
          boundaryId: CancelID.test
        )

      case .incrementResponse:
        state.count += 1
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

    let store = TestStore(initialState: TestState()) {
      baseReducer
    }

    // Test successful operation
    await store.send(.increment)
    await store.receive(.incrementResponse) {
      $0.count = 1
    }

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
    let baseReducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .purchase(let amount):
        // Create reducer with reducer-level condition
        let tempReducer = Reduce<TestState, TestAction> { _, _ in .none }
          .lock { state, _ in
            // Reducer-level condition
            guard state.isAuthenticated else {
              return .cancel(NotAuthenticatedError())
            }
            return .success
          }

        // Add action-level condition
        return tempReducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.purchaseResponse(amount: amount))
          },
          lockFailure: { error, send in
            await send(.setError(error.localizedDescription))
          },
          lockAction: PurchaseAction(),
          boundaryId: CancelID.payment,
          actionLockCondition: { state, _ in
            // Action-level condition
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
    }

    let store = TestStore(initialState: TestState()) {
      baseReducer
    }

    // Test successful purchase
    await store.send(.purchase(amount: 500))
    await store.receive(.purchaseResponse(amount: 500)) {
      $0.balance = 500
    }

    // Test insufficient funds (action-level condition)
    await store.send(.purchase(amount: 600))
    await store.receive(.setError("Insufficient funds: Required 600.0, Available 500.0")) {
      $0.lastError = "Insufficient funds: Required 600.0, Available 500.0"
    }

    // Test not authenticated (reducer-level condition)
    await store.send(.setAuthenticated(false)) {
      $0.isAuthenticated = false
    }

    await store.send(.purchase(amount: 100))
    await store.receive(.setError("Not authenticated")) {
      $0.lastError = "Not authenticated"
    }
  }

  @MainActor
  func testLockWithoutCondition() async {
    // Test using lock without any reducer-level condition
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        // Create reducer without condition
        let tempReducer = LockmanDynamicConditionReducer<TestState, TestAction>({ _, _ in .none })

        return tempReducer.lock(
          state: state,
          action: action,
          operation: { send in
            await send(.incrementResponse)
          },
          lockAction: IncrementAction(),
          boundaryId: CancelID.test
        )

      case .incrementResponse:
        state.count += 1
        return .none

      default:
        return .none
      }
    }

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Should work normally without reducer-level condition
    await store.send(.increment)
    await store.receive(.incrementResponse) {
      $0.count = 1
    }
  }

  @MainActor
  func testReducerWithLockAsPropertyWrapper() async {
    // Test using the method chain API with a Reducer struct
    let store = TestStore(initialState: TestState()) {
      TestFeatureWithCondition()
    }

    // Test the feature works as expected
    await store.send(.increment)
    await store.receive(.incrementResponse) {
      $0.count = 1
    }

    // Test with disabled condition
    await store.send(.setEnabled(false)) {
      $0.isEnabled = false
    }

    await store.send(.increment)
    await store.receive(.setError("Feature is disabled")) {
      $0.lastError = "Feature is disabled"
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
        // Use inline lock
        return Reduce<State, Action> { _, _ in .none }
          .lock { state, _ in
            guard state.isEnabled else {
              return .cancel(LockmanDynamicConditionReducerMethodChainTests.FeatureDisabledError())
            }
            return .success
          }
          .lock(
            state: state,
            action: action,
            operation: { send in
              await send(.incrementResponse)
            },
            lockFailure: { error, send in
              await send(.setError(error.localizedDescription))
            },
            lockAction: LockmanDynamicConditionReducerMethodChainTests.IncrementAction(),
            boundaryId: LockmanDynamicConditionReducerMethodChainTests.CancelID.test
          )

      case .incrementResponse:
        state.count += 1
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
  }
}
