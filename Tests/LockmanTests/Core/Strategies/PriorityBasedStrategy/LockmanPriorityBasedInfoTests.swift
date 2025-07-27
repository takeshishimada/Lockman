import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Helpers

/// Unified test boundary ID for integration tests
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

/// Factory for creating test info instances with clear intent
private enum TestInfoFactory {
  static func none(_ actionId: String = "noneAction")
    -> LockmanPriorityBasedInfo
  {
    LockmanPriorityBasedInfo(
      actionId: actionId, priority: .none)
  }

  static func lowExclusive(_ actionId: String = "lowExclusive")
    -> LockmanPriorityBasedInfo
  {
    LockmanPriorityBasedInfo(
      actionId: actionId, priority: .low(.exclusive))
  }

  static func lowReplaceable(_ actionId: String = "lowReplaceable")
    -> LockmanPriorityBasedInfo
  {
    LockmanPriorityBasedInfo(
      actionId: actionId, priority: .low(.replaceable))
  }

  static func highExclusive(_ actionId: String = "highExclusive")
    -> LockmanPriorityBasedInfo
  {
    LockmanPriorityBasedInfo(
      actionId: actionId, priority: .high(.exclusive))
  }

  static func highReplaceable(_ actionId: String = "highReplaceable")
    -> LockmanPriorityBasedInfo
  {
    LockmanPriorityBasedInfo(
      actionId: actionId, priority: .high(.replaceable))
  }
}

// MARK: - LockmanPriorityBasedInfo Tests

final class LockmanPriorityBasedInfoTests: XCTestCase {
  // MARK: - Initialization and Properties

  func testInitializeWithAllPriorityLevels() {
    let actionId = "testAction"

    let testCases:
      [(info: LockmanPriorityBasedInfo, expectedPriority: LockmanPriorityBasedInfo.Priority)] = [
        (TestInfoFactory.none(actionId), .none),
        (TestInfoFactory.lowExclusive(actionId), .low(.exclusive)),
        (TestInfoFactory.lowReplaceable(actionId), .low(.replaceable)),
        (TestInfoFactory.highExclusive(actionId), .high(.exclusive)),
        (TestInfoFactory.highReplaceable(actionId), .high(.replaceable)),
      ]

    for (info, expectedPriority) in testCases {
      XCTAssertEqual(info.actionId, actionId)
      XCTAssertEqual(info.priority, expectedPriority)
    }
  }

  func testUniqueIdGenerationEnsuresInstanceUniqueness() {
    let info1 = TestInfoFactory.lowExclusive("same")
    let info2 = TestInfoFactory.lowExclusive("same")

    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertEqual(info1.actionId, info2.actionId)
  }

  // MARK: - Equality Semantics (Based on Actual Implementation)

  func testEqualityBasedOnUniqueIdNotActionId() {
    let info1 = TestInfoFactory.lowExclusive("same")
    let info2 = TestInfoFactory.highReplaceable("same")  // Same actionId, different priority
    let info3 = info1  // Same instance

    // Different instances are never equal regardless of actionId
    XCTAssertNotEqual(info1, info2)

    // Same instance is equal to itself
    XCTAssertEqual(info1, info3)

    // ActionIds can match even when instances differ
    XCTAssertEqual(info1.actionId, info2.actionId)
  }

  func testArrayOperationsWorkCorrectlyWithEquality() {
    let info1 = TestInfoFactory.lowExclusive("action1")
    let info2 = TestInfoFactory.lowExclusive("action1")  // Same actionId, different instance
    let info3 = TestInfoFactory.highReplaceable("action2")

    let infoArray = [info1, info3]

    XCTAssertTrue(infoArray.contains(info1))
    XCTAssertTrue(infoArray.contains(info3))
    XCTAssertFalse(infoArray.contains(info2))  // Different unique ID

    XCTAssertTrue(infoArray.firstIndex(of: info1) == 0)
    XCTAssertTrue(infoArray.firstIndex(of: info3) == 1)
    XCTAssertTrue(infoArray.firstIndex(of: info2) == nil)
  }

  // MARK: - Priority Comparison

  func testPriorityHierarchyOrdering() {
    let none = LockmanPriorityBasedInfo.Priority.none
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Test hierarchy: none < low < high
    XCTAssertLessThan(none, lowExclusive)
    XCTAssertLessThan(none, lowReplaceable)
    XCTAssertLessThan(lowExclusive, highExclusive)
    XCTAssertLessThan(lowReplaceable, highReplaceable)
    XCTAssertLessThan(none, highExclusive)
    XCTAssertLessThan(none, highReplaceable)
  }

  func testSamePriorityLevelEqualityIgnoresBehavior() {
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Same priority levels are equal regardless of behavior
    XCTAssertEqual(lowExclusive, lowReplaceable)
    XCTAssertEqual(highExclusive, highReplaceable)

    // Different priority levels are not equal
    XCTAssertNotEqual(lowExclusive, highExclusive)
    XCTAssertNotEqual(lowReplaceable, highReplaceable)

    // No ordering within same priority level
    XCTAssertFalse(lowExclusive < lowReplaceable)
    XCTAssertFalse(lowReplaceable < lowExclusive)
  }

  func testPriorityComparisonMatrixValidation() {
    let priorities: [LockmanPriorityBasedInfo.Priority] = [
      .none,
      .low(.exclusive),
      .low(.replaceable),
      .high(.exclusive),
      .high(.replaceable),
    ]

    let expectedHierarchy = [0, 1, 1, 2, 2]  // none=0, low=1, high=2

    for i in 0..<priorities.count {
      for j in 0..<priorities.count {
        let p1 = priorities[i]
        let p2 = priorities[j]
        let level1 = expectedHierarchy[i]
        let level2 = expectedHierarchy[j]

        if level1 < level2 {
          XCTAssertLessThan(p1, p2)
          XCTAssertNotEqual(p1, p2)
        } else if level1 > level2 {
          XCTAssertGreaterThan(p1, p2)
          XCTAssertNotEqual(p1, p2)
        } else {
          XCTAssertEqual(p1, p2)
          XCTAssertFalse(p1 < p2)
          XCTAssertFalse(p1 > p2)
        }
      }
    }
  }

  // MARK: - Behavior Property Access

  func testBehaviorPropertyAccess() {
    let testCases:
      [(
        priority: LockmanPriorityBasedInfo.Priority,
        expectedBehavior: LockmanPriorityBasedInfo.ConcurrencyBehavior?
      )] = [
        (.none, nil),
        (.low(.exclusive), .exclusive),
        (.low(.replaceable), .replaceable),
        (.high(.exclusive), .exclusive),
        (.high(.replaceable), .replaceable),
      ]

    for (priority, expectedBehavior) in testCases {
      XCTAssertEqual(priority.behavior, expectedBehavior)
    }
  }

  // MARK: - String Representations (Removed since description functionality was removed)

  // MARK: - Concurrency and Sendable

  func testConcurrentAccessMaintainsDataIntegrity() async {
    let info = TestInfoFactory.highExclusive("concurrentAction")

    let results = await withTaskGroup(
      of: LockmanPriorityBasedInfo.self, returning: [LockmanPriorityBasedInfo].self
    ) { group in
      for _ in 0..<5 {
        group.addTask { info }
      }

      var results: [LockmanPriorityBasedInfo] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // All results should maintain data integrity
    for result in results {
      XCTAssertEqual(result, info)
      XCTAssertEqual(result.actionId, "concurrentAction")
      XCTAssertEqual(result.priority, .high(.exclusive))
    }
  }

  // MARK: - Edge Cases and Robustness

  //  //  func testSpecialCharacterActionIds() {
  //    let specialActionIds  = [
  //      "",
  //      " ",
  //      "action with spaces",
  //      "action\nwith\nnewlines",
  //      "action\twith\ttabs",
  //      "action-with-dashes",
  //      "action_with_underscores",
  //      "action.with.dots"
  //    ]
  //
  //    for actionId in specialActionIds {
  //      let info = TestInfoFactory.highExclusive(actionId)
  //
  //      XCTAssertEqual(info.actionId, actionId)
  //      XCTAssertEqual(info.priority, .high(.exclusive)
  //      // XCTAssertTrue(info.description.contains(actionId)) // Removed - description functionality removed
  //    }
  //  }

  func testUnicodeActionIdSupport() {
    let unicodeActionIds = [
      "アクション",
      "行动",
      "действие",
      "🚀🎯🔥",
      "action🌟test",
      "ação_especial",
    ]

    for actionId in unicodeActionIds {
      let info = TestInfoFactory.lowReplaceable(actionId)

      XCTAssertEqual(info.actionId, actionId)
      XCTAssertEqual(info.priority, .low(.replaceable))
      // XCTAssertTrue(info.description.contains(actionId)) // Removed - description functionality removed
    }
  }

  func testValueTypeSemanticsPreservation() {
    let original = TestInfoFactory.lowExclusive("original")
    let copy = original

    // Copy should be equal to original (same instance)
    XCTAssertEqual(copy, original)
    XCTAssertEqual(copy.actionId, original.actionId)
    XCTAssertEqual(copy.priority, original.priority)
    XCTAssertEqual(copy.uniqueId, original.uniqueId)

    // New instance with same parameters should not be equal
    let different = TestInfoFactory.lowExclusive("original")
    XCTAssertNotEqual(different, original)  // Different uniqueId
    XCTAssertEqual(different.actionId, original.actionId)  // Same actionId
  }

  // MARK: - Performance

  func testPriorityComparisonPerformance() {
    let priorities: [LockmanPriorityBasedInfo.Priority] = [
      .none,
      .low(.exclusive),
      .low(.replaceable),
      .high(.exclusive),
      .high(.replaceable),
    ]

    let startTime = Date()

    // Perform many comparisons (reduced iterations for stability)
    for _ in 0..<100 {
      for i in 0..<priorities.count {
        for j in 0..<priorities.count {
          _ = priorities[i] < priorities[j]
          _ = priorities[i] == priorities[j]
          _ = priorities[i] > priorities[j]
        }
      }
    }

    let duration = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(duration, 0.1)  // Should complete quickly
  }

  // MARK: - Cancellation Target Tests

  func testIsCancellationTargetForNonePriority() {
    let info = TestInfoFactory.none("testNone")
    XCTAssertFalse(info.isCancellationTarget, "None priority should not be cancellation target")
  }

  func testIsCancellationTargetForLowPriority() {
    let lowExclusive = TestInfoFactory.lowExclusive("testLowExclusive")
    let lowReplaceable = TestInfoFactory.lowReplaceable("testLowReplaceable")

    XCTAssertTrue(
      lowExclusive.isCancellationTarget, "Low exclusive priority should be cancellation target")
    XCTAssertTrue(
      lowReplaceable.isCancellationTarget, "Low replaceable priority should be cancellation target")
  }

  func testIsCancellationTargetForHighPriority() {
    let highExclusive = TestInfoFactory.highExclusive("testHighExclusive")
    let highReplaceable = TestInfoFactory.highReplaceable("testHighReplaceable")

    XCTAssertTrue(
      highExclusive.isCancellationTarget, "High exclusive priority should be cancellation target")
    XCTAssertTrue(
      highReplaceable.isCancellationTarget,
      "High replaceable priority should be cancellation target")
  }

  func testIsCancellationTargetConsistentWithPriorityLogic() {
    let testCases: [(LockmanPriorityBasedInfo, Bool, String)] = [
      (TestInfoFactory.none(), false, "none priority"),
      (TestInfoFactory.lowExclusive(), true, "low exclusive priority"),
      (TestInfoFactory.lowReplaceable(), true, "low replaceable priority"),
      (TestInfoFactory.highExclusive(), true, "high exclusive priority"),
      (TestInfoFactory.highReplaceable(), true, "high replaceable priority"),
    ]

    for (info, expected, description) in testCases {
      XCTAssertEqual(
        info.isCancellationTarget, expected, "\(description) cancellation target mismatch")

      // Verify consistency: non-none priorities should be cancellation targets
      let isNonePriority = (info.priority == .none)
      XCTAssertEqual(
        info.isCancellationTarget, !isNonePriority,
        "Cancellation target should be inverse of none priority for \(description)")
    }
  }
  // MARK: - Protocol Conformance

  func testLockmanInfoProtocolConformance() {
    let info = TestInfoFactory.highExclusive("testProtocol")

    // Should work as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    XCTAssertEqual(lockmanInfo.actionId, "testProtocol")
    // XCTAssertTrue(lockmanInfo.description.contains("testProtocol")) // Removed - description functionality removed
    XCTAssertEqual(lockmanInfo.uniqueId, info.uniqueId)
  }
}

// MARK: - Integration Tests

final class LockmanPriorityBasedInfoIntegrationTests: XCTestCase {
  //  //  func testIntegrationWithLockmanState() {
  //    let state  = LockmanState<LockmanPriorityBasedInfo>()
  //    let boundaryId = TestBoundaryId.default
  //
  //    let info1 = TestInfoFactory.lowExclusive("action1")
  //    let info2 = TestInfoFactory.highReplaceable("action2")
  //    let info3 = TestInfoFactory.none("action3")
  //
  //    // Add infos to state
  //    state.add(id: boundaryId, info: info1)
  //    state.add(id: boundaryId, info: info2)
  //    state.add(id: boundaryId, info: info3)
  //
  //    // Verify state contains all infos in order
  //    let currents = state.currents(id: boundaryId)
  //    XCTAssertEqual(currents.count, 3)
  //    XCTAssertEqual(currents[0], info1)
  //    XCTAssertEqual(currents[1], info2)
  //    XCTAssertEqual(currents[2], info3)
  //
  //    // Remove by instance
  //    state.remove(id: boundaryId, info: info2)
  //    let afterRemove  = state.currents(id: boundaryId)
  //    XCTAssertEqual(afterRemove.count, 2)
  //    XCTAssertEqual(afterRemove[0], info1)
  //    XCTAssertEqual(afterRemove[1], info3)
  //
  //    // Remove by action ID
  //    state.remove(id: boundaryId, actionId: info1.actionId)
  //    let afterActionIdRemove  = state.currents(id: boundaryId)
  //    XCTAssertEqual(afterActionIdRemove.count, 1)
  //    XCTAssertEqual(afterActionIdRemove[0], info3)
  //
  //    // Clean up
  //    state.removeAll()
  //    XCTAssertTrue(state.currents(id: boundaryId).isEmpty)
  //  }

  func testPriorityBasedSortingBehavior() {
    var infos: [LockmanPriorityBasedInfo] = [
      TestInfoFactory.lowReplaceable("1"),
      TestInfoFactory.highExclusive("2"),
      TestInfoFactory.none("3"),
      TestInfoFactory.highReplaceable("4"),
      TestInfoFactory.lowExclusive("5"),
    ]

    // Sort by priority (ascending)
    infos.sort { $0.priority < $1.priority }

    // Verify order: none first, then low priorities, then high priorities
    XCTAssertEqual(infos[0].priority, .none)

    // Verify low priorities are in positions 1-2 (any order within same level)
    for index in 1...2 {
      switch infos[index].priority {
      case .low:
        break  // Correct
      default:
        XCTFail("Expected low priority at index \(index)")
      }
    }

    // Verify high priorities are in positions 3-4 (any order within same level)
    for index in 3...4 {
      switch infos[index].priority {
      case .high:
        break  // Correct
      default:
        XCTFail("Expected high priority at index \(index)")
      }
    }
  }

  func testIntegrationWithPriorityStrategy() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()
    do {
      try container.register(strategy)
    } catch {
      XCTFail("Unexpected error: \(error)")
    }

    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.default
      let info1 = TestInfoFactory.lowExclusive("action1")
      let info2 = TestInfoFactory.highReplaceable("action2")
      let info3 = TestInfoFactory.none("action3")

      let resolvedStrategy: AnyLockmanStrategy<LockmanPriorityBasedInfo>
      do {
        resolvedStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)
      } catch {
        XCTFail("Unexpected error: \(error)")
        return
      }

      // Test basic locking behavior
      XCTAssertEqual(resolvedStrategy.canLock(boundaryId: boundaryId, info: info1), .success)
      resolvedStrategy.lock(boundaryId: boundaryId, info: info1)

      // None priority always succeeds
      XCTAssertEqual(resolvedStrategy.canLock(boundaryId: boundaryId, info: info3), .success)

      // Higher priority preempts lower priority
      if case .successWithPrecedingCancellation = resolvedStrategy.canLock(
        boundaryId: boundaryId, info: info2)
      {
        // Success - expected behavior
      } else {
        XCTFail("Expected successWithPrecedingCancellation")
      }

      resolvedStrategy.cleanUp()
    }
  }

  func testComplexPriorityInteractionScenario() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = TestBoundaryId.default

    let noneInfo = TestInfoFactory.none("none")
    let lowExclusiveInfo = TestInfoFactory.lowExclusive("lowExc")
    let highReplaceableInfo = TestInfoFactory.highReplaceable("highRepl")
    let anotherLowInfo = TestInfoFactory.lowExclusive("lowExc2")

    // None priority always succeeds
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: noneInfo), .success)

    // First low priority succeeds
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: lowExclusiveInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: lowExclusiveInfo)

    // High priority preempts low priority
    if case .successWithPrecedingCancellation = strategy.canLock(
      boundaryId: boundaryId, info: highReplaceableInfo)
    {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }
    strategy.lock(boundaryId: boundaryId, info: highReplaceableInfo)

    // Another low priority fails against high priority
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: anotherLowInfo))

    // None priority still succeeds
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: noneInfo), .success)

    strategy.cleanUp()
  }

  func testBoundaryIsolationMaintainsSeparation() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundary1 = TestBoundaryId.boundary1
    let boundary2 = TestBoundaryId.boundary2

    let info = TestInfoFactory.highExclusive("shared")

    // Same info can be locked on different boundaries
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info), .success)
    strategy.lock(boundaryId: boundary1, info: info)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info), .success)
    strategy.lock(boundaryId: boundary2, info: info)

    // But duplicate on same boundary fails
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary1, info: info))
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary2, info: info))

    // Cleanup only affects specific boundary
    strategy.cleanUp(boundaryId: boundary1)
    XCTAssertEqual(strategy.canLock(boundaryId: boundary1, info: info), .success)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary2, info: info))  // Still locked

    strategy.cleanUp()
  }
}
