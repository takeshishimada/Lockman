import Foundation
import XCTest
@testable import LockmanCore

// MARK: - Test Helpers

/// Unified test boundary ID for consistent testing
private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: TestBoundaryId, rhs: TestBoundaryId) -> Bool {
    lhs.value == rhs.value
  }

  static let `default` = TestBoundaryId(value: "default")
  static let boundary1 = TestBoundaryId(value: "boundary1")
  static let boundary2 = TestBoundaryId(value: "boundary2")
}

/// Test action implementation with factory methods for clear test intent
private struct TestPriorityAction: LockmanPriorityBasedAction {
  let actionName: String
  private let _priority: LockmanPriorityBasedInfo.Priority

  var lockmanInfo: LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionName, priority: _priority)
  }

  var strategyType: LockmanPriorityBasedStrategy.Type {
    LockmanPriorityBasedStrategy.self
  }

  private init(actionName: String, priority: LockmanPriorityBasedInfo.Priority) {
    self.actionName = actionName
    self._priority = priority
  }

  // Factory methods for common test scenarios
  static func none(_ name: String = "noneAction") -> TestPriorityAction {
    TestPriorityAction(actionName: name, priority: .none)
  }

  static func lowExclusive(_ name: String = "lowExclusive") -> TestPriorityAction {
    TestPriorityAction(actionName: name, priority: .low(.exclusive))
  }

  static func lowReplaceable(_ name: String = "lowReplaceable") -> TestPriorityAction {
    TestPriorityAction(actionName: name, priority: .low(.replaceable))
  }

  static func highExclusive(_ name: String = "highExclusive") -> TestPriorityAction {
    TestPriorityAction(actionName: name, priority: .high(.exclusive))
  }

  static func highReplaceable(_ name: String = "highReplaceable") -> TestPriorityAction {
    TestPriorityAction(actionName: name, priority: .high(.replaceable))
  }
}

/// Dynamic action for testing mutable behavior
private struct DynamicPriorityAction: LockmanPriorityBasedAction {
  let actionName: String
  private var _priority: LockmanPriorityBasedInfo.Priority

  var lockmanInfo: LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionName, priority: _priority)
  }

  var strategyType: LockmanPriorityBasedStrategy.Type {
    LockmanPriorityBasedStrategy.self
  }

  init(actionName: String, priority: LockmanPriorityBasedInfo.Priority = .none) {
    self.actionName = actionName
    self._priority = priority
  }

  mutating func updatePriority(_ priority: LockmanPriorityBasedInfo.Priority) {
    self._priority = priority
  }
}

// MARK: - LockmanPriorityBasedAction Tests

final class LockmanPriorityBasedActionTests: XCTestCase {
  // MARK: - Protocol Conformance

  func testBasicProtocolConformance() {
    let action = TestPriorityAction.lowExclusive("testAction")

    XCTAssertEqual(action.actionName, "testAction")
    XCTAssertEqual(action.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(action.lockmanInfo.priority, .low(.exclusive))
    XCTAssertTrue(action.strategyType == LockmanPriorityBasedStrategy.self)
  }

  func testAllPriorityConfigurationsWorkCorrectly() {
    let testCases: [(action: TestPriorityAction, expectedPriority: LockmanPriorityBasedInfo.Priority)] = [
      (TestPriorityAction.none("none"), .none),
      (TestPriorityAction.lowExclusive("lowExc"), .low(.exclusive)),
      (TestPriorityAction.lowReplaceable("lowRepl"), .low(.replaceable)),
      (TestPriorityAction.highExclusive("highExc"), .high(.exclusive)),
      (TestPriorityAction.highReplaceable("highRepl"), .high(.replaceable)),
    ]

    for (action, expectedPriority) in testCases {
      XCTAssertEqual(action.lockmanInfo.priority, expectedPriority)
    }
  }

//  // MARK: - Strategy Resolution
//
//  //  func testStrategyTypeResolution() async throws {
//    let container  = LockmanStrategyContainer()
//    let strategy = LockmanPriorityBasedStrategy()
//    try container.register(strategy)
//
//    await Lockman.withTestContainer(container) {
//      let action = TestPriorityAction.highExclusive()
//
//      let resolvedStrategy = try! container.resolve(action.strategyType)
//      XCTAssertLessThan(resolvedStrategy is AnyLockmanStrategy, LockmanPriorityBasedInfo>)
//      XCTAssertEqual(action.strategyType, LockmanPriorityBasedStrategy.self)
//    }
//  }
//
//  //  func testMultipleActionsShareSameStrategyType() {
//    let actions  = [
//      TestPriorityAction.lowExclusive("action1"),
//      TestPriorityAction.highReplaceable("action2"),
//      TestPriorityAction.none("action3")
//    ]
//
//    let strategyTypes = Set(actions.map { $0.strategyType })
//    XCTAssertEqual(strategyTypes.count, 1)
//    XCTAssertEqual(strategyTypes.first, LockmanPriorityBasedStrategy.self)
//  }

  // MARK: - Priority Helper Methods

  func testPriorityMethodCreatesInfoWithCorrectProperties() {
    let action = TestPriorityAction.none("baseAction")

    let testCases: [(priority: LockmanPriorityBasedInfo.Priority, expectedActionId: String)] = [
      (.low(.exclusive), "baseAction"),
      (.high(.replaceable), "baseAction"),
      (.none, "baseAction"),
    ]

    for (priority, expectedActionId) in testCases {
      let info = action.priority(priority)
      XCTAssertEqual(info.actionId, expectedActionId)
      XCTAssertEqual(info.priority, priority)
    }
  }

  func testPriorityMethodWithIdSuffixCreatesCorrectActionIds() {
    let action = TestPriorityAction.none("base")

    let testCases: [(suffix: String, priority: LockmanPriorityBasedInfo.Priority, expectedActionId: String)] = [
      ("_123", .low(.exclusive), "base_123"),
      ("_suffix", .high(.replaceable), "base_suffix"),
      ("", .none, "base"),
    ]

    for (suffix, priority, expectedActionId) in testCases {
      let info = action.priority(suffix, priority)
      XCTAssertEqual(info.actionId, expectedActionId)
      XCTAssertEqual(info.priority, priority)
    }
  }

  func testPriorityMethodCreatesIndependentInstances() {
    let action = TestPriorityAction.highExclusive("test")

    // Original lockmanInfo should remain unchanged
    XCTAssertEqual(action.lockmanInfo.priority, .high(.exclusive))

    // New info should be different
    let newInfo = action.priority(.low(.replaceable))
    XCTAssertEqual(newInfo.priority, .low(.replaceable))
    XCTAssertEqual(newInfo.actionId, "test")

    // Original should still be unchanged
    XCTAssertEqual(action.lockmanInfo.priority, .high(.exclusive))
  }

  // MARK: - Description and String Representation (Removed)

  // MARK: - Dynamic Implementation

  func testDynamicPriorityActionSupportsRuntimeChanges() {
    var action = DynamicPriorityAction(actionName: "dynamic", priority: .low(.exclusive))

    XCTAssertEqual(action.lockmanInfo.priority, .low(.exclusive))
    XCTAssertEqual(action.actionName, "dynamic")

    // Test priority updates
    let priorityUpdates: [LockmanPriorityBasedInfo.Priority] = [
      .high(.replaceable),
      .none,
      .low(.replaceable),
    ]

    for newPriority in priorityUpdates {
      action.updatePriority(newPriority)
      XCTAssertEqual(action.lockmanInfo.priority, newPriority)
    }
  }

  // MARK: - Integration Tests

//  //  func testIntegrationWithStrategyContainerWorksCorrectly() async throws {
//    let container  = LockmanStrategyContainer()
//    let strategy = LockmanPriorityBasedStrategy()
//    try container.register(strategy)
//
//    await Lockman.withTestContainer(container) {
//      let actions = [
//        TestPriorityAction.lowExclusive("action1"),
//        TestPriorityAction.highReplaceable("action2")
//      ]
//
//      for action in actions {
//        let resolvedStrategy = try! container.resolve(action.strategyType)
//        XCTAssertLessThan(resolvedStrategy is AnyLockmanStrategy, LockmanPriorityBasedInfo>)
//      }
//    }
//  }

  func testActionInfoEqualitySemanticsWorkAsExpected() {
    let action1 = TestPriorityAction.lowExclusive("sameAction")
    let action2 = TestPriorityAction.highReplaceable("sameAction")
    let action3 = TestPriorityAction.lowExclusive("differentAction")

    // Same actionId but different instances
    XCTAssertEqual(action1.lockmanInfo.actionId, action2.lockmanInfo.actionId)
    XCTAssertNotEqual(action1.lockmanInfo, action2.lockmanInfo) // Different uniqueId

    // Different actionIds
    XCTAssertNotEqual(action1.lockmanInfo.actionId, action3.lockmanInfo.actionId)
    XCTAssertNotEqual(action2.lockmanInfo.actionId, action3.lockmanInfo.actionId)
  }

  // MARK: - Error Handling

  func testUnregisteredStrategyThrowsAppropriateError() async throws {
    let emptyContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(emptyContainer) {
      let action = TestPriorityAction.highExclusive()

      do {
        _ = try emptyContainer.resolve(action.strategyType)
        XCTFail("Expected error to be thrown")
      } catch is LockmanRegistrationError {
        // Expected error
      } catch {
        XCTFail("Unexpected error type: \(error)")
      }
    }
  }

  func testErrorContainsCorrectStrategyInformation() async throws {
    let emptyContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(emptyContainer) {
      let action = TestPriorityAction.lowReplaceable()

      do {
        _ = try emptyContainer.resolve(action.strategyType)
        XCTFail("Should have thrown an error")
      } catch let error as LockmanRegistrationError {
        if case let .strategyNotRegistered(strategyName) = error {
          XCTAssertTrue(strategyName.contains("LockmanPriorityBasedStrategy"))
        } else {
          XCTFail("Wrong error case")
        }
      } catch {
        XCTFail("Wrong error type")
      }
    }
  }

  // MARK: - Type Safety

//  //  func testAssociatedTypesAreCorrectlyConstrained() {
//    // Compile-time verification through type checking
//    let _: LockmanPriorityBasedInfo.Type = TestPriorityAction.I.self
//    let _: LockmanPriorityBasedStrategy.Type = TestPriorityAction.S.self
//
//    // Runtime verification
//    let action = TestPriorityAction.highExclusive()
//    XCTAssertTrue(action.lockmanInfo is LockmanPriorityBasedInfo)
//  }
//
//  //  func testProtocolInheritanceHierarchyWorksCorrectly() {
//    let action = TestPriorityAction.lowReplaceable()
//
//    // Should work as base LockmanAction
//    let baseAction: any LockmanAction = action
//    XCTAssertTrue(baseAction.description.contains("lowReplaceable"))
//
//    // Associated types should be correct through type checking
//    let _: LockmanPriorityBasedInfo.Type = type(of: baseAction).I.self
//    let _: LockmanPriorityBasedStrategy.Type = type(of: baseAction).S.self
//  }

  // MARK: - Edge Cases

  func testSpecialActionNamesAreHandledCorrectly() {
    let specialNames = [
      "",
      " ",
      "action-with-dashes",
      "action_with_underscores",
      "action.with.dots",
      "action with spaces",
      "アクション",
      "🚀action",
      "ação",
    ]

    for name in specialNames {
      let action = TestPriorityAction.highReplaceable(name)
      XCTAssertEqual(action.actionName, name)
      XCTAssertEqual(action.lockmanInfo.actionId, name)

      // Should work with priority methods
      let infoWithSuffix = action.priority("_test", .low(.exclusive))
      XCTAssertEqual(infoWithSuffix.actionId, name + "_test")
    }
  }

  func testEmptyActionNameEdgeCases() {
    let action = TestPriorityAction.none("")

    XCTAssertEqual(action.actionName, "")
    XCTAssertEqual(action.lockmanInfo.actionId, "")

    // Should work with priority methods
    let infoWithSuffix = action.priority("_suffix", .high(.exclusive))
    XCTAssertEqual(infoWithSuffix.actionId, "_suffix")

    let infoWithEmpty = action.priority("", .low(.replaceable))
    XCTAssertEqual(infoWithEmpty.actionId, "")
  }
}
