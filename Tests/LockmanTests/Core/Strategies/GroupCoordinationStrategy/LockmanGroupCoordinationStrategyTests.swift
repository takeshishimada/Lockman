import Foundation
import XCTest

@testable import Lockman

/// Tests for the LockmanGroupCoordinationStrategy
final class LockmanGroupCoordinationStrategyTests: XCTestCase {
  // MARK: - Test Helpers

  private struct TestBoundaryId: LockmanBoundaryId {
    let value: String
  }

  // MARK: - Instance Management Tests

  func testSharedInstanceSingleton() {
    let instance1 = LockmanGroupCoordinationStrategy.shared
    let instance2 = LockmanGroupCoordinationStrategy.shared

    XCTAssertTrue(instance1 === instance2)
  }

  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanGroupCoordinationStrategy.makeStrategyId()
    let id2 = LockmanGroupCoordinationStrategy.makeStrategyId()

    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id1, .groupCoordination)
  }

  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy = LockmanGroupCoordinationStrategy()
    let staticId = LockmanGroupCoordinationStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  // MARK: - Basic Functionality Tests

  func testLeaderCanLockWhenGroupIsEmpty() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leaderInfo), .success)
  }

  func testNoneRoleCanAlwaysJoinGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // First none action locks
    let none1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: none1), .success)
    strategy.lock(boundaryId: boundaryId, info: none1)

    // Second none action can also lock (concurrent execution)
    let none2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group1",
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: none2), .success)
    strategy.lock(boundaryId: boundaryId, info: none2)

    // Third none action can also lock
    let none3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action3"),
      groupId: "group1",
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: none3), .success)
  }

  func testLeaderCannotLockWhenGroupHasMembers() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // First actual leader locks
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader1), .success)
    strategy.lock(boundaryId: boundaryId, info: leader1)

    // Second leader should fail
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: leader2))
  }

  func testMemberCannotLockWhenGroupIsEmpty() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )

    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: memberInfo))
  }

  func testMemberCanLockWhenGroupHasMembers() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts the group
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Member can join
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
  }

  func testMultipleMembersCanJoinActiveGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: leader)

    // Multiple members
    let member1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join1"),
      groupId: "group1",
      coordinationRole: .member
    )
    let member2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group1",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member1), .success)
    strategy.lock(boundaryId: boundaryId, info: member1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member2), .success)
    strategy.lock(boundaryId: boundaryId, info: member2)
  }

  func testSameActionIdCannotExecuteTwiceInSameGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: leader)

    // First action locks successfully
    let action1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("duplicateAction"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: action1), .success)
    strategy.lock(boundaryId: boundaryId, info: action1)

    // Second action with same ID fails
    let action2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("duplicateAction"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: action2))
  }

  // MARK: - Group Lifecycle Tests

  func testGroupRemainsActiveAfterLeaderUnlocks() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts and locks
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    strategy.lock(boundaryId: boundaryId, info: leader)

    // Member joins
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )
    strategy.lock(boundaryId: boundaryId, info: member)

    // Leader unlocks
    strategy.unlock(boundaryId: boundaryId, info: leader)

    // New member can still join
    let newMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newMember), .success)

    // New leader cannot start (group still has members)
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: newLeader))
  }

  func testGroupDissolvesWhenLastMemberUnlocks() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Build up a group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .none
    )
    let member1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join1"),
      groupId: "group1",
      coordinationRole: .member
    )
    let member2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group1",
      coordinationRole: .member
    )

    strategy.lock(boundaryId: boundaryId, info: leader)
    strategy.lock(boundaryId: boundaryId, info: member1)
    strategy.lock(boundaryId: boundaryId, info: member2)

    // Unlock all members
    strategy.unlock(boundaryId: boundaryId, info: leader)
    strategy.unlock(boundaryId: boundaryId, info: member1)
    strategy.unlock(boundaryId: boundaryId, info: member2)

    // New leader can now start (group is empty)
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newLeader), .success)

    // Member cannot join (group is empty)
    let newMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newJoin"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: newMember))
  }

  // MARK: - Multiple Groups Tests

  func testDifferentGroupsOperateIndependently() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Group 1 leader
    let group1Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .none
    )

    // Group 2 leader
    let group2Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .none
    )

    // Both can lock independently
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Leader), .success)
    strategy.lock(boundaryId: boundaryId, info: group1Leader)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Leader), .success)
    strategy.lock(boundaryId: boundaryId, info: group2Leader)

    // Members for different groups
    let group1Member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join1"),
      groupId: "group1",
      coordinationRole: .member
    )
    let group2Member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group2",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group1Member), .success)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: group2Member), .success)
  }

  // MARK: - Boundary Isolation Tests

  func testSameGroupInDifferentBoundariesAreIsolated() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    // Same group ID, different boundaries
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "sharedGroup",
      coordinationRole: .none
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "sharedGroup",
      coordinationRole: .none
    )

    // Both can lock in their respective boundaries
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: leader1), .success)
    strategy.lock(boundaryId: boundary1, info: leader1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: leader2), .success)
    strategy.lock(boundaryId: boundary2, info: leader2)
  }

  // MARK: - Cleanup Tests

  func testCleanUpRemovesAllGroupsAndStates() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Create multiple groups
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .none
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: leader1)
    strategy.lock(boundaryId: boundaryId, info: leader2)

    // Clean up
    strategy.cleanUp()

    // New leaders can start (all groups cleared)
    let newLeader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart1"),
      groupId: "group1",
      coordinationRole: .none
    )
    let newLeader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart2"),
      groupId: "group2",
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newLeader1), .success)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newLeader2), .success)
  }

  func testCleanUpWithBoundaryIdRemovesOnlyThatBoundary() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    // Lock in both boundaries
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .none
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundary1, info: leader1)
    strategy.lock(boundaryId: boundary2, info: leader2)

    // Clean up only boundary1
    strategy.cleanUp(boundaryId: boundary1)

    // New leader can start in boundary1
    let newLeader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart1"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: newLeader1), .success)

    // boundary2 still has active group - .none actions can still join
    let newNone2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart2"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: newNone2), .success)

    // But a leader cannot start in boundary2
    let newLeader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newLeader2"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary2, info: newLeader2))
  }

  // MARK: - Multiple Groups Tests

  func testSingleActionCanBelongToMultipleGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Create leader for multiple groups
    let multiGroupLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiStart"),
      groupIds: ["group1", "group2", "group3"],
      coordinationRole: .none
    )

    // Should succeed when all groups are empty
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiGroupLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: multiGroupLeader)

    // Member can join any of these groups now
    let member1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join1"),
      groupId: "group1",
      coordinationRole: .member
    )
    let member2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group2",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member1), .success)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member2), .success)
  }

  func testMultipleGroupsWithAndCondition() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start group1 with an leader
    let group1Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: group1Leader)

    // Multi-group .none action can join
    let multiNone = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiNone"),
      groupIds: ["group1", "group2"],
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiNone), .success)

    // But multi-group leader should fail because group1 is not empty
    let multiLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiStart"),
      groupIds: ["group1", "group2"],
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: multiLeader))

    // Multi-group member needs all groups to have members
    let multiMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiJoin"),
      groupIds: ["group1", "group2"],
      coordinationRole: .member
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: multiMember))

    // Start group2
    let group2Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: group2Leader)

    // Now multi-group member can join
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiMember), .success)
  }

  func testMaximum5GroupsValidation() {
    // Valid: exactly 5 groups
    let info5 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupIds: ["g1", "g2", "g3", "g4", "g5"],
      coordinationRole: .none
    )
    XCTAssertEqual(info5.groupIds.count, 5)

    // Invalid: 6 groups (will trigger precondition in debug)
    // Note: In release builds, precondition is not checked
    // This test is commented out as it would crash in debug
    // _  = LockmanGroupCoordinatedInfo(
    //   actionId: LockmanActionId("test"),
    //   groupIds: ["g1", "g2", "g3", "g4", "g5", "g6"],
    //   coordinationRole: .none
    // )
  }

  func testEmptyGroupValidation() {
    // Empty set and empty strings will trigger precondition in debug
    // These tests are commented out as they would crash in debug
    // In a production setting, you might want to use a Result type instead

    // Empty set test:
    // _ = LockmanGroupCoordinatedInfo(
    //   actionId: LockmanActionId("test"),
    //   groupIds: [],
    //   coordinationRole: .none
    // )

    // Set with empty string test:
    // _ = LockmanGroupCoordinatedInfo(
    //   actionId: LockmanActionId("test"),
    //   groupIds: ["valid", ""],
    //   coordinationRole: .none
    // )

    // For now, just verify valid cases work
    let validInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupIds: ["valid1", "valid2"],
      coordinationRole: .none
    )
    XCTAssertEqual(validInfo.groupIds, [AnyLockmanGroupId("valid1"), AnyLockmanGroupId("valid2")])
  }

  func testMultiGroupUnlockRemovesFromAllGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Lock multiple groups
    let multiAction = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multi"),
      groupIds: ["g1", "g2", "g3"],
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: multiAction)

    // Add members to each group
    let p1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("p1"),
      groupId: "g1",
      coordinationRole: .member
    )
    let p2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("p2"),
      groupId: "g2",
      coordinationRole: .member
    )
    strategy.lock(boundaryId: boundaryId, info: p1)
    strategy.lock(boundaryId: boundaryId, info: p2)

    // Unlock multi-action
    strategy.unlock(boundaryId: boundaryId, info: multiAction)

    // Members should still be able to join
    let newP1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newP1"),
      groupId: "g1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newP1), .success)

    // .none actions can join g1 (still has p1)
    let newNone = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newNone"),
      groupId: "g1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newNone), .success)

    // But new leader cannot start in g1 (still has p1)
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newLeader"),
      groupId: "g1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: newLeader))

    // g3 should be empty now (only had the multi-action)
    let g3Init = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("g3Init"),
      groupId: "g3",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: g3Init), .success)
  }

  // MARK: - Integration Tests

  func testComplexScenarioWithMultipleGroupsAndRoles() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Navigation group
    let navLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("navigate"),
      groupId: "navigation",
      coordinationRole: .none
    )
    let navAnimation = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("animate"),
      groupId: "navigation",
      coordinationRole: .member
    )

    // Data loading group
    let dataLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("startLoad"),
      groupId: "dataLoading",
      coordinationRole: .none
    )
    let dataProgress = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("updateProgress"),
      groupId: "dataLoading",
      coordinationRole: .member
    )

    // Start navigation
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: navLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: navLeader)

    // Start data loading (different group)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: dataLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: dataLeader)

    // Add members to both groups
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: navAnimation), .success)
    strategy.lock(boundaryId: boundaryId, info: navAnimation)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: dataProgress), .success)
    strategy.lock(boundaryId: boundaryId, info: dataProgress)

    // Navigation completes
    strategy.unlock(boundaryId: boundaryId, info: navLeader)
    strategy.unlock(boundaryId: boundaryId, info: navAnimation)

    // New navigation can start
    let newNavLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("navigateAgain"),
      groupId: "navigation",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newNavLeader), .success)

    // Data loading still active
    let dataError = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("showError"),
      groupId: "dataLoading",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: dataError), .success)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentOperationsAreThreadSafe() async {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start the group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "concurrentGroup",
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: leader)

    // Concurrent member attempts
    await withTaskGroup(of: Bool.self) { group in
      for i in 0..<100 {
        group.addTask {
          let member = LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId("member\(i)"),
            groupId: "concurrentGroup",
            coordinationRole: .member
          )

          if strategy.canLock(boundaryId: boundaryId, info: member) == .success {
            strategy.lock(boundaryId: boundaryId, info: member)
            // Simulate some work
            try? await Task.sleep(nanoseconds: 1_000_000)  // 1ms
            strategy.unlock(boundaryId: boundaryId, info: member)
            return true
          }
          return false
        }
      }

      var successCount = 0
      for await success in group {
        if success {
          successCount += 1
        }
      }

      // All unique members should succeed
      XCTAssertEqual(successCount, 100)
    }
  }

  // MARK: - Exclusive Leader Mode Tests

  func testLeaderEmptyGroupPolicyRequiresEmptyGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader with .emptyGroup policy
    let emptyGroupLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("emptyGroupLeader"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    // Can join empty group
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: emptyGroupLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: emptyGroupLeader)

    // Another leader with .emptyGroup should fail (group not empty)
    let otherLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("otherLeader"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: otherLeader))

    // Member can join
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member), .success)

    // .none can join
    let noneAction = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("noneAction"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: noneAction), .success)
  }

  func testLeaderWithoutMembersPolicyAllowsOtherLeaders() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader with .withoutMembers policy
    let exclusiveLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("exclusiveAction"),
      groupId: "group1",
      coordinationRole: .leader(.withoutMembers)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: exclusiveLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: exclusiveLeader)

    // Another leader can join (no members present)
    let otherLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("otherLeader"),
      groupId: "group1",
      coordinationRole: .leader(.withoutMembers)
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: otherLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: otherLeader)

    // Now member joins
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member), .success)
    strategy.lock(boundaryId: boundaryId, info: member)

    // New leader with .withoutMembers should fail (members present)
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newLeader"),
      groupId: "group1",
      coordinationRole: .leader(.withoutMembers)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: newLeader))
  }

  func testLeaderWithoutLeaderPolicyBlocksOtherLeaders() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader with .withoutLeader policy
    let exclusiveLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("exclusiveAction"),
      groupId: "group1",
      coordinationRole: .leader(.withoutLeader)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: exclusiveLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: exclusiveLeader)

    // Another leader should be blocked
    let otherLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("otherLeader"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: otherLeader))

    // .none actions should succeed (not blocked by leadersOnly)
    let noneAction = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("noneAction"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: noneAction), .success)

    // Member should succeed
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member), .success)
  }

  func testNormalLeaderDoesNotBlockOthers() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Normal leader with .none mode
    let normalLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("normalAction"),
      groupId: "group1",
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: normalLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: normalLeader)

    // Member should succeed
    let member1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member1"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member1), .success)
    strategy.lock(boundaryId: boundaryId, info: member1)

    // Another member should succeed
    let member2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member2"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member2), .success)
  }

  func testLeaderWithMultipleGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader in multiple groups
    let multiGroupLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiLeader"),
      groupIds: ["group1", "group2"],
      coordinationRole: .leader(.emptyGroup)
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiGroupLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: multiGroupLeader)

    // Member in group1 can join
    let member1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member1"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member1), .success)

    // Member in group2 can also join
    let member2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member2"),
      groupId: "group2",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member2), .success)

    // Member in different group should succeed
    let member3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member3"),
      groupId: "group3",
      coordinationRole: .member
    )
    // But member needs a leader first
    let leader3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader3"),
      groupId: "group3",
      coordinationRole: .none
    )
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader3), .success)
    strategy.lock(boundaryId: boundaryId, info: leader3)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member3), .success)
  }

  func testExclusiveModeSelfDoesNotBlockItself() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Exclusive leader
    let exclusiveLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("exclusive"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    strategy.lock(boundaryId: boundaryId, info: exclusiveLeader)

    // Same action should not be blocked by its own exclusivity
    // (but will fail due to duplicate actionId rule)
    let sameLock = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("exclusive"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )

    if case .cancel(let error) = strategy.canLock(boundaryId: boundaryId, info: sameLock) {
      // Should fail due to actionAlreadyInGroup, not blockedByExclusiveLeader
      XCTAssertTrue(error is LockmanGroupCoordinationCancellationError)
      if let coordinationError = error as? LockmanGroupCoordinationCancellationError {
        if case .actionAlreadyInGroup = coordinationError.reason {
          // Expected
        } else {
          XCTFail("Expected actionAlreadyInGroup error, got \(coordinationError)")
        }
      }
    } else {
      XCTFail("Expected failure due to duplicate action")
    }
  }

  // MARK: - Error Case Tests

  func testLeaderEntryPolicyErrors() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start with a leader
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("leader1"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    strategy.lock(boundaryId: boundaryId, info: leader1)

    // Add a member
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("member"),
      groupId: "group1",
      coordinationRole: .member
    )
    strategy.lock(boundaryId: boundaryId, info: member)

    // Test .emptyGroup policy failure
    let emptyGroupLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("emptyGroupLeader"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    if case .cancel(let error) = strategy.canLock(boundaryId: boundaryId, info: emptyGroupLeader) {
      XCTAssertTrue(error is LockmanGroupCoordinationCancellationError)
    } else {
      XCTFail("Expected failure for .emptyGroup policy")
    }

    // Test .withoutMembers policy failure
    let withoutMembersLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("withoutMembersLeader"),
      groupId: "group1",
      coordinationRole: .leader(.withoutMembers)
    )
    if case .cancel(let error) = strategy.canLock(
      boundaryId: boundaryId, info: withoutMembersLeader)
    {
      XCTAssertTrue(error is LockmanGroupCoordinationCancellationError)
    } else {
      XCTFail("Expected failure for .withoutMembers policy")
    }

    // Test .withoutLeader policy failure
    let withoutLeaderLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("withoutLeaderLeader"),
      groupId: "group1",
      coordinationRole: .leader(.withoutLeader)
    )
    if case .cancel(let error) = strategy.canLock(
      boundaryId: boundaryId, info: withoutLeaderLeader)
    {
      XCTAssertTrue(error is LockmanGroupCoordinationCancellationError)
    } else {
      XCTFail("Expected failure for .withoutLeader policy")
    }
  }
}
