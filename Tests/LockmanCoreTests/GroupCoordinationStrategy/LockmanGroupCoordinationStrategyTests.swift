import Foundation
import XCTest
@testable import LockmanCore

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

    XCTAssertTrue(instance1  === instance2)
  }

  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanGroupCoordinationStrategy.makeStrategyId()
    let id2 = LockmanGroupCoordinationStrategy.makeStrategyId()

    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id1, .groupCoordination)
  }

  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy  = LockmanGroupCoordinationStrategy()
    let staticId = LockmanGroupCoordinationStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  // MARK: - Basic Functionality Tests

  func testLeaderCanLockWhenGroupIsEmpty() {
    let strategy  = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: leaderInfo), .success)
  }

  func testLeaderCannotLockWhenGroupHasMembers() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // First leader locks
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: leader1), .success)
    strategy.lock(id: boundaryId, info: leader1)

    // Second leader should fail
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .leader
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: leader2), .failure())
  }

  func testMemberCannotLockWhenGroupIsEmpty() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: memberInfo), .failure())
  }

  func testMemberCanLockWhenGroupHasMembers() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts the group
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
    )

    strategy.lock(id: boundaryId, info: leaderInfo)

    // Member can join
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: memberInfo), .success)
  }

  func testMultipleMembersCanJoinActiveGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: leader)

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

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: member1), .success)
    strategy.lock(id: boundaryId, info: member1)

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: member2), .success)
    strategy.lock(id: boundaryId, info: member2)
  }

  func testSameActionIdCannotExecuteTwiceInSameGroup() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: leader)

    // First action locks successfully
    let action1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("duplicateAction"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: action1), .success)
    strategy.lock(id: boundaryId, info: action1)

    // Second action with same ID fails
    let action2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("duplicateAction"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: action2), .failure())
  }

  // MARK: - Group Lifecycle Tests

  func testGroupRemainsActiveAfterLeaderUnlocks() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Leader starts and locks
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: leader)

    // Member joins
    let member = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join"),
      groupId: "group1",
      coordinationRole: .member
    )
    strategy.lock(id: boundaryId, info: member)

    // Leader unlocks
    strategy.unlock(id: boundaryId, info: leader)

    // New member can still join
    let newMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("join2"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newMember), .success)

    // New leader cannot start
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newLeader), .failure())
  }

  func testGroupDissolvesWhenLastMemberUnlocks() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Build up a group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "group1",
      coordinationRole: .leader
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

    strategy.lock(id: boundaryId, info: leader)
    strategy.lock(id: boundaryId, info: member1)
    strategy.lock(id: boundaryId, info: member2)

    // Unlock all members
    strategy.unlock(id: boundaryId, info: leader)
    strategy.unlock(id: boundaryId, info: member1)
    strategy.unlock(id: boundaryId, info: member2)

    // New leader can now start (group is empty)
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart"),
      groupId: "group1",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newLeader), .success)

    // Member cannot join (group is empty)
    let newMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newJoin"),
      groupId: "group1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newMember), .failure())
  }

  // MARK: - Multiple Groups Tests

  func testDifferentGroupsOperateIndependently() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Group 1 leader
    let group1Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader
    )

    // Group 2 leader
    let group2Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .leader
    )

    // Both can lock independently
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: group1Leader), .success)
    strategy.lock(id: boundaryId, info: group1Leader)

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: group2Leader), .success)
    strategy.lock(id: boundaryId, info: group2Leader)

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

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: group1Member), .success)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: group2Member), .success)
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
      coordinationRole: .leader
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "sharedGroup",
      coordinationRole: .leader
    )

    // Both can lock in their respective boundaries
    XCTAssertEqual(strategy.canLock(id: boundary1, info: leader1), .success)
    strategy.lock(id: boundary1, info: leader1)

    XCTAssertEqual(strategy.canLock(id: boundary2, info: leader2), .success)
    strategy.lock(id: boundary2, info: leader2)
  }

  // MARK: - Cleanup Tests

  func testCleanUpRemovesAllGroupsAndStates() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Create multiple groups
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .leader
    )

    strategy.lock(id: boundaryId, info: leader1)
    strategy.lock(id: boundaryId, info: leader2)

    // Clean up
    strategy.cleanUp()

    // New leaders can start (all groups cleared)
    let newLeader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    let newLeader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart2"),
      groupId: "group2",
      coordinationRole: .leader
    )

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newLeader1), .success)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newLeader2), .success)
  }

  func testCleanUpWithBoundaryIdRemovesOnlyThatBoundary() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    // Lock in both boundaries
    let leader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    let leader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group1",
      coordinationRole: .leader
    )

    strategy.lock(id: boundary1, info: leader1)
    strategy.lock(id: boundary2, info: leader2)

    // Clean up only boundary1
    strategy.cleanUp(id: boundary1)

    // New leader can start in boundary1
    let newLeader1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundary1, info: newLeader1), .success)

    // boundary2 still has active group
    let newLeader2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newStart2"),
      groupId: "group1",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundary2, info: newLeader2), .failure())
  }

  // MARK: - Multiple Groups Tests

  func testSingleActionCanBelongToMultipleGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Create leader for multiple groups
    let multiGroupLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiStart"),
      groupIds: ["group1", "group2", "group3"],
      coordinationRole: .leader
    )

    // Should succeed when all groups are empty
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: multiGroupLeader), .success)
    strategy.lock(id: boundaryId, info: multiGroupLeader)

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

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: member1), .success)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: member2), .success)
  }

  func testMultipleGroupsWithAndCondition() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start group1 with an leader
    let group1Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: group1Leader)

    // Try to start multi-group leader (should fail because group1 is not empty)
    let multiLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiStart"),
      groupIds: ["group1", "group2"],
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: multiLeader), .failure())

    // Multi-group member needs all groups to have members
    let multiMember = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multiJoin"),
      groupIds: ["group1", "group2"],
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: multiMember), .failure())

    // Start group2
    let group2Leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start2"),
      groupId: "group2",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: group2Leader)

    // Now multi-group member can join
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: multiMember), .success)
  }

  func testMaximum5GroupsValidation() {
    // Valid: exactly 5 groups
    let info5 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupIds: ["g1", "g2", "g3", "g4", "g5"],
      coordinationRole: .leader
    )
    XCTAssertEqual(info5.groupIds.count, 5)

    // Invalid: 6 groups (will trigger precondition in debug)
    // Note: In release builds, precondition is not checked
    // This test is commented out as it would crash in debug
    // _  = LockmanGroupCoordinatedInfo(
    //   actionId: LockmanActionId("test"),
    //   groupIds: ["g1", "g2", "g3", "g4", "g5", "g6"],
    //   coordinationRole: .leader
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
    //   coordinationRole: .leader
    // )

    // Set with empty string test:
    // _ = LockmanGroupCoordinatedInfo(
    //   actionId: LockmanActionId("test"),
    //   groupIds: ["valid", ""],
    //   coordinationRole: .leader
    // )

    // For now, just verify valid cases work
    let validInfo = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupIds: ["valid1", "valid2"],
      coordinationRole: .leader
    )
    XCTAssertEqual(validInfo.groupIds, ["valid1", "valid2"])
  }

  func testMultiGroupUnlockRemovesFromAllGroups() {
    let strategy  = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Lock multiple groups
    let multiAction = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multi"),
      groupIds: ["g1", "g2", "g3"],
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: multiAction)

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
    strategy.lock(id: boundaryId, info: p1)
    strategy.lock(id: boundaryId, info: p2)

    // Unlock multi-action
    strategy.unlock(id: boundaryId, info: multiAction)

    // Members should still be able to join
    let newP1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newP1"),
      groupId: "g1",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newP1), .success)

    // But new leader cannot start in g1 (still has p1)
    let newInit = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("newInit"),
      groupId: "g1",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newInit), .failure())

    // g3 should be empty now (only had the multi-action)
    let g3Init = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("g3Init"),
      groupId: "g3",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: g3Init), .success)
  }

  // MARK: - Integration Tests

  func testComplexScenarioWithMultipleGroupsAndRoles() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Navigation group
    let navLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("navigate"),
      groupId: "navigation",
      coordinationRole: .leader
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
      coordinationRole: .leader
    )
    let dataProgress = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("updateProgress"),
      groupId: "dataLoading",
      coordinationRole: .member
    )

    // Start navigation
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: navLeader), .success)
    strategy.lock(id: boundaryId, info: navLeader)

    // Start data loading (different group)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: dataLeader), .success)
    strategy.lock(id: boundaryId, info: dataLeader)

    // Add members to both groups
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: navAnimation), .success)
    strategy.lock(id: boundaryId, info: navAnimation)

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: dataProgress), .success)
    strategy.lock(id: boundaryId, info: dataProgress)

    // Navigation completes
    strategy.unlock(id: boundaryId, info: navLeader)
    strategy.unlock(id: boundaryId, info: navAnimation)

    // New navigation can start
    let newNavLeader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("navigateAgain"),
      groupId: "navigation",
      coordinationRole: .leader
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: newNavLeader), .success)

    // Data loading still active
    let dataError = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("showError"),
      groupId: "dataLoading",
      coordinationRole: .member
    )
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: dataError), .success)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentOperationsAreThreadSafe() async {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = TestBoundaryId(value: "test")

    // Start the group
    let leader = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("start"),
      groupId: "concurrentGroup",
      coordinationRole: .leader
    )
    strategy.lock(id: boundaryId, info: leader)

    // Concurrent member attempts
    await withTaskGroup(of: Bool.self) { group in
      for i in 0 ..< 100 {
        group.addTask {
          let member = LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId("member\(i)"),
            groupId: "concurrentGroup",
            coordinationRole: .member
          )

          if strategy.canLock(id: boundaryId, info: member) == .success {
            strategy.lock(id: boundaryId, info: member)
            // Simulate some work
            try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
            strategy.unlock(id: boundaryId, info: member)
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
}
