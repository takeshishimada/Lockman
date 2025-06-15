import Foundation
import Testing
@testable import LockmanCore

/// Tests for LockmanGroupCoordinatedAction protocol
@Suite("Group Coordinated Action Tests")
struct LockmanGroupCoordinatedActionTests {
  // MARK: - Mock Actions

  /// Simple leader action (single group)
  private struct StartLoadingAction: LockmanGroupCoordinatedAction {
    let actionName = "startLoading"
    let groupId = "dataLoading"
    let coordinationRole = GroupCoordinationRole.leader
  }

  /// Simple member action (single group)
  private struct UpdateProgressAction: LockmanGroupCoordinatedAction {
    let actionName = "updateProgress"
    let groupId = "dataLoading"
    let coordinationRole = GroupCoordinationRole.member
  }

  /// Multiple groups action
  private struct MultiGroupAction: LockmanGroupCoordinatedAction {
    let actionName = "multiGroupOperation"
    let groupIds: Set<String> = ["navigation", "dataLoading", "ui"]
    let coordinationRole = GroupCoordinationRole.member
  }

  /// Parameterized action with dynamic group ID
  private enum NavigationAction: LockmanGroupCoordinatedAction, LockmanSingleGroupAction {
    case startNavigation(screenId: String)
    case animateTransition(screenId: String)
    case completeNavigation(screenId: String)

    var actionName: String {
      switch self {
      case .startNavigation:
        return "startNavigation"
      case .animateTransition:
        return "animateTransition"
      case .completeNavigation:
        return "completeNavigation"
      }
    }

    var groupId: String {
      switch self {
      case let .animateTransition(screenId),
           let .completeNavigation(screenId),
           let .startNavigation(screenId):
        return "navigation-\(screenId)"
      }
    }

    var coordinationRole: GroupCoordinationRole {
      switch self {
      case .startNavigation:
        return .leader
      case .animateTransition,
           .completeNavigation:
        return .member
      }
    }
  }

  /// Action with configuration-based roles
  private struct ConfigurableAction: LockmanGroupCoordinatedAction {
    let actionName: String
    let groupId: String
    let coordinationRole: GroupCoordinationRole

    init(name: String, group: String, role: GroupCoordinationRole) {
      self.actionName = name
      self.groupId = group
      self.coordinationRole = role
    }
  }

  // MARK: - Protocol Conformance Tests

  @Test("Simple action protocol conformance")
  func testSimpleActionProtocolConformance() {
    let action = StartLoadingAction()

    // Test basic properties
    #expect(action.actionName == "startLoading")
    #expect(action.groupId == "dataLoading")
    #expect(action.coordinationRole == .leader)

    // Test automatic strategyId
    #expect(action.strategyId == .groupCoordination)

    // Test automatic lockmanInfo
    let info = action.lockmanInfo
    #expect(info.actionId == "startLoading")
    #expect(info.groupIds == ["dataLoading"])
    #expect(info.coordinationRole == .leader)
    #expect(info.uniqueId != UUID())
  }

  @Test("Member action protocol conformance")
  func testMemberActionProtocolConformance() {
    let action = UpdateProgressAction()

    #expect(action.actionName == "updateProgress")
    #expect(action.groupId == "dataLoading")
    #expect(action.coordinationRole == .member)
    #expect(action.strategyId == .groupCoordination)

    let info = action.lockmanInfo
    #expect(info.actionId == "updateProgress")
    #expect(info.groupIds == ["dataLoading"])
    #expect(info.coordinationRole == .member)
  }

  @Test("Parameterized action with dynamic properties")
  func testParameterizedActionWithDynamicProperties() {
    // Test leader
    let startNav = NavigationAction.startNavigation(screenId: "detail")
    #expect(startNav.actionName == "startNavigation")
    #expect(startNav.groupId == "navigation-detail")
    #expect(startNav.coordinationRole == .leader)

    // Test members
    let animate = NavigationAction.animateTransition(screenId: "detail")
    #expect(animate.actionName == "animateTransition")
    #expect(animate.groupId == "navigation-detail")
    #expect(animate.coordinationRole == .member)

    let complete = NavigationAction.completeNavigation(screenId: "detail")
    #expect(complete.actionName == "completeNavigation")
    #expect(complete.groupId == "navigation-detail")
    #expect(complete.coordinationRole == .member)

    // Different screen IDs create different groups
    let otherNav = NavigationAction.startNavigation(screenId: "settings")
    #expect(otherNav.groupId == "navigation-settings")
  }

  @Test("Configurable action flexibility")
  func testConfigurableActionFlexibility() {
    // Create different configurations
    let leader = ConfigurableAction(
      name: "fetchData",
      group: "api-users",
      role: .leader
    )

    let member = ConfigurableAction(
      name: "cacheData",
      group: "api-users",
      role: .member
    )

    #expect(leader.actionName == "fetchData")
    #expect(leader.groupId == "api-users")
    #expect(leader.coordinationRole == .leader)

    #expect(member.actionName == "cacheData")
    #expect(member.groupId == "api-users")
    #expect(member.coordinationRole == .member)

    // Both use the same strategy
    #expect(leader.strategyId == .groupCoordination)
    #expect(member.strategyId == .groupCoordination)
  }

  // MARK: - LockmanInfo Generation Tests

  @Test("Generated lockmanInfo has correct properties")
  func testGeneratedLockmanInfoHasCorrectProperties() {
    let action = StartLoadingAction()
    let info = action.lockmanInfo

    // Verify type
    #expect(type(of: info) == LockmanGroupCoordinatedInfo.self)

    // Verify properties match action
    #expect(info.actionId == action.actionName)
    #expect(info.groupIds == [action.groupId])
    #expect(info.coordinationRole == action.coordinationRole)

    // Each call generates new unique ID
    let info2 = action.lockmanInfo
    #expect(info.uniqueId != info2.uniqueId)
  }

  @Test("Different actions generate different infos")
  func testDifferentActionsGenerateDifferentInfos() {
    let action1 = StartLoadingAction()
    let action2 = UpdateProgressAction()

    let info1 = action1.lockmanInfo
    let info2 = action2.lockmanInfo

    // Different action IDs
    #expect(info1.actionId != info2.actionId)

    // Same group ID (by design in our test)
    #expect(info1.groupIds == info2.groupIds)

    // Different roles
    #expect(info1.coordinationRole != info2.coordinationRole)

    // Different unique IDs
    #expect(info1.uniqueId != info2.uniqueId)
  }

  // MARK: - Integration Tests

  @Test("Actions work with group coordination strategy")
  func testActionsWorkWithGroupCoordinationStrategy() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = "testBoundary"

    // Create actions
    let startAction = StartLoadingAction()
    let progressAction = UpdateProgressAction()

    // Leader can start
    let startInfo = startAction.lockmanInfo
    #expect(strategy.canLock(id: boundaryId, info: startInfo) == .success)
    strategy.lock(id: boundaryId, info: startInfo)

    // Member can join
    let progressInfo = progressAction.lockmanInfo
    #expect(strategy.canLock(id: boundaryId, info: progressInfo) == .success)
    strategy.lock(id: boundaryId, info: progressInfo)

    // Clean up
    strategy.unlock(id: boundaryId, info: startInfo)
    strategy.unlock(id: boundaryId, info: progressInfo)
  }

  @Test("Parameterized actions create isolated groups")
  func testParameterizedActionsCreateIsolatedGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = "testBoundary"

    // Navigation to different screens
    let navDetail = NavigationAction.startNavigation(screenId: "detail")
    let navSettings = NavigationAction.startNavigation(screenId: "settings")

    // Both can start (different groups)
    let detailInfo = navDetail.lockmanInfo
    let settingsInfo = navSettings.lockmanInfo

    // Debug: check what groupIds are being generated
    #expect(detailInfo.groupIds == ["navigation-detail"])
    #expect(settingsInfo.groupIds == ["navigation-settings"])

    #expect(strategy.canLock(id: boundaryId, info: detailInfo) == .success)
    strategy.lock(id: boundaryId, info: detailInfo)

    #expect(strategy.canLock(id: boundaryId, info: settingsInfo) == .success)
    strategy.lock(id: boundaryId, info: settingsInfo)

    // Members join correct groups
    let animateDetail = NavigationAction.animateTransition(screenId: "detail")
    let animateSettings = NavigationAction.animateTransition(screenId: "settings")

    #expect(strategy.canLock(id: boundaryId, info: animateDetail.lockmanInfo) == .success)
    #expect(strategy.canLock(id: boundaryId, info: animateSettings.lockmanInfo) == .success)
  }

  // MARK: - Multiple Groups Tests

  @Test("Multiple groups action protocol conformance")
  func testMultipleGroupsActionProtocolConformance() {
    let action = MultiGroupAction()

    #expect(action.actionName == "multiGroupOperation")
    #expect(action.groupIds == ["navigation", "dataLoading", "ui"])
    #expect(action.coordinationRole == .member)
    #expect(action.strategyId == .groupCoordination)

    let info = action.lockmanInfo
    #expect(info.actionId == "multiGroupOperation")
    #expect(info.groupIds == ["navigation", "dataLoading", "ui"])
    #expect(info.coordinationRole == .member)
  }

  @Test("Mixed single and multiple group actions")
  func testMixedSingleAndMultipleGroupActions() {
    // Action that can switch between single and multiple groups
    struct SingleGroupDynamicAction: LockmanGroupCoordinatedAction, LockmanSingleGroupAction {
      let actionName = "dynamic"
      let coordinationRole = GroupCoordinationRole.leader
      let groupId = "singleGroup"
    }

    struct MultiGroupDynamicAction: LockmanGroupCoordinatedAction, LockmanMultipleGroupsAction {
      let actionName = "dynamic"
      let coordinationRole = GroupCoordinationRole.leader
      let groupIds: Set<String> = ["group1", "group2"]
    }

    // Single group mode
    let singleMode = SingleGroupDynamicAction()
    let singleInfo = singleMode.lockmanInfo
    #expect(singleInfo.groupIds == ["singleGroup"])

    // Multiple group mode
    let multiMode = MultiGroupDynamicAction()
    let multiInfo = multiMode.lockmanInfo
    #expect(multiInfo.groupIds == ["group1", "group2"])
  }

  // MARK: - Edge Cases

  @Test("Actions with empty strings")
  func testActionsWithEmptyStrings() {
    let action = ConfigurableAction(
      name: "",
      group: "",
      role: .leader
    )

    #expect(action.actionName == "")
    #expect(action.groupId == "")
    #expect(action.coordinationRole == .leader)

    let info = action.lockmanInfo
    #expect(info.actionId == "")
    #expect(info.groupIds == [""])
  }

  @Test("Actions with special characters")
  func testActionsWithSpecialCharacters() {
    let action = ConfigurableAction(
      name: "action@#$%",
      group: "group-with-特殊文字-🔒",
      role: .member
    )

    #expect(action.actionName == "action@#$%")
    #expect(action.groupId == "group-with-特殊文字-🔒")

    let info = action.lockmanInfo
    #expect(info.actionId == "action@#$%")
    #expect(info.groupIds == ["group-with-特殊文字-🔒"])
  }
}
