
import Foundation
import Testing
@testable import LockmanCore

// MARK: - Test Helpers

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: TestBoundaryId, rhs: TestBoundaryId) -> Bool {
    lhs.value == rhs.value
  }
}

// Convenient constants
private extension TestBoundaryId {
  static let `default` = TestBoundaryId("default")
  static let boundary1 = TestBoundaryId("boundary1")
  static let boundary2 = TestBoundaryId("boundary2")
  static let concurrent = TestBoundaryId("concurrent")
}

/// Factory for creating priority-based test info
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

// MARK: - LockmanPriorityBasedStrategy Tests

@Suite("LockmanPriorityBasedStrategy Tests", .serialized)
struct LockmanPriorityBasedStrategyTests {
  // MARK: - Instance Management

  @Test("Shared instance maintains singleton pattern")
  func testSharedInstanceSingleton() {
    let instance1 = LockmanPriorityBasedStrategy.shared
    let instance2 = LockmanPriorityBasedStrategy.shared

    #expect(instance1 === instance2)
  }

  @Test("Independent instances maintain separate state")
  func testIndependentInstances() {
    let strategy1 = LockmanPriorityBasedStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    #expect(strategy1 !== strategy2)

    // Verify state isolation
    let info = TestInfoFactory.highExclusive("test")
    strategy1.lock(id: TestBoundaryId.default, info: info)

    #expect(strategy2.canLock(id: TestBoundaryId.default, info: info) == .success)

    strategy1.cleanUp()
  }

  @Test("makeStrategyId returns consistent identifier")
  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanPriorityBasedStrategy.makeStrategyId()
    let id2 = LockmanPriorityBasedStrategy.makeStrategyId()

    #expect(id1 == id2)
    #expect(id1 == .priorityBased)
  }

  @Test("Instance strategyId matches makeStrategyId")
  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy = LockmanPriorityBasedStrategy()
    let staticId = LockmanPriorityBasedStrategy.makeStrategyId()

    #expect(strategy.strategyId == staticId)
  }

  // MARK: - Basic Locking Behavior

  @Test("None priority bypasses all restrictions")
  func testNonePriorityBypassesRestrictions() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let highInfo = TestInfoFactory.highExclusive("blocker")

    // None priority succeeds on empty state
    #expect(strategy.canLock(id: id, info: noneInfo) == .success)

    // Lock with high priority to create contention
    strategy.lock(id: id, info: highInfo)

    // None priority should still succeed
    #expect(strategy.canLock(id: id, info: noneInfo) == .success)

    strategy.cleanUp()
  }

  @Test("First priority lock always succeeds")
  func testFirstPriorityLockSucceeds() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases = [
      TestInfoFactory.lowExclusive("low1"),
      TestInfoFactory.highReplaceable("high1"),
    ]

    for info in testCases {
      #expect(strategy.canLock(id: id, info: info) == .success)
      strategy.lock(id: id, info: info)
      strategy.unlock(id: id, info: info)
    }
  }

  @Test("Duplicate action ID always fails")
  func testDuplicateActionIdFails() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let info1 = TestInfoFactory.highExclusive("duplicate")
    let info2 = TestInfoFactory.highExclusive("duplicate") // Same action ID

    strategy.lock(id: id, info: info1)
    #expect(strategy.canLock(id: id, info: info2) == .failure)

    strategy.unlock(id: id, info: info1)
  }

  // MARK: - Priority Hierarchy

  @Test("Higher priority preempts lower priority")
  func testHigherPriorityPreemptsLowerPriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(lower: LockmanPriorityBasedInfo, higher: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.lowExclusive("low1"), TestInfoFactory.highExclusive("high1")),
      (TestInfoFactory.lowReplaceable("low2"), TestInfoFactory.highReplaceable("high2")),
    ]

    for (lowerInfo, higherInfo) in testCases {
      strategy.lock(id: id, info: lowerInfo)
      #expect(strategy.canLock(id: id, info: higherInfo) == .successWithPrecedingCancellation)
      strategy.cleanUp()
    }
  }

  @Test("Lower priority fails against higher priority")
  func testLowerPriorityFailsAgainstHigherPriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(higher: LockmanPriorityBasedInfo, lower: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.highExclusive("high1"), TestInfoFactory.lowExclusive("low1")),
      (TestInfoFactory.highReplaceable("high2"), TestInfoFactory.lowReplaceable("low2")),
    ]

    for (higherInfo, lowerInfo) in testCases {
      strategy.lock(id: id, info: higherInfo)
      #expect(strategy.canLock(id: id, info: lowerInfo) == .failure)
      strategy.cleanUp()
    }
  }

  // MARK: - Same Priority Behavior (Fixed based on actual implementation)

  @Test("Same priority exclusive behavior blocks new actions")
  func testSamePriorityExclusiveBehaviorBlocks() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(first: LockmanPriorityBasedInfo, second: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.lowExclusive("low1"), TestInfoFactory.lowExclusive("low2")),
      (TestInfoFactory.highExclusive("high1"), TestInfoFactory.highReplaceable("high2")),
    ]

    for (firstInfo, secondInfo) in testCases {
      strategy.lock(id: id, info: firstInfo)
      // Second action follows first action's exclusive behavior
      #expect(strategy.canLock(id: id, info: secondInfo) == .failure)
      strategy.cleanUp()
    }
  }

  @Test("Same priority replaceable behavior allows replacement")
  func testSamePriorityReplaceableBehaviorAllowsReplacement() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(first: LockmanPriorityBasedInfo, second: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.lowReplaceable("low1"), TestInfoFactory.lowReplaceable("low2")),
      (TestInfoFactory.highReplaceable("high1"), TestInfoFactory.highExclusive("high2")),
    ]

    for (firstInfo, secondInfo) in testCases {
      strategy.lock(id: id, info: firstInfo)
      // Second action follows first action's replaceable behavior
      #expect(strategy.canLock(id: id, info: secondInfo) == .successWithPrecedingCancellation)
      strategy.cleanUp()
    }
  }

  // MARK: - State Management

  @Test("Lock unlock cycle restores availability")
  func testLockUnlockCycleRestoresAvailability() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let info = TestInfoFactory.highExclusive("test")

    #expect(strategy.canLock(id: id, info: info) == .success)
    strategy.lock(id: id, info: info)
    #expect(strategy.canLock(id: id, info: info) == .failure)

    strategy.unlock(id: id, info: info)
    #expect(strategy.canLock(id: id, info: info) == .success)
  }

  @Test("Unlock with none priority is safe noop")
  func testUnlockWithNonePriorityIsSafeNoop() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let highInfo = TestInfoFactory.highExclusive("high")

    strategy.lock(id: id, info: highInfo)
    strategy.unlock(id: id, info: noneInfo) // Should not affect state

    #expect(strategy.canLock(id: id, info: highInfo) == .failure)

    strategy.unlock(id: id, info: highInfo)
  }

  // MARK: - Boundary Isolation

  @Test("Different boundaries maintain complete isolation")
  func testDifferentBoundariesMaintainCompleteIsolation() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("shared")

    // Same info can be locked on different boundaries
    strategy.lock(id: id1, info: info)
    #expect(strategy.canLock(id: id2, info: info) == .success)
    strategy.lock(id: id2, info: info)

    // Unlock only affects specific boundary
    strategy.unlock(id: id1, info: info)
    #expect(strategy.canLock(id: id1, info: info) == .success)
    #expect(strategy.canLock(id: id2, info: info) == .failure)

    strategy.cleanUp()
  }

  // MARK: - Cleanup Operations

  @Test("Global cleanup removes all state")
  func testGlobalCleanupRemovesAllState() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("action")

    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    strategy.cleanUp()

    #expect(strategy.canLock(id: id1, info: info) == .success)
    #expect(strategy.canLock(id: id2, info: info) == .success)
  }

  @Test("Boundary specific cleanup preserves other boundaries")
  func testBoundarySpecificCleanupPreservesOtherBoundaries() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("action")

    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    strategy.cleanUp(id: id1)

    #expect(strategy.canLock(id: id1, info: info) == .success)
    #expect(strategy.canLock(id: id2, info: info) == .failure)

    strategy.cleanUp()
  }

  // MARK: - Complex Scenarios

  @Test("Multiple priority levels interaction")
  func testMultiplePriorityLevelsInteraction() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let lowInfo = TestInfoFactory.lowReplaceable("low")
    let highInfo = TestInfoFactory.highExclusive("high")

    // Start with low priority
    strategy.lock(id: id, info: lowInfo)

    // None priority always succeeds
    #expect(strategy.canLock(id: id, info: noneInfo) == .success)

    // High priority preempts low priority
    #expect(strategy.canLock(id: id, info: highInfo) == .successWithPrecedingCancellation)
    strategy.lock(id: id, info: highInfo)

    // Low priority now fails against high priority
    #expect(strategy.canLock(id: id, info: lowInfo) == .failure)

    strategy.cleanUp()
  }

  @Test("Complex priority behavior sequence")
  func testComplexPriorityBehaviorSequence() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let lowReplaceable = TestInfoFactory.lowReplaceable("low1")
    let lowExclusive = TestInfoFactory.lowExclusive("low2")
    let highReplaceable = TestInfoFactory.highReplaceable("high1")
    let highExclusive = TestInfoFactory.highExclusive("high2")

    // Start with low replaceable
    strategy.lock(id: id, info: lowReplaceable)

    // Low exclusive can replace low replaceable
    #expect(strategy.canLock(id: id, info: lowExclusive) == .successWithPrecedingCancellation)
    strategy.lock(id: id, info: lowExclusive)

    // High replaceable preempts low exclusive
    #expect(strategy.canLock(id: id, info: highReplaceable) == .successWithPrecedingCancellation)
    strategy.lock(id: id, info: highReplaceable)

    // High exclusive can replace high replaceable
    #expect(strategy.canLock(id: id, info: highExclusive) == .successWithPrecedingCancellation)

    strategy.cleanUp()
  }

  // MARK: - Concurrency Tests

  @Test("Concurrent lock operations maintain consistency")
  func testConcurrentLockOperationsMaintainConsistency() async {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.concurrent

    let results = await withTaskGroup(of: LockResult.self, returning: [LockResult].self) { group in
      // Launch 10 concurrent lock attempts with different action IDs
      for i in 0 ..< 10 {
        group.addTask {
          let info = TestInfoFactory.highExclusive("action\(i)")
          return strategy.canLock(id: id, info: info)
        }
      }

      var results: [LockResult] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // At least one should succeed
    let successCount = results.filter { $0 == .success }.count
    #expect(successCount >= 1)

    strategy.cleanUp()
  }

  @Test("Concurrent operations with mixed priorities")
  func testConcurrentOperationsWithMixedPriorities() async {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.concurrent

    let results = await withTaskGroup(of: (String, LockResult).self, returning: [(String, LockResult)].self) { group in
      group.addTask {
        let info = TestInfoFactory.lowReplaceable("low")
        return ("low", strategy.canLock(id: id, info: info))
      }

      group.addTask {
        let info = TestInfoFactory.highExclusive("high")
        return ("high", strategy.canLock(id: id, info: info))
      }

      group.addTask {
        let info = TestInfoFactory.none("none")
        return ("none", strategy.canLock(id: id, info: info))
      }

      var results: [(String, LockResult)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // None priority should always succeed
    let noneResults = results.filter { $0.0 == "none" }
    #expect(noneResults.allSatisfy { $0.1 == .success })

    // At least one priority-based operation should succeed
    let priorityResults = results.filter { $0.0 != "none" }
    let prioritySuccessCount = priorityResults.filter { $0.1 == .success || $0.1 == .successWithPrecedingCancellation }.count
    #expect(prioritySuccessCount >= 1)

    strategy.cleanUp()
  }

  // MARK: - Edge Cases

  @Test("State consistency across complex behavior transitions")
  func testStateConsistencyAcrossBehaviorTransitions() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let lowReplaceable = TestInfoFactory.lowReplaceable("lowRepl")
    let lowExclusive = TestInfoFactory.lowExclusive("lowExcl")

    // Lock with replaceable behavior
    strategy.lock(id: id, info: lowReplaceable)

    // Exclusive can replace replaceable
    #expect(strategy.canLock(id: id, info: lowExclusive) == .successWithPrecedingCancellation)
    strategy.lock(id: id, info: lowExclusive)

    // Now replaceable cannot replace exclusive
    #expect(strategy.canLock(id: id, info: lowReplaceable) == .failure)

    strategy.cleanUp()
  }

  // MARK: - blocksSameAction Tests

  @Test("blocksSameAction prevents same actionId")
  func testBlocksSameActionPreventsSameActionId() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "payment"

    // First action with blocksSameAction = true
    let info1 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    #expect(strategy.canLock(id: id, info: info1) == .success)
    strategy.lock(id: id, info: info1)

    // Second action with same actionId should fail regardless of priority
    let info2 = TestInfoFactory.highReplaceable(actionId)
    #expect(strategy.canLock(id: id, info: info2) == .failure)

    // Even with lower priority, should fail
    let info3 = TestInfoFactory.lowExclusive(actionId)
    #expect(strategy.canLock(id: id, info: info3) == .failure)

    // Different actionId should work normally
    let info4 = TestInfoFactory.highExclusive("different")
    #expect(strategy.canLock(id: id, info: info4) == .failure) // Normal priority rule applies

    strategy.cleanUp()
  }

  @Test("blocksSameAction is bidirectional")
  func testBlocksSameActionIsBidirectional() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "save"

    // First action without blocksSameAction
    let info1 = TestInfoFactory.lowExclusive(actionId)
    strategy.lock(id: id, info: info1)

    // Second action with blocksSameAction = true and same actionId should fail
    let info2 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    #expect(strategy.canLock(id: id, info: info2) == .failure)

    strategy.cleanUp()
  }

  @Test("blocksSameAction with none priority")
  func testBlocksSameActionWithNonePriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "notification"

    // None priority with blocksSameAction = true
    let info1 = TestInfoFactory.none(actionId, blocksSameAction: true)
    #expect(strategy.canLock(id: id, info: info1) == .success)
    strategy.lock(id: id, info: info1)

    // Another none priority with same actionId should still succeed (none bypasses priority system)
    let info2 = TestInfoFactory.none(actionId)
    #expect(strategy.canLock(id: id, info: info2) == .success)

    strategy.cleanUp()
  }

  @Test("blocksSameAction across boundaries")
  func testBlocksSameActionAcrossBoundaries() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let actionId = "update"

    // Lock on boundary1 with blocksSameAction
    let info1 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    strategy.lock(id: id1, info: info1)

    // Same actionId on boundary2 should succeed (boundaries are isolated)
    let info2 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    #expect(strategy.canLock(id: id2, info: info2) == .success)
    strategy.lock(id: id2, info: info2)

    // But same actionId on same boundary should fail
    #expect(strategy.canLock(id: id1, info: info2) == .failure)
    #expect(strategy.canLock(id: id2, info: info1) == .failure)

    strategy.cleanUp()
  }

  @Test("blocksSameAction with priority transitions")
  func testBlocksSameActionWithPriorityTransitions() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "process"

    // Start with low priority blocksSameAction
    let lowBlocking = TestInfoFactory.lowExclusive(actionId, blocksSameAction: true)
    strategy.lock(id: id, info: lowBlocking)

    // High priority with same actionId should fail despite higher priority
    let highNormal = TestInfoFactory.highReplaceable(actionId)
    #expect(strategy.canLock(id: id, info: highNormal) == .failure)

    // Unlock the blocking action
    strategy.unlock(id: id, info: lowBlocking)

    // Now high priority should succeed
    #expect(strategy.canLock(id: id, info: highNormal) == .success)
    strategy.lock(id: id, info: highNormal)

    // Low priority blocking should now fail (normal priority rules)
    #expect(strategy.canLock(id: id, info: lowBlocking) == .failure)

    strategy.cleanUp()
  }

  @Test("blocksSameAction complex scenario")
  func testBlocksSameActionComplexScenario() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    // Multiple actions with different actionIds and blocksSameAction settings
    let payment1 = TestInfoFactory.highExclusive("payment", blocksSameAction: true)
    let payment2 = TestInfoFactory.highReplaceable("payment")
    let search1 = TestInfoFactory.highReplaceable("search")
    let search2 = TestInfoFactory.highReplaceable("search", blocksSameAction: true)
    let update1 = TestInfoFactory.lowExclusive("update", blocksSameAction: true)

    // Lock payment with blocksSameAction
    strategy.lock(id: id, info: payment1)

    // Payment2 should fail
    #expect(strategy.canLock(id: id, info: payment2) == .failure)

    // Search1 should succeed (different actionId)
    #expect(strategy.canLock(id: id, info: search1) == .failure) // Normal priority rule (same high priority, exclusive behavior)

    // Update1 should succeed (different actionId, despite blocksSameAction)
    #expect(strategy.canLock(id: id, info: update1) == .failure) // Normal priority rule (lower priority)

    strategy.unlock(id: id, info: payment1)

    // Now lock search1 without blocksSameAction
    strategy.lock(id: id, info: search1)

    // Search2 with blocksSameAction should fail
    #expect(strategy.canLock(id: id, info: search2) == .failure)

    strategy.cleanUp()
  }
}
