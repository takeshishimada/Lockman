import XCTest

@testable import Lockman

// Test implementation of LockmanDynamicConditionAction
private enum TestDynamicAction: LockmanDynamicConditionAction {
  case fetchData(userId: String, priority: Int)
  case processTask(size: Int)
  case simpleAction

  var actionName: String {
    switch self {
    case .fetchData:
      return "fetchData"
    case .processTask:
      return "processTask"
    case .simpleAction:
      return "simpleAction"
    }
  }
}

final class LockmanDynamicConditionActionTests: XCTestCase {

  func testActionNameProperty() {
    // Test that actionName returns correct values
    XCTAssertEqual(TestDynamicAction.fetchData(userId: "123", priority: 5).actionName, "fetchData")
    XCTAssertEqual(TestDynamicAction.processTask(size: 100).actionName, "processTask")
    XCTAssertEqual(TestDynamicAction.simpleAction.actionName, "simpleAction")
  }

  func testWithConditionMethod() {
    // Test creating lock info with custom condition
    let action = TestDynamicAction.fetchData(userId: "123", priority: 5)

    let info = action.with {
      .success
    }

    XCTAssertEqual(info.actionId, "fetchData")
    XCTAssertEqual(info.strategyId, .dynamicCondition)

    // Test condition execution
    switch info.condition() {
    case .success:
      // Expected
      break
    case .failure:
      XCTFail("Condition should return success")
    }
  }

  func testWithConditionFailure() {
    // Test condition that returns failure
    let action = TestDynamicAction.processTask(size: 1000)

    let info = action.with {
      .failure(TestError.conditionNotMet)
    }

    // Test condition execution
    switch info.condition() {
    case .success:
      XCTFail("Condition should return failure")
    case .failure(let error):
      XCTAssertTrue(error is TestError)
    }
  }

  func testComplexCondition() {
    // Test condition with logic based on action parameters
    let action = TestDynamicAction.fetchData(userId: "admin", priority: 8)

    let info = action.with { [action] in
      switch action {
      case .fetchData(let userId, let priority):
        if userId == "admin" && priority > 5 {
          return .success
        } else {
          return .failure(TestError.insufficientPriority)
        }
      default:
        return .failure(TestError.unexpectedAction)
      }
    }

    // Should succeed for admin with high priority
    switch info.condition() {
    case .success:
      // Expected
      break
    case .failure:
      XCTFail("Condition should succeed for admin with high priority")
    }
  }

  func testDefaultLockmanInfo() {
    // Test default implementation of lockmanInfo
    let action = TestDynamicAction.simpleAction
    let info = action.lockmanInfo

    XCTAssertEqual(info.actionId, "simpleAction")
    XCTAssertEqual(info.strategyId, .dynamicCondition)

    // Default condition should always succeed
    switch info.condition() {
    case .success:
      // Expected
      break
    case .failure:
      XCTFail("Default condition should always succeed")
    }
  }

  func testMultipleConditions() {
    // Test that multiple calls to with() create independent infos
    let action = TestDynamicAction.processTask(size: 50)

    let info1 = action.with { .success }
    let info2 = action.with { .failure(TestError.conditionNotMet) }

    // Both should have same actionId
    XCTAssertEqual(info1.actionId, info2.actionId)

    // But different conditions
    switch info1.condition() {
    case .success:
      // Expected for info1
      break
    case .failure:
      XCTFail("info1 condition should succeed")
    }

    switch info2.condition() {
    case .success:
      XCTFail("info2 condition should fail")
    case .failure:
      // Expected for info2
      break
    }
  }

  func testSendableConformance() {
    // Test that condition closures are properly Sendable
    let action = TestDynamicAction.fetchData(userId: "test", priority: 3)

    // This should compile without warnings
    Task {
      let info = action.with {
        .success
      }

      // Use in async context
      let result = info.condition()
      switch result {
      case .success:
        break
      case .failure:
        XCTFail("Should succeed")
      }
    }
  }

  func testProtocolConformance() {
    // Verify LockmanAction conformance
    let action: any LockmanAction = TestDynamicAction.simpleAction
    let info = action.lockmanInfo

    XCTAssertNotNil(info)
    XCTAssertEqual(info.strategyId, .dynamicCondition)
  }
}

// Test error for conditions
private enum TestError: Error {
  case conditionNotMet
  case insufficientPriority
  case unexpectedAction
}

