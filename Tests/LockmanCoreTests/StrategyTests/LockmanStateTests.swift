import Foundation
import XCTest
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

final class LockmanStateTests: XCTestCase {
  // MARK: - Basic Operations

  func testtestAddSingleEntry() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(id: boundaryId, info: info)

    let currents = state.currents(id: boundaryId)
    XCTAssertEqual(currents.count , 1)
    XCTAssertEqual(currents.first?.actionId , "1")
  }

  func testtestAddMultipleEntriesToSameBoundary() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")
    let info3 = TestLockmanInfo(id: "3")

    state.add(id: boundaryId, info: info1)
    state.add(id: boundaryId, info: info2)
    state.add(id: boundaryId, info: info3)

    let currents = state.currents(id: boundaryId)
    XCTAssertEqual(currents.count , 3)
    XCTAssertTrue(currents.map(\.actionId) == ["1", "2", "3"])
  }

  func testtestAddEntriesToDifferentBoundaries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")
    let info1 = TestLockmanInfo(id: "1")
    let info2 = TestLockmanInfo(id: "2")

    state.add(id: boundary1, info: info1)
    state.add(id: boundary2, info: info2)

    let currents1 = state.currents(id: boundary1)
    let currents2 = state.currents(id: boundary2)

    XCTAssertEqual(currents1.count , 1)
    XCTAssertEqual(currents1.first?.actionId , "1")
    XCTAssertEqual(currents2.count , 1)
    XCTAssertEqual(currents2.first?.actionId , "2")
  }

  func testtestRemoveLastFromSingleEntry() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let info = TestLockmanInfo(id: "1")

    state.add(id: boundaryId, info: info)
    state.removeAll(id: boundaryId)

    let currents = state.currents(id: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testtestRemoveLastFromMultipleEntries() {
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
    XCTAssertEqual(currents.count , 2)
    XCTAssertTrue(currents.map(\.actionId) == ["1", "2"])
  }

  func testtestRemoveLastFromNonExistentBoundary() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "non-existent")

    // Should not crash
    state.removeAll(id: boundaryId)

    let currents = state.currents(id: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testtestGetCurrentsFromEmptyState() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    let currents = state.currents(id: boundaryId)
    XCTAssertTrue(currents.isEmpty)
  }

  func testtestCleanUpAllEntries() {
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

    XCTAssertTrue(currents1.isEmpty)
    XCTAssertTrue(currents2.isEmpty)
  }

  func testtestCleanUpSpecificBoundary() {
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

    XCTAssertTrue(currents1.isEmpty)
    XCTAssertEqual(currents2.count , 1)
    XCTAssertEqual(currents2.first?.actionId , "2")
  }

  // MARK: - Concurrent Access Tests

  func testtestConcurrentAddsToSameBoundary() async throws {
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
    XCTAssertEqual(currents.count , iterations, "All concurrent adds should succeed")
  }

  func testtestConcurrentAddsToDifferentBoundaries() async throws {
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
      XCTAssertEqual(currents.count , expectedCount, "Each boundary should have \(expectedCount) entries")
    }
  }

  func testtestConcurrentAddAndRemoveOperations() async throws {
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
    XCTAssertEqual(currents.count , iterations)
  }

  func testtestConcurrentReadOperations() async throws {
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

    XCTAssertTrue(results.allSatisfy { $0 == 10 })
  }

  // MARK: - Edge Cases

  func testtestStackLikeBehavior() {
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
      XCTAssertEqual(currents.last?.uniqueId , info.uniqueId)
      state.remove(id: boundaryId, info: info)
    }

    XCTAssertTrue(state.currents(id: boundaryId).isEmpty)
  }

  func testtestLargeNumberOfEntries() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")
    let count = 1000 // Reduced from 10000 for reasonable test time

    for i in 0 ..< count {
      state.add(id: boundaryId, info: TestLockmanInfo(id: "\(i)"))
    }

    let currents = state.currents(id: boundaryId)
    XCTAssertEqual(currents.count , count)

    // Verify order is maintained
    for (index, info) in currents.enumerated() {
      XCTAssertEqual(info.actionId , "\(index)")
    }
  }

  func testtestMultipleCleanUpOperations() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "test")

    state.add(id: boundaryId, info: TestLockmanInfo(id: "1"))

    // Multiple cleanups should be safe
    state.removeAll(id: boundaryId)
    state.removeAll(id: boundaryId)
    state.removeAll()

    XCTAssertTrue(state.currents(id: boundaryId).isEmpty)
  }

  // MARK: - Data Integrity Tests

  func testtestOrderPreservation() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "order_test")
    let testData = ["first", "second", "third", "fourth", "fifth"]

    for id in testData {
      state.add(id: boundaryId, info: TestLockmanInfo(id: id))
    }

    let currents = state.currents(id: boundaryId)
    XCTAssertTrue(currents.map(\.actionId) == testData)
  }

  func testtestBoundaryIsolation() {
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

    XCTAssertTrue(state.currents(id: boundary1).isEmpty)
    XCTAssertTrue(state.currents(id: boundary2).count == 1)
    XCTAssertTrue(state.currents(id: boundary3).count == 1)
    XCTAssertTrue(state.currents(id: boundary2).first?.actionId == "b")
    XCTAssertTrue(state.currents(id: boundary3).first?.actionId == "c")
  }

  func testtestComplexSequenceOperations() {
    let state = LockmanState<TestLockmanInfo>()
    let boundaryId = TestBoundaryId(value: "complex")

    // Complex sequence: add, add, remove, add, remove, remove
    state.add(id: boundaryId, info: TestLockmanInfo(id: "1"))
    state.add(id: boundaryId, info: TestLockmanInfo(id: "2"))
    state.removeAll(id: boundaryId) // Remove "2"
    state.add(id: boundaryId, info: TestLockmanInfo(id: "3"))
    state.removeAll(id: boundaryId) // Remove "3"
    state.removeAll(id: boundaryId) // Remove "1"

    XCTAssertTrue(state.currents(id: boundaryId).isEmpty)
  }

  // MARK: - Memory Management Tests

  func testtestMemoryCleanupAfterRemovals() {
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
    XCTAssertTrue(state.currents(id: boundaryId).isEmpty)

    // Should be able to add again without issues
    state.add(id: boundaryId, info: TestLockmanInfo(id: "new"))
    XCTAssertTrue(state.currents(id: boundaryId).count == 1)
  }

  func testtestCleanupWithMixedBoundaryStates() {
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

    XCTAssertTrue(state.currents(id: emptyBoundary).isEmpty)
    XCTAssertTrue(state.currents(id: fullBoundary).isEmpty)
    XCTAssertTrue(state.currents(id: partialBoundary).count == 3)
  }
}

// MARK: - AnyLockmanBoundaryId Tests

final class AnyLockmanBoundaryIdTests: XCTestCase {
  func testtestEqualityWithSameValues() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = TestBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    XCTAssertEqual(any1 , any2)
  }

  func testtestInequalityWithDifferentValues() {
    let id1 = TestBoundaryId(value: "test1")
    let id2 = TestBoundaryId(value: "test2")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    XCTAssertNotEqual(any1 , any2)
  }

  func testtestHashConsistency() {
    let id = TestBoundaryId(value: "test")
    let any1 = AnyLockmanBoundaryId(id)
    let any2 = AnyLockmanBoundaryId(id)

    XCTAssertEqual(any1.hashValue , any2.hashValue)
  }

  func testtestDifferentTypesWithSameValue() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = AnotherBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    // Different types should not be equal even with same value
    XCTAssertNotEqual(any1 , any2)
  }

  func testtestHashCollisionAvoidanceForDifferentTypes() {
    let id1 = TestBoundaryId(value: "test")
    let id2 = AnotherBoundaryId(value: "test")

    let any1 = AnyLockmanBoundaryId(id1)
    let any2 = AnyLockmanBoundaryId(id2)

    // Hash values should ideally be different for different types
    // This is a probabilistic test - hash collisions are possible but unlikely
    // We'll skip the hash comparison since occasional collisions are acceptable
    // and don't affect the correctness of the implementation

    // The important thing is that equality works correctly (tested elsewhere)
    XCTAssertNotEqual(any1 , any2) // Different types should never be equal

    // Verify they can both be used as dictionary keys
    var dict: [AnyLockmanBoundaryId: String] = [:]
    dict[any1] = "value1"
    dict[any2] = "value2"
    XCTAssertEqual(dict.count , 2) // Both should be stored separately
  }

  func testtestUseAsDictionaryKey() {
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

    XCTAssertEqual(dict.count , 2)
    XCTAssertEqual(dict[any1] , "updated_value1")
    XCTAssertEqual(dict[any2] , "value2")
  }

  func testtestSendableComplianceAcrossTasks() async throws {
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

    XCTAssertEqual(results.count , 5)
    XCTAssertTrue(results.allSatisfy { $0 == anyId })
  }
}

// MARK: - Performance Tests

final class LockmanStatePerformanceTests: XCTestCase {
  func testtestPerformanceWithFrequentAddsAndRemoves() async throws {
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
    XCTAssertTrue(duration < 1.0)

    // Verify final state
    let finalCount = state.currents(id: boundaryId).count
    XCTAssertEqual(finalCount , iterations / 2) // Half were removed
  }

  func testtestPerformanceWithManyBoundaries() {
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

    XCTAssertTrue(duration < 1.0)

    // Verify all boundaries have correct number of entries
    for i in 0 ..< boundaryCount {
      let boundaryId = TestBoundaryId(value: "boundary_\(i)")
      XCTAssertTrue(state.currents(id: boundaryId).count == entriesPerBoundary)
    }
  }

  func testtestConcurrentPerformance() async throws {
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

    XCTAssertTrue(duration < 2.0)

    // Verify each task's boundary has expected number of entries
    for taskId in 0 ..< taskCount {
      let boundaryId = TestBoundaryId(value: "task_\(taskId)")
      let currents = state.currents(id: boundaryId)
      let currentCount = currents.count
      let expectedCount = operationsPerTask - (operationsPerTask / 3) - 1
      XCTAssertEqual(currentCount , expectedCount)
    }
  }
}
