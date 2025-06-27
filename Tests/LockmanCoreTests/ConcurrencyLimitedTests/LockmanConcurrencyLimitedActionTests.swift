import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Boundary Id

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

// MARK: - Test Action

private enum TestAction: LockmanConcurrencyLimitedAction {
  case fetchUser(id: String)
  case uploadFile(name: String)
  case processData

  var actionName: String {
    switch self {
    case .fetchUser: return "fetchUser"
    case .uploadFile: return "uploadFile"
    case .processData: return "processData"
    }
  }

  var lockmanInfo: LockmanConcurrencyLimitedInfo {
    switch self {
    case .fetchUser:
      return .init(actionId: actionName, group: TestConcurrencyGroup.apiRequests)
    case .uploadFile:
      return .init(actionId: actionName, group: TestConcurrencyGroup.fileOperations)
    case .processData:
      return .init(actionId: actionName, .limited(1))
    }
  }
}

// MARK: - LockmanConcurrencyLimitedAction Tests

final class LockmanConcurrencyLimitedActionTests: XCTestCase {
  // MARK: - Protocol Conformance Tests

  func testActionNameProperty() {
    XCTAssertEqual(TestAction.fetchUser(id: "123").actionName, "fetchUser")
    XCTAssertEqual(TestAction.uploadFile(name: "test.txt").actionName, "uploadFile")
    XCTAssertEqual(TestAction.processData.actionName, "processData")
  }

  func testLockmanInfoPropertyWithGroup() {
    let fetchUserInfo = TestAction.fetchUser(id: "123").lockmanInfo
    XCTAssertEqual(fetchUserInfo.actionId, "fetchUser")
    XCTAssertEqual(fetchUserInfo.concurrencyId, "api_requests")
    XCTAssertEqual(fetchUserInfo.limit, .limited(3))

    let uploadFileInfo = TestAction.uploadFile(name: "test.txt").lockmanInfo
    XCTAssertEqual(uploadFileInfo.actionId, "uploadFile")
    XCTAssertEqual(uploadFileInfo.concurrencyId, "file_operations")
    XCTAssertEqual(uploadFileInfo.limit, .limited(2))
  }

  func testLockmanInfoPropertyWithDirectLimit() {
    let processDataInfo = TestAction.processData.lockmanInfo
    XCTAssertEqual(processDataInfo.actionId, "processData")
    XCTAssertEqual(processDataInfo.concurrencyId, "processData")
    XCTAssertEqual(processDataInfo.limit, .limited(1))
  }

  func testStrategyIdProperty() {
    let action = TestAction.fetchUser(id: "123")
    let expectedId = LockmanConcurrencyLimitedStrategy.makeStrategyId()
    XCTAssertEqual(action.lockmanInfo.strategyId, expectedId)
  }

  // MARK: - Different Action Cases Tests

  func testDifferentActionsHaveDifferentActionNames() {
    let actions: [TestAction] = [
      .fetchUser(id: "1"),
      .uploadFile(name: "file"),
      .processData,
    ]

    let actionNames = actions.map { $0.actionName }
    let uniqueNames = Set(actionNames)

    XCTAssertEqual(actionNames.count, uniqueNames.count)
  }

  func testSameActionWithDifferentAssociatedValues() {
    let action1 = TestAction.fetchUser(id: "123")
    let action2 = TestAction.fetchUser(id: "456")

    XCTAssertEqual(action1.actionName, action2.actionName)
    XCTAssertEqual(action1.lockmanInfo.concurrencyId, action2.lockmanInfo.concurrencyId)
    XCTAssertEqual(action1.lockmanInfo.limit, action2.lockmanInfo.limit)
  }

  // MARK: - Integration Tests

  func testActionCanBeUsedWithStrategy() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")
    let action = TestAction.fetchUser(id: "123")
    let info = action.lockmanInfo

    // First lock should succeed
    let result = strategy.canLock(id: boundary, info: info)
    XCTAssertEqual(result, .success)

    // Clean up
    strategy.cleanUp(id: boundary)
  }

  func testMultipleActionsRespectConcurrencyLimits() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // Process data has limit of 1
    let action1 = TestAction.processData
    let action2 = TestAction.processData

    strategy.lock(id: boundary, info: action1.lockmanInfo)

    // Second should fail
    let result = strategy.canLock(id: boundary, info: action2.lockmanInfo)
    XCTAssertLockFailure(result)

    // Clean up
    strategy.cleanUp(id: boundary)
  }

  // MARK: - Type Safety Tests

  func testActionIsLockmanAction() {
    let action: any LockmanAction = TestAction.fetchUser(id: "123")
    // Cast to concrete type to access actionName
    if let testAction = action as? TestAction {
      XCTAssertEqual(testAction.actionName, "fetchUser")
    } else {
      XCTFail("Action should be TestAction")
    }
    XCTAssertNotNil(action.lockmanInfo)
  }

  func testActionInfoType() {
    let action = TestAction.fetchUser(id: "123")
    let info = action.lockmanInfo

    // Verify the info type is correct
    XCTAssertTrue(type(of: info) == LockmanConcurrencyLimitedInfo.self)
  }
}

// MARK: - Test Action with Unlimited

private enum UnlimitedTestAction: LockmanConcurrencyLimitedAction {
  case refreshUI
  case updateCache

  var actionName: String {
    switch self {
    case .refreshUI: return "refreshUI"
    case .updateCache: return "updateCache"
    }
  }

  var lockmanInfo: LockmanConcurrencyLimitedInfo {
    .init(actionId: actionName, .unlimited)
  }
}

extension LockmanConcurrencyLimitedActionTests {
  func testUnlimitedActions() {
    let strategy = LockmanConcurrencyLimitedStrategy.shared
    let boundary = TestBoundaryId("test")

    // Lock many unlimited actions
    for i in 0..<100 {
      let action = i % 2 == 0 ? UnlimitedTestAction.refreshUI : UnlimitedTestAction.updateCache
      let result = strategy.canLock(id: boundary, info: action.lockmanInfo)
      XCTAssertEqual(result, .success)
      strategy.lock(id: boundary, info: action.lockmanInfo)
    }

    // Clean up
    strategy.cleanUp(id: boundary)
  }
}
