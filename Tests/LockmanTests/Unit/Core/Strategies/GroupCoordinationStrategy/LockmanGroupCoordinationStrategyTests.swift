import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Simplified LockmanGroupCoordinationStrategy tests with 3-phase approach
// ✅ 13 test methods covering all coordination roles and group policies
// ✅ Phase 1: Basic strategy functionality (initialization, canLock, lock, unlock)
// ✅ Phase 2: Coordination role testing (.none, .leader, .member) with various policies
// ✅ Phase 3: Integration testing and edge cases

final class LockmanGroupCoordinationStrategyTests: XCTestCase {

  private var strategy: LockmanGroupCoordinationStrategy!

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    strategy = LockmanGroupCoordinationStrategy()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    strategy = nil
  }

  // MARK: - Phase 1: Basic Strategy Functionality

  func testLockmanGroupCoordinationStrategyInitialization() {
    // Test strategy initialization and properties
    let strategy = LockmanGroupCoordinationStrategy()

    // Verify strategyId
    XCTAssertEqual(strategy.strategyId, .groupCoordination)
    XCTAssertEqual(strategy.strategyId, LockmanGroupCoordinationStrategy.makeStrategyId())

    // Test shared instance
    let sharedStrategy = LockmanGroupCoordinationStrategy.shared
    XCTAssertNotNil(sharedStrategy)
    XCTAssertEqual(sharedStrategy.strategyId, .groupCoordination)

    // Test that different instances have same strategyId but different references
    XCTAssertFalse(strategy === sharedStrategy)
    XCTAssertEqual(strategy.strategyId, sharedStrategy.strategyId)
  }

  func testLockmanGroupCoordinationStrategyTypeAlias() {
    // Test that the strategy's Info type matches expected type
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupId: "testGroup",
      coordinationRole: .none
    )
    XCTAssertTrue(info is LockmanGroupCoordinationStrategy.I)

    // Test that the typealias is correctly defined
    func testGenericFunction<S: LockmanStrategy>(_ strategy: S, info: S.I) -> Bool {
      return info is LockmanGroupCoordinatedInfo
    }

    let result = testGenericFunction(strategy, info: info)
    XCTAssertTrue(result)
  }

  func testLockmanGroupCoordinationStrategyBasicCanLock() {
    // Test basic canLock functionality
    let boundaryId = "testBoundary"

    // Test .none role (always succeeds)
    let noneInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("noneAction"),
      groupId: "testGroup",
      coordinationRole: .none
    )
    let noneResult = strategy.canLock(boundaryId: boundaryId, info: noneInfo)
    XCTAssertEqual(noneResult, .success)

    // Test .leader role with emptyGroup policy (succeeds when no locks)
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leaderAction"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    let leaderResult = strategy.canLock(boundaryId: boundaryId, info: leaderInfo)
    XCTAssertEqual(leaderResult, .success)
  }

  func testLockmanGroupCoordinationStrategyBasicLockUnlock() {
    // Test basic lock-unlock cycle
    let boundaryId = "lockUnlockBoundary"
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )

    // Initial state - should be able to lock
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)

    // Lock the resource
    strategy.lock(boundaryId: boundaryId, info: info)

    // After lock - same action should fail (duplicate action prevention)
    let secondInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: secondInfo) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for duplicate action")
    }

    // Unlock the resource
    strategy.unlock(boundaryId: boundaryId, info: info)

    // After unlock - should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: secondInfo), .success)
  }

  func testLockmanGroupCoordinationStrategyCleanup() {
    // Test cleanup functionality
    let boundaryId = "cleanupBoundary"
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )

    // Lock and verify it's locked
    strategy.lock(boundaryId: boundaryId, info: info)
    let secondInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
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

  // MARK: - Phase 2: Coordination Role Testing

  func testLockmanGroupCoordinationStrategyNoneRole() {
    // Test .none role behavior (no coordination)
    let boundaryId = "noneRoleBoundary"
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("noneAction1"),
      groupId: "testGroup",
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("noneAction2"),
      groupId: "testGroup",
      coordinationRole: .none
    )

    // First lock
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second lock with different action - should succeed (.none has no coordination)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Both actions can coexist
    XCTAssertTrue(true)  // Test completed successfully
  }

  func testLockmanGroupCoordinationStrategyLeaderEmptyGroupPolicy() {
    // Test .leader(.emptyGroup) policy behavior
    let boundaryId = "emptyGroupBoundary"
    let leader1Info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader1"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    let leader2Info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader2"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )

    // First leader should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: leader1Info)

    // Second leader should fail (group not empty)
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: leader2Info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for emptyGroup policy")
    }

    // Unlock first and try second again
    strategy.unlock(boundaryId: boundaryId, info: leader1Info)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader2Info), .success)
  }

  func testLockmanGroupCoordinationStrategyLeaderWithoutMembersPolicy() {
    // Test .leader(.withoutMembers) policy behavior
    let boundaryId = "withoutMembersBoundary"
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader"),
      groupId: "testGroup",
      coordinationRole: .leader(.withoutMembers)
    )
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "testGroup",
      coordinationRole: .member
    )

    // Leader should succeed initially
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leaderInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Member should succeed (can join with leader)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: memberInfo)

    // Another leader should fail (has members)
    let leader2Info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader2"),
      groupId: "testGroup",
      coordinationRole: .leader(.withoutMembers)
    )
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: leader2Info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for withoutMembers policy with active member")
    }
  }

  func testLockmanGroupCoordinationStrategyLeaderWithoutLeaderPolicy() {
    // Test .leader(.withoutLeader) policy behavior
    let boundaryId = "withoutLeaderBoundary"
    let leader1Info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader1"),
      groupId: "testGroup",
      coordinationRole: .leader(.withoutLeader)
    )
    let leader2Info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader2"),
      groupId: "testGroup",
      coordinationRole: .leader(.withoutLeader)
    )

    // First leader should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: leader1Info)

    // Second leader should fail (already has leader)
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: leader2Info) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for withoutLeader policy")
    }
  }

  func testLockmanGroupCoordinationStrategyMemberRole() {
    // Test .member role behavior
    let boundaryId = "memberRoleBoundary"
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "testGroup",
      coordinationRole: .member
    )
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader"),
      groupId: "testGroup",
      coordinationRole: .leader(.withoutLeader)
    )

    // Member should fail when group is empty
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: memberInfo) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for member in empty group")
    }

    // Lock a leader first
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Now member should succeed (group has active participants)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
  }

  // MARK: - Phase 3: Integration and Edge Cases

  func testLockmanGroupCoordinationStrategyMultipleBoundaries() {
    // Test that different boundaries are isolated from each other
    let boundary1 = "boundary1"
    let boundary2 = "boundary2"
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )

    // Lock in boundary1
    strategy.lock(boundaryId: boundary1, info: info)

    // Should be able to lock same group in boundary2
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info2), .success)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Both boundaries should now have the same action locked
    let info3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    if case .cancel = strategy.canLock(boundaryId: boundary1, info: info3) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for boundary1")
    }
  }

  func testLockmanGroupCoordinationStrategyBoundarySpecificCleanup() {
    // Test boundary-specific cleanup
    let boundary1 = "cleanupBoundary1"
    let boundary2 = "cleanupBoundary2"
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group2",
      coordinationRole: .leader(.emptyGroup)
    )

    // Add locks to both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Cleanup boundary1 only
    strategy.cleanUp(boundaryId: boundary1)

    // Should be able to lock in boundary1 again
    let testInfo1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: testInfo1), .success)

    // boundary2 should still be locked
    let testInfo2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group2",
      coordinationRole: .leader(.emptyGroup)
    )
    if case .cancel = strategy.canLock(boundaryId: boundary2, info: testInfo2) {
      XCTAssertTrue(true)  // Expected locked state
    } else {
      XCTFail("Expected locked state")
    }
  }

  func testLockmanGroupCoordinationStrategyMultipleGroups() {
    // Test actions with multiple group IDs
    let boundaryId = "multiGroupBoundary"
    let multiGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiAction"),
      groupIds: Set(["group1", "group2"]),
      coordinationRole: .none
    )

    // Should succeed with multiple groups
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiGroupInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: multiGroupInfo)

    // Same action in any of the groups should fail
    let conflictInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiAction"),
      groupId: "group1",
      coordinationRole: .none
    )
    if case .cancel = strategy.canLock(boundaryId: boundaryId, info: conflictInfo) {
      XCTAssertTrue(true)  // Expected cancel result
    } else {
      XCTFail("Expected cancel result for same action in overlapping group")
    }
  }

  func testLockmanGroupCoordinationStrategyTypeErasure() {
    // Test strategy through type-erased interface
    let anyStrategy: any LockmanStrategy<LockmanGroupCoordinatedInfo> = strategy
    let boundaryId = "typeErasureBoundary"
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )

    // Test through type-erased interface
    XCTAssertEqual(anyStrategy.canLock(boundaryId: boundaryId, info: info), .success)
    anyStrategy.lock(boundaryId: boundaryId, info: info)

    // Verify lock is active
    let testInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
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
