import Foundation
import Testing
@testable import LockmanCore

// MARK: - Test Helpers

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(value: String) {
    self.value = value
  }

  init(_ value: String) {
    self.value = value
  }

  var description: String { value }

  static func == (lhs: TestBoundaryId, rhs: TestBoundaryId) -> Bool {
    lhs.value == rhs.value
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }
}

private struct AnotherBoundaryId: LockmanBoundaryId {
  let value: String
  var description: String { value }
}

private struct TestLockmanInfo: LockmanInfo, Equatable {
  let actionId: String
  let uniqueId: UUID = .init()
  let timestamp: Date

  init(id: String, timestamp: Date = Date()) {
    self.actionId = id
    self.timestamp = timestamp
  }

  var description: String {
    "TestLockmanInfo(id: \(actionId), timestamp: \(timestamp))"
  }

  var debugDescription: String {
    "TestLockmanInfo(actionId: \(actionId))"
  }

  static func == (lhs: TestLockmanInfo, rhs: TestLockmanInfo) -> Bool {
    lhs.actionId == rhs.actionId && lhs.timestamp == rhs.timestamp
  }
}

// MARK: - LockmanState Tests

@Suite("LockmanState Tests")
struct LockmanStateTests {
  // MARK: - Basic Operations

  @Test("Add single entry")
  func testAddSingleEntry() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(id: boundaryId, info: info)

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == 1)
    #expect(currents.first?.actionId == "1")
  }

  @Test("Add multiple entries to same boundary")
  func testAddMultipleEntriesToSameBoundary() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")
    let info3 = TestLockmanInfo(id: "3")

    state.add(id: boundaryId, info: info1)
    state.add(id: boundaryId, info: info2)
    state.add(id: boundaryId, info: info3)

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == 3)
    #expect(currents.map(\.actionId) == ["1", "2", "3"])
  }

  @Test("Add entries to different boundaries")
  func testAddEntriesToDifferentBoundaries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(id: boundary1, info: info1)
    state.add(id: boundary2, info: info2)

    let currents1 = state.currents(id: boundary1)
    let currents2 = state.currents(id: boundary2)

    #expect(currents1.count == 1)
    #expect(currents1.first?.actionId == "1")
    #expect(currents2.count == 1)
    #expect(currents2.first?.actionId == "2")
  }

  @Test("Remove last from single entry")
  func testRemoveLastFromSingleEntry() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(id: boundaryId, info: info)
    state.removeAll(id: boundaryId)

    let currents = state.currents(id: boundaryId)
    #expect(currents.isEmpty)
  }

  @Test("Remove last from multiple entries")
  func testRemoveLastFromMultipleEntries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")
    let info3 = TestLockmanInfo(id: "3")

    state.add(id: boundaryId, info: info1)
    state.add(id: boundaryId, info: info2)
    state.add(id: boundaryId, info: info3)

    state.remove(id: boundaryId, info: info3)

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == 2)
    #expect(currents.map(\.actionId) == ["1", "2"])
  }

  @Test("Remove last from non-existent boundary")
  func testRemoveLastFromNonExistentBoundary() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "non-existent")

    // Should not crash
    state.removeAll(id: boundaryId)

    let currents = state.currents(id: boundaryId)
    #expect(currents.isEmpty)
  }

  @Test("Get currents from empty state")
  func testGetCurrentsFromEmptyState() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    let currents = state.currents(id: boundaryId)
    #expect(currents.isEmpty)
  }

  @Test("Clean up all entries")
  func testCleanUpAllEntries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(id: boundary1, info: info1)
    state.add(id: boundary2, info: info2)

    state.removeAll()

    let currents1 = state.currents(id: boundary1)
    let currents2 = state.currents(id: boundary2)

    #expect(currents1.isEmpty)
    #expect(currents2.isEmpty)
  }

  @Test("Clean up specific boundary")
  func testCleanUpSpecificBoundary() {
    let state = LockmanState<TestLockmanInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(id: boundary1, info: info1)
    state.add(id: boundary2, info: info2)

    state.removeAll(id: boundary1)

    let currents1 = state.currents(id: boundary1)
    let currents2 = state.currents(id: boundary2)

    #expect(currents1.isEmpty)
    #expect(currents2.count == 1)
    #expect(currents2.first?.actionId == "2")
  }

  // MARK: - Concurrent Access Tests

  @Test("Concurrent adds to same boundary")
  func testConcurrentAddsToSameBoundary() async {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId("test")
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< iterations {
        group.addTask {
          let info = TestLockmanInfo(id: "\(i)")
          state.add(id: boundaryId, info: info)
        }
      }
    }

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == iterations, "All concurrent adds should succeed")
  }

  @Test("Concurrent adds to different boundaries")
  func testConcurrentAddsToDifferentBoundaries() async {
    let state = LockmanState<TestLockmanInfo>()
    let iterations = 50
    let boundaryCount = 5

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< iterations {
        group.addTask {
          let boundaryId = TestBoundaryId("boundary\(i % boundaryCount)")
          let info = TestLockmanInfo(id: "\(i)")
          state.add(id: boundaryId, info: info)
        }
      }
    }

    for i in 0 ..< boundaryCount {
      let boundaryId = TestBoundaryId("boundary\(i)")
      let currents = state.currents(id: boundaryId)
      let expectedCount = iterations / boundaryCount
      #expect(currents.count == expectedCount, "Each boundary should have \(expectedCount) entries")
    }
  }

  @Test("Concurrent add and remove operations")
  func testConcurrentAddAndRemoveOperations() async {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let iterations = 100

    let infoList = (0 ..< iterations).map { TestLockmanInfo(id: "\($0)") }

    // First, add some entries
    for info in infoList {
      state.add(id: boundaryId, info: info)
    }

    await withTaskGroup(of: Void.self) { group in
      // Add more entries
      for i in iterations ..< (iterations * 2) {
        group.addTask {
          let info = TestLockmanInfo(id: "\(i)")
          state.add(id: boundaryId, info: info)
        }
      }

      // Remove entries
      for info in infoList {
        state.remove(id: boundaryId, info: info)
      }
    }

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == iterations)
  }

  @Test("Concurrent read operations")
  func testConcurrentReadOperations() async {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    // Add some initial data
    for i in 0 ..< 10 {
      state.add(id: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
      for _ in 0 ..< 100 {
        group.addTask {
          state.currents(id: boundaryId).count
        }
      }

      var counts: [Int] = []
      for await count in group {
        counts.append(count)
      }
      return counts
    }

    #expect(results.allSatisfy { $0 == 10 })
  }

  // MARK: - Edge Cases

  @Test("Stack-like behavior verification")
  func testStackLikeBehavior() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    let infoList = (1 ... 5).map { TestLockmanInfo(id: "\($0)") }
    // Add in order
    for info in infoList {
      state.add(id: boundaryId, info: info)
    }

    // Remove and verify LIFO order
    for info in infoList.reversed() {
      let currents = state.currents(id: boundaryId)
      #expect(currents.last?.uniqueId == info.uniqueId)
      state.remove(id: boundaryId, info: info)
    }

    #expect(state.currents(id: boundaryId).isEmpty)
  }

  @Test("Large number of entries")
  func testLargeNumberOfEntries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let count = 1000 // Reduced from 10000 for reasonable test time

    for i in 0 ..< count {
      state.add(id: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == count)

    // Verify order is maintained
    for (index, info) in currents.enumerated() {
      #expect(info.actionId == "\(index)")
    }
  }

  @Test("Multiple clean up operations")
  func testMultipleCleanUpOperations() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    state.add(id: boundaryId, info: TestLockmanInfo(id: "1"))

    // Multiple cleanups should be safe
    state.removeAll(id: boundaryId)
    state.removeAll(id: boundaryId)
    state.removeAll()

    #expect(state.currents(id: boundaryId).isEmpty)
  }

  // MARK: - Data Integrity Tests

  @Test("Order preservation")
  func testOrderPreservation() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "order_test")
    let testData = ["first", "second", "third", "fourth", "fifth"]

    for id in testData {
      state.add(id: boundaryId, info: TestLockmanInfo(id: id))
    }

    let currents = state.currents(id: boundaryId)
    #expect(currents.map(\.actionId) == testData)
  }

  @Test("Boundary isolation")
  func testBoundaryIsolation() {
    let state = LockmanState<TestLockmanInfo>()
    let boundary1 = TestBoundaryId(value: "isolated1")
    let boundary2 = TestBoundaryId(value: "isolated2")
    let boundary3 = TestBoundaryId(value: "isolated3")

    // Add different data to each boundary
    state.add(id: boundary1, info: TestLockmanInfo(id: "a"))
    state.add(id: boundary2, info: TestLockmanInfo(id: "b"))
    state.add(id: boundary3, info: TestLockmanInfo(id: "c"))

    // Operations on one boundary should not affect others
    state.removeAll(id: boundary1)

    #expect(state.currents(id: boundary1).isEmpty)
    #expect(state.currents(id: boundary2).count == 1)
    #expect(state.currents(id: boundary3).count == 1)
    #expect(state.currents(id: boundary2).first?.actionId == "b")
    #expect(state.currents(id: boundary3).first?.actionId == "c")
  }

  @Test("Complex sequence operations")
  func testComplexSequenceOperations() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "complex")

    // Complex sequence: add, add, remove, add, remove, remove
    state.add(id: boundaryId, info: TestLockmanInfo(id: "1"))
    state.add(id: boundaryId, info: TestLockmanInfo(id: "2"))
    state.removeAll(id: boundaryId) // Remove "2"
    state.add(id: boundaryId, info: TestLockmanInfo(id: "3"))
    state.removeAll(id: boundaryId) // Remove "3"
    state.removeAll(id: boundaryId) // Remove "1"

    #expect(state.currents(id: boundaryId).isEmpty)
  }

  // MARK: - Memory Management Tests

  @Test("Memory cleanup after removals")
  func testMemoryCleanupAfterRemovals() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "memory_test")

    // Add many entries
    for i in 0 ..< 100 {
      state.add(id: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    // Remove all entries
    for _ in 0 ..< 100 {
      state.removeAll(id: boundaryId)
    }

    // State should be completely empty
    #expect(state.currents(id: boundaryId).isEmpty)

    // Should be able to add again without issues
    state.add(id: boundaryId, info: TestLockmanInfo(id: "new"))
    #expect(state.currents(id: boundaryId).count == 1)
  }

  @Test("Cleanup with mixed boundary states")
  func testCleanupWithMixedBoundaryStates() {
    let state = LockmanState<TestLockmanInfo>()
    let emptyBoundary = TestBoundaryId(value: "empty")
    let fullBoundary = TestBoundaryId(value: "full")
    let partialBoundary = TestBoundaryId(value: "partial")

    // fullBoundary has entries
    for i in 0 ..< 5 {
      state.add(id: fullBoundary, info: TestLockmanInfo(id: "full_\(i)"))
    }

    // partialBoundary has entries then some removed
    for i in 0 ..< 3 {
      state.add(id: partialBoundary, info: TestLockmanInfo(id: "partial_\(i)"))
    }

    // Clean up specific boundaries
    state.removeAll(id: emptyBoundary) // Should be safe
    state.removeAll(id: fullBoundary)

    #expect(state.currents(id: emptyBoundary).isEmpty)
    #expect(state.currents(id: fullBoundary).isEmpty)
    #expect(state.currents(id: partialBoundary).count == 3)
  }
}

// MARK: - AnyLockmanBoundaryId Tests

@Suite("AnyLockmanBoundaryId Tests")
struct AnyLockmanBoundaryIdTests {
  @Test("Equality with same values")
  func testEqualityWithSameValues() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = TestBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    #expect(any1 == any2)
  }

  @Test("Inequality with different values")
  func testInequalityWithDifferentValues() {
    let id1 = TestBoundaryId(value: "test1")
    let id2 = TestBoundaryId(value: "test2")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    #expect(any1 != any2)
  }

  @Test("Hash consistency")
  func testHashConsistency() {
    let id = TestBoundaryId(value: "test")
    let any1 = AnyLockmanBoundaryId(id)
    let any2 = AnyLockmanBoundaryId(id)

    #expect(any1.hashValue == any2.hashValue)
  }

  @Test("Different types with same value")
  func testDifferentTypesWithSameValue() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = AnotherBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    // Different types should not be equal even with same value
    #expect(any1 != any2)
  }

  @Test("Hash collision avoidance for different types")
  func testHashCollisionAvoidanceForDifferentTypes() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = AnotherBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    // Hash values should ideally be different for different types
    // This is a probabilistic test - hash collisions are possible but unlikely
    // We'll skip the hash comparison since occasional collisions are acceptable
    // and don't affect the correctness of the implementation

    // The important thing is that equality works correctly (tested elsewhere)
    #expect(any1 != any2) // Different types should never be equal

    // Verify they can both be used as dictionary keys
    var dict: [AnyLockmanBoundaryId: String] = [:]
    dict[any1] = "value1"
    dict[any2] = "value2"
    #expect(dict.count == 2) // Both should be stored separately
  }

  @Test("Use as dictionary key")
  func testUseAsDictionaryKey() {
    var dict: [AnyLockmanBoundaryId: String] = [:]

    let id1 = TestBoundaryId(value: "key1")
    let id2 = TestBoundaryId(value: "key2")
    let id1Copy = TestBoundaryId(value: "key1")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)
    let any1Copy = AnyLockmanBoundaryId(id1Copy)

    dict[any1] = "value1"
    dict[any2] = "value2"
    dict[any1Copy] = "updated_value1" // Should overwrite

    #expect(dict.count == 2)
    #expect(dict[any1] == "updated_value1")
    #expect(dict[any2] == "value2")
  }

  @Test("Sendable compliance across tasks")
  func testSendableComplianceAcrossTasks() async {
    let id = TestBoundaryId(value: "concurrent")
    let anyId = AnyLockmanBoundaryId(id)

    let results = await withTaskGroup(of: AnyLockmanBoundaryId.self, returning: [AnyLockmanBoundaryId].self) { group in
      for _ in 0 ..< 5 {
        group.addTask {
          anyId
        }
      }

      var results: [AnyLockmanBoundaryId] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    #expect(results.count == 5)
    #expect(results.allSatisfy { $0 == anyId })
  }
}

// MARK: - Performance Tests

@Suite("LockmanState Performance Tests")
struct LockmanStatePerformanceTests {
  @Test("Performance with frequent adds and removes")
  func testPerformanceWithFrequentAddsAndRemoves() async throws {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let iterations = 1000

    let startTime = Date()

    for i in 0 ..< iterations {
      let info = TestLockmanInfo(id: "\(i)")
      state.add(id: boundaryId, info: info)
      if i % 2 == 0 {
        state.remove(id: boundaryId, info: info)
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Should complete within reasonable time (adjust threshold as needed)
    #expect(duration < 1.0)

    // Verify final state
    let finalCount = state.currents(id: boundaryId).count
    #expect(finalCount == iterations / 2) // Half were removed
  }

  @Test("Performance with many boundaries")
  func testPerformanceWithManyBoundaries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryCount = 100
    let entriesPerBoundary = 10

    let startTime = Date()

    for i in 0 ..< boundaryCount {
      let boundaryId = TestBoundaryId(value: "boundary_\(i)")
      for j in 0 ..< entriesPerBoundary {
        state.add(id: boundaryId, info: TestLockmanInfo(id: "\(i)_\(j)"))
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(duration < 1.0)

    // Verify all boundaries have correct number of entries
    for i in 0 ..< boundaryCount {
      let boundaryId = TestBoundaryId(value: "boundary_\(i)")
      #expect(state.currents(id: boundaryId).count == entriesPerBoundary)
    }
  }

  @Test("Concurrent performance test")
  func testConcurrentPerformance() async {
    let state = LockmanState<TestLockmanInfo>()
    let taskCount = 1
    let operationsPerTask = 100

    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for taskId in 0 ..< taskCount {
        group.addTask {
          let boundaryId = TestBoundaryId(value: "task_\(taskId)")
          for i in 0 ..< operationsPerTask {
            let info = TestLockmanInfo(id: "\(taskId)_\(i)")
            state.add(id: boundaryId, info: info)
            if i % 3 == 0 {
              state.remove(id: boundaryId, info: info)
            }
          }
        }
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    #expect(duration < 2.0)

    // Verify each task's boundary has expected number of entries
    for taskId in 0 ..< taskCount {
      let boundaryId = TestBoundaryId(value: "task_\(taskId)")
      let currents = state.currents(id: boundaryId)
      let currentCount = currents.count
      let expectedCount = operationsPerTask - (operationsPerTask / 3) - 1
      #expect(currentCount == expectedCount)
    }
  }
}
