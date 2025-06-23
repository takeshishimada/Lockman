import ComposableArchitecture
import LockmanCore
import XCTest

@testable import LockmanComposable

/// Integration tests for ReduceWithLock to ensure proper lock management
final class ReduceWithLockIntegrationTests: XCTestCase {

  // MARK: - Test Types

  struct TestState: Equatable, Sendable {
    var count: Int = 0
    var lockAcquired: Bool = false
    var conditionChecked: Bool = false
  }

  enum TestAction: Equatable, Sendable {
    case increment
    case setLockAcquired(Bool)
    case setConditionChecked(Bool)
  }

  struct TestLockAction: LockmanSingleExecutionAction {
    var actionName: String { "test" }
    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }
  }

  override func setUp() {
    super.setUp()
    // Register strategies
    _ = Lockman.container
    do {
      try Lockman.container.register(LockmanDynamicConditionStrategy.shared)
    } catch {
      // Already registered
    }
  }

  override func tearDown() {
    super.tearDown()
    // Clean up all locks
    Lockman.cleanup.all()
  }

  // MARK: - Lock Lifecycle Tests

  @MainActor
  func testDynamicConditionLocksAreProperlyAcquiredAndReleased() async {
    // Get strategy reference
    let dynamicStrategy = LockmanDynamicConditionStrategy.shared
    let singleExecutionStrategy = LockmanSingleExecutionStrategy.shared
    let cancelID = TestLockAction().lockmanInfo.actionId

    // Create a class to track lock states
    final class LockTracker: @unchecked Sendable {
      var step1LockAcquired = false
      var step2LockAcquired = false
      var step3LockAcquired = false
    }
    let lockTracker = LockTracker()

    // Create reducer with both conditions
    // Note: We need to create the reducer in a way that allows us to call withLock on it
    let baseReducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          return .none
        case .setLockAcquired(let value):
          state.lockAcquired = value
          return .none
        case .setConditionChecked(let value):
          state.conditionChecked = value
          return .none
        }
      },
      lockCondition: { state, _ in
        // Reducer-level condition
        return .success
      }
    )

    // Wrap in another reducer that uses withLock from the base reducer
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1  // Execute the increment logic
        return baseReducer.withLock(
          state: state,
          action: action,
          unlockOption: .immediate,
          operation: { send in
            // Check lock states during operation
            lockTracker.step1LockAcquired =
              dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)]?.contains {
                $0.actionId == cancelID
              } ?? false
            lockTracker.step2LockAcquired = lockTracker.step1LockAcquired  // Both use same strategy
            lockTracker.step3LockAcquired =
              singleExecutionStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)]?.contains {
                $0.actionId == cancelID
              } ?? false

            await send(.setLockAcquired(true))
          },
          lockAction: TestLockAction(),
          cancelID: cancelID,
          lockCondition: { _, _ in
            // Action-level condition
            return .success
          }
        )
      default:
        return baseReducer.reduce(into: &state, action: action)
      }
    }

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Execute the action - this will trigger the withLock effect
    await store.send(.increment) {
      $0.count = 1
    }

    // Receive the action from the withLock operation
    await store.receive(.setLockAcquired(true)) {
      $0.lockAcquired = true
    }

    // Wait a bit to ensure cleanup
    try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    // Check locks were released after operation
    let step1LockReleased =
      !(dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)]?.contains {
        $0.actionId == cancelID
      } ?? false)
    let step2LockReleased = step1LockReleased
    let step3LockReleased =
      !(singleExecutionStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)]?.contains {
        $0.actionId == cancelID
      } ?? false)

    // Verify lock lifecycle
    XCTAssertTrue(lockTracker.step1LockAcquired, "Step 1 dynamic condition lock should be acquired")
    XCTAssertTrue(lockTracker.step2LockAcquired, "Step 2 dynamic condition lock should be acquired")
    XCTAssertTrue(lockTracker.step3LockAcquired, "Step 3 single execution lock should be acquired")

    XCTAssertTrue(step1LockReleased, "Step 1 lock should be released after operation")
    XCTAssertTrue(step2LockReleased, "Step 2 lock should be released after operation")
    XCTAssertTrue(step3LockReleased, "Step 3 lock should be released after operation")
  }

  @MainActor
  func testMultipleDynamicConditionLocksWithSameActionId() async {
    let dynamicStrategy = LockmanDynamicConditionStrategy.shared
    let actionId = "testAction"
    let boundary = TestLockAction().lockmanInfo.actionId

    // Create multiple dynamic condition infos with same actionId
    let info1 = LockmanDynamicConditionInfo(
      actionId: actionId,
      condition: { .success }
    )
    let info2 = LockmanDynamicConditionInfo(
      actionId: actionId,
      condition: { .success }
    )

    // Acquire both locks
    dynamicStrategy.lock(id: boundary, info: info1)
    dynamicStrategy.lock(id: boundary, info: info2)

    // Verify both locks exist (different uniqueIds)
    let locks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(boundary)] ?? []
    let locksWithActionId = locks.filter { $0.actionId == actionId }
    XCTAssertEqual(locksWithActionId.count, 2, "Should have 2 locks with same actionId")

    // Unlock removes ALL locks with same actionId
    dynamicStrategy.unlock(id: boundary, info: info1)

    // Verify all locks with the actionId are removed
    let remainingLocks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(boundary)] ?? []
    let remainingWithActionId = remainingLocks.filter { $0.actionId == actionId }
    XCTAssertEqual(remainingWithActionId.count, 0, "All locks with same actionId should be removed")

    // Verify all locks are released
    let finalLocks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(boundary)] ?? []
    XCTAssertTrue(finalLocks.isEmpty, "All locks should be released")
  }

  @MainActor
  func testDynamicConditionFailureDoesNotAcquireLock() async {
    let dynamicStrategy = LockmanDynamicConditionStrategy.shared
    let cancelID = TestLockAction().lockmanInfo.actionId

    // Create a class to track operation execution
    final class ExecutionTracker: @unchecked Sendable {
      var operationExecuted = false
      var errorHandlerCalled = false
    }
    let tracker = ExecutionTracker()

    // Create reducer
    let reducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          let tempReducer = ReduceWithLock<TestState, TestAction>(
            { _, _ in .none }
          )
          return tempReducer.withLock(
            state: state,
            action: action,
            operation: { send in
              // This should not be called
              tracker.operationExecuted = true
              await send(.setLockAcquired(true))
            },
            catch: { error, send in
              tracker.errorHandlerCalled = true
            },
            lockAction: TestLockAction(),
            cancelID: TestLockAction().lockmanInfo.actionId,
            lockCondition: { _, _ in
              // Failing condition
              return .failure(
                LockmanDynamicConditionError.conditionNotMet(
                  actionId: "test",
                  hint: "Test failure"
                ))
            }
          )
        case .setLockAcquired(let value):
          state.lockAcquired = value
          return .none
        default:
          return .none
        }
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    store.exhaustivity = .off

    // Execute the action
    await store.send(.increment) {
      $0.count = 1
    }

    // Wait a bit to ensure no async operations are pending
    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

    // Verify operation was not executed
    XCTAssertFalse(tracker.operationExecuted, "Operation should not execute when condition fails")
    XCTAssertFalse(
      tracker.errorHandlerCalled,
      "Error handler should not be called for dynamic condition failures")

    // Verify no locks were acquired
    let locks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)] ?? []
    XCTAssertTrue(locks.isEmpty, "No locks should be acquired when condition fails")
  }

  // MARK: - Manual Unlock Tests

  @MainActor
  func testManualUnlockVersionProvidesUnlockToken() async {
    // Track unlock execution
    final class UnlockTracker: @unchecked Sendable {
      var unlockTokenReceived = false
      var unlockCalled = false
    }
    let tracker = UnlockTracker()

    let reducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          // Test manual unlock version
          let tempReducer = ReduceWithLock<TestState, TestAction>(
            { _, _ in .none }
          )
          return tempReducer.withLock(
            state: state,
            action: action,
            operation: { send, unlock in
              tracker.unlockTokenReceived = true
              // Simulate some async work
              try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
              // Manually unlock
              unlock()
              tracker.unlockCalled = true
              await send(.setLockAcquired(true))
            },
            lockAction: TestLockAction(),
            cancelID: TestLockAction().lockmanInfo.actionId
          )
        case .setLockAcquired(let value):
          state.lockAcquired = value
          return .none
        default:
          return .none
        }
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    await store.send(.increment) {
      $0.count = 1
    }

    await store.receive(.setLockAcquired(true)) {
      $0.lockAcquired = true
    }

    XCTAssertTrue(tracker.unlockTokenReceived, "Unlock token should be provided to operation")
    XCTAssertTrue(tracker.unlockCalled, "Unlock should be called manually")
  }

  @MainActor
  func testManualUnlockVersionWithErrorHandler() async {
    final class ErrorTracker: @unchecked Sendable {
      var errorHandlerCalled = false
      var unlockTokenInHandler = false
    }
    let tracker = ErrorTracker()

    struct TestError: Error {}

    let reducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          // Test error handling with unlock token
          let tempReducer = ReduceWithLock<TestState, TestAction>(
            { _, _ in .none }
          )
          return tempReducer.withLock(
            state: state,
            action: action,
            operation: { send, unlock in
              // Throw an error to trigger catch handler
              throw TestError()
            },
            catch: { error, send, unlock in
              tracker.errorHandlerCalled = true
              tracker.unlockTokenInHandler = true
              // Important: Must call unlock in error handler
              unlock()
            },
            lockAction: TestLockAction(),
            cancelID: TestLockAction().lockmanInfo.actionId
          )
        default:
          return .none
        }
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    await store.send(.increment) {
      $0.count = 1
    }

    // Wait for error handler to complete
    try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    XCTAssertTrue(tracker.errorHandlerCalled, "Error handler should be called")
    XCTAssertTrue(tracker.unlockTokenInHandler, "Unlock token should be available in error handler")
  }

  @MainActor
  func testManualUnlockWithDynamicConditions() async {
    final class ConditionTracker: @unchecked Sendable {
      var conditionEvaluated = false
      var operationExecuted = false
      var unlockExecuted = false
    }
    let tracker = ConditionTracker()

    let reducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          // Test manual unlock with both reducer and action level conditions
          let tempReducer = ReduceWithLock<TestState, TestAction>(
            { _, _ in .none },
            lockCondition: { _, _ in
              tracker.conditionEvaluated = true
              return .success
            }
          )
          return tempReducer.withLock(
            state: state,
            action: action,
            operation: { send, unlock in
              tracker.operationExecuted = true
              // Manually control when to unlock
              try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms
              unlock()
              tracker.unlockExecuted = true
              await send(.setLockAcquired(true))
            },
            lockAction: TestLockAction(),
            cancelID: TestLockAction().lockmanInfo.actionId,
            lockCondition: { _, _ in
              // Action-level condition
              return .success
            }
          )
        case .setLockAcquired(let value):
          state.lockAcquired = value
          return .none
        default:
          return .none
        }
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    await store.send(.increment) {
      $0.count = 1
    }

    await store.receive(.setLockAcquired(true)) {
      $0.lockAcquired = true
    }

    XCTAssertTrue(tracker.conditionEvaluated, "Reducer-level condition should be evaluated")
    XCTAssertTrue(tracker.operationExecuted, "Operation should execute after conditions pass")
    XCTAssertTrue(tracker.unlockExecuted, "Manual unlock should be executed")
  }

  // MARK: - Lock Cleanup Tests

  @MainActor
  func testDynamicConditionLocksAreCleanedUpOnFailure() async {
    let dynamicStrategy = LockmanDynamicConditionStrategy.shared
    let singleExecutionStrategy = LockmanSingleExecutionStrategy.shared
    let cancelID = TestLockAction().lockmanInfo.actionId

    final class EvaluationTracker: @unchecked Sendable {
      var step1Evaluated = false
      var step2Evaluated = false
    }
    let tracker = EvaluationTracker()

    // Create another lock to simulate step 3 failing
    singleExecutionStrategy.lock(
      id: cancelID,
      info: LockmanSingleExecutionInfo(actionId: cancelID, mode: .boundary)
    )

    let reducer = ReduceWithLock<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          let tempReducer = ReduceWithLock<TestState, TestAction>(
            { _, _ in .none },
            lockCondition: { _, _ in
              tracker.step1Evaluated = true
              return .success  // Step 1 passes
            }
          )
          return tempReducer.withLock(
            state: state,
            action: action,
            operation: { send in
              // This should not be called
              XCTFail("Operation should not execute when step 3 fails")
            },
            lockAction: TestLockAction(),
            cancelID: TestLockAction().lockmanInfo.actionId,
            lockCondition: { _, _ in
              tracker.step2Evaluated = true
              return .success  // Step 2 also passes
            }
          )
        default:
          return .none
        }
      }
    )

    let store = TestStore(initialState: TestState()) {
      reducer
    }

    // Execute the action
    await store.send(.increment) {
      $0.count = 1
    }

    // Wait a bit to ensure cleanup
    try? await Task.sleep(nanoseconds: 50_000_000)  // 50ms

    // Verify steps were evaluated
    XCTAssertTrue(tracker.step1Evaluated, "Step 1 should be evaluated")
    XCTAssertTrue(tracker.step2Evaluated, "Step 2 should be evaluated")

    // Verify all dynamic condition locks were cleaned up
    let dynamicLocks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(cancelID)] ?? []
    XCTAssertTrue(
      dynamicLocks.isEmpty, "All dynamic condition locks should be cleaned up when step 3 fails")

    // Clean up the test lock
    singleExecutionStrategy.unlock(
      id: cancelID,
      info: LockmanSingleExecutionInfo(actionId: cancelID, mode: .boundary)
    )
  }

}
