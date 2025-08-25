import XCTest

@testable import Lockman

/// Unit tests for LockmanGroupCoordinationError
final class LockmanGroupCoordinationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Error Creation Tests

  func testLeaderCannotJoinNonEmptyGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = "testBoundary"
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let error = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testMemberCannotJoinEmptyGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )
    let boundaryId = AnyLockmanBoundaryId("testBoundary")
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let error = LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testActionAlreadyInGroupError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )
    let boundaryId = AnyLockmanBoundaryId("testBoundary")
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let error = LockmanGroupCoordinationError.actionAlreadyInGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testBlockedByExclusiveLeaderError() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )
    let boundaryId = AnyLockmanBoundaryId("testBoundary")
    let groupId = AnyLockmanGroupId("testGroup")
    let entryPolicy = LockmanGroupCoordinationRole.LeaderEntryPolicy.emptyGroup

    let error = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupId: groupId,
      entryPolicy: entryPolicy
    )

    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  // MARK: - LocalizedError Conformance Tests

  func testErrorDescriptionMessages() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupIds: Set(["testGroup"]),
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = "testBoundary"
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let leaderError = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    let memberError = LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    let alreadyInGroupError = LockmanGroupCoordinationError.actionAlreadyInGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    let blockedError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupId: AnyLockmanGroupId("testGroup"),
      entryPolicy: .emptyGroup
    )

    // Test all error descriptions exist and contain relevant info
    XCTAssertNotNil(leaderError.errorDescription)
    XCTAssertTrue(leaderError.errorDescription!.contains("testAction"))

    XCTAssertNotNil(memberError.errorDescription)
    XCTAssertTrue(memberError.errorDescription!.contains("testAction"))

    XCTAssertNotNil(alreadyInGroupError.errorDescription)
    XCTAssertTrue(alreadyInGroupError.errorDescription!.contains("testAction"))

    XCTAssertNotNil(blockedError.errorDescription)
    XCTAssertTrue(blockedError.errorDescription!.contains("testAction"))
  }

  func testFailureReasonMessages() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "testAction",
      groupIds: Set(["testGroup"]),
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = "testBoundary"
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let leaderError = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    let memberError = LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    let alreadyInGroupError = LockmanGroupCoordinationError.actionAlreadyInGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    // Test different entry policies
    let emptyGroupError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupId: AnyLockmanGroupId("testGroup"),
      entryPolicy: .emptyGroup
    )

    let withoutMembersError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupId: AnyLockmanGroupId("testGroup"),
      entryPolicy: .withoutMembers
    )

    let withoutLeaderError = LockmanGroupCoordinationError.blockedByExclusiveLeader(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupId: AnyLockmanGroupId("testGroup"),
      entryPolicy: .withoutLeader
    )

    // Test all failure reasons exist
    XCTAssertNotNil(leaderError.failureReason)
    XCTAssertNotNil(memberError.failureReason)
    XCTAssertNotNil(alreadyInGroupError.failureReason)
    XCTAssertNotNil(emptyGroupError.failureReason)
    XCTAssertNotNil(withoutMembersError.failureReason)
    XCTAssertNotNil(withoutLeaderError.failureReason)
  }

  // MARK: - LockmanStrategyError Conformance Tests

  func testLockmanStrategyErrorConformance() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "testAction",
      groupIds: Set(["testGroup"]),
      coordinationRole: .member
    )
    let boundaryId = "testBoundary"
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let error = LockmanGroupCoordinationError.actionAlreadyInGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    XCTAssertNotNil(error.lockmanInfo)
    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

}
