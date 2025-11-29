import XCTest

@testable import Lockman

final class LockmanManagerGenericLockTests: XCTestCase {
  override func setUp() {
    super.setUp()
    LockmanManager.config.reset()
  }

  override func tearDown() {
    LockmanManager.cleanup.all()
    super.tearDown()
  }

  // MARK: - Success Tests

  func testGenericLock_Success_CallsOnSuccessWithUnlockToken() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test
      var unlockCalled = false

      let result: String = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { receivedAction, unlock in
          XCTAssertEqual(receivedAction.actionName, action.actionName)
          unlock()
          unlockCalled = true
          return "success"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in
          XCTFail("Should not call onSuccessWithPrecedingCancellation")
          return "failure"
        },
        onCancel: { _, _ in
          XCTFail("Should not call onCancel")
          return "failure"
        },
        onError: { _, _ in
          XCTFail("Should not call onError")
          return "failure"
        }
      )

      XCTAssertEqual(result, "success")
      XCTAssertTrue(unlockCalled)
    }
  }

  func testGenericLock_Success_WithExplicitUnlockOption() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.increment
      let boundaryId = TestBoundaryId.test
      var unlockCalled = false

      let result: Int = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        onSuccess: { _, unlock in
          unlock()
          unlockCalled = true
          return 42
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in
          return 0
        },
        onCancel: { _, _ in
          return 0
        },
        onError: { _, _ in
          return 0
        }
      )

      XCTAssertEqual(result, 42)
      XCTAssertTrue(unlockCalled)
    }
  }

  // MARK: - Cancel Tests

  func testGenericLock_Cancel_CallsOnCancel() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test  // Use same action to trigger conflict
      let boundaryId = TestBoundaryId.test

      // First lock acquisition - don't unlock to simulate ongoing operation
      let firstResult: Bool = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, unlock in
          // Don't unlock to keep the lock active
          return true
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in false },
        onCancel: { _, _ in false },
        onError: { _, _ in false }
      )
      XCTAssertTrue(firstResult)

      // Second lock acquisition with same action should be cancelled
      var cancelCalled = false
      let result: String = LockmanManager.lock(
        action: action,  // Same action to trigger conflict
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, _ in
          XCTFail("Should not call onSuccess")
          return "failure"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in
          XCTFail("Should not call onSuccessWithPrecedingCancellation")
          return "failure"
        },
        onCancel: { receivedAction, error in
          XCTAssertEqual(receivedAction.actionName, action.actionName)
          XCTAssertNotNil(error)
          cancelCalled = true
          return "cancelled"
        },
        onError: { _, _ in
          XCTFail("Should not call onError")
          return "failure"
        }
      )

      XCTAssertEqual(result, "cancelled")
      XCTAssertTrue(cancelCalled)
    }
  }

  // MARK: - Error Tests

  func testGenericLock_StrategyNotRegistered_CallsOnError() async throws {
    let container = LockmanStrategyContainer()
    // Don't register any strategy

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test
      var errorCalled = false

      let result: String = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, _ in
          XCTFail("Should not call onSuccess")
          return "failure"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in
          XCTFail("Should not call onSuccessWithPrecedingCancellation")
          return "failure"
        },
        onCancel: { _, _ in
          XCTFail("Should not call onCancel")
          return "failure"
        },
        onError: { receivedAction, error in
          XCTAssertEqual(receivedAction.actionName, action.actionName)
          XCTAssertTrue(error is LockmanRegistrationError)
          errorCalled = true
          return "error"
        }
      )

      XCTAssertEqual(result, "error")
      XCTAssertTrue(errorCalled)
    }
  }

  // MARK: - Type Safety Tests

  func testGenericLock_DifferentReturnTypes_Success() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test

      // Test with Bool return type
      let boolResult: Bool = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, unlock in
          unlock()
          return true
        },
        onSuccessWithPrecedingCancellation: { _, _, unlock in
          unlock()
          return false
        },
        onCancel: { _, _ in false },
        onError: { _, _ in false }
      )
      XCTAssertTrue(boolResult)

      // Test with Int return type
      let intResult: Int = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, unlock in
          unlock()
          return 123
        },
        onSuccessWithPrecedingCancellation: { _, _, unlock in
          unlock()
          return 0
        },
        onCancel: { _, _ in 0 },
        onError: { _, _ in 0 }
      )
      XCTAssertEqual(intResult, 123)

      // Test with custom struct return type
      struct TestResult {
        let value: String
        let count: Int
      }

      let customResult: TestResult = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, unlock in
          unlock()
          return TestResult(value: "test", count: 42)
        },
        onSuccessWithPrecedingCancellation: { _, _, unlock in
          unlock()
          return TestResult(value: "cancelled", count: 0)
        },
        onCancel: { _, _ in TestResult(value: "cancel", count: -1) },
        onError: { _, _ in TestResult(value: "error", count: -2) }
      )

      XCTAssertEqual(customResult.value, "test")
      XCTAssertEqual(customResult.count, 42)
    }
  }

  // MARK: - Unlock Token Behavior Tests

  func testGenericLock_UnlockToken_IdempotentCalls() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test
      var unlockCallCount = 0

      let result: String = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,
        onSuccess: { _, unlock in
          // Call unlock multiple times - should be safe
          unlock()
          unlockCallCount += 1
          unlock()
          unlockCallCount += 1
          unlock()
          unlockCallCount += 1
          return "success"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in "failure" },
        onCancel: { _, _ in "failure" },
        onError: { _, _ in "failure" }
      )

      XCTAssertEqual(result, "success")
      XCTAssertEqual(unlockCallCount, 3)  // All calls should be recorded, even if unlock is idempotent internally
    }
  }

  // MARK: - Action Default UnlockOption Tests

  func testGenericLock_UsesActionDefaultUnlockOption_WhenNilProvided() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test

      let result: String = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: nil,  // Should use action's default
        onSuccess: { receivedAction, unlock in
          // The action's unlockOption should be used
          XCTAssertEqual(receivedAction.unlockOption, .immediate)
          unlock()
          return "success"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in "failure" },
        onCancel: { _, _ in "failure" },
        onError: { _, _ in "failure" }
      )

      XCTAssertEqual(result, "success")
    }
  }

  func testGenericLock_OverridesActionDefaultUnlockOption_WhenExplicitProvided() async throws {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let action = SharedTestAction.test
      let boundaryId = TestBoundaryId.test

      let result: String = LockmanManager.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: .delayed(0.1),  // Should override action's default
        onSuccess: { receivedAction, unlock in
          // The original action's unlockOption should be preserved
          XCTAssertEqual(receivedAction.unlockOption, .immediate)
          unlock()
          return "success"
        },
        onSuccessWithPrecedingCancellation: { _, _, _ in "failure" },
        onCancel: { _, _ in "failure" },
        onError: { _, _ in "failure" }
      )

      XCTAssertEqual(result, "success")
    }
  }
}
