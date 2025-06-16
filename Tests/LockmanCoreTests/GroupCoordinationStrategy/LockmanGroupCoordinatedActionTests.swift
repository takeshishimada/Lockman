import Foundation
import XCTest
@testable import LockmanCore

/// Tests for LockmanGroupCoordinatedAction protocol
final class LockmanGroupCoordinatedActionTests: XCTestCase {
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

  func testtestSimpleActionProtocolConformance() {
    let action = StartLoadingAction()

    // Test basic properties
    XCTAssertEqual(action.actionName , "startLoading")
    XCTAssertEqual(action.groupId , "dataLoading")
    XCTAssertEqual(action.coordinationRole , .leader)

    // Test automatic strategyId
    XCTAssertEqual(action.strategyId , .groupCoordination)

    // Test automatic lockmanInfo
    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId , "startLoading")
    XCTAssertEqual(info.groupIds , ["dataLoading"])
    XCTAssertEqual(info.coordinationRole , .leader)
    XCTAssertNotEqual(info.uniqueId , UUID())
  }

  func testtestMemberActionProtocolConformance() {
    let action = UpdateProgressAction()

    XCTAssertEqual(action.actionName , "updateProgress")
    XCTAssertEqual(action.groupId , "dataLoading")
    XCTAssertEqual(action.coordinationRole , .member)
    XCTAssertEqual(action.strategyId , .groupCoordination)

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId , "updateProgress")
    XCTAssertEqual(info.groupIds , ["dataLoading"])
    XCTAssertEqual(info.coordinationRole , .member)
  }

  func testtestParameterizedActionWithDynamicProperties() {
    // Test leader
    let startNav = NavigationAction.startNavigation(screenId: "detail")
    XCTAssertEqual(startNav.actionName , "startNavigation")
    XCTAssertEqual(startNav.groupId , "navigation-detail")
    XCTAssertEqual(startNav.coordinationRole , .leader)

    // Test members
    let animate = NavigationAction.animateTransition(screenId: "detail")
    XCTAssertEqual(animate.actionName , "animateTransition")
    XCTAssertEqual(animate.groupId , "navigation-detail")
    XCTAssertEqual(animate.coordinationRole , .member)

    let complete = NavigationAction.completeNavigation(screenId: "detail")
    XCTAssertEqual(complete.actionName , "completeNavigation")
    XCTAssertEqual(complete.groupId , "navigation-detail")
    XCTAssertEqual(complete.coordinationRole , .member)

    // Different screen IDs create different groups
    let otherNav = NavigationAction.startNavigation(screenId: "settings")
    XCTAssertEqual(otherNav.groupId , "navigation-settings")
  }

  func testtestConfigurableActionFlexibility() {
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

    XCTAssertEqual(leader.actionName , "fetchData")
    XCTAssertEqual(leader.groupId , "api-users")
    XCTAssertEqual(leader.coordinationRole , .leader)

    XCTAssertEqual(member.actionName , "cacheData")
    XCTAssertEqual(member.groupId , "api-users")
    XCTAssertEqual(member.coordinationRole , .member)

    // Both use the same strategy
    XCTAssertEqual(leader.strategyId , .groupCoordination)
    XCTAssertEqual(member.strategyId , .groupCoordination)
  }

  // MARK: - LockmanInfo Generation Tests

  func testtestGeneratedLockmanInfoHasCorrectProperties() {
    let action = StartLoadingAction()
    let info = action.lockmanInfo

    // Verify type
    XCTAssertTrue(type(of: info) == LockmanGroupCoordinatedInfo.self)

    // Verify properties match action
    XCTAssertEqual(info.actionId , action.actionName)
    XCTAssertEqual(info.groupIds , [action.groupId])
    XCTAssertEqual(info.coordinationRole , action.coordinationRole)

    // Each call generates new unique ID
    let info2 = action.lockmanInfo
    XCTAssertNotEqual(info.uniqueId , info2.uniqueId)
  }

  func testtestDifferentActionsGenerateDifferentInfos() {
    let action1 = StartLoadingAction()
    let action2 = UpdateProgressAction()

    let info1 = action1.lockmanInfo
    let info2 = action2.lockmanInfo

    // Different action IDs
    XCTAssertNotEqual(info1.actionId , info2.actionId)

    // Same group ID (by design in our test)
    XCTAssertEqual(info1.groupIds , info2.groupIds)

    // Different roles
    XCTAssertNotEqual(info1.coordinationRole , info2.coordinationRole)

    // Different unique IDs
    XCTAssertNotEqual(info1.uniqueId , info2.uniqueId)
  }

  // MARK: - Integration Tests

  func testtestActionsWorkWithGroupCoordinationStrategy() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = "testBoundary"

    // Create actions
    let startAction = StartLoadingAction()
    let progressAction = UpdateProgressAction()

    // Leader can start
    let startInfo = startAction.lockmanInfo
    XCTAssertTrue(strategy.canLock(id: boundaryId, info: startInfo) == .success)
    strategy.lock(id: boundaryId, info: startInfo)

    // Member can join
    let progressInfo = progressAction.lockmanInfo
    XCTAssertTrue(strategy.canLock(id: boundaryId, info: progressInfo) == .success)
    strategy.lock(id: boundaryId, info: progressInfo)

    // Clean up
    strategy.unlock(id: boundaryId, info: startInfo)
    strategy.unlock(id: boundaryId, info: progressInfo)
  }

  func testtestParameterizedActionsCreateIsolatedGroups() {
    let strategy = LockmanGroupCoordinationStrategy()
    let boundaryId = "testBoundary"

    // Navigation to different screens
    let navDetail = NavigationAction.startNavigation(screenId: "detail")
    let navSettings = NavigationAction.startNavigation(screenId: "settings")

    // Both can start (different groups)
    let detailInfo = navDetail.lockmanInfo
    let settingsInfo = navSettings.lockmanInfo

    // Debug: check what groupIds are being generated
    XCTAssertEqual(detailInfo.groupIds , ["navigation-detail"])
    XCTAssertEqual(settingsInfo.groupIds , ["navigation-settings"])

    XCTAssertTrue(strategy.canLock(id: boundaryId, info: detailInfo) == .success)
    strategy.lock(id: boundaryId, info: detailInfo)

    XCTAssertTrue(strategy.canLock(id: boundaryId, info: settingsInfo) == .success)
    strategy.lock(id: boundaryId, info: settingsInfo)

    // Members join correct groups
    let animateDetail = NavigationAction.animateTransition(screenId: "detail")
    let animateSettings = NavigationAction.animateTransition(screenId: "settings")

    XCTAssertTrue(strategy.canLock(id: boundaryId, info: animateDetail.lockmanInfo) == .success)
    XCTAssertTrue(strategy.canLock(id: boundaryId, info: animateSettings.lockmanInfo) == .success)
  }

  // MARK: - Multiple Groups Tests

  func testtestMultipleGroupsActionProtocolConformance() {
    let action = MultiGroupAction()

    XCTAssertEqual(action.actionName , "multiGroupOperation")
    XCTAssertEqual(action.groupIds , ["navigation", "dataLoading", "ui"])
    XCTAssertEqual(action.coordinationRole , .member)
    XCTAssertEqual(action.strategyId , .groupCoordination)

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId , "multiGroupOperation")
    XCTAssertEqual(info.groupIds , ["navigation", "dataLoading", "ui"])
    XCTAssertEqual(info.coordinationRole , .member)
  }

  func testtestMixedSingleAndMultipleGroupActions() {
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
    XCTAssertEqual(singleInfo.groupIds , ["singleGroup"])

    // Multiple group mode
    let multiMode = MultiGroupDynamicAction()
    let multiInfo = multiMode.lockmanInfo
    XCTAssertEqual(multiInfo.groupIds , ["group1", "group2"])
  }

  // MARK: - Edge Cases

  func testtestActionsWithEmptyStrings() {
    let action = ConfigurableAction(
      name: "",
      group: "",
      role: .leader
    )

    XCTAssertEqual(action.actionName , "")
    XCTAssertEqual(action.groupId , "")
    XCTAssertEqual(action.coordinationRole , .leader)

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId , "")
    XCTAssertEqual(info.groupIds , [""])
  }

  func testtestActionsWithSpecialCharacters() {
    let action = ConfigurableAction(
      name: "action@#$%",
      group: "group-with-特殊文字-🔒",
      role: .member
    )

    XCTAssertEqual(action.actionName , "action@#$%")
    XCTAssertEqual(action.groupId , "group-with-特殊文字-🔒")

    let info = action.lockmanInfo
    XCTAssertEqual(info.actionId , "action@#$%")
    XCTAssertEqual(info.groupIds , ["group-with-特殊文字-🔒"])
  }
}
