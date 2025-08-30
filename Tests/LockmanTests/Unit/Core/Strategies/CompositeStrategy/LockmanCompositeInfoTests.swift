import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanCompositeInfoTests: XCTestCase {
  
  private struct TestConcurrencyGroup: LockmanConcurrencyGroup, Equatable {
    let id: String
    let limit: LockmanConcurrencyLimit
    
    static func == (lhs: TestConcurrencyGroup, rhs: TestConcurrencyGroup) -> Bool {
      return lhs.id == rhs.id && lhs.limit == rhs.limit
    }
  }
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Basic CompositeInfo Functionality
  
  func testLockmanCompositeInfo2BasicProperties() {
    // Test basic properties of LockmanCompositeInfo2
    let info1 = LockmanSingleExecutionInfo(mode: .action)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .high(.exclusive)
    )
    
    let compositeInfo = LockmanCompositeInfo2(
      actionId: LockmanActionId("composite"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    
    // Test basic properties
    XCTAssertEqual(compositeInfo.actionId, "composite")
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy2")
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertTrue(compositeInfo.isCancellationTarget)
    
    // Test strategy-specific info
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.priority, .high(.exclusive))
  }
  
  func testLockmanCompositeInfo3BasicProperties() {
    // Test basic properties of LockmanCompositeInfo3
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .low(.replaceable)
    )
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("concurrency"),
      .limited(3)
    )
    
    let compositeInfo = LockmanCompositeInfo3(
      actionId: LockmanActionId("composite3"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3
    )
    
    // Test basic properties
    XCTAssertEqual(compositeInfo.actionId, "composite3")
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy3")
    XCTAssertNotNil(compositeInfo.uniqueId)
    
    // Test all strategy-specific infos
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .boundary)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.priority, .low(.replaceable))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3.limit, .limited(3))
  }
  
  func testLockmanCompositeInfo4BasicProperties() {
    // Test basic properties of LockmanCompositeInfo4
    let info1 = LockmanSingleExecutionInfo(mode: .action)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .none
    )
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("concurrency"),
      group: TestConcurrencyGroup(id: "test", limit: .unlimited)
    )
    let info4 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("group"),
      groupId: "testGroup",
      coordinationRole: .member
    )
    
    let compositeInfo = LockmanCompositeInfo4(
      actionId: LockmanActionId("composite4"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4
    )
    
    // Test basic properties
    XCTAssertEqual(compositeInfo.actionId, "composite4")
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy4")
    
    // Test all strategy-specific infos
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.priority, .none)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3.limit, .unlimited)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy4.coordinationRole, .member)
  }
  
  func testLockmanCompositeInfo5BasicProperties() {
    // Test basic properties of LockmanCompositeInfo5
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .high(.replaceable)
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
      coordinationRole: .leader(.withoutMembers)
    )
    
    let compositeInfo = LockmanCompositeInfo5(
      actionId: LockmanActionId("composite5"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4,
      lockmanInfoForStrategy5: info5
    )
    
    // Test basic properties
    XCTAssertEqual(compositeInfo.actionId, "composite5")
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy5")
    
    // Test all strategy-specific infos
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .boundary)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.priority, .high(.replaceable))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3.limit, .limited(5))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy4.coordinationRole, .leader(.emptyGroup))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy5.coordinationRole, .leader(.withoutMembers))
  }
  
  // MARK: - Phase 2: Initialization and Edge Cases
  
  func testCompositeInfoCustomStrategyId() {
    // Test CompositeInfo with custom strategy ID
    let customStrategyId = LockmanStrategyId(name: "CustomComposite")
    
    let compositeInfo = LockmanCompositeInfo2(
      strategyId: customStrategyId,
      actionId: LockmanActionId("custom"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("custom"),
        priority: .low(.exclusive)
      )
    )
    
    XCTAssertEqual(compositeInfo.strategyId, customStrategyId)
    XCTAssertEqual(compositeInfo.actionId, "custom")
  }
  
  func testCompositeInfoUniqueIdGeneration() {
    // Test that each CompositeInfo instance gets a unique ID
    let info1 = LockmanCompositeInfo2(
      actionId: LockmanActionId("test"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test"),
        priority: .high(.exclusive)
      )
    )
    
    let info2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("test"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test"),
        priority: .high(.exclusive)
      )
    )
    
    // Same configuration but different unique IDs
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }
  
  func testCompositeInfoEquality() {
    // Test equality comparison for CompositeInfo
    let info1 = LockmanSingleExecutionInfo(mode: .action)
    let info2 = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priority"),
      priority: .high(.exclusive)
    )
    
    let composite1 = LockmanCompositeInfo2(
      actionId: LockmanActionId("test"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    
    let composite2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("test"),
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    
    // Different instances should not be equal due to unique IDs
    XCTAssertNotEqual(composite1.uniqueId, composite2.uniqueId)
    
    // Same instance should have consistent properties
    XCTAssertEqual(composite1.actionId, composite1.actionId)
    XCTAssertEqual(composite1.uniqueId, composite1.uniqueId)
  }
  
  // MARK: - Phase 3: Debug and Integration Testing
  
  func testCompositeInfoDebugDescription() {
    // Test debug description functionality for all CompositeInfo types
    let compositeInfo2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("debugTest2"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("debugTest2"),
        priority: .high(.exclusive)
      )
    )
    
    let compositeInfo3 = LockmanCompositeInfo3(
      actionId: LockmanActionId("debugTest3"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("debugTest3"),
        priority: .low(.exclusive)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("debugTest3"),
        .limited(2)
      )
    )
    
    let compositeInfo4 = LockmanCompositeInfo4(
      actionId: LockmanActionId("debugTest4"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("debugTest4"),
        priority: .none
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("debugTest4"),
        .unlimited
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("debugTest4"),
        groupId: "debugGroup",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    let compositeInfo5 = LockmanCompositeInfo5(
      actionId: LockmanActionId("debugTest5"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("debugTest5"),
        priority: .high(.replaceable)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("debugTest5"),
        .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("debugTest5"),
        groupId: "debugGroup1",
        coordinationRole: .leader(.withoutMembers)
      ),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("debugTest5"),
        groupId: "debugGroup2",
        coordinationRole: .member
      )
    )
    
    // Test debug descriptions for all types
    let debugDescription2 = compositeInfo2.debugDescription
    let debugDescription3 = compositeInfo3.debugDescription
    let debugDescription4 = compositeInfo4.debugDescription
    let debugDescription5 = compositeInfo5.debugDescription
    
    // Verify debug descriptions contain key information
    XCTAssertFalse(debugDescription2.isEmpty)
    XCTAssertTrue(debugDescription2.contains("CompositeInfo2"))
    XCTAssertTrue(debugDescription2.contains("debugTest2"))
    XCTAssertTrue(debugDescription2.contains(compositeInfo2.uniqueId.uuidString))
    
    XCTAssertFalse(debugDescription3.isEmpty)
    XCTAssertTrue(debugDescription3.contains("CompositeInfo3"))
    XCTAssertTrue(debugDescription3.contains("debugTest3"))
    XCTAssertTrue(debugDescription3.contains(compositeInfo3.uniqueId.uuidString))
    
    XCTAssertFalse(debugDescription4.isEmpty)
    XCTAssertTrue(debugDescription4.contains("CompositeInfo4"))
    XCTAssertTrue(debugDescription4.contains("debugTest4"))
    XCTAssertTrue(debugDescription4.contains(compositeInfo4.uniqueId.uuidString))
    
    XCTAssertFalse(debugDescription5.isEmpty)
    XCTAssertTrue(debugDescription5.contains("CompositeInfo5"))
    XCTAssertTrue(debugDescription5.contains("debugTest5"))
    XCTAssertTrue(debugDescription5.contains(compositeInfo5.uniqueId.uuidString))
  }
  
  func testCompositeInfoDebugAdditionalInfo() {
    // Test debug additional info functionality for all CompositeInfo types
    let compositeInfo2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("test2"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test2"),
        priority: .high(.replaceable)
      )
    )
    
    let compositeInfo3 = LockmanCompositeInfo3(
      actionId: LockmanActionId("test3"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test3"),
        priority: .none
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("test3"),
        .unlimited
      )
    )
    
    let compositeInfo4 = LockmanCompositeInfo4(
      actionId: LockmanActionId("test4"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test4"),
        priority: .none
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("test4"),
        .unlimited
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("test4"),
        groupId: "testGroup",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    let compositeInfo5 = LockmanCompositeInfo5(
      actionId: LockmanActionId("test5"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test5"),
        priority: .high(.exclusive)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("test5"),
        .limited(2)
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("test5"),
        groupId: "testGroup1",
        coordinationRole: .leader(.emptyGroup)
      ),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("test5"),
        groupId: "testGroup2",
        coordinationRole: .member
      )
    )
    
    // Test debug additional info for all types
    let additionalInfo2 = compositeInfo2.debugAdditionalInfo
    let additionalInfo3 = compositeInfo3.debugAdditionalInfo
    let additionalInfo4 = compositeInfo4.debugAdditionalInfo
    let additionalInfo5 = compositeInfo5.debugAdditionalInfo
    
    XCTAssertFalse(additionalInfo2.isEmpty)
    XCTAssertFalse(additionalInfo3.isEmpty)
    XCTAssertFalse(additionalInfo4.isEmpty)
    XCTAssertFalse(additionalInfo5.isEmpty)
    
    // All composite infos return "Composite"
    XCTAssertEqual(additionalInfo2, "Composite")
    XCTAssertEqual(additionalInfo3, "Composite")
    XCTAssertEqual(additionalInfo4, "Composite")
    XCTAssertEqual(additionalInfo5, "Composite")
  }
  
  func testCompositeInfoSendableConformance() {
    // Test Sendable conformance by using in concurrent context
    let expectation = self.expectation(description: "Concurrent composite info creation")
    expectation.expectedFulfillmentCount = 5
    
    // Create composite infos concurrently
    for i in 0..<5 {
      Task.detached {
        let info = LockmanCompositeInfo3(
          actionId: LockmanActionId("concurrent\(i)"),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId("concurrent\(i)"),
            priority: .high(.exclusive)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId("concurrent\(i)"),
            .limited(1)
          )
        )
        
        // Verify the info was created correctly
        XCTAssertEqual(info.actionId, "concurrent\(i)")
        expectation.fulfill()
      }
    }
    
    waitForExpectations(timeout: 1.0)
  }
  
  func testCompositeInfoIntegrationWithStrategies() {
    // Test that CompositeInfo works correctly with actual strategies
    let compositeInfo = LockmanCompositeInfo2(
      actionId: LockmanActionId("integration"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("integration"),
        priority: .low(.replaceable)
      )
    )
    
    // Create strategies and test compatibility
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()
    
    let boundaryId = "integrationBoundary"
    
    // Test that strategies can handle their respective infos
    XCTAssertEqual(
      singleStrategy.canLock(boundaryId: boundaryId, info: compositeInfo.lockmanInfoForStrategy1),
      .success
    )
    XCTAssertEqual(
      priorityStrategy.canLock(boundaryId: boundaryId, info: compositeInfo.lockmanInfoForStrategy2),
      .success
    )
  }
  
  func testCompositeInfoWithComplexConfiguration() {
    // Test CompositeInfo with complex strategy configurations
    let compositeInfo = LockmanCompositeInfo5(
      actionId: LockmanActionId("complexConfig"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("priority1"),
        priority: .high(.exclusive)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("concurrency1"),
        .limited(10)
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("group1"),
        groupId: "complexGroup1",
        coordinationRole: .leader(.withoutLeader)
      ),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("group2"),
        groupId: "complexGroup2",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    // Verify complex configuration
    XCTAssertEqual(compositeInfo.actionId, "complexConfig")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, "priority1")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3.actionId, "concurrency1")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy4.actionId, "group1")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy5.actionId, "group2")
    
    // Verify different action IDs are preserved
    XCTAssertNotEqual(compositeInfo.actionId, compositeInfo.lockmanInfoForStrategy2.actionId)
    XCTAssertNotEqual(compositeInfo.lockmanInfoForStrategy2.actionId, compositeInfo.lockmanInfoForStrategy3.actionId)
  }
  
  func testCompositeInfoAllInfosMethod() {
    // Test allInfos() method for all CompositeInfo types to achieve 100% coverage
    let info2 = LockmanCompositeInfo2(
      actionId: LockmanActionId("allInfosTest2"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("allInfosTest2"),
        priority: .high(.exclusive)
      )
    )
    
    let info3 = LockmanCompositeInfo3(
      actionId: LockmanActionId("allInfosTest3"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("allInfosTest3"),
        priority: .low(.replaceable)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("allInfosTest3"),
        .limited(1)
      )
    )
    
    let info4 = LockmanCompositeInfo4(
      actionId: LockmanActionId("allInfosTest4"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .none),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("allInfosTest4"),
        priority: .none
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("allInfosTest4"),
        .unlimited
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("allInfosTest4"),
        groupId: "allInfosGroup4",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    let info5 = LockmanCompositeInfo5(
      actionId: LockmanActionId("allInfosTest5"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("allInfosTest5"),
        priority: .high(.replaceable)
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("allInfosTest5"),
        .limited(3)
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("allInfosTest5"),
        groupId: "allInfosGroup4",
        coordinationRole: .leader(.withoutMembers)
      ),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("allInfosTest5"),
        groupId: "allInfosGroup5",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    // Test allInfos() method for each type
    let allInfos2 = info2.allInfos()
    let allInfos3 = info3.allInfos()
    let allInfos4 = info4.allInfos()
    let allInfos5 = info5.allInfos()
    
    // Verify correct number of infos returned
    XCTAssertEqual(allInfos2.count, 2)
    XCTAssertEqual(allInfos3.count, 3)
    XCTAssertEqual(allInfos4.count, 4)
    XCTAssertEqual(allInfos5.count, 5)
    
    // Verify the infos are the correct ones
    XCTAssertTrue(allInfos2.contains { $0.actionId == info2.lockmanInfoForStrategy1.actionId })
    XCTAssertTrue(allInfos2.contains { $0.actionId == info2.lockmanInfoForStrategy2.actionId })
    
    XCTAssertTrue(allInfos5.contains { $0.actionId == info5.lockmanInfoForStrategy1.actionId })
    XCTAssertTrue(allInfos5.contains { $0.actionId == info5.lockmanInfoForStrategy5.actionId })
  }
  
  func testCompositeInfoStaticMakeStrategyIdMethods() {
    // Test static makeStrategyId() methods for 100% coverage
    let strategyId5 = LockmanCompositeStrategy5<
      LockmanSingleExecutionInfo, LockmanSingleExecutionStrategy,
      LockmanPriorityBasedInfo, LockmanPriorityBasedStrategy,
      LockmanConcurrencyLimitedInfo, LockmanConcurrencyLimitedStrategy,
      LockmanGroupCoordinatedInfo, LockmanGroupCoordinationStrategy,
      LockmanGroupCoordinatedInfo, LockmanGroupCoordinationStrategy
    >.makeStrategyId()
    
    XCTAssertTrue(strategyId5.value.contains("CompositeStrategy5"))
    
    // Test that default strategy ID is consistent
    let defaultInfo5 = LockmanCompositeInfo5(
      actionId: LockmanActionId("defaultTest"),
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("defaultTest"),
        priority: .none
      ),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId("defaultTest"),
        .unlimited
      ),
      lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("defaultTest"),
        groupId: "defaultGroup4",
        coordinationRole: .leader(.emptyGroup)
      ),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId("defaultTest"),
        groupId: "defaultGroup5",
        coordinationRole: .leader(.emptyGroup)
      )
    )
    
    XCTAssertEqual(defaultInfo5.strategyId.value, "Lockman.CompositeStrategy5")
  }
  
}
