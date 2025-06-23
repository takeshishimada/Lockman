import XCTest

@testable import Lockman

/// Tests to improve code coverage for error types
final class LockmanErrorCoverageTests: XCTestCase {

  // MARK: - LockmanSingleExecutionError Tests

  func testSingleExecutionErrorFailureReason() {
    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(boundaryId: "test-boundary")
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("boundary"))

    let error2 = LockmanSingleExecutionError.actionAlreadyRunning(actionId: "test-action")
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("action"))
  }

  // MARK: - LockmanPriorityBasedError Tests

  func testPriorityBasedErrorFailureReason() {
    let error1 = LockmanPriorityBasedError.higherPriorityExists(
      requested: .low(.exclusive),
      currentHighest: .high(.exclusive)
    )
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("priority"))

    let error2 = LockmanPriorityBasedError.samePriorityConflict(priority: .low(.replaceable))
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("priority"))

    let error3 = LockmanPriorityBasedError.blockedBySameAction(actionId: "test-action")
    XCTAssertNotNil(error3.failureReason)
    XCTAssertTrue(error3.failureReason!.contains("action"))
  }

  // MARK: - LockmanDynamicConditionError Tests

  func testDynamicConditionErrorFailureReason() {
    let error1 = LockmanDynamicConditionError.conditionNotMet(actionId: "test-action", hint: nil)
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("condition"))

    let error2 = LockmanDynamicConditionError.conditionNotMet(
      actionId: "test-action", hint: "Rate limit exceeded")
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("condition"))
  }

  // MARK: - LockmanGroupCoordinationError Tests

  func testGroupCoordinationErrorProperties() {
    let error1 = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(groupIds: [
      AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2"),
    ])
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertTrue(error1.errorDescription!.contains("leader"))
    XCTAssertTrue(error1.errorDescription!.contains("group1"))
    XCTAssertNotNil(error1.failureReason)
    XCTAssertTrue(error1.failureReason!.contains("Leader"))

    let error2 = LockmanGroupCoordinationError.memberCannotJoinEmptyGroup(groupIds: [AnyLockmanGroupId("group3")])
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertTrue(error2.errorDescription!.contains("member"))
    XCTAssertNotNil(error2.failureReason)
    XCTAssertTrue(error2.failureReason!.contains("Member"))

    let error3 = LockmanGroupCoordinationError.actionAlreadyInGroup(
      actionId: "action1", groupIds: [AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2")])
    XCTAssertNotNil(error3.errorDescription)
    XCTAssertTrue(error3.errorDescription!.contains("action1"))
    XCTAssertNotNil(error3.failureReason)
    XCTAssertTrue(error3.failureReason!.contains("action"))
  }

  // MARK: - Error Description Edge Cases

  func testErrorDescriptionsWithSpecialCharacters() {
    let specialId = "test-<>&\"'123"

    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(boundaryId: specialId)
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertTrue(error1.errorDescription!.contains(specialId))

    let error2 = LockmanPriorityBasedError.blockedBySameAction(actionId: specialId)
    XCTAssertNotNil(error2.errorDescription)
    XCTAssertTrue(error2.errorDescription!.contains(specialId))

    let error3 = LockmanDynamicConditionError.conditionNotMet(actionId: specialId, hint: nil)
    XCTAssertNotNil(error3.errorDescription)
    XCTAssertTrue(error3.errorDescription!.contains(specialId))
  }

  func testErrorDescriptionsWithEmptyStrings() {
    let emptyId = ""

    let error1 = LockmanSingleExecutionError.actionAlreadyRunning(actionId: emptyId)
    XCTAssertNotNil(error1.errorDescription)
    XCTAssertNotNil(error1.failureReason)

    let error2 = LockmanGroupCoordinationError.actionAlreadyInGroup(
      actionId: emptyId, groupIds: Set<AnyLockmanGroupId>())
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

    for priority in priorities {
      let error = LockmanPriorityBasedError.samePriorityConflict(priority: priority)
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
      let error = LockmanDynamicConditionError.conditionNotMet(actionId: "test", hint: hint)
      XCTAssertNotNil(error.errorDescription)
      if let hint = hint {
        XCTAssertTrue(error.errorDescription!.contains(hint))
      }
    }
  }
}
