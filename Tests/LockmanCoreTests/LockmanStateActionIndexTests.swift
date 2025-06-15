import Foundation
import Testing
@testable import LockmanCore

/// Tests for the new actionId-based index functionality in LockmanState
@Suite("LockmanState ActionId Index Tests")
struct LockmanStateActionIndexTests {
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

  @Test("Contains returns false for non-existent action")
  func containsReturnsFalseForNonExistentAction() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    #expect(!state.contains(id: boundary, actionId: "nonexistent"))
  }

  @Test("Contains returns true after adding action")
  func containsReturnsTrueAfterAddingAction() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info)

    #expect(state.contains(id: boundary, actionId: "action1"))
    #expect(!state.contains(id: boundary, actionId: "action2"))
  }

  @Test("Contains returns false after removing action")
  func containsReturnsFalseAfterRemovingAction() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info)
    #expect(state.contains(id: boundary, actionId: "action1"))

    state.remove(id: boundary, info: info)
    #expect(!state.contains(id: boundary, actionId: "action1"))
  }

  // MARK: - currents(id:actionId:) Tests

  @Test("Currents by actionId returns empty for non-existent action")
  func currentsByActionIdReturnsEmptyForNonExistent() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let results = state.currents(id: boundary, actionId: "nonexistent")
    #expect(results.isEmpty)
  }

  @Test("Currents by actionId returns matching locks")
  func currentsByActionIdReturnsMatchingLocks() {
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

    #expect(action1Results.count == 2)
    #expect(action2Results.count == 1)

    #expect(action1Results.map(\.uniqueId).contains(info1.uniqueId))
    #expect(action1Results.map(\.uniqueId).contains(info3.uniqueId))
    #expect(action2Results.map(\.uniqueId).contains(info2.uniqueId))
  }

  @Test("Currents by actionId preserves insertion order")
  func currentsByActionIdPreservesInsertionOrder() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action1")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    let results = state.currents(id: boundary, actionId: "action1")

    #expect(results.count == 3)
    #expect(results[0].uniqueId == info1.uniqueId)
    #expect(results[1].uniqueId == info2.uniqueId)
    #expect(results[2].uniqueId == info3.uniqueId)
  }

  // MARK: - Count Tests

  @Test("Count returns zero for non-existent action")
  func countReturnsZeroForNonExistent() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    #expect(state.count(id: boundary, actionId: "nonexistent") == 0)
  }

  @Test("Count returns correct number of locks")
  func countReturnsCorrectNumber() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action2")

    state.add(id: boundary, info: info1)
    state.add(id: boundary, info: info2)
    state.add(id: boundary, info: info3)

    #expect(state.count(id: boundary, actionId: "action1") == 2)
    #expect(state.count(id: boundary, actionId: "action2") == 1)
    #expect(state.count(id: boundary, actionId: "action3") == 0)
  }

  // MARK: - ActionIds Tests

  @Test("ActionIds returns empty set for empty boundary")
  func actionIdsReturnsEmptyForEmptyBoundary() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let actionIds = state.actionIds(id: boundary)
    #expect(actionIds.isEmpty)
  }

  @Test("ActionIds returns all unique action IDs")
  func actionIdsReturnsAllUnique() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    state.add(id: boundary, info: TestInfo(actionId: "action1"))
    state.add(id: boundary, info: TestInfo(actionId: "action2"))
    state.add(id: boundary, info: TestInfo(actionId: "action1")) // Duplicate
    state.add(id: boundary, info: TestInfo(actionId: "action3"))

    let actionIds = state.actionIds(id: boundary)

    #expect(actionIds.count == 3)
    #expect(actionIds.contains("action1"))
    #expect(actionIds.contains("action2"))
    #expect(actionIds.contains("action3"))
  }

  // MARK: - Boundary Isolation Tests

  @Test("Actions are isolated between boundaries")
  func actionsAreIsolatedBetweenBoundaries() {
    let state = LockmanState<TestInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(id: boundary1, info: TestInfo(actionId: "action1"))
    state.add(id: boundary2, info: TestInfo(actionId: "action1"))

    #expect(state.contains(id: boundary1, actionId: "action1"))
    #expect(state.contains(id: boundary2, actionId: "action1"))

    state.removeAll(id: boundary1)

    #expect(!state.contains(id: boundary1, actionId: "action1"))
    #expect(state.contains(id: boundary2, actionId: "action1"))
  }

  // MARK: - Performance Tests

  @Test("Contains performs in O(1) time")
  func containsPerformanceTest() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    // Add many different actions
    for i in 0 ..< 1000 {
      state.add(id: boundary, info: TestInfo(actionId: "action\(i)"))
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    // Perform many lookups
    for i in 0 ..< 1000 {
      _ = state.contains(id: boundary, actionId: "action\(i)")
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete very quickly for O(1) operations
    #expect(executionTime < 0.01) // Less than 10ms for 1000 lookups
  }

  // MARK: - Edge Cases

  @Test("Handles empty action IDs")
  func handlesEmptyActionIds() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let info = TestInfo(actionId: "")
    state.add(id: boundary, info: info)

    #expect(state.contains(id: boundary, actionId: ""))
    #expect(state.count(id: boundary, actionId: "") == 1)
  }

  @Test("Handles unicode action IDs")
  func handlesUnicodeActionIds() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    let actionId = "🚀アクション💻"
    let info = TestInfo(actionId: actionId)
    state.add(id: boundary, info: info)

    #expect(state.contains(id: boundary, actionId: actionId))
    #expect(state.currents(id: boundary, actionId: actionId).count == 1)
  }

  // MARK: - Cleanup Tests

  @Test("RemoveAll clears action index")
  func removeAllClearsActionIndex() {
    let state = LockmanState<TestInfo>()
    let boundary = TestBoundaryId(value: "test")

    state.add(id: boundary, info: TestInfo(actionId: "action1"))
    state.add(id: boundary, info: TestInfo(actionId: "action2"))

    state.removeAll()

    #expect(!state.contains(id: boundary, actionId: "action1"))
    #expect(!state.contains(id: boundary, actionId: "action2"))
    #expect(state.actionIds(id: boundary).isEmpty)
  }

  @Test("RemoveAll with boundary clears boundary action index")
  func removeAllWithBoundaryClearsBoundaryActionIndex() {
    let state = LockmanState<TestInfo>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(id: boundary1, info: TestInfo(actionId: "action1"))
    state.add(id: boundary2, info: TestInfo(actionId: "action1"))

    state.removeAll(id: boundary1)

    #expect(!state.contains(id: boundary1, actionId: "action1"))
    #expect(state.contains(id: boundary2, actionId: "action1"))
  }
}
