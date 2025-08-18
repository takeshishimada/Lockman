import XCTest

@testable import Lockman

/// Unit tests for LockmanConcurrencyLimitedStrategy
///
/// Tests the strategy that limits the number of concurrent executions per concurrency group,
/// enabling fine-grained control over resource usage and parallel execution limits.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Strategy Initialization and Configuration
/// - [ ] Shared singleton instance access and consistency
/// - [ ] Private initializer enforcement (singleton pattern)
/// - [ ] makeStrategyId() returns "concurrencyLimited" identifier
/// - [ ] Strategy ID consistency across multiple calls
/// - [ ] @unchecked Sendable conformance verification
/// - [ ] Thread-safe state container initialization with concurrencyId keys
///
/// ### LockmanStrategy Protocol Implementation
/// - [ ] Typealias I = LockmanConcurrencyLimitedInfo correctness
/// - [ ] All required protocol methods implementation verification
/// - [ ] Generic boundary type handling in all methods
/// - [ ] Protocol conformance completeness
///
/// ### Concurrency Limit Enforcement - canLock Method
/// - [ ] Success when current count is below limit
/// - [ ] Cancellation when limit is exactly reached
/// - [ ] Cancellation when limit is exceeded
/// - [ ] .unlimited limit behavior (always allows)
/// - [ ] .limited(n) limit behavior with various values
/// - [ ] Zero limit handling (.limited(0))
/// - [ ] Large limit values handling
///
/// ### Concurrency Group Management
/// - [ ] Multiple concurrency groups within same boundary
/// - [ ] Independent limit tracking per concurrency group
/// - [ ] ConcurrencyId-based key extraction and indexing
/// - [ ] String-based concurrency ID handling
/// - [ ] Empty concurrency ID edge cases
///
/// ### Lock State Management - lock/unlock Methods
/// - [ ] Successful lock addition after canLock success
/// - [ ] Exact info instance preservation with uniqueId
/// - [ ] Thread-safe lock addition across concurrent calls
/// - [ ] State consistency after multiple lock operations
/// - [ ] Unlock removes specific lock instance by uniqueId
/// - [ ] Other locks in same concurrency group remain unaffected
///
/// ### Concurrent Execution Scenarios
/// - [ ] Multiple locks within same concurrency group up to limit
/// - [ ] Mixing different concurrency groups in same boundary
/// - [ ] Rapid lock/unlock cycles within same group
/// - [ ] Lock acquisition order independence
/// - [ ] First-come-first-served behavior within limits
///
/// ### Error Generation and Handling
/// - [ ] LockmanConcurrencyLimitedError.concurrencyLimitReached creation
/// - [ ] Error contains correct lockmanInfo, boundaryId, currentCount
/// - [ ] Error message includes limit details and current count
/// - [ ] Proper error context for debugging
/// - [ ] Error consistency across different limit scenarios
///
/// ### LockmanConcurrencyLimit Integration
/// - [ ] .unlimited limit integration and behavior
/// - [ ] .limited(Int) limit integration and enforcement
/// - [ ] isExceeded(currentCount:) method usage
/// - [ ] Edge cases with limit boundary conditions
/// - [ ] Limit type switching scenarios
///
/// ### Cleanup Operations
/// - [ ] cleanUp() removes all locks across all boundaries and groups
/// - [ ] cleanUp(boundaryId:) removes only specified boundary locks
/// - [ ] Other boundaries remain unaffected by boundary-specific cleanup
/// - [ ] State emptiness after global cleanup
/// - [ ] Concurrency group isolation during cleanup
///
/// ### Performance Characteristics (Unit Test Level)
/// - [ ] activeLockCount returns correct count value
/// - [ ] Concurrency ID-based key extraction functionality
/// - [ ] Lock storage behavior with multiple concurrent locks
/// - [ ] State container behavior with multiple concurrency groups
/// - [ ] Lock acquisition/release order verification
///
/// ### Thread Safety Verification
/// - [ ] Concurrent canLock calls on same concurrency group
/// - [ ] Concurrent lock/unlock operations across threads
/// - [ ] Race condition prevention in limit checking
/// - [ ] State consistency under high concurrent load
/// - [ ] LockmanState thread-safety delegation verification
///
/// ### getCurrentLocks Debug Information
/// - [ ] Returns empty dictionary when no locks exist
/// - [ ] Correct boundary-to-locks mapping
/// - [ ] Type-erased LockmanInfo instances in results
/// - [ ] Consistent snapshot of current state
/// - [ ] Thread-safe access to debug information
/// - [ ] Concurrency group information preservation
///
/// ### Logging Integration
/// - [ ] LockmanLogger.logCanLock called with correct parameters
/// - [ ] Strategy name "ConcurrencyLimited" in logs
/// - [ ] Failure reason includes concurrency ID and limit details
/// - [ ] Log message format: "current/limit" for exceeded scenarios
/// - [ ] Boundary ID string representation in logs
///
/// ### Complex Concurrency Scenarios
/// - [ ] Multiple boundaries with same concurrency group names
/// - [ ] Mixed limit types across different concurrency groups
/// - [ ] Dynamic limit changes (if applicable)
/// - [ ] High-frequency lock churn within limits
/// - [ ] Stress testing with rapid concurrent operations
///
/// ### Edge Cases and Error Conditions
/// - [ ] Empty concurrency ID handling
/// - [ ] Very long concurrency ID names
/// - [ ] Special characters in concurrency IDs
/// - [ ] Negative limit values (should not occur but test robustness)
/// - [ ] Integer overflow scenarios with very large counts
///
/// ### Integration with Boundary System
/// - [ ] Multiple boundaries with independent concurrency tracking
/// - [ ] Boundary isolation verification
/// - [ ] AnyLockmanBoundaryId type erasure correctness
/// - [ ] Cross-boundary concurrency group independence
/// - [ ] Boundary cleanup impact on other boundaries
///
/// ### Memory Management and Resource Cleanup
/// - [ ] Proper cleanup of concurrency group tracking
/// - [ ] Memory leak prevention during long-running operations
/// - [ ] Resource cleanup completeness after operations
/// - [ ] State container memory management
/// - [ ] Lock info instance lifecycle management
///
/// ### Functional Usage Verification
/// - [ ] Limit enforcement with various limit values
/// - [ ] Concurrency group separation behavior
/// - [ ] Action execution control within limits
/// - [ ] Lock release behavior and slot availability
/// - [ ] Strategy behavior with different configuration types
///
final class LockmanConcurrencyLimitedStrategyTests: XCTestCase {

  // MARK: - Test Properties

  var strategy: LockmanConcurrencyLimitedStrategy!
  var boundaryId: TestBoundaryId!

  struct TestBoundaryId: LockmanBoundaryId {
    let value: String
    init(_ value: String) {
      self.value = value
    }
  }

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    strategy = LockmanConcurrencyLimitedStrategy.shared
    boundaryId = TestBoundaryId("testBoundary")
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Strategy Initialization and Configuration Tests

  func testSharedInstanceConsistency() {
    let instance1 = LockmanConcurrencyLimitedStrategy.shared
    let instance2 = LockmanConcurrencyLimitedStrategy.shared
    XCTAssertTrue(instance1 === instance2, "Shared instance should be the same object")
  }

  func testMakeStrategyIdReturnsCorrectIdentifier() {
    let strategyId = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    XCTAssertEqual(strategyId.value, "concurrencyLimited")
  }

  func testStrategyIdConsistencyAcrossMultipleCalls() {
    let id1 = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    let id2 = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    XCTAssertEqual(id1, id2)
  }

  func testInstanceStrategyIdMatchesStaticVersion() {
    let staticId = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    let instanceId = strategy.strategyId
    XCTAssertEqual(staticId, instanceId)
  }

  // MARK: - Concurrency Limit Enforcement Tests

  func testCanLockSuccessWhenBelowLimit() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCanLockCancellationWhenLimitReached() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    // Lock once to reach limit
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    strategy.lock(boundaryId: boundaryId, info: info)

    // Second attempt should be cancelled
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let concurrencyError = error as? LockmanConcurrencyLimitedError else {
      XCTFail("Expected LockmanConcurrencyLimitedError, got \(type(of: error))")
      return
    }

    guard case .concurrencyLimitReached(let errorInfo, _, let currentCount) = concurrencyError
    else {
      XCTFail("Expected concurrencyLimitReached case")
      return
    }

    XCTAssertEqual(errorInfo.concurrencyId, "group1")
    XCTAssertEqual(currentCount, 1)
  }

  func testUnlimitedLimitAlwaysAllows() {
    let _ = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .unlimited)
    )

    // Lock multiple times
    for i in 0..<10 {
      let testInfo = LockmanConcurrencyLimitedInfo(
        actionId: "test\(i)",
        group: TestConcurrencyGroup(id: "group1", limit: .unlimited)
      )
      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: testInfo), .success)
      strategy.lock(boundaryId: boundaryId, info: testInfo)
    }
  }

  func testZeroLimitHandling() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(0))
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel = result else {
      XCTFail("Expected .cancel for zero limit, got \(result)")
      return
    }
  }

  func testLargeLimitValues() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1000))
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  // MARK: - Concurrency Group Management Tests

  func testMultipleConcurrencyGroupsWithinSameBoundary() {
    let group1Info = LockmanConcurrencyLimitedInfo(
      actionId: "test1",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let group2Info = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group2", limit: .limited(1))
    )

    // Both should succeed as they're in different groups
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: group1Info)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Info), .success)
    strategy.lock(boundaryId: boundaryId, info: group2Info)
  }

  func testIndependentLimitTrackingPerConcurrencyGroup() {
    let group1Info1 = LockmanConcurrencyLimitedInfo(
      actionId: "test1",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    let group1Info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    let group2Info = LockmanConcurrencyLimitedInfo(
      actionId: "test3",
      group: TestConcurrencyGroup(id: "group2", limit: .limited(1))
    )

    // Lock 2 in group1
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Info1), .success)
    strategy.lock(boundaryId: boundaryId, info: group1Info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Info2), .success)
    strategy.lock(boundaryId: boundaryId, info: group1Info2)

    // Lock 1 in group2 (should still succeed)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Info), .success)
  }

  func testEmptyConcurrencyIdHandling() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "", limit: .limited(1))
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  // MARK: - Lock State Management Tests

  func testLockAfterCanLockSuccess() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    strategy.lock(boundaryId: boundaryId, info: info)

    // Should now be at limit
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2) else {
      XCTFail("Expected .cancel after reaching limit")
      return
    }
  }

  func testUnlockRemovesSpecificLockInstance() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )

    // Lock both
    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Unlock first one
    strategy.unlock(boundaryId: boundaryId, info: info1)

    // Should be able to lock one more
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: "test3",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info3), .success)
  }

  func testStateConsistencyAfterMultipleLockOperations() {
    let infos = (0..<5).map { i in
      LockmanConcurrencyLimitedInfo(
        actionId: "test\(i)",
        group: TestConcurrencyGroup(id: "group1", limit: .limited(3))
      )
    }

    // Lock first 3
    for i in 0..<3 {
      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: infos[i]), .success)
      strategy.lock(boundaryId: boundaryId, info: infos[i])
    }

    // 4th should fail
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: infos[3]) else {
      XCTFail("Expected .cancel")
      return
    }

    // Unlock one, then 4th should succeed
    strategy.unlock(boundaryId: boundaryId, info: infos[0])
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: infos[3]), .success)
  }

  // MARK: - Concurrent Execution Tests

  func testMultipleLocksWithinSameConcurrencyGroupUpToLimit() {
    let limit = 3
    let infos = (0..<limit).map { i in
      LockmanConcurrencyLimitedInfo(
        actionId: "test\(i)",
        group: TestConcurrencyGroup(id: "group1", limit: .limited(limit))
      )
    }

    // All should succeed
    for info in infos {
      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
      strategy.lock(boundaryId: boundaryId, info: info)
    }

    // Next one should fail
    let extraInfo = LockmanConcurrencyLimitedInfo(
      actionId: "extra",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(limit))
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: extraInfo) else {
      XCTFail("Expected .cancel")
      return
    }
  }

  func testMixingDifferentConcurrencyGroupsInSameBoundary() {
    let group1Info = LockmanConcurrencyLimitedInfo(
      actionId: "group1_action",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let group2Info = LockmanConcurrencyLimitedInfo(
      actionId: "group2_action",
      group: TestConcurrencyGroup(id: "group2", limit: .limited(1))
    )

    // Both should succeed as they're in different groups
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: group1Info)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Info), .success)
    strategy.lock(boundaryId: boundaryId, info: group2Info)

    // Additional locks in each group should fail
    let group1Extra = LockmanConcurrencyLimitedInfo(
      actionId: "group1_extra",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let group2Extra = LockmanConcurrencyLimitedInfo(
      actionId: "group2_extra",
      group: TestConcurrencyGroup(id: "group2", limit: .limited(1))
    )

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: group1Extra) else {
      XCTFail("Expected .cancel for group1 extra")
      return
    }

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: group2Extra) else {
      XCTFail("Expected .cancel for group2 extra")
      return
    }
  }

  // MARK: - Cleanup Operations Tests

  func testCleanUpRemovesAllLocks() {
    let infos = (0..<3).map { i in
      LockmanConcurrencyLimitedInfo(
        actionId: "test\(i)",
        group: TestConcurrencyGroup(id: "group1", limit: .limited(5))
      )
    }

    // Lock all
    for info in infos {
      strategy.lock(boundaryId: boundaryId, info: info)
    }

    strategy.cleanUp()

    // All should be able to lock again
    for info in infos {
      XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    }
  }

  func testCleanUpBoundaryRemovesOnlySpecifiedBoundary() {
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")

    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "test1",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    // Lock on both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Clean up only boundary1
    strategy.cleanUp(boundaryId: boundary1)

    // boundary1 should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info1), .success)

    // boundary2 should still have the lock
    guard case .cancel = strategy.canLock(boundaryId: boundary2, info: info1) else {
      XCTFail("Expected .cancel for boundary2")
      return
    }
  }

  func testStateEmptyAfterGlobalCleanup() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    strategy.lock(boundaryId: boundaryId, info: info)
    strategy.cleanUp()

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertTrue(currentLocks.isEmpty, "Strategy should have no locks after cleanup")
  }

  // MARK: - getCurrentLocks Tests

  func testGetCurrentLocksReturnsEmptyWhenNoLocks() {
    let currentLocks = strategy.getCurrentLocks()
    XCTAssertTrue(currentLocks.isEmpty)
  }

  func testGetCurrentLocksReturnsCorrectBoundaryMapping() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    strategy.lock(boundaryId: boundaryId, info: info)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let boundaryKey = currentLocks.keys.first!
    XCTAssertEqual(String(describing: boundaryKey), String(describing: boundaryId))

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 1)

    guard let lockInfo = lockInfos.first as? LockmanConcurrencyLimitedInfo else {
      XCTFail("Expected LockmanConcurrencyLimitedInfo")
      return
    }

    XCTAssertEqual(lockInfo.actionId, "test")
    XCTAssertEqual(lockInfo.concurrencyId, "group1")
  }

  func testGetCurrentLocksWithMultipleConcurrencyGroups() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "test1",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group2", limit: .limited(2))
    )

    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 2)

    let actionIds = lockInfos.compactMap { ($0 as? LockmanConcurrencyLimitedInfo)?.actionId }
    XCTAssertTrue(actionIds.contains("test1"))
    XCTAssertTrue(actionIds.contains("test2"))
  }

  // MARK: - Error Generation Tests

  func testConcurrencyLimitReachedErrorContainsCorrectInformation() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )

    // Lock once to reach limit
    strategy.lock(boundaryId: boundaryId, info: info)

    // Second attempt should generate error
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(1))
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let concurrencyError = error as? LockmanConcurrencyLimitedError else {
      XCTFail("Expected LockmanConcurrencyLimitedError")
      return
    }

    guard
      case .concurrencyLimitReached(let errorInfo, let errorBoundaryId, let currentCount) =
        concurrencyError
    else {
      XCTFail("Expected concurrencyLimitReached case")
      return
    }

    XCTAssertEqual(errorInfo.actionId, "test2")
    XCTAssertEqual(errorInfo.concurrencyId, "group1")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertEqual(currentCount, 1)
  }

  func testErrorMessageIncludesLimitDetails() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )

    // Lock twice to reach limit
    strategy.lock(boundaryId: boundaryId, info: info)
    let info1_5 = LockmanConcurrencyLimitedInfo(
      actionId: "test1_5",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    strategy.lock(boundaryId: boundaryId, info: info1_5)

    // Third attempt should generate error
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "test2",
      group: TestConcurrencyGroup(id: "group1", limit: .limited(2))
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    let errorDescription = error.localizedDescription
    XCTAssertTrue(errorDescription.contains("group1"))
    XCTAssertTrue(errorDescription.contains("2/2") || errorDescription.contains("2"))
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCanLockCallsOnSameConcurrencyGroup() {
    let expectation = XCTestExpectation(description: "Concurrent canLock calls")
    expectation.expectedFulfillmentCount = 10

    let queue = DispatchQueue.global(qos: .default)
    let strategy = self.strategy!
    let boundaryId = self.boundaryId!

    for i in 0..<10 {
      queue.async {
        let info = LockmanConcurrencyLimitedInfo(
          actionId: "test\(i)",
          group: TestConcurrencyGroup(id: "group1", limit: .limited(5))
        )

        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        // Result should be either success or cancel, never crash
        switch result {
        case .success, .cancel:
          break  // Expected outcomes
        case .successWithPrecedingCancellation:
          XCTFail("Unexpected .successWithPrecedingCancellation in concurrency limit strategy")
        }

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  // MARK: - Helper Types

  struct TestConcurrencyGroup: LockmanConcurrencyGroup {
    let id: String
    let limit: LockmanConcurrencyLimit
  }
}
