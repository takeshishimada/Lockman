import XCTest

@testable import Lockman

/// Unit tests for LockmanPriorityBasedStrategy
///
/// Tests the locking strategy that enforces priority-based execution semantics
/// with configurable concurrency behavior and preemption capabilities.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Strategy Initialization and Configuration
/// - [ ] Shared singleton instance access and consistency
/// - [ ] Custom instance creation and strategyId uniqueness
/// - [ ] makeStrategyId() returns correct "priorityBased" identifier
/// - [ ] Thread-safe state container initialization
/// - [ ] @unchecked Sendable conformance verification
///
/// ### Priority System Core Logic
/// - [ ] High priority (.high) can cancel low/none priority actions
/// - [ ] Low priority (.low) can cancel none priority actions
/// - [ ] None priority (.none) bypasses priority system entirely
/// - [ ] Priority comparison hierarchy validation
/// - [ ] Priority level precedence enforcement
///
/// ### canLock Method - None Priority Bypass
/// - [ ] Actions with .none priority always return .success
/// - [ ] No state modification during canLock with .none priority
/// - [ ] Bypasses all priority system logic for .none
/// - [ ] Consistent behavior regardless of existing locks
///
/// ### canLock Method - Priority vs Non-Priority
/// - [ ] Priority actions always succeed against non-priority actions
/// - [ ] Non-priority actions yield to any priority action
/// - [ ] Proper conflict resolution between priority and none types
/// - [ ] State consistency after priority preemption
///
/// ### canLock Method - Different Priority Levels
/// - [ ] High priority wins against low priority
/// - [ ] Low priority wins against none priority
/// - [ ] Higher priority actions can preempt lower priority
/// - [ ] Proper LockmanPriorityBasedError.precedingActionCancelled creation
/// - [ ] Error contains correct cancelled action information
///
/// ### canLock Method - Same Priority Level with ConcurrencyBehavior
/// - [ ] Exclusive behavior: existing action continues, new action fails
/// - [ ] Replaceable behavior: existing action canceled, new action succeeds
/// - [ ] Most recent priority action's behavior determines outcome
/// - [ ] OrderedDictionary insertion order preservation
/// - [ ] Proper same-action blocking logic
///
/// ### Same Action Conflict Resolution
/// - [ ] Same actionId with same uniqueId handling
/// - [ ] Same actionId with different uniqueId handling
/// - [ ] Exclusive same-action always fails
/// - [ ] Replaceable same-action behavior
/// - [ ] Error creation for same-action conflicts
///
/// ### lock Method Implementation
/// - [ ] Successfully adds lock to state after canLock success
/// - [ ] Preserves exact info instance with uniqueId
/// - [ ] Thread-safe lock addition across concurrent calls
/// - [ ] State consistency after multiple lock operations
/// - [ ] Priority order maintenance in state
///
/// ### unlock Method Implementation
/// - [ ] Successfully removes specific lock instance by uniqueId
/// - [ ] Only removes exact info instance that was locked
/// - [ ] Other locks with same actionId remain unaffected
/// - [ ] Thread-safe unlock operations
/// - [ ] Priority order consistency after unlock
/// - [ ] State cleanup when boundary becomes empty
///
/// ### Precedence Cancellation Logic
/// - [ ] successWithPrecedingCancellation result creation
/// - [ ] Proper LockmanPrecedingCancellationError propagation
/// - [ ] Cancelled action information preservation
/// - [ ] Multiple actions cancellation scenarios
/// - [ ] Priority chain reaction effects
///
/// ### Global Cleanup Operations
/// - [ ] cleanUp() removes all locks across all boundaries
/// - [ ] cleanUp(boundaryId:) removes only specified boundary locks
/// - [ ] Other boundaries remain unaffected by boundary-specific cleanup
/// - [ ] State is empty after global cleanup
/// - [ ] Priority order reset after cleanup
///
/// ### getCurrentLocks Debug Information
/// - [ ] Returns empty dictionary when no locks exist
/// - [ ] Returns correct boundary-to-locks mapping
/// - [ ] Priority order preservation in returned values
/// - [ ] Type-erased LockmanInfo instances in returned values
/// - [ ] Thread-safe access to current locks information
///
/// ### Logging Integration
/// - [ ] LockmanLogger.logCanLock called with correct parameters
/// - [ ] Proper strategy name "PriorityBased" in logs
/// - [ ] Correct failure reason messages for priority conflicts
/// - [ ] Cancelled action information in logs
/// - [ ] Log messages for different priority scenarios
///
/// ### Error Handling and Edge Cases
/// - [ ] Graceful handling of empty actionId strings
/// - [ ] Behavior with complex priority hierarchies
/// - [ ] State consistency under high concurrent load
/// - [ ] Memory management for long-running priority locks
/// - [ ] Edge cases in priority comparison logic
///
/// ### Thread Safety Verification
/// - [ ] Concurrent canLock calls with different priorities
/// - [ ] Concurrent lock/unlock operations with priority conflicts
/// - [ ] Concurrent cleanup operations
/// - [ ] State consistency under priority race conditions
/// - [ ] LockmanState thread-safety delegation
///
/// ### Protocol Conformance
/// - [ ] LockmanStrategy protocol implementation completeness
/// - [ ] Correct typealias I = LockmanPriorityBasedInfo
/// - [ ] All required protocol methods implemented
/// - [ ] Generic boundary type handling
/// - [ ] LockmanPrecedingCancellationError proper usage
///
final class LockmanPriorityBasedStrategyTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Properties

  var strategy: LockmanPriorityBasedStrategy = LockmanPriorityBasedStrategy.shared
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
    let instance1 = LockmanPriorityBasedStrategy.shared
    let instance2 = LockmanPriorityBasedStrategy.shared
    XCTAssertTrue(instance1 === instance2, "Shared instance should be the same object")
  }

  func testCustomInstanceCreation() {
    let customStrategy = LockmanPriorityBasedStrategy()
    XCTAssertFalse(customStrategy === strategy, "Custom instance should be different from shared")
    XCTAssertEqual(
      customStrategy.strategyId, strategy.strategyId, "Strategy IDs should be the same")
  }

  func testMakeStrategyIdReturnsCorrectIdentifier() {
    let strategyId = LockmanPriorityBasedStrategy.makeStrategyId()
    XCTAssertEqual(strategyId.value, "priorityBased")
  }

  func testStrategyIdConsistencyAcrossMultipleCalls() {
    let id1 = LockmanPriorityBasedStrategy.makeStrategyId()
    let id2 = LockmanPriorityBasedStrategy.makeStrategyId()
    XCTAssertEqual(id1, id2)
  }

  func testInstanceStrategyIdMatchesStaticVersion() {
    let staticId = LockmanPriorityBasedStrategy.makeStrategyId()
    let instanceId = strategy.strategyId
    XCTAssertEqual(staticId, instanceId)
  }

  // MARK: - Priority System Core Logic Tests

  func testNonePriorityBypassesPrioritySystem() {
    let info = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .none
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testNonePriorityAlwaysSucceedsRegardlessOfExistingLocks() {
    // Lock a high priority action first
    let highPriorityInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: highPriorityInfo)

    // None priority should still succeed
    let noneInfo = LockmanPriorityBasedInfo(
      actionId: "none",
      priority: .none
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: noneInfo)
    XCTAssertEqual(result, .success)
  }

  func testPriorityComparison() {
    // Test priority hierarchy: none < low < high
    XCTAssertTrue(LockmanPriorityBasedInfo.Priority.none < .low(.exclusive))
    XCTAssertTrue(LockmanPriorityBasedInfo.Priority.low(.exclusive) < .high(.exclusive))
    XCTAssertTrue(LockmanPriorityBasedInfo.Priority.none < .high(.exclusive))
  }

  func testPriorityEquality() {
    // Same priority levels should be equal regardless of behavior
    XCTAssertEqual(LockmanPriorityBasedInfo.Priority.high(.exclusive), .high(.replaceable))
    XCTAssertEqual(LockmanPriorityBasedInfo.Priority.low(.exclusive), .low(.replaceable))
    XCTAssertEqual(LockmanPriorityBasedInfo.Priority.none, .none)
  }

  // MARK: - canLock None Priority Tests

  func testNonePriorityNoStateModificationDuringCanLock() {
    let info = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .none
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

  func testNonePriorityConsistentBehavior() {
    let info = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .none
    )

    // Should always succeed regardless of how many times called
    for _ in 0..<10 {
      let result = strategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(result, .success)
    }
  }

  // MARK: - Priority vs Non-Priority Tests

  func testPriorityActionsSucceedAgainstNonPriorityActions() {
    // Lock none priority action first
    let noneInfo = LockmanPriorityBasedInfo(
      actionId: "none",
      priority: .none
    )
    strategy.lock(boundaryId: boundaryId, info: noneInfo)

    // Priority action should succeed
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "priority",
      priority: .low(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: priorityInfo)
    XCTAssertEqual(result, .success)
  }

  func testNonPriorityActionsYieldToAnyPriorityAction() {
    // Lock priority action first
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "priority",
      priority: .low(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: priorityInfo)

    // None priority action should still succeed (they don't participate in conflicts)
    let noneInfo = LockmanPriorityBasedInfo(
      actionId: "none",
      priority: .none
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: noneInfo)
    XCTAssertEqual(result, .success)
  }

  // MARK: - Different Priority Levels Tests

  func testHighPriorityWinsAgainstLowPriority() {
    // Lock low priority action first
    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: lowInfo)

    // High priority should be able to preempt
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: highInfo)

    guard case .successWithPrecedingCancellation(let error) = result else {
      XCTFail("Expected .successWithPrecedingCancellation, got \(result)")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError, got \(type(of: error))")
      return
    }

    guard case .precedingActionCancelled(let cancelledInfo, _) = priorityError else {
      XCTFail("Expected precedingActionCancelled case")
      return
    }

    XCTAssertEqual(cancelledInfo.actionId, "low")
  }

  func testLowPriorityFailsAgainstHighPriority() {
    // Lock high priority action first
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: highInfo)

    // Low priority should fail
    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: lowInfo)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError, got \(type(of: error))")
      return
    }

    guard case .higherPriorityExists(let requestedInfo, let existingInfo, _) = priorityError else {
      XCTFail("Expected higherPriorityExists case")
      return
    }

    XCTAssertEqual(requestedInfo.actionId, "low")
    XCTAssertEqual(existingInfo.actionId, "high")
  }

  // MARK: - Same Priority Level with ConcurrencyBehavior Tests

  func testSamePriorityExclusiveBehaviorBlocksNewAction() {
    // Lock exclusive action first
    let exclusiveInfo = LockmanPriorityBasedInfo(
      actionId: "exclusive",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: exclusiveInfo)

    // Same priority action should be blocked
    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.replaceable)  // Note: existing action's behavior determines outcome
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: newInfo)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError, got \(type(of: error))")
      return
    }

    guard case .samePriorityConflict(let requestedInfo, let existingInfo, _) = priorityError else {
      XCTFail("Expected samePriorityConflict case")
      return
    }

    XCTAssertEqual(requestedInfo.actionId, "new")
    XCTAssertEqual(existingInfo.actionId, "exclusive")
  }

  func testSamePriorityReplaceableBehaviorAllowsPreemption() {
    // Lock replaceable action first
    let replaceableInfo = LockmanPriorityBasedInfo(
      actionId: "replaceable",
      priority: .high(.replaceable)
    )
    strategy.lock(boundaryId: boundaryId, info: replaceableInfo)

    // Same priority action should be able to replace
    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.exclusive)  // Note: existing action's behavior determines outcome
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: newInfo)

    guard case .successWithPrecedingCancellation(let error) = result else {
      XCTFail("Expected .successWithPrecedingCancellation, got \(result)")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError, got \(type(of: error))")
      return
    }

    guard case .precedingActionCancelled(let cancelledInfo, _) = priorityError else {
      XCTFail("Expected precedingActionCancelled case")
      return
    }

    XCTAssertEqual(cancelledInfo.actionId, "replaceable")
  }

  func testMostRecentPriorityActionDeterminesBehavior() {
    // Lock first priority action
    let firstInfo = LockmanPriorityBasedInfo(
      actionId: "first",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: firstInfo)

    // Lock second priority action with replaceable behavior
    let secondInfo = LockmanPriorityBasedInfo(
      actionId: "second",
      priority: .high(.replaceable)
    )
    // This should succeed by replacing the first
    guard
      case .successWithPrecedingCancellation = strategy.canLock(
        boundaryId: boundaryId, info: secondInfo)
    else {
      XCTFail("Second action should be able to replace first")
      return
    }
    strategy.lock(boundaryId: boundaryId, info: secondInfo)

    // Third action should be determined by second action's replaceable behavior
    let thirdInfo = LockmanPriorityBasedInfo(
      actionId: "third",
      priority: .high(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: thirdInfo)

    // Should succeed with cancellation since second action is replaceable
    guard case .successWithPrecedingCancellation = result else {
      XCTFail(
        "Expected .successWithPrecedingCancellation based on second action's replaceable behavior")
      return
    }
  }

  // MARK: - Lock/Unlock Implementation Tests

  func testLockAfterCanLockSuccess() {
    let info = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .high(.exclusive)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    strategy.lock(boundaryId: boundaryId, info: info)

    // Verify lock is active by trying another lock
    let info2 = LockmanPriorityBasedInfo(
      actionId: "test2",
      priority: .high(.exclusive)
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info2) else {
      XCTFail("Expected .cancel after locking exclusive action")
      return
    }
  }

  func testUnlockRemovesSpecificLockInstance() {
    let info1 = LockmanPriorityBasedInfo(
      actionId: "action1",
      priority: .high(.exclusive)
    )
    let info2 = LockmanPriorityBasedInfo(
      actionId: "action2",
      priority: .low(.exclusive)
    )

    // Lock both actions (different priorities)
    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Unlock first action
    strategy.unlock(boundaryId: boundaryId, info: info1)

    // Second action should still be there (action2 is lower priority)
    let info3 = LockmanPriorityBasedInfo(
      actionId: "action3",
      priority: .low(.exclusive)
    )
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: info3) else {
      XCTFail("Expected .cancel because action2 should still be locked")
      return
    }
  }

  func testPriorityOrderMaintenanceInState() {
    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.replaceable)
    )
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.replaceable)
    )

    // Lock low priority first
    strategy.lock(boundaryId: boundaryId, info: lowInfo)

    // Then high priority (should cause preemption)
    guard
      case .successWithPrecedingCancellation = strategy.canLock(
        boundaryId: boundaryId, info: highInfo)
    else {
      XCTFail("High priority should preempt low priority")
      return
    }
    strategy.lock(boundaryId: boundaryId, info: highInfo)

    // Verify high priority is now active
    let anotherHighInfo = LockmanPriorityBasedInfo(
      actionId: "anotherHigh",
      priority: .high(.exclusive)
    )

    // This should be determined by the current high priority action's replaceable behavior
    let result = strategy.canLock(boundaryId: boundaryId, info: anotherHighInfo)
    guard case .successWithPrecedingCancellation = result else {
      XCTFail("Expected preemption based on existing high priority action's replaceable behavior")
      return
    }
  }

  // MARK: - Cleanup Tests

  func testCleanUpRemovesAllLocks() {
    let infos = [
      LockmanPriorityBasedInfo(actionId: "test1", priority: .high(.exclusive)),
      LockmanPriorityBasedInfo(actionId: "test2", priority: .low(.exclusive)),
      LockmanPriorityBasedInfo(actionId: "test3", priority: .none),
    ]

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

    let info1 = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .high(.exclusive)
    )
    let info2 = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .high(.exclusive)
    )

    // Lock on both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Clean up only boundary1
    strategy.cleanUp(boundaryId: boundary1)

    // boundary1 should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info1), .success)

    // boundary2 should still have the lock
    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.exclusive)
    )
    guard case .cancel = strategy.canLock(boundaryId: boundary2, info: newInfo) else {
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
    let info = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .high(.exclusive)
    )

    strategy.lock(boundaryId: boundaryId, info: info)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let boundaryKey = currentLocks.keys.first!
    XCTAssertEqual(String(describing: boundaryKey), String(describing: boundaryId))

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 1)

    guard let lockInfo = lockInfos.first as? LockmanPriorityBasedInfo else {
      XCTFail("Expected LockmanPriorityBasedInfo")
      return
    }

    XCTAssertEqual(lockInfo.actionId, "test")
    XCTAssertEqual(lockInfo.priority, .high(.exclusive))
  }

  func testGetCurrentLocksPreservesPriorityOrder() {
    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.exclusive)
    )
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    let noneInfo = LockmanPriorityBasedInfo(
      actionId: "none",
      priority: .none
    )

    // Lock in different order
    strategy.lock(boundaryId: boundaryId, info: lowInfo)
    strategy.lock(boundaryId: boundaryId, info: noneInfo)
    strategy.lock(boundaryId: boundaryId, info: highInfo)

    let currentLocks = strategy.getCurrentLocks()
    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 3)

    let actionIds = lockInfos.compactMap { ($0 as? LockmanPriorityBasedInfo)?.actionId }
    XCTAssertTrue(actionIds.contains("low"))
    XCTAssertTrue(actionIds.contains("high"))
    XCTAssertTrue(actionIds.contains("none"))
  }

  // MARK: - Error Generation Tests

  func testHigherPriorityExistsErrorContainsCorrectInformation() {
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: highInfo)

    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: lowInfo)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError")
      return
    }

    guard
      case .higherPriorityExists(let requestedInfo, let existingInfo, let errorBoundaryId) =
        priorityError
    else {
      XCTFail("Expected higherPriorityExists case")
      return
    }

    XCTAssertEqual(requestedInfo.actionId, "low")
    XCTAssertEqual(existingInfo.actionId, "high")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
  }

  func testSamePriorityConflictErrorContainsCorrectInformation() {
    let exclusiveInfo = LockmanPriorityBasedInfo(
      actionId: "exclusive",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: exclusiveInfo)

    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.replaceable)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: newInfo)

    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError")
      return
    }

    guard
      case .samePriorityConflict(let requestedInfo, let existingInfo, let errorBoundaryId) =
        priorityError
    else {
      XCTFail("Expected samePriorityConflict case")
      return
    }

    XCTAssertEqual(requestedInfo.actionId, "new")
    XCTAssertEqual(existingInfo.actionId, "exclusive")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
  }

  func testPrecedingActionCancelledErrorContainsCorrectInformation() {
    let replaceableInfo = LockmanPriorityBasedInfo(
      actionId: "replaceable",
      priority: .low(.replaceable)
    )
    strategy.lock(boundaryId: boundaryId, info: replaceableInfo)

    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )
    let result = strategy.canLock(boundaryId: boundaryId, info: highInfo)

    guard case .successWithPrecedingCancellation(let error) = result else {
      XCTFail("Expected .successWithPrecedingCancellation")
      return
    }

    guard let priorityError = error as? LockmanPriorityBasedError else {
      XCTFail("Expected LockmanPriorityBasedError")
      return
    }

    guard case .precedingActionCancelled(let cancelledInfo, let errorBoundaryId) = priorityError
    else {
      XCTFail("Expected precedingActionCancelled case")
      return
    }

    XCTAssertEqual(cancelledInfo.actionId, "replaceable")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
  }

  // MARK: - Thread Safety Tests

  func testConcurrentCanLockCallsWithDifferentPriorities() {
    let expectation = XCTestExpectation(description: "Concurrent canLock calls")
    expectation.expectedFulfillmentCount = 15

    let queue = DispatchQueue.global(qos: .default)
    let strategy = self.strategy
    let boundaryId = self.boundaryId

    for i in 0..<5 {
      // High priority
      queue.async {
        let info = LockmanPriorityBasedInfo(
          actionId: "high\(i)",
          priority: .high(.exclusive)
        )
        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        // Should be success, cancel, or successWithPrecedingCancellation
        switch result {
        case .success, .cancel, .successWithPrecedingCancellation:
          break  // Expected outcomes
        }
        expectation.fulfill()
      }

      // Low priority
      queue.async {
        let info = LockmanPriorityBasedInfo(
          actionId: "low\(i)",
          priority: .low(.exclusive)
        )
        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        switch result {
        case .success, .cancel, .successWithPrecedingCancellation:
          break  // Expected outcomes
        }
        expectation.fulfill()
      }

      // None priority
      queue.async {
        let info = LockmanPriorityBasedInfo(
          actionId: "none\(i)",
          priority: .none
        )
        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        XCTAssertEqual(result, .success, "None priority should always succeed")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  // MARK: - Complex Priority Scenarios Tests

  func testPriorityChainReactionEffects() {
    // Create a chain: none -> low -> high
    let noneInfo = LockmanPriorityBasedInfo(
      actionId: "none",
      priority: .none
    )
    let lowInfo = LockmanPriorityBasedInfo(
      actionId: "low",
      priority: .low(.replaceable)
    )
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "high",
      priority: .high(.exclusive)
    )

    // Lock none (doesn't participate in priority system)
    strategy.lock(boundaryId: boundaryId, info: noneInfo)

    // Lock low (should succeed)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: lowInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: lowInfo)

    // High priority should preempt low priority
    guard
      case .successWithPrecedingCancellation = strategy.canLock(
        boundaryId: boundaryId, info: highInfo)
    else {
      XCTFail("High priority should preempt low priority")
      return
    }
  }

  func testMultipleActionsWithSamePriority() {
    let info1 = LockmanPriorityBasedInfo(
      actionId: "action1",
      priority: .high(.replaceable)
    )
    let info2 = LockmanPriorityBasedInfo(
      actionId: "action2",
      priority: .high(.replaceable)
    )
    let info3 = LockmanPriorityBasedInfo(
      actionId: "action3",
      priority: .high(.exclusive)
    )

    // Lock first action
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second action should replace first (same priority, first is replaceable)
    guard
      case .successWithPrecedingCancellation = strategy.canLock(boundaryId: boundaryId, info: info2)
    else {
      XCTFail("Second action should replace first")
      return
    }
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Third action should replace second (same priority, second is replaceable)
    guard
      case .successWithPrecedingCancellation = strategy.canLock(boundaryId: boundaryId, info: info3)
    else {
      XCTFail("Third action should replace second")
      return
    }
  }

  // MARK: - Edge Cases Tests

  func testEmptyActionIdHandling() {
    let info = LockmanPriorityBasedInfo(
      actionId: "",
      priority: .high(.exclusive)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testVeryLongActionIdHandling() {
    let longActionId = String(repeating: "a", count: 1000)
    let info = LockmanPriorityBasedInfo(
      actionId: longActionId,
      priority: .high(.exclusive)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testSpecialCharactersInActionId() {
    let specialActionId = "action!@#$%^&*()_+-=[]{}|;:,.<>?"
    let info = LockmanPriorityBasedInfo(
      actionId: specialActionId,
      priority: .high(.exclusive)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  // MARK: - ConcurrencyBehavior Tests

  func testConcurrencyBehaviorExtraction() {
    XCTAssertNil(LockmanPriorityBasedInfo.Priority.none.behavior)
    XCTAssertEqual(LockmanPriorityBasedInfo.Priority.high(.exclusive).behavior, .exclusive)
    XCTAssertEqual(LockmanPriorityBasedInfo.Priority.low(.replaceable).behavior, .replaceable)
  }

  func testExclusiveBehaviorMeaning() {
    // Exclusive means "I run exclusively, block others"
    let exclusiveInfo = LockmanPriorityBasedInfo(
      actionId: "exclusive",
      priority: .high(.exclusive)
    )
    strategy.lock(boundaryId: boundaryId, info: exclusiveInfo)

    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.replaceable)
    )

    // Should be blocked by exclusive action
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: newInfo) else {
      XCTFail("Exclusive action should block new action")
      return
    }
  }

  func testReplaceableBehaviorMeaning() {
    // Replaceable means "I can be replaced by others"
    let replaceableInfo = LockmanPriorityBasedInfo(
      actionId: "replaceable",
      priority: .high(.replaceable)
    )
    strategy.lock(boundaryId: boundaryId, info: replaceableInfo)

    let newInfo = LockmanPriorityBasedInfo(
      actionId: "new",
      priority: .high(.exclusive)
    )

    // Should be able to replace
    guard
      case .successWithPrecedingCancellation = strategy.canLock(
        boundaryId: boundaryId, info: newInfo)
    else {
      XCTFail("Replaceable action should allow replacement")
      return
    }
  }
}
