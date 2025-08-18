import XCTest

@testable import Lockman

/// Unit tests for LockmanConcurrencyLimitedError
final class LockmanConcurrencyLimitedErrorTests: XCTestCase {

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

  func testConcurrencyLimitReachedError() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(3)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 3
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  // MARK: - LocalizedError Conformance Tests

  func testErrorDescriptionWithLimitedConcurrency() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(5)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 5
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let description = error.errorDescription
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("5/5"))
    XCTAssertTrue(description!.contains("testAction"))
  }

  func testErrorDescriptionWithUnlimitedConcurrency() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.unlimited
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 100
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let description = error.errorDescription
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("100/unlimited"))
    XCTAssertTrue(description!.contains("testAction"))
  }

  func testFailureReasonMessage() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(3)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 3
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let failureReason = error.failureReason
    XCTAssertNotNil(failureReason)
    XCTAssertTrue(failureReason!.contains("maximum number"))
    XCTAssertTrue(failureReason!.contains("concurrent"))
  }

  // MARK: - LockmanStrategyError Conformance Tests

  func testLockmanStrategyErrorConformance() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(2)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 2
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    XCTAssertTrue(error is any LockmanStrategyError)
    XCTAssertEqual(error.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testLockmanInfoPropertyAccess() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "specificAction",
      LockmanConcurrencyLimit.limited(10)
    )
    let boundaryId = TestBoundaryId("specificBoundary")
    let currentCount = 10
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let retrievedInfo = error.lockmanInfo as! LockmanConcurrencyLimitedInfo
    XCTAssertEqual(retrievedInfo.actionId, "specificAction")
    XCTAssertEqual(retrievedInfo.strategyId, .concurrencyLimited)
  }

  func testBoundaryIdPropertyAccess() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(1)
    )
    let boundaryId = TestBoundaryId("uniqueBoundary")
    let currentCount = 1
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let retrievedBoundaryId = error.boundaryId as! TestBoundaryId
    XCTAssertEqual(retrievedBoundaryId.value, "uniqueBoundary")
  }

  // MARK: - Edge Cases Tests

  func testErrorWithZeroCurrentCount() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(0)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 0
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let description = error.errorDescription
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("0/0"))
  }

  func testErrorWithHighCurrentCount() {
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: .concurrencyLimited,
      actionId: "testAction",
      LockmanConcurrencyLimit.limited(1000)
    )
    let boundaryId = TestBoundaryId("testBoundary")
    let currentCount = 1000
    
    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: boundaryId,
      currentCount: currentCount
    )
    
    let description = error.errorDescription
    XCTAssertNotNil(description)
    XCTAssertTrue(description!.contains("1000/1000"))
  }

  // MARK: - Support Types

  struct TestBoundaryId: LockmanBoundaryId {
    let value: String
    
    init(_ value: String) {
      self.value = value
    }
    
    var description: String {
      "TestBoundaryId(\(value))"
    }
  }
}
