import XCTest

@testable import Lockman

/// Unit tests for LockmanAction
///
/// Tests the base protocol for actions participating in Lockman's locking mechanism.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance
/// - [ ] Sendable protocol compliance validation
/// - [ ] Associated type I: LockmanInfo constraint
/// - [ ] Protocol requirement fulfillment verification
/// - [ ] Generic type parameter validation
/// - [ ] Type safety across action implementations
///
/// ### createLockmanInfo() Method Testing
/// - [ ] Method implementation requirement
/// - [ ] Associated type I return validation
/// - [ ] Method call consistency across instances
/// - [ ] Return value immutability
/// - [ ] Once-per-operation call pattern validation
/// - [ ] UniqueId consistency throughout lock lifecycle
///
/// ### Associated Type Constraint Validation
/// - [ ] I: LockmanInfo constraint enforcement
/// - [ ] Concrete type compatibility validation
/// - [ ] Type inference from createLockmanInfo() return
/// - [ ] Generic type parameter resolution
/// - [ ] Compile-time type checking validation
///
/// ### unlockOption Property Behavior
/// - [ ] unlockOption property requirement
/// - [ ] Default implementation using global config
/// - [ ] LockmanManager.config.defaultUnlockOption integration
/// - [ ] Custom unlockOption override behavior
/// - [ ] LockmanUnlockOption value validation
///
/// ### Lock Information Creation Patterns
/// - [ ] Simple action lock info creation
/// - [ ] Parameter-specific action lock info
/// - [ ] Strategy-specific lock info configuration
/// - [ ] Custom strategyId usage in lock info
/// - [ ] Complex lock info composition
///
/// ### Strategy Integration
/// - [ ] StrategyId determination from lock info
/// - [ ] Strategy container resolution compatibility
/// - [ ] Action-strategy coordination
/// - [ ] Lock acquisition through action protocol
/// - [ ] Strategy flexibility through lock info
///
/// ### Unlock Timing Control
/// - [ ] Default unlock timing (.action) behavior
/// - [ ] Custom unlock timing (.transition) behavior
/// - [ ] Unlock timing impact on lock lifecycle
/// - [ ] Strategy-specific unlock timing requirements
/// - [ ] Global configuration override patterns
///
/// ### Thread Safety & Sendable
/// - [ ] Sendable compliance across concurrent contexts
/// - [ ] Thread-safe createLockmanInfo() calls
/// - [ ] Immutable action behavior
/// - [ ] Safe concurrent access to properties
/// - [ ] No shared mutable state verification
///
/// ### Performance & Scalability
/// - [ ] createLockmanInfo() performance benchmarks
/// - [ ] Lock info creation performance
/// - [ ] Action instance creation performance
/// - [ ] Memory usage with many action instances
/// - [ ] UUID generation performance impact
///
/// ### Real-world Implementation Patterns
/// - [ ] MyAction simple implementation example
/// - [ ] TransitionAction custom unlock timing example
/// - [ ] ConfiguredAction custom strategy example
/// - [ ] Complex action with multiple parameters
/// - [ ] Strategy-specific action implementations
///
/// ### Integration with Action Types
/// - [ ] LockmanSingleExecutionAction conformance
/// - [ ] LockmanPriorityBasedAction conformance
/// - [ ] LockmanCompositeAction conformance
/// - [ ] LockmanConcurrencyLimitedAction conformance
/// - [ ] LockmanGroupCoordinatedAction conformance
/// - [ ] Custom action type implementations
///
/// ### Edge Cases & Error Conditions
/// - [ ] createLockmanInfo() multiple calls behavior
/// - [ ] Invalid lock info creation scenarios
/// - [ ] Memory pressure with action creation
/// - [ ] Action lifecycle edge cases
///
/// ### Documentation Examples Validation
/// - [ ] MyAction example implementation
/// - [ ] TransitionAction example with custom unlock
/// - [ ] ConfiguredAction example with custom strategy
/// - [ ] Code example correctness verification
/// - [ ] Usage pattern validation from documentation
///
/// ### Type Erasure & Generics
/// - [ ] Type erasure compatibility
/// - [ ] Generic type parameter inference
/// - [ ] Associated type constraint validation
/// - [ ] Runtime type safety validation
///
final class LockmanActionTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock Actions for Testing

  private struct MockSimpleAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        actionId: LockmanActionId("mock-simple"),
        mode: .boundary
      )
    }
  }

  private struct MockCustomUnlockAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        actionId: LockmanActionId("mock-custom"),
        mode: .action
      )
    }

    var unlockOption: LockmanUnlockOption { .transition }
  }

  private struct MockPriorityAction: LockmanAction {
    typealias I = LockmanPriorityBasedInfo

    let priority: LockmanPriorityBasedInfo.Priority

    init(priority: LockmanPriorityBasedInfo.Priority = .high(.exclusive)) {
      self.priority = priority
    }

    func createLockmanInfo() -> LockmanPriorityBasedInfo {
      return LockmanPriorityBasedInfo(
        actionId: LockmanActionId("mock-priority"),
        priority: priority
      )
    }
  }

  private struct MockParameterizedAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    let userId: String

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        actionId: LockmanActionId("fetchUser_\(userId)"),
        mode: .action
      )
    }
  }

  private struct MockCustomStrategyAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    let customStrategyId: LockmanStrategyId

    init(customStrategyId: LockmanStrategyId = LockmanStrategyId("custom-strategy")) {
      self.customStrategyId = customStrategyId
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        strategyId: customStrategyId,
        actionId: LockmanActionId("custom-action"),
        mode: .boundary
      )
    }

    var unlockOption: LockmanUnlockOption { .delayed(0.5) }
  }

  // MARK: - Protocol Conformance Tests

  func testProtocolSendableConformance() {
    let action = MockSimpleAction()

    let expectation = XCTestExpectation(description: "Sendable conformance")

    DispatchQueue.global().async {
      // Access action in concurrent context
      _ = action.createLockmanInfo()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testAssociatedTypeConstraint() {
    let action = MockSimpleAction()
    let info = action.createLockmanInfo()

    // Verify associated type conforms to LockmanInfo
    XCTAssertTrue(info is any LockmanInfo)
    XCTAssertNotNil(info.actionId)
    XCTAssertNotNil(info.uniqueId)
    XCTAssertNotNil(info.strategyId)
  }

  func testGenericTypeParameterResolution() {
    let simpleAction = MockSimpleAction()
    let priorityAction = MockPriorityAction()

    let simpleInfo = simpleAction.createLockmanInfo()
    let priorityInfo = priorityAction.createLockmanInfo()

    // Type inference should work correctly
    XCTAssertTrue(simpleInfo is LockmanSingleExecutionInfo)
    XCTAssertTrue(priorityInfo is LockmanPriorityBasedInfo)
  }

  // MARK: - createLockmanInfo() Method Tests

  func testCreateLockmanInfoRequirement() {
    let action = MockSimpleAction()

    let info = action.createLockmanInfo()

    XCTAssertNotNil(info)
    XCTAssertEqual(info.actionId, LockmanActionId("mock-simple"))
    XCTAssertEqual(info.strategyId, .singleExecution)
    XCTAssertEqual(info.mode, .boundary)
  }

  func testCreateLockmanInfoReturnValueConsistency() {
    let action = MockSimpleAction()

    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()

    // ActionId should be same, but uniqueId should be different (new instances)
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertEqual(info1.strategyId, info2.strategyId)
    XCTAssertEqual(info1.mode, info2.mode)
  }

  func testCreateLockmanInfoUniqueIdConsistency() {
    let action = MockSimpleAction()

    // Each call should create a new instance with different uniqueId
    let instances = (0..<10).map { _ in action.createLockmanInfo() }
    let uniqueIds = Set(instances.map { $0.uniqueId })

    // All uniqueIds should be different
    XCTAssertEqual(uniqueIds.count, instances.count)

    // But other properties should be consistent
    let actionIds = Set(instances.map { $0.actionId })
    XCTAssertEqual(actionIds.count, 1)
  }

  func testCreateLockmanInfoWithDifferentActionTypes() {
    let simpleAction = MockSimpleAction()
    let priorityAction = MockPriorityAction(priority: .low(.replaceable))

    let simpleInfo = simpleAction.createLockmanInfo()
    let priorityInfo = priorityAction.createLockmanInfo()

    // Different action types should create different info types
    XCTAssertEqual(simpleInfo.actionId, LockmanActionId("mock-simple"))
    XCTAssertEqual(priorityInfo.actionId, LockmanActionId("mock-priority"))
    XCTAssertEqual(priorityInfo.priority, .low(.replaceable))
  }

  // MARK: - unlockOption Property Tests

  func testDefaultUnlockOptionImplementation() {
    let action = MockSimpleAction()

    // Should use global default
    let originalDefault = LockmanManager.config.defaultUnlockOption
    defer { LockmanManager.config.defaultUnlockOption = originalDefault }

    LockmanManager.config.defaultUnlockOption = .immediate
    XCTAssertEqual(action.unlockOption, .immediate)

    LockmanManager.config.defaultUnlockOption = .transition
    XCTAssertEqual(action.unlockOption, .transition)

    LockmanManager.config.defaultUnlockOption = .delayed(1.0)
    XCTAssertEqual(action.unlockOption, .delayed(1.0))
  }

  func testCustomUnlockOptionOverride() {
    let action = MockCustomUnlockAction()

    // Should use custom override, not global default
    let originalDefault = LockmanManager.config.defaultUnlockOption
    defer { LockmanManager.config.defaultUnlockOption = originalDefault }

    LockmanManager.config.defaultUnlockOption = .immediate
    XCTAssertEqual(action.unlockOption, .transition)  // Custom override
  }

  func testUnlockOptionVariousValues() {
    let delayedAction = MockCustomStrategyAction()

    XCTAssertEqual(delayedAction.unlockOption, .delayed(0.5))
  }

  // MARK: - Lock Information Creation Patterns

  func testSimpleActionLockInfoCreation() {
    let action = MockSimpleAction()
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("mock-simple"))
    XCTAssertEqual(info.strategyId, .singleExecution)
    XCTAssertEqual(info.mode, .boundary)
    XCTAssertNotNil(info.uniqueId)
  }

  func testParameterSpecificActionLockInfo() {
    let action1 = MockParameterizedAction(userId: "123")
    let action2 = MockParameterizedAction(userId: "456")

    let info1 = action1.createLockmanInfo()
    let info2 = action2.createLockmanInfo()

    XCTAssertEqual(info1.actionId, LockmanActionId("fetchUser_123"))
    XCTAssertEqual(info2.actionId, LockmanActionId("fetchUser_456"))
    XCTAssertNotEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info1.mode, info2.mode)
  }

  func testCustomStrategyLockInfoConfiguration() {
    let customStrategyId = LockmanStrategyId("rate-limit-strategy")
    let action = MockCustomStrategyAction(customStrategyId: customStrategyId)
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.strategyId, customStrategyId)
    XCTAssertEqual(info.actionId, LockmanActionId("custom-action"))
    XCTAssertEqual(info.mode, .boundary)
  }

  func testComplexLockInfoComposition() {
    let priorityAction = MockPriorityAction(priority: .high(.exclusive))
    let info = priorityAction.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("mock-priority"))
    XCTAssertEqual(info.strategyId, .priorityBased)
    XCTAssertEqual(info.priority, .high(.exclusive))
    XCTAssertNotNil(info.uniqueId)
  }

  // MARK: - Strategy Integration Tests

  func testStrategyIdDeterminationFromLockInfo() {
    let singleAction = MockSimpleAction()
    let priorityAction = MockPriorityAction()
    let customAction = MockCustomStrategyAction()

    let singleInfo = singleAction.createLockmanInfo()
    let priorityInfo = priorityAction.createLockmanInfo()
    let customInfo = customAction.createLockmanInfo()

    XCTAssertEqual(singleInfo.strategyId, .singleExecution)
    XCTAssertEqual(priorityInfo.strategyId, .priorityBased)
    XCTAssertEqual(customInfo.strategyId, LockmanStrategyId("custom-strategy"))
  }

  func testActionStrategyCoordination() {
    let action = MockPriorityAction(priority: .low(.replaceable))
    let info = action.createLockmanInfo()

    // Action and its lock info should be compatible
    XCTAssertEqual(info.priority, .low(.replaceable))
    XCTAssertEqual(action.unlockOption, LockmanManager.config.defaultUnlockOption)
  }

  // MARK: - Thread Safety & Sendable Tests

  func testSendableComplianceAcrossConcurrentContexts() {
    let action = MockSimpleAction()
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        let info = action.createLockmanInfo()
        XCTAssertNotNil(info.actionId)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testThreadSafeCreateLockmanInfoCalls() {
    let action = MockSimpleAction()
    let lock = NSLock()
    var infos: [LockmanSingleExecutionInfo] = []

    let expectation = XCTestExpectation(description: "Thread safe calls")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let info = action.createLockmanInfo()
        lock.lock()
        infos.append(info)
        lock.unlock()
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)

    // All calls should succeed
    XCTAssertEqual(infos.count, 5)

    // All should have same actionId but different uniqueIds
    let actionIds = Set(infos.map { $0.actionId })
    let uniqueIds = Set(infos.map { $0.uniqueId })

    XCTAssertEqual(actionIds.count, 1)
    XCTAssertEqual(uniqueIds.count, 5)
  }

  func testImmutableActionBehavior() {
    let action = MockParameterizedAction(userId: "test")

    // Multiple calls should not change action state
    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()
    let info3 = action.createLockmanInfo()

    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info2.actionId, info3.actionId)
    XCTAssertEqual(info1.actionId, LockmanActionId("fetchUser_test"))
  }

  // MARK: - Performance & Scalability Tests

  func testCreateLockmanInfoPerformance() {
    let action = MockSimpleAction()

    measure {
      for _ in 0..<1000 {
        _ = action.createLockmanInfo()
      }
    }
  }

  func testLockInfoCreationPerformance() {
    let actions = (0..<100).map { MockParameterizedAction(userId: "\($0)") }

    measure {
      for action in actions {
        _ = action.createLockmanInfo()
      }
    }
  }

  func testMemoryUsageWithManyActionInstances() {
    // Test memory efficiency with many action instances
    // Since MockSimpleAction is a struct (value type), we test performance instead
    let actionCount = 1000
    var actions: [MockSimpleAction] = []
    
    // Measure memory usage indirectly through performance
    measure {
      actions.removeAll()
      for _ in 0..<actionCount {
        let action = MockSimpleAction()
        let _ = action.createLockmanInfo()
        actions.append(action)
      }
    }
    
    XCTAssertEqual(actions.count, actionCount, "Should create all actions efficiently")
  }

  func testUUIDGenerationPerformanceImpact() {
    let action = MockSimpleAction()
    let startTime = CFAbsoluteTimeGetCurrent()

    // Generate many lock infos (each creates a new UUID)
    let infos = (0..<1000).map { _ in action.createLockmanInfo() }

    let duration = CFAbsoluteTimeGetCurrent() - startTime

    XCTAssertEqual(infos.count, 1000)
    XCTAssertLessThan(duration, 1.0, "UUID generation should be fast")
  }

  // MARK: - Real-world Implementation Patterns

  func testMyActionSimpleImplementationExample() {
    // Based on documentation example
    struct MyAction: LockmanAction {
      typealias I = LockmanSingleExecutionInfo

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: LockmanActionId("myAction"),
          mode: .boundary
        )
      }
    }

    let action = MyAction()
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("myAction"))
    XCTAssertEqual(info.mode, .boundary)
    XCTAssertEqual(info.strategyId, .singleExecution)
    XCTAssertEqual(action.unlockOption, LockmanManager.config.defaultUnlockOption)
  }

  func testTransitionActionCustomUnlockExample() {
    // Based on documentation example
    struct TransitionAction: LockmanAction {
      typealias I = LockmanSingleExecutionInfo

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: LockmanActionId("transition"),
          mode: .boundary
        )
      }

      var unlockOption: LockmanUnlockOption { .transition }
    }

    let action = TransitionAction()
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("transition"))
    XCTAssertEqual(info.mode, .boundary)
    XCTAssertEqual(action.unlockOption, .transition)
  }

  func testConfiguredActionCustomStrategyExample() {
    // Based on documentation example (simplified)
    struct ConfiguredAction: LockmanAction {
      typealias I = LockmanSingleExecutionInfo

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          strategyId: LockmanStrategyId("RateLimitStrategy"),
          actionId: LockmanActionId("apiCall"),
          mode: .action
        )
      }
    }

    let action = ConfiguredAction()
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.strategyId, LockmanStrategyId("RateLimitStrategy"))
    XCTAssertEqual(info.actionId, LockmanActionId("apiCall"))
    XCTAssertEqual(info.mode, .action)
  }

  func testComplexActionWithMultipleParameters() {
    struct ComplexAction: LockmanAction {
      typealias I = LockmanPriorityBasedInfo

      let userId: String
      let operation: String
      let priority: LockmanPriorityBasedInfo.Priority

      func createLockmanInfo() -> LockmanPriorityBasedInfo {
        LockmanPriorityBasedInfo(
          actionId: LockmanActionId("\(operation)_\(userId)"),
          priority: priority
        )
      }

      var unlockOption: LockmanUnlockOption {
        switch operation {
        case "save": return .transition
        case "fetch": return .immediate
        default: return .mainRunLoop
        }
      }
    }

    let action = ComplexAction(
      userId: "123",
      operation: "save",
      priority: .high(.exclusive)
    )

    let info = action.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("save_123"))
    XCTAssertEqual(info.priority, .high(.exclusive))
    XCTAssertEqual(action.unlockOption, .transition)
  }

  // MARK: - Integration with Action Types

  func testLockmanSingleExecutionActionConformance() {
    // Test with existing concrete action type
    enum TestAction: LockmanSingleExecutionAction {
      case login
      case logout

      var actionName: String {
        switch self {
        case .login: return "login"
        case .logout: return "logout"
        }
      }

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        return LockmanSingleExecutionInfo(
          actionId: LockmanActionId(actionName),
          mode: .action
        )
      }
    }

    let action = TestAction.login
    let info = action.createLockmanInfo()

    XCTAssertEqual(info.actionId, LockmanActionId("login"))
    XCTAssertEqual(info.mode, .action)
    XCTAssertEqual(action.actionName, "login")
  }

  // MARK: - Edge Cases & Error Conditions

  func testCreateLockmanInfoMultipleCallsBehavior() {
    let action = MockSimpleAction()

    // Multiple calls should work fine but create different instances
    let infos = (0..<5).map { _ in action.createLockmanInfo() }

    // All should have same actionId
    let actionIds = Set(infos.map { $0.actionId })
    XCTAssertEqual(actionIds.count, 1)

    // But different uniqueIds
    let uniqueIds = Set(infos.map { $0.uniqueId })
    XCTAssertEqual(uniqueIds.count, 5)
  }

  func testActionLifecycleEdgeCases() {
    // Test that actions can be created and used immediately
    let info1 = MockSimpleAction().createLockmanInfo()
    let info2 = MockParameterizedAction(userId: "temp").createLockmanInfo()

    XCTAssertNotNil(info1.actionId)
    XCTAssertNotNil(info2.actionId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  // MARK: - Type Erasure & Generics

  func testTypeErasureCompatibility() {
    let simpleAction: any LockmanAction = MockSimpleAction()
    let priorityAction: any LockmanAction = MockPriorityAction()

    // Type erasure should maintain functionality
    XCTAssertEqual(simpleAction.unlockOption, LockmanManager.config.defaultUnlockOption)
    XCTAssertEqual(priorityAction.unlockOption, LockmanManager.config.defaultUnlockOption)
  }

  func testGenericTypeParameterInference() {
    func testAction<A: LockmanAction>(_ action: A) -> A.I {
      return action.createLockmanInfo()
    }

    let simpleInfo = testAction(MockSimpleAction())
    let priorityInfo = testAction(MockPriorityAction())

    XCTAssertTrue(simpleInfo is LockmanSingleExecutionInfo)
    XCTAssertTrue(priorityInfo is LockmanPriorityBasedInfo)
  }

  func testRuntimeTypeSafetyValidation() {
    let actions: [any LockmanAction] = [
      MockSimpleAction(),
      MockCustomUnlockAction(),
      MockPriorityAction(),
      MockParameterizedAction(userId: "runtime-test"),
    ]

    for action in actions {
      // All should conform to protocol and work correctly
      XCTAssertNotNil(action.unlockOption)
      // Note: can't call createLockmanInfo() on type-erased action due to associated type
    }
  }
}
