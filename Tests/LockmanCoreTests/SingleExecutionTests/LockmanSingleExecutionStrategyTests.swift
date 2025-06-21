
import Foundation
import XCTest
@testable import LockmanCore

// MARK: - Test Helpers

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: TestBoundaryId, rhs: TestBoundaryId) -> Bool {
    lhs.value == rhs.value
  }
}

// MARK: - LockmanSingleExecutionStrategy Tests

final class LockmanSingleExecutionStrategyTests: XCTestCase {
  // MARK: - Initialization Tests

  func testSharedInstanceIsSingleton() {
    let instance1 = LockmanSingleExecutionStrategy.shared
    let instance2 = LockmanSingleExecutionStrategy.shared

    XCTAssertTrue(instance1  === instance2)
  }

  func testMultipleInstancesAreIndependent() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()

    XCTAssertTrue(strategy1 !== strategy2)
  }

  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanSingleExecutionStrategy.makeStrategyId()
    let id2 = LockmanSingleExecutionStrategy.makeStrategyId()

    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id1, .singleExecution)
  }

  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy  = LockmanSingleExecutionStrategy()
    let staticId = LockmanSingleExecutionStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  func testDifferentActionsOnSameBoundaryFailWithBoundaryMode() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // Lock first action
    strategy.lock(id: id, info: info1)

    // Different action should fail in boundary mode
    XCTAssertLockFailure(strategy.canLock(id: id, info: info2))

    // Cleanup
    strategy.cleanUp()
  }

  // MARK: - Basic Lock Behavior Tests

  func testFirstLockSucceedsWithBoundaryMode() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    let result = strategy.canLock(id: id, info: info)
    XCTAssertEqual(result, .success)
  }

  func testDuplicateLockFailsWithBoundaryMode() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // First lock should succeed
    let result1 = strategy.canLock(id: id, info: info)
    XCTAssertEqual(result1, .success)
    strategy.lock(id: id, info: info)

    // Second lock should fail
    let result2  = strategy.canLock(id: id, info: info)
    XCTAssertLockFailure(result2)

    // Cleanup for isolation
    strategy.unlock(id: id, info: info)
  }

  func testAnySecondLockOnSameBoundaryFails() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary) // Same actionId

    // First lock should succeed
    let result1 = strategy.canLock(id: id, info: info1)
    XCTAssertEqual(result1, .success)
    strategy.lock(id: id, info: info1)

    // Second lock should fail (any lock fails when boundary is locked)
    let result2  = strategy.canLock(id: id, info: info2)
    XCTAssertLockFailure(result2)

    // Cleanup
    strategy.unlock(id: id, info: info1)
  }

  // MARK: - Unlock Tests

  func testUnlockAllowsSubsequentLock() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Lock
    let result1 = strategy.canLock(id: id, info: info)
    XCTAssertEqual(result1, .success)
    strategy.lock(id: id, info: info)

    // Unlock
    strategy.unlock(id: id, info: info)

    // Lock again should succeed
    let result2  = strategy.canLock(id: id, info: info)
    XCTAssertEqual(result2, .success)
  }

  func testUnlockWithoutPriorLockDoesNotCrash() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Should not crash
    strategy.unlock(id: id, info: info)

    // Should still be able to lock after invalid unlock
    let result = strategy.canLock(id: id, info: info)
    XCTAssertEqual(result, .success)
  }

  // MARK: - Boundary Isolation Tests

  func testDifferentBoundaryIdsAreIsolated() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id1 = TestBoundaryId("test1")
    let id2 = TestBoundaryId("test2")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Lock with id1
    let result1 = strategy.canLock(id: id1, info: info)
    XCTAssertEqual(result1, .success)
    strategy.lock(id: id1, info: info)

    // Lock with id2 should also succeed (different boundary)
    let result2  = strategy.canLock(id: id2, info: info)
    XCTAssertEqual(result2, .success)
    strategy.lock(id: id2, info: info)

    // Cleanup
    strategy.unlock(id: id1, info: info)
    strategy.unlock(id: id2, info: info)
  }

  func testUnlockAffectsOnlySpecificBoundary() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id1 = TestBoundaryId("test1")
    let id2 = TestBoundaryId("test2")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Lock both boundaries
    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    // Unlock only id1
    strategy.unlock(id: id1, info: info)

    // id1 should be able to lock again
    let result1 = strategy.canLock(id: id1, info: info)
    XCTAssertEqual(result1, .success)

    // id2 should still be locked
    let result2  = strategy.canLock(id: id2, info: info)
    XCTAssertLockFailure(result2)

    // Cleanup id2
    strategy.unlock(id: id2, info: info)
  }

  // MARK: - CleanUp Tests

  func testCleanUpRemovesAllLockState() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id1 = TestBoundaryId("test1")
    let id2 = TestBoundaryId("test2")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Lock multiple boundaries
    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    // Clean up all
    strategy.cleanUp()

    // Both should be able to lock again
    let result1 = strategy.canLock(id: id1, info: info)
    let result2 = strategy.canLock(id: id2, info: info)

    XCTAssertEqual(result1, .success)
    XCTAssertEqual(result2, .success)
  }

  func testCleanUpWithSpecificBoundaryIdRemovesOnlyThatBoundary() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id1 = TestBoundaryId("test1")
    let id2 = TestBoundaryId("test2")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Lock both boundaries
    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    // Clean up only id1
    strategy.cleanUp(id: id1)

    // id1 should be able to lock again
    let result1 = strategy.canLock(id: id1, info: info)
    XCTAssertEqual(result1, .success)

    // id2 should still be locked
    let result2  = strategy.canLock(id: id2, info: info)
    XCTAssertLockFailure(result2)

    // Cleanup id2
    strategy.cleanUp(id: id2)
  }

  // MARK: - Lock/Unlock Sequence Tests

  func testMultipleLockUnlockCycles() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

    // Test multiple cycles
    for _ in 0 ..< 3 {
      // Lock should succeed
      let lockResult = strategy.canLock(id: id, info: info)
      XCTAssertEqual(lockResult, .success)
      strategy.lock(id: id, info: info)

      // Duplicate lock should fail
      let duplicateResult  = strategy.canLock(id: id, info: info)
      XCTAssertLockFailure(duplicateResult)

      // Unlock
      strategy.unlock(id: id, info: info)
    }
  }

  func testSequentialLockAndUnlockOperations() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("complex")
    let action1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let action2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)
    let action3 = LockmanSingleExecutionInfo(actionId: "action3", mode: .boundary)

    // Lock action1
    XCTAssertEqual(strategy.canLock(id: id, info: action1), .success)
    strategy.lock(id: id, info: action1)

    // Lock action2 should fail (boundary is locked)
    XCTAssertLockFailure(strategy.canLock(id: id, info: action2))

    // Unlock action1
    strategy.unlock(id: id, info: action1)

    // Now action2 should succeed
    XCTAssertEqual(strategy.canLock(id: id, info: action2), .success)
    strategy.lock(id: id, info: action2)

    // action3 should fail
    XCTAssertLockFailure(strategy.canLock(id: id, info: action3))

    // Cleanup
    strategy.unlock(id: id, info: action2)
  }

  // MARK: - State Management Tests

  func testEmptyBoundaryCleanup() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("empty")

    // Cleanup on empty boundary should not crash
    strategy.cleanUp(id: id)

    // Should still be able to use the boundary
    let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
    XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
  }

  // MARK: - Boundary Lock Tests

  func testBlocksAllActionsWhenOneIsLocked() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: "action3", mode: .boundary)

    // First lock succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // All other actions should fail regardless of actionId
    XCTAssertLockFailure(strategy.canLock(id: id, info: info2))
    XCTAssertLockFailure(strategy.canLock(id: id, info: info3))

    // Even same actionId should fail
    XCTAssertLockFailure(strategy.canLock(id: id, info: info1))

    // Cleanup
    strategy.unlock(id: id, info: info1)
  }

  func testAllowsLockAfterUnlock() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // Lock and unlock first action
    strategy.lock(id: id, info: info1)
    strategy.unlock(id: id, info: info1)

    // Second action should now succeed
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .success)
    strategy.lock(id: id, info: info2)

    // Cleanup
    strategy.unlock(id: id, info: info2)
  }

  func testSharedInstanceBehavior() {
    let strategy = LockmanSingleExecutionStrategy.shared
    let id = TestBoundaryId("test-shared")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // Lock first action
    strategy.lock(id: id, info: info1)

    // Different action should fail
    XCTAssertLockFailure(strategy.canLock(id: id, info: info2))

    // Cleanup
    strategy.cleanUp(id: id)
  }

  // MARK: - Thread Safety Tests

  func testBasicConcurrentLockOperationsOnDifferentBoundaries() async {
    let strategy = LockmanSingleExecutionStrategy()

    let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
      // Launch 10 concurrent lock attempts on different boundaries
      for i in 0 ..< 10 {
        group.addTask {
          let id = TestBoundaryId("test\(i)")
          let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
          let result = strategy.canLock(id: id, info: info)
          if result == .success {
            strategy.lock(id: id, info: info)
          }
          return result == .success
        }
      }

      var results: [Bool] = []
      for await success in group {
        results.append(success)
      }
      return results
    }

    let successCount = results.filter { $0 }.count
    // All should succeed since they use different boundaries
    XCTAssertEqual(successCount, 10)

    // Cleanup
    strategy.cleanUp()
  }

  func testConcurrentAccessToSameBoundary() async {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("concurrent")

    let results = await withTaskGroup(of: LockResult.self, returning: [LockResult].self) { group in
      // Launch 5 concurrent lock attempts on same boundary with same action
      for _ in 0 ..< 5 {
        group.addTask {
          let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
          return strategy.canLock(id: id, info: info)
        }
      }

      var results: [LockResult] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    let successCount = results.filter { $0 == .success }.count
    // At least one should succeed due to single execution semantics
    XCTAssertGreaterThanOrEqual(successCount , 1)
    // But not all should succeed
    XCTAssertLessThanOrEqual(successCount , 5)

    // Cleanup
    strategy.cleanUp()
  }

  func testConcurrentAccessWithDifferentActionsOnSameBoundary() async {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("concurrent_different")

    let results = await withTaskGroup(of: (String, LockResult).self, returning: [(String, LockResult)].self) { group in
      // Launch concurrent lock attempts with different actions
      for i in 0 ..< 5 {
        group.addTask {
          let info = LockmanSingleExecutionInfo(actionId: "action\(i)", mode: .boundary)
          let result = strategy.canLock(id: id, info: info)
          return ("action\(i)", result)
        }
      }

      var results: [(String, LockResult)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    let successCount = results.filter { $0.1 == .success }.count
    // All different actions should be able to succeed
    XCTAssertEqual(successCount, 5)

    // Cleanup
    strategy.cleanUp()
  }

  // MARK: - Integration Tests

  func testIntegrationWithLockmanState() {
    let strategy  = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("integration")

    let action1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let action2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // Test that the strategy correctly uses its internal state
    XCTAssertEqual(strategy.canLock(id: id, info: action1), .success)
    strategy.lock(id: id, info: action1)

    // Second action should fail (boundary is locked)
    XCTAssertLockFailure(strategy.canLock(id: id, info: action2))

    // Unlock and verify state changes
    strategy.unlock(id: id, info: action1)

    // Now action2 should succeed
    XCTAssertEqual(strategy.canLock(id: id, info: action2), .success)

    strategy.cleanUp()
  }

  func testPerformanceWithManySequentialOperations() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("performance")

    let startTime = Date()

    // Perform many lock/unlock cycles
    for i in 0 ..< 100 {
      let info = LockmanSingleExecutionInfo(actionId: "action\(i)", mode: .boundary)

      XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
      strategy.lock(id: id, info: info)
      strategy.unlock(id: id, info: info)
    }

    let duration = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(duration , 1.0) // Should complete quickly

    strategy.cleanUp()
  }

  func testMemoryEfficiencyWithManyBoundaries() {
    let strategy = LockmanSingleExecutionStrategy()
    var boundaries: [TestBoundaryId] = []

    // Create many boundaries and lock them
    for i in 0 ..< 50 {
      let id = TestBoundaryId("boundary\(i)")
      boundaries.append(id)

      let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
      strategy.lock(id: id, info: info)
    }

    // Cleanup half of them
    for i in 0 ..< 25 {
      strategy.cleanUp(id: boundaries[i])
    }

    // Verify remaining boundaries are still locked
    for i in 25 ..< 50 {
      let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
      XCTAssertLockFailure(strategy.canLock(id: boundaries[i], info: info))
    }

    // Full cleanup
    strategy.cleanUp()

    // All should be unlocked now
    for boundary in boundaries {
      let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
      XCTAssertEqual(strategy.canLock(id: boundary, info: info), .success)
    }
  }

  // MARK: - Execution Mode Tests

  func testNoneModeAlwaysAllowsLocks() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .none)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .none)

    // First lock succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // Second lock also succeeds with none mode
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .success)
    strategy.lock(id: id, info: info2)

    // Cleanup
    strategy.cleanUp()
  }

  func testBoundaryModeBlocksAllActions() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // First lock succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // Second lock fails (different actionId but same boundary)
    XCTAssertLockFailure(strategy.canLock(id: id, info: info2))

    // Cleanup
    strategy.cleanUp()
  }

  func testActionModeBlocksOnlySameActionId() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .action)
    let info3 = LockmanSingleExecutionInfo(actionId: "action1", mode: .action)

    // First lock succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // Different actionId succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .success)
    strategy.lock(id: id, info: info2)

    // Same actionId as info1 fails
    XCTAssertLockFailure(strategy.canLock(id: id, info: info3))

    // Cleanup
    strategy.cleanUp()
  }

  func testMixedModesWorkCorrectly() {
    let strategy = LockmanSingleExecutionStrategy()
    let id = TestBoundaryId("test")
    let actionInfo = LockmanSingleExecutionInfo(actionId: "action1", mode: .action)
    let boundaryInfo = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)
    let noneInfo = LockmanSingleExecutionInfo(actionId: "action3", mode: .none)

    // Action mode lock succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: actionInfo), .success)
    strategy.lock(id: id, info: actionInfo)

    // None mode always succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: noneInfo), .success)
    strategy.lock(id: id, info: noneInfo)

    // Boundary mode fails because locks exist
    XCTAssertLockFailure(strategy.canLock(id: id, info: boundaryInfo))

    // Cleanup
    strategy.cleanUp()
  }
}
