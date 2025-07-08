import XCTest

@testable import Lockman

// Test-specific error for dynamic condition tests
struct TestDynamicConditionError: Error, LocalizedError {
  let actionId: String
  let hint: String?

  var errorDescription: String? {
    "Dynamic condition not met for action '\(actionId)'" + (hint.map { ". Hint: \($0)" } ?? "")
  }

  var failureReason: String? {
    "The condition for action '\(actionId)' was not met" + (hint.map { ": \($0)" } ?? "")
  }

  static func conditionNotMet(actionId: String, hint: String?) -> TestDynamicConditionError {
    TestDynamicConditionError(actionId: actionId, hint: hint)
  }
}

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  var description: String { value }
}

/// Tests to improve code coverage for error types
final class LockmanErrorCoverageTests: XCTestCase {

  // MARK: - LockmanSingleExecutionCancellationError Tests

  func testSingleExecutionCancellationErrorFailureReason() {
    let existingInfo = LockmanSingleExecutionInfo(actionId: "existing-action", mode: .boundary)
    let cancelledInfo = LockmanSingleExecutionInfo(actionId: "new-action", mode: .boundary)
    let boundaryId = TestBoundaryId("test-boundary")

    let error1 = LockmanSingleExecutionCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      reason: .boundaryAlreadyLocked(existingInfo: existingInfo)
    )
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("boundary"))
    XCTAssertEqual(error1.lockmanInfo.actionId, cancelledInfo.actionId)
    XCTAssertNotNil(error1.errorDescription)

    let error2 = LockmanSingleExecutionCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      reason: .actionAlreadyRunning(existingInfo: existingInfo)
    )
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("action"))
  }

  // MARK: - LockmanPriorityBasedBlockedError Tests

  func testPriorityBasedBlockedErrorFailureReason() {
    let blockedInfo = LockmanPriorityBasedInfo(
      actionId: "blocked-action",
      priority: .low(.exclusive)
    )
    let boundaryId = TestBoundaryId("test-boundary")

    let error1 = LockmanPriorityBasedBlockedError(
      blockedInfo: blockedInfo,
      boundaryId: boundaryId,
      reason: .higherPriorityExists(
        requested: .low(.exclusive),
        currentHighest: .high(.exclusive)
      )
    )
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("priority"))
    XCTAssertEqual(error1.lockmanInfo.actionId, blockedInfo.actionId)

    let error2 = LockmanPriorityBasedBlockedError(
      blockedInfo: blockedInfo,
      boundaryId: boundaryId,
      reason: .samePriorityConflict(priority: .low(.replaceable))
    )
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("priority"))
  }

  // MARK: - LockmanPriorityBasedCancellationError Tests

  func testPriorityBasedCancellationError() {
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "cancelled-action",
      priority: .low(.replaceable)
    )
    let boundaryId = TestBoundaryId("test-boundary")

    let error = LockmanPriorityBasedCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId
    )
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("cancelled"))
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(error.lockmanInfo.actionId, cancelledInfo.actionId)
  }

  // MARK: - TestDynamicConditionError Tests

  func testDynamicConditionErrorFailureReason() {
    let error1 = TestDynamicConditionError.conditionNotMet(actionId: "test-action", hint: nil)
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("condition"))

    let error2 = TestDynamicConditionError.conditionNotMet(
      actionId: "test-action", hint: "Rate limit exceeded")
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("condition"))
  }

  // MARK: - LockmanGroupCoordinationCancellationError Tests

  func testGroupCoordinationCancellationErrorProperties() {
    let cancelledInfo = LockmanGroupCoordinatedInfo(
      actionId: "action1", groupId: "group1", coordinationRole: .member)
    let boundaryId = TestBoundaryId("test-boundary")

    let error1 = LockmanGroupCoordinationCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      reason: .leaderCannotJoinNonEmptyGroup(groupIds: [
        AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2"),
      ])
    )
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertTrue(error1.errorDescription!.contains("leader"))
    XCTAssertTrue(error1.errorDescription!.contains("group1"))
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("Leader"))

    let error2 = LockmanGroupCoordinationCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      reason: .memberCannotJoinEmptyGroup(groupIds: [
        AnyLockmanGroupId("group3")
      ])
    )
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertTrue(error2.errorDescription!.contains("member"))
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("Member"))

    let existingInfo3 = LockmanGroupCoordinatedInfo(
      actionId: "existing", groupId: "group1", coordinationRole: .member)
    let error3 = LockmanGroupCoordinationCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      reason: .actionAlreadyInGroup(
        existingInfo: existingInfo3,
        groupIds: [AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2")])
    )
    XCTAssertNotNil(error3.errorDescription)
    XCTAssertTrue(error3.errorDescription!.contains("existing"))
    XCTAssertNotNil(error3.failureReason)
    XCTAssertTrue(error3.failureReason!.contains("action"))
  }

  // MARK: - LockmanConcurrencyLimitedCancellationError Tests

  func testConcurrencyLimitedCancellationError() {
    let cancelledInfo = LockmanConcurrencyLimitedInfo(
      actionId: "cancelled-action",
      .limited(3)
    )
    let existingInfo1 = LockmanConcurrencyLimitedInfo(
      actionId: "existing1",
      .limited(3)
    )
    let existingInfo2 = LockmanConcurrencyLimitedInfo(
      actionId: "existing2",
      .limited(3)
    )
    let boundaryId = TestBoundaryId("test-boundary")

    let error = LockmanConcurrencyLimitedCancellationError(
      cancelledInfo: cancelledInfo,
      boundaryId: boundaryId,
      existingInfos: [existingInfo1, existingInfo2],
      currentCount: 2
    )
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("2/3"))
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(error.lockmanInfo.actionId, cancelledInfo.actionId)
  }

  // MARK: - Error Description Edge Cases

  func testErrorDescriptionsWithSpecialCharacters() {
    let specialId = "test-<>&\"'123"
    let boundaryId = TestBoundaryId(specialId)

    let existingInfo1 = LockmanSingleExecutionInfo(actionId: "existing", mode: .boundary)
    let cancelledInfo1 = LockmanSingleExecutionInfo(actionId: "new", mode: .boundary)
    let error1 = LockmanSingleExecutionCancellationError(
      cancelledInfo: cancelledInfo1,
      boundaryId: boundaryId,
      reason: .boundaryAlreadyLocked(existingInfo: existingInfo1)
    )
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertTrue(error1.errorDescription!.contains(String(describing: boundaryId)))

    let error2 = TestDynamicConditionError.conditionNotMet(actionId: specialId, hint: nil)
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertTrue(error2.errorDescription!.contains(specialId))
  }

  func testErrorDescriptionsWithEmptyStrings() {
    let emptyId = ""
    let boundaryId = TestBoundaryId("boundary")

    let existingInfo1 = LockmanSingleExecutionInfo(actionId: emptyId, mode: .action)
    let cancelledInfo1 = LockmanSingleExecutionInfo(actionId: "new", mode: .action)
    let error1 = LockmanSingleExecutionCancellationError(
      cancelledInfo: cancelledInfo1,
      boundaryId: boundaryId,
      reason: .actionAlreadyRunning(existingInfo: existingInfo1)
    )
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertNotNil(error1.failureReason)

    let cancelledInfo2 = LockmanGroupCoordinatedInfo(
      actionId: emptyId, groupId: "group1", coordinationRole: .member)
    let existingInfo2 = LockmanGroupCoordinatedInfo(
      actionId: "existing", groupId: "group1", coordinationRole: .member)
    let error2 = LockmanGroupCoordinationCancellationError(
      cancelledInfo: cancelledInfo2,
      boundaryId: boundaryId,
      reason: .actionAlreadyInGroup(
        existingInfo: existingInfo2, groupIds: Set<AnyLockmanGroupId>())
    )
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertNotNil(error2.failureReason)
  }

  func testPriorityErrorWithAllPriorityLevels() {
    let priorities: [LockmanPriorityBasedInfo.Priority] = [
      .none,
      .low(.exclusive),
      .low(.replaceable),
      .high(.exclusive),
      .high(.replaceable),
    ]
    let boundaryId = TestBoundaryId("boundary")

    for priority in priorities {
      let blockedInfo = LockmanPriorityBasedInfo(
        actionId: "blocked",
        priority: priority
      )
      let error = LockmanPriorityBasedBlockedError(
        blockedInfo: blockedInfo,
        boundaryId: boundaryId,
        reason: .samePriorityConflict(priority: priority)
      )
      XCTAssertNotNil(error.errorDescription)
      XCTAssertTrue(error.errorDescription!.contains("priority"))
      XCTAssertNotNil(error.failureReason)
    }
  }

  func testDynamicConditionErrorWithHint() {
    let hints = [
      "Rate limit exceeded",
      "Resource unavailable",
      "Maintenance mode",
      nil,
    ]

    for hint in hints {
      let error = TestDynamicConditionError.conditionNotMet(actionId: "test", hint: hint)
      XCTAssertNotNil(error.errorDescription)
      if let hint = hint {
        XCTAssertTrue(error.errorDescription!.contains(hint))
      }
    }
  }
}
