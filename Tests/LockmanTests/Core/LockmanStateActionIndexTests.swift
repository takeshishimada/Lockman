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
    var strategyId: LockmanStrategyId { LockmanStrategyId(type: MockLockmanStrategy.self) }

    init(actionId: LockmanActionId) {
      self.actionId = actionId
      self.uniqueId = UUID()
    }

    var debugDescription: String {
      "TestInfo(actionId: \(actionId))"
    }
  }

  // Mock strategy type for the TestInfo
  private final class MockLockmanStrategy: LockmanStrategy {
    typealias I = TestInfo

    var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestInfo) -> LockmanResult { .success }
    func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestInfo) {}
    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  // MARK: - Basic Functionality Tests

  func testContainsReturnsFalseForNonExistentAction() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "nonexistent"))
  }

  func testContainsReturnsTrueAfterAddingAction() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(boundaryId: boundary, info: info)

    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: "action1"))
    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action2"))
  }

  func testContainsReturnsFalseAfterRemovingAction() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")
    let info = TestInfo(actionId: "action1")

    state.add(boundaryId: boundary, info: info)
    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: "action1"))

    state.remove(boundaryId: boundary, info: info)
    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action1"))
  }

  // MARK: - currents(id:actionId:) Tests

  func testCurrentsByActionIdReturnsEmptyForNonExistent() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let results = state.currentLocks(in: boundary, matching: "nonexistent")
    XCTAssertTrue(results.isEmpty)
  }

  func testCurrentsByActionIdReturnsMatchingLocks() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action2")
    let info3 = TestInfo(actionId: "action1")

    state.add(boundaryId: boundary, info: info1)
    state.add(boundaryId: boundary, info: info2)
    state.add(boundaryId: boundary, info: info3)

    let action1Results = state.currentLocks(in: boundary, matching: "action1")
    let action2Results = state.currentLocks(in: boundary, matching: "action2")

    XCTAssertEqual(action1Results.count, 2)
    XCTAssertEqual(action2Results.count, 1)

    XCTAssertTrue(action1Results.map(\.uniqueId).contains(info1.uniqueId))
    XCTAssertTrue(action1Results.map(\.uniqueId).contains(info3.uniqueId))
    XCTAssertTrue(action2Results.map(\.uniqueId).contains(info2.uniqueId))
  }

  func testCurrentsByActionIdPreservesInsertionOrder() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action1")

    state.add(boundaryId: boundary, info: info1)
    state.add(boundaryId: boundary, info: info2)
    state.add(boundaryId: boundary, info: info3)

    let results = state.currentLocks(in: boundary, matching: "action1")

    XCTAssertEqual(results.count, 3)
    XCTAssertEqual(results[0].uniqueId, info1.uniqueId)
    XCTAssertEqual(results[1].uniqueId, info2.uniqueId)
    XCTAssertEqual(results[2].uniqueId, info3.uniqueId)
  }

  // MARK: - Count Tests

  func testCountReturnsZeroForNonExistent() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "nonexistent"), 0)
  }

  func testCountReturnsCorrectNumber() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action2")

    state.add(boundaryId: boundary, info: info1)
    state.add(boundaryId: boundary, info: info2)
    state.add(boundaryId: boundary, info: info3)

    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action1"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action2"), 1)
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action3"), 0)
  }

  // MARK: - ActionIds Tests

  func testActionIdsReturnsEmptyForEmptyBoundary() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let actionIds = state.activeKeys(in: boundary)
    XCTAssertTrue(actionIds.isEmpty)
  }

  func testActionIdsReturnsAllUnique() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    state.add(boundaryId: boundary, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action2"))
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action1"))  // Duplicate
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action3"))

    let actionIds = state.activeKeys(in: boundary)

    XCTAssertEqual(actionIds.count, 3)
    XCTAssertTrue(actionIds.contains("action1"))
    XCTAssertTrue(actionIds.contains("action2"))
    XCTAssertTrue(actionIds.contains("action3"))
  }

  // MARK: - Boundary Isolation Tests

  func testActionsAreIsolatedBetweenBoundaries() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(boundaryId: boundary1, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "action1"))

    XCTAssertTrue(state.hasActiveLocks(in: boundary1, matching: "action1"))
    XCTAssertTrue(state.hasActiveLocks(in: boundary2, matching: "action1"))

    state.removeAll(boundaryId: boundary1)

    XCTAssertFalse(state.hasActiveLocks(in: boundary1, matching: "action1"))
    XCTAssertTrue(state.hasActiveLocks(in: boundary2, matching: "action1"))
  }

  // MARK: - Performance Tests

  func testContainsPerformanceTest() {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    // Add many different actions
    for i in 0..<1000 {
      state.add(boundaryId: boundary, info: TestInfo(actionId: "action\(i)"))
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    // Perform many lookups
    for i in 0..<1000 {
      _ = state.hasActiveLocks(in: boundary, matching: "action\(i)")
    }

    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime

    // Should complete very quickly for O(1) operations
    XCTAssertLessThan(executionTime, 0.01)  // Less than 10ms for 1000 lookups
  }

  // MARK: - Edge Cases

  func testHandlesEmptyActionIds() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let info = TestInfo(actionId: "")
    state.add(boundaryId: boundary, info: info)

    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: ""))
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: ""), 1)
  }

  func testHandlesUnicodeActionIds() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    let actionId = "🚀アクション💻"
    let info = TestInfo(actionId: actionId)
    state.add(boundaryId: boundary, info: info)

    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: actionId))
    XCTAssertEqual(state.currentLocks(in: boundary, matching: actionId).count, 1)
  }

  // MARK: - Cleanup Tests

  func testRemoveAllClearsActionIndex() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    state.add(boundaryId: boundary, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action2"))

    state.removeAll()

    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action1"))
    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action2"))
    XCTAssertTrue(state.activeKeys(in: boundary).isEmpty)
  }

  func testRemoveAllWithBoundaryClearsBoundaryActionIndex() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    state.add(boundaryId: boundary1, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "action1"))

    state.removeAll(boundaryId: boundary1)

    XCTAssertFalse(state.hasActiveLocks(in: boundary1, matching: "action1"))
    XCTAssertTrue(state.hasActiveLocks(in: boundary2, matching: "action1"))
  }

  // MARK: - removeAll(id:actionId:) Tests

  func testRemoveAllByActionId() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    // Add multiple locks with same actionId
    let info1 = TestInfo(actionId: "action1")
    let info2 = TestInfo(actionId: "action1")
    let info3 = TestInfo(actionId: "action2")

    state.add(boundaryId: boundary, info: info1)
    state.add(boundaryId: boundary, info: info2)
    state.add(boundaryId: boundary, info: info3)

    // Verify initial state
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action1"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action2"), 1)

    // Remove all locks with actionId "action1"
    state.removeAllLocks(in: boundary, matching: "action1")

    // Verify removal
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action1"), 0)
    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action1"))
    XCTAssertEqual(state.activeLockCount(in: boundary, matching: "action2"), 1)
    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: "action2"))
  }

  func testRemoveAllByActionIdEmptyCase() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    // Try to remove non-existent actionId
    state.removeAllLocks(in: boundary, matching: "nonexistent")

    // Should not crash and state should remain empty
    XCTAssertEqual(state.currentLocks(in: boundary).count, 0)
  }

  func testRemoveAllByActionIdPreservesOtherActions() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")

    // Add locks with different actionIds
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action2"))
    state.add(boundaryId: boundary, info: TestInfo(actionId: "action3"))

    // Remove only action2
    state.removeAllLocks(in: boundary, matching: "action2")

    // Verify only action2 was removed
    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: "action1"))
    XCTAssertFalse(state.hasActiveLocks(in: boundary, matching: "action2"))
    XCTAssertTrue(state.hasActiveLocks(in: boundary, matching: "action3"))
    XCTAssertEqual(state.currentLocks(in: boundary).count, 2)
  }

  func testRemoveAllByActionIdMultipleBoundaries() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary1 = TestBoundaryId(value: "boundary1")
    let boundary2 = TestBoundaryId(value: "boundary2")

    // Add same actionId to different boundaries
    state.add(boundaryId: boundary1, info: TestInfo(actionId: "action1"))
    state.add(boundaryId: boundary2, info: TestInfo(actionId: "action1"))

    // Remove from boundary1 only
    state.removeAllLocks(in: boundary1, matching: "action1")

    // Verify isolation between boundaries
    XCTAssertFalse(state.hasActiveLocks(in: boundary1, matching: "action1"))
    XCTAssertTrue(state.hasActiveLocks(in: boundary2, matching: "action1"))
  }

  func testRemoveAllByActionIdConcurrent() async throws {
    let state = LockmanState<TestInfo, LockmanActionId>()
    let boundary = TestBoundaryId(value: "test")
    let iterations = 100

    // Add many locks concurrently
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<iterations {
        group.addTask {
          let actionId = "action\(i % 10)"  // 10 different action IDs
          state.add(boundaryId: boundary, info: TestInfo(actionId: actionId))
        }
      }
    }

    // Remove specific actionId concurrently with adds
    await withTaskGroup(of: Void.self) { group in
      // Remove action5
      group.addTask {
        state.removeAllLocks(in: boundary, matching: "action5")
      }

      // Add more action5 locks
      for _ in 0..<10 {
        group.addTask {
          state.add(boundaryId: boundary, info: TestInfo(actionId: "action5"))
        }
      }
    }

    // Verify state is consistent (action5 count depends on timing)
    let action5Count = state.activeLockCount(in: boundary, matching: "action5")
    XCTAssertTrue(action5Count >= 0 && action5Count <= 10)
  }
}
