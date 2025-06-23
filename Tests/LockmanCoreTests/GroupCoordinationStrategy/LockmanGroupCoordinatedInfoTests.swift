import Foundation
import XCTest

@testable import Lockman

/// Tests for LockmanGroupCoordinatedInfo
final class LockmanGroupCoordinatedInfoTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitializeWithLockmanActionId() {
    let actionId = LockmanActionId("testAction")
    let info = LockmanGroupCoordinatedInfo(
      actionId: actionId,
      groupId: "testGroup",
      coordinationRole: .none
    )

    XCTAssertEqual(info.actionId, actionId)
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("testGroup")])
    XCTAssertEqual(info.coordinationRole, .none)
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  func testInitializeWithStringActionId() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId, "testAction")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("testGroup")])
    XCTAssertEqual(info.coordinationRole, .member)
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  func testEachInstanceHasUniqueId() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .none
    )

    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .none
    )

    // Same properties but different unique IDs
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info1.groupIds, info2.groupIds)
    XCTAssertEqual(info1.coordinationRole, info2.coordinationRole)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  // MARK: - GroupCoordinationRole Tests

  func testGroupCoordinationRoleValues() {
    let noneRole = GroupCoordinationRole.none
    let exclusiveLeader = GroupCoordinationRole.leader(.emptyGroup)
    let member = GroupCoordinationRole.member

    // Test pattern matching
    if case .none = noneRole {
      // Success
    } else {
      XCTFail("Should be none")
    }

    if case .leader(let policy) = exclusiveLeader {
      XCTAssertEqual(policy, .emptyGroup)
    } else {
      XCTFail("Should be leader")
    }

    if case .member = member {
      // Success
    } else {
      XCTFail("Should be member")
    }
  }

  func testGroupCoordinationRoleIsSendableAndHashable() {
    let roles: Set<GroupCoordinationRole> = [
      .none,
      .member,
      .none,
      .leader(.emptyGroup),
    ]
    XCTAssertEqual(roles.count, 3)  // Duplicate .none removed

    // Can be used in dictionaries
    let roleMap: [GroupCoordinationRole: String] = [
      .none: "Start",
      .leader(.emptyGroup): "ExclusiveStart",
      .member: "Join",
    ]
    XCTAssertEqual(roleMap[.none], "Start")
    XCTAssertEqual(roleMap[.leader(.emptyGroup)], "ExclusiveStart")
    XCTAssertEqual(roleMap[.member], "Join")
  }

  // MARK: - Equatable Tests

  func testEqualityBasedOnUniqueIdOnly() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .none
    )

    // Same instance equals itself
    XCTAssertEqual(info1, info1)

    // Different instance with same properties is not equal
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .none
    )
    XCTAssertNotEqual(info1, info2)

    // Different properties but would never have same uniqueId
    let info3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group2",
      coordinationRole: .member
    )
    XCTAssertNotEqual(info1, info3)
  }

  func testArrayOperationsWithEquality() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .none
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .none
    )

    let array = [info1, info2, info1]

    // Contains checks
    XCTAssertTrue(array.contains(info1))
    XCTAssertTrue(array.contains(info2))

    // First index
    XCTAssertTrue(array.firstIndex(of: info1) == 0)
    XCTAssertTrue(array.firstIndex(of: info2) == 1)

    // Filter
    let filtered = array.filter { $0 == info1 }
    XCTAssertEqual(filtered.count, 2)  // info1 appears twice
  }

  // MARK: - LockmanInfo Protocol Tests

  func testConformsToLockmanInfoProtocol() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupId: "group",
      coordinationRole: .member
    )

    // Can be used as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    XCTAssertEqual(lockmanInfo.actionId, "test")
    XCTAssertEqual(lockmanInfo.uniqueId, info.uniqueId)
  }

  // MARK: - Edge Cases

  func testEmptyStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(""),
      groupId: "",
      coordinationRole: .none
    )

    XCTAssertEqual(info.actionId, "")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("")])
    XCTAssertEqual(info.coordinationRole, .none)
  }

  func testSpecialCharactersInStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action@#$%^&*()"),
      groupId: "group-with-特殊文字-🔒",
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId, "action@#$%^&*()")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("group-with-特殊文字-🔒")])
  }

  func testVeryLongStrings() {
    let longString = String(repeating: "x", count: 1000)
    let info = LockmanGroupCoordinatedInfo(
      actionId: longString,
      groupId: longString,
      coordinationRole: .none
    )

    XCTAssertEqual(info.actionId, longString)
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId(longString)])
  }

  // MARK: - Sendable Conformance

  func testSendableAcrossConcurrentContexts() async {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("concurrent-test"),
      groupId: "test",
      coordinationRole: .none
    )

    await withTaskGroup(of: String.self) { group in
      for i in 0..<10 {
        group.addTask {
          // Can safely access info properties
          "\(i): \(info.actionId)-\(info.groupIds.first!)"
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 10)
      XCTAssertTrue(results.allSatisfy { $0.contains("concurrent-test") })
    }
  }

  // MARK: - Multiple Groups Tests

  func testInitializeWithMultipleGroups() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multi"),
      groupIds: ["group1", "group2", "group3"],
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId, "multi")
    XCTAssertEqual(
      info.groupIds,
      [AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2"), AnyLockmanGroupId("group3")])
    XCTAssertEqual(info.coordinationRole, .member)
  }
}
