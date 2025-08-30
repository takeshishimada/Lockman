import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive protocol tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanActionTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Test Action Types for Protocol Conformance
  
  // Basic LockmanInfo for testing
  private struct TestLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let priority: String
    
    init(strategyId: LockmanStrategyId = "TestStrategy", actionId: LockmanActionId = "testAction", priority: String = "medium") {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.priority = priority
    }
    
    var debugDescription: String {
      "TestLockmanInfo(actionId: '\(actionId)', priority: '\(priority)')"
    }
    
    var debugAdditionalInfo: String {
      "priority: \(priority)"
    }
  }
  
  // Basic action with default unlock option
  private struct TestBasicAction: LockmanAction {
    let actionId: LockmanActionId
    let priority: String
    
    init(actionId: LockmanActionId = "basicAction", priority: String = "medium") {
      self.actionId = actionId
      self.priority = priority
    }
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: actionId, priority: priority)
    }
  }
  
  // Action with custom unlock option
  private struct TestCustomUnlockAction: LockmanAction {
    let actionId: LockmanActionId
    let customUnlockOption: LockmanUnlockOption
    
    init(actionId: LockmanActionId = "customAction", unlockOption: LockmanUnlockOption = .immediate) {
      self.actionId = actionId
      self.customUnlockOption = unlockOption
    }
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: actionId, priority: "high")
    }
    
    var unlockOption: LockmanUnlockOption {
      customUnlockOption
    }
  }
  
  // Action using built-in LockmanInfo types
  private struct TestSingleExecutionAction: LockmanAction {
    let actionId: LockmanActionId
    let mode: LockmanSingleExecutionStrategy.ExecutionMode
    
    init(actionId: LockmanActionId = "singleAction", mode: LockmanSingleExecutionStrategy.ExecutionMode = .boundary) {
      self.actionId = actionId
      self.mode = mode
    }
    
    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionId, mode: mode)
    }
  }
  
  // Generic action for testing associatedtype constraints
  private struct TestGenericAction<T: LockmanInfo>: LockmanAction {
    let actionId: LockmanActionId
    let infoFactory: () -> T
    
    init(actionId: LockmanActionId, infoFactory: @escaping () -> T) {
      self.actionId = actionId
      self.infoFactory = infoFactory
    }
    
    func createLockmanInfo() -> T {
      infoFactory()
    }
  }
  
  // Class-based action
  private final class TestClassAction: LockmanAction {
    let actionId: LockmanActionId
    let creationTimestamp: Date
    
    init(actionId: LockmanActionId = "classAction") {
      self.actionId = actionId
      self.creationTimestamp = Date()
    }
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: actionId, priority: "low")
    }
    
    var unlockOption: LockmanUnlockOption {
      .mainRunLoop
    }
  }
  
  // Enum-based action
  private enum TestEnumAction: String, LockmanAction, CaseIterable {
    case login = "login"
    case logout = "logout"
    case fetchData = "fetchData"
    case syncData = "syncData"
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: self.rawValue, priority: "high")
    }
    
    var unlockOption: LockmanUnlockOption {
      switch self {
      case .login, .logout:
        return .transition
      case .fetchData, .syncData:
        return .immediate
      }
    }
  }
  
  // MARK: - Phase 1: Basic Protocol Conformance
  
  func testLockmanActionProtocolRequirements() {
    // Test basic protocol conformance
    let action = TestBasicAction(actionId: "protocolTest")
    
    // Should conform to Sendable
    XCTAssertNotNil(action as any Sendable)
    
    // Should have associated type constraint
    let info = action.createLockmanInfo()
    XCTAssertTrue(info is TestLockmanInfo)
    XCTAssertEqual(info.actionId, "protocolTest")
  }
  
  func testLockmanActionCreateLockmanInfo() {
    // Test createLockmanInfo method
    let action = TestBasicAction(actionId: "infoTest", priority: "critical")
    let info = action.createLockmanInfo()
    
    XCTAssertEqual(info.actionId, "infoTest")
    XCTAssertEqual(info.priority, "critical")
    XCTAssertNotNil(info.uniqueId)
    XCTAssertEqual(info.strategyId.value, "TestStrategy")
  }
  
  func testLockmanActionUniqueIdConsistency() {
    // Test that multiple calls generate different uniqueIds
    let action = TestBasicAction(actionId: "uniqueTest")
    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()
    let info3 = action.createLockmanInfo()
    
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertNotEqual(info1.uniqueId, info3.uniqueId)
    XCTAssertNotEqual(info2.uniqueId, info3.uniqueId)
    
    // But actionId should be the same
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info1.actionId, info3.actionId)
  }
  
  func testLockmanActionDefaultUnlockOption() {
    // Test default unlock option behavior
    let action = TestBasicAction()
    
    // Should use global default
    XCTAssertEqual(action.unlockOption, LockmanManager.config.defaultUnlockOption)
  }
  
  func testLockmanActionCustomUnlockOption() {
    // Test custom unlock option
    let immediateAction = TestCustomUnlockAction(unlockOption: .immediate)
    let transitionAction = TestCustomUnlockAction(unlockOption: .transition)
    let delayedAction = TestCustomUnlockAction(unlockOption: .delayed(2.0))
    
    switch immediateAction.unlockOption {
    case .immediate:
      XCTAssertTrue(true) // Expected
    default:
      XCTFail("Should be immediate")
    }
    
    switch transitionAction.unlockOption {
    case .transition:
      XCTAssertTrue(true) // Expected
    default:
      XCTFail("Should be transition")
    }
    
    switch delayedAction.unlockOption {
    case .delayed(let interval):
      XCTAssertEqual(interval, 2.0, accuracy: 0.001)
    default:
      XCTFail("Should be delayed")
    }
  }
  
  // MARK: - Phase 2: Built-in LockmanInfo Integration
  
  func testLockmanActionWithSingleExecutionInfo() {
    // Test action using built-in info type
    let boundaryAction = TestSingleExecutionAction(actionId: "boundaryTest", mode: .boundary)
    let noneAction = TestSingleExecutionAction(actionId: "noneTest", mode: .none)
    
    let boundaryInfo = boundaryAction.createLockmanInfo()
    let noneInfo = noneAction.createLockmanInfo()
    
    XCTAssertEqual(boundaryInfo.actionId, "boundaryTest")
    XCTAssertEqual(boundaryInfo.mode, .boundary)
    XCTAssertTrue(boundaryInfo.strategyId.value.contains("SingleExecution"))
    
    XCTAssertEqual(noneInfo.actionId, "noneTest")
    XCTAssertEqual(noneInfo.mode, .none)
  }
  
  func testLockmanActionWithPriorityBasedInfo() {
    // Test with PriorityBasedInfo (if available)
    struct TestPriorityAction: LockmanAction {
      let actionId: LockmanActionId
      let priority: LockmanPriorityBasedInfo.Priority
      
      func createLockmanInfo() -> LockmanPriorityBasedInfo {
        LockmanPriorityBasedInfo(actionId: actionId, priority: priority)
      }
    }
    
    let highAction = TestPriorityAction(actionId: "highPriority", priority: .high(.exclusive))
    let lowAction = TestPriorityAction(actionId: "lowPriority", priority: .low(.exclusive))
    
    let highInfo = highAction.createLockmanInfo()
    let lowInfo = lowAction.createLockmanInfo()
    
    XCTAssertEqual(highInfo.actionId, "highPriority")
    XCTAssertEqual(lowInfo.actionId, "lowPriority")
    
    switch highInfo.priority {
    case .high(.exclusive):
      XCTAssertTrue(true)
    default:
      XCTFail("Should be high priority with exclusive")
    }
  }
  
  // MARK: - Phase 3: Type System and Generics
  
  func testLockmanActionAssociatedType() {
    // Test associated type constraints work correctly
    let basicAction = TestBasicAction(actionId: "associatedTest")
    let singleAction = TestSingleExecutionAction(actionId: "associatedTest2")
    
    // Both should create different types
    let basicInfo: TestLockmanInfo = basicAction.createLockmanInfo()
    let singleInfo: LockmanSingleExecutionInfo = singleAction.createLockmanInfo()
    
    XCTAssertEqual(basicInfo.actionId, "associatedTest")
    XCTAssertEqual(singleInfo.actionId, "associatedTest2")
    
    // Should not be the same type
    XCTAssertFalse(basicInfo is LockmanSingleExecutionInfo)
    XCTAssertFalse(singleInfo is TestLockmanInfo)
  }
  
  func testLockmanActionGenericConstraints() {
    // Test generic actions with type constraints
    let testInfoAction = TestGenericAction(actionId: "genericTest") {
      TestLockmanInfo(actionId: "genericCreated", priority: "generic")
    }
    
    let singleInfoAction = TestGenericAction(actionId: "singleGeneric") {
      LockmanSingleExecutionInfo(actionId: "singleCreated", mode: .boundary)
    }
    
    let testInfo = testInfoAction.createLockmanInfo()
    let singleInfo = singleInfoAction.createLockmanInfo()
    
    XCTAssertEqual(testInfo.actionId, "genericCreated")
    XCTAssertEqual(singleInfo.actionId, "singleCreated")
    XCTAssertTrue(testInfo is TestLockmanInfo)
    XCTAssertTrue(singleInfo is LockmanSingleExecutionInfo)
  }
  
  func testLockmanActionTypeErasure() {
    // Test different action types in collection
    let actions: [any LockmanAction] = [
      TestBasicAction(actionId: "action1"),
      TestCustomUnlockAction(actionId: "action2"),
      TestSingleExecutionAction(actionId: "action3"),
      TestClassAction(actionId: "action4")
    ]
    
    XCTAssertEqual(actions.count, 4)
    
    // Test we can access common properties through type erasure
    for action in actions {
      XCTAssertNotNil(action.unlockOption)
      // Note: createLockmanInfo() returns 'any LockmanInfo' through type erasure
    }
  }
  
  // MARK: - Phase 4: Different Type Conformance Patterns
  
  func testLockmanActionStructConformance() {
    // Test struct-based conformance
    let action = TestBasicAction(actionId: "structTest")
    let info = action.createLockmanInfo()
    
    XCTAssertEqual(info.actionId, "structTest")
    XCTAssertEqual(action.unlockOption, LockmanManager.config.defaultUnlockOption)
  }
  
  func testLockmanActionClassConformance() {
    // Test class-based conformance
    let action = TestClassAction(actionId: "classTest")
    let info = action.createLockmanInfo()
    
    XCTAssertEqual(info.actionId, "classTest")
    XCTAssertEqual(info.priority, "low")
    
    switch action.unlockOption {
    case .mainRunLoop:
      XCTAssertTrue(true)
    default:
      XCTFail("Should be mainRunLoop")
    }
    
    XCTAssertNotNil(action.creationTimestamp)
  }
  
  func testLockmanActionEnumConformance() {
    // Test enum-based conformance
    let loginAction = TestEnumAction.login
    let fetchAction = TestEnumAction.fetchData
    
    let loginInfo = loginAction.createLockmanInfo()
    let fetchInfo = fetchAction.createLockmanInfo()
    
    XCTAssertEqual(loginInfo.actionId, "login")
    XCTAssertEqual(fetchInfo.actionId, "fetchData")
    
    switch loginAction.unlockOption {
    case .transition:
      XCTAssertTrue(true)
    default:
      XCTFail("Login should use transition")
    }
    
    switch fetchAction.unlockOption {
    case .immediate:
      XCTAssertTrue(true)
    default:
      XCTFail("Fetch should use immediate")
    }
  }
  
  func testLockmanActionEnumAllCases() {
    // Test all enum cases
    for actionCase in TestEnumAction.allCases {
      let info = actionCase.createLockmanInfo()
      XCTAssertEqual(info.actionId, actionCase.rawValue)
      XCTAssertEqual(info.priority, "high")
      XCTAssertNotNil(actionCase.unlockOption)
    }
  }
  
  // MARK: - Phase 5: Real-world Usage Patterns
  
  func testLockmanActionDocumentationExamples() {
    // Test examples from documentation
    struct MyAction: LockmanAction {
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: "myAction",
          mode: .boundary
        )
      }
    }
    
    struct TransitionAction: LockmanAction {
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: "transition",
          mode: .boundary
        )
      }
      
      var unlockOption: LockmanUnlockOption { .transition }
    }
    
    let myAction = MyAction()
    let transitionAction = TransitionAction()
    
    let myInfo = myAction.createLockmanInfo()
    let transitionInfo = transitionAction.createLockmanInfo()
    
    XCTAssertEqual(myInfo.actionId, "myAction")
    XCTAssertEqual(myInfo.mode, .boundary)
    
    XCTAssertEqual(transitionInfo.actionId, "transition")
    XCTAssertEqual(transitionInfo.mode, .boundary)
    
    XCTAssertEqual(myAction.unlockOption, LockmanManager.config.defaultUnlockOption)
    
    switch transitionAction.unlockOption {
    case .transition:
      XCTAssertTrue(true)
    default:
      XCTFail("Should be transition")
    }
  }
  
  func testLockmanActionCustomStrategyExample() {
    // Test custom strategy example from documentation
    struct CustomLockInfo: LockmanInfo {
      let strategyId: LockmanStrategyId
      let actionId: LockmanActionId
      let uniqueId: UUID
      
      init(strategyId: LockmanStrategyId, actionId: LockmanActionId) {
        self.strategyId = strategyId
        self.actionId = actionId
        self.uniqueId = UUID()
      }
      
      var debugDescription: String {
        "CustomLockInfo(actionId: \(actionId), strategyId: \(strategyId))"
      }
    }
    
    struct ConfiguredAction: LockmanAction {
      func createLockmanInfo() -> CustomLockInfo {
        CustomLockInfo(
          strategyId: LockmanStrategyId(
            name: "RateLimitStrategy",
            configuration: "limit-100"
          ),
          actionId: "apiCall"
        )
      }
    }
    
    let action = ConfiguredAction()
    let info = action.createLockmanInfo()
    
    XCTAssertEqual(info.actionId, "apiCall")
    XCTAssertEqual(info.strategyId.value, "RateLimitStrategy:limit-100")
  }
  
  func testLockmanActionSendableRequirement() async {
    // Test Sendable conformance with concurrent access
    let action = TestBasicAction(actionId: "sendableTest")
    
    await withTaskGroup(of: String.self) { group in
      group.addTask {
        // This compiles without warning = Sendable works
        let info = action.createLockmanInfo()
        return "Task1: \(info.actionId)"
      }
      group.addTask {
        let info = action.createLockmanInfo()
        return "Task2: \(info.uniqueId)"
      }
      
      var results: [String] = []
      for await result in group {
        results.append(result)
      }
      
      XCTAssertEqual(results.count, 2)
      XCTAssertTrue(results.contains("Task1: sendableTest"))
    }
  }
  
  func testLockmanActionUnlockOptionVariations() {
    // Test all unlock option variations
    let immediateAction = TestCustomUnlockAction(unlockOption: .immediate)
    let transitionAction = TestCustomUnlockAction(unlockOption: .transition)
    let mainRunLoopAction = TestCustomUnlockAction(unlockOption: .mainRunLoop)
    let delayedAction = TestCustomUnlockAction(unlockOption: .delayed(1.5))
    
    let actions = [immediateAction, transitionAction, mainRunLoopAction, delayedAction]
    
    for action in actions {
      let info = action.createLockmanInfo()
      XCTAssertNotNil(info.actionId)
      XCTAssertNotNil(action.unlockOption)
    }
    
    // Verify specific options
    switch immediateAction.unlockOption {
    case .immediate: break
    default: XCTFail("Should be immediate")
    }
    
    switch transitionAction.unlockOption {
    case .transition: break
    default: XCTFail("Should be transition")
    }
    
    switch mainRunLoopAction.unlockOption {
    case .mainRunLoop: break
    default: XCTFail("Should be mainRunLoop")
    }
    
    switch delayedAction.unlockOption {
    case .delayed(let interval):
      XCTAssertEqual(interval, 1.5, accuracy: 0.001)
    default:
      XCTFail("Should be delayed")
    }
  }

}
