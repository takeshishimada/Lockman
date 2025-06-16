import Foundation
import XCTest
@testable import LockmanCore

/// Tests for LockmanGroupCoordinatedInfo
final class LockmanGroupCoordinatedInfoTests: XCTestCase {
  // MARK: - Initialization Tests

  func testtestInitializeWithLockmanActionId() {
    let actionId = LockmanActionId("testAction")
    let info = LockmanGroupCoordinatedInfo(
      actionId: actionId,
      groupId: "testGroup",
      coordinationRole: .leader
    )

    XCTAssertEqual(info.actionId , actionId)
    XCTAssertEqual(info.groupIds , ["testGroup"])
    XCTAssertEqual(info.coordinationRole , .leader)
    XCTAssertNotEqual(info.uniqueId , UUID())
  }

  func testtestInitializeWithStringActionId() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId , "testAction")
    XCTAssertEqual(info.groupIds , ["testGroup"])
    XCTAssertEqual(info.coordinationRole , .member)
    XCTAssertNotEqual(info.uniqueId , UUID())
  }

  func testtestEachInstanceHasUniqueId() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .leader
    )

    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .leader
    )

    // Same properties but different unique IDs
    XCTAssertEqual(info1.actionId , info2.actionId)
    XCTAssertEqual(info1.groupIds , info2.groupIds)
    XCTAssertEqual(info1.coordinationRole , info2.coordinationRole)
    XCTAssertNotEqual(info1.uniqueId , info2.uniqueId)
  }

  // MARK: - GroupCoordinationRole Tests

  func testtestGroupCoordinationRoleValues() {
    let leader = GroupCoordinationRole.leader
    let member = GroupCoordinationRole.member

    XCTAssertEqual(leader.rawValue , "leader")
    XCTAssertEqual(member.rawValue , "member")

    // All cases
    XCTAssertEqual(GroupCoordinationRole.allCases.count , 2)
    XCTAssertTrue(GroupCoordinationRole.allCases.contains(.leader))
    XCTAssertTrue(GroupCoordinationRole.allCases.contains(.member))
  }

  func testtestGroupCoordinationRoleIsSendableAndHashable() {
    let roles: Set<GroupCoordinationRole> = [.leader, .member, .leader]
    XCTAssertEqual(roles.count , 2) // Duplicate .leader removed

    // Can be used in dictionaries
    let roleMap: [GroupCoordinationRole: String] = [
      .leader: "Start",
      .member: "Join",
    ]
    XCTAssertEqual(roleMap[.leader] , "Start")
    XCTAssertEqual(roleMap[.member] , "Join")
  }

  // MARK: - Equatable Tests

  func testtestEqualityBasedOnUniqueIdOnly() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader
    )

    // Same instance equals itself
    XCTAssertEqual(info1 , info1)

    // Different instance with same properties is not equal
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    XCTAssertNotEqual(info1 , info2)

    // Different properties but would never have same uniqueId
    let info3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group2",
      coordinationRole: .member
    )
    XCTAssertNotEqual(info1 , info3)
  }

  func testtestArrayOperationsWithEquality() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .leader
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action"),
      groupId: "group",
      coordinationRole: .leader
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
    XCTAssertEqual(filtered.count , 2) // info1 appears twice
  }

  // MARK: - LockmanInfo Protocol Tests

  func testtestConformsToLockmanInfoProtocol() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupId: "group",
      coordinationRole: .member
    )

    // Can be used as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    XCTAssertEqual(lockmanInfo.actionId , "test")
    XCTAssertEqual(lockmanInfo.uniqueId , info.uniqueId)
  }

  // MARK: - Edge Cases

  func testtestEmptyStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(""),
      groupId: "",
      coordinationRole: .leader
    )

    XCTAssertEqual(info.actionId , "")
    XCTAssertEqual(info.groupIds , [""])
    XCTAssertEqual(info.coordinationRole , .leader)
  }

  func testtestSpecialCharactersInStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action@#$%^&*()"),
      groupId: "group-with-特殊文字-🔒",
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId , "action@#$%^&*()")
    XCTAssertEqual(info.groupIds , ["group-with-特殊文字-🔒"])
  }

  func testtestVeryLongStrings() {
    let longString = String(repeating: "x", count: 1000)
    let info = LockmanGroupCoordinatedInfo(
      actionId: longString,
      groupId: longString,
      coordinationRole: .leader
    )

    XCTAssertEqual(info.actionId , longString)
    XCTAssertEqual(info.groupIds , [longString])
  }

  // MARK: - Sendable Conformance

  func testtestSendableAcrossConcurrentContexts() async throws {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("concurrent"),
      groupId: "test",
      coordinationRole: .leader
    )

    await withTaskGroup(of: String.self) { group in
      for i in 0 ..< 10 {
        group.addTask {
          // Can safely access info properties
          "\(i): \(info.actionId)-\(info.groupIds.first!)-\(info.coordinationRole.rawValue)"
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count , 10)
      XCTAssertTrue(results.allSatisfy { $0.contains("concurrent-test-leader") })
    }
  }

  // MARK: - Multiple Groups Tests

  func testtestInitializeWithMultipleGroups() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multi"),
      groupIds: ["group1", "group2", "group3"],
      coordinationRole: .member
    )

    XCTAssertEqual(info.actionId , "multi")
    XCTAssertEqual(info.groupIds , ["group1", "group2", "group3"])
    XCTAssertEqual(info.coordinationRole , .member)
  }
}
