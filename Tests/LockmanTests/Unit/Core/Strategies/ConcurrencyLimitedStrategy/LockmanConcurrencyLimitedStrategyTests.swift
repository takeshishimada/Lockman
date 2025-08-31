import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Simplified LockmanConcurrencyLimitedStrategy tests with 3-phase approach
// ✅ 14 test methods covering all concurrency limits and behaviors
// ✅ Phase 1: Basic strategy functionality (initialization, canLock, lock, unlock)
// ✅ Phase 2: Concurrency limit testing (.unlimited, .limited) with various limits
// ✅ Phase 3: Integration testing and edge cases

final class LockmanConcurrencyLimitedStrategyTests: XCTestCase {

  private var strategy: LockmanConcurrencyLimitedStrategy!

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    strategy = LockmanConcurrencyLimitedStrategy.shared
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    strategy = nil
  }

  // MARK: - Phase 1: Basic Strategy Functionality

  func testLockmanConcurrencyLimitedStrategyInitialization() {
    // Test strategy initialization and properties
    let sharedStrategy = LockmanConcurrencyLimitedStrategy.shared

    // Verify strategyId
    let expectedStrategyId = LockmanStrategyId(name: "concurrencyLimited")
    XCTAssertEqual(sharedStrategy.strategyId, expectedStrategyId)
    XCTAssertEqual(sharedStrategy.strategyId, LockmanConcurrencyLimitedStrategy.makeStrategyId())

    // Test shared instance singleton behavior
    XCTAssertNotNil(sharedStrategy)
    XCTAssertTrue(sharedStrategy === LockmanConcurrencyLimitedStrategy.shared)
  }

  func testLockmanConcurrencyLimitedStrategyTypeAlias() {
    // Test that the strategy's Info type matches expected type
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("test"), .limited(1))
    XCTAssertTrue(info is LockmanConcurrencyLimitedStrategy.I)

    // Test that the typealias is correctly defined
    func testGenericFunction<S: LockmanStrategy>(_ strategy: S, info: S.I) -> Bool {
      return info is LockmanConcurrencyLimitedInfo
    }

    let result = testGenericFunction(strategy, info: info)
    XCTAssertTrue(result)
  }

  func testLockmanConcurrencyLimitedStrategyBasicCanLock() {
    // Test basic canLock functionality
    let boundaryId = "testBoundary"

    // Test .unlimited limit (always succeeds)
    let unlimitedInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("unlimitedAction"), .unlimited)
    let unlimitedResult = strategy.canLock(boundaryId: boundaryId, info: unlimitedInfo)
    XCTAssertEqual(unlimitedResult, .success)

    // Test .limited limit (succeeds when no locks)
    let limitedInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("limitedAction"), .limited(2))
    let limitedResult = strategy.canLock(boundaryId: boundaryId, info: limitedInfo)
    XCTAssertEqual(limitedResult, .success)
  }

  func testLockmanConcurrencyLimitedStrategyBasicLockUnlock() {
    // Test basic lock-unlock cycle
    let boundaryId = "lockUnlockBoundary"
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))

    // Initial state - should be able to lock
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)

    // Lock the resource
    strategy.lock(boundaryId: boundaryId, info: info)

    // After lock - should not be able to lock again with same actionId due to limit of 1
    let secondInfo = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: secondInfo) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for exceeded limit")
    }

    // Unlock the resource
    strategy.unlock(boundaryId: boundaryId, info: info)

    // After unlock - should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: secondInfo), .success)
  }

  func testLockmanConcurrencyLimitedStrategyCleanup() {
    // Test cleanup functionality
    let boundaryId = "cleanupBoundary"
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))

    // Lock and verify it's locked
    strategy.lock(boundaryId: boundaryId, info: info)
    let secondInfo = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: secondInfo) {
      XCTAssertTrue(true)  // Expected locked state
    } else {
      XCTFail("Expected locked state")
    }

    // Global cleanup
    strategy.cleanUp()

    // Should be able to lock again after cleanup
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: secondInfo), .success)
  }

  // MARK: - Phase 2: Concurrency Limit Testing

  func testLockmanConcurrencyLimitedStrategyUnlimitedConcurrency() {
    // Test .unlimited concurrency behavior
    let boundaryId = "unlimitedBoundary"
    var infos: [LockmanConcurrencyLimitedInfo] = []

    // Lock multiple actions with unlimited concurrency
    for i in 0..<10 {
      let info = LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("unlimitedAction\(i)"), .unlimited)
      infos.append(info)

      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
      strategy.lock(boundaryId: boundaryId, info: info)
    }

    // Should still be able to add more unlimited actions
    let additionalInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("additionalUnlimited"), .unlimited)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: additionalInfo), .success)
  }

  func testLockmanConcurrencyLimitedStrategyLimitedConcurrencyOne() {
    // Test .limited(1) concurrency behavior (exclusive within same actionId)
    let boundaryId = "limited1Boundary"
    let info1 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("sameAction"), .limited(1))
    let info2 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("sameAction"), .limited(1))

    // First lock should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second lock with same actionId should fail due to limit of 1
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for limit of 1")
    }

    // Unlock first and try second again
    strategy.unlock(boundaryId: boundaryId, info: info1)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
  }

  func testLockmanConcurrencyLimitedStrategyLimitedConcurrencyMultiple() {
    // Test .limited(3) concurrency behavior within same actionId
    let boundaryId = "limited3Boundary"
    var infos: [LockmanConcurrencyLimitedInfo] = []
    let sharedActionId = LockmanActionId("sharedAction")

    // Lock up to the limit (3) with same actionId
    for i in 0..<3 {
      let info = LockmanConcurrencyLimitedInfo(actionId: sharedActionId, .limited(3))
      infos.append(info)

      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
      strategy.lock(boundaryId: boundaryId, info: info)
    }

    // Fourth action with same actionId should fail due to limit of 3
    let fourthInfo = LockmanConcurrencyLimitedInfo(actionId: sharedActionId, .limited(3))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: fourthInfo) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for limit of 3")
    }

    // Unlock one and try fourth again
    strategy.unlock(boundaryId: boundaryId, info: infos[0])
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: fourthInfo), .success)
  }

  func testLockmanConcurrencyLimitedStrategyConcurrencyGroups() {
    // Test different concurrency groups are isolated
    let boundaryId = "concurrencyGroupsBoundary"
    let group1Info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("group1Action"), .limited(1))
    let group2Info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("group2Action"), .limited(1))

    // Lock in group1 (action id serves as concurrency id)
    strategy.lock(boundaryId: boundaryId, info: group1Info)

    // Should still be able to lock in group2 (different concurrency id)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Info), .success)
    strategy.lock(boundaryId: boundaryId, info: group2Info)

    // Additional action in group1 should fail
    let additionalGroup1Info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("group1Action"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: additionalGroup1Info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for group1 limit")
    }

    // Additional action in group2 should also fail
    let additionalGroup2Info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("group2Action"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: additionalGroup2Info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for group2 limit")
    }
  }

  func testLockmanConcurrencyLimitedStrategyMixedLimits() {
    // Test mixing unlimited and limited actions
    let boundaryId = "mixedLimitsBoundary"
    let unlimitedInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("unlimited"), .unlimited)
    let limitedInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("limited"), .limited(1))

    // Lock unlimited action first
    strategy.lock(boundaryId: boundaryId, info: unlimitedInfo)

    // Should still be able to lock limited action (different concurrency group)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: limitedInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: limitedInfo)

    // Additional unlimited actions should succeed
    let additionalUnlimited = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("unlimited"), .unlimited)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: additionalUnlimited), .success)

    // Additional limited action should fail
    let additionalLimited = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("limited"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: additionalLimited) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for limited group")
    }
  }

  // MARK: - Phase 3: Integration and Edge Cases

  func testLockmanConcurrencyLimitedStrategyMultipleBoundaries() {
    // Test that different boundaries are isolated from each other
    let boundary1 = "boundary1"
    let boundary2 = "boundary2"
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))

    // Lock in boundary1
    strategy.lock(boundaryId: boundary1, info: info)

    // Should be able to lock same concurrency group in boundary2
    let info2 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))
    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info2), .success)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Both boundaries should now be at their limits
    let info3 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundary1, info: info3) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for boundary1")
    }

    if case .cancel = strategy.canLock(boundaryId: boundary2, info: info3) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for boundary2")
    }
  }

  func testLockmanConcurrencyLimitedStrategyBoundarySpecificCleanup() {
    // Test boundary-specific cleanup
    let boundary1 = "cleanupBoundary1"
    let boundary2 = "cleanupBoundary2"
    let info1 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action1"), .limited(1))
    let info2 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action2"), .limited(1))

    // Add locks to both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Verify locks exist by trying to acquire again
    let testInfo1 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action1"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundary1, info: testInfo1) {
      XCTAssertTrue(true)  // Expected locked state
    } else {
      XCTFail("Expected locked state")
    }

    // Cleanup boundary1 only
    strategy.cleanUp(boundaryId: boundary1)

    // Should be able to lock in boundary1 again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: testInfo1), .success)

    // boundary2 should still be locked
    let testInfo2 = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action2"), .limited(1))
    if case .cancel = strategy.canLock(boundaryId: boundary2, info: testInfo2) {
      XCTAssertTrue(true)  // Expected locked state
    } else {
      XCTFail("Expected locked state")
    }
  }

  func testLockmanConcurrencyLimitedStrategyZeroLimit() {
    // Test edge case with limit of 0
    let boundaryId = "zeroLimitBoundary"
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(0))

    // Should fail immediately with limit of 0
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for limit of 0")
    }
  }

  func testLockmanConcurrencyLimitedStrategyTypeErasure() {
    // Test strategy through type-erased interface
    let anyStrategy: any LockmanStrategy<LockmanConcurrencyLimitedInfo> = strategy
    let boundaryId = "typeErasureBoundary"
    let info = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))

    // Test through type-erased interface
    XCTAssertEqual(anyStrategy.canLock(boundaryId: boundaryId, info: info), .success)
    anyStrategy.lock(boundaryId: boundaryId, info: info)

    // Verify lock is active
    let testInfo = LockmanConcurrencyLimitedInfo(actionId: LockmanActionId("action"), .limited(1))
    if case .cancel = anyStrategy.canLock(boundaryId: boundaryId, info: testInfo) {
      XCTAssertTrue(true)  // Expected locked state
    } else {
      XCTFail("Expected locked state")
    }

    // Unlock and verify
    anyStrategy.unlock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(anyStrategy.canLock(boundaryId: boundaryId, info: testInfo), .success)
  }

}
