import XCTest
@testable import Lockman

final class ConcurrencyLimitTests: XCTestCase {
  
  // MARK: - Basic Functionality Tests
  
  func testUnlimitedConcurrency() {
    let limit = ConcurrencyLimit.unlimited
    
    // maxConcurrency should be nil for unlimited
    XCTAssertNil(limit.maxConcurrency)
    
    // Should never be exceeded
    XCTAssertFalse(limit.isExceeded(currentCount: 0))
    XCTAssertFalse(limit.isExceeded(currentCount: 100))
    XCTAssertFalse(limit.isExceeded(currentCount: 1000))
    XCTAssertFalse(limit.isExceeded(currentCount: Int.max))
  }
  
  func testLimitedConcurrency() {
    let limit = ConcurrencyLimit.limited(5)
    
    // maxConcurrency should return the limit value
    XCTAssertEqual(limit.maxConcurrency, 5)
    
    // Test boundary conditions
    XCTAssertFalse(limit.isExceeded(currentCount: 0))
    XCTAssertFalse(limit.isExceeded(currentCount: 1))
    XCTAssertFalse(limit.isExceeded(currentCount: 4))
    XCTAssertTrue(limit.isExceeded(currentCount: 5))  // At limit
    XCTAssertTrue(limit.isExceeded(currentCount: 6))  // Over limit
    XCTAssertTrue(limit.isExceeded(currentCount: 100))
  }
  
  func testLimitedWithZero() {
    let limit = ConcurrencyLimit.limited(0)
    
    XCTAssertEqual(limit.maxConcurrency, 0)
    
    // Zero limit means no concurrency allowed
    XCTAssertTrue(limit.isExceeded(currentCount: 0))
    XCTAssertTrue(limit.isExceeded(currentCount: 1))
  }
  
  func testLimitedWithOne() {
    let limit = ConcurrencyLimit.limited(1)
    
    XCTAssertEqual(limit.maxConcurrency, 1)
    
    // Only one concurrent execution allowed
    XCTAssertFalse(limit.isExceeded(currentCount: 0))
    XCTAssertTrue(limit.isExceeded(currentCount: 1))
    XCTAssertTrue(limit.isExceeded(currentCount: 2))
  }
  
  func testLimitedWithLargeValue() {
    let largeLimit = 1_000_000
    let limit = ConcurrencyLimit.limited(largeLimit)
    
    XCTAssertEqual(limit.maxConcurrency, largeLimit)
    
    XCTAssertFalse(limit.isExceeded(currentCount: largeLimit - 1))
    XCTAssertTrue(limit.isExceeded(currentCount: largeLimit))
    XCTAssertTrue(limit.isExceeded(currentCount: largeLimit + 1))
  }
  
  // MARK: - Debug Description Tests
  
  func testDebugDescriptionUnlimited() {
    let limit = ConcurrencyLimit.unlimited
    XCTAssertEqual(limit.debugDescription, "unlimited")
  }
  
  func testDebugDescriptionLimited() {
    XCTAssertEqual(ConcurrencyLimit.limited(1).debugDescription, "limited(1)")
    XCTAssertEqual(ConcurrencyLimit.limited(10).debugDescription, "limited(10)")
    XCTAssertEqual(ConcurrencyLimit.limited(100).debugDescription, "limited(100)")
  }
  
  // MARK: - Equatable Tests
  
  func testEquality() {
    // Unlimited cases
    XCTAssertEqual(ConcurrencyLimit.unlimited, ConcurrencyLimit.unlimited)
    
    // Limited cases with same value
    XCTAssertEqual(ConcurrencyLimit.limited(5), ConcurrencyLimit.limited(5))
    XCTAssertEqual(ConcurrencyLimit.limited(0), ConcurrencyLimit.limited(0))
    
    // Different values
    XCTAssertNotEqual(ConcurrencyLimit.limited(5), ConcurrencyLimit.limited(6))
    XCTAssertNotEqual(ConcurrencyLimit.unlimited, ConcurrencyLimit.limited(5))
    XCTAssertNotEqual(ConcurrencyLimit.limited(5), ConcurrencyLimit.unlimited)
  }
  
  // MARK: - Pattern Matching Tests
  
  func testPatternMatching() {
    let limits: [ConcurrencyLimit] = [
      .unlimited,
      .limited(1),
      .limited(5),
      .limited(10)
    ]
    
    var unlimitedCount = 0
    var limitedCount = 0
    var totalLimitValue = 0
    
    for limit in limits {
      switch limit {
      case .unlimited:
        unlimitedCount += 1
      case .limited(let value):
        limitedCount += 1
        totalLimitValue += value
      }
    }
    
    XCTAssertEqual(unlimitedCount, 1)
    XCTAssertEqual(limitedCount, 3)
    XCTAssertEqual(totalLimitValue, 16) // 1 + 5 + 10
  }
  
  // MARK: - Integration with Strategy Tests
  
  func testConcurrencyLimitInStrategy() {
    let strategy = LockmanConcurrencyLimitedStrategy()
    let boundaryId = AnyLockmanBoundaryId("test")
    
    // Test unlimited concurrency
    let unlimitedInfo = LockmanConcurrencyLimitedInfo(
      concurrencyId: AnyLockmanGroupId("unlimited-group"),
      limit: .unlimited
    )
    
    // Should always allow locking for unlimited
    for _ in 0..<100 {
      let result = strategy.canLock(id: boundaryId, info: unlimitedInfo)
      XCTAssertEqual(result, .success)
      strategy.lock(id: boundaryId, info: unlimitedInfo)
    }
    
    // Clean up
    strategy.cleanUp()
    
    // Test limited concurrency
    let limitedInfo1 = LockmanConcurrencyLimitedInfo(
      concurrencyId: AnyLockmanGroupId("limited-group"),
      limit: .limited(2)
    )
    
    let limitedInfo2 = LockmanConcurrencyLimitedInfo(
      concurrencyId: AnyLockmanGroupId("limited-group"),
      limit: .limited(2)
    )
    
    let limitedInfo3 = LockmanConcurrencyLimitedInfo(
      concurrencyId: AnyLockmanGroupId("limited-group"),
      limit: .limited(2)
    )
    
    // First two should succeed
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: limitedInfo1), .success)
    strategy.lock(id: boundaryId, info: limitedInfo1)
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: limitedInfo2), .success)
    strategy.lock(id: boundaryId, info: limitedInfo2)
    
    // Third should fail (limit reached)
    let result3 = strategy.canLock(id: boundaryId, info: limitedInfo3)
    switch result3 {
    case .failure(let error):
      XCTAssertTrue(error is LockmanConcurrencyLimitedError)
    default:
      XCTFail("Expected failure but got \(result3)")
    }
    
    // Clean up
    strategy.cleanUp()
  }
  
  // MARK: - Edge Case Tests
  
  func testNegativeCurrentCount() {
    // Even though currentCount should never be negative in practice,
    // test the behavior for robustness
    let limit = ConcurrencyLimit.limited(5)
    
    // Negative count should not exceed limit
    XCTAssertFalse(limit.isExceeded(currentCount: -1))
    XCTAssertFalse(limit.isExceeded(currentCount: -100))
  }
  
  func testConcurrencyLimitWithDifferentGroups() {
    let strategy = LockmanConcurrencyLimitedStrategy()
    let boundaryId = AnyLockmanBoundaryId("test")
    
    // Different groups with different limits
    let apiGroup = AnyLockmanGroupId("api")
    let fileGroup = AnyLockmanGroupId("file")
    
    let apiInfo1 = LockmanConcurrencyLimitedInfo(
      concurrencyId: apiGroup,
      limit: .limited(2)
    )
    
    let apiInfo2 = LockmanConcurrencyLimitedInfo(
      concurrencyId: apiGroup,
      limit: .limited(2)
    )
    
    let fileInfo1 = LockmanConcurrencyLimitedInfo(
      concurrencyId: fileGroup,
      limit: .limited(1)
    )
    
    // Lock both API slots
    strategy.lock(id: boundaryId, info: apiInfo1)
    strategy.lock(id: boundaryId, info: apiInfo2)
    
    // File group should still be available (different group)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: fileInfo1), .success)
    strategy.lock(id: boundaryId, info: fileInfo1)
    
    // Clean up
    strategy.cleanUp()
  }
  
  // MARK: - Sendable Conformance Test
  
  func testSendableConformance() {
    // This test verifies that ConcurrencyLimit can be safely passed between threads
    let limit = ConcurrencyLimit.limited(5)
    
    let expectation = expectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10
    
    DispatchQueue.concurrentPerform(iterations: 10) { index in
      // Access limit from multiple threads
      _ = limit.maxConcurrency
      _ = limit.isExceeded(currentCount: index)
      _ = limit.debugDescription
      
      expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 1.0)
  }
}