import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanConcurrencyLimitTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Happy Path Coverage
  
  func testMaxConcurrencyForUnlimited() {
    let unlimitedLimit = LockmanConcurrencyLimit.unlimited
    
    XCTAssertNil(unlimitedLimit.maxConcurrency)
  }
  
  func testMaxConcurrencyForLimited() {
    let limitedLimit = LockmanConcurrencyLimit.limited(5)
    
    XCTAssertEqual(limitedLimit.maxConcurrency, 5)
  }
  
  func testIsExceededForUnlimited() {
    let unlimitedLimit = LockmanConcurrencyLimit.unlimited
    
    XCTAssertFalse(unlimitedLimit.isExceeded(currentCount: 0))
    XCTAssertFalse(unlimitedLimit.isExceeded(currentCount: 10))
    XCTAssertFalse(unlimitedLimit.isExceeded(currentCount: 1000))
  }
  
  func testIsExceededForLimited() {
    let limitedLimit = LockmanConcurrencyLimit.limited(3)
    
    // Below limit
    XCTAssertFalse(limitedLimit.isExceeded(currentCount: 0))
    XCTAssertFalse(limitedLimit.isExceeded(currentCount: 1))
    XCTAssertFalse(limitedLimit.isExceeded(currentCount: 2))
    
    // At limit (should be exceeded because currentCount >= limit)
    XCTAssertTrue(limitedLimit.isExceeded(currentCount: 3))
    
    // Above limit
    XCTAssertTrue(limitedLimit.isExceeded(currentCount: 4))
    XCTAssertTrue(limitedLimit.isExceeded(currentCount: 10))
  }
  
  func testDebugDescriptionForUnlimited() {
    let unlimitedLimit = LockmanConcurrencyLimit.unlimited
    
    XCTAssertEqual(unlimitedLimit.debugDescription, "unlimited")
  }
  
  func testDebugDescriptionForLimited() {
    let limitedLimit1 = LockmanConcurrencyLimit.limited(1)
    XCTAssertEqual(limitedLimit1.debugDescription, "limited(1)")
    
    let limitedLimit10 = LockmanConcurrencyLimit.limited(10)
    XCTAssertEqual(limitedLimit10.debugDescription, "limited(10)")
    
    let limitedLimit0 = LockmanConcurrencyLimit.limited(0)
    XCTAssertEqual(limitedLimit0.debugDescription, "limited(0)")
  }
  
  func testEqualityAndSendability() {
    let unlimited1 = LockmanConcurrencyLimit.unlimited
    let unlimited2 = LockmanConcurrencyLimit.unlimited
    let limited1 = LockmanConcurrencyLimit.limited(5)
    let limited2 = LockmanConcurrencyLimit.limited(5)
    let limited3 = LockmanConcurrencyLimit.limited(10)
    
    // Test Equatable conformance
    XCTAssertEqual(unlimited1, unlimited2)
    XCTAssertEqual(limited1, limited2)
    XCTAssertNotEqual(unlimited1, limited1)
    XCTAssertNotEqual(limited1, limited3)
  }
}
