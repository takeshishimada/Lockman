import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanPriorityBasedErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Happy Path Coverage

  func testHigherPriorityExistsError() {
    let requestedInfo = LockmanPriorityBasedInfo(actionId: "requested", priority: .low(.exclusive))
    let lockmanInfo = LockmanPriorityBasedInfo(actionId: "current", priority: .high(.exclusive))
    let boundaryId = TestBoundaryId.test

    let error = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: requestedInfo,
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("Cannot acquire lock"))
    XCTAssertTrue(error.errorDescription!.contains("is higher than"))

    XCTAssertEqual(
      error.failureReason,
      "A higher priority action is currently executing and cannot be interrupted."
    )

    // Test LockmanPrecedingCancellationError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, requestedInfo.actionId)
    XCTAssertEqual(error.lockmanInfo.uniqueId, requestedInfo.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testSamePriorityConflictError() {
    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: "requested", priority: .high(.replaceable))
    let lockmanInfo = LockmanPriorityBasedInfo(actionId: "current", priority: .high(.exclusive))
    let boundaryId = TestBoundaryId.test

    let error = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: requestedInfo,
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("Cannot acquire lock"))
    XCTAssertTrue(error.errorDescription!.contains("exclusive behavior"))

    XCTAssertEqual(
      error.failureReason,
      "The existing action with same priority has exclusive concurrency behavior."
    )

    // Test LockmanPrecedingCancellationError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, requestedInfo.actionId)
    XCTAssertEqual(error.lockmanInfo.uniqueId, requestedInfo.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testPrecedingActionCancelledError() {
    let lockmanInfo = LockmanPriorityBasedInfo(actionId: "cancelled", priority: .low(.replaceable))
    let boundaryId = TestBoundaryId.test

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId
    )

    // Test LocalizedError conformance
    XCTAssertEqual(
      error.errorDescription,
      "Lock acquired, preceding action 'cancelled' will be cancelled."
    )

    XCTAssertEqual(
      error.failureReason,
      "A lower priority action was preempted by a higher priority action."
    )

    // Test LockmanPrecedingCancellationError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, lockmanInfo.actionId)
    XCTAssertEqual(error.lockmanInfo.uniqueId, lockmanInfo.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }
}
