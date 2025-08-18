import XCTest

@testable import Lockman

/// Unit tests for LockmanSingleExecutionStrategy
///
/// Tests the locking strategy that provides flexible execution control within a boundary
/// with three execution modes: none, boundary, and action.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Strategy Initialization and Configuration
/// - [ ] Shared singleton instance access and consistency
/// - [ ] Custom instance creation and strategyId uniqueness
/// - [ ] makeStrategyId() returns correct "singleExecution" identifier
/// - [ ] Thread-safe state container initialization
/// - [ ] @unchecked Sendable conformance verification
///
/// ### ExecutionMode Enum Testing
/// - [ ] ExecutionMode.none case creation and equality
/// - [ ] ExecutionMode.boundary case creation and equality
/// - [ ] ExecutionMode.action case creation and equality
/// - [ ] Sendable conformance for ExecutionMode
/// - [ ] Equatable conformance for ExecutionMode
///
/// ### canLock Method - Mode.none
/// - [ ] Always returns .success regardless of existing locks
/// - [ ] No state modification during canLock with mode.none
/// - [ ] Consistent behavior across multiple calls with mode.none
/// - [ ] Bypasses all lock checking logic for mode.none
///
/// ### canLock Method - Mode.boundary
/// - [ ] Returns .success when no locks exist in boundary
/// - [ ] Returns .cancel when any lock exists in boundary
/// - [ ] Proper LockmanSingleExecutionError.boundaryAlreadyLocked creation
/// - [ ] Error contains correct boundaryId and existing lockInfo
/// - [ ] Different action IDs are blocked within same boundary
///
/// ### canLock Method - Mode.action
/// - [ ] Returns .success when no matching actionId exists
/// - [ ] Returns .cancel when same actionId already locked
/// - [ ] Allows different actionIds within same boundary
/// - [ ] Proper LockmanSingleExecutionError.actionAlreadyRunning creation
/// - [ ] Error contains correct boundaryId and existing lockInfo
///
/// ### lock Method Implementation
/// - [ ] Successfully adds lock to state after canLock success
/// - [ ] Preserves exact info instance with uniqueId
/// - [ ] Thread-safe lock addition across concurrent calls
/// - [ ] State consistency after multiple lock operations
/// - [ ] No state modification if canLock would fail
///
/// ### unlock Method Implementation
/// - [ ] Successfully removes specific lock instance by uniqueId
/// - [ ] Only removes exact info instance that was locked
/// - [ ] Other locks with same actionId remain unaffected
/// - [ ] Thread-safe unlock operations
/// - [ ] No effect when unlocking non-existent lock
/// - [ ] State consistency after unlock operations
///
/// ### Instance-Specific Lock Management
/// - [ ] Multiple instances with same actionId get different uniqueIds
/// - [ ] Unlock only removes the specific instance that was locked
/// - [ ] Different boundaries can have same actionId simultaneously
/// - [ ] 1:1 correspondence between lock() and unlock() calls
///
/// ### Global Cleanup Operations
/// - [ ] cleanUp() removes all locks across all boundaries
/// - [ ] cleanUp(boundaryId:) removes only specified boundary locks
/// - [ ] Other boundaries remain unaffected by boundary-specific cleanup
/// - [ ] State is empty after global cleanup
/// - [ ] Thread-safe cleanup operations
///
/// ### getCurrentLocks Debug Information
/// - [ ] Returns empty dictionary when no locks exist
/// - [ ] Returns correct boundary-to-locks mapping
/// - [ ] Type-erased LockmanInfo instances in returned values
/// - [ ] Consistent snapshot of current state
/// - [ ] Thread-safe access to current locks information
///
/// ### Logging Integration
/// - [ ] LockmanLogger.logCanLock called with correct parameters
/// - [ ] Proper strategy name "SingleExecution" in logs
/// - [ ] Correct failure reason messages for boundary/action conflicts
/// - [ ] Log messages include boundaryId string representation
///
/// ### Error Handling and Edge Cases
/// - [ ] Graceful handling of empty actionId strings
/// - [ ] Behavior with nil or empty boundary identifiers
/// - [ ] State consistency under high concurrent load
/// - [ ] Memory management for long-running locks
/// - [ ] Error object lifecycle and memory safety
///
/// ### Thread Safety Verification
/// - [ ] Concurrent canLock calls on same boundary
/// - [ ] Concurrent lock/unlock operations
/// - [ ] Concurrent cleanup operations
/// - [ ] State consistency under race conditions
/// - [ ] LockmanState thread-safety delegation
///
/// ### Protocol Conformance
/// - [ ] LockmanStrategy protocol implementation completeness
/// - [ ] Correct typealias I = LockmanSingleExecutionInfo
/// - [ ] All required protocol methods implemented
/// - [ ] Generic boundary type handling
///
final class LockmanSingleExecutionStrategyTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Properties

  var strategy: LockmanSingleExecutionStrategy = LockmanSingleExecutionStrategy.shared
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
    boundaryId = TestBoundaryId("testBoundary")
  }

  // MARK: - Strategy Initialization and Configuration Tests

  func testSharedInstanceConsistency() {
    let instance1 = LockmanSingleExecutionStrategy.shared
    let instance2 = LockmanSingleExecutionStrategy.shared
    XCTAssertTrue(instance1 === instance2, "Shared instance should be the same object")
  }

  func testCustomInstanceCreation() {
    let customStrategy = LockmanSingleExecutionStrategy()
    XCTAssertFalse(customStrategy === strategy, "Custom instance should be different from shared")
    XCTAssertEqual(
      customStrategy.strategyId, strategy.strategyId, "Strategy IDs should be the same")
  }

  func testMakeStrategyIdReturnsCorrectIdentifier() {
    let strategyId = LockmanSingleExecutionStrategy.makeStrategyId()
    XCTAssertEqual(strategyId.value, "singleExecution")
  }

  func testStrategyIdConsistencyAcrossMultipleCalls() {
    let id1 = LockmanSingleExecutionStrategy.makeStrategyId()
    let id2 = LockmanSingleExecutionStrategy.makeStrategyId()
    XCTAssertEqual(id1, id2)
  }

  func testInstanceStrategyIdMatchesStaticVersion() {
    let staticId = LockmanSingleExecutionStrategy.makeStrategyId()
    let instanceId = strategy.strategyId
    XCTAssertEqual(staticId, instanceId)
  }

  // MARK: - ExecutionMode Tests

  func testExecutionModeEquality() {
    XCTAssertEqual(LockmanSingleExecutionStrategy.ExecutionMode.none, .none)
    XCTAssertEqual(LockmanSingleExecutionStrategy.ExecutionMode.boundary, .boundary)
    XCTAssertEqual(LockmanSingleExecutionStrategy.ExecutionMode.action, .action)

    XCTAssertNotEqual(LockmanSingleExecutionStrategy.ExecutionMode.none, .boundary)
    XCTAssertNotEqual(LockmanSingleExecutionStrategy.ExecutionMode.none, .action)
    XCTAssertNotEqual(LockmanSingleExecutionStrategy.ExecutionMode.boundary, .action)
  }

  // MARK: - Mode.none Tests

  func testModeNoneAlwaysReturnsSuccess() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .none
    )

    // Should always succeed regardless of existing locks
    for _ in 0..<10 {
      let result = strategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(result, .success)
    }
  }

  func testModeNoneNoStateModificationDuringCanLock() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .none
    )

    // canLock should not affect state
    let result1 = strategy.canLock(boundaryId: boundaryId, info: info)
    let result2 = strategy.canLock(boundaryId: boundaryId, info: info)

    XCTAssertEqual(result1, .success)
    XCTAssertEqual(result2, .success)

    // getCurrentLocks should still be empty since we didn't call lock()
    let currentLocks = strategy.getCurrentLocks()
    XCTAssertTrue(currentLocks.isEmpty)
  }

  func testModeNoneBypassesAllLockCheckingLogic() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "test1",
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test2",
      mode: .none
    )

    // Lock boundary mode first
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Mode.none should still succeed even with boundary locked
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
  }

  // MARK: - Mode.boundary Tests

  func testModeBoundarySuccessWhenNoLocksExist() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .boundary
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testModeBoundaryCancelWhenAnyLockExists() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "test1",
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test2",
      mode: .boundary
    )

    // Lock first
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second should fail
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let singleExecutionError = error as? LockmanSingleExecutionError else {
      XCTFail("Expected LockmanSingleExecutionError, got \(type(of: error))")
      return
    }

    guard case .boundaryAlreadyLocked(let errorBoundaryId, let existingInfo) = singleExecutionError
    else {
      XCTFail("Expected boundaryAlreadyLocked case, got \(singleExecutionError)")
      return
    }

    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertEqual(existingInfo.actionId, "test1")
  }

  func testModeBoundaryBlocksDifferentActionIds() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "action1",
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "action2",
      mode: .boundary
    )

    // Lock first action
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second action with different ID should still be blocked
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2) else {
      XCTFail("Expected .cancel for different action ID in boundary mode")
      return
    }
  }

  // MARK: - Mode.action Tests

  func testModeActionSuccessWhenNoMatchingActionId() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testModeActionCancelWhenSameActionIdExists() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )

    // Lock first
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second with same action ID should fail
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let singleExecutionError = error as? LockmanSingleExecutionError else {
      XCTFail("Expected LockmanSingleExecutionError, got \(type(of: error))")
      return
    }

    guard case .actionAlreadyRunning(let errorBoundaryId, let existingInfo) = singleExecutionError
    else {
      XCTFail("Expected actionAlreadyRunning case, got \(singleExecutionError)")
      return
    }

    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertEqual(existingInfo.actionId, "sameAction")
  }

  func testModeActionAllowsDifferentActionIds() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "action1",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "action2",
      mode: .action
    )

    // Lock first action
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second action with different ID should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
  }

  // MARK: - Lock/Unlock Tests

  func testLockAfterCanLockSuccess() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .boundary
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    strategy.lock(boundaryId: boundaryId, info: info)

    // Verify lock is active by trying another lock
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test2",
      mode: .boundary
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2) else {
      XCTFail("Expected .cancel after locking")
      return
    }
  }

  func testUnlockRemovesSpecificLockInstance() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "action1",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "action2",
      mode: .action
    )

    // Lock both actions
    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Unlock first action
    strategy.unlock(boundaryId: boundaryId, info: info1)

    // Should be able to lock action1 again
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)

    // action2 should still be locked
    let info2Again = LockmanSingleExecutionInfo(
      actionId: "action2",
      mode: .action
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2Again) else {
      XCTFail("Expected .cancel for action2 still being locked")
      return
    }
  }

  func testUnlockIsIdempotent() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )

    // Lock and unlock
    strategy.lock(boundaryId: boundaryId, info: info)
    strategy.unlock(boundaryId: boundaryId, info: info)

    // Unlock again should not crash
    strategy.unlock(boundaryId: boundaryId, info: info)

    // Should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
  }

  // MARK: - Instance-Specific Lock Management Tests

  func testMultipleInstancesWithSameActionIdGetDifferentUniqueIds() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )

    XCTAssertNotEqual(
      info1.uniqueId, info2.uniqueId, "Different instances should have different unique IDs")
    XCTAssertEqual(info1.actionId, info2.actionId, "Action IDs should be the same")
  }

  func testUnlockOnlyRemovesSpecificInstanceWithUniqueId() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )

    // Lock info1
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Create different instance with same action ID
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )

    // Unlocking info2 should not affect info1's lock
    strategy.unlock(boundaryId: boundaryId, info: info2)

    // info1 should still be locked
    let info3 = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info3) else {
      XCTFail("Expected .cancel because info1 should still be locked")
      return
    }

    // Unlocking the correct instance should work
    strategy.unlock(boundaryId: boundaryId, info: info1)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info3), .success)
  }

  func testDifferentBoundariesCanHaveSameActionIdSimultaneously() {
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")

    let info1 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )

    // Both should succeed on different boundaries
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info1), .success)
    strategy.lock(boundaryId: boundary1, info: info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info2), .success)
    strategy.lock(boundaryId: boundary2, info: info2)
  }

  // MARK: - Cleanup Tests

  func testCleanUpRemovesAllLocks() {
    let infos = (0..<3).map { i in
      LockmanSingleExecutionInfo(
        actionId: "test\(i)",
        mode: .action
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

    let info1 = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .boundary
    )

    // Lock on both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Clean up only boundary1
    strategy.cleanUp(boundaryId: boundary1)

    // boundary1 should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info1), .success)

    // boundary2 should still have the lock
    guard case .cancel = strategy.canLock(boundaryId: boundary2, info: info2) else {
      XCTFail("Expected .cancel for boundary2")
      return
    }
  }

  // MARK: - getCurrentLocks Tests

  func testGetCurrentLocksReturnsEmptyWhenNoLocks() {
    let currentLocks = strategy.getCurrentLocks()
    XCTAssertTrue(currentLocks.isEmpty)
  }

  func testGetCurrentLocksReturnsCorrectBoundaryMapping() {
    let info = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .action
    )

    strategy.lock(boundaryId: boundaryId, info: info)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let boundaryKey = currentLocks.keys.first!
    XCTAssertEqual(String(describing: boundaryKey), String(describing: boundaryId))

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 1)

    guard let lockInfo = lockInfos.first as? LockmanSingleExecutionInfo else {
      XCTFail("Expected LockmanSingleExecutionInfo")
      return
    }

    XCTAssertEqual(lockInfo.actionId, "test")
    XCTAssertEqual(lockInfo.mode, .action)
  }

  func testGetCurrentLocksWithMultipleActions() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "test1",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "test2",
      mode: .action
    )

    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 2)

    let actionIds = lockInfos.compactMap { ($0 as? LockmanSingleExecutionInfo)?.actionId }
    XCTAssertTrue(actionIds.contains("test1"))
    XCTAssertTrue(actionIds.contains("test2"))
  }

  // MARK: - Error Handling Tests

  func testBoundaryAlreadyLockedErrorContainsCorrectInformation() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "first",
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "second",
      mode: .boundary
    )

    // Lock first
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second should generate error
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let singleExecutionError = error as? LockmanSingleExecutionError else {
      XCTFail("Expected LockmanSingleExecutionError")
      return
    }

    guard case .boundaryAlreadyLocked(let errorBoundaryId, let existingInfo) = singleExecutionError
    else {
      XCTFail("Expected boundaryAlreadyLocked case")
      return
    }

    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertEqual(existingInfo.actionId, "first")

    let errorDescription = error.localizedDescription
    XCTAssertTrue(errorDescription.contains("first"))
    XCTAssertTrue(errorDescription.contains(String(describing: boundaryId)))
  }

  func testActionAlreadyRunningErrorContainsCorrectInformation() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: "sameAction",
      mode: .action
    )

    // Lock first
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second should generate error
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let singleExecutionError = error as? LockmanSingleExecutionError else {
      XCTFail("Expected LockmanSingleExecutionError")
      return
    }

    guard case .actionAlreadyRunning(let errorBoundaryId, let existingInfo) = singleExecutionError
    else {
      XCTFail("Expected actionAlreadyRunning case")
      return
    }

    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertEqual(existingInfo.actionId, "sameAction")

    let errorDescription = error.localizedDescription
    XCTAssertTrue(errorDescription.contains("sameAction"))
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCanLockCallsOnSameBoundary() {
    let expectation = XCTestExpectation(description: "Concurrent canLock calls")
    expectation.expectedFulfillmentCount = 10

    let queue = DispatchQueue.global(qos: .default)
    let strategy = self.strategy
    let boundaryId = self.boundaryId

    for i in 0..<10 {
      queue.async {
        let info = LockmanSingleExecutionInfo(
          actionId: "test\(i)",
          mode: .action
        )

        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        // Result should be either success or cancel, never crash
        switch result {
        case .success, .cancel:
          break  // Expected outcomes
        case .successWithPrecedingCancellation:
          XCTFail("Unexpected .successWithPrecedingCancellation in single execution strategy")
        }

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testConcurrentLockUnlockOperations() {
    let expectation = XCTestExpectation(description: "Concurrent lock/unlock operations")
    expectation.expectedFulfillmentCount = 20

    let queue = DispatchQueue.global(qos: .default)
    let strategy = self.strategy
    let boundaryId = self.boundaryId

    for i in 0..<10 {
      // Lock operations
      queue.async {
        let info = LockmanSingleExecutionInfo(
          actionId: "lock\(i)",
          mode: .action
        )
        strategy.lock(boundaryId: boundaryId, info: info)
        expectation.fulfill()
      }

      // Unlock operations
      queue.async {
        let info = LockmanSingleExecutionInfo(
          actionId: "unlock\(i)",
          mode: .action
        )
        strategy.unlock(boundaryId: boundaryId, info: info)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  // MARK: - Edge Cases Tests

  func testEmptyActionIdHandling() {
    let info = LockmanSingleExecutionInfo(
      actionId: "",
      mode: .action
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testLongActionIdHandling() {
    let longActionId = String(repeating: "a", count: 1000)
    let info = LockmanSingleExecutionInfo(
      actionId: longActionId,
      mode: .action
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testSpecialCharactersInActionId() {
    let specialActionId = "action!@#$%^&*()_+-=[]{}|;:,.<>?"
    let info = LockmanSingleExecutionInfo(
      actionId: specialActionId,
      mode: .action
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }
}
