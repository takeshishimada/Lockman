import ComposableArchitecture
import Lockman
import XCTest

@testable import Lockman

// Test-specific error for dynamic condition tests
private struct ComposableTestDynamicConditionError: LockmanError {
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

/// Integration tests for LockmanDynamicConditionReducer to ensure proper lock management
final class LockmanDynamicConditionReducerIntegrationTests: XCTestCase {

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
    _ = LockmanManager.container
    do {
      try LockmanManager.container.register(LockmanDynamicConditionStrategy.shared)
    } catch {
      // Already registered
    }
  }

  override func tearDown() {
    super.tearDown()
    // Clean up all locks
    LockmanManager.cleanup.all()
  }

  // MARK: - Lock Lifecycle Tests

  @MainActor
  func disabled_testDynamicConditionLocksAreProperlyAcquiredAndReleased() async {
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
    // Note: We need to create the reducer in a way that allows us to call lock on it
    let baseReducer = LockmanDynamicConditionReducer<TestState, TestAction>(
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

    // Wrap in another reducer that uses lock from the base reducer
    let reducer = Reduce<TestState, TestAction> { state, action in
      switch action {
      case .increment:
        state.count += 1  // Execute the increment logic
        return baseReducer.lock(
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
          boundaryId: cancelID,
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

    // Execute the action - this will trigger the lock effect
    await store.send(.increment) {
      $0.count = 1
    }

    // Receive the action from the lock operation
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
    dynamicStrategy.lock(boundaryId: boundary, info: info1)
    dynamicStrategy.lock(boundaryId: boundary, info: info2)

    // Verify both locks exist (different uniqueIds)
    let locks = dynamicStrategy.getCurrentLocks()[AnyLockmanBoundaryId(boundary)] ?? []
    let locksWithActionId = locks.filter { $0.actionId == actionId }
    XCTAssertEqual(locksWithActionId.count, 2, "Should have 2 locks with same actionId")

    // Unlock removes ALL locks with same actionId
    dynamicStrategy.unlock(boundaryId: boundary, info: info1)

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
    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          let tempReducer = LockmanDynamicConditionReducer<TestState, TestAction>(
            { _, _ in .none }
          )
          return tempReducer.lock(
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
            boundaryId: TestLockAction().lockmanInfo.actionId,
            lockCondition: { _, _ in
              // Failing condition
              return .cancel(
                ComposableTestDynamicConditionError.conditionNotMet(
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

  // MARK: - Lock Cleanup Tests

  @MainActor
  func disabled_testDynamicConditionLocksAreCleanedUpOnFailure() async {
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
      boundaryId: cancelID,
      info: LockmanSingleExecutionInfo(actionId: cancelID, mode: .boundary)
    )

    let reducer = LockmanDynamicConditionReducer<TestState, TestAction>(
      { state, action in
        switch action {
        case .increment:
          state.count += 1
          let tempReducer = LockmanDynamicConditionReducer<TestState, TestAction>(
            { _, _ in .none },
            lockCondition: { _, _ in
              tracker.step1Evaluated = true
              return .success  // Step 1 passes
            }
          )
          return tempReducer.lock(
            state: state,
            action: action,
            operation: { send in
              // This should not be called
              XCTFail("Operation should not execute when step 3 fails")
            },
            lockAction: TestLockAction(),
            boundaryId: TestLockAction().lockmanInfo.actionId,
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
      boundaryId: cancelID,
      info: LockmanSingleExecutionInfo(actionId: cancelID, mode: .boundary)
    )
  }

}
