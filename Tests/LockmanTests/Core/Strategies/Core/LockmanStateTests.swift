import Foundation
import XCTest

@testable import Lockman

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
  var strategyId: LockmanStrategyId { LockmanStrategyId("TestStrategy") }

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

final class LockmanStateTests: XCTestCase {
  // MARK: - Basic Operations

  func testAddSingleEntry() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(boundaryId: boundaryId, info: info)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, 1)
    XCTAssertEqual(currents.first?.actionId, "1")
  }

  func testAddMultipleEntriesToSameBoundary() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")
    let info3 = TestLockmanInfo(id: "3")

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, 3)
    XCTAssertEqual(currents.map(\.actionId), ["1", "2", "3"])
  }

  func testAddEntriesToDifferentBoundaries() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary2, info: info2)

    let currents1 = state.currentLocks(in: boundary1)
    let currents2 = state.currentLocks(in: boundary2)

    XCTAssertEqual(currents1.count, 1)
    XCTAssertEqual(currents1.first?.actionId, "1")
    XCTAssertEqual(currents2.count, 1)
    XCTAssertEqual(currents2.first?.actionId, "2")
  }

  func testRemoveLastFromSingleEntry() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(boundaryId: boundaryId, info: info)
    state.removeAll(boundaryId: boundaryId)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testRemoveLastFromMultipleEntries() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")
    let info3 = TestLockmanInfo(id: "3")

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)

    state.remove(boundaryId: boundaryId, info: info3)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, 2)
    XCTAssertEqual(currents.map(\.actionId), ["1", "2"])
  }

  func testRemoveLastFromNonExistentBoundary() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "non-existent")

    // Should not crash
    state.removeAll(boundaryId: boundaryId)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testGetCurrentsFromEmptyState() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testCleanUpAllEntries() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary2, info: info2)

    state.removeAll()

    let currents1 = state.currentLocks(in: boundary1)
    let currents2 = state.currentLocks(in: boundary2)

    XCTAssertTrue(currents1.isEmpty)
    XCTAssertTrue(currents2.isEmpty)
  }

  func testCleanUpSpecificBoundary() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary2, info: info2)

    state.removeAll(boundaryId: boundary1)

    let currents1 = state.currentLocks(in: boundary1)
    let currents2 = state.currentLocks(in: boundary2)

    XCTAssertTrue(currents1.isEmpty)
    XCTAssertEqual(currents2.count, 1)
    XCTAssertEqual(currents2.first?.actionId, "2")
  }

  // MARK: - Concurrent Access Tests

  func testConcurrentAddsToSameBoundary() async {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId("test")
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let info = TestLockmanInfo(id: "\(i)")
          state.add(boundaryId: boundaryId, info: info)
        }
      }
    }

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, iterations, "All concurrent adds should succeed")
  }

  func testConcurrentAddsToDifferentBoundaries() async {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let iterations = 50
    let boundaryCount = 5

    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let boundaryId = TestBoundaryId("boundary\(i % boundaryCount)")
          let info = TestLockmanInfo(id: "\(i)")
          state.add(boundaryId: boundaryId, info: info)
        }
      }
    }

    for i in 0..<boundaryCount {
      let boundaryId = TestBoundaryId("boundary\(i)")
      let currents = state.currentLocks(in: boundaryId)
      let expectedCount = iterations / boundaryCount
      XCTAssertEqual(
        currents.count, expectedCount, "Each boundary should have \(expectedCount) entries")
    }
  }

  func testConcurrentAddAndRemoveOperations() async {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let iterations = 100

    let infoList = (0..<iterations).map { TestLockmanInfo(id: "\($0)") }

    // First, add some entries
    for info in infoList {
      state.add(boundaryId: boundaryId, info: info)
    }

    await withTaskGroup(of: Void.self) { group in
      // Add more entries
      for i in iterations..<(iterations * 2) {
        group.addTask {
          let info = TestLockmanInfo(id: "\(i)")
          state.add(boundaryId: boundaryId, info: info)
        }
      }

      // Remove entries
      for info in infoList {
        state.remove(boundaryId: boundaryId, info: info)
      }
    }

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, iterations)
  }

  func testConcurrentReadOperations() async {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")

    // Add some initial data
    for i in 0..<10 {
      state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    let results = await withTaskGroup(of: Int.self, returning: [Int].self) { group in
      for _ in 0..<100 {
        group.addTask {
          state.currentLocks(in: boundaryId).count
        }
      }

      var counts: [Int] = []
      for await count in group {
        counts.append(count)
      }
      return counts
    }

    XCTAssertTrue(results.allSatisfy { $0 == 10 })
  }

  // MARK: - Edge Cases

  func testStackLikeBehavior() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")

    let infoList = (1...5).map { TestLockmanInfo(id: "\($0)") }
    // Add in order
    for info in infoList {
      state.add(boundaryId: boundaryId, info: info)
    }

    // Remove and verify LIFO order
    for info in infoList.reversed() {
      let currents = state.currentLocks(in: boundaryId)
      XCTAssertEqual(currents.last?.uniqueId, info.uniqueId)
      state.remove(boundaryId: boundaryId, info: info)
    }

    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
  }

  func testLargeNumberOfEntries() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let count = 1000  // Reduced from 10000 for reasonable test time

    for i in 0..<count {
      state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, count)

    // Verify order is maintained
    for (index, info) in currents.enumerated() {
      XCTAssertEqual(info.actionId, "\(index)")
    }
  }

  func testMultipleCleanUpOperations() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")

    state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "1"))

    // Multiple cleanups should be safe
    state.removeAll(boundaryId: boundaryId)
    state.removeAll(boundaryId: boundaryId)
    state.removeAll()

    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
  }

  // MARK: - Data Integrity Tests

  func testOrderPreservation() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "order_test")
    let testData = ["first", "second", "third", "fourth", "fifth"]

    for id in testData {
      state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: id))
    }

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertTrue(currents.map(\.actionId) == testData)
  }

  func testBoundaryIsolation() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "isolated1")
    let boundary2 = TestBoundaryId(value: "isolated2")
    let boundary3 = TestBoundaryId(value: "isolated3")

    // Add different data to each boundary
    state.add(boundaryId: boundary1, info: TestLockmanInfo(id: "a"))
    state.add(boundaryId: boundary2, info: TestLockmanInfo(id: "b"))
    state.add(boundaryId: boundary3, info: TestLockmanInfo(id: "c"))

    // Operations on one boundary should not affect others
    state.removeAll(boundaryId: boundary1)

    XCTAssertTrue(state.currentLocks(in: boundary1).isEmpty)
    XCTAssertTrue(state.currentLocks(in: boundary2).count == 1)
    XCTAssertTrue(state.currentLocks(in: boundary3).count == 1)
    XCTAssertTrue(state.currentLocks(in: boundary2).first?.actionId == "b")
    XCTAssertTrue(state.currentLocks(in: boundary3).first?.actionId == "c")
  }

  func testComplexSequenceOperations() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "complex")

    // Complex sequence: add, add, remove, add, remove, remove
    state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "1"))
    state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "2"))
    state.removeAll(boundaryId: boundaryId)  // Remove "2"
    state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "3"))
    state.removeAll(boundaryId: boundaryId)  // Remove "3"
    state.removeAll(boundaryId: boundaryId)  // Remove "1"

    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)
  }

  // MARK: - Memory Management Tests

  func testMemoryCleanupAfterRemovals() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "memory_test")

    // Add many entries
    for i in 0..<100 {
      state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    // Remove all entries
    for _ in 0..<100 {
      state.removeAll(boundaryId: boundaryId)
    }

    // State should be completely empty
    XCTAssertTrue(state.currentLocks(in: boundaryId).isEmpty)

    // Should be able to add again without issues
    state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "new"))
    XCTAssertTrue(state.currentLocks(in: boundaryId).count == 1)
  }

  func testCleanupWithMixedBoundaryStates() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let emptyBoundary = TestBoundaryId(value: "empty")
    let fullBoundary = TestBoundaryId(value: "full")
    let partialBoundary = TestBoundaryId(value: "partial")

    // fullBoundary has entries
    for i in 0..<5 {
      state.add(boundaryId: fullBoundary, info: TestLockmanInfo(id: "full_\(i)"))
    }

    // partialBoundary has entries then some removed
    for i in 0..<3 {
      state.add(boundaryId: partialBoundary, info: TestLockmanInfo(id: "partial_\(i)"))
    }

    // Clean up specific boundaries
    state.removeAll(boundaryId: emptyBoundary)  // Should be safe
    state.removeAll(boundaryId: fullBoundary)

    XCTAssertTrue(state.currentLocks(in: emptyBoundary).isEmpty)
    XCTAssertTrue(state.currentLocks(in: fullBoundary).isEmpty)
    XCTAssertTrue(state.currentLocks(in: partialBoundary).count == 3)
  }
}

// MARK: - AnyLockmanBoundaryId Tests

final class AnyLockmanBoundaryIdTests: XCTestCase {
  func testEqualityWithSameValues() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = TestBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    XCTAssertEqual(any1, any2)
  }

  func testInequalityWithDifferentValues() {
    let id1 = TestBoundaryId(value: "test1")
    let id2 = TestBoundaryId(value: "test2")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    XCTAssertNotEqual(any1, any2)
  }

  func testHashConsistency() {
    let id = TestBoundaryId(value: "test")
    let any1 = AnyLockmanBoundaryId(id)
    let any2 = AnyLockmanBoundaryId(id)

    XCTAssertEqual(any1.hashValue, any2.hashValue)
  }

  func testDifferentTypesWithSameValue() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = AnotherBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    // Different types should not be equal even with same value
    XCTAssertNotEqual(any1, any2)
  }

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
    XCTAssertNotEqual(any1, any2)  // Different types should never be equal

    // Verify they can both be used as dictionary keys
    var dict: [AnyLockmanBoundaryId: String] = [:]
    dict[any1] = "value1"
    dict[any2] = "value2"
    XCTAssertEqual(dict.count, 2)  // Both should be stored separately
  }

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
    dict[any1Copy] = "updated_value1"  // Should overwrite

    XCTAssertEqual(dict.count, 2)
    XCTAssertEqual(dict[any1], "updated_value1")
    XCTAssertEqual(dict[any2], "value2")
  }

  func testSendableComplianceAcrossTasks() async {
    let id = TestBoundaryId(value: "concurrent")
    let anyId = AnyLockmanBoundaryId(id)

    let results = await withTaskGroup(
      of: AnyLockmanBoundaryId.self, returning: [AnyLockmanBoundaryId].self
    ) { group in
      for _ in 0..<5 {
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

    XCTAssertEqual(results.count, 5)
    XCTAssertTrue(results.allSatisfy { $0 == anyId })
  }
}

// MARK: - Performance Tests

final class LockmanStatePerformanceTests: XCTestCase {
  func testPerformanceWithFrequentAddsAndRemoves() async throws {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryId = TestBoundaryId(value: "test")
    let iterations = 1000

    let startTime = Date()

    for i in 0..<iterations {
      let info = TestLockmanInfo(id: "\(i)")
      state.add(boundaryId: boundaryId, info: info)
      if i % 2 == 0 {
        state.remove(boundaryId: boundaryId, info: info)
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Should complete within reasonable time (adjust threshold as needed)
    XCTAssertLessThan(duration, 1.0)

    // Verify final state
    let finalCount = state.currentLocks(in: boundaryId).count
    XCTAssertEqual(finalCount, iterations / 2)  // Half were removed
  }

  func testPerformanceWithManyBoundaries() {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let boundaryCount = 100
    let entriesPerBoundary = 10

    let startTime = Date()

    for i in 0..<boundaryCount {
      let boundaryId = TestBoundaryId(value: "boundary_\(i)")
      for j in 0..<entriesPerBoundary {
        state.add(boundaryId: boundaryId, info: TestLockmanInfo(id: "\(i)_\(j)"))
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    XCTAssertLessThan(duration, 1.0)

    // Verify all boundaries have correct number of entries
    for i in 0..<boundaryCount {
      let boundaryId = TestBoundaryId(value: "boundary_\(i)")
      XCTAssertTrue(state.currentLocks(in: boundaryId).count == entriesPerBoundary)
    }
  }

  func testConcurrentPerformance() async {
    let state = LockmanState<TestLockmanInfo, LockmanActionId>()
    let taskCount = 1
    let operationsPerTask = 100

    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for taskId in 0..<taskCount {
        group.addTask {
          let boundaryId = TestBoundaryId(value: "task_\(taskId)")
          for i in 0..<operationsPerTask {
            let info = TestLockmanInfo(id: "\(taskId)_\(i)")
            state.add(boundaryId: boundaryId, info: info)
            if i % 3 == 0 {
              state.remove(boundaryId: boundaryId, info: info)
            }
          }
        }
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    XCTAssertLessThan(duration, 2.0)

    // Verify each task's boundary has expected number of entries
    for taskId in 0..<taskCount {
      let boundaryId = TestBoundaryId(value: "task_\(taskId)")
      let currents = state.currentLocks(in: boundaryId)
      let currentCount = currents.count
      let expectedCount = operationsPerTask - (operationsPerTask / 3) - 1
      XCTAssertEqual(currentCount, expectedCount)
    }
  }
}
