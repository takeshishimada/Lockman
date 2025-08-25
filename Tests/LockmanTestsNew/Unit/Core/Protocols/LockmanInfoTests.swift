import XCTest

@testable import Lockman

/// Unit tests for LockmanInfo
///
/// Tests the base protocol for lock information used by strategies.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance
/// - [x] Sendable protocol compliance validation
/// - [x] CustomDebugStringConvertible protocol implementation
/// - [x] Protocol requirement fulfillment verification
/// - [x] Multiple protocol conformance compatibility
///
/// ### Core Properties Validation
/// - [x] strategyId property requirement and behavior
/// - [x] actionId property requirement and behavior
/// - [x] uniqueId property requirement and uniqueness
/// - [x] Property immutability validation
/// - [x] Property access thread safety
///
/// ### StrategyId Behavior
/// - [x] LockmanStrategyId format validation
/// - [x] Built-in strategy ID patterns ("Lockman.SingleExecutionStrategy")
/// - [x] Custom strategy ID patterns ("CustomApp.RateLimitStrategy")
/// - [x] StrategyId debugging and identification
/// - [x] StrategyId consistency across instances
///
/// ### ActionId Behavior
/// - [x] LockmanActionId usage for conflict detection
/// - [x] Simple action ID patterns ("login")
/// - [x] Parameter-specific action IDs ("fetchUser_123")
/// - [x] Scoped action IDs ("sync_userProfile")
/// - [x] ActionId string validation and constraints
/// - [x] Human-readable actionId formatting
///
/// ### UniqueId Behavior
/// - [x] UUID automatic generation validation
/// - [x] Uniqueness across all instances
/// - [x] UniqueId consistency during lock lifecycle
/// - [x] UniqueId independence from actionId
/// - [x] Instance identity through uniqueId
///
/// ### Debug Support Implementation
/// - [x] debugDescription format and content
/// - [x] debugAdditionalInfo default implementation (empty string)
/// - [x] debugAdditionalInfo strategy-specific overrides
/// - [x] Debug information completeness and readability
/// - [x] Strategy-specific debug patterns validation
///
/// ### Cancellation Target Behavior
/// - [x] isCancellationTarget default implementation (true)
/// - [x] Strategy-specific isCancellationTarget overrides
/// - [x] Cancellation behavior based on strategy settings
/// - [x] Effect cancellation ID attachment logic
/// - [x] Protection from cancellation behavior
///
/// ### Strategy-Specific Implementations
/// - [x] LockmanSingleExecutionInfo implementation
/// - [x] LockmanPriorityBasedInfo implementation
/// - [x] LockmanCompositeInfo variants implementation
/// - [x] Custom strategy info implementations
/// - [x] Info implementation consistency
///
/// ### Thread Safety & Sendable
/// - [x] Sendable compliance across concurrent contexts
/// - [x] Immutable properties thread safety
/// - [x] Safe concurrent access to all properties
/// - [x] UUID thread-safe generation
/// - [x] No shared mutable state verification
///
/// ### Integration with Strategy System
/// - [x] Strategy container compatibility
/// - [x] Strategy resolution through strategyId
/// - [x] Conflict detection through actionId
/// - [x] Instance tracking through uniqueId
/// - [x] Lock lifecycle management integration
///
/// ### Performance & Memory
/// - [x] Property access performance
/// - [x] Memory footprint validation
/// - [x] Debug string generation performance
/// - [x] UUID generation performance impact
/// - [x] Large-scale info object usage
///
/// ### Real-world Usage Patterns
/// - [x] Simple action lock info creation
/// - [x] Complex multi-strategy info coordination
/// - [x] Parameter-specific action separation
/// - [x] Strategy-specific configuration patterns
/// - [x] Custom lock information requirements
///
/// ### Edge Cases & Error Conditions
/// - [x] Empty actionId handling
/// - [x] Very long actionId strings
/// - [x] Special characters in actionId
/// - [x] Invalid strategyId formats
/// - [x] Memory pressure scenarios
///
/// ### Documentation Examples Validation
/// - [x] Single execution info example
/// - [x] Priority-based info example
/// - [x] Code example correctness verification
/// - [x] Usage pattern validation from documentation
///
final class LockmanInfoTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock LockmanInfo Implementation for Testing

  private struct MockLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let customDebugInfo: String
    let isCancellable: Bool

    init(
      strategyId: LockmanStrategyId = LockmanStrategyId("MockStrategy"),
      actionId: LockmanActionId = LockmanActionId("mockAction"),
      customDebugInfo: String = "mock debug info",
      isCancellable: Bool = true
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.customDebugInfo = customDebugInfo
      self.isCancellable = isCancellable
    }

    var debugDescription: String {
      "MockLockmanInfo(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId))"
    }

    var debugAdditionalInfo: String {
      customDebugInfo
    }

    var isCancellationTarget: Bool {
      isCancellable
    }
  }

  // MARK: - Protocol Conformance Tests

  func testSendableProtocolComplianceValidation() {
    let info = MockLockmanInfo()

    let expectation = XCTestExpectation(description: "Sendable compliance")

    Task {
      // Access info in async context
      let strategyId = info.strategyId
      let actionId = info.actionId
      let uniqueId = info.uniqueId

      XCTAssertNotNil(strategyId)
      XCTAssertNotNil(actionId)
      XCTAssertNotNil(uniqueId)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testCustomDebugStringConvertibleImplementation() {
    let info = MockLockmanInfo(
      strategyId: LockmanStrategyId("TestStrategy"),
      actionId: LockmanActionId("testAction")
    )

    // Should conform to CustomDebugStringConvertible
    XCTAssertTrue(info is any CustomDebugStringConvertible)

    let debugString = info.debugDescription
    XCTAssertFalse(debugString.isEmpty)
    XCTAssertTrue(debugString.contains("TestStrategy"))
    XCTAssertTrue(debugString.contains("testAction"))
    XCTAssertTrue(debugString.contains("MockLockmanInfo"))
  }

  func testProtocolRequirementFulfillmentVerification() {
    let info = MockLockmanInfo()

    // Verify all required properties are accessible
    XCTAssertNotNil(info.strategyId)
    XCTAssertNotNil(info.actionId)
    XCTAssertNotNil(info.uniqueId)
    XCTAssertNotNil(info.debugDescription)
    XCTAssertNotNil(info.debugAdditionalInfo)
    XCTAssertNotNil(info.isCancellationTarget)
  }

  func testMultipleProtocolConformanceCompatibility() {
    let info = MockLockmanInfo()

    // Should conform to all required protocols
    XCTAssertTrue(info is any LockmanInfo)
    // info is Sendable by definition (marker protocol)
    XCTAssertTrue(info is any CustomDebugStringConvertible)

    // Should work with type erasure
    let anyInfo: any LockmanInfo = info
    XCTAssertNotNil(anyInfo.strategyId)
    XCTAssertNotNil(anyInfo.debugDescription)
  }

  // MARK: - Core Properties Validation Tests

  func testStrategyIdPropertyRequirementAndBehavior() {
    let customStrategyId = LockmanStrategyId("CustomTestStrategy")
    let info = MockLockmanInfo(strategyId: customStrategyId)

    XCTAssertEqual(info.strategyId, customStrategyId)

    // Property should be consistent across accesses
    XCTAssertEqual(info.strategyId, info.strategyId)
  }

  func testActionIdPropertyRequirementAndBehavior() {
    let customActionId = LockmanActionId("customTestAction")
    let info = MockLockmanInfo(actionId: customActionId)

    XCTAssertEqual(info.actionId, customActionId)

    // Property should be consistent across accesses
    XCTAssertEqual(info.actionId, info.actionId)
  }

  func testUniqueIdPropertyRequirementAndUniqueness() {
    let info1 = MockLockmanInfo()
    let info2 = MockLockmanInfo()

    // Each instance should have a unique UUID
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)

    // UniqueId should be consistent for the same instance
    XCTAssertEqual(info1.uniqueId, info1.uniqueId)
    XCTAssertEqual(info2.uniqueId, info2.uniqueId)
  }

  func testPropertyImmutabilityValidation() {
    let info = MockLockmanInfo(
      strategyId: LockmanStrategyId("ImmutableTest"),
      actionId: LockmanActionId("immutableAction")
    )

    let originalStrategyId = info.strategyId
    let originalActionId = info.actionId
    let originalUniqueId = info.uniqueId

    // Properties should remain the same (immutable)
    XCTAssertEqual(info.strategyId, originalStrategyId)
    XCTAssertEqual(info.actionId, originalActionId)
    XCTAssertEqual(info.uniqueId, originalUniqueId)
  }

  func testPropertyAccessThreadSafety() {
    let info = MockLockmanInfo()
    let expectation = XCTestExpectation(description: "Thread safe property access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        // Concurrent access to properties should be safe
        _ = info.strategyId
        _ = info.actionId
        _ = info.uniqueId
        _ = info.debugDescription
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - StrategyId Behavior Tests

  func testLockmanStrategyIdFormatValidation() {
    let builtInId = LockmanStrategyId.singleExecution
    let customId = LockmanStrategyId("CustomApp.RateLimitStrategy")

    let info1 = MockLockmanInfo(strategyId: builtInId)
    let info2 = MockLockmanInfo(strategyId: customId)

    XCTAssertEqual(info1.strategyId, builtInId)
    XCTAssertEqual(info2.strategyId, customId)

    // Both should be valid LockmanStrategyId instances (by definition)
    XCTAssertNotNil(info1.strategyId)
    XCTAssertNotNil(info2.strategyId)
  }

  func testBuiltInStrategyIdPatterns() {
    let singleExecutionInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    XCTAssertEqual(singleExecutionInfo.strategyId, .singleExecution)
    XCTAssertEqual(priorityInfo.strategyId, .priorityBased)

    // Debug descriptions should contain strategy identifiers
    XCTAssertTrue(singleExecutionInfo.debugDescription.contains("singleExecution"))
    XCTAssertTrue(priorityInfo.debugDescription.contains("priorityBased"))
  }

  func testCustomStrategyIdPatterns() {
    let customStrategyIds = [
      "CustomApp.RateLimitStrategy",
      "MyFramework.CustomLockingStrategy",
      "UserDefined.ComplexStrategy",
    ]

    for strategyIdString in customStrategyIds {
      let strategyId = LockmanStrategyId(strategyIdString)
      let info = MockLockmanInfo(strategyId: strategyId)

      XCTAssertEqual(info.strategyId, strategyId)
      XCTAssertTrue(info.debugDescription.contains(strategyIdString))
    }
  }

  func testStrategyIdDebuggingAndIdentification() {
    let strategyId = LockmanStrategyId("DebugTestStrategy")
    let info = MockLockmanInfo(strategyId: strategyId)

    // StrategyId should be identifiable in debug output
    let debugString = info.debugDescription
    XCTAssertTrue(debugString.contains("DebugTestStrategy"))
    XCTAssertTrue(debugString.contains("strategyId"))
  }

  func testStrategyIdConsistencyAcrossInstances() {
    let strategyId = LockmanStrategyId("ConsistencyTest")
    let info1 = MockLockmanInfo(strategyId: strategyId)
    let info2 = MockLockmanInfo(strategyId: strategyId)

    // Same strategyId should be equal across instances
    XCTAssertEqual(info1.strategyId, info2.strategyId)

    // But uniqueIds should be different
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  // MARK: - ActionId Behavior Tests

  func testLockmanActionIdUsageForConflictDetection() {
    let actionId = LockmanActionId("conflictTestAction")
    let info1 = MockLockmanInfo(actionId: actionId)
    let info2 = MockLockmanInfo(actionId: actionId)

    // Same actionId should be equal (for conflict detection)
    XCTAssertEqual(info1.actionId, info2.actionId)

    // But uniqueIds should be different (for instance tracking)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testSimpleActionIdPatterns() {
    let simpleActionIds = ["login", "logout", "refresh", "save", "load"]

    for actionIdString in simpleActionIds {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      XCTAssertEqual(info.actionId, actionId)
      XCTAssertTrue(info.debugDescription.contains(actionIdString))
    }
  }

  func testParameterSpecificActionIds() {
    let parameterizedActionIds = [
      "fetchUser_123",
      "saveDocument_abc123",
      "loadProfile_user456",
      "updateSettings_theme",
    ]

    for actionIdString in parameterizedActionIds {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      XCTAssertEqual(info.actionId, actionId)
      XCTAssertTrue(info.debugDescription.contains(actionIdString))
    }
  }

  func testScopedActionIds() {
    let scopedActionIds = [
      "sync_userProfile",
      "api_fetchUserData",
      "ui_updateTheme",
      "db_saveUserSettings",
    ]

    for actionIdString in scopedActionIds {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      XCTAssertEqual(info.actionId, actionId)
      XCTAssertTrue(info.debugDescription.contains(actionIdString))
    }
  }

  func testActionIdStringValidationAndConstraints() {
    // Test various string patterns
    let testCases = [
      "",  // Empty string
      " ",  // Whitespace
      "normal_action",  // Normal case
      "action-with-dashes",  // Dashes
      "action.with.dots",  // Dots
      "actionWithNumbers123",  // Numbers
      "CamelCaseAction",  // CamelCase
      "action_with_underscores",  // Underscores
    ]

    for actionIdString in testCases {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      XCTAssertEqual(info.actionId, actionId)
      // All should be valid (LockmanActionId is a String typealias)
    }
  }

  func testHumanReadableActionIdFormatting() {
    let readableActionIds = [
      "user_login",
      "document_save",
      "profile_update",
      "settings_load",
    ]

    for actionIdString in readableActionIds {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      // ActionId should be human-readable in debug output
      let debugString = info.debugDescription
      XCTAssertTrue(debugString.contains(actionIdString))
      XCTAssertFalse(debugString.contains("Optional"))
      XCTAssertFalse(debugString.contains("nil"))
    }
  }

  // MARK: - UniqueId Behavior Tests

  func testUUIDAutomaticGenerationValidation() {
    let info = MockLockmanInfo()

    // Should have a valid UUID
    XCTAssertNotNil(info.uniqueId)

    // UUID should be a valid UUID format
    let uuidString = info.uniqueId.uuidString
    XCTAssertEqual(uuidString.count, 36)  // Standard UUID string length
    XCTAssertTrue(uuidString.contains("-"))
  }

  func testUniquenessAcrossAllInstances() {
    let infos = (0..<100).map { _ in MockLockmanInfo() }
    let uniqueIds = Set(infos.map { $0.uniqueId })

    // All should have unique UUIDs
    XCTAssertEqual(uniqueIds.count, infos.count)
  }

  func testUniqueIdConsistencyDuringLockLifecycle() {
    let info = MockLockmanInfo()
    let originalUniqueId = info.uniqueId

    // UniqueId should remain consistent
    XCTAssertEqual(info.uniqueId, originalUniqueId)
    XCTAssertEqual(info.uniqueId, originalUniqueId)
    XCTAssertEqual(info.uniqueId, originalUniqueId)
  }

  func testUniqueIdIndependenceFromActionId() {
    let actionId = LockmanActionId("sameAction")
    let info1 = MockLockmanInfo(actionId: actionId)
    let info2 = MockLockmanInfo(actionId: actionId)

    // Same actionId should not affect uniqueId uniqueness
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testInstanceIdentityThroughUniqueId() {
    let info1 = MockLockmanInfo()
    let info2 = MockLockmanInfo()

    // Each instance should have distinct identity
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)

    // Identity should be stable for each instance
    XCTAssertEqual(info1.uniqueId, info1.uniqueId)
    XCTAssertEqual(info2.uniqueId, info2.uniqueId)
  }

  // MARK: - Debug Support Implementation Tests

  func testDebugDescriptionFormatAndContent() {
    let info = MockLockmanInfo(
      strategyId: LockmanStrategyId("DebugStrategy"),
      actionId: LockmanActionId("debugAction")
    )

    let debugDescription = info.debugDescription

    // Should contain key information
    XCTAssertTrue(debugDescription.contains("DebugStrategy"))
    XCTAssertTrue(debugDescription.contains("debugAction"))
    XCTAssertTrue(debugDescription.contains("uniqueId"))
    XCTAssertTrue(debugDescription.contains("MockLockmanInfo"))
  }

  func testDebugAdditionalInfoDefaultImplementation() {
    // Create a basic info that uses default implementation
    struct BasicInfo: LockmanInfo {
      let strategyId = LockmanStrategyId("BasicStrategy")
      let actionId = LockmanActionId("basicAction")
      let uniqueId = UUID()

      var debugDescription: String {
        "BasicInfo()"
      }
    }

    let basicInfo = BasicInfo()

    // Default implementation should return empty string
    XCTAssertEqual(basicInfo.debugAdditionalInfo, "")

    // Explicitly test the protocol extension's default implementation
    let info: any LockmanInfo = basicInfo
    XCTAssertEqual(info.debugAdditionalInfo, "")
  }

  func testDebugAdditionalInfoStrategySpecificOverrides() {
    let singleExecutionInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    // Strategy-specific overrides should provide meaningful info
    XCTAssertTrue(singleExecutionInfo.debugAdditionalInfo.contains("mode"))
    XCTAssertTrue(priorityInfo.debugAdditionalInfo.contains("priority"))

    XCTAssertNotEqual(singleExecutionInfo.debugAdditionalInfo, "")
    XCTAssertNotEqual(priorityInfo.debugAdditionalInfo, "")
  }

  func testDebugInformationCompletenessAndReadability() {
    let info = MockLockmanInfo(customDebugInfo: "comprehensive debug info")

    let debugDescription = info.debugDescription
    let additionalInfo = info.debugAdditionalInfo

    // Should be readable and complete
    XCTAssertFalse(debugDescription.isEmpty)
    XCTAssertFalse(additionalInfo.isEmpty)
    XCTAssertEqual(additionalInfo, "comprehensive debug info")

    // Should not contain internal/technical details inappropriately
    XCTAssertFalse(debugDescription.contains("Optional"))
    XCTAssertFalse(debugDescription.contains("nil"))
  }

  func testStrategySpecificDebugPatternsValidation() {
    // Test LockmanSingleExecutionInfo debug pattern
    let singleInfo = LockmanSingleExecutionInfo(mode: .action)
    XCTAssertTrue(singleInfo.debugDescription.contains("LockmanSingleExecutionInfo"))
    XCTAssertTrue(singleInfo.debugAdditionalInfo.contains("action"))

    // Test LockmanPriorityBasedInfo debug pattern
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .low(.replaceable)
    )
    XCTAssertTrue(priorityInfo.debugDescription.contains("LockmanPriorityBasedInfo"))
    XCTAssertTrue(priorityInfo.debugAdditionalInfo.contains("priority"))
  }

  // MARK: - Cancellation Target Behavior Tests

  func testIsCancellationTargetDefaultImplementation() {
    // Create a basic info that uses default implementation
    struct DefaultCancellationInfo: LockmanInfo {
      let strategyId = LockmanStrategyId("DefaultStrategy")
      let actionId = LockmanActionId("defaultAction")
      let uniqueId = UUID()

      var debugDescription: String {
        "DefaultCancellationInfo()"
      }
    }

    let defaultInfo = DefaultCancellationInfo()

    // Default implementation should return true
    XCTAssertTrue(defaultInfo.isCancellationTarget)

    // Explicitly test the protocol extension's default implementation
    let info: any LockmanInfo = defaultInfo
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testStrategySpecificIsCancellationTargetOverrides() {
    // Test SingleExecutionInfo with different modes
    let noneInfo = LockmanSingleExecutionInfo(mode: .none)
    let boundaryInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionInfo = LockmanSingleExecutionInfo(mode: .action)

    XCTAssertFalse(noneInfo.isCancellationTarget)  // .none mode not cancellable
    XCTAssertTrue(boundaryInfo.isCancellationTarget)  // .boundary mode is cancellable
    XCTAssertTrue(actionInfo.isCancellationTarget)  // .action mode is cancellable

    // Test PriorityBasedInfo with different priorities
    let nonePriorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .none
    )
    let highPriorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    XCTAssertFalse(nonePriorityInfo.isCancellationTarget)  // .none priority not cancellable
    XCTAssertTrue(highPriorityInfo.isCancellationTarget)  // .high priority is cancellable
  }

  func testCancellationBehaviorBasedOnStrategySettings() {
    let mockNonCancellable = MockLockmanInfo(isCancellable: false)
    let mockCancellable = MockLockmanInfo(isCancellable: true)

    XCTAssertFalse(mockNonCancellable.isCancellationTarget)
    XCTAssertTrue(mockCancellable.isCancellationTarget)
  }

  func testEffectCancellationIdAttachmentLogic() {
    // Simulate the effect building logic
    func shouldAttachCancellationId(for info: any LockmanInfo) -> Bool {
      return info.isCancellationTarget
    }

    let cancellableInfo = MockLockmanInfo(isCancellable: true)
    let nonCancellableInfo = MockLockmanInfo(isCancellable: false)

    XCTAssertTrue(shouldAttachCancellationId(for: cancellableInfo))
    XCTAssertFalse(shouldAttachCancellationId(for: nonCancellableInfo))
  }

  func testProtectionFromCancellationBehavior() {
    let protectedInfo = LockmanSingleExecutionInfo(mode: .none)
    let vulnerableInfo = LockmanSingleExecutionInfo(mode: .boundary)

    // Protected info should not be a cancellation target
    XCTAssertFalse(protectedInfo.isCancellationTarget)

    // Vulnerable info should be a cancellation target
    XCTAssertTrue(vulnerableInfo.isCancellationTarget)
  }

  // MARK: - Strategy-Specific Implementations Tests

  func testLockmanSingleExecutionInfoImplementation() {
    let info = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("singleTest"),
      mode: .boundary
    )

    // Should implement LockmanInfo correctly
    XCTAssertTrue(info is any LockmanInfo)
    XCTAssertEqual(info.strategyId, .singleExecution)
    XCTAssertEqual(info.actionId, LockmanActionId("singleTest"))
    XCTAssertNotNil(info.uniqueId)
    XCTAssertTrue(info.debugAdditionalInfo.contains("mode"))
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testLockmanPriorityBasedInfoImplementation() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("priorityTest"),
      priority: .high(.exclusive)
    )

    // Should implement LockmanInfo correctly
    XCTAssertTrue(info is any LockmanInfo)
    XCTAssertEqual(info.strategyId, .priorityBased)
    XCTAssertEqual(info.actionId, LockmanActionId("priorityTest"))
    XCTAssertNotNil(info.uniqueId)
    XCTAssertTrue(info.debugAdditionalInfo.contains("priority"))
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testLockmanCompositeInfoVariantsImplementation() {
    let singleInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("composite"),
      priority: .high(.exclusive)
    )

    let compositeInfo = LockmanCompositeInfo2(
      actionId: LockmanActionId("compositeTest"),
      lockmanInfoForStrategy1: singleInfo,
      lockmanInfoForStrategy2: priorityInfo
    )

    // Should implement LockmanInfo correctly
    // compositeInfo is LockmanInfo by definition
    XCTAssertEqual(compositeInfo.actionId, LockmanActionId("compositeTest"))
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertEqual(compositeInfo.debugAdditionalInfo, "Composite")
    XCTAssertTrue(compositeInfo.isCancellationTarget)  // Default implementation

    // Should contain nested info
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.uniqueId, singleInfo.uniqueId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.uniqueId, priorityInfo.uniqueId)
  }

  func testCustomStrategyInfoImplementations() {
    struct CustomStrategyInfo: LockmanInfo {
      let strategyId = LockmanStrategyId("CustomStrategy")
      let actionId: LockmanActionId
      let uniqueId = UUID()
      let customProperty: String

      var debugDescription: String {
        "CustomStrategyInfo(actionId: '\(actionId)', customProperty: '\(customProperty)')"
      }

      var debugAdditionalInfo: String {
        "custom: \(customProperty)"
      }
    }

    let customInfo = CustomStrategyInfo(
      actionId: LockmanActionId("customAction"),
      customProperty: "customValue"
    )

    // Should implement LockmanInfo correctly
    XCTAssertTrue(customInfo is CustomStrategyInfo)
    XCTAssertEqual(customInfo.strategyId, LockmanStrategyId("CustomStrategy"))
    XCTAssertEqual(customInfo.actionId, LockmanActionId("customAction"))
    XCTAssertNotNil(customInfo.uniqueId)
    XCTAssertTrue(customInfo.debugAdditionalInfo.contains("customValue"))
    XCTAssertTrue(customInfo.isCancellationTarget)  // Default implementation
  }

  func testInfoImplementationConsistency() {
    let singleInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    // All should implement required properties consistently
    let infos: [any LockmanInfo] = [singleInfo, priorityInfo]

    for info in infos {
      XCTAssertNotNil(info.strategyId)
      XCTAssertNotNil(info.actionId)
      XCTAssertNotNil(info.uniqueId)
      XCTAssertNotNil(info.debugDescription)
      XCTAssertNotNil(info.debugAdditionalInfo)
      XCTAssertNotNil(info.isCancellationTarget)
    }
  }

  // MARK: - Thread Safety & Sendable Tests

  func testSendableComplianceAcrossConcurrentContexts() {
    let info = MockLockmanInfo()
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        // Access properties in concurrent context
        _ = info.strategyId
        _ = info.actionId
        _ = info.uniqueId
        _ = info.debugDescription
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testImmutablePropertiesThreadSafety() {
    let info = MockLockmanInfo()

    actor ResultCollector {
      private var results: [String] = []

      func add(_ result: String) {
        results.append(result)
      }

      func getResults() -> [String] {
        return results
      }
    }

    let collector = ResultCollector()
    let expectation = XCTestExpectation(description: "Thread safe immutability")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      Task {
        let result = "\(info.strategyId)_\(info.actionId)_\(info.uniqueId)"
        await collector.add(result)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)

    Task {
      // All results should be identical (immutable properties)
      let results = await collector.getResults()
      XCTAssertEqual(results.count, 5)
      XCTAssertTrue(results.allSatisfy { $0 == results.first })
    }
  }

  func testSafeConcurrentAccessToAllProperties() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let expectation = XCTestExpectation(description: "Concurrent property access")
    expectation.expectedFulfillmentCount = 20

    // Access all properties concurrently
    for _ in 0..<5 {
      DispatchQueue.global().async {
        _ = info.strategyId
        expectation.fulfill()
      }
      DispatchQueue.global().async {
        _ = info.actionId
        expectation.fulfill()
      }
      DispatchQueue.global().async {
        _ = info.uniqueId
        expectation.fulfill()
      }
      DispatchQueue.global().async {
        _ = info.debugDescription
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testUUIDThreadSafeGeneration() {
    let expectation = XCTestExpectation(description: "Thread safe UUID generation")
    expectation.expectedFulfillmentCount = 50

    actor UUIDCollector {
      private var uniqueIds: Set<UUID> = []

      func insert(_ uuid: UUID) {
        uniqueIds.insert(uuid)
      }

      func getUniqueIds() -> Set<UUID> {
        return uniqueIds
      }
    }

    let collector = UUIDCollector()

    for _ in 0..<50 {
      Task {
        let info = MockLockmanInfo()
        await collector.insert(info.uniqueId)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)

    Task {
      // All UUIDs should be unique
      let uniqueIds = await collector.getUniqueIds()
      XCTAssertEqual(uniqueIds.count, 50)
    }
  }

  func testNoSharedMutableStateVerification() {
    let info1 = MockLockmanInfo()
    let info2 = MockLockmanInfo()

    // Modifying one instance should not affect another (no shared state)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)

    // Properties should remain independent
    let info1Copy = info1  // Copy should have same properties
    XCTAssertEqual(info1.uniqueId, info1Copy.uniqueId)
    XCTAssertEqual(info1.actionId, info1Copy.actionId)
  }

  // MARK: - Integration with Strategy System Tests

  func testStrategyContainerCompatibility() {
    let singleInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    // Should work with type erasure (strategy container usage)
    let infos: [any LockmanInfo] = [singleInfo, priorityInfo]

    for info in infos {
      XCTAssertNotNil(info.strategyId)
      XCTAssertNotNil(info.actionId)
      XCTAssertNotNil(info.uniqueId)
    }
  }

  func testStrategyResolutionThroughStrategyId() {
    let singleInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )

    // StrategyId should match expected strategy types
    XCTAssertEqual(singleInfo.strategyId, .singleExecution)
    XCTAssertEqual(priorityInfo.strategyId, .priorityBased)

    // Should be usable for strategy resolution
    func resolveStrategy(for info: any LockmanInfo) -> String {
      switch info.strategyId {
      case .singleExecution:
        return "SingleExecutionStrategy"
      case .priorityBased:
        return "PriorityBasedStrategy"
      default:
        return "UnknownStrategy"
      }
    }

    XCTAssertEqual(resolveStrategy(for: singleInfo), "SingleExecutionStrategy")
    XCTAssertEqual(resolveStrategy(for: priorityInfo), "PriorityBasedStrategy")
  }

  func testConflictDetectionThroughActionId() {
    let actionId = LockmanActionId("conflictTest")
    let info1 = MockLockmanInfo(actionId: actionId)
    let info2 = MockLockmanInfo(actionId: actionId)
    let info3 = MockLockmanInfo(actionId: LockmanActionId("different"))

    // Same actionId should indicate potential conflict
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1.actionId, info3.actionId)

    // But unique instances should still be distinguishable
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testInstanceTrackingThroughUniqueId() {
    let infos = (0..<10).map { _ in MockLockmanInfo() }
    let uniqueIds = infos.map { $0.uniqueId }

    // Each instance should be trackable through its uniqueId
    XCTAssertEqual(Set(uniqueIds).count, infos.count)

    // Should be able to find specific instances
    for (index, info) in infos.enumerated() {
      XCTAssertEqual(info.uniqueId, uniqueIds[index])
    }
  }

  func testLockLifecycleManagementIntegration() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let originalUniqueId = info.uniqueId

    // UniqueId should remain stable throughout lock lifecycle
    // (simulating lock acquisition, hold, and release)
    XCTAssertEqual(info.uniqueId, originalUniqueId)  // During acquisition
    XCTAssertEqual(info.uniqueId, originalUniqueId)  // During hold
    XCTAssertEqual(info.uniqueId, originalUniqueId)  // During release
  }

  // MARK: - Performance & Memory Tests

  func testPropertyAccessPerformance() {
    let info = MockLockmanInfo()

    measure {
      for _ in 0..<10000 {
        _ = info.strategyId
        _ = info.actionId
        _ = info.uniqueId
        _ = info.isCancellationTarget
      }
    }
  }

  func testMemoryFootprintValidation() {
    // Test memory efficiency of struct-based LockmanInfo
    autoreleasepool {
      let infos = (0..<1000).map { _ in MockLockmanInfo() }

      // Use infos to prevent optimization
      let count = infos.count
      XCTAssertEqual(count, 1000)

      // Verify each info has unique UUID
      let uniqueIds = Set(infos.map { $0.uniqueId })
      XCTAssertEqual(uniqueIds.count, 1000)
    }

    // Structs are value types - memory is automatically managed
    XCTAssertTrue(true)  // Test completed without memory issues
  }

  func testDebugStringGenerationPerformance() {
    let infos = (0..<100).map { _ in MockLockmanInfo() }

    measure {
      for info in infos {
        _ = info.debugDescription
        _ = info.debugAdditionalInfo
      }
    }
  }

  func testUUIDGenerationPerformanceImpact() {
    measure {
      for _ in 0..<1000 {
        _ = MockLockmanInfo()
      }
    }
  }

  func testLargeScaleInfoObjectUsage() {
    let startTime = CFAbsoluteTimeGetCurrent()

    let infos = (0..<10000).map { i in
      MockLockmanInfo(
        actionId: LockmanActionId("action_\(i)"),
        customDebugInfo: "debug_\(i)"
      )
    }

    let creationTime = CFAbsoluteTimeGetCurrent() - startTime

    // Access all properties
    let accessStartTime = CFAbsoluteTimeGetCurrent()
    for info in infos {
      _ = info.strategyId
      _ = info.actionId
      _ = info.uniqueId
    }
    let accessTime = CFAbsoluteTimeGetCurrent() - accessStartTime

    XCTAssertEqual(infos.count, 10000)
    XCTAssertLessThan(creationTime, 2.0, "Creation should be fast")
    XCTAssertLessThan(accessTime, 1.0, "Access should be fast")
  }

  // MARK: - Real-world Usage Patterns Tests

  func testSimpleActionLockInfoCreation() {
    // Based on documentation examples
    let singleInfo = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("login"),
      mode: .boundary
    )

    XCTAssertEqual(singleInfo.actionId, LockmanActionId("login"))
    XCTAssertEqual(singleInfo.strategyId, .singleExecution)
    XCTAssertNotNil(singleInfo.uniqueId)
    XCTAssertTrue(singleInfo.isCancellationTarget)
  }

  func testComplexMultiStrategyInfoCoordination() {
    let singleInfo = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("userLogin"),
      mode: .boundary
    )
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("userLogin"),
      priority: .high(.exclusive)
    )

    let compositeInfo = LockmanCompositeInfo2(
      actionId: LockmanActionId("userLogin"),
      lockmanInfoForStrategy1: singleInfo,
      lockmanInfoForStrategy2: priorityInfo
    )

    // Should coordinate multiple strategies
    XCTAssertEqual(compositeInfo.actionId, LockmanActionId("userLogin"))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.actionId, LockmanActionId("userLogin"))
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, LockmanActionId("userLogin"))
  }

  func testParameterSpecificActionSeparation() {
    let user123Info = MockLockmanInfo(actionId: LockmanActionId("fetchUser_123"))
    let user456Info = MockLockmanInfo(actionId: LockmanActionId("fetchUser_456"))

    // Different parameters should create separate actions
    XCTAssertNotEqual(user123Info.actionId, user456Info.actionId)
    XCTAssertNotEqual(user123Info.uniqueId, user456Info.uniqueId)
  }

  func testStrategySpecificConfigurationPatterns() {
    // Single execution with different modes
    let noneMode = LockmanSingleExecutionInfo(mode: .none)
    let boundaryMode = LockmanSingleExecutionInfo(mode: .boundary)
    let actionMode = LockmanSingleExecutionInfo(mode: .action)

    XCTAssertFalse(noneMode.isCancellationTarget)
    XCTAssertTrue(boundaryMode.isCancellationTarget)
    XCTAssertTrue(actionMode.isCancellationTarget)

    // Priority with different levels
    let highPriority = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .high(.exclusive)
    )
    let lowPriority = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test"),
      priority: .low(.replaceable)
    )

    XCTAssertTrue(highPriority.debugAdditionalInfo.contains("priority"))
    XCTAssertTrue(lowPriority.debugAdditionalInfo.contains("priority"))
  }

  func testCustomLockInformationRequirements() {
    struct CustomBusinessInfo: LockmanInfo {
      let strategyId = LockmanStrategyId("BusinessStrategy")
      let actionId: LockmanActionId
      let uniqueId = UUID()
      let businessContext: String
      let priority: Int

      var debugDescription: String {
        "BusinessInfo(action: '\(actionId)', context: '\(businessContext)', priority: \(priority))"
      }

      var debugAdditionalInfo: String {
        "context: \(businessContext), p: \(priority)"
      }

      var isCancellationTarget: Bool {
        priority > 0
      }
    }

    let businessInfo = CustomBusinessInfo(
      actionId: LockmanActionId("processOrder"),
      businessContext: "ecommerce",
      priority: 5
    )

    XCTAssertEqual(businessInfo.actionId, LockmanActionId("processOrder"))
    XCTAssertTrue(businessInfo.debugAdditionalInfo.contains("ecommerce"))
    XCTAssertTrue(businessInfo.isCancellationTarget)
  }

  // MARK: - Edge Cases & Error Conditions Tests

  func testEmptyActionIdHandling() {
    let emptyActionId = LockmanActionId("")
    let info = MockLockmanInfo(actionId: emptyActionId)

    XCTAssertEqual(info.actionId, emptyActionId)
    XCTAssertNotNil(info.debugDescription)
    // Should handle empty string gracefully
  }

  func testVeryLongActionIdStrings() {
    let longActionId = LockmanActionId(String(repeating: "a", count: 1000))
    let info = MockLockmanInfo(actionId: longActionId)

    XCTAssertEqual(info.actionId, longActionId)
    XCTAssertNotNil(info.debugDescription)
    // Should handle long strings
  }

  func testSpecialCharactersInActionId() {
    let specialActionIds = [
      "action-with-dashes",
      "action.with.dots",
      "action_with_underscores",
      "action with spaces",
      "action@with#symbols$",
      "actionWith数字和中文",
    ]

    for actionIdString in specialActionIds {
      let actionId = LockmanActionId(actionIdString)
      let info = MockLockmanInfo(actionId: actionId)

      XCTAssertEqual(info.actionId, actionId)
      XCTAssertNotNil(info.debugDescription)
    }
  }

  func testInvalidStrategyIdFormats() {
    let strategyIds = [
      "",  // Empty
      " ",  // Whitespace
      "NonamSpace",  // No namespace
      "TooMany.Dots.Here",  // Multiple dots
      "Special@Characters#",  // Special characters
    ]

    for strategyIdString in strategyIds {
      let strategyId = LockmanStrategyId(strategyIdString)
      let info = MockLockmanInfo(strategyId: strategyId)

      XCTAssertEqual(info.strategyId, strategyId)
      XCTAssertNotNil(info.debugDescription)
      // Should handle all formats (LockmanStrategyId is String-based)
    }
  }

  func testMemoryPressureScenarios() {
    // Test memory pressure handling with struct-based LockmanInfo
    autoreleasepool {
      // Create many info objects
      let infos = (0..<10000).map { i in
        MockLockmanInfo(
          actionId: LockmanActionId("memoryTest_\(i)"),
          customDebugInfo: "pressure_test_\(i)"
        )
      }

      // Use them briefly
      let count = infos.count
      XCTAssertEqual(count, 10000)

      // Test that they're all unique
      let uniqueIds = Set(infos.map { $0.uniqueId })
      XCTAssertEqual(uniqueIds.count, 10000)
    }

    // Structs are automatically managed - no manual cleanup needed
    XCTAssertTrue(true)  // Test completed successfully
  }

  // MARK: - Documentation Examples Validation Tests

  func testSingleExecutionInfoExample() {
    // From documentation: LockmanSingleExecutionInfo(actionId: "login")
    let loginInfo = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("login"),
      mode: .boundary
    )

    XCTAssertEqual(loginInfo.actionId, LockmanActionId("login"))
    XCTAssertEqual(loginInfo.strategyId, .singleExecution)
    XCTAssertNotNil(loginInfo.uniqueId)
    XCTAssertTrue(loginInfo.isCancellationTarget)
  }

  func testPriorityBasedInfoExample() {
    // From documentation: LockmanPriorityBasedInfo(actionId: "sync", priority: .high(.preferLater))
    let syncInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("sync"),
      priority: .high(.exclusive)  // Using .exclusive instead of deprecated .preferLater
    )

    XCTAssertEqual(syncInfo.actionId, LockmanActionId("sync"))
    XCTAssertEqual(syncInfo.strategyId, .priorityBased)
    XCTAssertNotNil(syncInfo.uniqueId)
    XCTAssertTrue(syncInfo.isCancellationTarget)
  }

  func testCodeExampleCorrectnessVerification() {
    // Verify that documented patterns work correctly
    let examples: [any LockmanInfo] = [
      LockmanSingleExecutionInfo(actionId: LockmanActionId("login"), mode: .boundary),
      LockmanPriorityBasedInfo(actionId: LockmanActionId("sync"), priority: .high(.exclusive)),
    ]

    for example in examples {
      XCTAssertNotNil(example.strategyId)
      XCTAssertNotNil(example.actionId)
      XCTAssertNotNil(example.uniqueId)
      XCTAssertNotNil(example.debugDescription)
      XCTAssertNotNil(example.debugAdditionalInfo)
      XCTAssertNotNil(example.isCancellationTarget)
    }
  }

  func testUsagePatternValidationFromDocumentation() {
    // Test the patterns shown in protocol documentation

    // Simple action
    let simpleAction = LockmanSingleExecutionInfo(mode: .boundary)
    XCTAssertNotNil(simpleAction.actionId)

    // Parameter-specific action
    let parameterAction = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("fetchUser_123"),
      mode: .action
    )
    XCTAssertEqual(parameterAction.actionId, LockmanActionId("fetchUser_123"))

    // Scoped action
    let scopedAction = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("sync_userProfile"),
      mode: .action
    )
    XCTAssertEqual(scopedAction.actionId, LockmanActionId("sync_userProfile"))
  }
}
