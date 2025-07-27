import ComposableArchitecture
import Foundation
import XCTest

@testable import Lockman

// MARK: - buildLockEffect Tests
//
// Essential tests for the buildLockEffect function focusing on the isCancellationTarget
// functionality that controls whether effects get cancellation IDs attached.

final class EffectBuildLockEffectTests: XCTestCase {

  // MARK: - Basic Property Tests

  func testIsCancellationTargetProperty_SingleExecution() {
    let noneMode = LockmanSingleExecutionInfo(actionId: "test", mode: .none)
    let boundaryMode = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
    let actionMode = LockmanSingleExecutionInfo(actionId: "test", mode: .action)

    XCTAssertFalse(noneMode.isCancellationTarget, ".none mode should not be cancellation target")
    XCTAssertTrue(boundaryMode.isCancellationTarget, ".boundary mode should be cancellation target")
    XCTAssertTrue(actionMode.isCancellationTarget, ".action mode should be cancellation target")
  }

  func testIsCancellationTargetProperty_Priority() {
    let nonePriority = LockmanPriorityBasedInfo(actionId: "test", priority: .none)
    let lowPriority = LockmanPriorityBasedInfo(actionId: "test", priority: .low(.exclusive))
    let highPriority = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))

    XCTAssertFalse(
      nonePriority.isCancellationTarget, ".none priority should not be cancellation target")
    XCTAssertTrue(lowPriority.isCancellationTarget, "low priority should be cancellation target")
    XCTAssertTrue(highPriority.isCancellationTarget, "high priority should be cancellation target")
  }

  func testIsCancellationTargetProperty_GroupCoordination() {
    let noneRole = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: "group",
      coordinationRole: .none
    )
    let memberRole = LockmanGroupCoordinatedInfo(
      actionId: "test",
      groupId: "group",
      coordinationRole: .member
    )

    XCTAssertTrue(
      noneRole.isCancellationTarget, "Group coordination .none role should be cancellation target")
    XCTAssertTrue(
      memberRole.isCancellationTarget,
      "Group coordination member role should be cancellation target")
  }

  func testIsCancellationTargetProperty_ConcurrencyLimited() {
    let concurrencyInfo = LockmanConcurrencyLimitedInfo(
      actionId: "test",
      .limited(3)
    )

    XCTAssertTrue(
      concurrencyInfo.isCancellationTarget,
      "Concurrency limited should always be cancellation target")
  }
}
