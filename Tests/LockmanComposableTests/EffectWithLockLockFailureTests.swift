import ComposableArchitecture
import XCTest

@testable import Lockman

/// Tests for the lockFailure handler in withLock manual unlock variant
final class EffectWithLockLockFailureTests: XCTestCase {

  struct TestAction: LockmanSingleExecutionAction, Equatable {
    var actionName: LockmanActionId = "test-action"

    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }

    var strategyId: LockmanStrategyId {
      .singleExecution
    }
  }

  @Reducer
  struct TestReducer {
    @ObservableState
    struct State: Equatable {
      var lockFailureErrorMessage: String?
      var operationErrorMessage: String?
      var operationCompleted = false
      var unlockCalled = false
    }

    enum Action: Equatable {
      case testManualUnlockWithLockFailure
      case testManualUnlockWithOperationError
      case lockFailureOccurred(String)
      case operationErrorOccurred(String)
      case operationCompleted
      case unlockCalled
    }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .testManualUnlockWithLockFailure:
          // First lock the resource
          let lockAction = TestAction()
          let lockInfo = lockAction.lockmanInfo
          let strategy = LockmanSingleExecutionStrategy.shared

          // Manually lock it first to cause failure on second attempt
          strategy.lock(id: TestBoundaryId.testBoundary, info: lockInfo)

          return .withLock(
            operation: { send, unlock in
              // This should never be called
              defer { unlock() }
              await send(.operationCompleted)
            },
            catch: { _, send, unlock in
              // This should never be called for lock failure
              unlock()
              await send(.operationErrorOccurred("Should not be called"))
            },
            lockFailure: { error, send in
              // This should be called with lock acquisition error
              await send(.lockFailureOccurred(error.localizedDescription))
            },
            action: lockAction,
            cancelID: TestBoundaryId.testBoundary
          )

        case .testManualUnlockWithOperationError:
          return .withLock(
            operation: { send, unlock in
              defer {
                unlock()
              }
              await send(.unlockCalled)
              // Simulate operation error
              struct TestError: Error {}
              throw TestError()
            },
            catch: { error, send, unlock in
              // This should be called for operation errors
              await send(.operationErrorOccurred(String(describing: error)))
            },
            lockFailure: { _, send in
              // This should not be called
              await send(.lockFailureOccurred("Should not be called"))
            },
            action: TestAction(),
            cancelID: TestBoundaryId.testBoundary2
          )

        case let .lockFailureOccurred(errorMessage):
          state.lockFailureErrorMessage = errorMessage
          return .none

        case let .operationErrorOccurred(errorMessage):
          state.operationErrorMessage = errorMessage
          return .none

        case .operationCompleted:
          state.operationCompleted = true
          return .none

        case .unlockCalled:
          state.unlockCalled = true
          return .none
        }
      }
    }
  }

  private struct TestError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
  }

  private enum TestBoundaryId: LockmanBoundaryId {
    case testBoundary
    case testBoundary2
  }

  @MainActor
  func testLockFailureHandlerIsCalledWhenLockAcquisitionFails() async throws {
    // Register strategy if not already registered
    if !Lockman.container.isRegistered(LockmanSingleExecutionStrategy.self) {
      try Lockman.container.register(LockmanSingleExecutionStrategy.shared)
    }
    defer { Lockman.container.cleanUp() }

    let store = TestStore(initialState: TestReducer.State()) {
      TestReducer()
    }

    await store.send(.testManualUnlockWithLockFailure)

    // Wait for async handler
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    await store.receive(
      .lockFailureOccurred(
        "Cannot acquire lock: boundary 'testBoundary' already has an active lock.")
    ) {
      $0.lockFailureErrorMessage =
        "Cannot acquire lock: boundary 'testBoundary' already has an active lock."
    }

    // Verify operation was not called
    XCTAssertFalse(store.state.operationCompleted)
    XCTAssertNil(store.state.operationErrorMessage)

    // Clean up
    let strategy = LockmanSingleExecutionStrategy.shared
    strategy.cleanUp()
  }

  @MainActor
  func testCatchHandlerIsCalledForOperationErrors() async throws {
    // Register strategy if not already registered
    if !Lockman.container.isRegistered(LockmanSingleExecutionStrategy.self) {
      try Lockman.container.register(LockmanSingleExecutionStrategy.shared)
    }
    defer { Lockman.container.cleanUp() }

    let store = TestStore(initialState: TestReducer.State()) {
      TestReducer()
    }

    await store.send(.testManualUnlockWithOperationError)

    // Wait for async operation
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    await store.receive(.unlockCalled) {
      $0.unlockCalled = true
    }

    await store.receive(.operationErrorOccurred("TestError()")) {
      $0.operationErrorMessage = "TestError()"
    }

    // Verify lock failure handler was not called
    XCTAssertNil(store.state.lockFailureErrorMessage)
  }

  @Reducer
  struct SimpleReducer {
    struct State: Equatable {
      var completed = false
    }

    enum Action: Equatable {
      case runWithoutHandlers
      case completed
    }

    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .runWithoutHandlers:
          return .withLock(
            operation: { send, unlock in
              defer { unlock() }
              await send(.completed)
            },
            // No catch handler
            // No lockFailure handler
            action: EffectWithLockLockFailureTests.TestAction(),
            cancelID: EffectWithLockLockFailureTests.TestBoundaryId.testBoundary
          )

        case .completed:
          state.completed = true
          return .none
        }
      }
    }
  }

  @MainActor
  func testBothHandlersAreOptional() async throws {
    // Register strategy if not already registered
    if !Lockman.container.isRegistered(LockmanSingleExecutionStrategy.self) {
      try Lockman.container.register(LockmanSingleExecutionStrategy.shared)
    }
    defer { Lockman.container.cleanUp() }

    let store = TestStore(initialState: SimpleReducer.State()) {
      SimpleReducer()
    }

    await store.send(.runWithoutHandlers)

    // Wait for async operation
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    await store.receive(.completed) {
      $0.completed = true
    }
  }
}
