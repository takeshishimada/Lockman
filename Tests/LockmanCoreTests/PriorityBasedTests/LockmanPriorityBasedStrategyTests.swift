import Foundation
import XCTest

@testable import Lockman

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
extension TestBoundaryId {
  fileprivate static let `default` = TestBoundaryId("default")
  fileprivate static let boundary1 = TestBoundaryId("boundary1")
  fileprivate static let boundary2 = TestBoundaryId("boundary2")
  fileprivate static let concurrent = TestBoundaryId("concurrent")
}

/// Factory for creating priority-based test info
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

// MARK: - LockmanPriorityBasedStrategy Tests

final class LockmanPriorityBasedStrategyTests: XCTestCase {
  // MARK: - Instance Management

  func testSharedInstanceSingleton() {
    let instance1 = LockmanPriorityBasedStrategy.shared
    let instance2 = LockmanPriorityBasedStrategy.shared

    XCTAssertTrue(instance1 === instance2)
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
    let strategy = LockmanPriorityBasedStrategy()
    let staticId = LockmanPriorityBasedStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  // MARK: - Basic Locking Behavior

  func testNonePriorityBypassesRestrictions() {
    let strategy = LockmanPriorityBasedStrategy()
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
    let info2 = TestInfoFactory.highExclusive("duplicate")  // Same action ID

    strategy.lock(id: id, info: info1)
    XCTAssertLockFailure(strategy.canLock(id: id, info: info2))

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
      if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: higherInfo) {
        // Success - expected behavior
      } else {
        XCTFail("Expected successWithPrecedingCancellation")
      }
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
      XCTAssertLockFailure(strategy.canLock(id: id, info: lowerInfo))
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
      XCTAssertLockFailure(strategy.canLock(id: id, info: secondInfo))
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
      if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: secondInfo) {
        // Success - expected behavior
      } else {
        XCTFail("Expected successWithPrecedingCancellation")
      }
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
    XCTAssertLockFailure(strategy.canLock(id: id, info: info))

    strategy.unlock(id: id, info: info)
    XCTAssertEqual(strategy.canLock(id: id, info: info), .success)
  }

  func testUnlockWithNonePriorityIsSafeNoop() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default
    let noneInfo = TestInfoFactory.none()
    let highInfo = TestInfoFactory.highExclusive("high")

    strategy.lock(id: id, info: highInfo)
    strategy.unlock(id: id, info: noneInfo)  // Should not affect state

    XCTAssertLockFailure(strategy.canLock(id: id, info: highInfo))

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
    XCTAssertLockFailure(strategy.canLock(id: id2, info: info))

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
    XCTAssertLockFailure(strategy.canLock(id: id2, info: info))

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
    if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: highInfo) {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }
    strategy.lock(id: id, info: highInfo)

    // Low priority now fails against high priority
    XCTAssertLockFailure(strategy.canLock(id: id, info: lowInfo))

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
    if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: lowExclusive) {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }
    strategy.lock(id: id, info: lowExclusive)

    // High replaceable preempts low exclusive
    if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: highReplaceable) {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }
    strategy.lock(id: id, info: highReplaceable)

    // High exclusive can replace high replaceable
    if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: highExclusive) {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }

    strategy.cleanUp()
  }

  // MARK: - Concurrency Tests

  func testConcurrentLockOperationsMaintainConsistency() async {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.concurrent

    let results = await withTaskGroup(of: LockmanResult.self, returning: [LockmanResult].self) {
      group in
      // Launch 10 concurrent lock attempts with different action IDs
      for i in 0..<10 {
        group.addTask {
          let info = TestInfoFactory.highExclusive("action\(i)")
          return strategy.canLock(id: id, info: info)
        }
      }

      var results: [LockmanResult] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // At least one should succeed
    let successCount = results.filter { $0 == .success }.count
    XCTAssertGreaterThanOrEqual(successCount, 1)

    strategy.cleanUp()
  }

  func testConcurrentOperationsWithMixedPriorities() async {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.concurrent

    let results = await withTaskGroup(
      of: (String, LockmanResult).self, returning: [(String, LockmanResult)].self
    ) { group in
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

      var results: [(String, LockmanResult)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // None priority should always succeed
    let noneResults = results.filter { $0.0 == "none" }
    XCTAssertTrue(noneResults.allSatisfy { $0.1 == .success })

    // At least one priority-based operation should succeed
    let priorityResults = results.filter { $0.0 != "none" }
    let prioritySuccessCount = priorityResults.filter {
      switch $0.1 {
      case .success, .successWithPrecedingCancellation:
        return true
      case .failure:
        return false
      }
    }.count
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
    if case .successWithPrecedingCancellation = strategy.canLock(id: id, info: lowExclusive) {
      // Success - expected behavior
    } else {
      XCTFail("Expected successWithPrecedingCancellation")
    }
    strategy.lock(id: id, info: lowExclusive)

    // Now replaceable cannot replace exclusive
    XCTAssertLockFailure(strategy.canLock(id: id, info: lowReplaceable))

    strategy.cleanUp()
  }

  // MARK: - Preceding Action Cancellation Error Tests

  func testSuccessWithPrecedingCancellation_ReturnsCorrectError() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    // Lock a low priority action
    let lowAction = TestInfoFactory.lowExclusive("lowAction")
    strategy.lock(id: id, info: lowAction)

    // Try to lock a high priority action
    let highAction = TestInfoFactory.highExclusive("highAction")
    let result = strategy.canLock(id: id, info: highAction)

    // Should succeed with preceding cancellation
    switch result {
    case .successWithPrecedingCancellation(let error):
      // Verify the error is of the correct type
      guard let priorityError = error as? LockmanPriorityBasedError else {
        XCTFail("Expected LockmanPriorityBasedError but got \(type(of: error))")
        return
      }

      // Verify the error contains correct information
      if case .precedingActionCancelled(let cancelledInfo) = priorityError {
        XCTAssertEqual(
          cancelledInfo.actionId, "lowAction", "Error should contain the cancelled action ID")
      } else {
        XCTFail("Expected precedingActionCancelled error but got \(priorityError)")
      }
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }

    strategy.cleanUp()
  }

  func testReplaceableBehavior_ReturnsCorrectCancellationError() {
    let strategy = LockmanPriorityBasedStrategy()
    let id = TestBoundaryId.default

    // Lock a replaceable action
    let replaceableAction = TestInfoFactory.lowReplaceable("replaceableAction")
    strategy.lock(id: id, info: replaceableAction)

    // Try to lock another low priority action (should replace the existing one)
    let newAction = TestInfoFactory.lowExclusive("newAction")
    let result = strategy.canLock(id: id, info: newAction)

    // Should succeed with preceding cancellation
    switch result {
    case .successWithPrecedingCancellation(let error):
      // Verify the error contains the correct action ID
      guard let priorityError = error as? LockmanPriorityBasedError else {
        XCTFail("Expected LockmanPriorityBasedError but got \(type(of: error))")
        return
      }

      if case .precedingActionCancelled(let cancelledInfo) = priorityError {
        XCTAssertEqual(
          cancelledInfo.actionId, "replaceableAction",
          "Error should contain the cancelled action ID")
      } else {
        XCTFail("Expected precedingActionCancelled error but got \(priorityError)")
      }
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }

    strategy.cleanUp()
  }
}
