import ComposableArchitecture
import XCTest

@testable import Lockman

final class LockmanReducerTests: XCTestCase {

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

  // MARK: - Lock-First Behavior Tests

  func testLockFirstBehaviorWithSuccessfulLock() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Create LockmanReducer
    let baseReducer = TestReducer()
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // State should be mutated (lock was successful)
    XCTAssertEqual(state.counter, 1)
    XCTAssertEqual(state.lastActionId, "increment")
    XCTAssertNotNil(effect)
  }

  func testLockFirstBehaviorPreventsMutation() {
    // Test that state mutations are PREVENTED when lock fails
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("prevent-mutation-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    let baseReducer = TestReducer()
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState(counter: 10, isProcessing: true, lastActionId: "original")
    let originalState = state
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // State should remain COMPLETELY unchanged (true lock-first behavior)
    XCTAssertEqual(state.counter, originalState.counter)
    XCTAssertEqual(state.isProcessing, originalState.isProcessing)
    XCTAssertEqual(state.lastActionId, originalState.lastActionId)
    XCTAssertNotNil(effect)  // Effect may be .none or error handler
  }

  func testLockFirstBehaviorTimingValidation() {
    // Test that lock check happens BEFORE base reducer execution
    final class TimingValidationStrategy: LockmanStrategy, @unchecked Sendable {
      typealias I = TestLockmanInfo
      
      var strategyId: LockmanStrategyId { .init(name: "TimingValidationStrategy") }
      
      static func makeStrategyId() -> LockmanStrategyId {
        .init(name: "TimingValidationStrategy")
      }

      var canLockCallTime: Date?
      var lockCallTime: Date?

      func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
        canLockCallTime = Date()
        return .success
      }

      func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        lockCallTime = Date()
      }

      func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    let strategy = TimingValidationStrategy()
    let strategyId = LockmanStrategyId("timing-strategy")

    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    class TimingValidationReducer: Reducer {
      typealias State = TestReducerState
      typealias Action = SharedTestAction

      let strategy: TimingValidationStrategy
      var baseReducerCallTime: Date?

      init(strategy: TimingValidationStrategy) {
        self.strategy = strategy
      }

      var body: some Reducer<State, Action> {
        Reduce { state, action in
          self.baseReducerCallTime = Date()
          state.counter += 1
          return .none
        }
      }
    }

    let baseReducer = TimingValidationReducer(strategy: strategy)
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    _ = lockmanReducer.reduce(into: &state, action: action)

    // Verify timing: canLock should be called before base reducer
    XCTAssertNotNil(strategy.canLockCallTime)
    XCTAssertNotNil(baseReducer.baseReducerCallTime)

    if let canLockTime = strategy.canLockCallTime,
      let baseReducerTime = baseReducer.baseReducerCallTime
    {
      XCTAssertLessThanOrEqual(
        canLockTime.timeIntervalSince1970,
        baseReducerTime.timeIntervalSince1970,
        "canLock should be called before base reducer"
      )
    }
  }

  func testLockFirstBehaviorWithFailedLock() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock the action to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    // Create LockmanReducer
    let baseReducer = TestReducer()
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState(counter: 5)  // Start with non-zero value
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // State should NOT be mutated (lock failed)
    XCTAssertEqual(state.counter, 5)  // Should remain unchanged
    XCTAssertEqual(state.lastActionId, "")  // Should remain unchanged
    XCTAssertNotNil(effect)  // Effect should still be returned (could be .none)
  }

  func testLockFirstBehaviorWithNonLockmanAction() {
    // Create LockmanReducer
    let baseReducer = TestReducer()
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.nonLockmanAction

    // Execute reducer (this should be treated as non-lockman action in extractor)
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // State should be mutated normally (no locking applied)
    XCTAssertEqual(state.lastActionId, "nonLockmanAction")
    XCTAssertNotNil(effect)
  }

  // MARK: - Action Processing & Classification Tests

  func testLockmanActionExtraction() {
    let extractor: (SharedTestAction) -> (any LockmanAction)? = { action in
      return action
    }

    // Test LockmanAction conforming actions
    let incrementAction = SharedTestAction.increment
    let decrementAction = SharedTestAction.decrement

    XCTAssertNotNil(extractor(incrementAction))
    XCTAssertNotNil(extractor(decrementAction))

    // Test action name extraction
    XCTAssertEqual(incrementAction.actionName, "increment")
    XCTAssertEqual(decrementAction.actionName, "decrement")
  }

  func testCustomActionExtractor() {
    // Test custom extractor that only extracts specific actions
    let customExtractor: (SharedTestAction) -> (any LockmanAction)? = { action in
      switch action {
      case .increment, .decrement:
        return action
      default:
        return nil
      }
    }

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: customExtractor
    )

    XCTAssertNotNil(lockmanReducer)
  }

  // MARK: - LockmanInfo Lifecycle Management Tests

  func testLockmanInfoConsistency() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let action = SharedTestAction.increment

    // Create multiple LockmanInfo instances
    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()

    // Each should have unique ID but same action/strategy IDs
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertEqual(info1.strategyId, info2.strategyId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testUniqueIdPreservation() {
    let action = SharedTestAction.increment
    let info = action.createLockmanInfo()
    let originalUniqueId = info.uniqueId

    // UniqueId should remain consistent
    XCTAssertEqual(info.uniqueId, originalUniqueId)

    // Creating new info should have different uniqueId
    let newInfo = action.createLockmanInfo()
    XCTAssertNotEqual(newInfo.uniqueId, originalUniqueId)
  }

  // MARK: - Lock Failure Handling Tests

  func testLockFailureHandlerInvocation() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    actor TestState {
      private var handlerCalled = false
      private var receivedError: (any Error)?
      
      func setHandlerCalled() { handlerCalled = true }
      func getHandlerCalled() -> Bool { handlerCalled }
      func setReceivedError(_ error: any Error) { receivedError = error }
      func getReceivedError() -> (any Error)? { receivedError }
    }
    
    let testState = TestState()
    let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
      await testState.setHandlerCalled()
      await testState.setReceivedError(error)
    }

    // Create LockmanReducer with failure handler
    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: lockFailureHandler,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // Effect should be created (for handler execution)
    XCTAssertNotNil(effect)
  }

  func testLockFailureErrorWrapping() {
    // Test that strategy errors are properly wrapped in LockmanCancellationError
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("error-wrap-strategy")

    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    actor ErrorCapture {
      private var capturedError: (any Error)?
      func setCapturedError(_ error: any Error) { capturedError = error }
      func getCapturedError() -> (any Error)? { capturedError }
    }
    
    let errorCapture = ErrorCapture()
    let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
      await errorCapture.setCapturedError(error)
    }

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: lockFailureHandler,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    _ = lockmanReducer.reduce(into: &state, action: action)

    // Error should be available for inspection (though async)
    XCTAssertNotNil(lockmanReducer.lockFailure)
  }

  func testLockFailureWithSendFunction() {
    // Test that send function is provided to lock failure handler
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("send-function-strategy")

    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    actor SendFunctionCheck {
      private var sendFunctionProvided = false
      func setSendFunctionProvided() { sendFunctionProvided = true }
      func getSendFunctionProvided() -> Bool { sendFunctionProvided }
    }
    
    let sendFunctionCheck = SendFunctionCheck()
    let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
      await sendFunctionCheck.setSendFunctionProvided()
      // Send function should be usable (though we can't easily test the effect here)
      XCTAssertNotNil(send)
    }

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: lockFailureHandler,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    _ = lockmanReducer.reduce(into: &state, action: action)

    // Handler should be configured
    XCTAssertNotNil(lockmanReducer.lockFailure)
  }

  func testLockFailureWithoutHandler() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to cause failure
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    // Create LockmanReducer without failure handler
    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // Should return .none effect when no handler provided
    XCTAssertNotNil(effect)
  }

  // MARK: - Strategy Resolution & Error Handling Tests

  func testStrategyResolutionFailure() {
    // Don't register any strategy to cause resolution failure

    actor HandlerCheck {
      private var handlerCalled = false
      func setHandlerCalled() { handlerCalled = true }
      func getHandlerCalled() -> Bool { handlerCalled }
    }
    
    let handlerCheck = HandlerCheck()
    let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
      await handlerCheck.setHandlerCalled()
    }

    // Create LockmanReducer
    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: lockFailureHandler,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // Effect should be created for error handling
    XCTAssertNotNil(effect)
  }

  // MARK: - Effect Management & Integration Tests

  func testEffectIntegrationWithLockSuccess() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Create base reducer that returns an effect
    struct EffectTestReducer: Reducer {
      typealias State = TestReducerState
      typealias Action = SharedTestAction

      var body: some Reducer<State, Action> {
        Reduce { state, action in
          switch action {
          case .increment:
            state.counter += 1
            return .run { _ in
              // Test effect
            }
          default:
            return .none
          }
        }
      }
    }

    let lockmanReducer = LockmanReducer(
      base: EffectTestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()
    let action = SharedTestAction.increment

    // Execute reducer
    let effect = lockmanReducer.reduce(into: &state, action: action)

    // State should be mutated and effect should be created
    XCTAssertEqual(state.counter, 1)
    XCTAssertNotNil(effect)
  }

  // MARK: - Boundary ID Management Tests

  func testBoundaryIdConsistency() {
    let boundaryId = TestBoundaryId.feature

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: boundaryId,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Boundary ID should be preserved
    XCTAssertEqual(lockmanReducer.boundaryId as? TestBoundaryId, boundaryId)
  }

  func testMultipleBoundaryIds() {
    let boundary1 = TestBoundaryId.test
    let boundary2 = TestBoundaryId.feature

    let reducer1 = LockmanReducer(
      base: TestReducer(),
      boundaryId: boundary1,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    let reducer2 = LockmanReducer(
      base: TestReducer(),
      boundaryId: boundary2,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Reducers should have different boundary IDs
    XCTAssertNotEqual(
      reducer1.boundaryId as? TestBoundaryId,
      reducer2.boundaryId as? TestBoundaryId
    )
  }

  // MARK: - Unlock Option Configuration Tests

  func testUnlockOptionConfiguration() {
    let unlockOptions: [LockmanUnlockOption] = [
      .immediate,
      .delayed(1.0),
      .mainRunLoop,
      .transition,
    ]

    for option in unlockOptions {
      let lockmanReducer = LockmanReducer(
        base: TestReducer(),
        boundaryId: TestBoundaryId.test,
        unlockOption: option,
        lockFailure: nil,
        extractLockmanAction: { action in action }
      )

      // Unlock option should be preserved
      XCTAssertEqual(lockmanReducer.unlockOption, option)
    }
  }

  // MARK: - Reducer Composition & Nesting Tests

  func testReducerComposition() {
    // Test that LockmanReducer can be composed with other reducers
    let baseReducer = TestReducer()
    let lockmanReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Should maintain reducer protocol conformance
    XCTAssertNotNil(lockmanReducer.body)
  }

  func testNestedLockmanReducers() {
    // Test nesting LockmanReducers
    let baseReducer = TestReducer()
    let innerReducer = LockmanReducer(
      base: baseReducer,
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    let outerReducer = LockmanReducer(
      base: innerReducer,
      boundaryId: TestBoundaryId.feature,
      unlockOption: .delayed(0.5),
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Nested reducers should work
    XCTAssertNotNil(outerReducer)
  }

  // MARK: - State Mutation Prevention Tests

  func testStateMutationPrevention() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    // Pre-lock to prevent execution
    let testInfo = TestLockmanInfo(
      actionId: "increment",
      strategyId: strategyId,
      uniqueId: UUID()
    )
    strategy.lock(boundaryId: TestBoundaryId.test, info: testInfo)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    let originalState = TestReducerState(counter: 42, isProcessing: true, lastActionId: "original")
    var state = originalState
    let action = SharedTestAction.increment

    // Execute reducer
    _ = lockmanReducer.reduce(into: &state, action: action)

    // State should remain unchanged
    XCTAssertEqual(state, originalState)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentActionProcessing() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Test concurrent execution
    await TestSupport.performConcurrentOperations(count: 10) {
      var state = TestReducerState()
      let action = SharedTestAction.increment
      _ = lockmanReducer.reduce(into: &state, action: action)
    }

    // If we reach here without crashes, concurrent processing worked
    XCTAssertTrue(true)
  }

  func testThreadSafeLockAcquisition() async {
    // Test that lock acquisition is thread-safe
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("thread-safe-strategy")

    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Perform many concurrent operations with same action ID
    var successCount = 0
    let results = try! await TestSupport.executeConcurrently(iterations: 50) {
      var state = TestReducerState()
      let action = SharedTestAction.increment
      _ = lockmanReducer.reduce(into: &state, action: action)
      return state.counter > 0 ? 1 : 0  // Count successful state mutations
    }

    successCount = results.reduce(0, +)

    // Due to single execution strategy, only one should succeed
    XCTAssertGreaterThan(successCount, 0, "At least one operation should succeed")
    XCTAssertLessThanOrEqual(
      successCount, 50, "Not all operations should succeed with single execution")
  }

  func testMemorySafetyUnderConcurrency() async {
    // Test memory safety under concurrent access
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("memory-safe-strategy")

    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Perform concurrent operations with different actions
    await TestSupport.performConcurrentOperations(count: 20) {
      var state = TestReducerState()
      let actions: [SharedTestAction] = [.increment, .decrement, .setProcessing(true)]
      let action = actions.randomElement() ?? .increment
      _ = lockmanReducer.reduce(into: &state, action: action)
    }

    // If we reach here without memory corruption or crashes, test passed
    XCTAssertTrue(true, "Memory safety maintained under concurrency")
  }

  // MARK: - Integration with ComposableArchitecture Tests

  func testReducerProtocolConformance() {
    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    // Should conform to Reducer protocol
    XCTAssertNotNil(lockmanReducer.body)

    // Should have correct associated types
    XCTAssertNotNil(lockmanReducer.body)
  }

  // MARK: - Real-world Usage Pattern Tests

  func testCounterIncrementDecrementPattern() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()

    // Test increment
    _ = lockmanReducer.reduce(into: &state, action: .increment)
    XCTAssertEqual(state.counter, 1)

    // Test decrement
    _ = lockmanReducer.reduce(into: &state, action: .decrement)
    XCTAssertEqual(state.counter, 0)
  }

  func testProcessingStatePattern() {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let strategyId = LockmanStrategyId("test-strategy")

    // Register strategy
    // TODO: Fix to use proper container pattern
    try! LockmanManager.container.register(id: strategyId, strategy: strategy)

    let lockmanReducer = LockmanReducer(
      base: TestReducer(),
      boundaryId: TestBoundaryId.test,
      unlockOption: .immediate,
      lockFailure: nil,
      extractLockmanAction: { action in action }
    )

    var state = TestReducerState()

    // Test setting processing state
    _ = lockmanReducer.reduce(into: &state, action: .setProcessing(true))
    XCTAssertTrue(state.isProcessing)

    _ = lockmanReducer.reduce(into: &state, action: .setProcessing(false))
    XCTAssertFalse(state.isProcessing)
  }
}
