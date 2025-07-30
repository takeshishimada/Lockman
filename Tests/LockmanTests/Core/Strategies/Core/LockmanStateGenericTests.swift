import ConcurrencyExtras
import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Types

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String
  init(_ value: String) { self.value = value }
}

private struct TestInfo: LockmanInfo {
  let actionId: String
  let category: String
  let uniqueId = UUID()
  let strategyId = LockmanStrategyId("test")

  init(actionId: String, category: String) {
    self.actionId = actionId
    self.category = category
  }

  var debugDescription: String {
    "TestInfo(action: \(actionId), category: \(category))"
  }
}

private struct CompositeKey: Hashable {
  let category: String
  let priority: Int
}

private struct ComplexInfo: LockmanInfo {
  let actionId: String
  let category: String
  let priority: Int
  let uniqueId = UUID()
  let strategyId = LockmanStrategyId("complex")

  var debugDescription: String {
    "ComplexInfo(action: \(actionId), category: \(category), priority: \(priority))"
  }
}

// MARK: - Generic Key Type Tests

final class LockmanStateGenericTests: XCTestCase {

  // MARK: - Custom Key Type Tests

  func testLockmanStateWithCustomKeyType() {
    // Test using category as key instead of actionId
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    let info1 = TestInfo(actionId: "action1", category: "network")
    let info2 = TestInfo(actionId: "action2", category: "network")
    let info3 = TestInfo(actionId: "action3", category: "storage")

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)

    // Test contains with custom key
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "network"))
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "storage"))
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "compute"))

    // Test count by custom key
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "network"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "storage"), 1)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "compute"), 0)

    // Test currents by custom key
    let networkInfos = state.currentLocks(in: boundaryId, matching: "network")
    XCTAssertEqual(networkInfos.count, 2)
    XCTAssertTrue(networkInfos.contains { $0.actionId == "action1" })
    XCTAssertTrue(networkInfos.contains { $0.actionId == "action2" })

    // Test keys retrieval
    let keys = state.activeKeys(in: boundaryId)
    XCTAssertEqual(keys, Set(["network", "storage"]))
  }

  func testCompositeKeyType() {
    // Test with composite key type
    let state = LockmanState<ComplexInfo, CompositeKey>(
      keyExtractor: { CompositeKey(category: $0.category, priority: $0.priority) }
    )
    let boundaryId = TestBoundaryId("test")

    let info1 = ComplexInfo(actionId: "a1", category: "network", priority: 1)
    let info2 = ComplexInfo(actionId: "a2", category: "network", priority: 1)
    let info3 = ComplexInfo(actionId: "a3", category: "network", priority: 2)
    let info4 = ComplexInfo(actionId: "a4", category: "storage", priority: 1)

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)
    state.add(boundaryId: boundaryId, info: info4)

    let key1 = CompositeKey(category: "network", priority: 1)
    let key2 = CompositeKey(category: "network", priority: 2)
    let key3 = CompositeKey(category: "storage", priority: 1)

    // Test contains with composite key
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: key1))
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: key2))
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: key3))
    XCTAssertFalse(
      state.hasActiveLocks(in: boundaryId, matching: CompositeKey(category: "compute", priority: 1))
    )

    // Test count with composite key
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: key1), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: key2), 1)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: key3), 1)

    // Test currents with composite key
    let networkP1Infos = state.currentLocks(in: boundaryId, matching: key1)
    XCTAssertEqual(networkP1Infos.count, 2)
    XCTAssertTrue(networkP1Infos.allSatisfy { $0.category == "network" && $0.priority == 1 })
  }

  // MARK: - Generic removeAll Tests

  func testRemoveAllWithCustomKey() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add multiple infos with different categories
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a1", category: "network"))
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a2", category: "network"))
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a3", category: "storage"))
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a4", category: "compute"))

    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 4)

    // Remove all with "network" category
    state.removeAll(boundaryId: boundaryId, key: "network")

    let remaining = state.currentLocks(in: boundaryId)
    XCTAssertEqual(remaining.count, 2)
    XCTAssertFalse(remaining.contains { $0.category == "network" })
    XCTAssertTrue(remaining.contains { $0.category == "storage" })
    XCTAssertTrue(remaining.contains { $0.category == "compute" })

    // Try removing non-existent key
    state.removeAll(boundaryId: boundaryId, key: "nonexistent")
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 2)  // Should not change
  }

  func testRemoveAllWithEmptyBoundary() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("empty")

    // Try removing from empty boundary
    state.removeAll(boundaryId: boundaryId, key: "network")

    // Should not crash and should remain empty
    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
  }

  func testRemoveAllLastKeyInBoundary() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add infos with only one category
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a1", category: "network"))
    state.add(boundaryId: boundaryId, info: TestInfo(actionId: "a2", category: "network"))

    // Remove all with that category
    state.removeAll(boundaryId: boundaryId, key: "network")

    // Boundary should be completely empty
    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
    XCTAssertTrue(state.activeKeys(in: boundaryId).isEmpty)
  }

  // MARK: - Bulk Query Operations Tests

  func testAllBoundaryIds() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })

    let boundary1 = TestBoundaryId("b1")
    let boundary2 = TestBoundaryId("b2")
    let boundary3 = TestBoundaryId("b3")

    // Initially empty
    XCTAssertTrue(state.activeBoundaryIds().isEmpty)

    // Add to different boundaries
    state.add(boundaryId: boundary1, info: TestInfo(actionId: "a1", category: "cat1"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "a2", category: "cat2"))
    state.add(boundaryId: boundary3, info: TestInfo(actionId: "a3", category: "cat3"))

    let allBoundaryIds = state.activeBoundaryIds()
    XCTAssertEqual(allBoundaryIds.count, 3)
    XCTAssertTrue(allBoundaryIds.contains(AnyLockmanBoundaryId(boundary1)))
    XCTAssertTrue(allBoundaryIds.contains(AnyLockmanBoundaryId(boundary2)))
    XCTAssertTrue(allBoundaryIds.contains(AnyLockmanBoundaryId(boundary3)))

    // Remove one boundary
    state.removeAll(boundaryId: boundary2)

    let remainingBoundaryIds = state.activeBoundaryIds()
    XCTAssertEqual(remainingBoundaryIds.count, 2)
    XCTAssertFalse(remainingBoundaryIds.contains(AnyLockmanBoundaryId(boundary2)))
  }

  func testTotalLockCount() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })

    let boundary1 = TestBoundaryId("b1")
    let boundary2 = TestBoundaryId("b2")

    // Initially zero
    XCTAssertEqual(state.totalActiveLockCount(), 0)

    // Add locks to different boundaries
    state.add(boundaryId: boundary1, info: TestInfo(actionId: "a1", category: "cat1"))
    state.add(boundaryId: boundary1, info: TestInfo(actionId: "a2", category: "cat2"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "a3", category: "cat1"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "a4", category: "cat2"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "a5", category: "cat3"))

    XCTAssertEqual(state.totalActiveLockCount(), 5)

    // Remove some locks
    state.removeAll(boundaryId: boundary1, key: "cat1")
    XCTAssertEqual(state.totalActiveLockCount(), 4)

    // Remove entire boundary
    state.removeAll(boundaryId: boundary2)
    XCTAssertEqual(state.totalActiveLockCount(), 1)

    // Remove all
    state.removeAll()
    XCTAssertEqual(state.totalActiveLockCount(), 0)
  }

  func testGetAllLocks() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })

    let boundary1 = TestBoundaryId("b1")
    let boundary2 = TestBoundaryId("b2")

    // Initially empty
    XCTAssertTrue(state.allActiveLocks().isEmpty)

    // Add locks
    let info1 = TestInfo(actionId: "a1", category: "cat1")
    let info2 = TestInfo(actionId: "a2", category: "cat2")
    let info3 = TestInfo(actionId: "a3", category: "cat1")

    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary1, info: info2)
    state.add(boundaryId: boundary2, info: info3)

    let allLocks = state.allActiveLocks()
    XCTAssertEqual(allLocks.count, 2)

    let boundary1Locks = allLocks[AnyLockmanBoundaryId(boundary1)]
    XCTAssertNotNil(boundary1Locks)
    XCTAssertEqual(boundary1Locks?.count, 2)

    let boundary2Locks = allLocks[AnyLockmanBoundaryId(boundary2)]
    XCTAssertNotNil(boundary2Locks)
    XCTAssertEqual(boundary2Locks?.count, 1)
  }

  // MARK: - Index Consistency Tests

  func testIndexConsistencyAfterComplexOperations() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add multiple infos
    let infos = [
      TestInfo(actionId: "a1", category: "network"),
      TestInfo(actionId: "a2", category: "network"),
      TestInfo(actionId: "a3", category: "storage"),
      TestInfo(actionId: "a4", category: "storage"),
      TestInfo(actionId: "a5", category: "compute"),
    ]

    for info in infos {
      state.add(boundaryId: boundaryId, info: info)
    }

    // Verify initial state
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "network"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "storage"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "compute"), 1)

    // Remove individual items
    state.remove(boundaryId: boundaryId, info: infos[0])  // Remove one network
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "network"), 1)

    // Remove by key
    state.removeAll(boundaryId: boundaryId, key: "storage")
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "storage"), 0)
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "storage"))

    // Verify keys are updated
    let keys = state.activeKeys(in: boundaryId)
    XCTAssertEqual(keys, Set(["network", "compute"]))

    // Verify total count
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 2)
  }

  func testIndexCleanupAfterPartialRemovals() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add infos with same category
    let info1 = TestInfo(actionId: "a1", category: "network")
    let info2 = TestInfo(actionId: "a2", category: "network")

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)

    // Remove one by one
    state.remove(boundaryId: boundaryId, info: info1)
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "network"))
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "network"), 1)

    state.remove(boundaryId: boundaryId, info: info2)
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "network"))
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "network"), 0)
    XCTAssertTrue(state.activeKeys(in: boundaryId).isEmpty)
  }

  // MARK: - Memory and Performance Tests

  func testMemoryEfficiencyWithManyUniqueKeys() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add many infos with unique categories
    for i in 0..<1000 {
      let info = TestInfo(actionId: "action\(i)", category: "category\(i)")
      state.add(boundaryId: boundaryId, info: info)
    }

    // Verify all keys are tracked
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, 1000)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1000)

    // Each key should have exactly one info
    for i in 0..<1000 {
      XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "category\(i)"), 1)
    }
  }

  func testPerformanceOfKeyBasedOperations() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Create a scenario with few keys but many items per key
    for i in 0..<1000 {
      let category = "category\(i % 10)"  // Only 10 unique categories
      let info = TestInfo(actionId: "action\(i)", category: category)
      state.add(boundaryId: boundaryId, info: info)
    }

    // Measure key-based operations
    let startTime = Date()

    // These should be O(1) operations
    for i in 0..<100 {
      let category = "category\(i % 10)"
      _ = state.hasActiveLocks(in: boundaryId, matching: category)
      _ = state.activeLockCount(in: boundaryId, matching: category)
    }

    let duration = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(duration, 0.1)  // Should be very fast

    // Verify counts
    for i in 0..<10 {
      XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "category\(i)"), 100)
    }
  }

  // MARK: - Edge Cases

  func testKeyExtractorConsistency() {
    let extractorCallCount = ManagedCriticalState(0)
    let state = LockmanState<TestInfo, String>(keyExtractor: { info in
      extractorCallCount.withCriticalRegion { count in
        count += 1
      }
      return info.category
    })

    let boundaryId = TestBoundaryId("test")
    let info = TestInfo(actionId: "a1", category: "network")

    // Add should call extractor once
    let initialCount = extractorCallCount.withCriticalRegion { $0 }
    state.add(boundaryId: boundaryId, info: info)
    XCTAssertEqual(extractorCallCount.withCriticalRegion { $0 }, initialCount + 1)

    // Remove should call extractor once
    let countBeforeRemove = extractorCallCount.withCriticalRegion { $0 }
    state.remove(boundaryId: boundaryId, info: info)
    XCTAssertEqual(extractorCallCount.withCriticalRegion { $0 }, countBeforeRemove + 1)
  }

  func testOrderPreservationWithCustomKeys() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add infos in specific order
    let infos = [
      TestInfo(actionId: "first", category: "network"),
      TestInfo(actionId: "second", category: "storage"),
      TestInfo(actionId: "third", category: "network"),
      TestInfo(actionId: "fourth", category: "compute"),
      TestInfo(actionId: "fifth", category: "network"),
    ]

    for info in infos {
      state.add(boundaryId: boundaryId, info: info)
    }

    // Get all currents - should preserve order
    let allCurrents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(allCurrents.map(\.actionId), ["first", "second", "third", "fourth", "fifth"])

    // Get currents by key - should preserve relative order
    let networkCurrents = state.currentLocks(in: boundaryId, matching: "network")
    XCTAssertEqual(networkCurrents.map(\.actionId), ["first", "third", "fifth"])
  }

  func testConcurrentAccessWithCustomKeys() async {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    await withTaskGroup(of: Void.self) { group in
      // Add tasks
      for i in 0..<100 {
        group.addTask {
          let category = "category\(i % 5)"
          let info = TestInfo(actionId: "action\(i)", category: category)
          state.add(boundaryId: boundaryId, info: info)
        }
      }

      // Query tasks
      for i in 0..<50 {
        group.addTask {
          let category = "category\(i % 5)"
          _ = state.hasActiveLocks(in: boundaryId, matching: category)
          _ = state.activeLockCount(in: boundaryId, matching: category)
          _ = state.currentLocks(in: boundaryId, matching: category)
        }
      }
    }

    // Verify final state
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 100)
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, 5)
  }

  func testEmptyKeyHandling() {
    let state = LockmanState<TestInfo, String>(keyExtractor: { $0.category })
    let boundaryId = TestBoundaryId("test")

    // Add info with empty category
    let info = TestInfo(actionId: "a1", category: "")
    state.add(boundaryId: boundaryId, info: info)

    // Should work with empty key
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: ""))
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: ""), 1)
    XCTAssertEqual(state.currentLocks(in: boundaryId, matching: "").count, 1)

    // Remove with empty key
    state.removeAll(boundaryId: boundaryId, key: "")
    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
  }
}
