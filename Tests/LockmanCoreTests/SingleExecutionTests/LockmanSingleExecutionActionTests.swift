
import Foundation
import XCTest
@testable import LockmanCore

/// Tests for LockmanSingleExecutionAction protocol and implementations
final class LockmanSingleExecutionActionTests: XCTestCase {
  // MARK: - Mock Actions

  /// Simple action without parameters
  struct SimpleAction: LockmanSingleExecutionAction {
    let actionName = "simpleAction"

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }
  }

  /// Action with parameter-specific naming
  enum ParameterizedAction: LockmanSingleExecutionAction {
    case fetchUser(id: String)
    case updateProfile(userId: String, name: String)
    case deletePost(postId: Int)

    var actionName: String {
      switch self {
      case let .fetchUser(id):
        return "fetchUser_\(id)"
      case let .updateProfile(userId, _):
        return "updateProfile_\(userId)"
      case let .deletePost(postId):
        return "deletePost_\(postId)"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }
  }

  /// Action with shared lock for all instances
  enum SharedLockAction: LockmanSingleExecutionAction {
    case save(data: String)
    case load
    case reset

    var actionName: String {
      switch self {
      case .save:
        return "sharedOperation"
      case .load:
        return "sharedOperation"
      case .reset:
        return "reset"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }
  }

  // MARK: - Protocol Conformance Tests

  func testsimpleActionProtocolConformance() {
    let action = SimpleAction()

    // Test actionName
    XCTAssertEqual(action.actionName, "simpleAction")

    // Test automatic strategyId
    XCTAssertEqual(action.strategyId, .singleExecution)

    // Test automatic lockmanInfo
    let info  = action.lockmanInfo
    XCTAssertEqual(info.actionId, "simpleAction")
    XCTAssertNotEqual(info.uniqueId, UUID())
  }

  func testparameterizedActionUniqueNames() {
    let action1 = ParameterizedAction.fetchUser(id: "123")
    let action2 = ParameterizedAction.fetchUser(id: "456")
    let action3 = ParameterizedAction.updateProfile(userId: "123", name: "John")
    let action4 = ParameterizedAction.deletePost(postId: 789)

    // Each should have unique actionName
    XCTAssertEqual(action1.actionName, "fetchUser_123")
    XCTAssertEqual(action2.actionName, "fetchUser_456")
    XCTAssertEqual(action3.actionName, "updateProfile_123")
    XCTAssertEqual(action4.actionName, "deletePost_789")

    // All should use the same strategy ID
    XCTAssertEqual(action1.strategyId, .singleExecution)
    XCTAssertEqual(action2.strategyId, .singleExecution)
    XCTAssertEqual(action3.strategyId, .singleExecution)
    XCTAssertEqual(action4.strategyId, .singleExecution)

    // LockmanInfo should reflect the actionName
    XCTAssertEqual(action1.lockmanInfo.actionId, "fetchUser_123")
    XCTAssertEqual(action2.lockmanInfo.actionId, "fetchUser_456")
    XCTAssertEqual(action3.lockmanInfo.actionId, "updateProfile_123")
    XCTAssertEqual(action4.lockmanInfo.actionId, "deletePost_789")
  }

  func testsharedLockActionBehavior() {
    let saveAction  = SharedLockAction.save(data: "test data")
    let loadAction = SharedLockAction.load
    let resetAction = SharedLockAction.reset

    // Save and load share the same actionName
    XCTAssertEqual(saveAction.actionName, "sharedOperation")
    XCTAssertEqual(loadAction.actionName, "sharedOperation")
    XCTAssertEqual(resetAction.actionName, "reset")

    // They should conflict with each other
    XCTAssertEqual(saveAction.lockmanInfo.actionId, loadAction.lockmanInfo.actionId)
    XCTAssertNotEqual(saveAction.lockmanInfo.actionId, resetAction.lockmanInfo.actionId)
  }

  // MARK: - LockmanAction Protocol Tests

  func testsingleExecutionActionIsLockmanAction() {
    // Test that SingleExecutionAction conforms to LockmanAction
    let action: any LockmanAction  = SimpleAction()

    // Verify we can store it as LockmanAction
    let actions: [any LockmanAction] = [action]
    XCTAssertEqual(actions.count, 1)

    // Test type constraints are satisfied
    let info  = action.lockmanInfo as? LockmanSingleExecutionInfo
    XCTAssertNotNil(info )
    XCTAssertEqual(info?.actionId, "simpleAction")
  }

  // MARK: - Integration Tests

  func testintegrationWithStrategyContainer() async {
    let container  = LockmanStrategyContainer()
    try? container.register(LockmanSingleExecutionStrategy.shared)

    await Lockman.withTestContainer(container) {
      let action = SimpleAction()

      // Resolve strategy for the action
      do {
        let strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(
          id: action.strategyId,
          expecting: LockmanSingleExecutionInfo.self
        )

        // Test locking behavior
        let boundaryId = "test-boundary"
        let info = action.lockmanInfo

        XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
        strategy.lock(id: boundaryId, info: info)
        XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: info))
        strategy.unlock(id: boundaryId, info: info)
        XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
      } catch {
        XCTFail("Strategy resolution should succeed")
      }
    }
  }

  func testconcurrentExecutionPrevention() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "test-boundary"

    // Test with same action
    let action1 = ParameterizedAction.fetchUser(id: "123")
    let action2 = ParameterizedAction.fetchUser(id: "123")

    // First lock should succeed
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: action1.lockmanInfo), .success)
    strategy.lock(id: boundaryId, info: action1.lockmanInfo)

    // Second lock should fail (boundary is locked)
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: action2.lockmanInfo))

    // Different action should also fail (boundary is locked)
    let action3 = ParameterizedAction.fetchUser(id: "456")
    XCTAssertLockFailure(strategy.canLock(id: boundaryId, info: action3.lockmanInfo))

    // Cleanup
    strategy.cleanUp()
  }

  // MARK: - Edge Cases

  func testemptyActionNameHandling() {
    struct EmptyNameAction: LockmanSingleExecutionAction {
      let actionName = ""

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = EmptyNameAction()
    XCTAssertEqual(action.actionName, "")
    XCTAssertEqual(action.lockmanInfo.actionId, "")
    XCTAssertEqual(action.strategyId, .singleExecution)
  }

  func testunicodeActionNameHandling() {
    struct UnicodeAction: LockmanSingleExecutionAction {
      let actionName  = "🔒アクション🚀"

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = UnicodeAction()
    XCTAssertEqual(action.actionName, "🔒アクション🚀")
    XCTAssertEqual(action.lockmanInfo.actionId, "🔒アクション🚀")
  }

  func testveryLongActionNameHandling() {
    struct LongNameAction: LockmanSingleExecutionAction {
      let actionName  = String(repeating: "VeryLongActionName", count: 100)

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = LongNameAction()
    XCTAssertEqual(action.actionName.count, 1800)
    XCTAssertEqual(action.lockmanInfo.actionId, action.actionName)
  }

  func testactionNameConsistencyAcrossInstances() {
    let action1  = SimpleAction()
    let action2 = SimpleAction()

    XCTAssertEqual(action1.actionName, action2.actionName)
    XCTAssertEqual(action1.lockmanInfo.actionId, action2.lockmanInfo.actionId)
    // But unique IDs should be different
    XCTAssertNotEqual(action1.lockmanInfo.uniqueId, action2.lockmanInfo.uniqueId)
  }
}
