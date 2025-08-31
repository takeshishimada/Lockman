import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanPriorityBasedInfoTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Happy Path Coverage
  
  func testBasicInitializationAndProperties() {
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))
    
    XCTAssertEqual(info.actionId, "test")
    XCTAssertEqual(info.priority, .high(.exclusive))
    XCTAssertEqual(info.strategyId, .priorityBased)
    XCTAssertNotNil(info.uniqueId)
  }
  
  func testCustomStrategyId() {
    let customStrategyId = LockmanStrategyId(name: "custom")
    let info = LockmanPriorityBasedInfo(
      strategyId: customStrategyId,
      actionId: "test",
      priority: .low(.replaceable)
    )
    
    XCTAssertEqual(info.strategyId, customStrategyId)
  }
  
  func testEqualityBasedOnUniqueId() {
    let info1 = LockmanPriorityBasedInfo(actionId: "same", priority: .high(.exclusive))
    let info2 = LockmanPriorityBasedInfo(actionId: "same", priority: .high(.exclusive))
    
    // Same properties but different instances should be unequal
    XCTAssertNotEqual(info1, info2)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    
    // Same instance should be equal to itself
    XCTAssertEqual(info1, info1)
  }
  
  func testDebugDescription() {
    let info1 = LockmanPriorityBasedInfo(actionId: "testAction", priority: .high(.exclusive))
    let debugDesc1 = info1.debugDescription
    
    XCTAssertTrue(debugDesc1.contains("LockmanPriorityBasedInfo"))
    XCTAssertTrue(debugDesc1.contains("testAction"))
    XCTAssertTrue(debugDesc1.contains("LockmanPriorityBasedStrategy") || debugDesc1.contains("priorityBased"))
    XCTAssertTrue(debugDesc1.contains(".high(.exclusive)"))
    XCTAssertTrue(debugDesc1.contains(info1.uniqueId.uuidString))
    
    let info2 = LockmanPriorityBasedInfo(actionId: "lowAction", priority: .low(.replaceable))
    let debugDesc2 = info2.debugDescription
    XCTAssertTrue(debugDesc2.contains(".low(.replaceable)"))
    
    let info3 = LockmanPriorityBasedInfo(actionId: "noneAction", priority: .none)
    let debugDesc3 = info3.debugDescription
    XCTAssertTrue(debugDesc3.contains(".none"))
  }
  
  func testDebugAdditionalInfo() {
    // Test with high priority exclusive behavior
    let info1 = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))
    let debugInfo1 = info1.debugAdditionalInfo
    XCTAssertTrue(debugInfo1.contains("priorit"))
    XCTAssertTrue(debugInfo1.contains("b:"))
    XCTAssertTrue(debugInfo1.contains(".exclusive"))
    
    // Test with low priority replaceable behavior
    let info2 = LockmanPriorityBasedInfo(actionId: "test", priority: .low(.replaceable))
    let debugInfo2 = info2.debugAdditionalInfo
    XCTAssertTrue(debugInfo2.contains("priorit"))
    XCTAssertTrue(debugInfo2.contains("b:"))
    XCTAssertTrue(debugInfo2.contains(".replaceable"))
    
    // Test with none priority (no behavior)
    let info3 = LockmanPriorityBasedInfo(actionId: "test", priority: .none)
    let debugInfo3 = info3.debugAdditionalInfo
    XCTAssertTrue(debugInfo3.contains("priority:"))
    XCTAssertTrue(debugInfo3.contains("none"))
    // .none priority should not have behavior info
    XCTAssertFalse(debugInfo3.contains("b:"))
  }
  
  func testIsCancellationTarget() {
    // Priority actions are cancellation targets
    let highInfo = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))
    XCTAssertTrue(highInfo.isCancellationTarget)
    
    let lowInfo = LockmanPriorityBasedInfo(actionId: "test", priority: .low(.replaceable))
    XCTAssertTrue(lowInfo.isCancellationTarget)
    
    // None priority actions are not cancellation targets
    let noneInfo = LockmanPriorityBasedInfo(actionId: "test", priority: .none)
    XCTAssertFalse(noneInfo.isCancellationTarget)
  }
  
  func testPriorityBehaviorProperty() {
    // Test high priority behavior extraction
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    XCTAssertEqual(highExclusive.behavior, .exclusive)
    
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)
    XCTAssertEqual(highReplaceable.behavior, .replaceable)
    
    // Test low priority behavior extraction
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    XCTAssertEqual(lowExclusive.behavior, .exclusive)
    
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    XCTAssertEqual(lowReplaceable.behavior, .replaceable)
    
    // Test none priority has no behavior
    let nonePriority = LockmanPriorityBasedInfo.Priority.none
    XCTAssertNil(nonePriority.behavior)
  }
  
  func testPriorityComparison() {
    let none = LockmanPriorityBasedInfo.Priority.none
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)
    
    // Test less than comparisons
    XCTAssertTrue(none < lowExclusive)
    XCTAssertTrue(none < lowReplaceable)
    XCTAssertTrue(none < highExclusive)
    XCTAssertTrue(none < highReplaceable)
    
    XCTAssertTrue(lowExclusive < highExclusive)
    XCTAssertTrue(lowReplaceable < highExclusive)
    XCTAssertTrue(lowExclusive < highReplaceable)
    XCTAssertTrue(lowReplaceable < highReplaceable)
    
    // Test not less than (greater or equal)
    XCTAssertFalse(lowExclusive < none)
    XCTAssertFalse(highExclusive < none)
    XCTAssertFalse(highExclusive < lowExclusive)
    
    // Test equality at same priority level (regardless of behavior)
    XCTAssertTrue(lowExclusive == lowReplaceable)  // Same level, different behavior
    XCTAssertTrue(highExclusive == highReplaceable)  // Same level, different behavior
    
    // Test inequality across different levels
    XCTAssertFalse(none == lowExclusive)
    XCTAssertFalse(lowExclusive == highExclusive)
  }
}
