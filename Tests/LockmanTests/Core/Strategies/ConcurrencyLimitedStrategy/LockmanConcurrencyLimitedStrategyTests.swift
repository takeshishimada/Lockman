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

private enum TestConcurrencyGroup: LockmanConcurrencyGroup {
  case apiRequests
  case fileOperations
  case uiUpdates

  var id: String {
    switch self {
    case .apiRequests: return "api_requests"
    case .fileOperations: return "file_operations"
    case .uiUpdates: return "ui_updates"
    }
  }

  var limit: LockmanConcurrencyLimit {
    switch self {
    case .apiRequests: return .limited(3)
    case .fileOperations: return .limited(2)
    case .uiUpdates: return .unlimited
    }
  }
}

// MARK: - LockmanConcurrencyLimitedStrategy Tests

final class LockmanConcurrencyLimitedStrategyTests: XCTestCase {
  // MARK: - Initialization Tests

  func testSharedInstanceIsSingleton() {
    let instance1 = LockmanConcurrencyLimitedStrategy.shared
    let instance2 = LockmanConcurrencyLimitedStrategy.shared

    XCTAssertTrue(instance1 === instance2)
  }

  func testMakeStrategyIdReturnsConsistentIdentifier() {
    let id1 = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    let id2 = LockmanConcurrencyLimitedStrategy.makeStrategyId()

    XCTAssertEqual(id1, id2)
  }

  func testInstanceStrategyIdMatchesMakeStrategyId() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let staticId = LockmanConcurrencyLimitedStrategy.makeStrategyId()

    XCTAssertEqual(strategy.strategyId, staticId)
  }

  // MARK: - Basic Lock Behavior Tests with Groups

  func testFirstLockSucceedsWithGroup() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "action", group: TestConcurrencyGroup.apiRequests)

    let result = strategy.canLock(boundaryId: boundary, info: info)
    XCTAssertEqual(result, .success)

    strategy.cleanUp(boundaryId: boundary)
  }

  func testMultipleLocksWithinLimitSucceed() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // API requests allow 3 concurrent
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1", group: TestConcurrencyGroup.apiRequests)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2", group: TestConcurrencyGroup.apiRequests)
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: "action3", group: TestConcurrencyGroup.apiRequests)

    // All three should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info1), .success)
    strategy.lock(boundaryId: boundary, info: info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info2), .success)
    strategy.lock(boundaryId: boundary, info: info2)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info3), .success)
    strategy.lock(boundaryId: boundary, info: info3)

    strategy.cleanUp(boundaryId: boundary)
  }

  func testLockFailsWhenLimitExceeded() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // File operations allow 2 concurrent
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "upload1", group: TestConcurrencyGroup.fileOperations)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "upload2", group: TestConcurrencyGroup.fileOperations)
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: "upload3", group: TestConcurrencyGroup.fileOperations)

    // First two should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info1), .success)
    strategy.lock(boundaryId: boundary, info: info1)

    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info2), .success)
    strategy.lock(boundaryId: boundary, info: info2)

    // Third should fail
    let result = strategy.canLock(boundaryId: boundary, info: info3)
    XCTAssertLockFailure(result)

    if case .cancel(let error) = result,
      let concurrencyError = error as? LockmanConcurrencyLimitedError
    {
      switch concurrencyError {
      case .concurrencyLimitReached(let lockmanInfo, let boundaryId, let currentCount):
        XCTAssertEqual(lockmanInfo.concurrencyId, "file_operations")
        XCTAssertEqual(lockmanInfo.actionId, "upload3")
        XCTAssertEqual(currentCount, 2)
        XCTAssertNotNil(boundaryId)
      }
    } else {
      XCTFail("Expected LockmanConcurrencyLimitedError")
    }

    strategy.cleanUp(boundaryId: boundary)
  }

  func testUnlimitedGroupAllowsManyLocks() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // UI updates are unlimited
    for i in 0..<100 {
      let info = LockmanConcurrencyLimitedInfo(
        actionId: "ui\(i)", group: TestConcurrencyGroup.uiUpdates)
      XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info), .success)
      strategy.lock(boundaryId: boundary, info: info)
    }

    strategy.cleanUp(boundaryId: boundary)
  }

  // MARK: - Direct Limit Tests

  func testDirectLimitedConfiguration() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    let info1 = LockmanConcurrencyLimitedInfo(actionId: "special1", .limited(1))
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "special1", .limited(1))

    // First should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info1), .success)
    strategy.lock(boundaryId: boundary, info: info1)

    // Second with same actionId should fail (limit is 1)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary, info: info2))

    strategy.cleanUp(boundaryId: boundary)
  }

  func testDirectUnlimitedConfiguration() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // Multiple locks with same actionId and unlimited
    for _ in 0..<50 {
      let info = LockmanConcurrencyLimitedInfo(actionId: "unlimited-action", .unlimited)
      XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info), .success)
      strategy.lock(boundaryId: boundary, info: info)
    }

    strategy.cleanUp(boundaryId: boundary)
  }

  // MARK: - Cross-Boundary Tests

  func testDifferentBoundariesHaveIndependentLimits() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")

    // File operations allow 2 concurrent per boundary
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "upload1", group: TestConcurrencyGroup.fileOperations)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "upload2", group: TestConcurrencyGroup.fileOperations)
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: "upload3", group: TestConcurrencyGroup.fileOperations)

    // Fill boundary1 to limit
    strategy.lock(boundaryId: boundary1, info: info1)
    strategy.lock(boundaryId: boundary1, info: info2)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary1, info: info3))

    // boundary2 should still allow locks
    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info1), .success)
    strategy.lock(boundaryId: boundary2, info: info1)
    XCTAssertEqual(strategy.canLock(boundaryId: boundary2, info: info2), .success)

    strategy.cleanUp(boundaryId: boundary1)
    strategy.cleanUp(boundaryId: boundary2)
  }

  // MARK: - Unlock Behavior Tests

  func testUnlockFreesSlot() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // File operations allow 2 concurrent
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "upload1", group: TestConcurrencyGroup.fileOperations)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "upload2", group: TestConcurrencyGroup.fileOperations)
    let info3 = LockmanConcurrencyLimitedInfo(
      actionId: "upload3", group: TestConcurrencyGroup.fileOperations)

    // Fill to limit
    strategy.lock(boundaryId: boundary, info: info1)
    strategy.lock(boundaryId: boundary, info: info2)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundary, info: info3))

    // Unlock one
    strategy.unlock(boundaryId: boundary, info: info1)

    // Now third should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info3), .success)

    strategy.cleanUp(boundaryId: boundary)
  }

  // MARK: - CleanUp Tests

  func testCleanUpRemovesAllLocksForBoundary() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // Add multiple locks
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1", group: TestConcurrencyGroup.apiRequests)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2", group: TestConcurrencyGroup.apiRequests)

    strategy.lock(boundaryId: boundary, info: info1)
    strategy.lock(boundaryId: boundary, info: info2)

    // Clean up
    strategy.cleanUp(boundaryId: boundary)

    // Should be able to lock again
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info1), .success)
    XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info2), .success)
  }

  // MARK: - GetCurrentLocks Tests

  func testGetCurrentLocksReturnsCorrectLocks() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1", group: TestConcurrencyGroup.apiRequests)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2", group: TestConcurrencyGroup.fileOperations)

    strategy.lock(boundaryId: boundary, info: info1)
    strategy.lock(boundaryId: boundary, info: info2)

    let allLocks = strategy.getCurrentLocks()
    let locks = allLocks[AnyLockmanBoundaryId(boundary)] ?? []
    XCTAssertEqual(locks.count, 2)

    let actionIds = locks.compactMap { ($0 as? LockmanConcurrencyLimitedInfo)?.actionId }.sorted()
    XCTAssertEqual(actionIds, ["action1", "action2"])

    strategy.cleanUp(boundaryId: boundary)
  }
}
