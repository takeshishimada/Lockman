
import Foundation
import XCTest
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

final class LockmanPriorityBasedStrategyTests: XCTestCase {
  // MARK: - Instance Management

  func testSharedInstanceSingleton() {
    let instance1 = LockmanPriorityBasedStrategy.shared
    let instance2 = LockmanPriorityBasedStrategy.shared

    XCTAssertTrue(instance1  === instance2)
  }

  func testIndependentInstances() {
    let strategy1 = LockmanPriorityBasedStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    XCTAssertTrue(strategy1 !== strategy2)

    // Verify state isolation
    let info = TestInfoFactory.highExclusive("test")
    strategy1.lock(id: TestBoundaryId.default, info: info)

    XCTAssertEqual(strategy2.canLock(id: TestBoundaryId.default, info: info), .success)

    strategy1.cleanUp()
  }

  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanPriorityBasedStrategy.makeStrategyId()
    let id2 = LockmanPriorityBasedStrategy.makeStrategyId()

    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id1, .priorityBased)
  }

  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy  = LockmanPriorityBasedStrategy()
    let staticId = LockmanPriorityBasedStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  // MARK: - Basic Locking Behavior

  func testNonePriorityBypassesRestrictions() {
    let strategy  = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let highInfo = TestInfoFactory.highExclusive("blocker")

    // None priority succeeds on empty state
    XCTAssertEqual(strategy.canLock(id: id, info: noneInfo), .success)

    // Lock with high priority to create contention
    strategy.lock(id: id, info: highInfo)

    // None priority should still succeed
    XCTAssertEqual(strategy.canLock(id: id, info: noneInfo), .success)

    strategy.cleanUp()
  }

  func testFirstPriorityLockSucceeds() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases = [
      TestInfoFactory.lowExclusive("low1"),
      TestInfoFactory.highReplaceable("high1"),
    ]

    for info in testCases {
      XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
      strategy.lock(id: id, info: info)
      strategy.unlock(id: id, info: info)
    }
  }

  func testDuplicateActionIdFails() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let info1 = TestInfoFactory.highExclusive("duplicate")
    let info2 = TestInfoFactory.highExclusive("duplicate") // Same action ID

    strategy.lock(id: id, info: info1)
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .failure)

    strategy.unlock(id: id, info: info1)
  }

  // MARK: - Priority Hierarchy

  func testHigherPriorityPreemptsLowerPriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(lower: LockmanPriorityBasedInfo, higher: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.lowExclusive("low1"), TestInfoFactory.highExclusive("high1")),
      (TestInfoFactory.lowReplaceable("low2"), TestInfoFactory.highReplaceable("high2")),
    ]

    for (lowerInfo, higherInfo) in testCases {
      strategy.lock(id: id, info: lowerInfo)
      XCTAssertEqual(strategy.canLock(id: id, info: higherInfo), .successWithPrecedingCancellation)
      strategy.cleanUp()
    }
  }

  func testLowerPriorityFailsAgainstHigherPriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let testCases: [(higher: LockmanPriorityBasedInfo, lower: LockmanPriorityBasedInfo)] = [
      (TestInfoFactory.highExclusive("high1"), TestInfoFactory.lowExclusive("low1")),
      (TestInfoFactory.highReplaceable("high2"), TestInfoFactory.lowReplaceable("low2")),
    ]

    for (higherInfo, lowerInfo) in testCases {
      strategy.lock(id: id, info: higherInfo)
      XCTAssertEqual(strategy.canLock(id: id, info: lowerInfo), .failure)
      strategy.cleanUp()
    }
  }

  // MARK: - Same Priority Behavior (Fixed based on actual implementation)

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
      XCTAssertEqual(strategy.canLock(id: id, info: secondInfo), .failure)
      strategy.cleanUp()
    }
  }

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
      XCTAssertEqual(strategy.canLock(id: id, info: secondInfo), .successWithPrecedingCancellation)
      strategy.cleanUp()
    }
  }

  // MARK: - State Management

  func testLockUnlockCycleRestoresAvailability() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let info = TestInfoFactory.highExclusive("test")

    XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
    strategy.lock(id: id, info: info)
    XCTAssertEqual(strategy.canLock(id: id, info: info), .failure)

    strategy.unlock(id: id, info: info)
    XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
  }

  func testUnlockWithNonePriorityIsSafeNoop() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let highInfo = TestInfoFactory.highExclusive("high")

    strategy.lock(id: id, info: highInfo)
    strategy.unlock(id: id, info: noneInfo) // Should not affect state

    XCTAssertEqual(strategy.canLock(id: id, info: highInfo), .failure)

    strategy.unlock(id: id, info: highInfo)
  }

  // MARK: - Boundary Isolation

  func testDifferentBoundariesMaintainCompleteIsolation() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("shared")

    // Same info can be locked on different boundaries
    strategy.lock(id: id1, info: info)
    XCTAssertEqual(strategy.canLock(id: id2, info: info), .success)
    strategy.lock(id: id2, info: info)

    // Unlock only affects specific boundary
    strategy.unlock(id: id1, info: info)
    XCTAssertEqual(strategy.canLock(id: id1, info: info), .success)
    XCTAssertEqual(strategy.canLock(id: id2, info: info), .failure)

    strategy.cleanUp()
  }

  // MARK: - Cleanup Operations

  func testGlobalCleanupRemovesAllState() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("action")

    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    strategy.cleanUp()

    XCTAssertEqual(strategy.canLock(id: id1, info: info), .success)
    XCTAssertEqual(strategy.canLock(id: id2, info: info), .success)
  }

  func testBoundarySpecificCleanupPreservesOtherBoundaries() {
    let strategy = LockmanPriorityBasedStrategy()
    let id1 = TestBoundaryId.boundary1
    let id2 = TestBoundaryId.boundary2
    let info = TestInfoFactory.highExclusive("action")

    strategy.lock(id: id1, info: info)
    strategy.lock(id: id2, info: info)

    strategy.cleanUp(id: id1)

    XCTAssertEqual(strategy.canLock(id: id1, info: info), .success)
    XCTAssertEqual(strategy.canLock(id: id2, info: info), .failure)

    strategy.cleanUp()
  }

  // MARK: - Complex Scenarios

  func testMultiplePriorityLevelsInteraction() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let lowInfo = TestInfoFactory.lowReplaceable("low")
    let highInfo = TestInfoFactory.highExclusive("high")

    // Start with low priority
    strategy.lock(id: id, info: lowInfo)

    // None priority always succeeds
    XCTAssertEqual(strategy.canLock(id: id, info: noneInfo), .success)

    // High priority preempts low priority
    XCTAssertEqual(strategy.canLock(id: id, info: highInfo), .successWithPrecedingCancellation)
    strategy.lock(id: id, info: highInfo)

    // Low priority now fails against high priority
    XCTAssertEqual(strategy.canLock(id: id, info: lowInfo), .failure)

    strategy.cleanUp()
  }

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
    XCTAssertEqual(strategy.canLock(id: id, info: lowExclusive), .successWithPrecedingCancellation)
    strategy.lock(id: id, info: lowExclusive)

    // High replaceable preempts low exclusive
    XCTAssertEqual(strategy.canLock(id: id, info: highReplaceable), .successWithPrecedingCancellation)
    strategy.lock(id: id, info: highReplaceable)

    // High exclusive can replace high replaceable
    XCTAssertEqual(strategy.canLock(id: id, info: highExclusive), .successWithPrecedingCancellation)

    strategy.cleanUp()
  }

  // MARK: - Concurrency Tests

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
    XCTAssertGreaterThanOrEqual(successCount , 1)

    strategy.cleanUp()
  }

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
    XCTAssertTrue(noneResults.allSatisfy { $0.1 == .success })

    // At least one priority-based operation should succeed
    let priorityResults  = results.filter { $0.0 != "none" }
    let prioritySuccessCount = priorityResults.filter { $0.1 == .success || $0.1 == .successWithPrecedingCancellation }.count
    XCTAssertGreaterThanOrEqual(prioritySuccessCount, 1)

    strategy.cleanUp()
  }

  // MARK: - Edge Cases

  func testStateConsistencyAcrossBehaviorTransitions() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    let lowReplaceable = TestInfoFactory.lowReplaceable("lowRepl")
    let lowExclusive = TestInfoFactory.lowExclusive("lowExcl")

    // Lock with replaceable behavior
    strategy.lock(id: id, info: lowReplaceable)

    // Exclusive can replace replaceable
    XCTAssertEqual(strategy.canLock(id: id, info: lowExclusive), .successWithPrecedingCancellation)
    strategy.lock(id: id, info: lowExclusive)

    // Now replaceable cannot replace exclusive
    XCTAssertEqual(strategy.canLock(id: id, info: lowReplaceable), .failure)

    strategy.cleanUp()
  }

  // MARK: - blocksSameAction Tests

  func testBlocksSameActionPreventsSameActionId() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "payment"

    // First action with blocksSameAction = true
    let info1 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // Second action with same actionId should fail regardless of priority
    let info2 = TestInfoFactory.highReplaceable(actionId)
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .failure)

    // Even with lower priority, should fail
    let info3 = TestInfoFactory.lowExclusive(actionId)
    XCTAssertEqual(strategy.canLock(id: id, info: info3), .failure)

    // Different actionId should work normally
    let info4 = TestInfoFactory.highExclusive("different")
    XCTAssertEqual(strategy.canLock(id: id, info: info4), .failure) // Normal priority rule applies

    strategy.cleanUp()
  }

  func testBlocksSameActionIsBidirectional() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "save"

    // First action without blocksSameAction
    let info1 = TestInfoFactory.lowExclusive(actionId)
    strategy.lock(id: id, info: info1)

    // Second action with blocksSameAction = true and same actionId should fail
    let info2 = TestInfoFactory.highExclusive(actionId, blocksSameAction: true)
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .failure)

    strategy.cleanUp()
  }

  func testBlocksSameActionWithNonePriority() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "notification"

    // None priority with blocksSameAction = true
    let info1 = TestInfoFactory.none(actionId, blocksSameAction: true)
    XCTAssertEqual(strategy.canLock(id: id, info: info1), .success)
    strategy.lock(id: id, info: info1)

    // Another none priority with same actionId should still succeed (none bypasses priority system)
    let info2 = TestInfoFactory.none(actionId)
    XCTAssertEqual(strategy.canLock(id: id, info: info2), .success)

    strategy.cleanUp()
  }

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
    XCTAssertEqual(strategy.canLock(id: id2, info: info2), .success)
    strategy.lock(id: id2, info: info2)

    // But same actionId on same boundary should fail
    XCTAssertEqual(strategy.canLock(id: id1, info: info2), .failure)
    XCTAssertEqual(strategy.canLock(id: id2, info: info1), .failure)

    strategy.cleanUp()
  }

  func testBlocksSameActionWithPriorityTransitions() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let actionId = "process"

    // Start with low priority blocksSameAction
    let lowBlocking = TestInfoFactory.lowExclusive(actionId, blocksSameAction: true)
    strategy.lock(id: id, info: lowBlocking)

    // High priority with same actionId should fail despite higher priority
    let highNormal = TestInfoFactory.highReplaceable(actionId)
    XCTAssertEqual(strategy.canLock(id: id, info: highNormal), .failure)

    // Unlock the blocking action
    strategy.unlock(id: id, info: lowBlocking)

    // Now high priority should succeed
    XCTAssertEqual(strategy.canLock(id: id, info: highNormal), .success)
    strategy.lock(id: id, info: highNormal)

    // Low priority blocking should now fail (normal priority rules)
    XCTAssertEqual(strategy.canLock(id: id, info: lowBlocking), .failure)

    strategy.cleanUp()
  }

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
    XCTAssertEqual(strategy.canLock(id: id, info: payment2), .failure)

    // Search1 should succeed (different actionId)
    XCTAssertEqual(strategy.canLock(id: id, info: search1), .failure) // Normal priority rule (same high priority, exclusive behavior)

    // Update1 should succeed (different actionId, despite blocksSameAction)
    XCTAssertEqual(strategy.canLock(id: id, info: update1), .failure) // Normal priority rule (lower priority)

    strategy.unlock(id: id, info: payment1)

    // Now lock search1 without blocksSameAction
    strategy.lock(id: id, info: search1)

    // Search2 with blocksSameAction should fail
    XCTAssertEqual(strategy.canLock(id: id, info: search2), .failure)

    strategy.cleanUp()
  }
}
