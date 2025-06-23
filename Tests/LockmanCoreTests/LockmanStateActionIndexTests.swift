import Foundation
import XCTest

@testable import Lockman

/// Tests for the new actionId-based index functionality in LockmanState
final class LockmanStateActionIndexTests: XCTestCase {
  // MARK: - Test Helpers

  private struct TestBoundaryId: LockmanBoundaryId {
    let value: String
  }

  private struct TestInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId: UUID

    init(actionId: LockmanActionId) {
      self.actionId = actionId
      self.uniqueId = UUID()
    }

    var debugDescription: String {
      "TestInfo(actionId: \(actionId))"
    }
  }

  // MARK: - Basic Functionality Tests

  func testContainsReturnsFalseForNonExistentAction() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    XCTAssertFalse(state.contains(id: boundary, actionId: "nonexistent"))
  }

  func testContainsReturnsTrueAfterAddingAction() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info)

    XCTAssertTrue(state.contains(id: boundary, actionId: "action1"))
    XCTAssertFalse(state.contains(id: boundary, actionId: "action2"))
  }

  func testContainsReturnsFalseAfterRemovingAction() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info)
    XCTAssertTrue(state.contains(id: boundary, actionId: "action1"))

    state.remove(id: boundary, info: info)
    XCTAssertFalse(state.contains(id: boundary, actionId: "action1"))
  }

  // MARK: - currents(id:actionId:) Tests

  func testCurrentsByActionIdReturnsEmptyForNonExistent() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let results = state.currents(id: boundary, actionId: "nonexistent")
    XCTAssertTrue(results.isEmpty)
  }

  func testCurrentsByActionIdReturnsMatchingLocks() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action2")
    let info3 = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    let action1Results = state.currents(id: boundary, actionId: "action1")
    let action2Results = state.currents(id: boundary, actionId: "action2")

    XCTAssertEqual(action1Results.count, 2)
    XCTAssertEqual(action2Results.count, 1)

    XCTAssertTrue(action1Results.map(\.uniqueId).contains(info1.uniqueId))
    XCTAssertTrue(action1Results.map(\.uniqueId).contains(info3.uniqueId))
    XCTAssertTrue(action2Results.map(\.uniqueId).contains(info2.uniqueId))
  }

  func testCurrentsByActionIdPreservesInsertionOrder() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    let results = state.currents(id: boundary, actionId: "action1")

    XCTAssertEqual(results.count, 3)
    XCTAssertEqual(results[0].uniqueId, info1.uniqueId)
    XCTAssertEqual(results[1].uniqueId, info2.uniqueId)
    XCTAssertEqual(results[2].uniqueId, info3.uniqueId)
  }

  // MARK: - Count Tests

  func testCountReturnsZeroForNonExistent() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    XCTAssertEqual(state.count(id: boundary, actionId: "nonexistent"), 0)
  }

  func testCountReturnsCorrectNumber() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action2")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    XCTAssertEqual(state.count(id: boundary, actionId: "action1"), 2)
    XCTAssertEqual(state.count(id: boundary, actionId: "action2"), 1)
    XCTAssertEqual(state.count(id: boundary, actionId: "action3"), 0)
  }

  // MARK: - ActionIds Tests

  func testActionIdsReturnsEmptyForEmptyBoundary() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let actionIds = state.actionIds(id: boundary)
    XCTAssertTrue(actionIds.isEmpty)
  }

  func testActionIdsReturnsAllUnique() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    state.add(id: boundary, info: TestInfo(actionId: "action1"))
    state.add(id: boundary, info: TestInfo(actionId: "action2"))
    state.add(id: boundary, info: TestInfo(actionId: "action1"))  // Duplicate
    state.add(id: boundary, info: TestInfo(actionId: "action3"))

    let actionIds = state.actionIds(id: boundary)

    XCTAssertEqual(actionIds.count, 3)
    XCTAssertTrue(actionIds.contains("action1"))
    XCTAssertTrue(actionIds.contains("action2"))
    XCTAssertTrue(actionIds.contains("action3"))
  }

  // MARK: - Boundary Isolation Tests

  func testActionsAreIsolatedBetweenBoundaries() async throws {
    let state = LockmanState<TestInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(id: boundary1, info: TestInfo(actionId: "action1"))
    state.add(id: boundary2, info: TestInfo(actionId: "action1"))

    XCTAssertTrue(state.contains(id: boundary1, actionId: "action1"))
    XCTAssertTrue(state.contains(id: boundary2, actionId: "action1"))

    state.removeAll(id: boundary1)

    XCTAssertFalse(state.contains(id: boundary1, actionId: "action1"))
    XCTAssertTrue(state.contains(id: boundary2, actionId: "action1"))
  }

  // MARK: - Performance Tests

  func testContainsPerformanceTest() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    // Add many different actions
    for i in 0..<1000 {
      state.add(id: boundary, info: TestInfo(actionId: "action\(i)"))
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    // Perform many lookups
    for i in 0..<1000 {
      _ = state.contains(id: boundary, actionId: "action\(i)")
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete very quickly for O(1) operations
    XCTAssertLessThan(executionTime, 0.01)  // Less than 10ms for 1000 lookups
  }

  // MARK: - Edge Cases

  func testHandlesEmptyActionIds() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info = TestInfo(actionId: "")
    state.add(id: boundary, info: info)

    XCTAssertTrue(state.contains(id: boundary, actionId: ""))
    XCTAssertEqual(state.count(id: boundary, actionId: ""), 1)
  }

  func testHandlesUnicodeActionIds() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let actionId = "🚀アクション💻"
    let info = TestInfo(actionId: actionId)
    state.add(id: boundary, info: info)

    XCTAssertTrue(state.contains(id: boundary, actionId: actionId))
    XCTAssertEqual(state.currents(id: boundary, actionId: actionId).count, 1)
  }

  // MARK: - Cleanup Tests

  func testRemoveAllClearsActionIndex() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    state.add(id: boundary, info: TestInfo(actionId: "action1"))
    state.add(id: boundary, info: TestInfo(actionId: "action2"))

    state.removeAll()

    XCTAssertFalse(state.contains(id: boundary, actionId: "action1"))
    XCTAssertFalse(state.contains(id: boundary, actionId: "action2"))
    XCTAssertTrue(state.actionIds(id: boundary).isEmpty)
  }

  func testRemoveAllWithBoundaryClearsBoundaryActionIndex() async throws {
    let state = LockmanState<TestInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(id: boundary1, info: TestInfo(actionId: "action1"))
    state.add(id: boundary2, info: TestInfo(actionId: "action1"))

    state.removeAll(id: boundary1)

    XCTAssertFalse(state.contains(id: boundary1, actionId: "action1"))
    XCTAssertTrue(state.contains(id: boundary2, actionId: "action1"))
  }

  // MARK: - removeAll(id:actionId:) Tests

  func testRemoveAllByActionId() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    // Add multiple locks with same actionId
    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action2")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    // Verify initial state
    XCTAssertEqual(state.count(id: boundary, actionId: "action1"), 2)
    XCTAssertEqual(state.count(id: boundary, actionId: "action2"), 1)

    // Remove all locks with actionId "action1"
    state.removeAll(id: boundary, actionId: "action1")

    // Verify removal
    XCTAssertEqual(state.count(id: boundary, actionId: "action1"), 0)
    XCTAssertFalse(state.contains(id: boundary, actionId: "action1"))
    XCTAssertEqual(state.count(id: boundary, actionId: "action2"), 1)
    XCTAssertTrue(state.contains(id: boundary, actionId: "action2"))
  }

  func testRemoveAllByActionIdEmptyCase() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    // Try to remove non-existent actionId
    state.removeAll(id: boundary, actionId: "nonexistent")

    // Should not crash and state should remain empty
    XCTAssertEqual(state.currents(id: boundary).count, 0)
  }

  func testRemoveAllByActionIdPreservesOtherActions() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    // Add locks with different actionIds
    state.add(id: boundary, info: TestInfo(actionId: "action1"))
    state.add(id: boundary, info: TestInfo(actionId: "action2"))
    state.add(id: boundary, info: TestInfo(actionId: "action3"))

    // Remove only action2
    state.removeAll(id: boundary, actionId: "action2")

    // Verify only action2 was removed
    XCTAssertTrue(state.contains(id: boundary, actionId: "action1"))
    XCTAssertFalse(state.contains(id: boundary, actionId: "action2"))
    XCTAssertTrue(state.contains(id: boundary, actionId: "action3"))
    XCTAssertEqual(state.currents(id: boundary).count, 2)
  }

  func testRemoveAllByActionIdMultipleBoundaries() async throws {
    let state = LockmanState<TestInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    // Add same actionId to different boundaries
    state.add(id: boundary1, info: TestInfo(actionId: "action1"))
    state.add(id: boundary2, info: TestInfo(actionId: "action1"))

    // Remove from boundary1 only
    state.removeAll(id: boundary1, actionId: "action1")

    // Verify isolation between boundaries
    XCTAssertFalse(state.contains(id: boundary1, actionId: "action1"))
    XCTAssertTrue(state.contains(id: boundary2, actionId: "action1"))
  }

  func testRemoveAllByActionIdConcurrent() async throws {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")
    let iterations = 100

    // Add many locks concurrently
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let actionId = "action\(i % 10)"  // 10 different action IDs
          state.add(id: boundary, info: TestInfo(actionId: actionId))
        }
      }
    }

    // Remove specific actionId concurrently with adds
    await withTaskGroup(of: Void.self) { group in
      // Remove action5
      group.addTask {
        state.removeAll(id: boundary, actionId: "action5")
      }

      // Add more action5 locks
      for _ in 0..<10 {
        group.addTask {
          state.add(id: boundary, info: TestInfo(actionId: "action5"))
        }
      }
    }

    // Verify state is consistent (action5 count depends on timing)
    let action5Count = state.count(id: boundary, actionId: "action5")
    XCTAssertTrue(action5Count >= 0 && action5Count <= 10)
  }
}
