import XCTest

@testable import Lockman

/// Unit tests for LockmanGroupCoordinationStrategy
///
/// Tests the strategy that coordinates actions within groups based on their roles:
/// - Leaders can execute based on their entry policy
/// - Members can only execute when their group has active participants
/// - None role participates without exclusion
final class LockmanGroupCoordinationStrategyTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Properties

  var strategy: LockmanGroupCoordinationStrategy = LockmanGroupCoordinationStrategy.shared
  var boundaryId: TestBoundaryId!

  struct TestBoundaryId: LockmanBoundaryId {
    let value: String
    init(_ value: String) {
      self.value = value
    }
  }

  enum TestGroupId: String, LockmanGroupId {
    case group1 = "group1"
    case group2 = "group2"
    case navigation = "navigation"
    case dataLoading = "dataLoading"
    case animation = "animation"
  }

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    boundaryId = TestBoundaryId("testBoundary")
  }

  // MARK: - Strategy Initialization and Configuration Tests

  func testSharedInstanceConsistency() {
    let instance1 = LockmanGroupCoordinationStrategy.shared
    let instance2 = LockmanGroupCoordinationStrategy.shared
    XCTAssertTrue(instance1 === instance2, "Shared instance should be the same object")
  }

  func testCustomInstanceCreation() {
    let customStrategy = LockmanGroupCoordinationStrategy()
    XCTAssertFalse(customStrategy === strategy, "Custom instance should be different from shared")
    XCTAssertEqual(
      customStrategy.strategyId, strategy.strategyId, "Strategy IDs should be the same")
  }

  func testMakeStrategyIdReturnsCorrectIdentifier() {
    let strategyId = LockmanGroupCoordinationStrategy.makeStrategyId()
    XCTAssertEqual(strategyId.value, "groupCoordination")
  }

  func testStrategyIdConsistencyAcrossMultipleCalls() {
    let id1 = LockmanGroupCoordinationStrategy.makeStrategyId()
    let id2 = LockmanGroupCoordinationStrategy.makeStrategyId()
    XCTAssertEqual(id1, id2)
  }

  func testInstanceStrategyIdMatchesStaticVersion() {
    let staticId = LockmanGroupCoordinationStrategy.makeStrategyId()
    let instanceId = strategy.strategyId
    XCTAssertEqual(staticId, instanceId)
  }

  // MARK: - Role.none Tests

  func testNoneRoleCanAlwaysJoinGroup() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testNoneRoleParticipatesWithoutExclusion() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "action1",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "action2",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    // Both should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
    strategy.lock(boundaryId: boundaryId, info: info2)
  }

  func testNoneRoleCanJoinWithExistingMembers() {
    // First, add a member
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    // This will fail because there are no existing participants
    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: memberInfo) else {
      XCTFail("Member should not be able to join empty group")
      return
    }

    // Add none role first
    let noneInfo = LockmanGroupCoordinatedInfo(
      actionId: "none",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: noneInfo)

    // Now member should be able to join
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
  }

  // MARK: - Leader Entry Policy Tests

  func testLeaderEmptyGroupPolicyRequiresEmptyGroup() {
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.emptyGroup)
    )

    // Should succeed when group is empty
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leaderInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Another leader with same policy should fail
    let anotherLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "anotherLeader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.emptyGroup)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: anotherLeaderInfo)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .leaderCannotJoinNonEmptyGroup = groupError else {
      XCTFail("Expected leaderCannotJoinNonEmptyGroup")
      return
    }
  }

  func testLeaderWithoutMembersPolicyAllowsOtherLeaders() {
    let leader1Info = LockmanGroupCoordinatedInfo(
      actionId: "leader1",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )
    let leader2Info = LockmanGroupCoordinatedInfo(
      actionId: "leader2",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )

    // Both leaders should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: leader1Info)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader2Info), .success)
    strategy.lock(boundaryId: boundaryId, info: leader2Info)
  }

  func testLeaderWithoutMembersPolicyBlocksMembers() {
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    // Lock leader first
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Member should be able to join (leader allows members to exist)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: memberInfo)

    // New leader with withoutMembers policy should fail
    let newLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "newLeader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: newLeaderInfo)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel when members exist")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .leaderCannotJoinNonEmptyGroup = groupError else {
      XCTFail("Expected leaderCannotJoinNonEmptyGroup")
      return
    }
  }

  func testLeaderWithoutLeaderPolicyAllowsMembers() {
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutLeader)
    )
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    // Lock leader first
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Member should be able to join
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
  }

  func testLeaderWithoutLeaderPolicyBlocksOtherLeaders() {
    let leader1Info = LockmanGroupCoordinatedInfo(
      actionId: "leader1",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutLeader)
    )
    let leader2Info = LockmanGroupCoordinatedInfo(
      actionId: "leader2",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutLeader)
    )

    // First leader should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: leader1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: leader1Info)

    // Second leader should fail
    let result = strategy.canLock(boundaryId: boundaryId, info: leader2Info)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel when another leader exists")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .leaderCannotJoinNonEmptyGroup = groupError else {
      XCTFail("Expected leaderCannotJoinNonEmptyGroup")
      return
    }
  }

  // MARK: - Member Role Tests

  func testMemberCannotJoinEmptyGroup() {
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: memberInfo)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel for member joining empty group")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .memberCannotJoinEmptyGroup = groupError else {
      XCTFail("Expected memberCannotJoinEmptyGroup")
      return
    }
  }

  func testMemberCanJoinWhenGroupHasActiveParticipants() {
    // Add a leader first
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Member should be able to join
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: memberInfo), .success)
  }

  func testMultipleMembersCanJoinActiveGroup() {
    // Add a leader first
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.withoutMembers)
    )
    strategy.lock(boundaryId: boundaryId, info: leaderInfo)

    // Multiple members should be able to join
    let member1Info = LockmanGroupCoordinatedInfo(
      actionId: "member1",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )
    let member2Info = LockmanGroupCoordinatedInfo(
      actionId: "member2",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member1Info), .success)
    strategy.lock(boundaryId: boundaryId, info: member1Info)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: member2Info), .success)
    strategy.lock(boundaryId: boundaryId, info: member2Info)
  }

  // MARK: - Duplicate Action Prevention Tests

  func testSameActionIdCannotRunTwiceInSameGroup() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "sameAction",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "sameAction",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    // First should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Second with same action ID should fail
    let result = strategy.canLock(boundaryId: boundaryId, info: info2)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel for duplicate action ID")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .actionAlreadyInGroup(let errorInfo, _, let groupIds) = groupError else {
      XCTFail("Expected actionAlreadyInGroup")
      return
    }

    XCTAssertEqual(errorInfo.actionId, "sameAction")
    XCTAssertTrue(groupIds.contains(AnyLockmanGroupId(TestGroupId.group1)))
  }

  func testSameActionIdCanRunInDifferentGroups() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "sameAction",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "sameAction",
      groupId: TestGroupId.group2,
      coordinationRole: .none
    )

    // Both should succeed as they're in different groups
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
    strategy.lock(boundaryId: boundaryId, info: info2)
  }

  // MARK: - Multiple Groups Tests

  func testActionCanCoordinateAcrossMultipleGroups() {
    let multiGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),
      coordinationRole: .none
    )

    // Should succeed when all groups are empty
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiGroupInfo), .success)
  }

  func testMultipleGroupsRequireAllGroupsToSatisfyConditions() {
    // Add member to group1 first
    let group1Member = LockmanGroupCoordinatedInfo(
      actionId: "group1Member",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    strategy.lock(boundaryId: boundaryId, info: group1Member)

    // Multi-group member should fail if any group is empty
    let multiGroupMember = LockmanGroupCoordinatedInfo(
      actionId: "multiMember",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),  // group2 is empty
      coordinationRole: .member
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: multiGroupMember)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel when one group is empty")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard case .memberCannotJoinEmptyGroup = groupError else {
      XCTFail("Expected memberCannotJoinEmptyGroup")
      return
    }
  }

  func testMultipleGroupsSucceedWhenAllGroupsSatisfyConditions() {
    // Add participants to both groups
    let group1Participant = LockmanGroupCoordinatedInfo(
      actionId: "group1Participant",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let group2Participant = LockmanGroupCoordinatedInfo(
      actionId: "group2Participant",
      groupId: TestGroupId.group2,
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: group1Participant)
    strategy.lock(boundaryId: boundaryId, info: group2Participant)

    // Multi-group member should succeed when all groups have participants
    let multiGroupMember = LockmanGroupCoordinatedInfo(
      actionId: "multiMember",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),
      coordinationRole: .member
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: multiGroupMember), .success)
  }

  // MARK: - Lock/Unlock Tests

  func testLockRegistersActionInAllSpecifiedGroups() {
    let multiGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: multiGroupInfo)

    // Verify action is in both groups by checking duplicate action ID fails
    let duplicateInGroup1 = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let duplicateInGroup2 = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupId: TestGroupId.group2,
      coordinationRole: .none
    )

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: duplicateInGroup1) else {
      XCTFail("Expected action to be locked in group1")
      return
    }

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: duplicateInGroup2) else {
      XCTFail("Expected action to be locked in group2")
      return
    }
  }

  func testUnlockRemovesActionFromAllSpecifiedGroups() {
    let multiGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: multiGroupInfo)
    strategy.unlock(boundaryId: boundaryId, info: multiGroupInfo)

    // Should be able to lock same action ID in both groups again
    let newInGroup1 = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let newInGroup2 = LockmanGroupCoordinatedInfo(
      actionId: "multiGroup",
      groupId: TestGroupId.group2,
      coordinationRole: .none
    )

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newInGroup1), .success)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newInGroup2), .success)
  }

  func testAutomaticGroupCleanupWhenLastMemberLeaves() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "onlyMember",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    strategy.lock(boundaryId: boundaryId, info: info)
    strategy.unlock(boundaryId: boundaryId, info: info)

    // Group should be cleaned up automatically
    // This is verified by checking that the getCurrentLocks is empty
    let currentLocks = strategy.getCurrentLocks()
    XCTAssertTrue(currentLocks.isEmpty)
  }

  // MARK: - Cleanup Tests

  func testCleanUpRemovesAllLocks() {
    let infos = [
      LockmanGroupCoordinatedInfo(
        actionId: "test1", groupId: TestGroupId.group1, coordinationRole: .none),
      LockmanGroupCoordinatedInfo(
        actionId: "test2", groupId: TestGroupId.group2, coordinationRole: .none),
      LockmanGroupCoordinatedInfo(
        actionId: "test3", groupId: TestGroupId.navigation, coordinationRole: .none),
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

    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    // Lock on both boundaries
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary2, info: info2)

    // Clean up only boundary1
    strategy.cleanUp(boundaryId: boundary1)

    // boundary1 should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info1), .success)

    // boundary2 should still have the lock (same action ID should fail)
    guard case .cancel = strategy.canLock(boundaryId: boundary2, info: info1) else {
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
    let info = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.emptyGroup)
    )

    strategy.lock(boundaryId: boundaryId, info: info)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let boundaryKey = currentLocks.keys.first!
    XCTAssertEqual(String(describing: boundaryKey), String(describing: boundaryId))

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 1)

    guard let lockInfo = lockInfos.first as? LockmanGroupCoordinatedInfo else {
      XCTFail("Expected LockmanGroupCoordinatedInfo")
      return
    }

    XCTAssertEqual(lockInfo.actionId, "test")
    XCTAssertTrue(lockInfo.groupIds.contains(AnyLockmanGroupId(TestGroupId.group1)))
    XCTAssertEqual(lockInfo.coordinationRole, .leader(.emptyGroup))
  }

  func testGetCurrentLocksWithMultipleGroupsAndActions() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "action1",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "action2",
      groupIds: Set([TestGroupId.group1, TestGroupId.group2]),
      coordinationRole: .member
    )

    strategy.lock(boundaryId: boundaryId, info: info1)
    strategy.lock(boundaryId: boundaryId, info: info2)

    let currentLocks = strategy.getCurrentLocks()
    XCTAssertEqual(currentLocks.count, 1)

    let lockInfos = currentLocks.values.first!
    XCTAssertEqual(lockInfos.count, 2)

    let actionIds = lockInfos.compactMap { ($0 as? LockmanGroupCoordinatedInfo)?.actionId }
    XCTAssertTrue(actionIds.contains("action1"))
    XCTAssertTrue(actionIds.contains("action2"))
  }

  // MARK: - Error Handling Tests

  func testLeaderCannotJoinNonEmptyGroupErrorContainsCorrectInformation() {
    let firstLeader = LockmanGroupCoordinatedInfo(
      actionId: "first",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.emptyGroup)
    )
    strategy.lock(boundaryId: boundaryId, info: firstLeader)

    let secondLeader = LockmanGroupCoordinatedInfo(
      actionId: "second",
      groupId: TestGroupId.group1,
      coordinationRole: .leader(.emptyGroup)
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: secondLeader)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard
      case .leaderCannotJoinNonEmptyGroup(let errorInfo, let errorBoundaryId, let groupIds) =
        groupError
    else {
      XCTFail("Expected leaderCannotJoinNonEmptyGroup")
      return
    }

    XCTAssertEqual(errorInfo.actionId, "second")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertTrue(groupIds.contains(AnyLockmanGroupId(TestGroupId.group1)))
  }

  func testMemberCannotJoinEmptyGroupErrorContainsCorrectInformation() {
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: TestGroupId.group1,
      coordinationRole: .member
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: memberInfo)
    guard case .cancel(let error) = result else {
      XCTFail("Expected .cancel")
      return
    }

    guard let groupError = error as? LockmanGroupCoordinationError else {
      XCTFail("Expected LockmanGroupCoordinationError")
      return
    }

    guard
      case .memberCannotJoinEmptyGroup(let errorInfo, let errorBoundaryId, let groupIds) =
        groupError
    else {
      XCTFail("Expected memberCannotJoinEmptyGroup")
      return
    }

    XCTAssertEqual(errorInfo.actionId, "member")
    XCTAssertEqual(String(describing: errorBoundaryId), String(describing: boundaryId))
    XCTAssertTrue(groupIds.contains(AnyLockmanGroupId(TestGroupId.group1)))
  }

  // MARK: - Thread Safety Tests

  func testConcurrentOperationsOnSameGroup() {
    let expectation = XCTestExpectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 10

    let queue = DispatchQueue.global(qos: .default)
    let strategy = self.strategy
    let boundaryId = self.boundaryId

    for i in 0..<10 {
      queue.async { [strategy, boundaryId, expectation] in
        let info = LockmanGroupCoordinatedInfo(
          actionId: "action\(i)",
          groupId: TestGroupId.group1,
          coordinationRole: .none
        )

        let result = strategy.canLock(boundaryId: boundaryId, info: info)
        // Should either succeed or fail, never crash
        switch result {
        case .success, .cancel, .successWithPrecedingCancellation:
          break  // All are valid outcomes
        }

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  // MARK: - Integration Tests

  func testComplexGroupCoordinationScenario() {
    // Scenario: Navigation group with leaders and members
    let navigationLeader = LockmanGroupCoordinatedInfo(
      actionId: "navigate",
      groupId: TestGroupId.navigation,
      coordinationRole: .leader(.withoutMembers)
    )
    let animationMember = LockmanGroupCoordinatedInfo(
      actionId: "animate",
      groupId: TestGroupId.navigation,
      coordinationRole: .member
    )
    let progressMember = LockmanGroupCoordinatedInfo(
      actionId: "showProgress",
      groupId: TestGroupId.navigation,
      coordinationRole: .member
    )

    // Leader starts the group
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: navigationLeader), .success)
    strategy.lock(boundaryId: boundaryId, info: navigationLeader)

    // Members can join
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: animationMember), .success)
    strategy.lock(boundaryId: boundaryId, info: animationMember)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: progressMember), .success)
    strategy.lock(boundaryId: boundaryId, info: progressMember)

    // New leader with withoutMembers policy should fail
    let newLeader = LockmanGroupCoordinatedInfo(
      actionId: "newNavigate",
      groupId: TestGroupId.navigation,
      coordinationRole: .leader(.withoutMembers)
    )

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: newLeader) else {
      XCTFail("New leader should be blocked by existing members")
      return
    }

    // Leader with withoutLeader policy should also fail
    let anotherLeader = LockmanGroupCoordinatedInfo(
      actionId: "anotherNavigate",
      groupId: TestGroupId.navigation,
      coordinationRole: .leader(.withoutLeader)
    )

    guard case .cancel = strategy.canLock(boundaryId: boundaryId, info: anotherLeader) else {
      XCTFail("Another leader should be blocked by existing leader")
      return
    }
  }

  // MARK: - Edge Cases Tests

  func testEmptyActionIdHandling() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "",
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testLongActionIdHandling() {
    let longActionId = String(repeating: "a", count: 1000)
    let info = LockmanGroupCoordinatedInfo(
      actionId: longActionId,
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testSpecialCharactersInActionId() {
    let specialActionId = "action!@#$%^&*()_+-=[]{}|;:,.<>?"
    let info = LockmanGroupCoordinatedInfo(
      actionId: specialActionId,
      groupId: TestGroupId.group1,
      coordinationRole: .none
    )

    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }
}
