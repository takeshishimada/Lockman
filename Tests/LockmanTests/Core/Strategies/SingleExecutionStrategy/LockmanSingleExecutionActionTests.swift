import Foundation
import XCTest

@testable import Lockman

/// Tests for LockmanSingleExecutionAction protocol and implementations
final class LockmanSingleExecutionActionTests: XCTestCase {
  // MARK: - Mock Actions

  /// Simple action without parameters
  struct SimpleAction: LockmanSingleExecutionAction {
    let actionName = "simpleAction"

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
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
      case .fetchUser(let id):
        return "fetchUser_\(id)"
      case .updateProfile(let userId, _):
        return "updateProfile_\(userId)"
      case .deletePost(let postId):
        return "deletePost_\(postId)"
      }
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
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

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }
  }

  // MARK: - Protocol Conformance Tests

  func testsimpleActionProtocolConformance() {
    let action = SimpleAction()

    // Test actionName
    XCTAssertEqual(action.actionName, "simpleAction")

    // Test automatic strategyId (accessed through lockmanInfo)
    XCTAssertEqual(action.createLockmanInfo().strategyId, .singleExecution)

    // Test automatic lockmanInfo
    let info = action.createLockmanInfo()
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

    // All should use the same strategy ID (accessed through lockmanInfo)
    XCTAssertEqual(action1.createLockmanInfo().strategyId, .singleExecution)
    XCTAssertEqual(action2.createLockmanInfo().strategyId, .singleExecution)
    XCTAssertEqual(action3.createLockmanInfo().strategyId, .singleExecution)
    XCTAssertEqual(action4.createLockmanInfo().strategyId, .singleExecution)

    // LockmanInfo should reflect the actionName
    XCTAssertEqual(action1.createLockmanInfo().actionId, "fetchUser_123")
    XCTAssertEqual(action2.createLockmanInfo().actionId, "fetchUser_456")
    XCTAssertEqual(action3.createLockmanInfo().actionId, "updateProfile_123")
    XCTAssertEqual(action4.createLockmanInfo().actionId, "deletePost_789")
  }

  func testsharedLockActionBehavior() {
    let saveAction = SharedLockAction.save(data: "test data")
    let loadAction = SharedLockAction.load
    let resetAction = SharedLockAction.reset

    // Save and load share the same actionName
    XCTAssertEqual(saveAction.actionName, "sharedOperation")
    XCTAssertEqual(loadAction.actionName, "sharedOperation")
    XCTAssertEqual(resetAction.actionName, "reset")

    // They should conflict with each other
    XCTAssertEqual(saveAction.createLockmanInfo().actionId, loadAction.createLockmanInfo().actionId)
    XCTAssertNotEqual(
      saveAction.createLockmanInfo().actionId, resetAction.createLockmanInfo().actionId)
  }

  // MARK: - LockmanAction Protocol Tests

  func testsingleExecutionActionIsLockmanAction() {
    // Test that SingleExecutionAction conforms to LockmanAction
    let action: any LockmanAction = SimpleAction()

    // Verify we can store it as LockmanAction
    let actions: [any LockmanAction] = [action]
    XCTAssertEqual(actions.count, 1)

    // Test type constraints are satisfied
    let info = action.createLockmanInfo() as? LockmanSingleExecutionInfo
    XCTAssertNotNil(info)
    XCTAssertEqual(info?.actionId, "simpleAction")
  }

  // MARK: - Integration Tests

  func testintegrationWithStrategyContainer() async {
    let container = LockmanStrategyContainer()
    try? container.register(LockmanSingleExecutionStrategy.shared)

    await LockmanManager.withTestContainer(container) {
      let action = SimpleAction()

      // Resolve strategy for the action
      do {
        let strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(
          id: action.createLockmanInfo().strategyId,
          expecting: LockmanSingleExecutionInfo.self
        )

        // Test locking behavior
        let boundaryId = "test-boundary"
        let info = action.createLockmanInfo()

        XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
        strategy.lock(boundaryId: boundaryId, info: info)
        XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: info))
        strategy.unlock(boundaryId: boundaryId, info: info)
        XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
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
    XCTAssertEqual(
      strategy.canLock(boundaryId: boundaryId, info: action1.createLockmanInfo()), .success)
    strategy.lock(boundaryId: boundaryId, info: action1.createLockmanInfo())

    // Second lock should fail (boundary is locked)
    XCTAssertLockFailure(
      strategy.canLock(boundaryId: boundaryId, info: action2.createLockmanInfo()))

    // Different action should also fail (boundary is locked)
    let action3 = ParameterizedAction.fetchUser(id: "456")
    XCTAssertLockFailure(
      strategy.canLock(boundaryId: boundaryId, info: action3.createLockmanInfo()))

    // Cleanup
    strategy.cleanUp()
  }

  // MARK: - Edge Cases

  func testemptyActionNameHandling() {
    struct EmptyNameAction: LockmanSingleExecutionAction {
      let actionName = ""

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = EmptyNameAction()
    XCTAssertEqual(action.actionName, "")
    XCTAssertEqual(action.createLockmanInfo().actionId, "")
    XCTAssertEqual(action.createLockmanInfo().strategyId, .singleExecution)
  }

  func testunicodeActionNameHandling() {
    struct UnicodeAction: LockmanSingleExecutionAction {
      let actionName = "🔒アクション🚀"

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = UnicodeAction()
    XCTAssertEqual(action.actionName, "🔒アクション🚀")
    XCTAssertEqual(action.createLockmanInfo().actionId, "🔒アクション🚀")
  }

  func testveryLongActionNameHandling() {
    struct LongNameAction: LockmanSingleExecutionAction {
      let actionName = String(repeating: "VeryLongActionName", count: 100)

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = LongNameAction()
    XCTAssertEqual(action.actionName.count, 1800)
    XCTAssertEqual(action.createLockmanInfo().actionId, action.actionName)
  }

  func testactionNameConsistencyAcrossInstances() {
    let action1 = SimpleAction()
    let action2 = SimpleAction()

    XCTAssertEqual(action1.actionName, action2.actionName)
    XCTAssertEqual(action1.createLockmanInfo().actionId, action2.createLockmanInfo().actionId)
    // But unique IDs should be different
    XCTAssertNotEqual(action1.createLockmanInfo().uniqueId, action2.createLockmanInfo().uniqueId)
  }
}
