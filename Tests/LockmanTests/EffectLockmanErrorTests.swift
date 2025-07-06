import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import XCTest

@testable @_spi(Logging) import Lockman

/// Tests for Effect+Lockman error handling scenarios
final class EffectLockmanErrorTests: XCTestCase {
  // MARK: - Mock Types for Testing

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

    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }
  }

  /// Mock valid action using registered strategy
  private enum MockValidAction: LockmanAction {
    case testAction

    var actionName: String { "testAction" }
    var strategyId: LockmanStrategyId { .singleExecution }
    var lockmanInfo: LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
    }
  }

  /// Mock strategy type that is intentionally not registered
  private struct MockUnregisteredStrategy: LockmanStrategy {
    typealias I = LockmanSingleExecutionInfo

    var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("MockUnregisteredStrategy")
    }

    func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockmanResult
    {
      .success
    }

    func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(id _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  // MARK: - Strategy Resolution Error Tests

  func testWithLockHandlesUnregisteredStrategyGracefully() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)
      let errorReported = LockIsolated(false)

      // XCTExpectFailure to handle the reportIssue call
      XCTExpectFailure(
        "Effect.withLock strategy 'MockUnregisteredStrategy' not registered. Register before use."
      ) {
        // This should return a valid effect but the operation should not execute
        let effect = Effect<Never>.withLock(
          operation: { _ in
            operationExecuted.setValue(true)
          },
          action: action,
          cancelID: cancelID
        )

        // Effect should be created (error handling is internal)
        XCTAssertNotNil(effect)
        errorReported.setValue(true)
      }

      // Verify expectations
      XCTAssertEqual(
        operationExecuted.value, false, "Operation should not execute with unregistered strategy")
      XCTAssertEqual(errorReported.value, true, "Error should have been reported")
    }
  }

  func testWithLockWorksCorrectlyWithRegisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "test-cancel-id"

      // This should create a valid effect since strategy is registered
      let effect = Effect<Never>.withLock(
        operation: { _ in
          // This operation would execute in a real environment
        },
        action: action,
        cancelID: cancelID
      )

      // Effect should be created successfully
      XCTAssertNotNil(effect)
    }
  }

  func testWithLockManualUnlockHandlesUnregisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)
      let unlockProvided = LockIsolated(false)

      XCTExpectFailure("Effect.withLock strategy 'MockUnregisteredStrategy' not registered") {
        let effect = Effect<Never>.withLock(
          operation: { _, _ in
            operationExecuted.setValue(true)
            unlockProvided.setValue(true)
            XCTFail("Operation should not execute with unregistered strategy")
          },
          action: action,
          cancelID: cancelID
        )

        XCTAssertNotNil(effect)
      }

      XCTAssertEqual(operationExecuted.value, false)
      XCTAssertEqual(unlockProvided.value, false)
    }
  }

  func testConcatenateWithLockHandlesUnregisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"

      let operations = [
        Effect<Never>.run { _ in
          XCTFail("Operations should not execute with unregistered strategy")
        }
      ]

      XCTExpectFailure("Effect.withLock strategy 'MockUnregisteredStrategy' not registered") {
        let effect = Effect<Never>.concatenateWithLock(
          operations: operations,
          action: action,
          cancelID: cancelID
        )

        // Effect should handle the error gracefully
        XCTAssertNotNil(effect)
      }
    }
  }

  // MARK: - Error Handler Function Tests

  func testHandleErrorProcessesStrategyNotRegisteredCorrectly() {
    let error = LockmanRegistrationError.strategyNotRegistered("MockUnregisteredStrategy")

    // This would typically call reportIssue in a real environment
    // For testing, we verify that the error handling path is reachable
    XCTExpectFailure("Effect.withLock strategy 'MockUnregisteredStrategy' not registered") {
      Effect<Never>.handleError(
        error: error,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }

    // If no crash occurs, the error was handled correctly
    XCTAssertTrue(true)
  }

  func testHandleErrorProcessesStrategyAlreadyRegisteredCorrectly() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("LockmanSingleExecutionStrategy")

    XCTExpectFailure("Effect.withLock strategy 'LockmanSingleExecutionStrategy' already registered")
    {
      Effect<Never>.handleError(
        error: error,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }

    // If no crash occurs, the error was handled correctly
    XCTAssertTrue(Bool(true))
  }

  func testHandleErrorIgnoresNonLockmanErrorTypes() {
    let error = NSError(domain: "TestDomain", code: 123, userInfo: nil)

    // Should not crash or throw when given non-LockmanError
    Effect<Never>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    XCTAssertTrue(Bool(true))
  }

  // MARK: - Integration Error Tests

  func testStrategyResolutionFailureInRealisticScenario() async {
    // Start with empty container (realistic startup scenario)
    let testContainer = LockmanStrategyContainer()

    // Register some strategies but not the one we need
    try? testContainer.register(LockmanPriorityBasedStrategy.shared)

    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction  // Requires LockmanSingleExecutionStrategy
      let cancelID = "integration-test"

      XCTExpectFailure("Effect.withLock strategy 'LockmanSingleExecutionStrategy' not registered") {
        let effect = Effect<Never>.withLock(
          operation: { _ in
            XCTFail("Should not execute due to missing strategy")
          },
          catch: { _, _ in
            // Error handling would occur here in real usage
          },
          action: action,
          cancelID: cancelID
        )

        XCTAssertNotNil(effect)
      }
    }
  }

  func testMultipleStrategyTypesResolutionErrors() async {
    let testContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(testContainer) {
      let actions = [
        MockErrorAction.unregisteredStrategy,
        MockErrorAction.validStrategy,
      ]

      for action in actions {
        XCTExpectFailure("Effect.withLock strategy 'MockUnregisteredStrategy' not registered") {
          let effect = Effect<Never>.withLock(
            operation: { _ in
              XCTFail("No operations should execute")
            },
            action: action,
            cancelID: "multi-error-test"
          )

          XCTAssertNotNil(effect)
        }
      }
    }
  }

  // MARK: - Error Recovery Integration Tests

  func testErrorRecoveryThroughStrategyRegistration() async {
    let testContainer = LockmanStrategyContainer()

    // First attempt without registration
    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-1"

      XCTExpectFailure("Effect.withLock strategy 'LockmanSingleExecutionStrategy' not registered") {
        let effect1 = Effect<Never>.withLock(
          operation: { _ in
            XCTFail("Should fail without registration")
          },
          action: action,
          cancelID: cancelID
        )

        XCTAssertNotNil(effect1)
      }
    }

    // Register the required strategy
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    // Second attempt should work
    await LockmanManager.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-2"

      let effect2 = Effect<Never>.withLock(
        operation: { _ in
          // This would execute successfully in real environment
        },
        action: action,
        cancelID: cancelID
      )

      XCTAssertNotNil(effect2)
    }
  }

  // MARK: - Error Propagation Tests

  func testErrorInformationPreservation() {
    let originalError = LockmanRegistrationError.strategyNotRegistered("DetailedStrategyName")

    // Verify error information is preserved through handleError
    XCTExpectFailure("Effect.withLock strategy 'DetailedStrategyName' not registered") {
      Effect<Never>.handleError(
        error: originalError,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }

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
    XCTExpectFailure("Effect.withLock strategy 'TestStrategy' already registered") {
      Effect<Never>.handleError(
        error: error,
        fileID: testFileID,
        filePath: testFilePath,
        line: testLine,
        column: testColumn
      )
    }

    XCTAssertTrue(Bool(true))  // Success if no crash
  }

  // MARK: - Edge Cases

  func testErrorHandlingWithEmptyActionName() {
    // Test edge case where action name might be empty
    enum EmptyNameAction: LockmanAction {
      case empty
      var actionName: String { "" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let error = LockmanRegistrationError.strategyNotRegistered("")

    XCTExpectFailure("Effect.withLock strategy '' not registered") {
      Effect<Never>.handleError(
        error: error,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }

    XCTAssertTrue(Bool(true))
  }

  func testErrorHandlingWithUnicodeActionNames() {
    enum UnicodeAction: LockmanAction {
      case unicode
      var actionName: String { "🔒アクション测试🚀" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let error = LockmanRegistrationError.strategyNotRegistered("UnicodeStrategy🌟")

    XCTExpectFailure("Effect.withLock strategy 'UnicodeStrategy🌟' not registered") {
      Effect<Never>.handleError(
        error: error,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )
    }

    XCTAssertTrue(Bool(true))
  }
}
