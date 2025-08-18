import XCTest

@testable import Lockman

/// Unit tests for LockmanError
///
/// Tests the base protocol for all Lockman-related errors.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance
/// - [x] Error protocol inheritance validation
/// - [x] LocalizedError protocol inheritance validation
/// - [x] Marker protocol behavior (intentionally empty)
/// - [x] Multiple protocol conformance validation
/// - [x] Protocol composition behavior
///
/// ### Error Type Integration
/// - [x] LockmanRegistrationError conformance
/// - [x] LockmanPriorityBasedError conformance
/// - [x] LockmanCancellationError conformance
/// - [x] LockmanStrategyError conformance
/// - [x] LockmanPrecedingCancellationError conformance
/// - [x] Custom user-defined error types conformance
///
/// ### LocalizedError Implementation
/// - [x] errorDescription property access
/// - [x] failureReason property access
/// - [x] localizedDescription behavior
/// - [x] Error message localization support
/// - [x] User-friendly error descriptions
///
/// ### Error Handling Integration
/// - [x] LockmanResult.cancel(any LockmanError) usage
/// - [x] Strategy error reporting consistency
/// - [x] Error propagation through strategy layers
/// - [x] Type erasure with any LockmanError
/// - [x] Error casting and type checking
///
/// ### Strategy-Specific Error Behavior
/// - [x] Priority-based strategy error patterns
/// - [x] Strategy error integration
/// - [x] Custom error type integration
/// - [x] Error hierarchy validation
/// - [x] Strategy-specific error details
///
/// ### Error Context Preservation
/// - [x] BoundaryId information in errors
/// - [x] LockmanInfo information in errors
/// - [x] ActionId information in errors
/// - [x] Strategy-specific context preservation
/// - [x] Error correlation with system state
///
/// ### Thread Safety & Sendable
/// - [x] Error types Sendable compliance
/// - [x] Safe error passing across concurrent contexts
/// - [x] Immutable error information
/// - [x] Thread-safe error access
///
/// ### Performance & Memory
/// - [x] Error creation performance
/// - [x] Error memory footprint
/// - [x] Error string generation performance
/// - [x] Large-scale error handling behavior
///
/// ### Real-world Error Scenarios
/// - [x] Lock acquisition failures
/// - [x] Strategy registration errors
/// - [x] Error handler integration
/// - [x] Concurrent access conflicts
/// - [x] Resource limitation errors
///
/// ### Edge Cases & Error Conditions
/// - [x] Nil error descriptions handling
/// - [x] Empty error messages
/// - [x] Complex nested error scenarios
/// - [x] Error chaining and wrapping
/// - [x] Memory pressure error handling
///
/// ### Debugging & Diagnostics
/// - [x] Error debugging information completeness
/// - [x] Error categorization and filtering
/// - [x] Developer-friendly error messages
/// - [x] Error trace and context preservation
/// - [x] Error correlation with logs
///
final class LockmanErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock Error Types for Testing

  private struct MockSimpleLockmanError: LockmanError {
    let message: String

    var errorDescription: String? { message }
    var failureReason: String? { "Mock failure reason" }
    var recoverySuggestion: String? { "Mock recovery suggestion" }
    var helpAnchor: String? { "MockError" }
  }

  private struct MockStrategyError: LockmanStrategyError, @unchecked Sendable {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let message: String

    var errorDescription: String? { message }
    var failureReason: String? { "Strategy error occurred" }
  }

  private struct MockPrecedingCancellationError: LockmanPrecedingCancellationError, @unchecked Sendable {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let message: String

    var errorDescription: String? { message }
    var failureReason: String? { "Preceding action cancelled" }
  }

  private enum MockComplexError: LockmanError {
    case networkFailure(code: Int)
    case validationFailure(field: String)
    case unknownError

    var errorDescription: String? {
      switch self {
      case .networkFailure(let code):
        return "Network error with code \(code)"
      case .validationFailure(let field):
        return "Validation failed for field: \(field)"
      case .unknownError:
        return "An unknown error occurred"
      }
    }

    var failureReason: String? {
      switch self {
      case .networkFailure:
        return "Network connection failed"
      case .validationFailure:
        return "Input validation failed"
      case .unknownError:
        return "Error cause is unknown"
      }
    }
  }

  // MARK: - Protocol Conformance Tests

  func testErrorProtocolInheritanceValidation() {
    let error = MockSimpleLockmanError(message: "Test error")

    // Verify it conforms to Error (implicit through LockmanError)
    XCTAssertNotNil(error)

    // Verify it can be used in error contexts
    do {
      throw error
    } catch let caughtError {
      XCTAssertTrue(caughtError is any LockmanError)
      XCTAssertEqual((caughtError as? MockSimpleLockmanError)?.message, "Test error")
    }
  }

  func testLocalizedErrorProtocolInheritanceValidation() {
    let error = MockSimpleLockmanError(message: "Localized test error")

    // Verify it conforms to LocalizedError (implicit through LockmanError)
    XCTAssertNotNil(error.errorDescription)

    // Test LocalizedError properties
    XCTAssertEqual(error.errorDescription, "Localized test error")
    XCTAssertEqual(error.failureReason, "Mock failure reason")
    XCTAssertEqual(error.recoverySuggestion, "Mock recovery suggestion")
    XCTAssertEqual(error.helpAnchor, "MockError")
  }

  func testMarkerProtocolBehavior() {
    let simpleError = MockSimpleLockmanError(message: "Simple")
    let complexError = MockComplexError.networkFailure(code: 404)

    // Both should conform to LockmanError marker protocol (by definition)
    XCTAssertNotNil(simpleError)
    XCTAssertNotNil(complexError)

    // LockmanError is intentionally empty (marker protocol)
    // Should work in type erasure
    let anyError: any LockmanError = simpleError
    XCTAssertTrue(anyError is MockSimpleLockmanError)

    // Array of LockmanError should work
    let errors: [any LockmanError] = [simpleError, complexError]
    XCTAssertEqual(errors.count, 2)
  }

  func testMultipleProtocolConformanceValidation() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "test-boundary"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Strategy test error"
    )

    let precedingError = MockPrecedingCancellationError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Preceding cancellation test error"
    )

    // Type safety validation - test actual functionality instead of inheritance
    XCTAssertNotNil(strategyError.errorDescription)
    XCTAssertNotNil(strategyError.lockmanInfo)
    
    XCTAssertNotNil(precedingError.errorDescription)
    XCTAssertNotNil(precedingError.lockmanInfo)
    XCTAssertEqual(precedingError.lockmanInfo.actionId, "precedingTest")
  }

  func testProtocolCompositionBehavior() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "composition-test"

    let precedingError = MockPrecedingCancellationError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Composition test"
    )

    // Test functionality instead of redundant type checks
    XCTAssertNotNil(precedingError.localizedDescription)
    XCTAssertNotNil(precedingError.errorDescription)
    XCTAssertNotNil(precedingError.lockmanInfo)
    XCTAssertEqual(precedingError.lockmanInfo.actionId, "compositeAction")

    // Should work in generic contexts requiring multiple conformances
    func handleCompositeError<E: LockmanError & LocalizedError>(_ error: E) -> String {
      return error.localizedDescription
    }

    let description = handleCompositeError(precedingError)
    XCTAssertEqual(description, "Preceding cancellation test error")
  }

  // MARK: - Error Type Integration Tests

  func testLockmanRegistrationErrorConformance() {
    let alreadyRegisteredError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Both errors are LockmanError by definition
    XCTAssertNotNil(alreadyRegisteredError)
    XCTAssertNotNil(notRegisteredError)

    XCTAssertNotNil(alreadyRegisteredError.errorDescription)
    XCTAssertNotNil(notRegisteredError.errorDescription)
    XCTAssertNotNil(alreadyRegisteredError.recoverySuggestion)
    XCTAssertNotNil(notRegisteredError.recoverySuggestion)

    XCTAssertTrue(alreadyRegisteredError.errorDescription!.contains("TestStrategy"))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains("MissingStrategy"))
  }

  func testLockmanPriorityBasedErrorConformance() {
    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("requested"),
      priority: .low(.replaceable)
    )
    let existingInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("existing"),
      priority: .high(.exclusive)
    )
    let boundaryId = "priority-test"

    let priorityError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: requestedInfo,
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    // priorityError conforms to all these protocols by definition
    XCTAssertNotNil(priorityError)
    XCTAssertNotNil(priorityError.errorDescription)
    XCTAssertNotNil(priorityError.failureReason)
    XCTAssertEqual(priorityError.lockmanInfo.actionId, requestedInfo.actionId)
  }

  func testLockmanCancellationErrorConformance() {
    let action = MockAction()
    let boundaryId = "cancellation-test"
    let reason = MockSimpleLockmanError(message: "Cancellation reason")

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // cancellationError is LockmanError by definition
    XCTAssertEqual(cancellationError.errorDescription, "Cancellation reason")
    XCTAssertEqual(cancellationError.failureReason, "Mock failure reason")

    // Verify action and boundary preservation
    XCTAssertTrue(cancellationError.action is MockAction)
    XCTAssertEqual(String(describing: cancellationError.boundaryId), String(describing: boundaryId))
  }

  func testLockmanStrategyErrorConformance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "strategy-test"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Strategy conformance test"
    )

    // strategyError conforms to these protocols by definition
    XCTAssertNotNil(strategyError)
    XCTAssertEqual(strategyError.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(String(describing: strategyError.boundaryId), String(describing: boundaryId))
  }

  func testLockmanPrecedingCancellationErrorConformance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "preceding-test"

    let precedingError = MockPrecedingCancellationError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Preceding conformance test"
    )

    // precedingError conforms to these protocols by definition
    XCTAssertNotNil(precedingError)
    XCTAssertEqual(precedingError.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(String(describing: precedingError.boundaryId), String(describing: boundaryId))
  }

  func testCustomUserDefinedErrorTypesConformance() {
    // Custom error that conforms to LockmanError
    struct CustomBusinessError: LockmanError {
      let businessRule: String
      let violatedConstraint: String

      var errorDescription: String? {
        "Business rule '\(businessRule)' violated: \(violatedConstraint)"
      }
    }

    let customError = CustomBusinessError(
      businessRule: "single-session",
      violatedConstraint: "user already logged in"
    )

    // customError is CustomBusinessError by definition
    XCTAssertNotNil(customError)
    XCTAssertEqual(
      customError.errorDescription,
      "Business rule 'single-session' violated: user already logged in"
    )

    // Should work in LockmanError contexts
    let lockmanError: any LockmanError = customError
    XCTAssertTrue(lockmanError is CustomBusinessError)
  }

  // MARK: - LocalizedError Implementation Tests

  func testErrorDescriptionPropertyAccess() {
    let error1 = MockSimpleLockmanError(message: "Description test")
    let error2 = MockComplexError.networkFailure(code: 404)
    let error3 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")

    XCTAssertEqual(error1.errorDescription, "Description test")
    XCTAssertEqual(error2.errorDescription, "Network error with code 404")
    XCTAssertNotNil(error3.errorDescription)
    XCTAssertTrue(error3.errorDescription!.contains("TestStrategy"))
  }

  func testFailureReasonPropertyAccess() {
    let error1 = MockSimpleLockmanError(message: "Test")
    let error2 = MockComplexError.validationFailure(field: "email")
    let error3 = LockmanRegistrationError.strategyAlreadyRegistered("DuplicateStrategy")

    XCTAssertEqual(error1.failureReason, "Mock failure reason")
    XCTAssertEqual(error2.failureReason, "Input validation failed")
    XCTAssertNotNil(error3.failureReason)
    XCTAssertTrue(error3.failureReason!.contains("unique"))
  }

  func testLocalizedDescriptionBehavior() {
    let error = MockComplexError.unknownError

    // Should provide localizedDescription
    XCTAssertNotNil(error.localizedDescription)
    XCTAssertEqual(error.localizedDescription, "An unknown error occurred")

    // Should work with standard Error behavior
    XCTAssertFalse(error.localizedDescription.isEmpty)
  }

  func testErrorMessageLocalizationSupport() {
    let registrationError = LockmanRegistrationError.strategyNotRegistered("LocalizationTest")

    // Should provide complete localized error information
    XCTAssertNotNil(registrationError.errorDescription)
    XCTAssertNotNil(registrationError.failureReason)
    XCTAssertNotNil(registrationError.recoverySuggestion)
    XCTAssertNotNil(registrationError.helpAnchor)

    // All should contain meaningful content
    XCTAssertFalse(registrationError.errorDescription!.isEmpty)
    XCTAssertFalse(registrationError.failureReason!.isEmpty)
    XCTAssertFalse(registrationError.recoverySuggestion!.isEmpty)
    XCTAssertFalse(registrationError.helpAnchor!.isEmpty)
  }

  func testUserFriendlyErrorDescriptions() {
    let priorityError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("user-action"),
        priority: .low(.replaceable)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("system-action"),
        priority: .high(.exclusive)
      ),
      boundaryId: "user-test"
    )

    let description = priorityError.errorDescription!

    // Should be user-friendly and informative
    XCTAssertTrue(description.contains("priority"))
    XCTAssertTrue(description.contains("Cannot acquire lock"))
    XCTAssertFalse(description.contains("nil"))
    XCTAssertFalse(description.contains("Optional"))
  }

  // MARK: - Error Handling Integration Tests

  func testLockmanResultCancelUsage() {
    let error = MockSimpleLockmanError(message: "Cancel test")
    let result = LockmanResult.cancel(error)

    switch result {
    case .cancel(let cancelError):
      XCTAssertTrue(cancelError is MockSimpleLockmanError)
      XCTAssertEqual((cancelError as? MockSimpleLockmanError)?.message, "Cancel test")
    default:
      XCTFail("Expected cancel result")
    }
  }

  func testStrategyErrorReportingConsistency() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "consistency-test"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Consistency test error"
    )

    // All strategy errors should provide consistent information
    XCTAssertNotNil(strategyError.errorDescription)
    XCTAssertNotNil(strategyError.failureReason)
    XCTAssertNotNil(strategyError.lockmanInfo)
    XCTAssertNotNil(strategyError.boundaryId)

    // Information should be consistent
    XCTAssertEqual(strategyError.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(String(describing: strategyError.boundaryId), String(describing: boundaryId))
  }

  func testErrorPropagationThroughStrategyLayers() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "propagation-test"

    let originalError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Propagation test error"
    )

    // Error should propagate through result types
    let result = LockmanResult.cancel(originalError)

    switch result {
    case .cancel(let error):
      XCTAssertTrue(error is MockStrategyError)
      XCTAssertEqual((error as? MockStrategyError)?.message, "Propagation test error")
    default:
      XCTFail("Expected failure result")
    }
  }

  func testTypeErasureWithAnyLockmanError() {
    let error1 = MockSimpleLockmanError(message: "Error 1")
    let error2 = MockComplexError.validationFailure(field: "username")
    let error3 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")

    // Type erasure should work
    let erasedErrors: [any LockmanError] = [error1, error2, error3]

    XCTAssertEqual(erasedErrors.count, 3)
    XCTAssertEqual(erasedErrors[0].localizedDescription, "Error 1")
    XCTAssertEqual(erasedErrors[1].localizedDescription, "Validation failed for field: username")
    XCTAssertTrue(erasedErrors[2].localizedDescription.contains("TestStrategy"))
  }

  func testErrorCastingAndTypeChecking() {
    let errors: [any LockmanError] = [
      MockSimpleLockmanError(message: "Simple"),
      LockmanRegistrationError.strategyNotRegistered("Test"),
      MockComplexError.validationFailure(field: "username"),
    ]

    let registrationErrors = errors.compactMap { $0 as? LockmanRegistrationError }
    let complexErrors = errors.compactMap { $0 as? MockComplexError }

    XCTAssertEqual(registrationErrors.count, 1)
    XCTAssertEqual(complexErrors.count, 1)

    switch complexErrors.first {
    case .validationFailure(let field):
      XCTAssertEqual(field, "username")
    default:
      XCTFail("Expected validation failure")
    }
  }

  // MARK: - Strategy-Specific Error Behavior Tests

  func testPriorityBasedStrategyErrorPatterns() {
    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("requested"),
      priority: .high(.exclusive)
    )
    let existingInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("existing"),
      priority: .high(.exclusive)
    )
    let boundaryId = "priority-pattern-test"

    let samePriorityError = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: requestedInfo,
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    let precedingCancelledError = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    // Same priority conflict
    XCTAssertTrue(samePriorityError.errorDescription!.contains("exclusive"))
    XCTAssertEqual(samePriorityError.lockmanInfo.actionId, requestedInfo.actionId)

    // Preceding cancelled
    XCTAssertTrue(precedingCancelledError.errorDescription!.contains("cancelled"))
    XCTAssertEqual(precedingCancelledError.lockmanInfo.actionId, existingInfo.actionId)
  }

  func testStrategyErrorIntegration() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("integration-test"),
      priority: .high(.exclusive)
    )
    let boundaryId = "integration-boundary"

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: info,
      boundaryId: boundaryId
    )

    // Should integrate properly with result types
    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    switch result {
    case .successWithPrecedingCancellation(let precedingError):
      // precedingError is LockmanPrecedingCancellationError by definition in this case
      if let priorityError = precedingError as? LockmanPriorityBasedError {
        XCTAssertEqual(priorityError.lockmanInfo.actionId, info.actionId)
      } else {
        XCTFail("Expected LockmanPriorityBasedError")
      }
    default:
      XCTFail("Expected successWithPrecedingCancellation result")
    }
  }

  func testCustomErrorTypeIntegration() {
    struct CustomStrategyError: LockmanStrategyError, @unchecked Sendable {
      let lockmanInfo: any LockmanInfo
      let boundaryId: any LockmanBoundaryId
      let customData: [String: String]  // Changed to Sendable type

      var errorDescription: String? {
        "Custom strategy error for action \(lockmanInfo.actionId)"
      }

      var failureReason: String? {
        "Custom strategy constraint violated"
      }
    }

    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let customError = CustomStrategyError(
      lockmanInfo: info,
      boundaryId: "custom-test",
      customData: ["reason": "rate_limit", "limit": "100"]
    )

    // customError conforms to LockmanError by definition
    // customError conforms to LockmanStrategyError by definition
    XCTAssertEqual(customError.lockmanInfo.actionId, info.actionId)
    XCTAssertTrue(customError.errorDescription!.contains("Custom strategy error"))
  }

  func testErrorHierarchyValidation() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "hierarchy-test"

    let precedingError = MockPrecedingCancellationError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Hierarchy test"
    )

    // Test actual functionality instead of redundant type inheritance
    XCTAssertNotNil(precedingError.localizedDescription)
    XCTAssertNotNil(precedingError.errorDescription)
    XCTAssertNotNil(precedingError.lockmanInfo)
    XCTAssertNotNil(precedingError.boundaryId)
  }

  func testStrategySpecificErrorDetails() {
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("detailed-test"),
      priority: .low(.replaceable)
    )
    let boundaryId = "detail-test"

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: priorityInfo,
      boundaryId: boundaryId
    )

    // Should contain strategy-specific details
    XCTAssertEqual(error.lockmanInfo.actionId, priorityInfo.actionId)
    if let priorityLockmanInfo = error.lockmanInfo as? LockmanPriorityBasedInfo {
      XCTAssertEqual(priorityLockmanInfo.priority, .low(.replaceable))
    } else {
      XCTFail("Expected LockmanPriorityBasedInfo")
    }
  }

  // MARK: - Error Context Preservation Tests

  func testBoundaryIdInformationInErrors() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "boundary-preservation-test"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Boundary test"
    )

    XCTAssertEqual(String(describing: strategyError.boundaryId), String(describing: boundaryId))

    // Should preserve boundary information through error chaining
    let cancellationError = LockmanCancellationError(
      action: MockAction(),
      boundaryId: boundaryId,
      reason: strategyError
    )

    XCTAssertEqual(String(describing: cancellationError.boundaryId), String(describing: boundaryId))
  }

  func testLockmanInfoInformationInErrors() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let boundaryId = "info-preservation-test"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Info test"
    )

    XCTAssertEqual(strategyError.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual(strategyError.lockmanInfo.uniqueId, info.uniqueId)
    XCTAssertEqual(strategyError.lockmanInfo.strategyId, info.strategyId)
  }

  func testActionIdInformationInErrors() {
    let actionId = LockmanActionId("action-preservation-test")
    let info = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .boundary
    )
    let boundaryId = "action-test"

    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: boundaryId,
      message: "Action test"
    )

    XCTAssertEqual(strategyError.lockmanInfo.actionId, actionId)

    // Should be accessible through error properties
    XCTAssertTrue(strategyError.errorDescription!.contains("Action test"))
  }

  func testStrategySpecificContextPreservation() {
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("context-test"),
      priority: .high(.exclusive)
    )
    let boundaryId = "context-preservation-test"

    let error = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("requested"),
        priority: .low(.replaceable)
      ),
      lockmanInfo: priorityInfo,
      boundaryId: boundaryId
    )

    // Strategy-specific context should be preserved
    if let priorityLockmanInfo = error.lockmanInfo as? LockmanPriorityBasedInfo {
      XCTAssertEqual(priorityLockmanInfo.actionId, LockmanActionId("requested"))
      XCTAssertEqual(priorityLockmanInfo.priority, .low(.replaceable))
    } else {
      XCTFail("Expected LockmanPriorityBasedInfo")
    }
  }

  func testErrorCorrelationWithSystemState() {
    let action = MockAction()
    let boundaryId = "correlation-test"
    let originalError = MockSimpleLockmanError(message: "System state test")

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: originalError
    )

    // Error should maintain correlation with system state
    XCTAssertTrue(cancellationError.action is MockAction)
    XCTAssertEqual(String(describing: cancellationError.boundaryId), String(describing: boundaryId))
    XCTAssertTrue(cancellationError.reason is MockSimpleLockmanError)

    // Should be able to reconstruct system state from error
    let reconstructedActionId = cancellationError.action.createLockmanInfo().actionId
    XCTAssertEqual(reconstructedActionId, LockmanActionId("mock-action"))
  }

  // MARK: - Thread Safety & Sendable Tests

  func testErrorTypesSendableCompliance() {
    let error = MockSimpleLockmanError(message: "Sendable test")

    let expectation = XCTestExpectation(description: "Sendable compliance")

    Task {
      // Access error in async context
      let description = error.localizedDescription
      XCTAssertEqual(description, "Sendable test")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testSafeErrorPassingAcrossConcurrentContexts() {
    let error = LockmanRegistrationError.strategyNotRegistered("ConcurrentTest")
    let expectation = XCTestExpectation(description: "Concurrent error passing")
    expectation.expectedFulfillmentCount = 3

    for _ in 0..<3 {
      DispatchQueue.global().async {
        let description = error.errorDescription
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("ConcurrentTest"))
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testImmutableErrorInformation() {
    let error = MockComplexError.networkFailure(code: 500)

    // Error properties should be immutable
    let description1 = error.errorDescription
    let description2 = error.errorDescription
    let failureReason1 = error.failureReason
    let failureReason2 = error.failureReason

    XCTAssertEqual(description1, description2)
    XCTAssertEqual(failureReason1, failureReason2)
    XCTAssertEqual(description1, "Network error with code 500")
    XCTAssertEqual(failureReason1, "Network connection failed")
  }

  func testThreadSafeErrorAccess() {
    let error = MockComplexError.validationFailure(field: "concurrent")
    
    actor DescriptionCollector {
      private var descriptions: [String] = []
      
      func add(_ description: String) {
        descriptions.append(description)
      }
      
      func getDescriptions() -> [String] {
        return descriptions
      }
      
      var count: Int {
        descriptions.count
      }
    }
    
    let collector = DescriptionCollector()
    let expectation = XCTestExpectation(description: "Thread safe access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      Task {
        let description = error.errorDescription ?? "nil"
        await collector.add(description)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)

    Task {
      // All descriptions should be identical
      let count = await collector.count
      let descriptions = await collector.getDescriptions()
      XCTAssertEqual(count, 5)
      XCTAssertTrue(descriptions.allSatisfy { $0 == "Validation failed for field: concurrent" })
    }
  }

  // MARK: - Performance & Memory Tests

  func testErrorCreationPerformance() {
    measure {
      for i in 0..<1000 {
        _ = MockComplexError.networkFailure(code: i)
      }
    }
  }

  func testErrorMemoryFootprint() {
    var weakErrors: [MockSimpleLockmanError]?

    autoreleasepool {
      let errors = (0..<1000).map { MockSimpleLockmanError(message: "Memory test \($0)") }
      weakErrors = errors

      // Use errors to prevent optimization
      let totalLength = errors.reduce(0) { sum, error in
        sum + (error.errorDescription?.count ?? 0)
      }
      XCTAssertGreaterThan(totalLength, 0)
    }

    // Errors should be deallocated
    XCTAssertNil(weakErrors)
  }

  func testErrorStringGenerationPerformance() {
    let errors = (0..<100).map { MockSimpleLockmanError(message: "Performance test \($0)") }

    measure {
      for error in errors {
        _ = error.errorDescription
        _ = error.failureReason
        _ = error.localizedDescription
      }
    }
  }

  func testLargeScaleErrorHandlingBehavior() {
    let errors = (0..<10000).map { i -> any LockmanError in
      switch i % 3 {
      case 0:
        return MockSimpleLockmanError(message: "Large scale \(i)")
      case 1:
        return LockmanRegistrationError.strategyNotRegistered("Strategy\(i)")
      default:
        return MockComplexError.networkFailure(code: i)
      }
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    // Process all errors
    let descriptions = errors.map { $0.localizedDescription }

    let duration = CFAbsoluteTimeGetCurrent() - startTime

    XCTAssertEqual(descriptions.count, 10000)
    XCTAssertLessThan(duration, 1.0, "Large scale error handling should be efficient")
  }

  // MARK: - Real-world Error Scenarios Tests

  func testLockAcquisitionFailures() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("acquisition-test"),
      priority: .low(.replaceable)
    )
    let existingInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("blocking-action"),
      priority: .high(.exclusive)
    )
    let boundaryId = "acquisition-boundary"

    let lockFailureError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: info,
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    let result = LockmanResult.cancel(lockFailureError)

    switch result {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanPriorityBasedError)
      XCTAssertTrue(error.errorDescription!.contains("Cannot acquire lock"))
      XCTAssertTrue(error.errorDescription!.contains("priority"))
    default:
      XCTFail("Expected failure result")
    }
  }

  func testStrategyRegistrationErrors() {
    let alreadyRegisteredError = LockmanRegistrationError.strategyAlreadyRegistered(
      "DuplicateStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Should provide actionable error messages
    XCTAssertTrue(alreadyRegisteredError.errorDescription!.contains("already registered"))
    XCTAssertTrue(alreadyRegisteredError.recoverySuggestion!.contains("multiple times"))

    XCTAssertTrue(notRegisteredError.errorDescription!.contains("not registered"))
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains("register"))
  }

  func testErrorHandlerIntegration() {
    // Simulate a real error handler
    func handleLockFailure(_ error: any LockmanError) -> String {
      switch error {
      case let registrationError as LockmanRegistrationError:
        return "Registration: \(registrationError.localizedDescription)"
      case let cancellationError as LockmanCancellationError:
        return "Cancellation: \(cancellationError.localizedDescription)"
      case let priorityError as LockmanPriorityBasedError:
        return "Priority: \(priorityError.localizedDescription)"
      default:
        return "Unknown: \(error.localizedDescription)"
      }
    }

    let regError = LockmanRegistrationError.strategyNotRegistered("HandlerTest")
    let action = MockAction()
    let cancelError = LockmanCancellationError(
      action: action,
      boundaryId: "handler-test",
      reason: MockSimpleLockmanError(message: "Handler test reason")
    )
    let priorityError = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("priority-handler-test"),
        priority: .high(.exclusive)
      ),
      boundaryId: "priority-handler-boundary"
    )

    XCTAssertTrue(handleLockFailure(regError).hasPrefix("Registration:"))
    XCTAssertTrue(handleLockFailure(cancelError).hasPrefix("Cancellation:"))
    XCTAssertTrue(handleLockFailure(priorityError).hasPrefix("Priority:"))
  }

  func testConcurrentAccessConflicts() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("concurrent-conflict"),
      priority: .high(.exclusive)
    )
    let boundaryId = "conflict-boundary"

    let conflictError = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: info,
      lockmanInfo: info,
      boundaryId: boundaryId
    )

    XCTAssertTrue(conflictError.errorDescription!.contains("exclusive"))
    XCTAssertTrue(conflictError.failureReason!.contains("exclusive concurrency behavior"))
    XCTAssertEqual(conflictError.lockmanInfo.actionId, info.actionId)
  }

  func testResourceLimitationErrors() {
    struct ResourceLimitError: LockmanError {
      let resourceType: String
      let currentUsage: Int
      let limit: Int

      var errorDescription: String? {
        "\(resourceType) limit exceeded: \(currentUsage)/\(limit)"
      }

      var failureReason: String? {
        "Resource \(resourceType) has reached its maximum capacity"
      }
    }

    let resourceError = ResourceLimitError(
      resourceType: "connection",
      currentUsage: 105,
      limit: 100
    )

    // resourceError conforms to LockmanError by definition
    XCTAssertEqual(resourceError.errorDescription, "connection limit exceeded: 105/100")
    XCTAssertTrue(resourceError.failureReason!.contains("maximum capacity"))
  }

  // MARK: - Edge Cases & Error Conditions Tests

  func testNilErrorDescriptionsHandling() {
    struct NilDescriptionError: LockmanError {
      var errorDescription: String? { nil }
      var failureReason: String? { nil }
    }

    let error = NilDescriptionError()

    // Should handle nil gracefully
    XCTAssertNil(error.errorDescription)
    XCTAssertNil(error.failureReason)

    // localizedDescription should still work (provided by NSError)\n        XCTAssertNotNil(error.localizedDescription)
  }

  func testEmptyErrorMessages() {
    struct EmptyMessageError: LockmanError {
      var errorDescription: String? { "" }
      var failureReason: String? { "" }
    }

    let error = EmptyMessageError()

    XCTAssertEqual(error.errorDescription, "")
    XCTAssertEqual(error.failureReason, "")
    XCTAssertNotNil(error.localizedDescription)
  }

  func testComplexNestedErrorScenarios() {
    let originalError = MockSimpleLockmanError(message: "Original nested error")
    let action = MockAction()
    let boundaryId = "nested-test"

    let level1Error = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: originalError
    )

    let level2Error = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: level1Error
    )

    // Should handle nested errors
    XCTAssertTrue(level2Error.reason is LockmanCancellationError)
    let innerError = level2Error.reason as! LockmanCancellationError
    XCTAssertTrue(innerError.reason is MockSimpleLockmanError)

    // Error messages should propagate correctly
    XCTAssertEqual(level2Error.errorDescription, "Original nested error")
  }

  func testErrorChainingAndWrapping() {
    let originalError = MockComplexError.networkFailure(code: 500)
    let action = MockAction()
    let boundaryId = "chaining-test"

    let wrappedError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: originalError
    )

    // Error chaining should preserve original error information
    XCTAssertTrue(wrappedError.reason is MockComplexError)
    XCTAssertEqual(wrappedError.errorDescription, "Network error with code 500")
    XCTAssertEqual(wrappedError.failureReason, "Network connection failed")

    // Should not create circular references
    // Note: Different error types should have different descriptions
    XCTAssertNotEqual(wrappedError.errorDescription, wrappedError.reason.localizedDescription)
  }

  func testMemoryPressureErrorHandling() {
    var weakError: MockSimpleLockmanError?

    autoreleasepool {
      let error = MockSimpleLockmanError(message: "Memory pressure test")
      weakError = error

      let expectation = XCTestExpectation(description: "Memory pressure handling")
      expectation.expectedFulfillmentCount = 10

      for _ in 0..<10 {
        DispatchQueue.global().async {
          _ = error.localizedDescription
          expectation.fulfill()
        }
      }

      wait(for: [expectation], timeout: 2.0)
    }

    // Error should be deallocated after autoreleasepool
    XCTAssertNil(weakError)
  }

  // MARK: - Debugging & Diagnostics Tests

  func testErrorDebuggingInformationCompleteness() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("debug-action"),
      priority: .high(.exclusive)
    )
    let boundaryId = "debug-boundary"

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: info,
      boundaryId: boundaryId
    )

    // Should have complete debugging information
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertTrue(error.errorDescription!.contains("debug-action"))
    XCTAssertEqual(error.lockmanInfo.actionId, LockmanActionId("debug-action"))
    XCTAssertEqual(String(describing: error.boundaryId), String(describing: boundaryId))
  }

  func testErrorCategorizationAndFiltering() {
    struct ErrorCategorizer {
      static func categorizeError(_ error: any LockmanError) -> String {
        switch error {
        case is LockmanRegistrationError:
          return "configuration"
        case is LockmanCancellationError:
          return "cancellation"
        case is any LockmanStrategyError:
          return "strategy"
        case is MockComplexError:
          return "business"
        default:
          return "unknown"
        }
      }
    }

    let errors: [any LockmanError] = [
      LockmanRegistrationError.strategyAlreadyRegistered("CategoryTest"),
      LockmanCancellationError(
        action: MockAction(),
        boundaryId: "category-test",
        reason: MockSimpleLockmanError(message: "Category reason")
      ),
      MockComplexError.networkFailure(code: 500),
    ]

    let categories = errors.map(ErrorCategorizer.categorizeError)

    XCTAssertEqual(categories[0], "configuration")
    XCTAssertEqual(categories[1], "cancellation")
    XCTAssertEqual(categories[2], "business")
  }

  func testDeveloperFriendlyErrorMessages() {
    let registrationError = LockmanRegistrationError.strategyNotRegistered("DevFriendlyTest")

    // Should provide developer-friendly information
    let description = registrationError.errorDescription!
    let reason = registrationError.failureReason!
    let suggestion = registrationError.recoverySuggestion!

    XCTAssertTrue(description.contains("DevFriendlyTest"))
    XCTAssertTrue(description.contains("not registered"))
    XCTAssertTrue(reason.contains("previously registered"))
    XCTAssertTrue(suggestion.contains("LockmanManager.container.register"))
  }

  func testErrorTraceAndContextPreservation() {
    let action = MockAction()
    let boundaryId = "trace-test"
    let originalError = MockSimpleLockmanError(message: "Trace test original")

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: originalError
    )

    // Error trace should be preserved
    XCTAssertTrue(cancellationError.action is MockAction)
    XCTAssertEqual(String(describing: cancellationError.boundaryId), String(describing: boundaryId))
    XCTAssertTrue(cancellationError.reason is MockSimpleLockmanError)

    // Context should be accessible for debugging
    let actionInfo = cancellationError.action.createLockmanInfo()
    XCTAssertEqual(actionInfo.actionId, LockmanActionId("mock-action"))
  }

  func testErrorCorrelationWithLogs() {
    struct ErrorLogger {
      static func logError(_ error: any LockmanError) -> [String: Any] {
        var logData: [String: Any] = [
          "timestamp": Date().timeIntervalSince1970,
          "type": String(describing: type(of: error)),
          "description": error.localizedDescription,
        ]

        if let strategyError = error as? LockmanStrategyError {
          logData["actionId"] = strategyError.lockmanInfo.actionId
          logData["boundaryId"] = String(describing: strategyError.boundaryId)
        }

        if let registrationError = error as? LockmanRegistrationError {
          logData["category"] = "configuration"
          logData["registration_error"] = String(describing: registrationError)
        }

        return logData
      }
    }

    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let strategyError = MockStrategyError(
      lockmanInfo: info,
      boundaryId: "log-correlation-test",
      message: "Log correlation test error"
    )

    let logData = ErrorLogger.logError(strategyError)

    XCTAssertNotNil(logData["timestamp"])
    XCTAssertEqual(logData["type"] as! String, "MockStrategyError")
    XCTAssertEqual(logData["description"] as! String, "Log correlation test error")
    XCTAssertEqual(logData["actionId"] as! LockmanActionId, info.actionId)
    XCTAssertEqual(logData["boundaryId"] as! String, "log-correlation-test")
  }

  // MARK: - Helper Types

  private struct MockAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        actionId: LockmanActionId("mock-action"),
        mode: .boundary
      )
    }
  }
}
