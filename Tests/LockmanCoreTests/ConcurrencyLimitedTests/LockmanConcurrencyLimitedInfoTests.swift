import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Concurrency Group

private enum TestConcurrencyGroup: LockmanConcurrencyGroup {
  case apiRequests
  case fileOperations

  var id: String {
    switch self {
    case .apiRequests: return "api_requests"
    case .fileOperations: return "file_operations"
    }
  }

  var limit: LockmanConcurrencyLimit {
    switch self {
    case .apiRequests: return .limited(3)
    case .fileOperations: return .limited(2)
    }
  }
}

// MARK: - LockmanConcurrencyLimitedInfo Tests

final class LockmanConcurrencyLimitedInfoTests: XCTestCase {
  // MARK: - Initialization Tests with Group

  func testInitializationWithGroup() {
    let group = TestConcurrencyGroup.apiRequests
    let info = LockmanConcurrencyLimitedInfo(actionId: "testAction", group: group)

    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.concurrencyId, "api_requests")
    XCTAssertEqual(info.limit, .limited(3))
    XCTAssertNotNil(info.uniqueId)
  }

  func testInitializationWithDifferentGroups() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action1", group: TestConcurrencyGroup.apiRequests)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action2", group: TestConcurrencyGroup.fileOperations)

    XCTAssertEqual(info1.concurrencyId, "api_requests")
    XCTAssertEqual(info1.limit, .limited(3))

    XCTAssertEqual(info2.concurrencyId, "file_operations")
    XCTAssertEqual(info2.limit, .limited(2))
  }

  // MARK: - Initialization Tests with Direct Limit

  func testInitializationWithDirectLimit() {
    let info = LockmanConcurrencyLimitedInfo(actionId: "testAction", .limited(5))

    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.concurrencyId, "testAction")  // actionId becomes concurrencyId
    XCTAssertEqual(info.limit, .limited(5))
    XCTAssertNotNil(info.uniqueId)
  }

  func testInitializationWithUnlimited() {
    let info = LockmanConcurrencyLimitedInfo(actionId: "unlimitedAction", .unlimited)

    XCTAssertEqual(info.actionId, "unlimitedAction")
    XCTAssertEqual(info.concurrencyId, "unlimitedAction")
    XCTAssertEqual(info.limit, .unlimited)
    XCTAssertNotNil(info.uniqueId)
  }

  // MARK: - Equatable Tests

  func testEqualityWithSameValues() {
    let group = TestConcurrencyGroup.apiRequests

    // Create two instances with same values but different UUIDs
    let info1 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)

    // They should NOT be equal because uniqueIds are different
    XCTAssertNotEqual(info1, info2)
  }

  func testInequalityWithDifferentActionIds() {
    let group = TestConcurrencyGroup.apiRequests
    let info1 = LockmanConcurrencyLimitedInfo(actionId: "action1", group: group)
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "action2", group: group)

    XCTAssertNotEqual(info1, info2)
  }

  func testInequalityWithDifferentConcurrencyIds() {
    let info1 = LockmanConcurrencyLimitedInfo(
      actionId: "action", group: TestConcurrencyGroup.apiRequests)
    let info2 = LockmanConcurrencyLimitedInfo(
      actionId: "action", group: TestConcurrencyGroup.fileOperations)

    XCTAssertNotEqual(info1, info2)
  }

  func testInequalityWithDifferentLimits() {
    let info1 = LockmanConcurrencyLimitedInfo(actionId: "action", .limited(3))
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "action", .limited(5))

    XCTAssertNotEqual(info1, info2)
  }

  func testInequalityWithDifferentUniqueIds() {
    let group = TestConcurrencyGroup.apiRequests
    let info1 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)

    // Different UUIDs
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertNotEqual(info1, info2)
  }

  // MARK: - Debug Description Tests

  func testDebugDescriptionWithGroup() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "testAction", group: TestConcurrencyGroup.apiRequests)
    let description = info.debugDescription

    XCTAssertTrue(description.contains("ConcurrencyLimitedInfo"))
    XCTAssertTrue(description.contains("actionId: testAction"))
    XCTAssertTrue(description.contains("concurrencyId: api_requests"))
    XCTAssertTrue(description.contains("limit: limited(3)"))
    XCTAssertTrue(description.contains("uniqueId:"))
  }

  func testDebugDescriptionWithUnlimited() {
    let info = LockmanConcurrencyLimitedInfo(actionId: "unlimitedAction", .unlimited)
    let description = info.debugDescription

    XCTAssertTrue(description.contains("ConcurrencyLimitedInfo"))
    XCTAssertTrue(description.contains("actionId: unlimitedAction"))
    XCTAssertTrue(description.contains("concurrencyId: unlimitedAction"))
    XCTAssertTrue(description.contains("limit: unlimited"))
  }

  // MARK: - LockmanInfo Protocol Tests

  func testConformsToLockmanInfo() {
    let info = LockmanConcurrencyLimitedInfo(actionId: "test", .limited(1))

    // Verify it can be used as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    XCTAssertEqual(lockmanInfo.actionId, "test")
    XCTAssertNotNil(lockmanInfo.uniqueId)
  }

  func testSendable() {
    // This test ensures the type is Sendable by using it in a concurrent context
    let info = LockmanConcurrencyLimitedInfo(actionId: "test", .limited(1))

    Task {
      let capturedInfo = info
      XCTAssertEqual(capturedInfo.actionId, "test")
    }
  }
}
