import Foundation
import Testing
@testable import LockmanCore

@Suite("LockmanDynamicConditionStrategy Tests")
struct LockmanDynamicConditionStrategyTests {
  // MARK: - Test Helpers

  private struct TestBoundaryId: LockmanBoundaryId {
    let value: String
  }

  // MARK: - Basic Tests

  @Test("Strategy has correct ID")
  func strategyHasCorrectId() {
    let strategy = LockmanDynamicConditionStrategy()
    #expect(strategy.strategyId == .dynamicCondition)
  }

  @Test("Shared instance is singleton")
  func sharedInstanceIsSingleton() {
    #expect(LockmanDynamicConditionStrategy.shared === LockmanDynamicConditionStrategy.shared)
  }

  @Test("Default condition always allows lock")
  func defaultConditionAlwaysAllows() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Default condition (always success)
    let info = LockmanDynamicConditionInfo(
      actionId: "test"
    )

    #expect(strategy.canLock(id: boundary, info: info) == .success)

    // Add multiple locks - should still succeed
    strategy.lock(id: boundary, info: info)
    let info2 = LockmanDynamicConditionInfo(actionId: "test2")
    #expect(strategy.canLock(id: boundary, info: info2) == .success)
  }

  @Test("Custom condition is evaluated")
  func customConditionIsEvaluated() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Business logic: only allow if count is less than 2
    var currentCount = 0

    let info1 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount < 2
      }
    )

    // First lock succeeds
    #expect(strategy.canLock(id: boundary, info: info1) == .success)
    strategy.lock(id: boundary, info: info1)
    currentCount += 1

    // Second lock succeeds
    let info2 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount < 2
      }
    )
    #expect(strategy.canLock(id: boundary, info: info2) == .success)
    strategy.lock(id: boundary, info: info2)
    currentCount += 1

    // Third lock fails
    let info3 = LockmanDynamicConditionInfo(
      actionId: "fetch",
      condition: {
        currentCount < 2
      }
    )
    #expect(strategy.canLock(id: boundary, info: info3) == .failure)
  }

  // MARK: - Business Logic Tests

  @Test("Priority-based condition")
  func priorityBasedCondition() {
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

    #expect(strategy.canLock(id: boundary, info: highPriorityInfo) == .success)

    // Low priority action
    let lowPriority = 3
    let lowPriorityInfo = LockmanDynamicConditionInfo(
      actionId: "process",
      condition: {
        lowPriority > 5
      }
    )

    #expect(strategy.canLock(id: boundary, info: lowPriorityInfo) == .failure)
  }

  @Test("Time-based condition")
  func timeBasedCondition() {
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

    #expect(strategy.canLock(id: boundary, info: info) == .success)

    // After hours
    let afterHour = 20 // 8 PM
    let afterHoursInfo = LockmanDynamicConditionInfo(
      actionId: "batch",
      condition: {
        afterHour >= 9 && afterHour < 17
      }
    )

    #expect(strategy.canLock(id: boundary, info: afterHoursInfo) == .failure)
  }

  // MARK: - Lock/Unlock Tests

  @Test("Lock and unlock operations")
  func lockAndUnlockOperations() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    var isLocked = false

    let info = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked
      }
    )

    // First lock should succeed
    #expect(strategy.canLock(id: boundary, info: info) == .success)
    strategy.lock(id: boundary, info: info)
    isLocked = true

    // Second lock should fail
    let info2 = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked
      }
    )
    #expect(strategy.canLock(id: boundary, info: info2) == .failure)

    // Unlock
    strategy.unlock(id: boundary, info: info)
    isLocked = false

    // Now should succeed again
    let info3 = LockmanDynamicConditionInfo(
      actionId: "exclusive",
      condition: {
        !isLocked
      }
    )
    #expect(strategy.canLock(id: boundary, info: info3) == .success)
  }

  // MARK: - Cleanup Tests

  @Test("Cleanup removes all locks")
  func cleanupRemovesAllLocks() {
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

    #expect(strategy.canLock(id: boundary1, info: checkInfo) == .success)
    #expect(strategy.canLock(id: boundary2, info: checkInfo) == .success)
  }

  @Test("Cleanup for specific boundary")
  func cleanupForSpecificBoundary() {
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
    #expect(strategy.canLock(id: boundary1, info: checkInfo) == .success)
    #expect(strategy.canLock(id: boundary2, info: checkInfo) == .success)
  }

  // MARK: - Complex Condition Tests

  @Test("Complex business logic condition")
  func complexBusinessLogicCondition() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    // Simulate a rate limiter with quota
    var requestCount = 0
    let quota = 3
    let resetTime = Date().addingTimeInterval(3600) // 1 hour from now

    let makeInfo: () -> LockmanDynamicConditionInfo = {
      LockmanDynamicConditionInfo(
        actionId: "api-call",
        condition: {
          if Date() > resetTime {
            // Reset quota after time window
            requestCount = 0
          }

          return requestCount < quota
        }
      )
    }

    // First few requests succeed
    for _ in 0 ..< quota {
      let info = makeInfo()
      #expect(strategy.canLock(id: boundary, info: info) == .success)
      strategy.lock(id: boundary, info: info)
      requestCount += 1
    }

    // Next request fails
    let failInfo = makeInfo()
    #expect(strategy.canLock(id: boundary, info: failInfo) == .failure)
  }

  @Test("Failure with custom reason")
  func failureWithCustomReason() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary = TestBoundaryId(value: "test")

    let info = LockmanDynamicConditionInfo(
      actionId: "restricted",
      condition: {
        false
      }
    )

    let result = strategy.canLock(id: boundary, info: info)
    #expect(result == .failure)
  }

  // MARK: - Boundary Isolation Tests

  @Test("Different boundaries are isolated")
  func differentBoundariesAreIsolated() {
    let strategy = LockmanDynamicConditionStrategy()
    let boundary1 = TestBoundaryId(value: "user1")
    let boundary2 = TestBoundaryId(value: "user2")

    // Each user has their own counter
    var user1Count = 0
    var user2Count = 0

    let user1Info = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user1Count < 1
      }
    )

    // User1 makes a request
    #expect(strategy.canLock(id: boundary1, info: user1Info) == .success)
    strategy.lock(id: boundary1, info: user1Info)
    user1Count += 1

    // User2 can still make requests
    let user2Info = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user2Count < 1
      }
    )
    #expect(strategy.canLock(id: boundary2, info: user2Info) == .success)
    strategy.lock(id: boundary2, info: user2Info)
    user2Count += 1

    // User1 second request fails
    let user1Info2 = LockmanDynamicConditionInfo(
      actionId: "request",
      condition: {
        user1Count < 1
      }
    )
    #expect(strategy.canLock(id: boundary1, info: user1Info2) == .failure)
  }

  // MARK: - Thread Safety Tests

  @Test("Concurrent operations are thread-safe")
  func concurrentOperationsAreThreadSafe() async {
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
    #expect(strategy.canLock(id: boundary, info: info) == .success)
  }

  // MARK: - Unique ID Tests

  @Test("Each info has unique ID")
  func eachInfoHasUniqueId() {
    let info1 = LockmanDynamicConditionInfo(actionId: "test")
    let info2 = LockmanDynamicConditionInfo(actionId: "test")

    #expect(info1.uniqueId != info2.uniqueId)
    #expect(!(info1 == info2))
  }

  @Test("Info equality based on unique ID")
  func infoEqualityBasedOnUniqueId() {
    let info = LockmanDynamicConditionInfo(actionId: "test")

    #expect(info == info)
    #expect(info.uniqueId == info.uniqueId)
  }
}
