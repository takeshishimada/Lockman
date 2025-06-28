import XCTest

@testable import Lockman

final class LockmanConcurrencyLimitedErrorTests: XCTestCase {

  func testConcurrencyLimitReachedError() {
    // Create test data
    let requestedInfo = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("test-1"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 3
    )

    let existingInfo1 = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("existing-1"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 3
    )

    let existingInfo2 = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("existing-2"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 3
    )

    let existingInfo3 = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("existing-3"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 3
    )

    let existingInfos = [existingInfo1, existingInfo2, existingInfo3]

    // Create error
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      requestedInfo: requestedInfo,
      existingInfos: existingInfos,
      current: 3
    )

    // Test errorDescription
    XCTAssertEqual(
      error.errorDescription,
      "Concurrency limit reached for 'group-1': 3/3"
    )

    // Test failureReason
    XCTAssertEqual(
      error.failureReason,
      "Cannot execute action because the maximum number of concurrent executions has been reached"
    )
  }

  func testConcurrencyLimitReachedErrorWithDifferentLimits() {
    // Test with different limit values
    let requestedInfo = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("test-1"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("api-calls"),
      limit: 10
    )

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      requestedInfo: requestedInfo,
      existingInfos: [],
      current: 10
    )

    XCTAssertEqual(
      error.errorDescription,
      "Concurrency limit reached for 'api-calls': 10/10"
    )
  }

  func testErrorAssociatedValues() {
    // Create test data
    let requestedInfo = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("test-1"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 2
    )

    let existingInfo1 = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("existing-1"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 2
    )

    let existingInfo2 = LockmanConcurrencyLimitedInfo(
      id: AnyLockmanBoundaryId("existing-2"),
      strategyId: .concurrencyLimited,
      concurrencyId: AnyLockmanGroupId("group-1"),
      limit: 2
    )

    let existingInfos = [existingInfo1, existingInfo2]

    // Create error
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      requestedInfo: requestedInfo,
      existingInfos: existingInfos,
      current: 2
    )

    // Extract associated values
    switch error {
    case let .concurrencyLimitReached(info, infos, current):
      XCTAssertEqual(info.id, requestedInfo.id)
      XCTAssertEqual(info.concurrencyId, requestedInfo.concurrencyId)
      XCTAssertEqual(info.limit, requestedInfo.limit)
      XCTAssertEqual(infos.count, 2)
      XCTAssertEqual(current, 2)
    }
  }

  func testErrorConformsToLockmanError() {
    let error: LockmanError = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      requestedInfo: LockmanConcurrencyLimitedInfo(
        id: AnyLockmanBoundaryId("test"),
        strategyId: .concurrencyLimited,
        concurrencyId: AnyLockmanGroupId("group"),
        limit: 1
      ),
      existingInfos: [],
      current: 1
    )

    // Should be able to use it as LockmanError
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
  }
}
