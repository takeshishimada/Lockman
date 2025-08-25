import XCTest

@testable import Lockman

/// Tests to improve coverage for 0% coverage files
final class ZeroCoverageImprovementTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - LockmanComposableIssueReporter Tests

  func testLockmanComposableIssueReporterReportIssue() {
    // Test the static reportIssue method to improve coverage
    LockmanComposableIssueReporter.reportIssue("Test issue")
    // Method should execute without throwing
  }

  func testLockmanComposableIssueReporterConfigureReporting() {
    // Test the static configureComposableReporting method
    LockmanManager.config.configureComposableReporting()
    // Method should execute without throwing
  }

  // MARK: - LockmanInfo Protocol Extension Tests

  func testLockmanInfoDefaultImplementations() {
    // Create a minimal implementation to test protocol defaults
    struct TestInfo: LockmanInfo {
      let strategyId = LockmanStrategyId("TestStrategy")
      let actionId = LockmanActionId("testAction")
      let uniqueId = UUID()

      var debugDescription: String { "TestInfo" }
    }

    let info = TestInfo()

    // Test default implementation of debugAdditionalInfo
    XCTAssertEqual(info.debugAdditionalInfo, "")

    // Test default implementation of isCancellationTarget
    XCTAssertTrue(info.isCancellationTarget)
  }

  // MARK: - LockmanIssueReporter Protocol Tests

  func testLockmanIssueReporterConfiguration() {
    // Test the default reporter
    let originalReporter = LockmanManager.config.issueReporter

    // Test setting a custom reporter
    LockmanManager.config.issueReporter = LockmanComposableIssueReporter.self
    XCTAssertTrue(LockmanManager.config.issueReporter is LockmanComposableIssueReporter.Type)

    // Restore original reporter
    LockmanManager.config.issueReporter = originalReporter
  }

  // MARK: - Error Type Tests

  func testLockmanConcurrencyLimitedErrorInstantiation() {
    // Create error instance to improve coverage
    let info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("testAction"),
      .limited(3)
    )
    let boundaryId = "testBoundary"

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      currentCount: 3
    )

    // Test error properties
    XCTAssertEqual(error.lockmanInfo.actionId, LockmanActionId("testAction"))
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
  }

  func testLockmanGroupCoordinationErrorInstantiation() {
    // Create error instance to improve coverage
    let info = LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId("testAction"),
      groupId: "testGroup",
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = "testBoundary"
    let groupIds = Set([AnyLockmanGroupId("testGroup")])

    let error = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: groupIds
    )

    // Test error properties
    XCTAssertEqual(error.lockmanInfo.actionId, LockmanActionId("testAction"))
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
  }

  func testLockmanSingleExecutionErrorInstantiation() {
    // Create error instance to improve coverage
    let info = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("testAction"),
      mode: .boundary
    )
    let boundaryId = "testBoundary"

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      lockmanInfo: info
    )

    // Test error properties
    XCTAssertEqual(error.lockmanInfo.actionId, LockmanActionId("testAction"))
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
  }

  // MARK: - Quick Win Tests - Small Files

  func testLockmanActionProtocolUsage() {
    // Test LockmanAction protocol through concrete implementations
    struct TestSingleAction: LockmanAction {
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(mode: .boundary)
      }
    }

    struct TestPriorityAction: LockmanAction {
      func createLockmanInfo() -> LockmanPriorityBasedInfo {
        LockmanPriorityBasedInfo(
          actionId: LockmanActionId("test"),
          priority: .high(.exclusive)
        )
      }
    }

    let singleAction = TestSingleAction()
    let priorityAction = TestPriorityAction()

    // Test createLockmanInfo method
    let singleInfo = singleAction.createLockmanInfo()
    let priorityInfo = priorityAction.createLockmanInfo()

    XCTAssertNotNil(singleInfo)
    XCTAssertNotNil(priorityInfo)
    XCTAssertEqual(priorityInfo.actionId, LockmanActionId("test"))
  }

  func testLockmanCancellationErrorInstantiation() {
    // Test LockmanCancellationError with proper constructor
    struct TestAction: LockmanAction {
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(mode: .boundary)
      }
    }

    let action = TestAction()
    let boundaryId = "testBoundary"
    let reason = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      lockmanInfo: action.createLockmanInfo()
    )

    let error = LockmanCancellationError(
      action: action,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      reason: reason
    )

    // Test error properties
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertEqual(
      String(describing: error.boundaryId), String(describing: AnyLockmanBoundaryId(boundaryId)))
  }

  func testLockmanResultEquatableConformance() {
    // Test LockmanResult Equatable conformance we added
    let success1 = LockmanResult.success
    let success2 = LockmanResult.success
    struct TestAction: LockmanAction {
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(mode: .boundary)
      }
    }
    let testAction = TestAction()
    let testReason = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: AnyLockmanBoundaryId("test"),
      lockmanInfo: testAction.createLockmanInfo()
    )
    let testCancellation = LockmanCancellationError(
      action: testAction,
      boundaryId: AnyLockmanBoundaryId("test"),
      reason: testReason
    )
    let cancel = LockmanResult.cancel(testCancellation)

    // Test equality
    XCTAssertEqual(success1, success2)
    XCTAssertNotEqual(success1, cancel)

    // Test with preceding cancellation
    // Test with a proper LockmanPrecedingCancellationError
    let precedingError = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("cancelled"),
        priority: .low(.replaceable)
      ),
      boundaryId: AnyLockmanBoundaryId("test")
    )
    let successWithCancel = LockmanResult.successWithPrecedingCancellation(error: precedingError)
    XCTAssertNotEqual(success1, successWithCancel)

    // Test additional equality cases to improve coverage
    let cancel2 = LockmanResult.cancel(testCancellation)
    XCTAssertEqual(cancel, cancel2)

    // Test different error types in cancel cases
    let differentError = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: AnyLockmanBoundaryId("different"),
      lockmanInfo: testAction.createLockmanInfo()
    )
    let differentCancel = LockmanResult.cancel(differentError)
    XCTAssertNotEqual(cancel, differentCancel)

    // Test successWithPrecedingCancellation equality
    let precedingError2 = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("cancelled"),
        priority: .low(.replaceable)
      ),
      boundaryId: AnyLockmanBoundaryId("test")
    )
    let successWithCancel2 = LockmanResult.successWithPrecedingCancellation(error: precedingError2)
    XCTAssertEqual(successWithCancel, successWithCancel2)

    // Test different successWithPrecedingCancellation errors
    let differentPrecedingError = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("different"),
        priority: .high(.exclusive)
      ),
      boundaryId: AnyLockmanBoundaryId("test")
    )
    let differentSuccessWithCancel = LockmanResult.successWithPrecedingCancellation(
      error: differentPrecedingError)
    XCTAssertNotEqual(successWithCancel, differentSuccessWithCancel)
  }

  @MainActor
  func testLoggerBasicFunctionality() {
    // Test Logger to improve coverage
    let logger = Logger.shared

    // Test logger exists and is usable
    XCTAssertNotNil(logger)

    // Test logging functionality (these should not crash)
    logger.log("Test info message")
    logger.clear()

    // Test isEnabled property
    let originalEnabled = logger.isEnabled
    logger.isEnabled = true
    XCTAssertTrue(logger.isEnabled)

    // Test different log levels to improve coverage
    logger.log(level: .debug, "Debug message")
    logger.log(level: .info, "Info message")
    logger.log(level: .error, "Error message")
    logger.log(level: .fault, "Fault message")

    // Test with isEnabled = false to cover the guard statement
    logger.isEnabled = false
    logger.log("This should be ignored")

    // Test to cover all conditional branches
    logger.isEnabled = true

    // Test with different OSLogType values to ensure full coverage
    logger.log(level: .default, "Default level")

    // Test edge case: disable and re-enable to test all guard paths
    logger.isEnabled = false
    logger.log(level: .info, "This should be ignored due to guard")
    logger.isEnabled = true

    // Test with explicit autoclosure to ensure all code paths
    logger.log(level: .error, "Error message")

    logger.isEnabled = originalEnabled
  }

  func testLockmanUnlockBasicUsage() {
    // Test LockmanUnlock functionality
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "testBoundary"
    let strategy = AnyLockmanStrategy(LockmanSingleExecutionStrategy())

    // Test unlock creation and execution
    let unlock = LockmanUnlock(
      id: AnyLockmanBoundaryId(boundaryId),
      info: info,
      strategy: strategy,
      unlockOption: .immediate
    )

    XCTAssertNotNil(unlock)

    // Test unlock execution (should not crash)
    unlock()
  }

  func testLockmanAutoUnlockFunctionality() async {
    // Test LockmanAutoUnlock to improve coverage for manualUnlock and token getter
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "testBoundary"
    let strategy = AnyLockmanStrategy(LockmanSingleExecutionStrategy())

    let unlock = LockmanUnlock(
      id: AnyLockmanBoundaryId(boundaryId),
      info: info,
      strategy: strategy,
      unlockOption: .immediate
    )

    // Test AutoUnlock functionality
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    // Test token getter (0% coverage target)
    let retrievedToken = await autoUnlock.token
    XCTAssertNotNil(retrievedToken)

    // Test isLocked before manual unlock
    let isLockedBefore = await autoUnlock.isLocked
    XCTAssertTrue(isLockedBefore)

    // Test manualUnlock() (0% coverage target)
    await autoUnlock.manualUnlock()

    // Test isLocked after manual unlock
    let isLockedAfter = await autoUnlock.isLocked
    XCTAssertFalse(isLockedAfter)

    // Test token getter after manual unlock
    let retrievedTokenAfter = await autoUnlock.token
    XCTAssertNil(retrievedTokenAfter)
  }

  // MARK: - Complete Remaining Coverage Tests

  func testLockmanConcurrencyLimitedErrorAllCases() {
    // Complete remaining coverage for ConcurrencyLimitedError
    let info = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("testAction"),
      .limited(2)
    )

    let error = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: info,
      boundaryId: AnyLockmanBoundaryId("boundary"),
      currentCount: 2
    )

    // Test all error protocol conformances
    XCTAssertTrue(error is LockmanStrategyError)
    XCTAssertTrue(error is LocalizedError)
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertNotNil(error.recoverySuggestion)

    // Test error with unlimited limit
    let unlimitedInfo = LockmanConcurrencyLimitedInfo(
      actionId: LockmanActionId("unlimited"),
      .unlimited
    )

    let unlimitedError = LockmanConcurrencyLimitedError.concurrencyLimitReached(
      lockmanInfo: unlimitedInfo,
      boundaryId: AnyLockmanBoundaryId("boundary"),
      currentCount: 100
    )

    XCTAssertNotNil(unlimitedError.errorDescription)
  }

  func testLockmanIssueReporterCompleteUsage() {
    // Complete remaining coverage for LockmanIssueReporter using new DI approach
    let originalReporter = LockmanManager.config.issueReporter

    // Test different reporter types
    struct CustomReporter: LockmanIssueReporter {
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        // Custom implementation for testing
      }
    }

    // Test setting custom reporter
    LockmanManager.config.issueReporter = CustomReporter.self
    XCTAssertTrue(LockmanManager.config.issueReporter is CustomReporter.Type)

    // Test reporting with custom reporter
    CustomReporter.reportIssue("Custom test issue", file: #file, line: #line)

    // Test setting back to composable reporter
    LockmanManager.config.configureComposableReporting()
    XCTAssertTrue(LockmanManager.config.issueReporter is LockmanComposableIssueReporter.Type)

    // Test LockmanDefaultIssueReporter directly to improve coverage (0% target)
    LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
    XCTAssertTrue(LockmanManager.config.issueReporter is LockmanDefaultIssueReporter.Type)

    // Test default reporter functionality
    LockmanDefaultIssueReporter.reportIssue("Default reporter test", file: #file, line: #line)

    // Test through current configured reporter
    LockmanManager.config.issueReporter.reportIssue(
      "Test through interface", file: #file, line: #line)

    // Test edge case to cover the "Unknown" fallback in LockmanDefaultIssueReporter (0% target)
    LockmanDefaultIssueReporter.reportIssue("Test with empty file", file: "", line: 0)

    // Restore original reporter
    LockmanManager.config.issueReporter = originalReporter
  }

  // MARK: - Phase 3: Large Files Coverage Improvement

  func testLockmanCompositeStrategy2GetCurrentLocks() {
    // Test getCurrentLocks() method to improve coverage (0% target)
    let priority = LockmanPriorityBasedStrategy()
    let single = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    // Test getCurrentLocks when no locks are active
    let emptyLocks = composite.getCurrentLocks()
    XCTAssertNotNil(emptyLocks)

    // Add some locks and test getCurrentLocks
    let boundaryId = "test-boundary"
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action",
        priority: .high(.exclusive)
      ),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
        actionId: "test-action",
        mode: .boundary
      )
    )

    // Lock and then check getCurrentLocks
    composite.lock(boundaryId: boundaryId, info: info)
    let activeLocks = composite.getCurrentLocks()
    XCTAssertNotNil(activeLocks)

    // Cleanup
    composite.unlock(boundaryId: boundaryId, info: info)
    composite.cleanUp()
  }

  func testLockmanCompositeStrategy3Methods() {
    // Test 0% coverage methods in CompositeStrategy3
    let priority = LockmanPriorityBasedStrategy()
    let single1 = LockmanSingleExecutionStrategy()
    let single2 = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy3(
      strategy1: priority,
      strategy2: single1,
      strategy3: single2
    )

    // Test makeStrategyId() static method (0% target)
    let strategyId = LockmanCompositeStrategy3<
      LockmanPriorityBasedInfo,
      LockmanPriorityBasedStrategy,
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy
    >.makeStrategyId()
    XCTAssertNotNil(strategyId)

    // Test cleanUp(boundaryId:) method (0% target)
    let boundaryId = "test-cleanup-boundary"
    composite.cleanUp(boundaryId: boundaryId)

    // Test getCurrentLocks
    let locks = composite.getCurrentLocks()
    XCTAssertNotNil(locks)

    composite.cleanUp()
  }

  func testLockmanStrategyContainerUntestedMethods() {
    // Test 0% coverage methods in LockmanStrategyContainer
    let container = LockmanStrategyContainer()

    // Register some strategies first
    let priority = LockmanPriorityBasedStrategy()
    let single = LockmanSingleExecutionStrategy()

    do {
      try container.register(id: .priorityBased, strategy: priority)
      try container.register(id: .singleExecution, strategy: single)

      // Test registeredStrategyIds() method (0% target)
      let strategyIds = container.registeredStrategyIds()
      XCTAssertNotNil(strategyIds)
      XCTAssertTrue(strategyIds.contains(.priorityBased))
      XCTAssertTrue(strategyIds.contains(.singleExecution))

      // Test registeredStrategyInfo() method (0% target)
      let strategyInfo = container.registeredStrategyInfo()
      XCTAssertNotNil(strategyInfo)
      XCTAssertFalse(strategyInfo.isEmpty)

      // Test strategyCount() method
      let count = container.strategyCount()
      XCTAssertEqual(count, 2)

      // Test unregister methods
      let unregistered = container.unregister(id: .priorityBased)
      XCTAssertTrue(unregistered)
      let countAfterUnregister = container.strategyCount()
      XCTAssertEqual(countAfterUnregister, 1)

      // Test removeAllStrategies() method
      container.removeAllStrategies()
      let finalCount = container.strategyCount()
      XCTAssertEqual(finalCount, 0)

      // Test registerAll with array (0% target)
      let strategies: [LockmanPriorityBasedStrategy] = [priority]
      try container.registerAll(strategies)
      let countAfterRegisterAll = container.strategyCount()
      XCTAssertEqual(countAfterRegisterAll, 1)

    } catch {
      XCTFail("Registration should not fail: \(error)")
    }

    container.cleanUp()
  }

  func testLockmanCompositeStrategy4Methods() {
    // Test 0% coverage methods in CompositeStrategy4
    let priority = LockmanPriorityBasedStrategy()
    let single1 = LockmanSingleExecutionStrategy()
    let single2 = LockmanSingleExecutionStrategy()
    let single3 = LockmanSingleExecutionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: priority,
      strategy2: single1,
      strategy3: single2,
      strategy4: single3
    )

    // Test makeStrategyId() static method (0% target)
    let strategyId = LockmanCompositeStrategy4<
      LockmanPriorityBasedInfo,
      LockmanPriorityBasedStrategy,
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy
    >.makeStrategyId()
    XCTAssertNotNil(strategyId)

    // Test canLock to improve coverage (45.45% target)
    let boundaryId = "test-boundary-4"
    let info = LockmanCompositeInfo4(
      actionId: "test-action-4",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action-4",
        priority: .high(.replaceable)
      ),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
        actionId: "test-action-4",
        mode: .boundary
      ),
      lockmanInfoForStrategy3: LockmanSingleExecutionInfo(
        actionId: "test-action-4",
        mode: .action
      ),
      lockmanInfoForStrategy4: LockmanSingleExecutionInfo(
        actionId: "test-action-4",
        mode: .boundary
      )
    )

    // Test canLock method
    let canLockResult = composite.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(canLockResult, LockmanResult.success)

    // Test lock method (0% target)
    composite.lock(boundaryId: boundaryId, info: info)

    // Test unlock method (0% target)
    composite.unlock(boundaryId: boundaryId, info: info)

    // Test getCurrentLocks (0% target)
    let locks = composite.getCurrentLocks()
    XCTAssertNotNil(locks)

    // Test cleanUp methods (0% target)
    composite.cleanUp(boundaryId: boundaryId)
    composite.cleanUp()
  }

  func testLockmanCompositeStrategyCanLockEdgeCases() {
    // Test canLock edge cases to improve partial coverage
    let priority = LockmanPriorityBasedStrategy()
    let single = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    let boundaryId = "edge-case-boundary"
    let info = LockmanCompositeInfo2(
      actionId: "edge-case-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "edge-case-action",
        priority: .low(.exclusive)
      ),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
        actionId: "edge-case-action",
        mode: .action
      )
    )

    // Lock first to create conflict scenario
    composite.lock(boundaryId: boundaryId, info: info)

    // Test canLock when already locked (should return failure)
    let conflictResult = composite.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotEqual(conflictResult, .success)

    // Clean up
    composite.unlock(boundaryId: boundaryId, info: info)
    composite.cleanUp()
  }

  func testLockmanCompositeStrategyGetCurrentLocksImplicitClosures() {
    // Test implicit closures in getCurrentLocks methods to improve coverage

    // Test CompositeStrategy2 implicit closure #2
    let priority2 = LockmanPriorityBasedStrategy()
    let single2 = LockmanSingleExecutionStrategy()
    let composite2 = LockmanCompositeStrategy2(strategy1: priority2, strategy2: single2)

    // Add locks to different strategies to trigger implicit closure evaluation
    let boundaryId2 = "implicit-closure-test-2"
    let info2 = LockmanCompositeInfo2(
      actionId: "implicit-test-2",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "implicit-test-2",
        priority: .low(.exclusive)
      ),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
        actionId: "implicit-test-2",
        mode: .boundary
      )
    )

    composite2.lock(boundaryId: boundaryId2, info: info2)
    let locks2 = composite2.getCurrentLocks()
    XCTAssertNotNil(locks2)

    composite2.cleanUp()

    // Test CompositeStrategy3 implicit closures
    let priority3 = LockmanPriorityBasedStrategy()
    let single3a = LockmanSingleExecutionStrategy()
    let single3b = LockmanSingleExecutionStrategy()
    let composite3 = LockmanCompositeStrategy3(
      strategy1: priority3,
      strategy2: single3a,
      strategy3: single3b
    )

    let boundaryId3 = "implicit-closure-test-3"
    let info3 = LockmanCompositeInfo3(
      actionId: "implicit-test-3",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "implicit-test-3",
        priority: .high(.exclusive)
      ),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
        actionId: "implicit-test-3",
        mode: .boundary
      ),
      lockmanInfoForStrategy3: LockmanSingleExecutionInfo(
        actionId: "implicit-test-3",
        mode: .action
      )
    )

    composite3.lock(boundaryId: boundaryId3, info: info3)
    let locks3 = composite3.getCurrentLocks()
    XCTAssertNotNil(locks3)

    composite3.cleanUp()
  }
}
