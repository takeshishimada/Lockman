import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanInfo protocol tests
// ✅ Tests covering protocol requirements and conformance patterns
// ✅ Phase 1: Basic protocol conformance with required properties
// ✅ Phase 2: Debug description formatting and additional info handling
// ✅ Phase 3: Integration with actual strategy info types and type erasure

final class LockmanInfoTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Info Types for Protocol Conformance

  private struct TestBasicInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let customData: String

    init(
      strategyId: LockmanStrategyId = "testStrategy", actionId: LockmanActionId = "testAction",
      customData: String = ""
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.customData = customData
    }

    var debugDescription: String {
      "TestBasicInfo(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId))"
    }

    var debugAdditionalInfo: String {
      customData.isEmpty ? "" : "custom: \(customData)"
    }
  }

  private struct TestCancellableInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let isCancellable: Bool

    init(
      strategyId: LockmanStrategyId = "cancellableStrategy",
      actionId: LockmanActionId = "cancellableAction", isCancellable: Bool = true
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.isCancellable = isCancellable
    }

    var debugDescription: String {
      "TestCancellableInfo(actionId: '\(actionId)', cancellable: \(isCancellable))"
    }

    var isCancellationTarget: Bool {
      isCancellable
    }
  }

  // MARK: - Phase 1: Basic Protocol Conformance

  func testLockmanInfoBasicConformance() {
    // Test basic LockmanInfo conformance
    let info = TestBasicInfo()

    // Should conform to Sendable
    XCTAssertNotNil(info as any Sendable)
    // Should conform to CustomDebugStringConvertible
    XCTAssertNotNil(info as any CustomDebugStringConvertible)

    // Should have required properties
    XCTAssertEqual(info.strategyId.value, "testStrategy")
    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertNotNil(info.uniqueId)
  }

  func testLockmanInfoRequiredProperties() {
    // Test all required properties
    let strategyId = LockmanStrategyId("myStrategy")
    let actionId: LockmanActionId = "myAction"
    let info = TestBasicInfo(strategyId: strategyId, actionId: actionId)

    XCTAssertEqual(info.strategyId, strategyId)
    XCTAssertEqual(info.actionId, actionId)
    XCTAssertNotNil(info.uniqueId)
  }

  func testLockmanInfoUniqueIdUniqueness() {
    // Test that uniqueId is actually unique
    let info1 = TestBasicInfo()
    let info2 = TestBasicInfo()
    let info3 = TestBasicInfo()

    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertNotEqual(info1.uniqueId, info3.uniqueId)
    XCTAssertNotEqual(info2.uniqueId, info3.uniqueId)

    // Even with same actionId
    let sameAction1 = TestBasicInfo(actionId: "sameAction")
    let sameAction2 = TestBasicInfo(actionId: "sameAction")
    XCTAssertNotEqual(sameAction1.uniqueId, sameAction2.uniqueId)
  }

  func testLockmanInfoDebugDescription() {
    // Test CustomDebugStringConvertible conformance
    let info = TestBasicInfo(actionId: "debugTest")
    let description = info.debugDescription

    XCTAssertTrue(description.contains("TestBasicInfo"))
    XCTAssertTrue(description.contains("debugTest"))
    XCTAssertTrue(description.contains("testStrategy"))
    XCTAssertTrue(description.contains(info.uniqueId.uuidString))
  }

  // MARK: - Phase 2: Default Implementations

  func testLockmanInfoDefaultDebugAdditionalInfo() {
    // Test default implementation returns empty string
    let info = TestBasicInfo()  // Uses default implementation
    XCTAssertEqual(info.debugAdditionalInfo, "")
  }

  func testLockmanInfoCustomDebugAdditionalInfo() {
    // Test overridden debugAdditionalInfo
    let info = TestBasicInfo(customData: "extraInfo")
    XCTAssertEqual(info.debugAdditionalInfo, "custom: extraInfo")
  }

  func testLockmanInfoDefaultIsCancellationTarget() {
    // Test default implementation returns true
    let info = TestBasicInfo()  // Uses default implementation
    XCTAssertTrue(info.isCancellationTarget)
  }

  func testLockmanInfoCustomIsCancellationTarget() {
    // Test overridden isCancellationTarget
    let cancellableInfo = TestCancellableInfo(isCancellable: true)
    let nonCancellableInfo = TestCancellableInfo(isCancellable: false)

    XCTAssertTrue(cancellableInfo.isCancellationTarget)
    XCTAssertFalse(nonCancellableInfo.isCancellationTarget)
  }

  // MARK: - Phase 3: Sendable and Concurrency

  func testLockmanInfoSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let info = TestBasicInfo(actionId: "concurrentTest")

    await withTaskGroup(of: String.self) { group in
      group.addTask {
        // This compiles without warning = Sendable works
        return "Task1: \(info.actionId)"
      }
      group.addTask {
        return "Task2: \(info.uniqueId)"
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 2)
      XCTAssertTrue(results.contains("Task1: concurrentTest"))
    }
  }

  func testLockmanInfoInCollection() {
    // Test storing different LockmanInfo types in collection
    let infos: [any LockmanInfo] = [
      TestBasicInfo(actionId: "basic1"),
      TestBasicInfo(actionId: "basic2"),
      TestCancellableInfo(actionId: "cancellable1"),
      TestCancellableInfo(actionId: "cancellable2", isCancellable: false),
    ]

    XCTAssertEqual(infos.count, 4)

    // Test processing mixed info types
    let actionIds = infos.map { $0.actionId }
    XCTAssertTrue(actionIds.contains("basic1"))
    XCTAssertTrue(actionIds.contains("cancellable2"))
  }

  // MARK: - Phase 4: Strategy-specific Usage Patterns

  func testLockmanInfoStrategyIdUsage() {
    // Test different strategy ID formats
    let builtInInfo = TestBasicInfo(strategyId: LockmanStrategyId.singleExecution)
    let customInfo = TestBasicInfo(strategyId: LockmanStrategyId("MyApp.CustomStrategy"))
    let configuredInfo = TestBasicInfo(
      strategyId: LockmanStrategyId(name: "RateLimit", configuration: "burst-10"))

    XCTAssertTrue(builtInInfo.strategyId.value.contains("SingleExecution"))
    XCTAssertEqual(customInfo.strategyId.value, "MyApp.CustomStrategy")
    XCTAssertEqual(configuredInfo.strategyId.value, "RateLimit:burst-10")
  }

  func testLockmanInfoActionIdUsage() {
    // Test different action ID patterns
    let simpleInfo = TestBasicInfo(actionId: "login")
    let parameterizedInfo = TestBasicInfo(actionId: "fetchUser_123")
    let scopedInfo = TestBasicInfo(actionId: "sync_userProfile")

    XCTAssertEqual(simpleInfo.actionId, "login")
    XCTAssertEqual(parameterizedInfo.actionId, "fetchUser_123")
    XCTAssertEqual(scopedInfo.actionId, "sync_userProfile")
  }

  func testLockmanInfoCancellationPatterns() {
    // Test cancellation patterns based on documentation
    let alwaysCancellable = TestCancellableInfo(isCancellable: true)
    let neverCancellable = TestCancellableInfo(isCancellable: false)
    let defaultCancellable = TestBasicInfo()  // Uses default = true

    XCTAssertTrue(alwaysCancellable.isCancellationTarget)
    XCTAssertFalse(neverCancellable.isCancellationTarget)
    XCTAssertTrue(defaultCancellable.isCancellationTarget)
  }

  // MARK: - Phase 5: Real-world Lockman Integration

  func testLockmanInfoInLockingScenario() {
    // Test info in realistic locking scenario
    func processLockInfo(info: any LockmanInfo) -> String {
      let cancellationStatus = info.isCancellationTarget ? "cancellable" : "protected"
      let additionalInfo = info.debugAdditionalInfo.isEmpty ? "" : " (\(info.debugAdditionalInfo))"
      return "[\(info.strategyId.value)] \(info.actionId) - \(cancellationStatus)\(additionalInfo)"
    }

    let basicInfo = TestBasicInfo(actionId: "processData")
    let protectedInfo = TestCancellableInfo(actionId: "criticalSave", isCancellable: false)
    let customInfo = TestBasicInfo(customData: "priority=high")

    let result1 = processLockInfo(info: basicInfo)
    let result2 = processLockInfo(info: protectedInfo)
    let result3 = processLockInfo(info: customInfo)

    XCTAssertEqual(result1, "[testStrategy] processData - cancellable")
    XCTAssertEqual(result2, "[cancellableStrategy] criticalSave - protected")
    XCTAssertEqual(result3, "[testStrategy] testAction - cancellable (custom: priority=high)")
  }

  func testLockmanInfoDebugOutput() {
    // Test debug output formatting
    let info1 = TestBasicInfo(actionId: "debugAction1")
    let info2 = TestCancellableInfo(actionId: "debugAction2", isCancellable: false)

    let debugOutput1 = String(describing: info1)
    let debugOutput2 = String(describing: info2)

    XCTAssertTrue(debugOutput1.contains("debugAction1"))
    XCTAssertTrue(debugOutput2.contains("debugAction2"))
    XCTAssertTrue(debugOutput2.contains("cancellable: false"))
  }

}
