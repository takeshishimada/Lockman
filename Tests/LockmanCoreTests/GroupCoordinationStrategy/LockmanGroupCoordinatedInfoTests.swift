import Foundation
import Testing
@testable import LockmanCore

/// Tests for LockmanGroupCoordinatedInfo
@Suite("Group Coordinated Info Tests")
struct LockmanGroupCoordinatedInfoTests {
  // MARK: - Initialization Tests

  @Test("Initialize with LockmanActionId")
  func testInitializeWithLockmanActionId() {
    let actionId = LockmanActionId("testAction")
    let info = LockmanGroupCoordinatedInfo(
      actionId: actionId,
      groupId: "testGroup",
      coordinationRole: .leader
    )

    #expect(info.actionId == actionId)
    #expect(info.groupIds == ["testGroup"])
    #expect(info.coordinationRole == .leader)
    #expect(info.uniqueId != UUID())
  }

  @Test("Initialize with string actionId")
  func testInitializeWithStringActionId() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .member
    )

    #expect(info.actionId == "testAction")
    #expect(info.groupIds == ["testGroup"])
    #expect(info.coordinationRole == .member)
    #expect(info.uniqueId != UUID())
  }

  @Test("Each instance has unique ID")
  func testEachInstanceHasUniqueId() {
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
    #expect(info1.actionId == info2.actionId)
    #expect(info1.groupIds == info2.groupIds)
    #expect(info1.coordinationRole == info2.coordinationRole)
    #expect(info1.uniqueId != info2.uniqueId)
  }

  // MARK: - GroupCoordinationRole Tests

  @Test("GroupCoordinationRole values")
  func testGroupCoordinationRoleValues() {
    let leader = GroupCoordinationRole.leader
    let member = GroupCoordinationRole.member

    #expect(leader.rawValue == "leader")
    #expect(member.rawValue == "member")

    // All cases
    #expect(GroupCoordinationRole.allCases.count == 2)
    #expect(GroupCoordinationRole.allCases.contains(.leader))
    #expect(GroupCoordinationRole.allCases.contains(.member))
  }

  @Test("GroupCoordinationRole is Sendable and Hashable")
  func testGroupCoordinationRoleIsSendableAndHashable() {
    let roles: Set<GroupCoordinationRole> = [.leader, .member, .leader]
    #expect(roles.count == 2) // Duplicate .leader removed

    // Can be used in dictionaries
    let roleMap: [GroupCoordinationRole: String] = [
      .leader: "Start",
      .member: "Join",
    ]
    #expect(roleMap[.leader] == "Start")
    #expect(roleMap[.member] == "Join")
  }

  // MARK: - Equatable Tests

  @Test("Equality based on uniqueId only")
  func testEqualityBasedOnUniqueIdOnly() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader
    )

    // Same instance equals itself
    #expect(info1 == info1)

    // Different instance with same properties is not equal
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action1"),
      groupId: "group1",
      coordinationRole: .leader
    )
    #expect(info1 != info2)

    // Different properties but would never have same uniqueId
    let info3 = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action2"),
      groupId: "group2",
      coordinationRole: .member
    )
    #expect(info1 != info3)
  }

  @Test("Array operations with equality")
  func testArrayOperationsWithEquality() {
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
    #expect(array.contains(info1))
    #expect(array.contains(info2))

    // First index
    #expect(array.firstIndex(of: info1) == 0)
    #expect(array.firstIndex(of: info2) == 1)

    // Filter
    let filtered = array.filter { $0 == info1 }
    #expect(filtered.count == 2) // info1 appears twice
  }

  // MARK: - LockmanInfo Protocol Tests

  @Test("Conforms to LockmanInfo protocol")
  func testConformsToLockmanInfoProtocol() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("test"),
      groupId: "group",
      coordinationRole: .member
    )

    // Can be used as LockmanInfo
    let lockmanInfo: any LockmanInfo = info
    #expect(lockmanInfo.actionId == "test")
    #expect(lockmanInfo.uniqueId == info.uniqueId)
  }

  // MARK: - Edge Cases

  @Test("Empty strings")
  func testEmptyStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(""),
      groupId: "",
      coordinationRole: .leader
    )

    #expect(info.actionId == "")
    #expect(info.groupIds == [""])
    #expect(info.coordinationRole == .leader)
  }

  @Test("Special characters in strings")
  func testSpecialCharactersInStrings() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("action@#$%^&*()"),
      groupId: "group-with-特殊文字-🔒",
      coordinationRole: .member
    )

    #expect(info.actionId == "action@#$%^&*()")
    #expect(info.groupIds == ["group-with-特殊文字-🔒"])
  }

  @Test("Very long strings")
  func testVeryLongStrings() {
    let longString = String(repeating: "x", count: 1000)
    let info = LockmanGroupCoordinatedInfo(
      actionId: longString,
      groupId: longString,
      coordinationRole: .leader
    )

    #expect(info.actionId == longString)
    #expect(info.groupIds == [longString])
  }

  // MARK: - Sendable Conformance

  @Test("Sendable across concurrent contexts")
  func testSendableAcrossConcurrentContexts() async {
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

      #expect(results.count == 10)
      #expect(results.allSatisfy { $0.contains("concurrent-test-leader") })
    }
  }

  // MARK: - Multiple Groups Tests

  @Test("Initialize with multiple groups")
  func testInitializeWithMultipleGroups() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("multi"),
      groupIds: ["group1", "group2", "group3"],
      coordinationRole: .member
    )

    #expect(info.actionId == "multi")
    #expect(info.groupIds == ["group1", "group2", "group3"])
    #expect(info.coordinationRole == .member)
  }
}
