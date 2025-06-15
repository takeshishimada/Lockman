import Foundation
import Testing
@testable import LockmanCore

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
  static func none(_ actionId: String = "noneAction", blocksSameAction: Bool = false) -> LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionId, priority: .none, blocksSameAction: blocksSameAction)
  }

  static func lowExclusive(_ actionId: String = "lowExclusive", blocksSameAction: Bool = false) -> LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionId, priority: .low(.exclusive), blocksSameAction: blocksSameAction)
  }

  static func lowReplaceable(_ actionId: String = "lowReplaceable", blocksSameAction: Bool = false) -> LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionId, priority: .low(.replaceable), blocksSameAction: blocksSameAction)
  }

  static func highExclusive(_ actionId: String = "highExclusive", blocksSameAction: Bool = false) -> LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive), blocksSameAction: blocksSameAction)
  }

  static func highReplaceable(_ actionId: String = "highReplaceable", blocksSameAction: Bool = false) -> LockmanPriorityBasedInfo {
    LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.replaceable), blocksSameAction: blocksSameAction)
  }
}

// MARK: - LockmanPriorityBasedInfo Tests

@Suite("LockmanPriorityBasedInfo Tests")
struct LockmanPriorityBasedInfoTests {
  // MARK: - Initialization and Properties

  @Test("Initialize with all priority levels")
  func testInitializeWithAllPriorityLevels() {
    let actionId = "testAction"

    let testCases: [(info: LockmanPriorityBasedInfo, expectedPriority: LockmanPriorityBasedInfo.Priority)] = [
      (TestInfoFactory.none(actionId), .none),
      (TestInfoFactory.lowExclusive(actionId), .low(.exclusive)),
      (TestInfoFactory.lowReplaceable(actionId), .low(.replaceable)),
      (TestInfoFactory.highExclusive(actionId), .high(.exclusive)),
      (TestInfoFactory.highReplaceable(actionId), .high(.replaceable)),
    ]

    for (info, expectedPriority) in testCases {
      #expect(info.actionId == actionId)
      #expect(info.priority == expectedPriority)
      #expect(info.blocksSameAction == false) // Default value
    }
  }

  @Test("Initialize with blocksSameAction")
  func testInitializeWithBlocksSameAction() {
    let actionId = "testAction"

    // Test default value
    let info1 = LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive))
    #expect(info1.blocksSameAction == false)

    // Test explicit false
    let info2 = LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive), blocksSameAction: false)
    #expect(info2.blocksSameAction == false)

    // Test explicit true
    let info3 = LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive), blocksSameAction: true)
    #expect(info3.blocksSameAction == true)

    // Test with factory methods
    let info4 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    #expect(info4.blocksSameAction == true)
  }

  @Test("Unique ID generation ensures instance uniqueness")
  func testUniqueIdGenerationEnsuresInstanceUniqueness() {
    let info1 = TestInfoFactory.lowExclusive("same")
    let info2 = TestInfoFactory.lowExclusive("same")

    #expect(info1.uniqueId != info2.uniqueId)
    #expect(info1.actionId == info2.actionId)
  }

  // MARK: - Equality Semantics (Based on Actual Implementation)

  @Test("Equality based on unique ID not action ID")
  func testEqualityBasedOnUniqueIdNotActionId() {
    let info1 = TestInfoFactory.lowExclusive("same")
    let info2 = TestInfoFactory.highReplaceable("same") // Same actionId, different priority
    let info3 = info1 // Same instance

    // Different instances are never equal regardless of actionId
    #expect(info1 != info2)

    // Same instance is equal to itself
    #expect(info1 == info3)

    // ActionIds can match even when instances differ
    #expect(info1.actionId == info2.actionId)
  }

  @Test("Array operations work correctly with equality")
  func testArrayOperationsWorkCorrectlyWithEquality() {
    let info1 = TestInfoFactory.lowExclusive("action1")
    let info2 = TestInfoFactory.lowExclusive("action1") // Same actionId, different instance
    let info3 = TestInfoFactory.highReplaceable("action2")

    let infoArray = [info1, info3]

    #expect(infoArray.contains(info1))
    #expect(infoArray.contains(info3))
    #expect(!infoArray.contains(info2)) // Different unique ID

    #expect(infoArray.firstIndex(of: info1) == 0)
    #expect(infoArray.firstIndex(of: info3) == 1)
    #expect(infoArray.firstIndex(of: info2) == nil)
  }

  // MARK: - Priority Comparison

  @Test("Priority hierarchy ordering")
  func testPriorityHierarchyOrdering() {
    let none = LockmanPriorityBasedInfo.Priority.none
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Test hierarchy: none < low < high
    #expect(none < lowExclusive)
    #expect(none < lowReplaceable)
    #expect(lowExclusive < highExclusive)
    #expect(lowReplaceable < highReplaceable)
    #expect(none < highExclusive)
    #expect(none < highReplaceable)
  }

  @Test("Same priority level equality ignores behavior")
  func testSamePriorityLevelEqualityIgnoresBehavior() {
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Same priority levels are equal regardless of behavior
    #expect(lowExclusive == lowReplaceable)
    #expect(highExclusive == highReplaceable)

    // Different priority levels are not equal
    #expect(lowExclusive != highExclusive)
    #expect(lowReplaceable != highReplaceable)

    // No ordering within same priority level
    #expect(!(lowExclusive < lowReplaceable))
    #expect(!(lowExclusive > lowReplaceable))
  }

  @Test("Priority comparison matrix validation")
  func testPriorityComparisonMatrixValidation() {
    let priorities: [LockmanPriorityBasedInfo.Priority] = [
      .none,
      .low(.exclusive),
      .low(.replaceable),
      .high(.exclusive),
      .high(.replaceable),
    ]

    let expectedHierarchy = [0, 1, 1, 2, 2] // none=0, low=1, high=2

    for i in 0 ..< priorities.count {
      for j in 0 ..< priorities.count {
        let p1 = priorities[i]
        let p2 = priorities[j]
        let level1 = expectedHierarchy[i]
        let level2 = expectedHierarchy[j]

        if level1 < level2 {
          #expect(p1 < p2)
          #expect(p1 != p2)
        } else if level1 > level2 {
          #expect(p1 > p2)
          #expect(p1 != p2)
        } else {
          #expect(p1 == p2)
          #expect(!(p1 < p2))
          #expect(!(p1 > p2))
        }
      }
    }
  }

  // MARK: - Behavior Property Access

  @Test("Behavior property access")
  func testBehaviorPropertyAccess() {
    let testCases: [(priority: LockmanPriorityBasedInfo.Priority, expectedBehavior: LockmanPriorityBasedInfo.ConcurrencyBehavior?)] = [
      (.none, nil),
      (.low(.exclusive), .exclusive),
      (.low(.replaceable), .replaceable),
      (.high(.exclusive), .exclusive),
      (.high(.replaceable), .replaceable),
    ]

    for (priority, expectedBehavior) in testCases {
      #expect(priority.behavior == expectedBehavior)
    }
  }

  // MARK: - String Representations (Removed since description functionality was removed)

  // MARK: - Concurrency and Sendable

  @Test("Concurrent access maintains data integrity")
  func testConcurrentAccessMaintainsDataIntegrity() async {
    let info = TestInfoFactory.highExclusive("concurrentAction")

    let results = await withTaskGroup(of: LockmanPriorityBasedInfo.self, returning: [LockmanPriorityBasedInfo].self) { group in
      for _ in 0 ..< 5 {
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
      #expect(result == info)
      #expect(result.actionId == "concurrentAction")
      #expect(result.priority == .high(.exclusive))
    }
  }

  // MARK: - Edge Cases and Robustness

//  @Test("Special character action IDs")
//  func testSpecialCharacterActionIds() {
//    let specialActionIds = [
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
//      #expect(info.actionId == actionId)
//      #expect(info.priority == .high(.exclusive))
//      // #expect(info.description.contains(actionId)) // Removed - description functionality removed
//    }
//  }

  @Test("Unicode action ID support")
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

      #expect(info.actionId == actionId)
      #expect(info.priority == .low(.replaceable))
      // #expect(info.description.contains(actionId)) // Removed - description functionality removed
    }
  }

  @Test("Value type semantics preservation")
  func testValueTypeSemanticsPreservation() {
    let original = TestInfoFactory.lowExclusive("original")
    let copy = original

    // Copy should be equal to original (same instance)
    #expect(copy == original)
    #expect(copy.actionId == original.actionId)
    #expect(copy.priority == original.priority)
    #expect(copy.uniqueId == original.uniqueId)

    // New instance with same parameters should not be equal
    let different = TestInfoFactory.lowExclusive("original")
    #expect(different != original) // Different uniqueId
    #expect(different.actionId == original.actionId) // Same actionId
  }

  // MARK: - Performance

  @Test("Priority comparison performance")
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
    for _ in 0 ..< 100 {
      for i in 0 ..< priorities.count {
        for j in 0 ..< priorities.count {
          _ = priorities[i] < priorities[j]
          _ = priorities[i] == priorities[j]
          _ = priorities[i] > priorities[j]
        }
      }
    }

    let duration = Date().timeIntervalSince(startTime)
    #expect(duration < 0.1) // Should complete quickly
  }

  // MARK: - Protocol Conformance

  @Test("LockmanInfo protocol conformance")
  func testLockmanInfoProtocolConformance() {
    let info = TestInfoFactory.highExclusive("testProtocol")

    // Should work as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    #expect(lockmanInfo.actionId == "testProtocol")
    // #expect(lockmanInfo.description.contains("testProtocol")) // Removed - description functionality removed
    #expect(lockmanInfo.uniqueId == info.uniqueId)
  }
}

// MARK: - Integration Tests

@Suite("LockmanPriorityBasedInfo Integration Tests")
struct LockmanPriorityBasedInfoIntegrationTests {
//  @Test("Integration with LockmanState")
//  func testIntegrationWithLockmanState() {
//    let state = LockmanState<LockmanPriorityBasedInfo>()
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
//    #expect(currents.count == 3)
//    #expect(currents[0] == info1)
//    #expect(currents[1] == info2)
//    #expect(currents[2] == info3)
//
//    // Remove by instance
//    state.remove(id: boundaryId, info: info2)
//    let afterRemove = state.currents(id: boundaryId)
//    #expect(afterRemove.count == 2)
//    #expect(afterRemove[0] == info1)
//    #expect(afterRemove[1] == info3)
//
//    // Remove by action ID
//    state.remove(id: boundaryId, actionId: info1.actionId)
//    let afterActionIdRemove = state.currents(id: boundaryId)
//    #expect(afterActionIdRemove.count == 1)
//    #expect(afterActionIdRemove[0] == info3)
//
//    // Clean up
//    state.removeAll()
//    #expect(state.currents(id: boundaryId).isEmpty)
//  }

  @Test("Priority-based sorting behavior")
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
    #expect(infos[0].priority == .none)

    // Verify low priorities are in positions 1-2 (any order within same level)
    for index in 1 ... 2 {
      switch infos[index].priority {
      case .low:
        break // Correct
      default:
        #expect(Bool(false), "Expected low priority at index \(index)")
      }
    }

    // Verify high priorities are in positions 3-4 (any order within same level)
    for index in 3 ... 4 {
      switch infos[index].priority {
      case .high:
        break // Correct
      default:
        #expect(Bool(false), "Expected high priority at index \(index)")
      }
    }
  }

  @Test("Integration with priority strategy")
  func testIntegrationWithPriorityStrategy() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()
    do {
      try container.register(strategy)
    } catch {
      #expect(Bool(false), "Unexpected error: \(error)")
    }

    await Lockman.withTestContainer(container) {
      let boundaryId = TestBoundaryId.default
      let info1 = TestInfoFactory.lowExclusive("action1")
      let info2 = TestInfoFactory.highReplaceable("action2")
      let info3 = TestInfoFactory.none("action3")

      let resolvedStrategy: AnyLockmanStrategy<LockmanPriorityBasedInfo>
      do {
        resolvedStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)
      } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
        return
      }

      // Test basic locking behavior
      #expect(resolvedStrategy.canLock(id: boundaryId, info: info1) == .success)
      resolvedStrategy.lock(id: boundaryId, info: info1)

      // None priority always succeeds
      #expect(resolvedStrategy.canLock(id: boundaryId, info: info3) == .success)

      // Higher priority preempts lower priority
      #expect(resolvedStrategy.canLock(id: boundaryId, info: info2) == .successWithPrecedingCancellation)

      resolvedStrategy.cleanUp()
    }
  }

  @Test("Complex priority interaction scenario")
  func testComplexPriorityInteractionScenario() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = TestBoundaryId.default

    let noneInfo = TestInfoFactory.none("none")
    let lowExclusiveInfo = TestInfoFactory.lowExclusive("lowExc")
    let highReplaceableInfo = TestInfoFactory.highReplaceable("highRepl")
    let anotherLowInfo = TestInfoFactory.lowExclusive("lowExc2")

    // None priority always succeeds
    #expect(strategy.canLock(id: boundaryId, info: noneInfo) == .success)

    // First low priority succeeds
    #expect(strategy.canLock(id: boundaryId, info: lowExclusiveInfo) == .success)
    strategy.lock(id: boundaryId, info: lowExclusiveInfo)

    // High priority preempts low priority
    #expect(strategy.canLock(id: boundaryId, info: highReplaceableInfo) == .successWithPrecedingCancellation)
    strategy.lock(id: boundaryId, info: highReplaceableInfo)

    // Another low priority fails against high priority
    #expect(strategy.canLock(id: boundaryId, info: anotherLowInfo) == .failure)

    // None priority still succeeds
    #expect(strategy.canLock(id: boundaryId, info: noneInfo) == .success)

    strategy.cleanUp()
  }

  @Test("Boundary isolation maintains separation")
  func testBoundaryIsolationMaintainsSeparation() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundary1 = TestBoundaryId.boundary1
    let boundary2 = TestBoundaryId.boundary2

    let info = TestInfoFactory.highExclusive("shared")

    // Same info can be locked on different boundaries
    #expect(strategy.canLock(id: boundary1, info: info) == .success)
    strategy.lock(id: boundary1, info: info)

    #expect(strategy.canLock(id: boundary2, info: info) == .success)
    strategy.lock(id: boundary2, info: info)

    // But duplicate on same boundary fails
    #expect(strategy.canLock(id: boundary1, info: info) == .failure)
    #expect(strategy.canLock(id: boundary2, info: info) == .failure)

    // Cleanup only affects specific boundary
    strategy.cleanUp(id: boundary1)
    #expect(strategy.canLock(id: boundary1, info: info) == .success)
    #expect(strategy.canLock(id: boundary2, info: info) == .failure) // Still locked

    strategy.cleanUp()
  }
}
