import XCTest

@testable import Lockman

/// Unit tests for LockmanSingleExecutionInfo
///
/// Tests the information structure for single-execution locking behavior.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance
/// - [ ] LockmanInfo protocol implementation
/// - [ ] Sendable protocol compliance validation
/// - [ ] Equatable protocol custom implementation
/// - [ ] CustomDebugStringConvertible protocol implementation
/// - [ ] Protocol requirement fulfillment verification
///
/// ### Initialization & Property Validation
/// - [ ] Default initialization with mode parameter
/// - [ ] Custom strategyId initialization
/// - [ ] Custom actionId initialization
/// - [ ] Default actionId behavior (empty string)
/// - [ ] uniqueId automatic generation and uniqueness
/// - [ ] All initialization parameter combinations
/// - [ ] Property immutability after initialization
///
/// ### Execution Mode Behavior
/// - [ ] ExecutionMode.none behavior and properties
/// - [ ] ExecutionMode.boundary behavior and properties
/// - [ ] ExecutionMode.action behavior and properties
/// - [ ] Mode-specific lock conflict detection logic
/// - [ ] isCancellationTarget computation (.none vs others)
/// - [ ] Mode impact on actionId relevance
///
/// ### Equality Implementation
/// - [ ] Equality based solely on uniqueId
/// - [ ] Inequality with different uniqueId but same actionId
/// - [ ] Equality verification with same uniqueId
/// - [ ] Equality independence from strategyId/actionId/mode
/// - [ ] Hash consistency for Set/Dictionary usage
/// - [ ] Reflexive, symmetric, transitive equality properties
///
/// ### Thread Safety & Sendable
/// - [ ] Sendable compliance across concurrent contexts
/// - [ ] Immutable properties thread safety
/// - [ ] Safe concurrent access to all properties
/// - [ ] UUID thread-safe generation
/// - [ ] No shared mutable state verification
///
/// ### Debug Support
/// - [ ] debugDescription format and content
/// - [ ] debugAdditionalInfo mode representation
/// - [ ] Debug output readability and completeness
/// - [ ] All properties included in debug output
/// - [ ] Debug string parsing and validation
///
/// ### Integration with Strategy System
/// - [ ] LockmanInfo protocol integration
/// - [ ] Strategy container compatibility
/// - [ ] ActionId-based conflict detection
/// - [ ] BoundaryId interaction patterns
/// - [ ] Strategy resolution integration
/// - [ ] Type erasure with AnyLockmanStrategy
///
/// ### Performance & Memory
/// - [ ] Initialization performance benchmarks
/// - [ ] Memory footprint validation
/// - [ ] UUID generation performance impact
/// - [ ] Equality comparison performance
/// - [ ] Debug string generation performance
/// - [ ] Large-scale instance creation behavior
///
/// ### Edge Cases & Error Conditions
/// - [ ] Empty actionId handling
/// - [ ] Very long actionId strings
/// - [ ] Special characters in actionId
/// - [ ] UUID collision probability (theoretical)
/// - [ ] Extreme mode combinations
/// - [ ] Memory pressure scenarios
///
/// ### Boundary Integration
/// - [ ] Boundary-specific lock coordination
/// - [ ] Cross-boundary instance behavior
/// - [ ] Boundary cleanup integration
/// - [ ] Multiple boundary coordination
/// - [ ] Boundary lock memory management
///
/// ### ActionId-specific Testing
/// - [ ] ActionId pattern matching behavior
/// - [ ] Dynamic actionId generation integration
/// - [ ] ActionId-based grouping verification
/// - [ ] Complex actionId scenarios (user_123, doc_456)
/// - [ ] ActionId case sensitivity
/// - [ ] ActionId encoding/escaping requirements
///
final class LockmanSingleExecutionInfoTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Initialization Tests

  func testDefaultInitialization() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    XCTAssertEqual(info.strategyId, .singleExecution)
    XCTAssertEqual(info.actionId, "")
    XCTAssertEqual(info.mode, .boundary)
    XCTAssertNotNil(info.uniqueId)
  }

  func testCustomInitialization() {
    let customStrategyId = LockmanStrategyId("custom-strategy")
    let customActionId = TestSupport.uniqueActionId(prefix: "custom")
    let info = LockmanSingleExecutionInfo(
      strategyId: customStrategyId,
      actionId: customActionId,
      mode: .action
    )

    XCTAssertEqual(info.strategyId, customStrategyId)
    XCTAssertEqual(info.actionId, customActionId)
    XCTAssertEqual(info.mode, .action)
    XCTAssertNotNil(info.uniqueId)
  }

  func testUniqueIdGeneration() {
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(mode: .boundary)

    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testInitializationWithAllModes() {
    let noneInfo = LockmanSingleExecutionInfo(mode: .none)
    let boundaryInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionInfo = LockmanSingleExecutionInfo(mode: .action)

    XCTAssertEqual(noneInfo.mode, .none)
    XCTAssertEqual(boundaryInfo.mode, .boundary)
    XCTAssertEqual(actionInfo.mode, .action)
  }

  // MARK: - Property Validation Tests

  func testPropertyImmutability() {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "immutable"),
      mode: .boundary
    )

    let originalStrategyId = info.strategyId
    let originalActionId = info.actionId
    let originalUniqueId = info.uniqueId
    let originalMode = info.mode

    // Properties should remain unchanged
    XCTAssertEqual(info.strategyId, originalStrategyId)
    XCTAssertEqual(info.actionId, originalActionId)
    XCTAssertEqual(info.uniqueId, originalUniqueId)
    XCTAssertEqual(info.mode, originalMode)
  }

  func testDefaultActionIdBehavior() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    XCTAssertEqual(info.actionId, "")
  }

  func testCustomActionIdPreservation() {
    let customActionId = TestSupport.StandardActionIds.unicode
    let info = LockmanSingleExecutionInfo(actionId: customActionId, mode: .action)
    XCTAssertEqual(info.actionId, customActionId)
  }

  // MARK: - Execution Mode Behavior Tests

  func testNoneModeProperties() {
    let info = LockmanSingleExecutionInfo(mode: .none)
    XCTAssertEqual(info.mode, .none)
    XCTAssertFalse(info.isCancellationTarget)
  }

  func testBoundaryModeProperties() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    XCTAssertEqual(info.mode, .boundary)
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testActionModeProperties() {
    let info = LockmanSingleExecutionInfo(mode: .action)
    XCTAssertEqual(info.mode, .action)
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testIsCancellationTargetLogic() {
    let noneInfo = LockmanSingleExecutionInfo(mode: .none)
    let boundaryInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionInfo = LockmanSingleExecutionInfo(mode: .action)

    XCTAssertFalse(noneInfo.isCancellationTarget)
    XCTAssertTrue(boundaryInfo.isCancellationTarget)
    XCTAssertTrue(actionInfo.isCancellationTarget)
  }

  // MARK: - Equality Implementation Tests

  func testEqualityBasedOnUniqueId() {
    let actionId = TestSupport.uniqueActionId(prefix: "equality")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // Same actionId and mode but different uniqueIds should not be equal
    XCTAssertNotEqual(info1, info2)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testEqualityWithSameInstance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    XCTAssertEqual(info, info)
  }

  func testEqualityReflexivity() {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "reflexive"),
      mode: .action
    )
    XCTAssertEqual(info, info)
  }

  func testEqualitySymmetry() {
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = info1

    XCTAssertEqual(info1, info2)
    XCTAssertEqual(info2, info1)
  }

  func testEqualityTransitivity() {
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = info1
    let info3 = info1

    XCTAssertEqual(info1, info2)
    XCTAssertEqual(info2, info3)
    XCTAssertEqual(info1, info3)
  }

  func testEqualityIndependenceFromOtherProperties() {
    let actionId1 = TestSupport.uniqueActionId(prefix: "prop1")
    let actionId2 = TestSupport.uniqueActionId(prefix: "prop2")

    let info1 = LockmanSingleExecutionInfo(actionId: actionId1, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId2, mode: .action)

    // Different actionId and mode but different uniqueIds should not be equal
    XCTAssertNotEqual(info1, info2)
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanInfoConformance() {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "protocol"),
      mode: .boundary
    )

    XCTAssertTrue(info is any LockmanInfo)
    XCTAssertNotNil(info.strategyId)
    XCTAssertNotNil(info.actionId)
  }

  func testSendableConformance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Test concurrent access
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        // Access properties in concurrent context
        let _ = info.strategyId
        let _ = info.actionId
        let _ = info.uniqueId
        let _ = info.mode
        let _ = info.isCancellationTarget
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testEquatableConformance() {
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(mode: .boundary)

    XCTAssertTrue(info1 is any Equatable)
    XCTAssertNotEqual(info1, info2)
    XCTAssertEqual(info1, info1)
  }

  // MARK: - Debug Support Tests

  func testDebugDescription() {
    let actionId = TestSupport.uniqueActionId(prefix: "debug")
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    let description = info.debugDescription
    XCTAssertTrue(description.contains("LockmanSingleExecutionInfo"))
    XCTAssertTrue(description.contains("strategyId"))
    XCTAssertTrue(description.contains("actionId"))
    XCTAssertTrue(description.contains("uniqueId"))
    XCTAssertTrue(description.contains("mode"))
    XCTAssertTrue(description.contains(actionId))
    XCTAssertTrue(description.contains("\(info.uniqueId)"))
  }

  func testDebugAdditionalInfo() {
    let noneInfo = LockmanSingleExecutionInfo(mode: .none)
    let boundaryInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionInfo = LockmanSingleExecutionInfo(mode: .action)

    XCTAssertTrue(noneInfo.debugAdditionalInfo.contains("none"))
    XCTAssertTrue(boundaryInfo.debugAdditionalInfo.contains("boundary"))
    XCTAssertTrue(actionInfo.debugAdditionalInfo.contains("action"))
  }

  func testCustomDebugStringConvertibleConformance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    XCTAssertTrue(info is any CustomDebugStringConvertible)
    XCTAssertFalse(info.debugDescription.isEmpty)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentPropertyAccess() async {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "concurrent"),
      mode: .boundary
    )

    let results = try! await TestSupport.executeConcurrently(iterations: 50) {
      return (
        strategyId: info.strategyId,
        actionId: info.actionId,
        uniqueId: info.uniqueId,
        mode: info.mode,
        isCancellationTarget: info.isCancellationTarget
      )
    }

    XCTAssertEqual(results.count, 50)

    // All results should be identical
    let firstResult = results[0]
    for result in results.dropFirst() {
      XCTAssertEqual(result.strategyId, firstResult.strategyId)
      XCTAssertEqual(result.actionId, firstResult.actionId)
      XCTAssertEqual(result.uniqueId, firstResult.uniqueId)
      XCTAssertEqual(result.mode, firstResult.mode)
      XCTAssertEqual(result.isCancellationTarget, firstResult.isCancellationTarget)
    }
  }

  func testConcurrentDebugStringAccess() async {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "debug-concurrent"),
      mode: .action
    )

    let results = try! await TestSupport.executeConcurrently(iterations: 20) {
      return (
        debugDescription: info.debugDescription,
        debugAdditionalInfo: info.debugAdditionalInfo
      )
    }

    XCTAssertEqual(results.count, 20)

    // All results should be identical
    let firstResult = results[0]
    for result in results.dropFirst() {
      XCTAssertEqual(result.debugDescription, firstResult.debugDescription)
      XCTAssertEqual(result.debugAdditionalInfo, firstResult.debugAdditionalInfo)
    }
  }

  // MARK: - Edge Cases Tests

  func testEmptyActionId() {
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.StandardActionIds.empty,
      mode: .boundary
    )

    XCTAssertEqual(info.actionId, "")
    XCTAssertNotNil(info.debugDescription)
    XCTAssertTrue(info.debugDescription.contains("actionId"))
  }

  func testLongActionId() {
    let longActionId = TestSupport.StandardActionIds.veryLong
    let info = LockmanSingleExecutionInfo(actionId: longActionId, mode: .action)

    XCTAssertEqual(info.actionId, longActionId)
    XCTAssertNotNil(info.debugDescription)
    XCTAssertTrue(info.debugDescription.contains(longActionId))
  }

  func testSpecialCharactersInActionId() {
    let specialActionId = TestSupport.StandardActionIds.withSpecialChars
    let info = LockmanSingleExecutionInfo(actionId: specialActionId, mode: .boundary)

    XCTAssertEqual(info.actionId, specialActionId)
    XCTAssertTrue(info.debugDescription.contains(specialActionId))
  }

  func testUnicodeActionId() {
    let unicodeActionId = TestSupport.StandardActionIds.unicode
    let info = LockmanSingleExecutionInfo(actionId: unicodeActionId, mode: .action)

    XCTAssertEqual(info.actionId, unicodeActionId)
    XCTAssertTrue(info.debugDescription.contains(unicodeActionId))
  }

  func testActionIdWithNewlines() {
    let newlineActionId = TestSupport.StandardActionIds.withNewlines
    let info = LockmanSingleExecutionInfo(actionId: newlineActionId, mode: .boundary)

    XCTAssertEqual(info.actionId, newlineActionId)
    XCTAssertNotNil(info.debugDescription)
  }

  // MARK: - Performance Tests

  func testInitializationPerformance() {
    let executionTime = TestSupport.measureExecutionTime {
      for i in 0..<1000 {
        let _ = LockmanSingleExecutionInfo(
          actionId: TestSupport.uniqueActionId(prefix: "perf-\(i)"),
          mode: .boundary
        )
      }
    }

    XCTAssertLessThan(executionTime, 0.5, "Initialization should be fast")
  }

  func testEqualityPerformance() {
    let infos = (0..<100).map { i in
      LockmanSingleExecutionInfo(
        actionId: TestSupport.uniqueActionId(prefix: "eq-\(i)"),
        mode: .boundary
      )
    }

    let executionTime = TestSupport.measureExecutionTime {
      for i in 0..<infos.count {
        for j in i..<min(i + 10, infos.count) {
          let _ = infos[i] == infos[j]
        }
      }
    }

    XCTAssertLessThan(executionTime, 0.1, "Equality comparison should be fast")
  }

  func testDebugStringPerformance() {
    let infos = (0..<50).map { i in
      LockmanSingleExecutionInfo(
        actionId: TestSupport.uniqueActionId(prefix: "debug-\(i)"),
        mode: .action
      )
    }

    let executionTime = TestSupport.measureExecutionTime {
      for info in infos {
        let _ = info.debugDescription
        let _ = info.debugAdditionalInfo
      }
    }

    XCTAssertLessThan(executionTime, 0.1, "Debug string generation should be fast")
  }

  // MARK: - Integration Tests

  func testIntegrationWithStrategy() {
    let actionId = TestSupport.uniqueActionId(prefix: "integration")
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // Test that info can be used with strategy
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = TestSupport.StandardBoundaryIds.main

    // Should not throw or crash
    let result = strategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotNil(result)
  }

  func testIntegrationWithContainer() {
    let container = LockmanStrategyContainer()
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "container"),
      mode: .action
    )

    // Test that the strategy ID is properly recognized
    XCTAssertEqual(info.strategyId, .singleExecution)
  }

  func testActionIdBasedGrouping() {
    let baseActionId = TestSupport.uniqueActionId(prefix: "group")

    // Same actionId, different instances
    let info1 = LockmanSingleExecutionInfo(actionId: baseActionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: baseActionId, mode: .action)

    // Different instances but same actionId for grouping
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1, info2)  // Different uniqueIds
  }

  // MARK: - Real-world Scenario Tests

  func testUserAuthenticationScenario() {
    let loginInfo = LockmanSingleExecutionInfo(
      actionId: "user-login",
      mode: .boundary
    )

    XCTAssertEqual(loginInfo.actionId, "user-login")
    XCTAssertEqual(loginInfo.mode, .boundary)
    XCTAssertTrue(loginInfo.isCancellationTarget)
  }

  func testDataSyncScenario() {
    let syncInfo = LockmanSingleExecutionInfo(
      actionId: "sync-user-data",
      mode: .action
    )

    XCTAssertEqual(syncInfo.actionId, "sync-user-data")
    XCTAssertEqual(syncInfo.mode, .action)
    XCTAssertTrue(syncInfo.isCancellationTarget)
  }

  func testFileOperationScenario() {
    let fileInfo = LockmanSingleExecutionInfo(
      actionId: "save-document",
      mode: .boundary
    )

    XCTAssertEqual(fileInfo.actionId, "save-document")
    XCTAssertEqual(fileInfo.mode, .boundary)
    XCTAssertTrue(fileInfo.isCancellationTarget)
  }

  func testNonBlockingScenario() {
    let nonBlockingInfo = LockmanSingleExecutionInfo(
      actionId: "analytics-tracking",
      mode: .none
    )

    XCTAssertEqual(nonBlockingInfo.actionId, "analytics-tracking")
    XCTAssertEqual(nonBlockingInfo.mode, .none)
    XCTAssertFalse(nonBlockingInfo.isCancellationTarget)
  }

  // MARK: - Hash and Collection Tests

  func testEquatableConsistency() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "equatable"),
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "equatable"),
      mode: .boundary
    )

    // Different instances with different actionIds should not be equal
    XCTAssertNotEqual(info1, info2, "Different instances should not be equal")
    
    // Same instance should be equal to itself
    XCTAssertEqual(info1, info1, "Same instance should be equal to itself")
  }

  func testArrayUsage() {
    let infos = (0..<5).map { _ in
      LockmanSingleExecutionInfo(mode: .boundary)
    }

    // Test array contains functionality with Equatable
    let firstInfo = infos[0]
    XCTAssertTrue(infos.contains(firstInfo), "Array should contain the first info")
    XCTAssertEqual(infos.count, 5, "All infos should be in array")
  }

  func testArrayOperations() {
    let infos = [
      LockmanSingleExecutionInfo(mode: .boundary),
      LockmanSingleExecutionInfo(mode: .action),
      LockmanSingleExecutionInfo(mode: .none),
    ]

    XCTAssertEqual(infos.count, 3)

    // Test filtering by mode
    let boundaryInfos = infos.filter { $0.mode == .boundary }
    XCTAssertEqual(boundaryInfos.count, 1)

    let cancellationTargets = infos.filter { $0.isCancellationTarget }
    XCTAssertEqual(cancellationTargets.count, 2)
  }
}
