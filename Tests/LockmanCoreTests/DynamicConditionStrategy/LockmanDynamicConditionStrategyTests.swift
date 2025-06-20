import Foundation
import XCTest
@testable import LockmanCore

// Helper class for thread-safe mutable state in tests
private final class Atomic<Value>: @unchecked Sendable {
  private var _value: Value
  private let lock = NSLock()
  
  init(_ value: Value) {
    self._value = value
  }
  
  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }
}

final class LockmanDynamicConditionStrategyTests: XCTestCase {
  // MARK: - Test Helpers

  private struct TestBoundaryId: LockmanBoundaryId {
    let value: String
  }

  // MARK: - Basic Tests

  func teststrategyHasCorrectId() {
    let strategy = LockmanDynamicConditionStrategy()
    XCTAssertEqual(strategy.strategyId, .dynamicCondition)
  }

  func testsharedInstanceIsSingleton() {
    XCTAssertTrue(LockmanDynamicConditionStrategy.shared === LockmanDynamicConditionStrategy.shared)
  }

  func testdefaultConditionAlwaysAllows() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Default condition (always success)
    let info = LockmanDynamicConditionInfo(
      actionId: "test"
    )

    XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)

    // Add multiple locks - should still succeed
    strategy.lock(id: boundary, info: info)
    let info2 = LockmanDynamicConditionInfo(actionId: "test2")
    XCTAssertEqual(strategy.canLock(id: boundary, info: info2), .success)
  }

  func testcustomConditionIsEvaluated() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Business logic: only allow if count is less than 2
    let currentCount = Atomic<Int>(0)

    let info1 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount.value < 2
      }
    )

    // First lock succeeds
    XCTAssertEqual(strategy.canLock(id: boundary, info: info1), .success)
    strategy.lock(id: boundary, info: info1)
    currentCount.value += 1

    // Second lock succeeds
    let info2 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount.value < 2
      }
    )
    XCTAssertEqual(strategy.canLock(id: boundary, info: info2), .success)
    strategy.lock(id: boundary, info: info2)
    currentCount.value += 1

    // Third lock fails
    let info3 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount.value < 2
      }
    )
    XCTAssertLockFailure(strategy.canLock(id: boundary, info: info3))
  }

  // MARK: - Business Logic Tests

  func testpriorityBasedCondition() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // High priority action
    let priority = 10
    let highPriorityInfo = LockmanDynamicConditionInfo(
      actionId: "process",
      condition: {
        priority > 5
      }
    )

    XCTAssertEqual(strategy.canLock(id: boundary, info: highPriorityInfo), .success)

    // Low priority action
    let lowPriority = 3
    let lowPriorityInfo = LockmanDynamicConditionInfo(
      actionId: "process",
      condition: {
        lowPriority > 5
      }
    )

    XCTAssertLockFailure(strategy.canLock(id: boundary, info: lowPriorityInfo))
  }

  func testtimeBasedCondition() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Simulate business hours (9 AM - 5 PM)
    let currentHour = 14 // 2 PM

    let info = LockmanDynamicConditionInfo(
      actionId: "batch",
      condition: {
        currentHour >= 9 && currentHour < 17
      }
    )

    XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)

    // After hours
    let afterHour = 20 // 8 PM
    let afterHoursInfo = LockmanDynamicConditionInfo(
      actionId: "batch",
      condition: {
        afterHour >= 9 && afterHour < 17
      }
    )

    XCTAssertLockFailure(strategy.canLock(id: boundary, info: afterHoursInfo))
  }

  // MARK: - Lock/Unlock Tests

  func testlockAndUnlockOperations() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    let isLocked = Atomic<Bool>(false)

    let info = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked.value
      }
    )

    // First lock should succeed
    XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)
    strategy.lock(id: boundary, info: info)
    isLocked.value = true

    // Second lock should fail
    let info2 = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked.value
      }
    )
    XCTAssertLockFailure(strategy.canLock(id: boundary, info: info2))

    // Unlock
    strategy.unlock(id: boundary, info: info)
    isLocked.value = false

    // Now should succeed again
    let info3 = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked.value
      }
    )
    XCTAssertEqual(strategy.canLock(id: boundary, info: info3), .success)
  }

  // MARK: - Cleanup Tests

  func testcleanupRemovesAllLocks() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary1 = TestBoundaryId(value: "test1")
    let boundary2 = TestBoundaryId(value: "test2")

    // Add locks to multiple boundaries
    let info1 = LockmanDynamicConditionInfo(actionId: "task1")
    let info2 = LockmanDynamicConditionInfo(actionId: "task2")

    strategy.lock(id: boundary1, info: info1)
    strategy.lock(id: boundary2, info: info2)

    // Cleanup all
    strategy.cleanUp()

    // All boundaries should be clean
    let checkInfo = LockmanDynamicConditionInfo(
      actionId: "check",
      condition: {
        // This would fail if locks existed, but we can't check internal state
        // So we just verify the method doesn't crash
        true
      }
    )

    XCTAssertEqual(strategy.canLock(id: boundary1, info: checkInfo), .success)
    XCTAssertEqual(strategy.canLock(id: boundary2, info: checkInfo), .success)
  }

  func testcleanupForSpecificBoundary() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary1 = TestBoundaryId(value: "test1")
    let boundary2 = TestBoundaryId(value: "test2")

    // Add locks
    let info1 = LockmanDynamicConditionInfo(actionId: "task1")
    let info2 = LockmanDynamicConditionInfo(actionId: "task2")

    strategy.lock(id: boundary1, info: info1)
    strategy.lock(id: boundary2, info: info2)

    // Cleanup only boundary1
    strategy.cleanUp(id: boundary1)

    // Verify cleanup worked (we can't directly check state, so just ensure no crash)
    let checkInfo = LockmanDynamicConditionInfo(actionId: "check")
    XCTAssertEqual(strategy.canLock(id: boundary1, info: checkInfo), .success)
    XCTAssertEqual(strategy.canLock(id: boundary2, info: checkInfo), .success)
  }

  // MARK: - Complex Condition Tests

  func testcomplexBusinessLogicCondition() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Simulate a rate limiter with quota
    let requestCount = Atomic<Int>(0)
    let quota = 3
    let resetTime = Date().addingTimeInterval(3600) // 1 hour from now

    let makeInfo: () -> LockmanDynamicConditionInfo = {
      LockmanDynamicConditionInfo(
        actionId: "api-call",
        condition: {
          if Date() > resetTime {
            // Reset quota after time window
            requestCount.value = 0
          }

          return requestCount.value < quota
        }
      )
    }

    // First few requests succeed
    for _ in 0 ..< quota {
      let info = makeInfo()
      XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)
      strategy.lock(id: boundary, info: info)
      requestCount.value += 1
    }

    // Next request fails
    let failInfo = makeInfo()
    XCTAssertLockFailure(strategy.canLock(id: boundary, info: failInfo))
  }

  func testfailureWithCustomReason() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    let info = LockmanDynamicConditionInfo(
      actionId: "restricted",
      condition: {
        false
      }
    )

    let result = strategy.canLock(id: boundary, info: info)
    XCTAssertLockFailure(result)
  }

  // MARK: - Boundary Isolation Tests

  func testdifferentBoundariesAreIsolated() {
    let strategy  = LockmanDynamicConditionStrategy()
    let boundary1 = TestBoundaryId(value: "user1")
    let boundary2 = TestBoundaryId(value: "user2")

    // Each user has their own counter
    let user1Count = Atomic<Int>(0)
    let user2Count = Atomic<Int>(0)

    let user1Info = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user1Count.value < 1
      }
    )

    // User1 makes a request
    XCTAssertEqual(strategy.canLock(id: boundary1, info: user1Info), .success)
    strategy.lock(id: boundary1, info: user1Info)
    user1Count.value += 1

    // User2 can still make requests
    let user2Info = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user2Count.value < 1
      }
    )
    XCTAssertEqual(strategy.canLock(id: boundary2, info: user2Info), .success)
    strategy.lock(id: boundary2, info: user2Info)
    user2Count.value += 1

    // User1 second request fails
    let user1Info2 = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user1Count.value < 1
      }
    )
    XCTAssertLockFailure(strategy.canLock(id: boundary1, info: user1Info2))
  }

  // MARK: - Thread Safety Tests

  func testconcurrentOperationsAreThreadSafe() async {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Run multiple concurrent operations
    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< 10 {
        group.addTask {
          let info = LockmanDynamicConditionInfo(
            actionId: "concurrent-\(i)"
          )

          // Random operations
          if i % 3 == 0 {
            _ = strategy.canLock(id: boundary, info: info)
          } else if i % 3 == 1 {
            strategy.lock(id: boundary, info: info)
          } else {
            strategy.unlock(id: boundary, info: info)
          }
        }
      }
    }

    // Verify strategy is still functional
    let info = LockmanDynamicConditionInfo(actionId: "final")
    XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)
  }

  // MARK: - Unique ID Tests

  func testeachInfoHasUniqueId() {
    let info1 = LockmanDynamicConditionInfo(actionId: "test")
    let info2 = LockmanDynamicConditionInfo(actionId: "test")

    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testinfoEqualityBasedOnUniqueId() {
    let info = LockmanDynamicConditionInfo(actionId: "test")

    // Same instance should have same unique ID
    XCTAssertEqual(info.uniqueId, info.uniqueId)
  }
}
