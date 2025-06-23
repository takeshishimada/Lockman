import Foundation
import XCTest

@testable import Lockman

/// Tests for edge cases, boundary values, and exceptional scenarios
final class LockmanEdgeCaseTests: XCTestCase {
  // MARK: - Boundary ID Edge Cases

  func testEmptyBoundaryIDHandling() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    let emptyBoundaryId = ""

    // Should handle empty boundary ID without crashing
    XCTAssertEqual(strategy.canLock(id: emptyBoundaryId, info: info), .success)
    strategy.lock(id: emptyBoundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(id: emptyBoundaryId, info: info))
    strategy.unlock(id: emptyBoundaryId, info: info)
    XCTAssertEqual(strategy.canLock(id: emptyBoundaryId, info: info), .success)

    // Cleanup should work
    strategy.cleanUp(id: emptyBoundaryId)
  }

  func testVeryLongBoundaryIDHandling() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let info = LockmanPriorityBasedInfo(actionId: "test-action", priority: .high(.exclusive))
    let longBoundaryId = String(repeating: "VeryLongBoundaryId", count: 100)  // 1800 characters

    XCTAssertEqual(strategy.canLock(id: longBoundaryId, info: info), .success)
    strategy.lock(id: longBoundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(id: longBoundaryId, info: info))
    strategy.unlock(id: longBoundaryId, info: info)

    strategy.cleanUp(id: longBoundaryId)
  }

  func testUnicodeBoundaryIDHandling() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    let unicodeBoundaryId = "🔒境界識別子📱测试🚀"

    XCTAssertEqual(strategy.canLock(id: unicodeBoundaryId, info: info), .success)
    strategy.lock(id: unicodeBoundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(id: unicodeBoundaryId, info: info))
    strategy.unlock(id: unicodeBoundaryId, info: info)

    strategy.cleanUp(id: unicodeBoundaryId)
  }

  func testSpecialCharacterBoundaryIDHandling() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .low(.replaceable))
    let specialBoundaryId = "boundary@#$%^&*()_+-=[]{}|;':\",./<>?"

    XCTAssertEqual(strategy.canLock(id: specialBoundaryId, info: info), .success)
    strategy.lock(id: specialBoundaryId, info: info)
    strategy.cleanUp(id: specialBoundaryId)
  }

  // MARK: - Action ID Edge Cases

  func testEmptyActionIDHandling() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let emptyActionInfo = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    let boundaryId = "test-boundary"

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: emptyActionInfo), .success)
    strategy.lock(id: boundaryId, info: emptyActionInfo)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: emptyActionInfo))

    // Different empty action should also conflict
    let anotherEmptyInfo = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: anotherEmptyInfo))

    strategy.unlock(id: boundaryId, info: emptyActionInfo)
    strategy.cleanUp()
  }

  func testVeryLongActionIDHandling() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let longActionId = String(repeating: "VeryLongActionIdentifier", count: 50)  // 1250 characters
    let info = LockmanPriorityBasedInfo(actionId: longActionId, priority: .high(.exclusive))
    let boundaryId = "test-boundary"

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
    strategy.lock(id: boundaryId, info: info)

    // Same long action ID with lower priority should fail
    let sameActionInfo = LockmanPriorityBasedInfo(
      actionId: longActionId, priority: .low(.exclusive))
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: sameActionInfo))

    strategy.cleanUp()
  }

  func testUnicodeActionIDHandling() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let unicodeActionId = "🚀アクション测试🔒動作識別子📱"
    let info = LockmanSingleExecutionInfo(actionId: unicodeActionId, mode: .boundary)
    let boundaryId = "test-boundary"

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
    strategy.lock(id: boundaryId, info: info)

    // Same unicode action ID should conflict
    let sameUnicodeInfo = LockmanSingleExecutionInfo(actionId: unicodeActionId, mode: .boundary)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: sameUnicodeInfo))

    strategy.unlock(id: boundaryId, info: info)
    strategy.cleanUp()
  }

  // MARK: - Priority Edge Cases

  func testNonePriorityBehaviorWithConflicts() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "priority-test"

    let noneInfo1 = LockmanPriorityBasedInfo(
      actionId: "none-action", priority: .none, blocksSameAction: false)
    let noneInfo2 = LockmanPriorityBasedInfo(
      actionId: "none-action", priority: .none, blocksSameAction: false)
    let highInfo = LockmanPriorityBasedInfo(
      actionId: "none-action", priority: .high(.exclusive), blocksSameAction: false)

    // First none priority should succeed
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: noneInfo1), .success)
    strategy.lock(id: boundaryId, info: noneInfo1)

    // Second none priority with same action ID should succeed (no conflicts for .none)
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: noneInfo2), .success)
    strategy.lock(id: boundaryId, info: noneInfo2)

    // High priority should succeed (may not cancel if none priority doesn't block)
    let result = strategy.canLock(id: boundaryId, info: highInfo)
    XCTAssertTrue(result == .success || result == .successWithPrecedingCancellation)

    strategy.cleanUp()
  }

  func testPriorityComparisonEdgeCases() async throws {
    let none = LockmanPriorityBasedInfo.Priority.none
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Test ordering
    XCTAssertLessThan(none, lowExclusive)
    XCTAssertLessThan(none, lowReplaceable)
    XCTAssertLessThan(lowExclusive, highExclusive)
    XCTAssertLessThan(lowReplaceable, highReplaceable)

    // Test equality (ignores behavior)
    XCTAssertEqual(lowExclusive, lowReplaceable)
    XCTAssertEqual(highExclusive, highReplaceable)
    XCTAssertNotEqual(none, lowExclusive)
    XCTAssertNotEqual(lowExclusive, highExclusive)
  }

  // MARK: - Memory and Performance Edge Cases

  func testHighFrequencyLockOperations() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "performance-test"
    let operationCount = 1000

    let startTime = CFAbsoluteTimeGetCurrent()

    for i in 0..<operationCount {
      let info = LockmanSingleExecutionInfo(actionId: "operation-\(i)", mode: .boundary)

      XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
      strategy.lock(id: boundaryId, info: info)
      strategy.unlock(id: boundaryId, info: info)
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete 1000 operations in reasonable time
    XCTAssertLessThan(executionTime, 1.0)  // Less than 1 second

    strategy.cleanUp()
  }

  func testManyConcurrentBoundaries() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryCount = 1000

    // Lock on many different boundaries
    for i in 0..<boundaryCount {
      let boundaryId = "boundary-\(i)"
      let info = LockmanPriorityBasedInfo(actionId: "action", priority: .low(.exclusive))

      XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
      strategy.lock(id: boundaryId, info: info)
    }

    // Verify all are locked independently
    for i in 0..<boundaryCount {
      let boundaryId = "boundary-\(i)"
      let newInfo = LockmanPriorityBasedInfo(actionId: "action", priority: .low(.exclusive))

      XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: newInfo))
    }

    strategy.cleanUp()
  }

  func testMemoryEfficiencyWithManyInfoInstances() async throws {
    var infos: [LockmanSingleExecutionInfo] = []
    let instanceCount = 10000

    // Create many info instances
    for i in 0..<instanceCount {
      let info = LockmanSingleExecutionInfo(actionId: "action-\(i)", mode: .boundary)
      infos.append(info)
    }

    // Verify they all have unique IDs
    let uniqueIds = Set(infos.map(\.uniqueId))
    XCTAssertEqual(uniqueIds.count, instanceCount)

    // Verify they can be used with strategies
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "memory-test"

    // Use a subset to avoid excessive test time
    for i in 0..<100 {
      let info = infos[i]
      XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
      strategy.lock(id: boundaryId, info: info)
      strategy.unlock(id: boundaryId, info: info)
    }

    strategy.cleanUp()
  }

  // MARK: - Container Edge Cases

  func testStrategyContainerWithManyStrategyTypes() async throws {
    // Create multiple unique strategy types for testing
    struct Strategy1: LockmanStrategy {
      typealias I = LockmanSingleExecutionInfo
      var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
      static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo)
        -> LockmanResult
      { .success }
      func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
      func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(id _: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    struct Strategy2: LockmanStrategy {
      typealias I = LockmanSingleExecutionInfo
      var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
      static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo)
        -> LockmanResult
      { .success }
      func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
      func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(id _: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    struct Strategy3: LockmanStrategy {
      typealias I = LockmanPriorityBasedInfo
      var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
      static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) -> LockmanResult
      { .success }
      func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
      func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(id _: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    let container = LockmanStrategyContainer()

    // Register multiple strategy types
    do {
      try container.register(Strategy1())
      try container.register(Strategy2())
      try container.register(Strategy3())
    } catch {
      XCTFail("Registration should not throw: \(error)")
    }

    // Verify all are registered
    XCTAssertTrue(container.isRegistered(Strategy1.self))
    XCTAssertTrue(container.isRegistered(Strategy2.self))
    XCTAssertTrue(container.isRegistered(Strategy3.self))

    // Verify all can be resolved
    do {
      _ = try container.resolve(Strategy1.self)
      _ = try container.resolve(Strategy2.self)
      _ = try container.resolve(Strategy3.self)
    } catch {
      XCTFail("Resolution should not throw: \(error)")
    }
  }

  // MARK: - Cleanup Edge Cases

  func testCleanupWithNoActiveLocks() async throws {
    let strategy = LockmanSingleExecutionStrategy()

    // Cleanup should not crash even with no locks
    strategy.cleanUp()
    strategy.cleanUp(id: "non-existent-boundary")

    // Should still be usable after cleanup
    let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
    let boundaryId = "test-boundary"

    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
    strategy.lock(id: boundaryId, info: info)
    strategy.unlock(id: boundaryId, info: info)
  }

  func testMultipleCleanupCalls() async throws {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "cleanup-test"
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))

    // Lock something first
    strategy.lock(id: boundaryId, info: info)

    // Multiple cleanup calls should be safe
    strategy.cleanUp()
    strategy.cleanUp()
    strategy.cleanUp(id: boundaryId)
    strategy.cleanUp(id: boundaryId)

    // Should still be usable
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
  }

  func testCleanupDuringActiveOperations() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "concurrent-cleanup"
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)

    // Lock first
    strategy.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: info))

    // Cleanup should clear the lock
    strategy.cleanUp()
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)

    // Should be able to lock again
    strategy.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: info))

    strategy.cleanUp()
  }

  // MARK: - Boundary Lock Edge Cases

  func testSameBoundaryIDWithDifferentTypes() async throws {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()

    let boundaryId = "shared-boundary"
    let singleInfo = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(actionId: "action", priority: .high(.exclusive))

    // Both strategies should be able to use the same boundary ID independently
    singleStrategy.lock(id: boundaryId, info: singleInfo)
    priorityStrategy.lock(id: boundaryId, info: priorityInfo)

    // Each should respect their own locks
    XCTAssertLockFailure(singleStrategy.canLock(id: boundaryId, info: singleInfo))
    XCTAssertLockFailure(priorityStrategy.canLock(id: boundaryId, info: priorityInfo))

    // Cleanup one shouldn't affect the other
    singleStrategy.cleanUp(id: boundaryId)
    XCTAssertEqual(singleStrategy.canLock(id: boundaryId, info: singleInfo), .success)
    XCTAssertLockFailure(priorityStrategy.canLock(id: boundaryId, info: priorityInfo))

    priorityStrategy.cleanUp()
  }

  // MARK: - Unique ID Edge Cases

  func testUniqueIDCollisionResistance() async throws {
    var uniqueIds: Set<UUID> = []
    let instanceCount = 10000

    // Generate many instances with same action ID
    for _ in 0..<instanceCount {
      let info = LockmanSingleExecutionInfo(actionId: "same-action-id", mode: .boundary)
      XCTAssertTrue(uniqueIds.insert(info.uniqueId).inserted)  // Should always be unique
    }

    XCTAssertEqual(uniqueIds.count, instanceCount)
  }

  func testUniqueIDPersistenceAcrossOperations() async throws {
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))
    let originalUniqueId = info.uniqueId

    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "persistence-test"

    // Use in multiple operations
    strategy.lock(id: boundaryId, info: info)
    strategy.unlock(id: boundaryId, info: info)
    strategy.lock(id: boundaryId, info: info)

    // Unique ID should remain the same
    XCTAssertEqual(info.uniqueId, originalUniqueId)

    strategy.cleanUp()
  }
}
