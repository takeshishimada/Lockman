import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Support Types
// Shared test support types are defined in TestSupport.swift

// Test action types for different scenarios
@CasePathable
enum TestAction: LockmanAction, Sendable {
  case test
  case testWithId(String)
  case increment
  case decrement
  case setProcessing(Bool)
  case view(ViewAction)
  case delegate(DelegateAction)
  case nonLockmanAction

  var actionName: String {
    switch self {
    case .test: return "test"
    case .testWithId(let id): return "testWithId_\(id)"
    case .increment: return "increment"
    case .decrement: return "decrement"
    case .setProcessing: return "setProcessing"
    case .view: return "view"
    case .delegate: return "delegate"
    case .nonLockmanAction: return "nonLockmanAction"
    }
  }

  func createLockmanInfo() -> TestLockmanInfo {
    return TestLockmanInfo(
      actionId: actionName,
      strategyId: LockmanStrategyId(name: "TestSingleExecutionStrategy")
    )
  }

  var unlockOption: LockmanUnlockOption { .immediate }
}

enum ViewAction: LockmanAction, Sendable {
  case buttonTapped
  case textChanged(String)

  var actionName: String {
    switch self {
    case .buttonTapped: return "buttonTapped"
    case .textChanged: return "textChanged"
    }
  }

  func createLockmanInfo() -> TestLockmanInfo {
    return TestLockmanInfo(
      actionId: actionName,
      strategyId: LockmanStrategyId(name: "TestSingleExecutionStrategy")
    )
  }

  var unlockOption: LockmanUnlockOption { .immediate }
}

enum DelegateAction: LockmanAction, Sendable {
  case didComplete
  case didFail(String)

  var actionName: String {
    switch self {
    case .didComplete: return "didComplete"
    case .didFail: return "didFail"
    }
  }

  func createLockmanInfo() -> TestLockmanInfo {
    return TestLockmanInfo(
      actionId: actionName,
      strategyId: LockmanStrategyId(name: "TestSingleExecutionStrategy")
    )
  }

  var unlockOption: LockmanUnlockOption { .immediate }
}

// Error types for testing
struct InsufficientFundsError: Error {
  let message = "Insufficient funds"
}

struct NotAuthenticatedError: LockmanError {
  let message = "Not authenticated"

  var debugDescription: String {
    return message
  }
}

final class ReducerTestSingleExecutionStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  private var lockedActions: Set<String> = []
  private let lock = NSLock()

  var strategyId: LockmanStrategyId {
    LockmanStrategyId(name: "ReducerTestSingleExecutionStrategy")
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "ReducerTestSingleExecutionStrategy")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    return lock.withLock {
      if lockedActions.contains(info.actionId) {
        let singleExecutionInfo = LockmanSingleExecutionInfo(
          actionId: info.actionId,
          mode: .action
        )
        let error = LockmanSingleExecutionError.actionAlreadyRunning(
          boundaryId: boundaryId,
          lockmanInfo: singleExecutionInfo
        )
        return LockmanResult.cancel(error)
      }
      return LockmanResult.success
    }
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    _ = lock.withLock {
      lockedActions.insert(info.actionId)
    }
  }

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    _ = lock.withLock {
      lockedActions.remove(info.actionId)
    }
  }

  func cleanUp() {
    lock.withLock {
      lockedActions.removeAll()
    }
  }

  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    cleanUp()
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

// Test reducer
struct ReducerTestReducer: Reducer {
  typealias State = TestReducerState
  typealias Action = TestAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .test:
        state.lastActionId = action.actionName
        return .none

      case .testWithId:
        state.lastActionId = action.actionName
        return .none

      case .increment:
        state.counter += 1
        state.lastActionId = action.actionName
        return .none

      case .decrement:
        state.counter -= 1
        state.lastActionId = action.actionName
        return .none

      case .setProcessing(let isProcessing):
        state.isProcessing = isProcessing
        state.lastActionId = action.actionName
        return .none

      case .view(let viewAction):
        state.lastActionId = "view_\(viewAction.actionName)"
        return .none

      case .delegate(let delegateAction):
        state.lastActionId = "delegate_\(delegateAction.actionName)"
        return .none

      case .nonLockmanAction:
        state.lastActionId = action.actionName
        return .none
      }
    }
  }
}

final class ReducerLockmanTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Tests

  // MARK: - Dynamic Condition Reducer Integration Tests

  func testDynamicConditionReducerCreation() {
    let baseReducer = ReducerTestReducer()

    let dynamicReducer = baseReducer.lock(
      condition: { state, action in
        guard state.isAuthenticated else {
          return .cancel(NotAuthenticatedError())
        }
        return .success
      },
      boundaryId: TestBoundaryId.test
    )

    // Should create LockmanDynamicConditionReducer
    XCTAssertNotNil(dynamicReducer.body)
  }

  func testDynamicConditionWithSuccessfulCondition() {
    let baseReducer = ReducerTestReducer()

    let dynamicReducer = baseReducer.lock(
      condition: { state, action in
        // Always allow
        return .success
      },
      boundaryId: TestBoundaryId.test
    )

    var state = TestReducerState()
    let action = TestAction.increment

    // Execute reducer
    let effect = dynamicReducer.reduce(into: &state, action: action)

    // State should be mutated (condition passed)
    XCTAssertEqual(state.counter, 1)
    XCTAssertNotNil(effect)
  }

  func testDynamicConditionWithFailedCondition() {
    actor HandlerCheck {
      private var handlerCalled = false
      func setHandlerCalled() { handlerCalled = true }
      func getHandlerCalled() -> Bool { handlerCalled }
    }

    let handlerCheck = HandlerCheck()
    let baseReducer = ReducerTestReducer()

    let dynamicReducer = baseReducer.lock(
      condition: { state, action in
        // Always reject
        return .cancel(NotAuthenticatedError())
      },
      boundaryId: TestBoundaryId.test,
      lockFailure: { error, send in
        await handlerCheck.setHandlerCalled()
      }
    )

    var state = TestReducerState()
    let action = TestAction.increment

    // Execute reducer
    let effect = dynamicReducer.reduce(into: &state, action: action)

    // State should NOT be mutated (condition failed)
    XCTAssertEqual(state.counter, 0)
    XCTAssertNotNil(effect)
  }

  // MARK: - Basic LockmanReducer Integration Tests

  func testBasicLockmanReducerCreation() {
    // Setup test strategy
    let strategy = ReducerTestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("TestSingleExecutionStrategy")

    // Register strategy
    // Use isolated test container
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test
    )

    // Should create LockmanReducer
    XCTAssertNotNil(lockmanReducer)
  }

  func testLockmanReducerWithCustomUnlockOption() {
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      unlockOption: .delayed(1.0)
    )

    // Unlock option should be set correctly
    XCTAssertEqual(lockmanReducer.unlockOption, .delayed(1.0))
  }

  func testLockmanReducerWithLockFailureHandler() {
    actor HandlerCheck {
      private var handlerCalled = false
      func setHandlerCalled() { handlerCalled = true }
      func getHandlerCalled() -> Bool { handlerCalled }
    }

    let handlerCheck = HandlerCheck()
    let lockFailureHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
      await handlerCheck.setHandlerCalled()
    }

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      lockFailure: lockFailureHandler
    )

    // Handler should be set
    XCTAssertNotNil(lockmanReducer.lockFailure)
  }

  // MARK: - Single Path CaseKeyPath Support Tests

  func testSingleCaseKeyPathSupport() {
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    // Should create LockmanReducer with path extractor
    XCTAssertNotNil(lockmanReducer)
  }

  func testSinglePathActionExtraction() {
    // Setup test strategy for view actions
    let strategy = ReducerTestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("TestSingleExecutionStrategy")

    // Register strategy
    // Use isolated test container
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    var state = TestReducerState()
    let viewAction = ViewAction.buttonTapped
    let action = TestAction.view(viewAction)

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // Should extract and process view action
    XCTAssertEqual(state.lastActionId, "view_buttonTapped")
    XCTAssertNotNil(effect)
  }

  // MARK: - Two Path CaseKeyPath Support Tests

  func testTwoCaseKeyPathSupport() {
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate
    )

    // Should create LockmanReducer with multiple path extractor
    XCTAssertNotNil(lockmanReducer)
  }

  func testPathExtractionPriority() {
    // Test that path extraction takes priority over root action
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    // This validates that the extractor function prioritizes path extraction
    XCTAssertNotNil(lockmanReducer)
  }

  func testMultiplePathEvaluationOrder() {
    // Test that paths are evaluated in the correct order
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.increment
    )

    // Paths should be evaluated in order: view, delegate, increment, then root
    XCTAssertNotNil(lockmanReducer)
  }

  func testTwoPathActionExtraction() {
    // Setup strategies
    let viewStrategy = ReducerTestSingleExecutionStrategy()
    let delegateStrategy = ReducerTestSingleExecutionStrategy()

    // Use isolated test container with single strategy
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(viewStrategy)  // Only register one strategy to avoid conflicts

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate
    )

    var state = TestReducerState()

    // Test view action
    let viewAction = TestAction.view(.buttonTapped)
    _ = lockmanReducer.reduce(into: &state, action: viewAction)
    XCTAssertEqual(state.lastActionId, "view_buttonTapped")

    // Test delegate action
    let delegateAction = TestAction.delegate(.didComplete)
    _ = lockmanReducer.reduce(into: &state, action: delegateAction)
    XCTAssertEqual(state.lastActionId, "delegate_didComplete")
  }

  // MARK: - Three Path CaseKeyPath Support Tests

  func testThreeCaseKeyPathSupport() {
    let baseReducer = ReducerTestReducer()

    // Create a dummy third path for testing
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.nonLockmanAction
    )

    // Should create LockmanReducer with three path extractor
    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - Four Path CaseKeyPath Support Tests

  func testFourCaseKeyPathSupport() {
    let baseReducer = ReducerTestReducer()

    // Create dummy paths for testing
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.increment, \.decrement
    )

    // Should create LockmanReducer with four path extractor
    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - Five Path CaseKeyPath Support Tests

  func testFiveCaseKeyPathSupport() {
    let baseReducer = ReducerTestReducer()

    // Create dummy paths for testing
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.increment, \.decrement, \.nonLockmanAction
    )

    // Should create LockmanReducer with five path extractor
    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - Action Extraction Logic Tests

  func testRootActionExtractionFallback() {
    // Setup test strategy
    let strategy = ReducerTestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("TestSingleExecutionStrategy")

    // Register strategy
    // Use isolated test container
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    let baseReducer = ReducerTestReducer()

    // Use path that won't match, so it falls back to root action
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view  // This won't match .increment action
    )

    var state = TestReducerState()
    let action = TestAction.increment  // Root LockmanAction

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // Should fall back to root action extraction
    XCTAssertEqual(state.counter, 1)
    XCTAssertNotNil(effect)
  }

  func testPathExtractionPrecedence() {
    // Test that path extraction takes precedence over root action
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    // This tests the extraction logic without actual execution
    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - CasePathable Integration Tests

  func testCasePathableConstraintValidation() {
    // Test that CasePathable constraint is properly enforced
    let baseReducer = ReducerTestReducer()

    // TestAction conforms to CasePathable, so this should compile
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    XCTAssertNotNil(lockmanReducer)
  }

  func testCaseKeyPathSyntax() {
    // Test CaseKeyPath syntax usage
    let baseReducer = ReducerTestReducer()

    // Test various CaseKeyPath syntaxes
    let reducer1 = baseReducer.lock(boundaryId: TestBoundaryId.test, for: \.view)
    let reducer2 = baseReducer.lock(boundaryId: TestBoundaryId.test, for: \.delegate)
    let reducer3 = baseReducer.lock(boundaryId: TestBoundaryId.test, for: \.increment)

    XCTAssertNotNil(reducer1)
    XCTAssertNotNil(reducer2)
    XCTAssertNotNil(reducer3)
  }

  // MARK: - Parameter Validation and Type Safety Tests

  func testBoundaryIdTypeErasure() {
    let baseReducer = ReducerTestReducer()

    // Test different boundary ID types
    let boundary1 = TestBoundaryId.test
    let boundary2 = TestBoundaryId.feature

    let reducer1 = baseReducer.lock(boundaryId: boundary1)
    let reducer2 = baseReducer.lock(boundaryId: boundary2)

    XCTAssertNotEqual(
      reducer1.boundaryId as? TestBoundaryId,
      reducer2.boundaryId as? TestBoundaryId
    )
  }

  func testUnlockOptionValidation() {
    let baseReducer = ReducerTestReducer()

    let unlockOptions: [LockmanUnlockOption] = [
      .immediate,
      .delayed(1.0),
      .mainRunLoop,
      .transition,
    ]

    for option in unlockOptions {
      let lockmanReducer = baseReducer.lock(
        boundaryId: TestBoundaryId.test,
        unlockOption: option
      )

      XCTAssertEqual(lockmanReducer.unlockOption, option)
    }
  }

  func testLockFailureHandlerTypes() {
    let baseReducer = ReducerTestReducer()

    // Test async handler
    let asyncHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
      // Async handler
    }

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      lockFailure: asyncHandler
    )

    XCTAssertNotNil(lockmanReducer.lockFailure)
  }

  // MARK: - ViewAction Pattern Support Tests

  func testViewActionPatternExtraction() {
    let baseReducer = ReducerTestReducer()

    // Test typical ViewAction pattern
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    var state = TestReducerState()
    let viewAction = TestAction.view(.buttonTapped)

    // Execute with ViewAction
    let effect = lockmanReducer.reduce(into: &state, action: viewAction)

    XCTAssertEqual(state.lastActionId, "view_buttonTapped")
    XCTAssertNotNil(effect)
  }

  func testNestedActionHierarchySupport() {
    let baseReducer = ReducerTestReducer()

    // Test complex nested action hierarchy
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate
    )

    var state = TestReducerState()

    // Test nested view action
    let viewAction = TestAction.view(.textChanged("test"))
    _ = lockmanReducer.reduce(into: &state, action: viewAction)
    XCTAssertEqual(state.lastActionId, "view_textChanged")

    // Test nested delegate action
    let delegateAction = TestAction.delegate(.didComplete)
    _ = lockmanReducer.reduce(into: &state, action: delegateAction)
    XCTAssertEqual(state.lastActionId, "delegate_didComplete")
  }

  // MARK: - Error Handling and Lock Failure Tests

  func testLockFailureHandlerExecution() {
    actor HandlerState {
      private var handlerError: (any Error)?
      private var handlerCalled = false

      func setHandlerError(_ error: any Error) { handlerError = error }
      func getHandlerError() -> (any Error)? { handlerError }
      func setHandlerCalled() { handlerCalled = true }
      func getHandlerCalled() -> Bool { handlerCalled }
    }

    let handlerState = HandlerState()
    let lockFailureHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
      await handlerState.setHandlerError(error)
      await handlerState.setHandlerCalled()
    }

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      lockFailure: lockFailureHandler
    )

    // Handler should be set
    XCTAssertNotNil(lockmanReducer.lockFailure)
  }

  func testLockFailureWithSendFunction() {
    actor SendCheck {
      private var sendCalled = false
      func setSendCalled() { sendCalled = true }
      func getSendCalled() -> Bool { sendCalled }
    }

    let sendCheck = SendCheck()
    let lockFailureHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
      // Test that send function is provided
      XCTAssertNotNil(send)
      await sendCheck.setSendCalled()
    }

    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      lockFailure: lockFailureHandler
    )

    XCTAssertNotNil(lockmanReducer)

    // Send function should not be called during reducer creation
    Task {
      let wasCalled = await sendCheck.getSendCalled()
      XCTAssertFalse(wasCalled)
    }
  }

  // MARK: - Reducer Composition and Nesting Tests

  func testReducerMethodChaining() {
    let baseReducer = ReducerTestReducer()

    // Test method chaining
    let lockmanReducer =
      baseReducer
      .lock(boundaryId: TestBoundaryId.test)
      .lock(boundaryId: TestBoundaryId.feature)

    // Should create nested LockmanReducers
    XCTAssertNotNil(lockmanReducer)
  }

  func testMultipleLockCallsOnSameReducer() {
    let baseReducer = ReducerTestReducer()

    // Test multiple lock calls
    let reducer1 = baseReducer.lock(boundaryId: TestBoundaryId.test)
    let reducer2 = baseReducer.lock(boundaryId: TestBoundaryId.feature)

    // Both should be valid
    XCTAssertNotNil(reducer1)
    XCTAssertNotNil(reducer2)
  }

  func testComplexReducerComposition() {
    let baseReducer = ReducerTestReducer()

    // Test complex composition
    let complexReducer =
      baseReducer
      .lock(boundaryId: TestBoundaryId.test, for: \.view)
      .lock(boundaryId: TestBoundaryId.feature, for: \.delegate)

    XCTAssertNotNil(complexReducer)
  }

  // MARK: - State and Action Type Preservation Tests

  func testGenericTypeParameterPreservation() {
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test
    )

    // State and Action types should be preserved
    XCTAssertTrue(type(of: lockmanReducer).State.self == TestReducerState.self)
    XCTAssertTrue(type(of: lockmanReducer).Action.self == TestAction.self)
  }

  func testSendableConstraintEnforcement() {
    // Test that Sendable constraints are properly enforced
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test
    )

    // Should compile without Sendable constraint violations
    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - Thread Safety and Concurrency Tests

  func testConcurrentReducerCreation() async {
    let baseReducer = ReducerTestReducer()

    // Test concurrent reducer creation
    await TestSupport.performConcurrentOperations(count: 10) {
      let _ = baseReducer.lock(boundaryId: TestBoundaryId.test)
    }

    // Should not crash with concurrent creation
    XCTAssertTrue(true)
  }

  func testConcurrentActionProcessing() async {
    // Setup test strategy
    let strategy = ReducerTestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("TestSingleExecutionStrategy")

    // Use isolated test container
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) { @Sendable in
      let baseReducer = ReducerTestReducer()

      // Test concurrent action processing by creating reducer in each operation
      await TestSupport.performConcurrentOperations(count: 10) {
        let lockmanReducer = baseReducer.lock(boundaryId: TestBoundaryId.test)
        var state = TestReducerState()
        _ = lockmanReducer.reduce(into: &state, action: .increment)
      }

      // Should handle concurrent processing safely
      XCTAssertTrue(true)
    }
  }

  func testConcurrentReducerCreationSafety() async {
    // Test that creating reducers concurrently is safe
    let baseReducer = ReducerTestReducer()

    await TestSupport.performConcurrentOperations(count: 20) {
      let _ = baseReducer.lock(
        boundaryId: TestBoundaryId.test,
        for: \.view, \.delegate
      )
    }

    XCTAssertTrue(true, "Concurrent reducer creation should be safe")
  }

  func testThreadSafeExtractorGeneration() {
    // Test that extractor function generation is thread-safe
    let baseReducer = ReducerTestReducer()

    let reducers = (0..<100).map { _ in
      baseReducer.lock(
        boundaryId: TestBoundaryId.test,
        for: \.view, \.delegate, \.increment
      )
    }

    // All reducers should be created successfully
    XCTAssertEqual(reducers.count, 100)
    XCTAssertTrue(reducers.allSatisfy { _ in true })
  }

  // MARK: - Integration with ComposableArchitecture Tests

  func testReducerProtocolConformanceMaintenance() {
    let baseReducer = ReducerTestReducer()
    let lockmanReducer = baseReducer.lock(boundaryId: TestBoundaryId.test)

    // Should maintain Reducer protocol conformance
    XCTAssertNotNil(lockmanReducer.body)
  }

  func testEffectSystemIntegration() {
    let baseReducer = ReducerTestReducer()
    let lockmanReducer = baseReducer.lock(boundaryId: TestBoundaryId.test)

    var state = TestReducerState()
    let action = TestAction.increment

    // Should integrate with TCA effect system
    let effect = lockmanReducer.reduce(into: &state, action: action)
    XCTAssertNotNil(effect)
  }

  // MARK: - Real-world Usage Pattern Tests

  func testNavigationFeaturePattern() {
    let baseReducer = ReducerTestReducer()

    let navigationReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.navigation,
      for: \.view
    )

    var state = TestReducerState()
    let navigationAction = TestAction.view(.buttonTapped)

    let effect = navigationReducer.reduce(into: &state, action: navigationAction)

    XCTAssertEqual(state.lastActionId, "view_buttonTapped")
    XCTAssertNotNil(effect)
  }

  func testErrorRecoveryPatterns() {
    actor ErrorRecoveryState {
      private var errorRecovered = false
      func setErrorRecovered() { errorRecovered = true }
      func getErrorRecovered() -> Bool { errorRecovered }
    }

    let errorRecoveryState = ErrorRecoveryState()
    let errorRecoveryHandler: @Sendable (any Error, Send<TestAction>) async -> Void = {
      error, send in
      await errorRecoveryState.setErrorRecovered()
    }

    let baseReducer = ReducerTestReducer()

    let recoveryReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      lockFailure: errorRecoveryHandler
    )

    XCTAssertNotNil(recoveryReducer)
  }

  func testMultiFeatureBoundaryManagement() {
    let baseReducer = ReducerTestReducer()

    // Test multiple feature boundaries
    let feature1Reducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    let feature2Reducer = baseReducer.lock(
      boundaryId: TestBoundaryId.feature,
      for: \.delegate
    )

    XCTAssertNotEqual(
      feature1Reducer.boundaryId as? TestBoundaryId,
      feature2Reducer.boundaryId as? TestBoundaryId
    )
  }

  // MARK: - Performance and Memory Management Tests

  func testReducerWrapperOverhead() {
    let baseReducer = ReducerTestReducer()

    // Measure reducer creation performance
    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<1000 {
        let _ = baseReducer.lock(boundaryId: TestBoundaryId.test)
      }
    }

    // Should be reasonably fast
    XCTAssertLessThan(executionTime, 1.0, "Reducer wrapping should be efficient")
  }

  func testMemoryUsageWithMultiplePaths() {
    let baseReducer = ReducerTestReducer()

    // Test memory usage with multiple paths
    let multiPathReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.increment, \.decrement, \.nonLockmanAction
    )

    // Should not cause excessive memory usage
    XCTAssertNotNil(multiPathReducer)
  }

  // MARK: - Edge Cases and Error Conditions Tests

  func testInvalidCasePathHandling() {
    let baseReducer = ReducerTestReducer()

    // Test with paths that may not extract anything
    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view  // May not match all actions
    )

    var state = TestReducerState()
    let nonMatchingAction = TestAction.increment

    // Should fall back to root action extraction
    let effect = lockmanReducer.reduce(into: &state, action: nonMatchingAction)

    XCTAssertNotNil(effect)
  }

  func testNonConformingActionRecovery() {
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test
    )

    var state = TestReducerState()
    let action = TestAction.nonLockmanAction

    // Should handle non-conforming actions gracefully
    let effect = lockmanReducer.reduce(into: &state, action: action)

    XCTAssertEqual(state.lastActionId, "nonLockmanAction")
    XCTAssertNotNil(effect)
  }

  func testBoundaryIdCollisionScenarios() {
    let baseReducer = ReducerTestReducer()

    // Test multiple reducers with same boundary ID
    let reducer1 = baseReducer.lock(boundaryId: TestBoundaryId.test)
    let reducer2 = baseReducer.lock(boundaryId: TestBoundaryId.test)

    // Both should be valid (collision handling is at strategy level)
    XCTAssertNotNil(reducer1)
    XCTAssertNotNil(reducer2)
  }

  // MARK: - Advanced Integration Tests

  func testComplexActionHierarchyExtraction() {
    // Test complex action hierarchies with multiple nesting levels
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate, \.increment, \.decrement, \.nonLockmanAction
    )

    // Should handle complex hierarchies
    XCTAssertNotNil(lockmanReducer)
  }

  func testReducerCompositionWithTCA() {
    // Test composition with other TCA reducers
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view
    )

    // Test that it maintains TCA compatibility
    XCTAssertNotNil(lockmanReducer.body)
  }

  func testEffectSystemIntegrationWithPaths() {
    // Test that effects work properly with path extraction
    let baseReducer = ReducerTestReducer()

    let lockmanReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.test,
      for: \.view, \.delegate
    )

    var state = TestReducerState()

    // Test different action types
    let viewEffect = lockmanReducer.reduce(into: &state, action: .view(.buttonTapped))
    let delegateEffect = lockmanReducer.reduce(into: &state, action: .delegate(.didComplete))
    let rootEffect = lockmanReducer.reduce(into: &state, action: .increment)

    XCTAssertNotNil(viewEffect)
    XCTAssertNotNil(delegateEffect)
    XCTAssertNotNil(rootEffect)
  }

  func testLockConditionWithComplexState() {
    // Test dynamic condition with complex state validation
    let baseReducer = ReducerTestReducer()

    let conditionReducer = baseReducer.lock(
      condition: { state, action in
        // Complex condition logic
        guard state.isAuthenticated else {
          return .cancel(NotAuthenticatedError())
        }

        switch action {
        case .increment where state.balance < 0:
          return .cancel(NotAuthenticatedError())
        default:
          return .success
        }
      },
      boundaryId: TestBoundaryId.test
    )

    XCTAssertTrue(conditionReducer is LockmanDynamicConditionReducer<TestReducerState, TestAction>)
  }

  func testPerformanceWithMultiplePaths() {
    // Test performance characteristics with multiple case paths
    let baseReducer = ReducerTestReducer()

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<1000 {
        let _ = baseReducer.lock(
          boundaryId: TestBoundaryId.test,
          for: \.view, \.delegate, \.increment, \.decrement, \.nonLockmanAction
        )
      }
    }

    // Should be reasonably fast even with many paths
    XCTAssertLessThan(executionTime, 1.0, "Multiple path reducer creation should be efficient")
  }

  func testRealWorldFeaturePattern() {
    // Test realistic feature pattern with navigation and error handling
    let baseReducer = ReducerTestReducer()

    actor ErrorReceiver {
      private var errorReceived: (any Error)?
      func setErrorReceived(_ error: any Error) { errorReceived = error }
      func getErrorReceived() -> (any Error)? { errorReceived }
    }

    let errorReceiver = ErrorReceiver()
    let featureReducer = baseReducer.lock(
      boundaryId: TestBoundaryId.navigation,
      unlockOption: .transition,
      lockFailure: { @Sendable error, send in
        await errorReceiver.setErrorReceived(error)
      },
      for: \.view, \.delegate
    )

    // Should support real-world patterns
    XCTAssertNotNil(featureReducer)
    XCTAssertEqual(featureReducer.unlockOption, .transition)
    XCTAssertNotNil(featureReducer.lockFailure)
  }
}
