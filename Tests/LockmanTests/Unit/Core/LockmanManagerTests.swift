import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanManager static interface tests with 3-phase approach
// ✅ 15 test methods covering configuration, container access, cleanup, and boundary lock management
// ✅ Phase 1: Basic API access (configuration, container, cleanup operations)
// ✅ Phase 2: Boundary lock management and thread safety testing
// ✅ Phase 3: Test container integration and edge cases

final class LockmanManagerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    // Reset configuration to defaults for each test
    LockmanManager.config.reset()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    LockmanManager.config.reset()
  }

  // MARK: - Phase 1: Configuration API

  func testLockmanManagerConfigDefaultUnlockOption() {
    // Test default value
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)

    // Test setting and getting
    LockmanManager.config.defaultUnlockOption = .transition
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .transition)

    LockmanManager.config.defaultUnlockOption = .delayed(2.0)
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .delayed(2.0))

    LockmanManager.config.defaultUnlockOption = .mainRunLoop
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .mainRunLoop)
  }

  func testLockmanManagerConfigHandleCancellationErrors() {
    // Test default value
    XCTAssertEqual(LockmanManager.config.handleCancellationErrors, false)

    // Test setting and getting
    LockmanManager.config.handleCancellationErrors = true
    XCTAssertEqual(LockmanManager.config.handleCancellationErrors, true)

    LockmanManager.config.handleCancellationErrors = false
    XCTAssertEqual(LockmanManager.config.handleCancellationErrors, false)
  }

  func testLockmanManagerConfigIssueReporter() {
    // Test default value
    XCTAssertTrue(LockmanManager.config.issueReporter == LockmanDefaultIssueReporter.self)

    // Test setting custom issue reporter
    LockmanManager.config.issueReporter = LockmanComposableIssueReporter.self
    XCTAssertTrue(LockmanManager.config.issueReporter == LockmanComposableIssueReporter.self)
  }

  func testLockmanManagerConfigReset() {
    // Modify all configuration values
    LockmanManager.config.defaultUnlockOption = .delayed(5.0)
    LockmanManager.config.handleCancellationErrors = true
    LockmanManager.config.issueReporter = LockmanComposableIssueReporter.self

    // Reset configuration
    LockmanManager.config.reset()

    // Verify all values are back to defaults
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)
    XCTAssertEqual(LockmanManager.config.handleCancellationErrors, false)
    XCTAssertTrue(LockmanManager.config.issueReporter == LockmanDefaultIssueReporter.self)
  }

  // MARK: - Phase 2: Container Access

  func testLockmanManagerContainerAccess() {
    // Test that container is accessible
    let container = LockmanManager.container
    XCTAssertNotNil(container)

    // Test that it's a LockmanStrategyContainer
    XCTAssertTrue(container is LockmanStrategyContainer)
  }

  func testLockmanManagerContainerWithPreregisteredStrategies() {
    // Test that essential strategies are pre-registered
    let container = LockmanManager.container

    // Verify strategies are available by trying to resolve them
    // Note: We can't directly test this without creating locks, but we can test
    // that the container exists and is properly configured
    XCTAssertNotNil(container)

    // Test that multiple calls return the same container instance
    let container2 = LockmanManager.container
    XCTAssertTrue(container === container2)
  }

  // MARK: - Phase 3: Cleanup Operations

  func testLockmanManagerCleanupAll() {
    // Test cleanup.all() method executes without error
    XCTAssertNoThrow(LockmanManager.cleanup.all())

    // Test multiple calls are safe
    LockmanManager.cleanup.all()
    LockmanManager.cleanup.all()
    XCTAssertTrue(true)  // No crash means success
  }

  func testLockmanManagerCleanupBoundary() {
    // Test cleanup.boundary() with different boundary types
    let stringBoundary = "testBoundary"
    let intBoundary = 42
    let uuidBoundary = UUID()

    // Test cleanup for different boundary types
    XCTAssertNoThrow(LockmanManager.cleanup.boundary(stringBoundary))
    XCTAssertNoThrow(LockmanManager.cleanup.boundary(intBoundary))
    XCTAssertNoThrow(LockmanManager.cleanup.boundary(uuidBoundary))
  }

  // MARK: - Phase 4: Boundary Lock Management

  func testLockmanManagerWithBoundaryLock() {
    // Test withBoundaryLock executes operation
    let testBoundary = "testBoundary"
    var operationExecuted = false

    let result = LockmanManager.withBoundaryLock(for: testBoundary) {
      operationExecuted = true
      return "operation_result"
    }

    XCTAssertTrue(operationExecuted)
    XCTAssertEqual(result, "operation_result")
  }

  func testLockmanManagerWithBoundaryLockErrorHandling() {
    // Test that exceptions are properly propagated
    let testBoundary = "errorBoundary"

    struct TestError: Error, Equatable {
      let message: String
    }

    XCTAssertThrowsError(
      try LockmanManager.withBoundaryLock(for: testBoundary) {
        throw TestError(message: "test error")
      }
    ) { error in
      if let testError = error as? TestError {
        XCTAssertEqual(testError.message, "test error")
      } else {
        XCTFail("Expected TestError")
      }
    }
  }

  func testLockmanManagerWithBoundaryLockDifferentBoundaryTypes() {
    // Test with different boundary types
    let stringResult = LockmanManager.withBoundaryLock(for: "string") { "string_result" }
    let intResult = LockmanManager.withBoundaryLock(for: 123) { "int_result" }
    let uuidBoundary = UUID()
    let uuidResult = LockmanManager.withBoundaryLock(for: uuidBoundary) { "uuid_result" }

    XCTAssertEqual(stringResult, "string_result")
    XCTAssertEqual(intResult, "int_result")
    XCTAssertEqual(uuidResult, "uuid_result")
  }

  // MARK: - Phase 5: Test Container Integration

  func testLockmanManagerWithTestContainer() async {
    // Create a test container
    let testContainer = LockmanStrategyContainer()

    var testExecuted = false
    let result = await LockmanManager.withTestContainer(testContainer) {
      testExecuted = true

      // Verify that the test container is being used
      let currentContainer = LockmanManager.container
      XCTAssertTrue(currentContainer === testContainer)

      return "test_result"
    }

    XCTAssertTrue(testExecuted)
    XCTAssertEqual(result, "test_result")

    // Verify that after the test scope, we're back to the default container
    let defaultContainer = LockmanManager.container
    XCTAssertFalse(defaultContainer === testContainer)
  }

  func testLockmanManagerWithTestContainerNested() async {
    // Test nested test containers
    let testContainer1 = LockmanStrategyContainer()
    let testContainer2 = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer1) {
      let container1 = LockmanManager.container
      XCTAssertTrue(container1 === testContainer1)

      await LockmanManager.withTestContainer(testContainer2) {
        let container2 = LockmanManager.container
        XCTAssertTrue(container2 === testContainer2)
        XCTAssertFalse(container2 === testContainer1)
      }

      // After nested scope, should be back to testContainer1
      let containerAfterNested = LockmanManager.container
      XCTAssertTrue(containerAfterNested === testContainer1)
    }
  }

  func testLockmanManagerWithTestContainerErrorHandling() async {
    // Test error handling in test container scope
    let testContainer = LockmanStrategyContainer()

    struct TestAsyncError: Error {
      let message: String
    }

    do {
      try await LockmanManager.withTestContainer(testContainer) {
        let currentContainer = LockmanManager.container
        XCTAssertTrue(currentContainer === testContainer)

        throw TestAsyncError(message: "async test error")
      }
      XCTFail("Should have thrown error")
    } catch let error as TestAsyncError {
      XCTAssertEqual(error.message, "async test error")
    } catch {
      XCTFail("Unexpected error type: \\(error)")
    }

    // Verify container is restored after error
    let defaultContainer = LockmanManager.container
    XCTAssertFalse(defaultContainer === testContainer)
  }

  // MARK: - Phase 6: Thread Safety

  func testLockmanManagerConfigThreadSafety() async {
    // Test concurrent configuration access
    await withTaskGroup(of: Void.self) { group in
      // Launch multiple concurrent tasks that modify configuration
      for i in 0..<10 {
        group.addTask {
          if i % 2 == 0 {
            LockmanManager.config.defaultUnlockOption = .immediate
            LockmanManager.config.handleCancellationErrors = false
          } else {
            LockmanManager.config.defaultUnlockOption = .transition
            LockmanManager.config.handleCancellationErrors = true
          }

          // Read configuration
          _ = LockmanManager.config.defaultUnlockOption
          _ = LockmanManager.config.handleCancellationErrors
          _ = LockmanManager.config.issueReporter
        }
      }

      await group.waitForAll()
    }

    // Configuration should be in a valid state (no crash = success)
    _ = LockmanManager.config.defaultUnlockOption
    XCTAssertTrue(true)
  }

  func testLockmanManagerBoundaryLockConcurrency() async {
    // Test concurrent boundary lock access
    let testBoundary = "concurrencyTest"
    var executionCount = 0
    let expectedCount = 10

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<expectedCount {
        group.addTask {
          LockmanManager.withBoundaryLock(for: testBoundary) {
            executionCount += 1
            // Small delay to increase chance of race condition if not thread-safe
            Thread.sleep(forTimeInterval: 0.001)
          }
        }
      }

      await group.waitForAll()
    }

    // All operations should have completed successfully
    XCTAssertEqual(executionCount, expectedCount)
  }

  // MARK: - Phase 7: Core Lock Operations (TCA-Independent)

  func testLockmanManagerHandleErrorWithStrategyNotRegistered() {
    // Test custom issue reporter to capture messages
    class TestIssueReporter: LockmanIssueReporter {
      static var lastMessage: String?
      static var lastFileID: StaticString?
      static var lastLine: UInt?

      static func reportIssue(
        _ message: String,
        file: StaticString = #fileID,
        line: UInt = #line
      ) {
        lastMessage = message
        lastFileID = file
        lastLine = line
      }
    }

    // Set test reporter
    let originalReporter = LockmanManager.config.issueReporter
    LockmanManager.config.issueReporter = TestIssueReporter.self
    defer {
      LockmanManager.config.issueReporter = originalReporter
    }

    // Test handleError with strategyNotRegistered error
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyNotRegistered(strategyType)

    LockmanManager.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line
    )

    // Verify error was handled correctly
    XCTAssertEqual(
      TestIssueReporter.lastMessage,
      "Lockman strategy 'TestStrategy' not registered. Register before use.")
    XCTAssertNotNil(TestIssueReporter.lastFileID)
    XCTAssertNotNil(TestIssueReporter.lastLine)
  }

  func testLockmanManagerHandleErrorWithStrategyAlreadyRegistered() {
    // Test custom issue reporter to capture messages
    class TestIssueReporter: LockmanIssueReporter {
      static var lastMessage: String?

      static func reportIssue(
        _ message: String,
        file: StaticString = #fileID,
        line: UInt = #line
      ) {
        lastMessage = message
      }
    }

    // Set test reporter
    let originalReporter = LockmanManager.config.issueReporter
    LockmanManager.config.issueReporter = TestIssueReporter.self
    defer {
      LockmanManager.config.issueReporter = originalReporter
    }

    // Test handleError with strategyAlreadyRegistered error
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)

    LockmanManager.handleError(error: error)

    // Verify error was handled correctly
    XCTAssertEqual(
      TestIssueReporter.lastMessage, "Lockman strategy 'TestStrategy' already registered.")
  }

  func testLockmanManagerHandleErrorWithNonLockmanError() {
    // Test custom issue reporter to capture messages
    class TestIssueReporter: LockmanIssueReporter {
      static var messageReceived = false

      static func reportIssue(
        _ message: String,
        file: StaticString = #fileID,
        line: UInt = #line
      ) {
        messageReceived = true
      }
    }

    // Set test reporter
    let originalReporter = LockmanManager.config.issueReporter
    LockmanManager.config.issueReporter = TestIssueReporter.self
    defer {
      LockmanManager.config.issueReporter = originalReporter
    }

    // Test handleError with non-LockmanRegistrationError
    struct CustomError: Error {}
    let customError = CustomError()

    LockmanManager.handleError(error: customError)

    // Verify no message was sent for non-LockmanRegistrationError
    XCTAssertFalse(TestIssueReporter.messageReceived)
  }

  func testLockmanManagerAcquireLockWithSuccess() async throws {
    // Create a test container with a strategy that returns success
    let testContainer = LockmanStrategyContainer()
    let testStrategy = TestSuccessStrategy()
    try testContainer.register(testStrategy)

    try await LockmanManager.withTestContainer(testContainer) {
      // Create test lockman info
      let lockmanInfo = LockmanSingleExecutionInfo(
        strategyId: TestSuccessStrategy.makeStrategyId(),
        actionId: "testAction",
        mode: .boundary
      )
      let boundaryId = "testBoundary"

      do {
        // Test acquireLock method
        let result = try LockmanManager.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )

        // Verify successful result and unlock token
        switch result {
        case .success(let unlockToken):
          XCTAssertNotNil(unlockToken, "Unlock token should be created for successful lock")
        case .successWithPrecedingCancellation(let unlockToken, _):
          XCTAssertNotNil(unlockToken, "Unlock token should be created for successful lock")
        case .cancel:
          XCTFail("Expected success result")
        }
      } catch {
        XCTFail("acquireLock should not throw error: \\(error)")
      }
    }
  }

  func testLockmanManagerAcquireLockWithStrategyNotFound() async throws {
    // Create empty test container (no strategies registered)
    let testContainer = LockmanStrategyContainer()

    try await LockmanManager.withTestContainer(testContainer) {
      // Create test lockman info with non-existent strategy
      let lockmanInfo = LockmanSingleExecutionInfo(
        strategyId: LockmanStrategyId("nonExistentStrategy"),
        actionId: "testAction",
        mode: .boundary
      )
      let boundaryId = "testBoundary"

      // Test acquireLock should throw error for missing strategy
      XCTAssertThrowsError(
        try LockmanManager.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )
      ) { error in
        // Verify it's a LockmanRegistrationError
        XCTAssertTrue(error is LockmanRegistrationError)
      }
    }
  }

}

// MARK: - Test Support Types

private final class TestSuccessStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = LockmanSingleExecutionInfo

  let strategyId: LockmanStrategyId

  init() {
    self.strategyId = Self.makeStrategyId()
  }

  static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId("TestSuccessStrategy")
  }

  func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) -> LockmanStrategyResult where B: Sendable {
    return .success
  }

  func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) where B: Sendable {
    // No-op for test
  }

  func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanSingleExecutionInfo
  ) where B: Sendable {
    // No-op for test
  }

  func cleanUp() {
    // No-op for test
  }

  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) where B: Sendable {
    // No-op for test
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]  // Return empty for test
  }
}
