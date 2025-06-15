
import Foundation
import Testing
@testable import LockmanCore

/// Tests for LockmanSingleExecutionAction protocol and implementations
@Suite("Single Execution Action Tests")
struct LockmanSingleExecutionActionTests {
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

  @Test("Simple action protocol conformance")
  func simpleActionProtocolConformance() {
    let action = SimpleAction()

    // Test actionName
    #expect(action.actionName == "simpleAction")

    // Test automatic strategyId
    #expect(action.strategyId == .singleExecution)

    // Test automatic lockmanInfo
    let info = action.lockmanInfo
    #expect(info.actionId == "simpleAction")
    #expect(info.uniqueId != UUID())
  }

  @Test("Parameterized action with unique names")
  func parameterizedActionUniqueNames() {
    let action1 = ParameterizedAction.fetchUser(id: "123")
    let action2 = ParameterizedAction.fetchUser(id: "456")
    let action3 = ParameterizedAction.updateProfile(userId: "123", name: "John")
    let action4 = ParameterizedAction.deletePost(postId: 789)

    // Each should have unique actionName
    #expect(action1.actionName == "fetchUser_123")
    #expect(action2.actionName == "fetchUser_456")
    #expect(action3.actionName == "updateProfile_123")
    #expect(action4.actionName == "deletePost_789")

    // All should use the same strategy ID
    #expect(action1.strategyId == .singleExecution)
    #expect(action2.strategyId == .singleExecution)
    #expect(action3.strategyId == .singleExecution)
    #expect(action4.strategyId == .singleExecution)

    // LockmanInfo should reflect the actionName
    #expect(action1.lockmanInfo.actionId == "fetchUser_123")
    #expect(action2.lockmanInfo.actionId == "fetchUser_456")
    #expect(action3.lockmanInfo.actionId == "updateProfile_123")
    #expect(action4.lockmanInfo.actionId == "deletePost_789")
  }

  @Test("Shared lock action behavior")
  func sharedLockActionBehavior() {
    let saveAction = SharedLockAction.save(data: "test data")
    let loadAction = SharedLockAction.load
    let resetAction = SharedLockAction.reset

    // Save and load share the same actionName
    #expect(saveAction.actionName == "sharedOperation")
    #expect(loadAction.actionName == "sharedOperation")
    #expect(resetAction.actionName == "reset")

    // They should conflict with each other
    #expect(saveAction.lockmanInfo.actionId == loadAction.lockmanInfo.actionId)
    #expect(saveAction.lockmanInfo.actionId != resetAction.lockmanInfo.actionId)
  }

  // MARK: - LockmanAction Protocol Tests

  @Test("SingleExecutionAction is LockmanAction")
  func singleExecutionActionIsLockmanAction() {
    // Test that SingleExecutionAction conforms to LockmanAction
    let action: any LockmanAction = SimpleAction()

    // Verify we can store it as LockmanAction
    let actions: [any LockmanAction] = [action]
    #expect(actions.count == 1)

    // Test type constraints are satisfied
    let info = action.lockmanInfo as? LockmanSingleExecutionInfo
    #expect(info != nil)
    #expect(info?.actionId == "simpleAction")
  }

  // MARK: - Integration Tests

  @Test("Integration with strategy container")
  func integrationWithStrategyContainer() async {
    let container = LockmanStrategyContainer()
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

        #expect(strategy.canLock(id: boundaryId, info: info) == .success)
        strategy.lock(id: boundaryId, info: info)
        #expect(strategy.canLock(id: boundaryId, info: info) == .failure)
        strategy.unlock(id: boundaryId, info: info)
        #expect(strategy.canLock(id: boundaryId, info: info) == .success)
      } catch {
        #expect(Bool(false), "Strategy resolution should succeed")
      }
    }
  }

  @Test("Concurrent execution prevention")
  func concurrentExecutionPrevention() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "test-boundary"

    // Test with same action
    let action1 = ParameterizedAction.fetchUser(id: "123")
    let action2 = ParameterizedAction.fetchUser(id: "123")

    // First lock should succeed
    #expect(strategy.canLock(id: boundaryId, info: action1.lockmanInfo) == .success)
    strategy.lock(id: boundaryId, info: action1.lockmanInfo)

    // Second lock should fail (boundary is locked)
    #expect(strategy.canLock(id: boundaryId, info: action2.lockmanInfo) == .failure)

    // Different action should also fail (boundary is locked)
    let action3 = ParameterizedAction.fetchUser(id: "456")
    #expect(strategy.canLock(id: boundaryId, info: action3.lockmanInfo) == .failure)

    // Cleanup
    strategy.cleanUp()
  }

  // MARK: - Edge Cases

  @Test("Empty actionName handling")
  func emptyActionNameHandling() {
    struct EmptyNameAction: LockmanSingleExecutionAction {
      let actionName = ""

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = EmptyNameAction()
    #expect(action.actionName == "")
    #expect(action.lockmanInfo.actionId == "")
    #expect(action.strategyId == .singleExecution)
  }

  @Test("Unicode actionName handling")
  func unicodeActionNameHandling() {
    struct UnicodeAction: LockmanSingleExecutionAction {
      let actionName = "🔒アクション🚀"

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = UnicodeAction()
    #expect(action.actionName == "🔒アクション🚀")
    #expect(action.lockmanInfo.actionId == "🔒アクション🚀")
  }

  @Test("Very long actionName handling")
  func veryLongActionNameHandling() {
    struct LongNameAction: LockmanSingleExecutionAction {
      let actionName = String(repeating: "VeryLongActionName", count: 100)

      var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
      }
    }

    let action = LongNameAction()
    #expect(action.actionName.count == 1800)
    #expect(action.lockmanInfo.actionId == action.actionName)
  }

  @Test("ActionName consistency across instances")
  func actionNameConsistencyAcrossInstances() {
    let action1 = SimpleAction()
    let action2 = SimpleAction()

    #expect(action1.actionName == action2.actionName)
    #expect(action1.lockmanInfo.actionId == action2.lockmanInfo.actionId)
    // But unique IDs should be different
    #expect(action1.lockmanInfo.uniqueId != action2.lockmanInfo.uniqueId)
  }
}
