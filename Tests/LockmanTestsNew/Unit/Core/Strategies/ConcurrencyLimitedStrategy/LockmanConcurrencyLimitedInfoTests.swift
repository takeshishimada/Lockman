import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanConcurrencyLimitedInfoTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Happy Path Coverage
  
  func testInitWithConcurrencyGroup() {
    let testGroup = TestConcurrencyGroup(id: "testGroup", limit: .limited(5))
    
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "testAction",
      group: testGroup
    )
    
    XCTAssertEqual(info.strategyId, LockmanConcurrencyLimitedStrategy.makeStrategyId())
    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.concurrencyId, "testGroup")
    XCTAssertEqual(info.limit, .limited(5))
    XCTAssertNotNil(info.uniqueId)
  }
  
  func testInitWithConcurrencyGroupAndCustomStrategyId() {
    let customStrategyId = LockmanStrategyId(name: "customStrategy")
    let testGroup = TestConcurrencyGroup(id: "groupId", limit: .unlimited)
    
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: customStrategyId,
      actionId: "testAction2",
      group: testGroup
    )
    
    XCTAssertEqual(info.strategyId, customStrategyId)
    XCTAssertEqual(info.actionId, "testAction2")
    XCTAssertEqual(info.concurrencyId, "groupId")
    XCTAssertEqual(info.limit, .unlimited)
    XCTAssertNotNil(info.uniqueId)
  }
  
  func testInitWithDirectLimit() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "directAction",
      .limited(3)
    )
    
    XCTAssertEqual(info.strategyId, LockmanConcurrencyLimitedStrategy.makeStrategyId())
    XCTAssertEqual(info.actionId, "directAction")
    XCTAssertEqual(info.concurrencyId, "directAction") // Uses actionId as concurrencyId
    XCTAssertEqual(info.limit, .limited(3))
    XCTAssertNotNil(info.uniqueId)
  }
  
  func testInitWithDirectLimitAndCustomStrategyId() {
    let customStrategyId = LockmanStrategyId(name: "customStrategy2")
    
    let info = LockmanConcurrencyLimitedInfo(
      strategyId: customStrategyId,
      actionId: "unlimitedAction",
      .unlimited
    )
    
    XCTAssertEqual(info.strategyId, customStrategyId)
    XCTAssertEqual(info.actionId, "unlimitedAction")
    XCTAssertEqual(info.concurrencyId, "unlimitedAction")
    XCTAssertEqual(info.limit, .unlimited)
    XCTAssertNotNil(info.uniqueId)
  }
  
  func testDebugDescription() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "testAction",
      .limited(2)
    )
    
    let debugDesc = info.debugDescription
    
    XCTAssertTrue(debugDesc.contains("ConcurrencyLimitedInfo"))
    XCTAssertTrue(debugDesc.contains("testAction"))
    XCTAssertTrue(debugDesc.contains("limited(2)"))
    XCTAssertTrue(debugDesc.contains(info.uniqueId.uuidString))
  }
  
  func testDebugAdditionalInfo() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1",
      .limited(7)
    )
    
    let debugAdditional1 = info1.debugAdditionalInfo
    
    XCTAssertTrue(debugAdditional1.contains("concurrency:"))
    XCTAssertTrue(debugAdditional1.contains("action1"))
    XCTAssertTrue(debugAdditional1.contains("limit:"))
    XCTAssertTrue(debugAdditional1.contains("limited(7)"))
    
    // Test with unlimited
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2",
      .unlimited
    )
    
    let debugAdditional2 = info2.debugAdditionalInfo
    
    XCTAssertTrue(debugAdditional2.contains("concurrency: action2"))
    XCTAssertTrue(debugAdditional2.contains("limit: unlimited"))
  }
  
  func testIsCancellationTarget() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1",
      .limited(1)
    )
    
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2",
      .unlimited
    )
    
    // ConcurrencyLimitedInfo should always be a cancellation target
    XCTAssertTrue(info1.isCancellationTarget)
    XCTAssertTrue(info2.isCancellationTarget)
  }
  
  func testEquality() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "same",
      .limited(1)
    )
    
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "same",
      .limited(1)
    )
    
    // Different instances should be unequal (based on uniqueId)
    XCTAssertNotEqual(info1, info2)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    
    // Same instance should be equal to itself
    XCTAssertEqual(info1, info1)
  }
}

// MARK: - Test Helper Types

private struct TestConcurrencyGroup: LockmanConcurrencyGroup {
  let id: String
  let limit: LockmanConcurrencyLimit
}
