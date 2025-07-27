import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Helpers

private struct TestConcurrencyGroup: LockmanConcurrencyGroup {
  let id: String
  let limit: LockmanConcurrencyLimit
}

final class LockmanConcurrencyLimitedInfoTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitializeWithConcurrencyGroup() {
    let group = TestConcurrencyGroup(id: "testGroup", limit: .limited(3))
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "testAction",
      group: group
    )

    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.concurrencyId, "testGroup")
    XCTAssertEqual(info.limit, .limited(3))
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  func testInitializeWithDirectLimit() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "downloadAction",
      .limited(5)
    )

    XCTAssertEqual(info.actionId, "downloadAction")
    XCTAssertEqual(info.concurrencyId, "downloadAction")  // Uses actionId as concurrencyId
    XCTAssertEqual(info.limit, .limited(5))
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  // MARK: - Cancellation Target Tests

  func testIsCancellationTargetAlwaysTrue() {
    let testCases: [(LockmanConcurrencyLimit, String)] = [
      (.limited(1), "limited 1"),
      (.limited(10), "limited 10"),
      (.unlimited, "unlimited"),
    ]

    for (limit, description) in testCases {
      let info = LockmanConcurrencyLimitedInfo(
        actionId: "test_\(description)",
        limit
      )
      XCTAssertTrue(info.isCancellationTarget, "\(description) should be cancellation target")
    }
  }

  func testIsCancellationTargetWithDifferentGroups() {
    let group1 = TestConcurrencyGroup(id: "downloads", limit: .limited(3))
    let group2 = TestConcurrencyGroup(id: "uploads", limit: .unlimited)

    let downloadInfo = LockmanConcurrencyLimitedInfo(
      actionId: "download",
      group: group1
    )
    let uploadInfo = LockmanConcurrencyLimitedInfo(
      actionId: "upload",
      group: group2
    )

    XCTAssertTrue(
      downloadInfo.isCancellationTarget, "Download action should be cancellation target")
    XCTAssertTrue(uploadInfo.isCancellationTarget, "Upload action should be cancellation target")
  }

  // MARK: - Equality Tests

  func testEqualityBasedOnUniqueId() {
    let group = TestConcurrencyGroup(id: "test", limit: .limited(1))
    let info1 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)
    let info2 = LockmanConcurrencyLimitedInfo(actionId: "action", group: group)

    // Same instance equals itself
    XCTAssertEqual(info1, info1)

    // Different instances with same properties are not equal (due to unique UUID)
    XCTAssertNotEqual(info1, info2)
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info1.concurrencyId, info2.concurrencyId)
    XCTAssertEqual(info1.limit, info2.limit)
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanInfoProtocolConformance() {
    let info = LockmanConcurrencyLimitedInfo(
      actionId: "protocolTest",
      .limited(2)
    )

    // Should work as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    XCTAssertEqual(lockmanInfo.actionId, "protocolTest")
    XCTAssertEqual(lockmanInfo.uniqueId, info.uniqueId)
    XCTAssertTrue(lockmanInfo.isCancellationTarget)
  }
}
