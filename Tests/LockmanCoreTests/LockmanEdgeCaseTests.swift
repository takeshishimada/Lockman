import Foundation
import Testing
@testable import LockmanCore

/// Tests for edge cases, boundary values, and exceptional scenarios
@Suite("Lockman Edge Case Tests")
struct LockmanEdgeCaseTests {
  // MARK: - Boundary ID Edge Cases

  @Test("Empty boundary ID handling")
  func emptyBoundaryIdHandling() {
    let strategy = LockmanSingleExecutionStrategy()
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    let emptyBoundaryId = ""

    // Should handle empty boundary ID without crashing
    #expect(strategy.canLock(id: emptyBoundaryId, info: info) == .success)
    strategy.lock(id: emptyBoundaryId, info: info)
    #expect(strategy.canLock(id: emptyBoundaryId, info: info) == .failure)
    strategy.unlock(id: emptyBoundaryId, info: info)
    #expect(strategy.canLock(id: emptyBoundaryId, info: info) == .success)

    // Cleanup should work
    strategy.cleanUp(id: emptyBoundaryId)
  }

  @Test("Very long boundary ID handling")
  func veryLongBoundaryIdHandling() {
    let strategy = LockmanPriorityBasedStrategy()
    let info = LockmanPriorityBasedInfo(actionId: "test-action", priority: .high(.exclusive))
    let longBoundaryId = String(repeating: "VeryLongBoundaryId", count: 100) // 1800 characters

    #expect(strategy.canLock(id: longBoundaryId, info: info) == .success)
    strategy.lock(id: longBoundaryId, info: info)
    #expect(strategy.canLock(id: longBoundaryId, info: info) == .failure)
    strategy.unlock(id: longBoundaryId, info: info)

    strategy.cleanUp(id: longBoundaryId)
  }

  @Test("Unicode boundary ID handling")
  func unicodeBoundaryIdHandling() {
    let strategy = LockmanSingleExecutionStrategy()
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    let unicodeBoundaryId = "🔒境界識別子📱测试🚀"

    #expect(strategy.canLock(id: unicodeBoundaryId, info: info) == .success)
    strategy.lock(id: unicodeBoundaryId, info: info)
    #expect(strategy.canLock(id: unicodeBoundaryId, info: info) == .failure)
    strategy.unlock(id: unicodeBoundaryId, info: info)

    strategy.cleanUp(id: unicodeBoundaryId)
  }

  @Test("Special character boundary ID handling")
  func specialCharacterBoundaryIdHandling() {
    let strategy = LockmanPriorityBasedStrategy()
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .low(.replaceable))
    let specialBoundaryId = "boundary@#$%^&*()_+-=[]{}|;':\",./<>?"

    #expect(strategy.canLock(id: specialBoundaryId, info: info) == .success)
    strategy.lock(id: specialBoundaryId, info: info)
    strategy.cleanUp(id: specialBoundaryId)
  }

  // MARK: - Action ID Edge Cases

  @Test("Empty action ID handling")
  func emptyActionIdHandling() {
    let strategy = LockmanSingleExecutionStrategy()
    let emptyActionInfo = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    let boundaryId = "test-boundary"

    #expect(strategy.canLock(id: boundaryId, info: emptyActionInfo) == .success)
    strategy.lock(id: boundaryId, info: emptyActionInfo)
    #expect(strategy.canLock(id: boundaryId, info: emptyActionInfo) == .failure)

    // Different empty action should also conflict
    let anotherEmptyInfo = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    #expect(strategy.canLock(id: boundaryId, info: anotherEmptyInfo) == .failure)

    strategy.unlock(id: boundaryId, info: emptyActionInfo)
    strategy.cleanUp()
  }

  @Test("Very long action ID handling")
  func veryLongActionIdHandling() {
    let strategy = LockmanPriorityBasedStrategy()
    let longActionId = String(repeating: "VeryLongActionIdentifier", count: 50) // 1250 characters
    let info = LockmanPriorityBasedInfo(actionId: longActionId, priority: .high(.exclusive))
    let boundaryId = "test-boundary"

    #expect(strategy.canLock(id: boundaryId, info: info) == .success)
    strategy.lock(id: boundaryId, info: info)

    // Same long action ID with lower priority should fail
    let sameActionInfo = LockmanPriorityBasedInfo(actionId: longActionId, priority: .low(.exclusive))
    #expect(strategy.canLock(id: boundaryId, info: sameActionInfo) == .failure)

    strategy.cleanUp()
  }

  @Test("Unicode action ID handling")
  func unicodeActionIdHandling() {
    let strategy = LockmanSingleExecutionStrategy()
    let unicodeActionId = "🚀アクション测试🔒動作識別子📱"
    let info = LockmanSingleExecutionInfo(actionId: unicodeActionId, mode: .boundary)
    let boundaryId = "test-boundary"

    #expect(strategy.canLock(id: boundaryId, info: info) == .success)
    strategy.lock(id: boundaryId, info: info)

    // Same unicode action ID should conflict
    let sameUnicodeInfo = LockmanSingleExecutionInfo(actionId: unicodeActionId, mode: .boundary)
    #expect(strategy.canLock(id: boundaryId, info: sameUnicodeInfo) == .failure)

    strategy.unlock(id: boundaryId, info: info)
    strategy.cleanUp()
  }

  // MARK: - Priority Edge Cases

  @Test("None priority behavior with conflicts")
  func nonePriorityBehaviorWithConflicts() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "priority-test"

    let noneInfo1 = LockmanPriorityBasedInfo(actionId: "none-action", priority: .none)
    let noneInfo2 = LockmanPriorityBasedInfo(actionId: "none-action", priority: .none)
    let highInfo = LockmanPriorityBasedInfo(actionId: "none-action", priority: .high(.exclusive))

    // First none priority should succeed
    #expect(strategy.canLock(id: boundaryId, info: noneInfo1) == .success)
    strategy.lock(id: boundaryId, info: noneInfo1)

    // Second none priority with same action ID should succeed (no conflicts for .none)
    #expect(strategy.canLock(id: boundaryId, info: noneInfo2) == .success)
    strategy.lock(id: boundaryId, info: noneInfo2)

    // High priority should succeed (may not cancel if none priority doesn't block)
    let result = strategy.canLock(id: boundaryId, info: highInfo)
    #expect(result == .success || result == .successWithPrecedingCancellation)

    strategy.cleanUp()
  }

  @Test("Priority comparison edge cases")
  func priorityComparisonEdgeCases() {
    let none = LockmanPriorityBasedInfo.Priority.none
    let lowExclusive = LockmanPriorityBasedInfo.Priority.low(.exclusive)
    let lowReplaceable = LockmanPriorityBasedInfo.Priority.low(.replaceable)
    let highExclusive = LockmanPriorityBasedInfo.Priority.high(.exclusive)
    let highReplaceable = LockmanPriorityBasedInfo.Priority.high(.replaceable)

    // Test ordering
    #expect(none < lowExclusive)
    #expect(none < lowReplaceable)
    #expect(lowExclusive < highExclusive)
    #expect(lowReplaceable < highReplaceable)

    // Test equality (ignores behavior)
    #expect(lowExclusive == lowReplaceable)
    #expect(highExclusive == highReplaceable)
    #expect(none != lowExclusive)
    #expect(lowExclusive != highExclusive)
  }

  // MARK: - Memory and Performance Edge Cases

  @Test("High frequency lock operations")
  func highFrequencyLockOperations() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "performance-test"
    let operationCount = 1000

    let startTime = CFAbsoluteTimeGetCurrent()

    for i in 0 ..< operationCount {
      let info = LockmanSingleExecutionInfo(actionId: "operation-\(i)", mode: .boundary)

      #expect(strategy.canLock(id: boundaryId, info: info) == .success)
      strategy.lock(id: boundaryId, info: info)
      strategy.unlock(id: boundaryId, info: info)
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete 1000 operations in reasonable time
    #expect(executionTime < 1.0) // Less than 1 second

    strategy.cleanUp()
  }

  @Test("Many concurrent boundaries")
  func manyConcurrentBoundaries() {
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryCount = 1000

    // Lock on many different boundaries
    for i in 0 ..< boundaryCount {
      let boundaryId = "boundary-\(i)"
      let info = LockmanPriorityBasedInfo(actionId: "action", priority: .low(.exclusive))

      #expect(strategy.canLock(id: boundaryId, info: info) == .success)
      strategy.lock(id: boundaryId, info: info)
    }

    // Verify all are locked independently
    for i in 0 ..< boundaryCount {
      let boundaryId = "boundary-\(i)"
      let newInfo = LockmanPriorityBasedInfo(actionId: "action", priority: .low(.exclusive))

      #expect(strategy.canLock(id: boundaryId, info: newInfo) == .failure)
    }

    strategy.cleanUp()
  }

  @Test("Memory efficiency with many info instances")
  func memoryEfficiencyWithManyInfoInstances() {
    var infos: [LockmanSingleExecutionInfo] = []
    let instanceCount = 10000

    // Create many info instances
    for i in 0 ..< instanceCount {
      let info = LockmanSingleExecutionInfo(actionId: "action-\(i)", mode: .boundary)
      infos.append(info)
    }

    // Verify they all have unique IDs
    let uniqueIds = Set(infos.map(\.uniqueId))
    #expect(uniqueIds.count == instanceCount)

    // Verify they can be used with strategies
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "memory-test"

    // Use a subset to avoid excessive test time
    for i in 0 ..< 100 {
      let info = infos[i]
      #expect(strategy.canLock(id: boundaryId, info: info) == .success)
      strategy.lock(id: boundaryId, info: info)
      strategy.unlock(id: boundaryId, info: info)
    }

    strategy.cleanUp()
  }

  // MARK: - Container Edge Cases

  @Test("Strategy container with many strategy types")
  func strategyContainerWithManyStrategyTypes() {
    // Create multiple unique strategy types for testing
    struct Strategy1: LockmanStrategy {
      typealias I = LockmanSingleExecutionInfo
      var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
      static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockResult { .success }
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
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockResult { .success }
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
      func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) -> LockResult { .success }
      func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
      func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(id _: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    let container = LockmanStrategyContainer()

    // Register multiple strategy types
    #expect(throws: Never.self) {
      try container.register(Strategy1())
      try container.register(Strategy2())
      try container.register(Strategy3())
    }

    // Verify all are registered
    #expect(container.isRegistered(Strategy1.self))
    #expect(container.isRegistered(Strategy2.self))
    #expect(container.isRegistered(Strategy3.self))

    // Verify all can be resolved
    #expect(throws: Never.self) {
      _ = try container.resolve(Strategy1.self)
      _ = try container.resolve(Strategy2.self)
      _ = try container.resolve(Strategy3.self)
    }
  }

  // MARK: - Cleanup Edge Cases

  @Test("Cleanup with no active locks")
  func cleanupWithNoActiveLocks() {
    let strategy = LockmanSingleExecutionStrategy()

    // Cleanup should not crash even with no locks
    strategy.cleanUp()
    strategy.cleanUp(id: "non-existent-boundary")

    // Should still be usable after cleanup
    let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
    let boundaryId = "test-boundary"

    #expect(strategy.canLock(id: boundaryId, info: info) == .success)
    strategy.lock(id: boundaryId, info: info)
    strategy.unlock(id: boundaryId, info: info)
  }

  @Test("Multiple cleanup calls")
  func multipleCleanupCalls() {
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
    #expect(strategy.canLock(id: boundaryId, info: info) == .success)
  }

  @Test("Cleanup during active operations")
  func cleanupDuringActiveOperations() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "concurrent-cleanup"
    let info = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)

    // Lock first
    strategy.lock(id: boundaryId, info: info)
    #expect(strategy.canLock(id: boundaryId, info: info) == .failure)

    // Cleanup should clear the lock
    strategy.cleanUp()
    #expect(strategy.canLock(id: boundaryId, info: info) == .success)

    // Should be able to lock again
    strategy.lock(id: boundaryId, info: info)
    #expect(strategy.canLock(id: boundaryId, info: info) == .failure)

    strategy.cleanUp()
  }

  // MARK: - Boundary Lock Edge Cases

  @Test("Same boundary ID with different types")
  func sameBoundaryIdWithDifferentTypes() {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()

    let boundaryId = "shared-boundary"
    let singleInfo = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(actionId: "action", priority: .high(.exclusive))

    // Both strategies should be able to use the same boundary ID independently
    singleStrategy.lock(id: boundaryId, info: singleInfo)
    priorityStrategy.lock(id: boundaryId, info: priorityInfo)

    // Each should respect their own locks
    #expect(singleStrategy.canLock(id: boundaryId, info: singleInfo) == .failure)
    #expect(priorityStrategy.canLock(id: boundaryId, info: priorityInfo) == .failure)

    // Cleanup one shouldn't affect the other
    singleStrategy.cleanUp(id: boundaryId)
    #expect(singleStrategy.canLock(id: boundaryId, info: singleInfo) == .success)
    #expect(priorityStrategy.canLock(id: boundaryId, info: priorityInfo) == .failure)

    priorityStrategy.cleanUp()
  }

  // MARK: - Unique ID Edge Cases

  @Test("Unique ID collision resistance")
  func uniqueIdCollisionResistance() {
    var uniqueIds: Set<UUID> = []
    let instanceCount = 10000

    // Generate many instances with same action ID
    for _ in 0 ..< instanceCount {
      let info = LockmanSingleExecutionInfo(actionId: "same-action-id", mode: .boundary)
      #expect(uniqueIds.insert(info.uniqueId).inserted) // Should always be unique
    }

    #expect(uniqueIds.count == instanceCount)
  }

  @Test("Unique ID persistence across operations")
  func uniqueIdPersistenceAcrossOperations() {
    let info = LockmanPriorityBasedInfo(actionId: "test", priority: .high(.exclusive))
    let originalUniqueId = info.uniqueId

    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "persistence-test"

    // Use in multiple operations
    strategy.lock(id: boundaryId, info: info)
    strategy.unlock(id: boundaryId, info: info)
    strategy.lock(id: boundaryId, info: info)

    // Unique ID should remain the same
    #expect(info.uniqueId == originalUniqueId)

    strategy.cleanUp()
  }
}
