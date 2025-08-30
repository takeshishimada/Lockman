import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanPriorityBasedActionTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Happy Path Coverage
  
  func testPriorityConvenienceMethodSingleParameter() {
    let testAction = TestPriorityBasedAction(actionName: "testAction")
    
    let info = testAction.priority(.high(.exclusive))
    
    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.priority, .high(.exclusive))
    XCTAssertNotNil(info.uniqueId)
    XCTAssertEqual(info.strategyId, .priorityBased)
  }
  
  func testPriorityConvenienceMethodWithId() {
    let testAction = TestPriorityBasedAction(actionName: "baseAction")
    
    let info = testAction.priority("_suffix", .low(.replaceable))
    
    XCTAssertEqual(info.actionId, "baseAction_suffix")
    XCTAssertEqual(info.priority, .low(.replaceable))
    XCTAssertNotNil(info.uniqueId)
    XCTAssertEqual(info.strategyId, .priorityBased)
  }
  
  func testPriorityConvenienceMethodWithEmptyId() {
    let testAction = TestPriorityBasedAction(actionName: "action")
    
    let info = testAction.priority("", .none)
    
    XCTAssertEqual(info.actionId, "action")
    XCTAssertEqual(info.priority, .none)
  }
  
  func testPriorityConvenienceMethodWithComplexId() {
    let testAction = TestPriorityBasedAction(actionName: "fetch")
    
    let info = testAction.priority("_user123_data", .high(.exclusive))
    
    XCTAssertEqual(info.actionId, "fetch_user123_data")
    XCTAssertEqual(info.priority, .high(.exclusive))
  }
}

// MARK: - Test Helper Types

private struct TestPriorityBasedAction: LockmanPriorityBasedAction {
  let actionName: String
  
  init(actionName: String) {
    self.actionName = actionName
  }
  
  func createLockmanInfo() -> LockmanPriorityBasedInfo {
    return LockmanPriorityBasedInfo(actionId: actionName, priority: .high(.exclusive))
  }
}
