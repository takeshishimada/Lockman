import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanCompositeActionTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Basic Composite Action Protocol Testing
  
  func testLockmanCompositeAction2ProtocolConformance() {
    // Test basic protocol conformance for LockmanCompositeAction2
    struct TestCompositeAction2: LockmanCompositeAction2 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      
      let actionName = "testComposite2"
      
      func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
        return LockmanCompositeInfo2(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .high(.exclusive)
          )
        )
      }
    }
    
    let action = TestCompositeAction2()
    let info = action.createLockmanInfo()
    
    // Test protocol conformance
    XCTAssertEqual(info.actionId, "testComposite2")
    XCTAssertTrue(info.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertEqual(info.lockmanInfoForStrategy2.actionId, "testComposite2")
  }
  
  func testLockmanCompositeAction3ProtocolConformance() {
    // Test basic protocol conformance for LockmanCompositeAction3
    struct TestCompositeAction3: LockmanCompositeAction3 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      typealias I3 = LockmanConcurrencyLimitedInfo
      typealias S3 = LockmanConcurrencyLimitedStrategy
      
      let actionName = "testComposite3"
      
      func createLockmanInfo() -> LockmanCompositeInfo3<I1, I2, I3> {
        return LockmanCompositeInfo3(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .low(.replaceable)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId(actionName),
            .limited(2)
          )
        )
      }
    }
    
    let action = TestCompositeAction3()
    let info = action.createLockmanInfo()
    
    // Test protocol conformance
    XCTAssertEqual(info.actionId, "testComposite3")
    XCTAssertTrue(info.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertEqual(info.lockmanInfoForStrategy3.actionId, "testComposite3")
  }
  
  func testLockmanCompositeAction4ProtocolConformance() {
    // Test basic protocol conformance for LockmanCompositeAction4
    struct TestCompositeAction4: LockmanCompositeAction4 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      typealias I3 = LockmanConcurrencyLimitedInfo
      typealias S3 = LockmanConcurrencyLimitedStrategy
      typealias I4 = LockmanGroupCoordinatedInfo
      typealias S4 = LockmanGroupCoordinationStrategy
      
      let actionName = "testComposite4"
      
      func createLockmanInfo() -> LockmanCompositeInfo4<I1, I2, I3, I4> {
        return LockmanCompositeInfo4(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .high(.exclusive)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId(actionName),
            .limited(3)
          ),
          lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupId: "testGroup",
            coordinationRole: .leader(.emptyGroup)
          )
        )
      }
    }
    
    let action = TestCompositeAction4()
    let info = action.createLockmanInfo()
    
    // Test protocol conformance
    XCTAssertEqual(info.actionId, "testComposite4")
    XCTAssertTrue(info.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy4 is LockmanGroupCoordinatedInfo)
  }
  
  func testLockmanCompositeAction5ProtocolConformance() {
    // Test basic protocol conformance for LockmanCompositeAction5
    struct TestCompositeAction5: LockmanCompositeAction5 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      typealias I3 = LockmanConcurrencyLimitedInfo
      typealias S3 = LockmanConcurrencyLimitedStrategy
      typealias I4 = LockmanGroupCoordinatedInfo
      typealias S4 = LockmanGroupCoordinationStrategy
      typealias I5 = LockmanGroupCoordinatedInfo
      typealias S5 = LockmanGroupCoordinationStrategy
      
      let actionName = "testComposite5"
      
      func createLockmanInfo() -> LockmanCompositeInfo5<I1, I2, I3, I4, I5> {
        return LockmanCompositeInfo5(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .low(.exclusive)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId(actionName),
            .unlimited
          ),
          lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupId: "group1",
            coordinationRole: .leader(.withoutMembers)
          ),
          lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupId: "group2",
            coordinationRole: .leader(.emptyGroup)
          )
        )
      }
    }
    
    let action = TestCompositeAction5()
    let info = action.createLockmanInfo()
    
    // Test protocol conformance
    XCTAssertEqual(info.actionId, "testComposite5")
    XCTAssertTrue(info.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy4 is LockmanGroupCoordinatedInfo)
    XCTAssertTrue(info.lockmanInfoForStrategy5 is LockmanGroupCoordinatedInfo)
  }
  
  // MARK: - Phase 2: Edge Cases and Advanced Configurations
  
  func testCompositeActionWithDifferentActionIds() {
    // Test composite action with different action IDs for sub-strategies
    struct TestMixedAction: LockmanCompositeAction2 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      
      let actionName = "mixedComposite"
      
      func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
        return LockmanCompositeInfo2(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId("differentActionId"),
            priority: .none
          )
        )
      }
    }
    
    let action = TestMixedAction()
    let info = action.createLockmanInfo()
    
    // Test that composite action ID and sub-action IDs can be different
    XCTAssertEqual(info.actionId, "mixedComposite")
    XCTAssertEqual(info.lockmanInfoForStrategy2.actionId, "differentActionId")
    XCTAssertNotEqual(info.actionId, info.lockmanInfoForStrategy2.actionId)
  }
  
  func testCompositeActionUniqueIdGeneration() {
    // Test that multiple instances generate different unique IDs
    struct TestAction: LockmanCompositeAction2 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      
      let actionName = "uniqueTest"
      
      func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
        return LockmanCompositeInfo2(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .high(.replaceable)
          )
        )
      }
    }
    
    let action = TestAction()
    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()
    
    // Test unique ID generation
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertEqual(info1.actionId, info2.actionId) // Same action ID
    XCTAssertNotEqual(info1.lockmanInfoForStrategy1.uniqueId, info2.lockmanInfoForStrategy1.uniqueId)
    XCTAssertNotEqual(info1.lockmanInfoForStrategy2.uniqueId, info2.lockmanInfoForStrategy2.uniqueId)
  }
  
  // MARK: - Phase 3: Integration and Complex Scenarios
  
  func testCompositeActionWithAllStrategyTypes() {
    // Test a complex composite action using all available strategy types
    struct ComplexCompositeAction: LockmanCompositeAction4 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      typealias I3 = LockmanConcurrencyLimitedInfo
      typealias S3 = LockmanConcurrencyLimitedStrategy
      typealias I4 = LockmanGroupCoordinatedInfo
      typealias S4 = LockmanGroupCoordinationStrategy
      
      let actionName = "complexAction"
      
      func createLockmanInfo() -> LockmanCompositeInfo4<I1, I2, I3, I4> {
        return LockmanCompositeInfo4(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .boundary),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .high(.exclusive)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId(actionName),
            .limited(5)
          ),
          lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupId: "complexGroup",
            coordinationRole: .leader(.withoutLeader)
          )
        )
      }
    }
    
    let action = ComplexCompositeAction()
    let info = action.createLockmanInfo()
    
    // Verify all strategy configurations
    XCTAssertEqual(info.actionId, "complexAction")
    
    // Verify SingleExecution configuration
    let singleInfo = info.lockmanInfoForStrategy1
    XCTAssertEqual(singleInfo.mode, .boundary)
    
    // Verify PriorityBased configuration
    let priorityInfo = info.lockmanInfoForStrategy2
    XCTAssertEqual(priorityInfo.priority, .high(.exclusive))
    
    // Verify ConcurrencyLimited configuration
    let concurrencyInfo = info.lockmanInfoForStrategy3
    XCTAssertEqual(concurrencyInfo.limit, .limited(5))
    
    // Verify GroupCoordinated configuration
    let groupInfo = info.lockmanInfoForStrategy4
    XCTAssertEqual(groupInfo.coordinationRole, .leader(.withoutLeader))
  }
  
  func testCompositeActionIntegrationWithStrategies() {
    // Test that composite actions work correctly with actual strategies
    struct IntegrationAction: LockmanCompositeAction3 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      typealias I3 = LockmanConcurrencyLimitedInfo
      typealias S3 = LockmanConcurrencyLimitedStrategy
      
      let actionName = "integrationTest"
      
      func createLockmanInfo() -> LockmanCompositeInfo3<I1, I2, I3> {
        return LockmanCompositeInfo3(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .low(.exclusive)
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            actionId: LockmanActionId(actionName),
            .limited(1)
          )
        )
      }
    }
    
    let action = IntegrationAction()
    let info = action.createLockmanInfo()
    
    // Create individual strategies to verify compatibility
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()
    
    let boundaryId = "testBoundary"
    
    // Test that each sub-strategy can handle its respective info
    XCTAssertEqual(
      singleStrategy.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1),
      .success
    )
    XCTAssertEqual(
      priorityStrategy.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2),
      .success
    )
    // Note: ConcurrencyLimitedStrategy requires container registration for testing
  }
  
  func testCompositeActionDebugDescription() {
    // Test debug descriptions for composite action infos
    struct DebugAction: LockmanCompositeAction2 {
      typealias I1 = LockmanSingleExecutionInfo
      typealias S1 = LockmanSingleExecutionStrategy
      typealias I2 = LockmanPriorityBasedInfo
      typealias S2 = LockmanPriorityBasedStrategy
      
      let actionName = "debugTest"
      
      func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
        return LockmanCompositeInfo2(
          actionId: LockmanActionId(actionName),
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(mode: .action),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: LockmanActionId(actionName),
            priority: .high(.exclusive)
          )
        )
      }
    }
    
    let action = DebugAction()
    let info = action.createLockmanInfo()
    
    // Test that debug descriptions are available and non-empty
    let debugDescription = info.debugDescription
    XCTAssertFalse(debugDescription.isEmpty)
    XCTAssertTrue(debugDescription.contains("CompositeInfo2"))
    XCTAssertTrue(debugDescription.contains(info.actionId))
    
    // Test additional info for debug output
    let additionalInfo = info.debugAdditionalInfo
    XCTAssertFalse(additionalInfo.isEmpty)
    print("Additional info: \(additionalInfo)")
    // CompositeInfo returns "Composite"
    XCTAssertEqual(additionalInfo, "Composite")
  }
  
}
