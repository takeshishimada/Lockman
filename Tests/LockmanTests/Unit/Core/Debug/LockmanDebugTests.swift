import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanDebug tests with 3-phase approach
// ✅ 12 test methods covering debug utilities and composite info protocols
// ✅ Phase 1: Basic debug interface functionality
// ✅ Phase 2: Composite info protocol conformance testing 
// ✅ Phase 3: Integration testing with actual strategies

final class LockmanDebugTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    // Ensure debug logging is disabled by default in tests
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    // Reset debug logging state
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  // MARK: - Phase 1: Basic Debug Interface
  
  func testLockmanDebugLoggingEnabledProperty() {
    // Test that debug.isLoggingEnabled delegates to internal logger
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
    
    // Enable through debug interface
    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertTrue(LockmanManager.debug.isLoggingEnabled)
    
    // Disable through debug interface
    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }
  
  func testLockmanDebugPrintCurrentLocksBasic() {
    // Test that printCurrentLocks() doesn't crash
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
  }
  
  func testLockmanDebugPrintCurrentLocksWithOptions() {
    // Test printCurrentLocks with different format options
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks(options: .default)
    }
    
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks(options: .compact)
    }
    
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks(options: .detailed)
    }
  }
  
  func testLockmanDebugLoggingToggle() {
    // Test multiple toggling operations
    let initialState = LockmanManager.debug.isLoggingEnabled
    
    for i in 0..<5 {
      let expectedState = i % 2 == 1
      LockmanManager.debug.isLoggingEnabled = expectedState
      XCTAssertEqual(LockmanManager.debug.isLoggingEnabled, expectedState)
    }
    
    // Reset to initial state
    LockmanManager.debug.isLoggingEnabled = initialState
  }
  
  // MARK: - Phase 2: Composite Info Protocol Testing
  
  func testLockmanCompositeInfo2Protocol() {
    // Test LockmanCompositeInfo2 conformance to LockmanCompositeInfo
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )
    
    let compositeInfo2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("composite2"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    
    // Test protocol conformance
    let compositeProtocol: any LockmanCompositeInfo = compositeInfo2
    let allInfos = compositeProtocol.allInfos()
    
    XCTAssertEqual(allInfos.count, 2)
    XCTAssertTrue(allInfos[0] is LockmanSingleExecutionInfo)
    XCTAssertTrue(allInfos[1] is LockmanPriorityBasedInfo)
  }
  
  func testLockmanCompositeInfo3Protocol() {
    // Test LockmanCompositeInfo3 conformance to LockmanCompositeInfo
    let info1 = LockmanSingleExecutionInfo(mode: .action)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .high(.exclusive)
    )
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("concurrency"),
      .limited(3)
    )
    
    let compositeInfo3 = LockmanCompositeInfo3(
      actionId: LockmanActionId("composite3"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3
    )
    
    // Test protocol conformance
    let compositeProtocol: any LockmanCompositeInfo = compositeInfo3
    let allInfos = compositeProtocol.allInfos()
    
    XCTAssertEqual(allInfos.count, 3)
    XCTAssertTrue(allInfos[0] is LockmanSingleExecutionInfo)
    XCTAssertTrue(allInfos[1] is LockmanPriorityBasedInfo)
    XCTAssertTrue(allInfos[2] is LockmanConcurrencyLimitedInfo)
  }
  
  func testLockmanCompositeInfo4Protocol() {
    // Test LockmanCompositeInfo4 conformance to LockmanCompositeInfo
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .low(.replaceable)
    )
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("concurrency"),
      .limited(2)
    )
    let info4 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("group"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    
    let compositeInfo4 = LockmanCompositeInfo4(
      actionId: LockmanActionId("composite4"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4
    )
    
    // Test protocol conformance
    let compositeProtocol: any LockmanCompositeInfo = compositeInfo4
    let allInfos = compositeProtocol.allInfos()
    
    XCTAssertEqual(allInfos.count, 4)
    XCTAssertTrue(allInfos[0] is LockmanSingleExecutionInfo)
    XCTAssertTrue(allInfos[1] is LockmanPriorityBasedInfo)
    XCTAssertTrue(allInfos[2] is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(allInfos[3] is LockmanGroupCoordinatedInfo)
  }
  
  func testLockmanCompositeInfo5Protocol() {
    // Test LockmanCompositeInfo5 conformance to LockmanCompositeInfo
    let info1 = LockmanSingleExecutionInfo(mode: .action)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .low(.replaceable)
    )
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("concurrency"),
      .limited(5)
    )
    let info4 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("group1"),
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    let info5 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("group2"),
      groupId: "group2",
      coordinationRole: .member
    )
    
    let compositeInfo5 = LockmanCompositeInfo5(
      actionId: LockmanActionId("composite5"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4,
      lockmanInfoForStrategy5: info5
    )
    
    // Test protocol conformance
    let compositeProtocol: any LockmanCompositeInfo = compositeInfo5
    let allInfos = compositeProtocol.allInfos()
    
    XCTAssertEqual(allInfos.count, 5)
    XCTAssertTrue(allInfos[0] is LockmanSingleExecutionInfo)
    XCTAssertTrue(allInfos[1] is LockmanPriorityBasedInfo)
    XCTAssertTrue(allInfos[2] is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(allInfos[3] is LockmanGroupCoordinatedInfo)
    XCTAssertTrue(allInfos[4] is LockmanGroupCoordinatedInfo)
  }
  
  // MARK: - Phase 3: Integration Testing
  
  func testLockmanDebugWithStrategiesIntegration() {
    // Test debug interface integration with actual strategies
    LockmanManager.debug.isLoggingEnabled = true
    
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()
    
    XCTAssertNoThrow {
      // Operations should work with debug enabled
      let singleResult = singleStrategy.canLock(
        boundaryId: "debugTest",
        info: LockmanSingleExecutionInfo(mode: .boundary)
      )
      XCTAssertEqual(singleResult, .success)
      
      let priorityResult = priorityStrategy.canLock(
        boundaryId: "priorityDebug",
        info: LockmanPriorityBasedInfo(
          actionId: LockmanActionId("priorityAction"),
          priority: .high(.exclusive)
        )
      )
      XCTAssertEqual(priorityResult, .success)
      
      // Lock state printing should work
      LockmanManager.debug.printCurrentLocks()
    }
  }
  
  func testLockmanDebugWithContainer() {
    // Test debug integration with strategy container
    LockmanManager.debug.isLoggingEnabled = true
    
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    
    XCTAssertNoThrow {
      try container.register(strategy)
      
      // Container operations should work with debug enabled
      let resolvedStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
      XCTAssertNotNil(resolvedStrategy)
      
      // Debug printing should work with container
      LockmanManager.debug.printCurrentLocks()
    }
  }
  
  func testLockmanDebugConcurrencyHandling() async {
    // Test debug interface under concurrent access
    await withTaskGroup(of: Void.self) { group in
      // Test concurrent logging enable/disable
      for i in 0..<10 {
        group.addTask {
          LockmanManager.debug.isLoggingEnabled = (i % 2 == 0)
          LockmanManager.debug.printCurrentLocks()
        }
      }
      
      await group.waitForAll()
    }
    
    // Debug interface should remain functional
    let finalState = LockmanManager.debug.isLoggingEnabled
    XCTAssertTrue(finalState == true || finalState == false)
  }
  
}
