import Foundation
import XCTest

@testable import Lockman

/// Tests for LockmanGroupCoordinatedAction protocol
final class LockmanGroupCoordinatedActionTests: XCTestCase {
  // MARK: - Mock Actions

  /// Simple leader action (single group)
  private struct StartLoadingAction: LockmanGroupCoordinatedAction {
    let actionName = "startLoading"

    var lockmanInfo: LockmanGroupCoordinatedInfo {
      LockmanGroupCoordinatedInfo(
        actionId: actionName,
        groupId: "dataLoading",
        coordinationRole: .none
      )
    }
  }

  /// Simple member action (single group)
  private struct UpdateProgressAction: LockmanGroupCoordinatedAction {
    let actionName = "updateProgress"

    var lockmanInfo: LockmanGroupCoordinatedInfo {
      LockmanGroupCoordinatedInfo(
        actionId: actionName,
        groupId: "dataLoading",
        coordinationRole: .member
      )
    }
  }

  /// Multiple groups action
  private struct MultiGroupAction: LockmanGroupCoordinatedAction {
    let actionName = "multiGroupOperation"

    var lockmanInfo: LockmanGroupCoordinatedInfo {
      LockmanGroupCoordinatedInfo(
        actionId: actionName,
        groupIds: ["navigation", "dataLoading", "ui"],
        coordinationRole: .member
      )
    }
  }

  /// Parameterized action with dynamic group ID
  private enum NavigationAction: LockmanGroupCoordinatedAction {
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

    var lockmanInfo: LockmanGroupCoordinatedInfo {
      let screenId: String
      switch self {
      case .startNavigation(let id),
        .animateTransition(let id),
        .completeNavigation(let id):
        screenId = id
      }

      let role: LockmanGroupCoordinationRole
      switch self {
      case .startNavigation:
        role = .none
      case .animateTransition, .completeNavigation:
        role = .member
      }

      return LockmanGroupCoordinatedInfo(
        actionId: actionName,
        groupId: "navigation-\(screenId)",
        coordinationRole: role
      )
    }
  }

  /// Action with configuration-based roles
  private struct ConfigurableAction: LockmanGroupCoordinatedAction {
    let actionName: String
    let groupId: String
    let coordinationRole: LockmanGroupCoordinationRole

    init(name: String, group: String, role: LockmanGroupCoordinationRole) {
      self.actionName = name
      self.groupId = group
      self.coordinationRole = role
    }

    var lockmanInfo: LockmanGroupCoordinatedInfo {
      LockmanGroupCoordinatedInfo(
        actionId: actionName,
        groupId: groupId,
        coordinationRole: coordinationRole
      )
    }
  }

  // MARK: - Protocol Conformance Tests

  func testSimpleActionProtocolConformance() {
    let action = StartLoadingAction()

    // Test basic properties
    XCTAssertEqual(action.actionName, "startLoading")

    // Test automatic strategyId
    XCTAssertEqual(action.lockmanInfo.strategyId, .groupCoordination)

    // Test lockmanInfo
    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId, "startLoading")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("dataLoading")])
    XCTAssertEqual(info.coordinationRole, .none)
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  func testMemberActionProtocolConformance() {
    let action = UpdateProgressAction()

    XCTAssertEqual(action.actionName, "updateProgress")
    XCTAssertEqual(action.lockmanInfo.strategyId, .groupCoordination)

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId, "updateProgress")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("dataLoading")])
    XCTAssertEqual(info.coordinationRole, .member)
  }

  func testParameterizedActionWithDynamicProperties() {
    // Test leader
    let startNav = NavigationAction.startNavigation(screenId: "detail")
    XCTAssertEqual(startNav.actionName, "startNavigation")

    let startInfo = startNav.lockmanInfo
    XCTAssertEqual(startInfo.groupIds, [AnyLockmanGroupId("navigation-detail")])
    XCTAssertEqual(startInfo.coordinationRole, .none)

    // Test members
    let animate = NavigationAction.animateTransition(screenId: "detail")
    XCTAssertEqual(animate.actionName, "animateTransition")

    let animateInfo = animate.lockmanInfo
    XCTAssertEqual(animateInfo.groupIds, [AnyLockmanGroupId("navigation-detail")])
    XCTAssertEqual(animateInfo.coordinationRole, .member)

    let complete = NavigationAction.completeNavigation(screenId: "detail")
    XCTAssertEqual(complete.actionName, "completeNavigation")

    let completeInfo = complete.lockmanInfo
    XCTAssertEqual(completeInfo.groupIds, [AnyLockmanGroupId("navigation-detail")])
    XCTAssertEqual(completeInfo.coordinationRole, .member)

    // Different screen IDs create different groups
    let otherNav = NavigationAction.startNavigation(screenId: "settings")
    let otherInfo = otherNav.lockmanInfo
    XCTAssertEqual(otherInfo.groupIds, [AnyLockmanGroupId("navigation-settings")])
  }

  func testConfigurableActionFlexibility() {
    // Create different configurations
    let leader = ConfigurableAction(
      name: "fetchData",
      group: "api-users",
      role: .none
    )

    let member = ConfigurableAction(
      name: "cacheData",
      group: "api-users",
      role: .member
    )

    XCTAssertEqual(leader.actionName, "fetchData")
    let leaderInfo = leader.lockmanInfo
    XCTAssertEqual(leaderInfo.groupIds, [AnyLockmanGroupId("api-users")])
    XCTAssertEqual(leaderInfo.coordinationRole, .none)

    XCTAssertEqual(member.actionName, "cacheData")
    let memberInfo = member.lockmanInfo
    XCTAssertEqual(memberInfo.groupIds, [AnyLockmanGroupId("api-users")])
    XCTAssertEqual(memberInfo.coordinationRole, .member)

    // Both use the same strategy
    XCTAssertEqual(leader.lockmanInfo.strategyId, .groupCoordination)
    XCTAssertEqual(member.lockmanInfo.strategyId, .groupCoordination)
  }

  // MARK: - LockmanInfo Generation Tests

  func testGeneratedLockmanInfoHasCorrectProperties() {
    let action = StartLoadingAction()
    let info = action.lockmanInfo

    // Verify type
    XCTAssertTrue(type(of: info) == LockmanGroupCoordinatedInfo.self)

    // Verify properties match action
    XCTAssertEqual(info.actionId, action.actionName)
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("dataLoading")])
    XCTAssertEqual(info.coordinationRole, .none)

    // Each call generates new unique ID
    let info2 = action.lockmanInfo
    XCTAssertNotEqual(info.uniqueId, info2.uniqueId)
  }

  func testDifferentActionsGenerateDifferentInfos() {
    let action1 = StartLoadingAction()
    let action2 = UpdateProgressAction()

    let info1 = action1.lockmanInfo
    let info2 = action2.lockmanInfo

    // Different action IDs
    XCTAssertNotEqual(info1.actionId, info2.actionId)

    // Same group ID (by design in our test)
    XCTAssertEqual(info1.groupIds, info2.groupIds)

    // Different roles
    XCTAssertNotEqual(info1.coordinationRole, info2.coordinationRole)

    // Different unique IDs
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  // MARK: - Integration Tests

  func testActionsWorkWithGroupCoordinationStrategy() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = "testBoundary"

    // Create actions
    let startAction = StartLoadingAction()
    let progressAction = UpdateProgressAction()

    // Leader can start
    let startInfo = startAction.lockmanInfo
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: startInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: startInfo)

    // Member can join
    let progressInfo = progressAction.lockmanInfo
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: progressInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: progressInfo)

    // Clean up
    strategy.unlock(boundaryId: boundaryId, info: startInfo)
    strategy.unlock(boundaryId: boundaryId, info: progressInfo)
  }

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
    XCTAssertEqual(detailInfo.groupIds, [AnyLockmanGroupId("navigation-detail")])
    XCTAssertEqual(settingsInfo.groupIds, [AnyLockmanGroupId("navigation-settings")])

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: detailInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: detailInfo)

    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: settingsInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: settingsInfo)

    // Members join correct groups
    let animateDetail = NavigationAction.animateTransition(screenId: "detail")
    let animateSettings = NavigationAction.animateTransition(screenId: "settings")

    XCTAssertEqual(
      strategy.canLock(boundaryId: boundaryId, info: animateDetail.lockmanInfo), .success)
    XCTAssertEqual(
      strategy.canLock(boundaryId: boundaryId, info: animateSettings.lockmanInfo), .success)
  }

  // MARK: - Multiple Groups Tests

  func testMultipleGroupsActionProtocolConformance() {
    let action = MultiGroupAction()

    XCTAssertEqual(action.actionName, "multiGroupOperation")
    XCTAssertEqual(action.lockmanInfo.strategyId, .groupCoordination)

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId, "multiGroupOperation")
    XCTAssertEqual(
      info.groupIds,
      [AnyLockmanGroupId("navigation"), AnyLockmanGroupId("dataLoading"), AnyLockmanGroupId("ui")])
    XCTAssertEqual(info.coordinationRole, .member)
  }

  func testMixedSingleAndMultipleGroupActions() {
    // Action that can switch between single and multiple groups
    struct SingleGroupDynamicAction: LockmanGroupCoordinatedAction {
      let actionName = "dynamic"

      var lockmanInfo: LockmanGroupCoordinatedInfo {
        LockmanGroupCoordinatedInfo(
          actionId: actionName,
          groupId: "singleGroup",
          coordinationRole: .none
        )
      }
    }

    struct MultiGroupDynamicAction: LockmanGroupCoordinatedAction {
      let actionName = "dynamic"

      var lockmanInfo: LockmanGroupCoordinatedInfo {
        LockmanGroupCoordinatedInfo(
          actionId: actionName,
          groupIds: ["group1", "group2"],
          coordinationRole: .none
        )
      }
    }

    // Single group mode
    let singleMode = SingleGroupDynamicAction()
    let singleInfo = singleMode.lockmanInfo
    XCTAssertEqual(singleInfo.groupIds, [AnyLockmanGroupId("singleGroup")])

    // Multiple group mode
    let multiMode = MultiGroupDynamicAction()
    let multiInfo = multiMode.lockmanInfo
    XCTAssertEqual(multiInfo.groupIds, [AnyLockmanGroupId("group1"), AnyLockmanGroupId("group2")])
  }

  // MARK: - Edge Cases

  func testActionsWithEmptyStrings() {
    let action = ConfigurableAction(
      name: "",
      group: "",
      role: .none
    )

    XCTAssertEqual(action.actionName, "")

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId, "")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("")])
  }

  func testActionsWithSpecialCharacters() {
    let action = ConfigurableAction(
      name: "action@#$%",
      group: "group-with-特殊文字-🔒",
      role: .member
    )

    XCTAssertEqual(action.actionName, "action@#$%")

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId, "action@#$%")
    XCTAssertEqual(info.groupIds, [AnyLockmanGroupId("group-with-特殊文字-🔒")])
  }
}
