import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanGroupCoordinationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Error Case Coverage

  func testLeaderCannotJoinNonEmptyGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "leaderAction",
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = TestBoundaryId.test
    let groupIds: Set<AnyLockmanGroupId> = [AnyLockmanGroupId("group1")]

    let error = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupIds: groupIds
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(
      error.errorDescription!.contains("leader 'leaderAction' cannot join non-empty groups"))
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(error.failureReason, "Leaders must be the first to join a coordination group.")

    // Test LockmanStrategyError conformance
    XCTAssertTrue(error.lockmanInfo.actionId == "leaderAction")
    XCTAssertEqual(error.boundaryId as? TestBoundaryId, TestBoundaryId.test)
  }

  func testMemberCannotJoinEmptyGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "memberAction",
      groupId: "group2",
      coordinationRole: .member
    )
    let boundaryId = TestBoundaryId.feature
    let groupIds: Set<AnyLockmanGroupId> = [AnyLockmanGroupId("group2")]

    let error = LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupIds: groupIds
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(
      error.errorDescription!.contains("member 'memberAction' cannot join empty groups"))
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(
      error.failureReason, "Members require existing participants in the group for coordination.")

    // Test LockmanStrategyError conformance
    XCTAssertTrue(error.lockmanInfo.actionId == "memberAction")
    XCTAssertEqual(error.boundaryId as? TestBoundaryId, TestBoundaryId.feature)
  }

  func testActionAlreadyInGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "duplicateAction",
      groupId: "group3",
      coordinationRole: .none
    )
    let boundaryId = TestBoundaryId.navigation
    let groupIds: Set<AnyLockmanGroupId> = [AnyLockmanGroupId("group3")]

    let error = LockmanGroupCoordinationError.actionAlreadyInGroup(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupIds: groupIds
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("action 'duplicateAction' is already in groups"))
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(
      error.failureReason, "Each action must have a unique ID within its coordination groups.")

    // Test LockmanStrategyError conformance
    XCTAssertTrue(error.lockmanInfo.actionId == "duplicateAction")
    XCTAssertEqual(error.boundaryId as? TestBoundaryId, TestBoundaryId.navigation)
  }

  func testBlockedByExclusiveLeaderErrorWithAllPolicies() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "blockedAction",
      groupId: "group4",
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = TestBoundaryId.secondary
    let groupId = AnyLockmanGroupId("group4")

    // Test emptyGroup policy
    let emptyGroupError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupId: groupId,
      entryPolicy: .emptyGroup
    )

    XCTAssertNotNil(emptyGroupError.errorDescription)
    XCTAssertTrue(emptyGroupError.errorDescription!.contains("blocked by exclusive leader"))
    XCTAssertTrue(emptyGroupError.errorDescription!.contains("policy: emptyGroup"))
    XCTAssertEqual(
      emptyGroupError.failureReason,
      "Leader with 'emptyGroup' policy requires the group to be completely empty.")

    // Test withoutMembers policy
    let withoutMembersError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupId: groupId,
      entryPolicy: .withoutMembers
    )

    XCTAssertTrue(withoutMembersError.errorDescription!.contains("policy: withoutMembers"))
    XCTAssertEqual(
      withoutMembersError.failureReason,
      "Leader with 'withoutMembers' policy requires no members in the group.")

    // Test withoutLeader policy
    let withoutLeaderError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: boundaryId,
      groupId: groupId,
      entryPolicy: .withoutLeader
    )

    XCTAssertTrue(withoutLeaderError.errorDescription!.contains("policy: withoutLeader"))
    XCTAssertEqual(
      withoutLeaderError.failureReason,
      "Leader with 'withoutLeader' policy requires no other leaders in the group.")
  }

  // MARK: - Phase 2: Protocol Conformance Coverage

  func testLockmanStrategyErrorConformance() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "testAction",
      groupId: "testGroup",
      coordinationRole: .member
    )
    let boundaryId = TestBoundaryId.test
    let groupIds: Set<AnyLockmanGroupId> = [AnyLockmanGroupId("testGroup")]

    let errors: [LockmanGroupCoordinationError] = [
      .leaderCannotJoinNonEmptyGroup(lockmanInfo: info, boundaryId: boundaryId, groupIds: groupIds),
      .memberCannotJoinEmptyGroup(lockmanInfo: info, boundaryId: boundaryId, groupIds: groupIds),
      .actionAlreadyInGroup(lockmanInfo: info, boundaryId: boundaryId, groupIds: groupIds),
      .blockedByExclusiveLeader(
        lockmanInfo: info, boundaryId: boundaryId, groupId: AnyLockmanGroupId("testGroup"),
        entryPolicy: .emptyGroup),
    ]

    for error in errors {
      // Test LockmanStrategyError protocol requirements
      XCTAssertTrue(error.lockmanInfo.actionId == "testAction")
      XCTAssertEqual(error.boundaryId as? TestBoundaryId, TestBoundaryId.test)

      // Test LocalizedError protocol requirements
      XCTAssertNotNil(error.errorDescription)
      XCTAssertFalse(error.errorDescription!.isEmpty)
      XCTAssertNotNil(error.failureReason)
      XCTAssertFalse(error.failureReason!.isEmpty)
    }
  }

}
