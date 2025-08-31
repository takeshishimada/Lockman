import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanSingleExecutionErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Happy Path Coverage

  func testBoundaryAlreadyLockedError() {
    let info = LockmanSingleExecutionInfo(actionId: "boundaryAction", mode: .boundary)
    let boundaryId = TestBoundaryId.test

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId,
      lockmanInfo: info
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("Cannot acquire lock"))
    XCTAssertTrue(error.errorDescription!.contains("already has an active lock"))
    XCTAssertTrue(error.errorDescription!.contains(String(describing: boundaryId)))
    XCTAssertTrue(error.errorDescription!.contains(info.actionId))

    XCTAssertEqual(
      error.failureReason,
      "SingleExecutionStrategy with boundary mode prevents multiple operations in the same boundary."
    )

    // Test LockmanStrategyError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(error.lockmanInfo.uniqueId, info.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testActionAlreadyRunningError() {
    let info = LockmanSingleExecutionInfo(actionId: "testAction", mode: .action)
    let boundaryId = TestBoundaryId.test

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundaryId,
      lockmanInfo: info
    )

    // Test LocalizedError conformance
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("Cannot acquire lock"))
    XCTAssertTrue(error.errorDescription!.contains("is already running"))
    XCTAssertTrue(error.errorDescription!.contains("testAction"))

    XCTAssertEqual(
      error.failureReason,
      "SingleExecutionStrategy with action mode prevents duplicate action execution."
    )

    // Test LockmanStrategyError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(error.lockmanInfo.uniqueId, info.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testBoundaryAlreadyLockedErrorWithDifferentActionIds() {
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)
    let boundaryId = TestBoundaryId.test

    // Test with different action IDs but same boundary mode
    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId,
      lockmanInfo: info1
    )

    let error2 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId,
      lockmanInfo: info2
    )

    // Both should reference their respective action IDs
    XCTAssertTrue(error1.errorDescription!.contains("action1"))
    XCTAssertTrue(error2.errorDescription!.contains("action2"))

    // But failure reasons should be the same for boundary mode
    XCTAssertEqual(error1.failureReason, error2.failureReason)
  }

  func testActionAlreadyRunningErrorWithSameActionId() {
    let info1 = LockmanSingleExecutionInfo(actionId: "sameAction", mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: "sameAction", mode: .action)
    let boundaryId1 = TestBoundaryId.test
    let boundaryId2 = TestBoundaryId.secondary

    let error1 = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundaryId1,
      lockmanInfo: info1
    )

    let error2 = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundaryId2,
      lockmanInfo: info2
    )

    // Same action ID should appear in both error descriptions
    XCTAssertTrue(error1.errorDescription!.contains("sameAction"))
    XCTAssertTrue(error2.errorDescription!.contains("sameAction"))

    // But boundary IDs should be different
    XCTAssertEqual(String(describing: error1.boundaryId), String(describing: boundaryId1))
    XCTAssertEqual(String(describing: error2.boundaryId), String(describing: boundaryId2))

    // Different lockmanInfo instances but same action ID
    XCTAssertNotEqual(error1.lockmanInfo.uniqueId, error2.lockmanInfo.uniqueId)
    XCTAssertEqual(error1.lockmanInfo.actionId, error2.lockmanInfo.actionId)
  }
}
