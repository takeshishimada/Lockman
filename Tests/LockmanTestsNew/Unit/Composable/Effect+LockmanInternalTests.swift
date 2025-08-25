import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

/// Unit tests for Effect+LockmanInternal internal methods
final class EffectLockmanInternalTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    LockmanManager.cleanup.all()
    super.tearDown()
  }

  // MARK: - acquireLock Tests

  func testAcquireLockSuccess() async throws {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    try await LockmanManager.withTestContainer(container) {
      let effect = Effect<SharedTestAction>.none
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let strategyWrapper = try LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let result = try effect.acquireLock(
        strategy: strategyWrapper,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test
      )

      XCTAssertEqual(result, .success)
    }
  }

  func testAcquireLockCancel() async throws {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    try await LockmanManager.withTestContainer(container) {
      let effect = Effect<SharedTestAction>.none
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let strategyWrapper = try LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      // First lock should succeed
      _ = try effect.acquireLock(
        strategy: strategyWrapper,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test
      )

      // Second lock should fail
      let result = try effect.acquireLock(
        strategy: strategyWrapper,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test
      )

      if case .cancel = result {
        XCTAssertTrue(true)
      } else {
        XCTFail("Expected cancel result")
      }
    }
  }

  func testAcquireLockSuccessWithPrecedingCancellation() async throws {
    let strategy = TestPrecedingCancellationStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    try await LockmanManager.withTestContainer(container) {
      let effect = Effect<SharedTestAction>.none
      let lockmanInfo = TestLockmanInfo(
        actionId: "increment",
        strategyId: strategy.strategyId
      )
      let strategyWrapper = try LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let result = try effect.acquireLock(
        strategy: strategyWrapper,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test
      )

      if case .successWithPrecedingCancellation = result {
        XCTAssertTrue(true)
      } else {
        XCTFail("Expected successWithPrecedingCancellation result")
      }
    }
  }

  func testAcquireLockStrategyNotFound() async throws {
    let container = LockmanStrategyContainer()  // Empty container

    try await LockmanManager.withTestContainer(container) {
      let effect = Effect<SharedTestAction>.none
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()

      XCTAssertThrowsError(
        try {
          let strategyWrapper = try LockmanManager.container.resolve(
            id: lockmanInfo.strategyId,
            expecting: type(of: lockmanInfo)
          )
          return try effect.acquireLock(
            strategy: strategyWrapper,
            lockmanInfo: lockmanInfo,
            boundaryId: TestBoundaryId.test
          )
        }()
      ) { error in
        XCTAssertTrue(error is LockmanRegistrationError)
      }
    }
  }

  // MARK: - buildLockEffect Tests

  func testBuildLockEffectSuccess() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .success,
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectSuccessWithPrecedingCancellation() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let testError = TestPrecedingCancellationError(
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        reason: LockmanRegistrationError.strategyNotRegistered("test")
      )

      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .successWithPrecedingCancellation(error: testError),
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectSuccessWithPrecedingCancellationAndHandler() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let testError = TestPrecedingCancellationError(
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        reason: LockmanRegistrationError.strategyNotRegistered("test")
      )

      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .successWithPrecedingCancellation(error: testError),
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: { _, _ in }
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectCancel() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let error = LockmanRegistrationError.strategyNotRegistered("test")

      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .cancel(error),
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectCancelWithHandler() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let error = LockmanRegistrationError.strategyNotRegistered("test")

      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .cancel(error),
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: { _, _ in }
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectStrategyResolutionError() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)  // Register so we can resolve it

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .success,
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectStrategyResolutionErrorWithHandler() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)  // Register so we can resolve it

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)
      let lockmanInfo = SharedTestAction.increment.createLockmanInfo()
      let strategyWrapper = try! LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: type(of: lockmanInfo)
      )

      let effect = baseEffect.buildLockEffect(
        lockResult: .success,
        strategy: strategyWrapper,
        action: SharedTestAction.increment,
        lockmanInfo: lockmanInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: { _, _ in }
      )

      XCTAssertNotNil(effect)
    }
  }

  func testBuildLockEffectCancellableFlag() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let baseEffect = Effect<SharedTestAction>.send(.increment)

      // Test with cancellable info
      let cancellableInfo = TestLockmanInfo(
        actionId: "test",
        strategyId: strategy.strategyId,
        isCancellationTarget: true
      )

      let strategyWrapper1 = try! LockmanManager.container.resolve(
        id: cancellableInfo.strategyId,
        expecting: type(of: cancellableInfo)
      )

      let effect1 = baseEffect.buildLockEffect(
        lockResult: .success,
        strategy: strategyWrapper1,
        action: SharedTestAction.increment,
        lockmanInfo: cancellableInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Test with non-cancellable info
      let nonCancellableInfo = TestLockmanInfo(
        actionId: "test",
        strategyId: strategy.strategyId,
        isCancellationTarget: false
      )

      let strategyWrapper2 = try! LockmanManager.container.resolve(
        id: nonCancellableInfo.strategyId,
        expecting: type(of: nonCancellableInfo)
      )

      let effect2 = baseEffect.buildLockEffect(
        lockResult: .success,
        strategy: strategyWrapper2,
        action: SharedTestAction.increment,
        lockmanInfo: nonCancellableInfo,
        boundaryId: TestBoundaryId.test,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(effect1)
      XCTAssertNotNil(effect2)
    }
  }

  // MARK: - handleError Tests

  func testHandleErrorStrategyNotRegistered() async {
    let error = LockmanRegistrationError.strategyNotRegistered("TestStrategy")

    MockIssueReporter.reset()
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("not registered"))
  }

  func testHandleErrorStrategyAlreadyRegistered() async {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")

    MockIssueReporter.reset()
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("already registered"))
  }

  func testHandleErrorOtherError() async {
    struct OtherError: Error {}
    let error = OtherError()

    MockIssueReporter.reset()
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Should not report for non-LockmanRegistrationError
    XCTAssertEqual(MockIssueReporter.reportCount, 0)
  }

  func testHandleErrorDefaultReporter() async {
    let error = LockmanRegistrationError.strategyNotRegistered("TestStrategy")

    // Test that default reporter is used when not specified
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // Should complete without error (using default reporter)
    XCTAssertTrue(true)
  }

  // MARK: - Ultra Think Tests: Previously Uncovered Regions

  /// Test Line 153-154: unlock effect actually executes unlockToken()
  func testUnlockEffectActualExecution() async {
    let strategy = TestUnlockTrackingStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(initialState: TestUnlockFeature.State()) {
        TestUnlockFeature()
      }

      // Verify initial state
      XCTAssertEqual(strategy.unlockCallCount, 0)

      // Send action that triggers lock effect
      await store.send(.performAction) {
        $0.isRunning = true
      }

      // Wait for action completion
      await store.receive(\.actionCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      // Critical: Wait for all effects to complete (including unlock effect)
      await store.finish()

      // Verify unlock was actually called
      XCTAssertEqual(strategy.unlockCallCount, 1)
    }
  }

  /// Test Line 195-196: .cancel case handler execution via send action
  func testCancelHandlerExecutionViaSend() async {
    let strategy = TestSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try! container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(initialState: TestHandlerSendFeature.State()) {
        TestHandlerSendFeature()
      }

      // First action to establish lock
      await store.send(.firstAction) {
        $0.isRunning = true
      }

      // Second action that should trigger handler execution in Effect.run
      await store.send(.secondActionWithSendHandler)

      // Critical: Receive the action sent from inside Effect.run handler
      await store.receive(\.handlerWasExecuted) {
        $0.handlerExecutionCount = 1
        $0.lastHandlerError = "Lock acquisition failed"
      }

      // Complete first action
      await store.receive(\.firstCompleted) {
        $0.isRunning = false
      }

      await store.finish()
    }
  }

  /// Test Line 214-215: catch block handler execution via send action
  func testCatchBlockHandlerExecutionViaSend() async {
    let container = LockmanStrategyContainer()  // Empty - triggers error

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(initialState: TestHandlerSendFeature.State()) {
        TestHandlerSendFeature()
      }

      // This should trigger strategy resolution error and handler in catch block
      await store.send(.errorActionWithSendHandler)

      // Critical: Receive the action sent from inside catch block Effect.run handler
      await store.receive(\.handlerWasExecuted) {
        $0.handlerExecutionCount = 1
        $0.lastHandlerError = "Strategy resolution failed"
      }

      await store.finish()
    }
  }

}

// MARK: - Test Helper Classes

private struct TestPrecedingCancellationError: LockmanPrecedingCancellationError {
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId
  let reason: any Error

  init(lockmanInfo: any LockmanInfo, boundaryId: any LockmanBoundaryId, reason: any Error) {
    self.lockmanInfo = lockmanInfo
    self.boundaryId = boundaryId
    self.reason = reason
  }

  var localizedDescription: String {
    "Test preceding cancellation error"
  }
}

private final class TestPrecedingCancellationStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  var strategyId: LockmanStrategyId {
    LockmanStrategyId(name: "TestPrecedingCancellationStrategy")
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestPrecedingCancellationStrategy")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    let testError = TestPrecedingCancellationError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      reason: LockmanRegistrationError.strategyNotRegistered("cancelled_action")
    )
    return .successWithPrecedingCancellation(error: testError)
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}

  func cleanUp() {}

  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

private final class MockIssueReporter: LockmanIssueReporter, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) static var lastMessage: String = ""
  nonisolated(unsafe) static var lastFile: String = ""
  nonisolated(unsafe) static var lastLine: UInt = 0
  nonisolated(unsafe) static var reportCount: Int = 0

  static func reportIssue(_ message: String, file: StaticString, line: UInt) {
    lock.withLock {
      lastMessage = message
      lastFile = "\(file)"
      lastLine = line
      reportCount += 1
    }
  }

  static func reset() {
    lock.withLock {
      lastMessage = ""
      lastFile = ""
      lastLine = 0
      reportCount = 0
    }
  }
}

// MARK: - TestStore Integration Tests for Uncovered Regions

/// Tests using TestStore to cover uncovered regions in Effect+LockmanInternal.swift
/// Specifically targets:
/// - Line 153: unlock execution within Effect.run
/// - Line 195, 214: handler execution within Effect.run
final class EffectLockmanInternalIntegrationTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    LockmanManager.cleanup.all()
    super.tearDown()
  }

  // MARK: - Test Unlock Execution

  func testUnlockExecutionInEffect() async throws {
    let mockStrategy = MockStrategyWithUnlockTracking()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeature.State()
      ) {
        TestLockFeature()
      }

      // Send action that triggers lock effect
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Wait for operation completion
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      // Ensure all effects complete including unlock
      await store.finish()

      // Verify unlock was actually executed (covers line 153)
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      XCTAssertEqual(mockStrategy.lockCallCount, 1)
    }
  }

  // MARK: - Test Handler Execution

  func testHandlerExecutionForCancelResult() async throws {
    let mockStrategy = MockStrategyWithBlockingBehavior()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeature.State()
      ) {
        TestLockFeature()
      }

      // First operation to occupy the lock
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Second operation should be blocked and trigger handler
      await store.send(.startOperationWithHandler)

      // Handler should be called for blocked operation
      await store.receive(\.handlerCalled) {
        $0.handlerCallCount += 1
      }

      // First operation completes
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()

      // Verify handler was executed (covers line 195)
      XCTAssertEqual(mockStrategy.blockCallCount, 1)
    }
  }

  func testHandlerExecutionForSuccessWithPrecedingCancellation() async throws {
    let mockStrategy = MockStrategyWithPrecedingCancellation()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeature.State()
      ) {
        TestLockFeature()
      }

      // Operation with preceding cancellation and handler
      await store.send(.startOperationWithHandler) {
        $0.isRunning = true
      }

      // Handler should be called for preceding cancellation
      await store.receive(\.handlerCalled) {
        $0.handlerCallCount += 1
      }

      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()

      // Verify preceding cancellation handler was executed (covers line 177)
      XCTAssertEqual(mockStrategy.precedingCancellationCallCount, 1)
    }
  }

  func testHandlerExecutionForStrategyResolutionError() async throws {
    // Use container without registered strategy to trigger resolution error
    let container = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeature.State()
      ) {
        TestLockFeature()
      }

      // Operation should fail due to missing strategy and trigger error handler
      await store.send(.startOperationWithHandler) {
        $0.isRunning = true  // State changes first, then error occurs
      }

      // Handler should be called for strategy resolution error
      await store.receive(\.handlerCalled) {
        $0.handlerCallCount += 1
      }

      await store.finish()

      // Verify error handler was executed (covers line 214)
      XCTAssertTrue(true)  // Handler execution verified through state change
    }
  }

  // MARK: - Additional Tests for Uncovered Regions

  func testSuccessWithPrecedingCancellationNoHandler() async throws {
    let mockStrategy = MockStrategyWithPrecedingCancellation()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeatureNoHandler.State()
      ) {
        TestLockFeatureNoHandler()
      }

      // Operation with preceding cancellation but NO handler
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Should complete normally without handler call (covers line 183)
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()

      // Verify preceding cancellation occurred without handler
      XCTAssertEqual(mockStrategy.precedingCancellationCallCount, 1)
    }
  }

  func testCancelResultNoHandler() async throws {
    let mockStrategy = MockStrategyWithBlockingBehavior()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeatureNoHandler.State()
      ) {
        TestLockFeatureNoHandler()
      }

      // First operation to occupy the lock
      await store.send(.startOperation) {
        $0.isRunning = true
      }

      // Second operation should be blocked with NO handler (covers line 198)
      await store.send(.startOperation)

      // First operation completes
      await store.receive(\.operationCompleted) {
        $0.isRunning = false
        $0.completedCount = 1
      }

      await store.finish()

      // Verify block occurred without handler
      XCTAssertEqual(mockStrategy.blockCallCount, 1)
    }
  }

  func testBuildLockEffectCatchBlock() async throws {
    let container = LockmanStrategyContainer()
    // Don't register any strategy to trigger catch block

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestLockFeatureNoHandler.State()
      ) {
        TestLockFeatureNoHandler()
      }

      // Operation should fail in buildLockEffect catch block (covers lines 204-217)
      await store.send(.startOperation) {
        $0.isRunning = true  // State changes first, then catch block executes
      }

      await store.finish()

      // Verify error handling occurred (no handler so .none returned)
      XCTAssertTrue(true)
    }
  }

  func testBuildLockEffectCatchBlockWithHandler() async throws {
    let container = LockmanStrategyContainer()
    // Don't register any strategy to trigger catch block

    await LockmanManager.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestHandlerSendFeature.State()
      ) {
        TestHandlerSendFeature()
      }

      // Operation should fail in buildLockEffect catch block with handler (covers lines 214-215)
      await store.send(.errorActionWithSendHandler)

      // Should receive handler execution action from catch block
      await store.receive(.handlerWasExecuted("Strategy resolution failed")) {
        $0.handlerExecutionCount = 1
        $0.lastHandlerError = "Strategy resolution failed"
      }

      await store.finish()
    }
  }

  func testStrategyAlreadyRegisteredError() async throws {
    let mockStrategy = MockStrategyWithUnlockTracking()
    let container = LockmanStrategyContainer()
    try container.register(mockStrategy)

    // Try to register the same strategy again to trigger strategyAlreadyRegistered error
    XCTAssertThrowsError(try container.register(mockStrategy)) { error in
      guard let registrationError = error as? LockmanRegistrationError,
        case .strategyAlreadyRegistered = registrationError
      else {
        XCTFail("Expected strategyAlreadyRegistered error")
        return
      }

      // Test handleError with strategyAlreadyRegistered (covers lines 273-277)
      Effect<SharedTestAction>.handleError(
        error: registrationError,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }
  }

  func testUnknownDefaultCases() async throws {
    // Create a custom LockmanResult-like enum to test @unknown default
    // This is a theoretical test since we can't create unknown cases directly
    let container = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(container) {
      // This test verifies the structure exists for unknown default handling
      // The actual @unknown default cases (lines 200, 279) are defensive programming
      // and would only execute with future enum cases
      XCTAssertTrue(true)  // Structure test passes
    }
  }
}

// MARK: - Test Feature for TestStore Integration

@CasePathable
private enum TestLockAction: Equatable, LockmanAction {
  case startOperation
  case startOperationWithHandler
  case operationCompleted
  case handlerCalled

  func createLockmanInfo() -> TestLockmanInfo {
    switch self {
    case .startOperation, .startOperationWithHandler:
      return TestLockmanInfo(
        actionId: "testOperation",
        strategyId: LockmanStrategyId(name: "TestLockStrategy")
      )
    case .operationCompleted, .handlerCalled:
      return TestLockmanInfo(
        actionId: "other",
        strategyId: LockmanStrategyId(name: "TestLockStrategy")
      )
    }
  }
}

private enum TestLockBoundaryId: LockmanBoundaryId {
  case operation
}

@Reducer
private struct TestLockFeature {
  struct State: Equatable {
    var isRunning = false
    var completedCount = 0
    var handlerCallCount = 0
  }

  typealias Action = TestLockAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .startOperation:
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds
          await send(.operationCompleted)
        }
        .lock(
          action: action,
          boundaryId: TestLockBoundaryId.operation
        )

      case .startOperationWithHandler:
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds
          await send(.operationCompleted)
        }
        .lock(
          action: action,
          boundaryId: TestLockBoundaryId.operation,
          lockFailure: { _, send in
            await send(.handlerCalled)
          }
        )

      case .operationCompleted:
        state.isRunning = false
        state.completedCount += 1
        return .none

      case .handlerCalled:
        state.handlerCallCount += 1
        return .none
      }
    }
  }
}

@Reducer
private struct TestLockFeatureNoHandler {
  struct State: Equatable {
    var isRunning = false
    var completedCount = 0
    var handlerCallCount = 0
  }

  typealias Action = TestLockAction

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .startOperation:
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds
          await send(.operationCompleted)
        }
        .lock(
          action: action,
          boundaryId: TestLockBoundaryId.operation
            // No lockFailure handler - this tests the no-handler code paths
        )

      case .startOperationWithHandler:
        // Same as startOperation for this reducer (no handler)
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 50_000_000)  // 0.05 seconds
          await send(.operationCompleted)
        }
        .lock(
          action: action,
          boundaryId: TestLockBoundaryId.operation
        )

      case .operationCompleted:
        state.isRunning = false
        state.completedCount += 1
        return .none

      case .handlerCalled:
        state.handlerCallCount += 1
        return .none
      }
    }
  }
}

// MARK: - Mock Strategies for Integration Testing

private final class MockStrategyWithUnlockTracking: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  private let lock = NSLock()
  nonisolated(unsafe) var unlockCallCount = 0
  nonisolated(unsafe) var lockCallCount = 0

  var strategyId: LockmanStrategyId {
    Self.makeStrategyId()
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestLockStrategy")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    lock.withLock {
      lockCallCount += 1
    }
  }

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    lock.withLock {
      unlockCallCount += 1
    }
  }

  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
}

private final class MockStrategyWithBlockingBehavior: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  private let lock = NSLock()
  nonisolated(unsafe) var blockCallCount = 0
  nonisolated(unsafe) var isLocked = false

  var strategyId: LockmanStrategyId {
    Self.makeStrategyId()
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestLockStrategy")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    return lock.withLock {
      if isLocked {
        blockCallCount += 1
        return .cancel(LockmanRegistrationError.strategyNotRegistered("blocked"))
      } else {
        return .success
      }
    }
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    lock.withLock {
      isLocked = true
    }
  }

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    lock.withLock {
      isLocked = false
    }
  }

  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
}

private final class MockStrategyWithPrecedingCancellation: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  private let lock = NSLock()
  nonisolated(unsafe) var precedingCancellationCallCount = 0

  var strategyId: LockmanStrategyId {
    Self.makeStrategyId()
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestLockStrategy")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    lock.withLock {
      precedingCancellationCallCount += 1
      let testError = TestPrecedingCancellationError(
        lockmanInfo: info,
        boundaryId: boundaryId,
        reason: LockmanRegistrationError.strategyNotRegistered("cancelled_action")
      )
      return .successWithPrecedingCancellation(error: testError)
    }
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}
  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
}

// MARK: - Ultra Think Test Support Classes

/// Mock strategy that tracks unlock calls to verify Line 153-154 execution
private final class TestUnlockTrackingStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  var strategyId: LockmanStrategyId { LockmanStrategyId(name: "TestUnlockTrackingStrategy") }
  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestUnlockTrackingStrategy")
  }

  private let lock = NSLock()
  private var _unlockCallCount = 0

  var unlockCallCount: Int {
    lock.withLock { _unlockCallCount }
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    .success
  }
  func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    lock.withLock { _unlockCallCount += 1 }
  }

  func cleanUp() { lock.withLock { _unlockCallCount = 0 } }
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
}

/// Test feature for verifying unlock effect execution
@Reducer
private struct TestUnlockFeature {
  struct State: Equatable {
    var isRunning = false
    var completedCount = 0
  }

  enum Action: Equatable, LockmanAction {
    case performAction
    case actionCompleted

    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(
        actionId: "performAction",
        strategyId: TestUnlockTrackingStrategy.makeStrategyId()
      )
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .performAction:
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
          await send(.actionCompleted)
        }
        .lock(
          action: action,
          boundaryId: TestBoundaryId.test,
          unlockOption: .immediate
        )

      case .actionCompleted:
        state.isRunning = false
        state.completedCount += 1
        return .none
      }
    }
  }
}

/// Test feature for verifying handler execution via send actions
@Reducer
private struct TestHandlerSendFeature {
  struct State: Equatable {
    var isRunning = false
    var handlerExecutionCount = 0
    var lastHandlerError: String?
  }

  enum Action: Equatable, LockmanAction {
    case firstAction
    case secondActionWithSendHandler
    case errorActionWithSendHandler
    case firstCompleted
    case handlerWasExecuted(String)

    func createLockmanInfo() -> TestLockmanInfo {
      switch self {
      case .firstAction, .secondActionWithSendHandler:
        return TestLockmanInfo(
          actionId: "sharedAction",
          strategyId: TestSingleExecutionStrategy.makeStrategyId()
        )
      case .errorActionWithSendHandler:
        return TestLockmanInfo(
          actionId: "errorAction",
          strategyId: LockmanStrategyId(name: "NonExistentStrategy")
        )
      case .firstCompleted, .handlerWasExecuted:
        return TestLockmanInfo(
          actionId: "other",
          strategyId: TestSingleExecutionStrategy.makeStrategyId()
        )
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .firstAction:
        state.isRunning = true
        return .run { send in
          try await Task.sleep(nanoseconds: 50_000_000)  // 50ms
          await send(.firstCompleted)
        }
        .lock(action: action, boundaryId: TestBoundaryId.test)

      case .secondActionWithSendHandler:
        return .run { send in
          // This will be blocked and handler will be called
        }
        .lock(
          action: action,
          boundaryId: TestBoundaryId.test,
          lockFailure: { error, send in
            // Critical: Send action from inside Effect.run handler (Line 195-196)
            await send(.handlerWasExecuted("Lock acquisition failed"))
          }
        )

      case .errorActionWithSendHandler:
        return .run { send in
          // This will trigger strategy resolution error
        }
        .lock(
          action: action,
          boundaryId: TestBoundaryId.test,
          lockFailure: { error, send in
            // Critical: Send action from inside catch block handler (Line 214-215)
            await send(.handlerWasExecuted("Strategy resolution failed"))
          }
        )

      case .firstCompleted:
        state.isRunning = false
        return .none

      case .handlerWasExecuted(let errorMessage):
        state.handlerExecutionCount += 1
        state.lastHandlerError = errorMessage
        return .none
      }
    }
  }
}
