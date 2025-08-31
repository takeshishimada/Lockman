import ComposableArchitecture
import XCTest

@testable import Lockman

/// Integration tests for LockmanComposableMacros
///
/// These tests verify that the macro declarations in LockmanComposableMacros.swift
/// correctly integrate with the actual macro implementations and generate the expected
/// protocol conformances and member implementations.
// MARK: - Test Actions (Defined at file level to avoid "Local type cannot have attached extension macro")

@LockmanSingleExecution
enum SingleExecutionTestAction {
  case login
  case logout(userId: String)
  case refresh

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    switch self {
    case .login:
      return LockmanSingleExecutionInfo(actionId: LockmanActionId(actionName), mode: .boundary)
    case .logout:
      return LockmanSingleExecutionInfo(actionId: LockmanActionId(actionName), mode: .action)
    case .refresh:
      return LockmanSingleExecutionInfo(actionId: LockmanActionId(actionName), mode: .none)
    }
  }
}

@LockmanPriorityBased
enum PriorityBasedTestAction {
  case highPriorityTask
  case lowPriorityTask(id: Int)
  case noPriorityTask

  func createLockmanInfo() -> LockmanPriorityBasedInfo {
    switch self {
    case .highPriorityTask:
      return LockmanPriorityBasedInfo(
        actionId: LockmanActionId(actionName), priority: .high(.exclusive))
    case .lowPriorityTask:
      return LockmanPriorityBasedInfo(
        actionId: LockmanActionId(actionName), priority: .low(.replaceable))
    case .noPriorityTask:
      return LockmanPriorityBasedInfo(actionId: LockmanActionId(actionName), priority: .none)
    }
  }
}

@LockmanGroupCoordination
enum GroupCoordinationTestAction {
  case navigate(to: String)
  case back
  case refresh

  func createLockmanInfo() -> LockmanGroupCoordinatedInfo {
    switch self {
    case .navigate:
      return LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId(actionName),
        groupId: "navigation",
        coordinationRole: .leader(.emptyGroup)
      )
    case .back:
      return LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId(actionName),
        groupId: "navigation",
        coordinationRole: .member
      )
    case .refresh:
      return LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId(actionName),
        groupId: "ui",
        coordinationRole: .member
      )
    }
  }
}

@LockmanConcurrencyLimited
enum ConcurrencyLimitedTestAction {
  case fetchUserProfile(userId: String)
  case uploadFile(fileId: String)
  case refreshUI

  func createLockmanInfo() -> LockmanConcurrencyLimitedInfo {
    switch self {
    case .fetchUserProfile:
      return LockmanConcurrencyLimitedInfo(actionId: LockmanActionId(actionName), .limited(3))
    case .uploadFile:
      return LockmanConcurrencyLimitedInfo(actionId: LockmanActionId(actionName), .limited(2))
    case .refreshUI:
      return LockmanConcurrencyLimitedInfo(actionId: LockmanActionId(actionName), .unlimited)
    }
  }
}

@LockmanCompositeStrategy(LockmanSingleExecutionStrategy.self, LockmanPriorityBasedStrategy.self)
enum CompositeTestAction {
  case criticalOperation
  case importantTask(id: String)

  func createLockmanInfo() -> LockmanCompositeInfo2<
    LockmanSingleExecutionInfo, LockmanPriorityBasedInfo
  > {
    switch self {
    case .criticalOperation:
      return LockmanCompositeInfo2(
        actionId: LockmanActionId(actionName),
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: LockmanActionId(actionName), mode: .boundary),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: LockmanActionId(actionName), priority: .high(.exclusive))
      )
    case .importantTask:
      return LockmanCompositeInfo2(
        actionId: LockmanActionId(actionName),
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: LockmanActionId(actionName), mode: .action),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: LockmanActionId(actionName), priority: .low(.replaceable))
      )
    }
  }
}

@LockmanSingleExecution
enum TCATestAction: Equatable {
  case fetchData
  case processResult(String)

  func createLockmanInfo() -> LockmanSingleExecutionInfo {
    switch self {
    case .fetchData:
      return LockmanSingleExecutionInfo(actionId: LockmanActionId(actionName), mode: .boundary)
    case .processResult:
      return LockmanSingleExecutionInfo(actionId: LockmanActionId(actionName), mode: .action)
    }
  }
}

final class LockmanComposableMacrosTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - LockmanSingleExecution Macro Integration Tests

  func testLockmanSingleExecutionMacro_GeneratesCorrectConformance() {
    // Test protocol conformance
    XCTAssertTrue(SingleExecutionTestAction.login is LockmanSingleExecutionAction)
    XCTAssertTrue(SingleExecutionTestAction.logout(userId: "123") is LockmanAction)

    // Test actionName generation
    XCTAssertEqual(SingleExecutionTestAction.login.actionName, "login")
    XCTAssertEqual(SingleExecutionTestAction.logout(userId: "test").actionName, "logout")
    XCTAssertEqual(SingleExecutionTestAction.refresh.actionName, "refresh")

    // Test lockmanInfo access
    let loginInfo = SingleExecutionTestAction.login.createLockmanInfo()
    XCTAssertEqual(loginInfo.actionId, LockmanActionId("login"))
    XCTAssertEqual(loginInfo.mode, .boundary)

    let logoutInfo = SingleExecutionTestAction.logout(userId: "test").createLockmanInfo()
    XCTAssertEqual(logoutInfo.actionId, LockmanActionId("logout"))
    XCTAssertEqual(logoutInfo.mode, .action)

  }

  // MARK: - LockmanPriorityBased Macro Integration Tests

  func testLockmanPriorityBasedMacro_GeneratesCorrectConformance() {
    // Test protocol conformance
    XCTAssertTrue(PriorityBasedTestAction.highPriorityTask is LockmanPriorityBasedAction)
    XCTAssertTrue(PriorityBasedTestAction.lowPriorityTask(id: 1) is LockmanAction)

    // Test actionName generation
    XCTAssertEqual(PriorityBasedTestAction.highPriorityTask.actionName, "highPriorityTask")
    XCTAssertEqual(PriorityBasedTestAction.lowPriorityTask(id: 42).actionName, "lowPriorityTask")
    XCTAssertEqual(PriorityBasedTestAction.noPriorityTask.actionName, "noPriorityTask")

    // Test lockmanInfo access
    let highPriorityInfo = PriorityBasedTestAction.highPriorityTask.createLockmanInfo()
    XCTAssertEqual(highPriorityInfo.actionId, LockmanActionId("highPriorityTask"))
    XCTAssertEqual(highPriorityInfo.priority, .high(.exclusive))

    let lowPriorityInfo = PriorityBasedTestAction.lowPriorityTask(id: 42).createLockmanInfo()
    XCTAssertEqual(lowPriorityInfo.actionId, LockmanActionId("lowPriorityTask"))
    XCTAssertEqual(lowPriorityInfo.priority, .low(.replaceable))
  }

  // MARK: - LockmanGroupCoordination Macro Integration Tests

  func testLockmanGroupCoordinationMacro_GeneratesCorrectConformance() {
    // Test protocol conformance
    XCTAssertTrue(GroupCoordinationTestAction.navigate(to: "home") is LockmanGroupCoordinatedAction)
    XCTAssertTrue(GroupCoordinationTestAction.back is LockmanAction)

    // Test actionName generation
    XCTAssertEqual(GroupCoordinationTestAction.navigate(to: "test").actionName, "navigate")
    XCTAssertEqual(GroupCoordinationTestAction.back.actionName, "back")
    XCTAssertEqual(GroupCoordinationTestAction.refresh.actionName, "refresh")

    // Test lockmanInfo access
    let navigateInfo = GroupCoordinationTestAction.navigate(to: "test").createLockmanInfo()
    XCTAssertEqual(navigateInfo.actionId, LockmanActionId("navigate"))
    XCTAssertEqual(navigateInfo.coordinationRole, .leader(.emptyGroup))

    let backInfo = GroupCoordinationTestAction.back.createLockmanInfo()
    XCTAssertEqual(backInfo.actionId, LockmanActionId("back"))
    XCTAssertEqual(backInfo.coordinationRole, .member)
  }

  // MARK: - LockmanConcurrencyLimited Macro Integration Tests

  func testLockmanConcurrencyLimitedMacro_GeneratesCorrectConformance() {
    // Test protocol conformance
    XCTAssertTrue(
      ConcurrencyLimitedTestAction.fetchUserProfile(userId: "123")
        is LockmanConcurrencyLimitedAction)
    XCTAssertTrue(ConcurrencyLimitedTestAction.uploadFile(fileId: "abc") is LockmanAction)

    // Test actionName generation
    XCTAssertEqual(
      ConcurrencyLimitedTestAction.fetchUserProfile(userId: "test").actionName, "fetchUserProfile")
    XCTAssertEqual(ConcurrencyLimitedTestAction.uploadFile(fileId: "test").actionName, "uploadFile")
    XCTAssertEqual(ConcurrencyLimitedTestAction.refreshUI.actionName, "refreshUI")

    // Test lockmanInfo access
    let fetchInfo = ConcurrencyLimitedTestAction.fetchUserProfile(userId: "test")
      .createLockmanInfo()
    XCTAssertEqual(fetchInfo.actionId, LockmanActionId("fetchUserProfile"))
    XCTAssertEqual(fetchInfo.limit, .limited(3))

    let uploadInfo = ConcurrencyLimitedTestAction.uploadFile(fileId: "test").createLockmanInfo()
    XCTAssertEqual(uploadInfo.actionId, LockmanActionId("uploadFile"))
    XCTAssertEqual(uploadInfo.limit, .limited(2))

    let refreshInfo = ConcurrencyLimitedTestAction.refreshUI.createLockmanInfo()
    XCTAssertEqual(refreshInfo.actionId, LockmanActionId("refreshUI"))
    XCTAssertEqual(refreshInfo.limit, .unlimited)
  }

  // MARK: - LockmanCompositeStrategy Macro Integration Tests

  func testLockmanCompositeStrategy2Macro_GeneratesCorrectConformance() {
    // Test protocol conformance
    XCTAssertTrue(CompositeTestAction.criticalOperation is LockmanCompositeAction2)
    XCTAssertTrue(CompositeTestAction.importantTask(id: "test") is LockmanAction)

    // Test actionName generation
    XCTAssertEqual(CompositeTestAction.criticalOperation.actionName, "criticalOperation")
    XCTAssertEqual(CompositeTestAction.importantTask(id: "test").actionName, "importantTask")

    // Test lockmanInfo access
    let criticalInfo = CompositeTestAction.criticalOperation.createLockmanInfo()
    XCTAssertEqual(criticalInfo.actionId, LockmanActionId("criticalOperation"))
    XCTAssertEqual(criticalInfo.lockmanInfoForStrategy1.mode, .boundary)
    XCTAssertEqual(criticalInfo.lockmanInfoForStrategy2.priority, .high(.exclusive))

    let importantInfo = CompositeTestAction.importantTask(id: "test").createLockmanInfo()
    XCTAssertEqual(importantInfo.actionId, LockmanActionId("importantTask"))
    XCTAssertEqual(importantInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(importantInfo.lockmanInfoForStrategy2.priority, .low(.replaceable))

    // Test strategyId generation
    XCTAssertFalse(CompositeTestAction.criticalOperation.strategyId.value.isEmpty)
    XCTAssertFalse(CompositeTestAction.importantTask(id: "test").strategyId.value.isEmpty)
  }

  // MARK: - TCA Integration Tests

  func testMacroGeneratedAction_IntegratesWithTCA() async {
    struct TestState: Equatable {
      var data: String = ""
      var isLoading = false
    }

    let store = await TestStore<TestState, TCATestAction>(
      initialState: TestState()
    ) {
      Reduce { state, action in
        switch action {
        case .fetchData:
          state.isLoading = true
          return .run { send in
            await send(.processResult("test-data"))
          }
        case .processResult(let data):
          state.data = data
          state.isLoading = false
          return .none
        }
      }
    }

    // Test that macro-generated action works with TestStore
    await store.send(.fetchData) {
      $0.isLoading = true
    }

    await store.receive(.processResult("test-data")) {
      $0.data = "test-data"
      $0.isLoading = false
    }

    await store.finish()
  }

  // MARK: - Macro Compilation Tests

  func testAllMacrosCompileSuccessfully() {
    // This test verifies that all macro declarations compile without errors
    // and that the external macro references are valid

    // Verify all actions have been created successfully (compilation test)
    XCTAssertEqual(SingleExecutionTestAction.login.actionName, "login")
    XCTAssertEqual(PriorityBasedTestAction.highPriorityTask.actionName, "highPriorityTask")
    XCTAssertEqual(GroupCoordinationTestAction.back.actionName, "back")
    XCTAssertEqual(ConcurrencyLimitedTestAction.refreshUI.actionName, "refreshUI")
    XCTAssertEqual(CompositeTestAction.criticalOperation.actionName, "criticalOperation")
  }

  // MARK: - Error Handling Tests

  func testMacroGeneratedAction_HandlesComplexCaseNames() {
    // Test complex case name generation using the file-level defined actions
    XCTAssertEqual(SingleExecutionTestAction.login.actionName, "login")
    XCTAssertEqual(
      SingleExecutionTestAction.logout(userId: "test").actionName,
      "logout"
    )
    XCTAssertEqual(
      PriorityBasedTestAction.lowPriorityTask(id: 42).actionName,
      "lowPriorityTask"
    )
    XCTAssertEqual(
      GroupCoordinationTestAction.navigate(to: "home").actionName,
      "navigate"
    )
  }

}
