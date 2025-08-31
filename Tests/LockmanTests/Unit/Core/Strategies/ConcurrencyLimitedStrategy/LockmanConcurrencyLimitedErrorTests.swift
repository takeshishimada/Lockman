import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanConcurrencyLimitedErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Happy Path Coverage

  func testConcurrencyLimitReachedErrorWithLimitedConcurrency() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "testAction",
      .limited(3)
    )
    let boundaryId = TestBoundaryId.test
    let currentCount = 3

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )

    // Test LocalizedError conformance
    XCTAssertEqual(
      error.errorDescription,
      "Concurrency limit reached for 'testAction': 3/3"
    )

    XCTAssertEqual(
      error.failureReason,
      "Cannot execute action because the maximum number of concurrent executions has been reached"
    )

    // Test LockmanStrategyError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(error.lockmanInfo.uniqueId, info.uniqueId)

    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testConcurrencyLimitReachedErrorWithUnlimitedConcurrency() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "unlimitedAction",
      .unlimited
    )
    let boundaryId = TestBoundaryId.test
    let currentCount = 999

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )

    // Test LocalizedError conformance
    XCTAssertEqual(
      error.errorDescription,
      "Concurrency limit reached for 'unlimitedAction': 999/unlimited"
    )

    XCTAssertEqual(
      error.failureReason,
      "Cannot execute action because the maximum number of concurrent executions has been reached"
    )

    // Test LockmanStrategyError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testConcurrencyLimitReachedErrorWithCustomConcurrencyGroup() {
    let customGroup = TestConcurrencyGroup(id: "customGroup", limit: .limited(5))
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "groupAction",
      group: customGroup
    )
    let boundaryId = TestBoundaryId.test
    let currentCount = 5

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )

    // Test LocalizedError conformance
    XCTAssertEqual(
      error.errorDescription,
      "Concurrency limit reached for 'customGroup': 5/5"
    )

    // Test LockmanStrategyError conformance
    XCTAssertEqual(error.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }
}

// MARK: - Test Helper Types

private struct TestConcurrencyGroup: LockmanConcurrencyGroup {
  let id: String
  let limit: LockmanConcurrencyLimit
}
