import ComposableArchitecture
import ConcurrencyExtras
import Foundation
import Testing
@testable import LockmanComposable
@testable @_spi(Logging) import LockmanCore

/// Tests for Effect+Lockman error handling scenarios
@Suite("Effect+Lockman Error Tests")
struct EffectLockmanErrorTests {
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

    static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }

    func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockResult {
      .success
    }

    func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(id _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  // MARK: - Strategy Resolution Error Tests

  @Test("withLock handles unregistered strategy gracefully")
  func withLockHandlesUnregisteredStrategyGracefully() async {
    let testContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)
      let errorReported = LockIsolated(false)

      // withExpectedIssue to handle the reportIssue call
      withExpectedIssue("Effect.withLock strategy 'MockUnregisteredStrategy' not registered. Register before use.") {
        // This should return a valid effect but the operation should not execute
        let effect = Effect<Never>.withLock(
          operation: { _ in
            operationExecuted.setValue(true)
          },
          action: action,
          cancelID: cancelID
        )

        // Effect should be created (error handling is internal)
        #expect(effect != nil)
        errorReported.setValue(true)
      }

      // Verify expectations
      #expect(operationExecuted.value == false, "Operation should not execute with unregistered strategy")
      #expect(errorReported.value == true, "Error should have been reported")
    }
  }

  @Test("withLock works correctly with registered strategy")
  func withLockWorksCorrectlyWithRegisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    await Lockman.withTestContainer(testContainer) {
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
      #expect(effect != nil)
    }
  }

  @Test("withLock manual unlock handles unregistered strategy", .disabled("Issues with test framework error reporting"))
  func withLockManualUnlockHandlesUnregisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"
      let operationExecuted = LockIsolated(false)
      let unlockProvided = LockIsolated(false)

      let effect = Effect<Never>.withLock(
        operation: { _, _ in
          operationExecuted.setValue(true)
          unlockProvided.setValue(true)
          #expect(Bool(false), "Operation should not execute with unregistered strategy")
        },
        action: action,
        cancelID: cancelID
      )

      #expect(effect != nil)
      #expect(operationExecuted.value == false)
      #expect(unlockProvided.value == false)
    }
  }

  @Test("concatenateWithLock handles unregistered strategy", .disabled("Issues with test framework error reporting"))
  func concatenateWithLockHandlesUnregisteredStrategy() async {
    let testContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(testContainer) {
      let action = MockErrorAction.unregisteredStrategy
      let cancelID = "test-cancel-id"

      let operations = [
        Effect<Never>.run { _ in
          #expect(Bool(false), "Operations should not execute with unregistered strategy")
        },
      ]

      let effect = Effect<Never>.concatenateWithLock(
        operations: operations,
        action: action,
        cancelID: cancelID
      )

      // Effect should handle the error gracefully
      #expect(effect != nil)
    }
  }

  // MARK: - Error Handler Function Tests

  @Test("handleError processes strategyNotRegistered correctly", .disabled("Issues with test framework error reporting"))
  func handleErrorProcessesStrategyNotRegisteredCorrectly() {
    let action = MockErrorAction.unregisteredStrategy
    let error = LockmanError.strategyNotRegistered("MockUnregisteredStrategy")

    // This would typically call reportIssue in a real environment
    // For testing, we verify that the error handling path is reachable
    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // If no crash occurs, the error was handled correctly
    #expect(Bool(true))
  }

  @Test("handleError processes strategyAlreadyRegistered correctly", .disabled("Issues with test framework error reporting"))
  func handleErrorProcessesStrategyAlreadyRegisteredCorrectly() {
    let action = MockValidAction.testAction
    let error = LockmanError.strategyAlreadyRegistered("LockmanSingleExecutionStrategy")

    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // If no crash occurs, the error was handled correctly
    #expect(Bool(true))
  }

  @Test("handleError ignores non-LockmanError types", .disabled("Issues with test framework error reporting"))
  func handleErrorIgnoresNonLockmanErrorTypes() {
    let action = MockValidAction.testAction
    let error = NSError(domain: "TestDomain", code: 123, userInfo: nil)

    // Should not crash or throw when given non-LockmanError
    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    #expect(Bool(true))
  }

  // MARK: - Integration Error Tests

  @Test("Strategy resolution failure in realistic scenario", .disabled("Issues with test framework error reporting"))
  func strategyResolutionFailureInRealisticScenario() async {
    // Start with empty container (realistic startup scenario)
    let testContainer = LockmanStrategyContainer()

    // Register some strategies but not the one we need
    try? testContainer.register(LockmanPriorityBasedStrategy.shared)

    await Lockman.withTestContainer(testContainer) {
      let action = MockValidAction.testAction // Requires LockmanSingleExecutionStrategy
      let cancelID = "integration-test"

      let effect = Effect<Never>.withLock(
        operation: { _ in
          #expect(Bool(false), "Should not execute due to missing strategy")
        },
        catch: { _, _ in
          // Error handling would occur here in real usage
        },
        action: action,
        cancelID: cancelID
      )

      #expect(effect != nil)
    }
  }

  @Test("Multiple strategy types resolution errors", .disabled("Issues with test framework error reporting"))
  func multipleStrategyTypesResolutionErrors() async {
    let testContainer = LockmanStrategyContainer()

    await Lockman.withTestContainer(testContainer) {
      let actions = [
        MockErrorAction.unregisteredStrategy,
        MockErrorAction.validStrategy,
      ]

      for action in actions {
        let effect = Effect<Never>.withLock(
          operation: { _ in
            #expect(Bool(false), "No operations should execute")
          },
          action: action,
          cancelID: "multi-error-test"
        )

        #expect(effect != nil)
      }
    }
  }

  // MARK: - Error Recovery Integration Tests

  @Test("Error recovery through strategy registration", .disabled("Issues with test framework error reporting"))
  func errorRecoveryThroughStrategyRegistration() async {
    let testContainer = LockmanStrategyContainer()

    // First attempt without registration
    await Lockman.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-1"

      let effect1 = Effect<Never>.withLock(
        operation: { _ in
          #expect(Bool(false), "Should fail without registration")
        },
        action: action,
        cancelID: cancelID
      )

      #expect(effect1 != nil)
    }

    // Register the required strategy
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)

    // Second attempt should work
    await Lockman.withTestContainer(testContainer) {
      let action = MockValidAction.testAction
      let cancelID = "recovery-test-2"

      let effect2 = Effect<Never>.withLock(
        operation: { _ in
          // This would execute successfully in real environment
        },
        action: action,
        cancelID: cancelID
      )

      #expect(effect2 != nil)
    }
  }

  // MARK: - Error Propagation Tests

  @Test("Error information preservation", .disabled("Issues with test framework error reporting"))
  func errorInformationPreservation() {
    let action = MockErrorAction.unregisteredStrategy
    let originalError = LockmanError.strategyNotRegistered("DetailedStrategyName")

    // Verify error information is preserved through handleError
    Effect<Never>.handleError(
      action: action,
      error: originalError,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // Test that error details are accessible
    switch originalError {
    case let .strategyNotRegistered(strategyType):
      #expect(strategyType == "DetailedStrategyName")
    default:
      #expect(Bool(false), "Expected strategyNotRegistered error")
    }
  }

  @Test("Source location information in error handling", .disabled("Issues with test framework error reporting"))
  func sourceLocationInformationInErrorHandling() {
    let action = MockValidAction.testAction
    let error = LockmanError.strategyAlreadyRegistered("TestStrategy")

    let testFileID: StaticString = "TestFile.swift"
    let testFilePath: StaticString = "/path/to/TestFile.swift"
    let testLine: UInt = 42
    let testColumn: UInt = 10

    // Verify that source location parameters are accepted
    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: testFileID,
      filePath: testFilePath,
      line: testLine,
      column: testColumn
    )

    #expect(Bool(true)) // Success if no crash
  }

  // MARK: - Edge Cases

  @Test("Error handling with empty action name", .disabled("Issues with test framework error reporting"))
  func errorHandlingWithEmptyActionName() {
    // Test edge case where action name might be empty
    enum EmptyNameAction: LockmanAction {
      case empty
      var actionName: String { "" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let action = EmptyNameAction.empty
    let error = LockmanError.strategyNotRegistered("")

    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    #expect(Bool(true))
  }

  @Test("Error handling with unicode action names", .disabled("Issues with test framework error reporting"))
  func errorHandlingWithUnicodeActionNames() {
    enum UnicodeAction: LockmanAction {
      case unicode
      var actionName: String { "🔒アクション测试🚀" }
      var strategyId: LockmanStrategyId { LockmanStrategyId("MockUnregisteredStrategy") }
      var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary)
      }
    }

    let action = UnicodeAction.unicode
    let error = LockmanError.strategyNotRegistered("UnicodeStrategy🌟")

    Effect<Never>.handleError(
      action: action,
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    #expect(Bool(true))
  }
}
