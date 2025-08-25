import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import XCTest

@testable @_spi(Logging) import Lockman

/// Tests for Effect+Lockman error handling scenarios
final class EffectLockmanErrorTests: XCTestCase {
  // MARK: - Mock Types for Testing

  /// Mock issue reporter for testing
  private final class MockIssueReporter: LockmanIssueReporter {
    static var capturedMessages: [String] = []
    static var capturedFiles: [StaticString] = []
    static var capturedLines: [UInt] = []
    
    static func reportIssue(_ message: String, file: StaticString = #file, line: UInt = #line) {
      capturedMessages.append(message)
      capturedFiles.append(file)
      capturedLines.append(line)
    }
    
    static func reset() {
      capturedMessages.removeAll()
      capturedFiles.removeAll()
      capturedLines.removeAll()
    }
  }

  /// Mock action for testing error scenarios
  private enum MockErrorAction: LockmanAction {
    case unregisteredStrategy
    case validStrategy

    var actionName: String {
      switch self {
      case .unregisteredStrategy: return "unregisteredStrategy"
      case .validStrategy: return "validStrategy"
      }
    }

    var strategyId: LockmanStrategyId {
      LockmanStrategyId("MockUnregisteredStrategy")
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(strategyId: strategyId, actionId: actionName, mode: .boundary)
    }
  }

  /// Mock valid action using registered strategy
  private enum MockValidAction: LockmanAction {
    case testAction

    var actionName: String { "testAction" }
    var strategyId: LockmanStrategyId { .singleExecution }
    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(strategyId: strategyId, actionId: actionName, mode: .boundary)
    }
  }

  /// Mock strategy type that is intentionally not registered
  private struct MockUnregisteredStrategy: LockmanStrategy {
    typealias I = LockmanSingleExecutionInfo

    var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("MockUnregisteredStrategy")
    }

    func canLock<B: LockmanBoundaryId>(boundaryId _: B, info _: LockmanSingleExecutionInfo)
      -> LockmanResult
    {
      .success
    }

    func lock<B: LockmanBoundaryId>(boundaryId _: B, info _: LockmanSingleExecutionInfo) {}
    func unlock<B: LockmanBoundaryId>(boundaryId _: B, info _: LockmanSingleExecutionInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(boundaryId _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  // MARK: - Test Setup

  override func setUp() {
    super.setUp()
    MockIssueReporter.reset()
  }

  override func tearDown() {
    super.tearDown()
    MockIssueReporter.reset()
  }

  // MARK: - Strategy Resolution Error Tests

  func testWithLockHandlesUnregisteredStrategyGracefully() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)

      // This should return a valid effect but the operation should not execute
      let effect = Effect<Never>.run { _ in
        operationExecuted.setValue(true)
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      // Effect should be created (error handling is internal)
      XCTAssertNotNil(effect)

      // Verify expectations
      XCTAssertEqual(
        operationExecuted.value, false, "Operation should not execute with unregistered strategy")
      
      // Verify error was reported with expected content
      XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("MockUnregisteredStrategy") == true,
        "Should contain strategy name"
      )
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
        "Should contain 'not registered'"
      )
    }
  }

  func testWithLockWorksCorrectlyWithRegisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "test-cancel-id"

      // This should create a valid effect since strategy is registered
      let effect = Effect<Never>.run { _ in
        // This operation would execute in a real environment
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      // Effect should be created successfully
      XCTAssertNotNil(effect)
    }
  }

  func testWithLockHandlesUnregisteredStrategyWithOperation() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)
      let unlockProvided = LockIsolated(false)

      let effect = Effect<Never>.run { _ in
        operationExecuted.setValue(true)
        unlockProvided.setValue(true)
        XCTFail("Operation should not execute with unregistered strategy")
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      XCTAssertNotNil(effect)

      XCTAssertEqual(operationExecuted.value, false)
      XCTAssertEqual(unlockProvided.value, false)
      
      // Verify error was reported with expected content
      XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("MockUnregisteredStrategy") == true,
        "Should contain strategy name"
      )
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
        "Should contain 'not registered'"
      )
    }
  }

  func testConcatenateWithLockHandlesUnregisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"

      let operations = [
        Effect<Never>.run { _ in
          XCTFail("Operations should not execute with unregistered strategy")
        }
      ]

      let effect = Effect<Never>.lock(
        concatenating: operations,
        action: action,
        boundaryId: cancelID
      )

      // Effect should handle the error gracefully
      XCTAssertNotNil(effect)
      
      // Verify error was reported with expected content
      XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("MockUnregisteredStrategy") == true,
        "Should contain strategy name"
      )
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
        "Should contain 'not registered'"
      )
    }
  }

  // MARK: - Error Handler Function Tests

  func testHandleErrorProcessesStrategyNotRegisteredCorrectly() {
    let error = LockmanRegistrationError.strategyNotRegistered("MockUnregisteredStrategy")

    // Act - Use DI to inject mock reporter
    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Assert
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("MockUnregisteredStrategy") == true,
      "Should contain strategy name"
    )
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
      "Should contain 'not registered'"
    )
  }

  func testHandleErrorProcessesStrategyAlreadyRegisteredCorrectly() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("LockmanSingleExecutionStrategy")

    // Act - Use DI to inject mock reporter
    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Assert
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("LockmanSingleExecutionStrategy") == true,
      "Should contain strategy name"
    )
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("already registered") == true,
      "Should contain 'already registered'"
    )
  }

  func testHandleErrorIgnoresNonLockmanErrorTypes() {
    let error = NSError(domain: "TestDomain", code: 123, userInfo: nil)

    // Should not crash or throw when given non-LockmanError
    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Verify no error was reported for non-Lockman errors
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 0, "Should not report non-Lockman errors")
  }

  // MARK: - Integration Error Tests

  func testStrategyResolutionFailureInRealisticScenario() async {
    // Start with empty container (realistic startup scenario)
    let testContainer = LockmanStrategyContainer()

    // Register some strategies but not the one we need
    try? testContainer.register(LockmanPriorityBasedStrategy.shared)

    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let action = MockValidAction.testAction  // Requires LockmanSingleExecutionStrategy
      let cancelID = "integration-test"

      let effect = Effect<Never>.run { _ in
        XCTFail("Should not execute due to missing strategy")
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      XCTAssertNotNil(effect)
      
      // Verify error was reported with expected content
      XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("LockmanSingleExecutionStrategy") == true,
        "Should contain strategy name"
      )
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
        "Should contain 'not registered'"
      )
    }
  }

  func testMultipleStrategyTypesResolutionErrors() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let actions = [
        MockErrorAction.unregisteredStrategy,
        MockErrorAction.validStrategy,
      ]

      for action in actions {
        MockIssueReporter.reset()  // Reset for each iteration
        
        let effect = Effect<Never>.run { _ in
          XCTFail("No operations should execute")
        }
        .lock(
          action: action,
          boundaryId: "multi-error-test"
        )

        XCTAssertNotNil(effect)
        
        // Verify error was reported with expected content
        XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
        XCTAssertTrue(
          MockIssueReporter.capturedMessages.first?.contains("MockUnregisteredStrategy") == true,
          "Should contain strategy name"
        )
        XCTAssertTrue(
          MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
          "Should contain 'not registered'"
        )
      }
    }
  }

  // MARK: - Error Recovery Integration Tests

  func testErrorRecoveryThroughStrategyRegistration() async {
    let testContainer = LockmanStrategyContainer()

    // First attempt without registration
    await LockmanManager.withTestContainer(testContainer) {
      // Configure DI to use MockIssueReporter
      let originalReporter = LockmanManager.config.issueReporter
      LockmanManager.config.issueReporter = MockIssueReporter.self
      defer { LockmanManager.config.issueReporter = originalReporter }
      
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-1"

      let effect1 = Effect<Never>.run { _ in
        XCTFail("Should fail without registration")
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      XCTAssertNotNil(effect1)
      
      // Verify error was reported
      XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("LockmanSingleExecutionStrategy") == true,
        "Should contain strategy name"
      )
      XCTAssertTrue(
        MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
        "Should contain 'not registered'"
      )
    }

    // Register the required strategy
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    // Second attempt should work
    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-2"

      let effect2 = Effect<Never>.run { _ in
        // This would execute successfully in real environment
      }
      .lock(
        action: action,
        boundaryId: cancelID
      )

      XCTAssertNotNil(effect2)
    }
  }

  // MARK: - Error Propagation Tests

  func testErrorInformationPreservation() {
    let originalError = LockmanRegistrationError.strategyNotRegistered("DetailedStrategyName")

    // Verify error information is preserved through handleError
    Effect<Never>.handleError(
      error: originalError,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Verify error was reported with expected content
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("DetailedStrategyName") == true,
      "Should contain strategy name"
    )
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
      "Should contain 'not registered'"
    )

    // Test that error details are accessible
    switch originalError {
    case .strategyNotRegistered(let strategyType):
      XCTAssertEqual(strategyType, "DetailedStrategyName")
    default:
      XCTFail("Expected strategyNotRegistered error")
    }
  }

  func testSourceLocationInformationInErrorHandling() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")

    let testFileID: StaticString = "TestFile.swift"
    let testFilePath: StaticString = "/path/to/TestFile.swift"
    let testLine: UInt = 42
    let testColumn: UInt = 10

    // Verify that source location parameters are accepted
    Effect<Never>.handleError(
      error: error,
      fileID: testFileID,
      filePath: testFilePath,
      line: testLine,
      column: testColumn,
      reporter: MockIssueReporter.self
    )

    // Verify error was reported with expected content
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("TestStrategy") == true,
      "Should contain strategy name"
    )
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("already registered") == true,
      "Should contain 'already registered'"
    )
  }

  // MARK: - Edge Cases

  func testErrorHandlingWithEmptyActionName() {
    // Test edge case where action name might be empty
    enum EmptyNameAction: LockmanAction {
      case empty
      var actionName: String { "" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let error = LockmanRegistrationError.strategyNotRegistered("")

    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Verify error was reported with expected empty string
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("strategy '' not registered") == true,
      "Should contain empty strategy name"
    )
  }

  func testErrorHandlingWithUnicodeActionNames() {
    enum UnicodeAction: LockmanAction {
      case unicode
      var actionName: String { "🔒アクション测试🚀" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let error = LockmanRegistrationError.strategyNotRegistered("UnicodeStrategy🌟")

    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column,
      reporter: MockIssueReporter.self
    )

    // Verify error was reported with Unicode content
    XCTAssertEqual(MockIssueReporter.capturedMessages.count, 1)
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("UnicodeStrategy🌟") == true,
      "Should contain Unicode strategy name"
    )
    XCTAssertTrue(
      MockIssueReporter.capturedMessages.first?.contains("not registered") == true,
      "Should contain 'not registered'"
    )
  }
}
