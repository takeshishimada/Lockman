import XCTest

@testable import Lockman

/// Unit tests for LockmanCancellationError
///
/// Tests the unified error structure that wraps strategy-specific errors with action context.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Structure and Initialization
/// - [x] Basic initialization with action, boundaryId, and reason
/// - [x] Property storage and access (action, boundaryId, reason)
/// - [x] Type safety with any LockmanAction, any LockmanBoundaryId, any LockmanError
/// - [x] Immutable property behavior after initialization
/// - [x] Reference preservation for action instances
///
/// ### Protocol Conformance
/// - [x] LockmanError protocol conformance validation
/// - [x] LocalizedError protocol conformance and behavior
/// - [x] Error protocol inheritance validation
/// - [x] Sendable compliance for concurrent usage
/// - [x] Multiple protocol conformance behavior
///
/// ### LocalizedError Implementation
/// - [x] errorDescription delegation to underlying reason
/// - [x] failureReason delegation to underlying reason
/// - [x] localizedDescription behavior inheritance
/// - [x] Proper error message propagation
/// - [x] Nil handling from underlying reason
///
/// ### Action Context Preservation
/// - [x] Full action instance preservation (not just ID)
/// - [x] Action type information access
/// - [x] Action properties and methods availability
/// - [x] Type erasure behavior with any LockmanAction
/// - [x] Action equality comparison through preserved instances
///
/// ### Boundary Context Management
/// - [x] Boundary identifier preservation
/// - [x] Type erasure with any LockmanBoundaryId
/// - [x] Boundary equality comparison
/// - [x] String representation consistency
/// - [x] Complex boundary type support
///
/// ### Strategy Error Integration
/// - [x] Strategy-specific error preservation
/// - [x] LockmanSingleExecutionError wrapping
/// - [x] LockmanPriorityBasedError wrapping
/// - [x] Custom LockmanError implementations
/// - [x] Error type casting and inspection
/// - [x] Nested cancellation error scenarios
///
/// ### Error Handler Integration
/// - [x] Error handler usage patterns from documentation
/// - [x] Action inspection in error handlers
/// - [x] Strategy error switching and handling
/// - [x] Error recovery scenario implementation
/// - [x] Error context utilization
///
/// ### Real-world Usage Scenarios
/// - [x] Single execution strategy cancellation
/// - [x] Priority-based strategy preemption
/// - [x] Complex action cancellation scenarios
/// - [x] Multi-level error handling
/// - [x] Concurrent cancellation scenarios
///
/// ### Thread Safety & Concurrency
/// - [x] Concurrent access to error properties
/// - [x] Thread-safe error passing
/// - [x] Immutable error information
/// - [x] Safe action access across threads
/// - [x] Memory consistency across concurrent contexts
///
/// ### Performance & Memory
/// - [x] Error creation performance
/// - [x] Memory usage with preserved action references
/// - [x] Large-scale error handling behavior
/// - [x] Error cleanup and memory management
/// - [x] Weak reference scenarios
///
/// ### Edge Cases & Error Conditions
/// - [x] Nil error descriptions from underlying reason
/// - [x] Complex nested action structures
/// - [x] Very long error message chains
/// - [x] Circular reference prevention
/// - [x] Memory pressure scenarios
///
/// ### Integration with Error Systems
/// - [x] LockmanResult integration
/// - [x] Error propagation through effect systems
/// - [x] Error logging and debugging support
/// - [x] Error categorization and filtering
/// - [x] Error correlation with system state
///
final class LockmanCancellationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock Types for Testing

  private struct MockSimpleAction: LockmanAction {
    typealias I = LockmanSingleExecutionInfo

    let actionId: LockmanActionId

    init(actionId: LockmanActionId = LockmanActionId("mock-simple")) {
      self.actionId = actionId
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      return LockmanSingleExecutionInfo(
        actionId: actionId,
        mode: .boundary
      )
    }
  }

  private struct MockComplexAction: LockmanAction {
    typealias I = LockmanPriorityBasedInfo

    let userId: String
    let operation: String
    let priority: LockmanPriorityBasedInfo.Priority

    func createLockmanInfo() -> LockmanPriorityBasedInfo {
      return LockmanPriorityBasedInfo(
        actionId: LockmanActionId("\(operation)_\(userId)"),
        priority: priority
      )
    }
  }

  private struct MockCustomBoundary: LockmanBoundaryId {
    let module: String
    let identifier: String

    func hash(into hasher: inout Hasher) {
      hasher.combine(module)
      hasher.combine(identifier)
    }

    static func == (lhs: MockCustomBoundary, rhs: MockCustomBoundary) -> Bool {
      return lhs.module == rhs.module && lhs.identifier == rhs.identifier
    }
  }

  private struct MockStrategyError: LockmanError {
    let message: String
    let code: Int

    var errorDescription: String? { message }
    var failureReason: String? { "Mock strategy failure (code: \(code))" }
  }

  // MARK: - Structure and Initialization Tests

  func testBasicInitializationWithActionBoundaryIdAndReason() {
    let action = MockSimpleAction(actionId: LockmanActionId("init-test"))
    let boundaryId = "init-boundary"
    let reason = MockStrategyError(message: "Init test error", code: 1001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    XCTAssertEqual(
      cancellationError.action.createLockmanInfo().actionId, LockmanActionId("init-test"))
    XCTAssertEqual(String(describing: cancellationError.boundaryId), String(describing: boundaryId))
    XCTAssertEqual((cancellationError.reason as? MockStrategyError)?.message, "Init test error")
    XCTAssertEqual((cancellationError.reason as? MockStrategyError)?.code, 1001)
  }

  func testPropertyStorageAndAccess() {
    let action = MockComplexAction(
      userId: "user123",
      operation: "purchase",
      priority: .high(.exclusive)
    )
    let boundaryId = MockCustomBoundary(module: "Commerce", identifier: "payment")
    let reason = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "payment-test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Property access should work correctly
    XCTAssertNotNil(cancellationError.action)
    XCTAssertNotNil(cancellationError.boundaryId)
    XCTAssertNotNil(cancellationError.reason)

    // Type preservation
    XCTAssertTrue(cancellationError.action is MockComplexAction)
    XCTAssertTrue(cancellationError.boundaryId is MockCustomBoundary)
    XCTAssertTrue(cancellationError.reason is LockmanSingleExecutionError)
  }

  func testTypeSafetyWithTypeErasure() {
    let action: any LockmanAction = MockSimpleAction()
    let boundaryId: any LockmanBoundaryId = "type-safety-test"
    let reason: any LockmanError = MockStrategyError(message: "Type safety", code: 2001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle type erasure correctly
    XCTAssertNotNil(cancellationError.action)
    XCTAssertNotNil(cancellationError.boundaryId)
    XCTAssertNotNil(cancellationError.reason)

    // Should be able to cast back to specific types
    XCTAssertTrue(cancellationError.action is MockSimpleAction)
    XCTAssertTrue(cancellationError.boundaryId is String)
    XCTAssertTrue(cancellationError.reason is MockStrategyError)
  }

  func testImmutablePropertyBehaviorAfterInitialization() {
    let action = MockSimpleAction()
    let boundaryId = "immutable-test"
    let reason = MockStrategyError(message: "Immutable test", code: 3001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Properties should remain consistent across multiple accesses
    let action1 = cancellationError.action
    let action2 = cancellationError.action
    let boundaryId1 = cancellationError.boundaryId
    let boundaryId2 = cancellationError.boundaryId
    let reason1 = cancellationError.reason
    let reason2 = cancellationError.reason

    XCTAssertEqual(action1.createLockmanInfo().actionId, action2.createLockmanInfo().actionId)
    XCTAssertEqual(String(describing: boundaryId1), String(describing: boundaryId2))
    XCTAssertEqual(
      (reason1 as? MockStrategyError)?.message, (reason2 as? MockStrategyError)?.message)
  }

  func testReferencePreservationForActionInstances() {
    let originalAction = MockComplexAction(
      userId: "preserve-test",
      operation: "validate",
      priority: .high(.exclusive)
    )
    let boundaryId = "reference-test"
    let reason = MockStrategyError(message: "Reference test", code: 4001)

    let cancellationError = LockmanCancellationError(
      action: originalAction,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should preserve the original action's properties
    if let preservedAction = cancellationError.action as? MockComplexAction {
      XCTAssertEqual(preservedAction.userId, "preserve-test")
      XCTAssertEqual(preservedAction.operation, "validate")
      XCTAssertEqual(preservedAction.priority, .high(.exclusive))
    } else {
      XCTFail("Expected MockComplexAction to be preserved")
    }
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanErrorProtocolConformanceValidation() {
    let action = MockSimpleAction()
    let boundaryId = "protocol-test"
    let reason = MockStrategyError(message: "Protocol test", code: 5001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should work in LockmanError contexts
    let lockmanError: any LockmanError = cancellationError
    // Verify it can be type-erased to LockmanError
    XCTAssertNotNil(lockmanError)
  }

  func testLocalizedErrorProtocolConformanceAndBehavior() {
    let action = MockSimpleAction()
    let boundaryId = "localized-test"
    let reason = MockStrategyError(message: "Localized test error", code: 6001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should conform to LocalizedError
    XCTAssertTrue(cancellationError is any LocalizedError)

    // Should provide LocalizedError properties
    XCTAssertEqual(cancellationError.errorDescription, "Localized test error")
    XCTAssertEqual(cancellationError.failureReason, "Mock strategy failure (code: 6001)")
    XCTAssertNotNil(cancellationError.localizedDescription)
  }

  func testErrorProtocolInheritanceValidation() {
    let action = MockSimpleAction()
    let boundaryId = "error-inheritance-test"
    let reason = MockStrategyError(message: "Error inheritance", code: 7001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should work in error handling contexts
    do {
      throw cancellationError
    } catch let error {
      // Verify error can be caught and accessed
      XCTAssertNotNil(error)
      XCTAssertEqual(error.localizedDescription, cancellationError.localizedDescription)
    }
  }

  func testSendableComplianceForConcurrentUsage() async {
    let action = MockSimpleAction()
    let boundaryId = "sendable-test"
    let reason = MockStrategyError(message: "Sendable test", code: 8001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should be usable in concurrent contexts
    let results = try! await TestSupport.executeConcurrently(iterations: 5) {
      return cancellationError.errorDescription
    }

    XCTAssertEqual(results.count, 5)
    results.forEach { description in
      XCTAssertEqual(description, "Sendable test")
    }
  }

  func testMultipleProtocolConformanceBehavior() {
    let action = MockSimpleAction()
    let boundaryId = "multiple-protocol-test"
    let reason = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("multiple-test"),
        priority: .high(.exclusive)
      ),
      boundaryId: "multiple-boundary"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should work with protocol requirements

    // Should work in contexts requiring multiple conformances
    func handleMultipleProtocols<E: LockmanError & LocalizedError>(_ error: E) -> String {
      return error.localizedDescription
    }

    let description = handleMultipleProtocols(cancellationError)
    XCTAssertNotNil(description)
    XCTAssertFalse(description.isEmpty)
  }

  // MARK: - LocalizedError Implementation Tests

  func testErrorDescriptionDelegationToUnderlyingReason() {
    let action = MockSimpleAction()
    let boundaryId = "delegation-test"
    let reason = MockStrategyError(message: "Delegation test message", code: 9001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    XCTAssertEqual(cancellationError.errorDescription, "Delegation test message")
    XCTAssertEqual(reason.errorDescription, "Delegation test message")
  }

  func testFailureReasonDelegationToUnderlyingReason() {
    let action = MockSimpleAction()
    let boundaryId = "failure-reason-test"
    let reason = MockStrategyError(message: "Failure reason test", code: 10001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    XCTAssertEqual(cancellationError.failureReason, "Mock strategy failure (code: 10001)")
    XCTAssertEqual(reason.failureReason, "Mock strategy failure (code: 10001)")
  }

  func testLocalizedDescriptionBehaviorInheritance() {
    let action = MockSimpleAction()
    let boundaryId = "localized-behavior-test"
    let reason = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "localized-test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should provide meaningful localized description
    XCTAssertNotNil(cancellationError.localizedDescription)
    XCTAssertFalse(cancellationError.localizedDescription.isEmpty)
    XCTAssertEqual(cancellationError.localizedDescription, reason.localizedDescription)
  }

  func testProperErrorMessagePropagation() {
    let action = MockSimpleAction()
    let boundaryId = "propagation-test"
    let reason = LockmanRegistrationError.strategyNotRegistered("PropagationTestStrategy")

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Error message should propagate correctly
    XCTAssertTrue(cancellationError.errorDescription!.contains("PropagationTestStrategy"))
    XCTAssertTrue(cancellationError.errorDescription!.contains("not registered"))
    XCTAssertEqual(cancellationError.errorDescription, reason.errorDescription)
  }

  func testNilHandlingFromUnderlyingReason() {
    struct NilErrorDescriptionError: LockmanError {
      var errorDescription: String? { nil }
      var failureReason: String? { nil }
    }

    let action = MockSimpleAction()
    let boundaryId = "nil-handling-test"
    let reason = NilErrorDescriptionError()

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle nil descriptions gracefully
    XCTAssertNil(cancellationError.errorDescription)
    XCTAssertNil(cancellationError.failureReason)

    // localizedDescription should still work (from Error protocol)
    XCTAssertNotNil(cancellationError.localizedDescription)
  }

  // MARK: - Action Context Preservation Tests

  func testFullActionInstancePreservation() {
    let action = MockComplexAction(
      userId: "preservation-user",
      operation: "preservation-op",
      priority: .low(.replaceable)
    )
    let boundaryId = "preservation-test"
    let reason = MockStrategyError(message: "Preservation test", code: 11001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should preserve full action instance, not just ID
    if let preservedAction = cancellationError.action as? MockComplexAction {
      XCTAssertEqual(preservedAction.userId, "preservation-user")
      XCTAssertEqual(preservedAction.operation, "preservation-op")
      XCTAssertEqual(preservedAction.priority, .low(.replaceable))

      // Should be able to call methods on preserved action
      let info = preservedAction.createLockmanInfo()
      XCTAssertEqual(info.actionId, LockmanActionId("preservation-op_preservation-user"))
      XCTAssertEqual(info.priority, .low(.replaceable))
    } else {
      XCTFail("Expected MockComplexAction to be preserved")
    }
  }

  func testActionTypeInformationAccess() {
    let simpleAction = MockSimpleAction(actionId: LockmanActionId("type-info-simple"))
    let complexAction = MockComplexAction(
      userId: "type-info-user",
      operation: "type-info-op",
      priority: .high(.exclusive)
    )

    let simpleCancellation = LockmanCancellationError(
      action: simpleAction,
      boundaryId: "simple-test",
      reason: MockStrategyError(message: "Simple", code: 12001)
    )

    let complexCancellation = LockmanCancellationError(
      action: complexAction,
      boundaryId: "complex-test",
      reason: MockStrategyError(message: "Complex", code: 12002)
    )

    // Should preserve type information
    XCTAssertTrue(simpleCancellation.action is MockSimpleAction)
    XCTAssertTrue(complexCancellation.action is MockComplexAction)

    // Should be able to access type-specific properties
    if let simpleAct = simpleCancellation.action as? MockSimpleAction {
      XCTAssertEqual(simpleAct.actionId, LockmanActionId("type-info-simple"))
    }

    if let complexAct = complexCancellation.action as? MockComplexAction {
      XCTAssertEqual(complexAct.userId, "type-info-user")
      XCTAssertEqual(complexAct.operation, "type-info-op")
    }
  }

  func testActionPropertiesAndMethodsAvailability() {
    let action = MockComplexAction(
      userId: "method-test-user",
      operation: "method-test-op",
      priority: .high(.exclusive)
    )
    let boundaryId = "methods-test"
    let reason = MockStrategyError(message: "Methods test", code: 13001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should be able to call methods on the preserved action
    let info = cancellationError.action.createLockmanInfo()
    XCTAssertEqual(info.actionId, LockmanActionId("method-test-op_method-test-user"))

    // Should be able to access action properties through type casting
    if let complexAction = cancellationError.action as? MockComplexAction {
      XCTAssertEqual(complexAction.userId, "method-test-user")
      XCTAssertEqual(complexAction.operation, "method-test-op")
      XCTAssertEqual(complexAction.priority, .high(.exclusive))
    } else {
      XCTFail("Expected MockComplexAction")
    }
  }

  func testTypeErasureBehaviorWithAnyLockmanAction() {
    let action: any LockmanAction = MockSimpleAction(actionId: LockmanActionId("erasure-test"))
    let boundaryId = "erasure-boundary"
    let reason = MockStrategyError(message: "Type erasure test", code: 14001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle type erasure correctly
    XCTAssertNotNil(cancellationError.action)

    // Should be able to call protocol methods
    let info = cancellationError.action.createLockmanInfo()
    XCTAssertEqual(info.actionId, LockmanActionId("erasure-test"))

    // Should be able to cast back to concrete type
    XCTAssertTrue(cancellationError.action is MockSimpleAction)
    if let concreteAction = cancellationError.action as? MockSimpleAction {
      XCTAssertEqual(concreteAction.actionId, LockmanActionId("erasure-test"))
    }
  }

  func testActionEqualityComparisonThroughPreservedInstances() {
    let action1 = MockSimpleAction(actionId: LockmanActionId("equality-test"))
    let action2 = MockSimpleAction(actionId: LockmanActionId("equality-test"))
    let action3 = MockSimpleAction(actionId: LockmanActionId("different-action"))

    let cancellation1 = LockmanCancellationError(
      action: action1,
      boundaryId: "equality-test",
      reason: MockStrategyError(message: "Test 1", code: 15001)
    )

    let cancellation2 = LockmanCancellationError(
      action: action2,
      boundaryId: "equality-test",
      reason: MockStrategyError(message: "Test 2", code: 15002)
    )

    let cancellation3 = LockmanCancellationError(
      action: action3,
      boundaryId: "equality-test",
      reason: MockStrategyError(message: "Test 3", code: 15003)
    )

    // Should be able to compare action IDs through preserved instances
    XCTAssertEqual(
      cancellation1.action.createLockmanInfo().actionId,
      cancellation2.action.createLockmanInfo().actionId
    )
    XCTAssertNotEqual(
      cancellation1.action.createLockmanInfo().actionId,
      cancellation3.action.createLockmanInfo().actionId
    )
  }

  // MARK: - Boundary Context Management Tests

  func testBoundaryIdentifierPreservation() {
    let action = MockSimpleAction()
    let stringBoundary = "string-boundary-test"
    let customBoundary = MockCustomBoundary(module: "TestModule", identifier: "test-id")
    let intBoundary = 42

    let stringCancellation = LockmanCancellationError(
      action: action,
      boundaryId: stringBoundary,
      reason: MockStrategyError(message: "String", code: 16001)
    )

    let customCancellation = LockmanCancellationError(
      action: action,
      boundaryId: customBoundary,
      reason: MockStrategyError(message: "Custom", code: 16002)
    )

    let intCancellation = LockmanCancellationError(
      action: action,
      boundaryId: intBoundary,
      reason: MockStrategyError(message: "Int", code: 16003)
    )

    // Should preserve boundary identifiers correctly
    XCTAssertEqual(String(describing: stringCancellation.boundaryId), "string-boundary-test")
    XCTAssertEqual(String(describing: intCancellation.boundaryId), "42")

    // Should preserve custom boundary types
    XCTAssertTrue(customCancellation.boundaryId is MockCustomBoundary)
    if let preserved = customCancellation.boundaryId as? MockCustomBoundary {
      XCTAssertEqual(preserved.module, "TestModule")
      XCTAssertEqual(preserved.identifier, "test-id")
    }
  }

  func testTypeErasureWithAnyLockmanBoundaryId() {
    let action = MockSimpleAction()
    let boundaryId: any LockmanBoundaryId = "type-erased-boundary"
    let reason = MockStrategyError(message: "Type erasure boundary", code: 17001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle type erasure correctly
    XCTAssertNotNil(cancellationError.boundaryId)

    // Should be able to cast back to concrete type
    XCTAssertTrue(cancellationError.boundaryId is String)
    XCTAssertEqual(cancellationError.boundaryId as? String, "type-erased-boundary")
  }

  func testBoundaryEqualityComparison() {
    let action = MockSimpleAction()
    let boundary1 = "same-boundary"
    let boundary2 = "same-boundary"
    let boundary3 = "different-boundary"
    let reason = MockStrategyError(message: "Boundary equality", code: 18001)

    let cancellation1 = LockmanCancellationError(
      action: action,
      boundaryId: boundary1,
      reason: reason
    )

    let cancellation2 = LockmanCancellationError(
      action: action,
      boundaryId: boundary2,
      reason: reason
    )

    let cancellation3 = LockmanCancellationError(
      action: action,
      boundaryId: boundary3,
      reason: reason
    )

    // Should support equality comparison
    XCTAssertEqual(
      String(describing: cancellation1.boundaryId),
      String(describing: cancellation2.boundaryId)
    )
    XCTAssertNotEqual(
      String(describing: cancellation1.boundaryId),
      String(describing: cancellation3.boundaryId)
    )
  }

  func testStringRepresentationConsistency() {
    let action = MockSimpleAction()
    let boundaryId = "consistency-test-boundary"
    let reason = MockStrategyError(message: "Consistency test", code: 19001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // String representation should be consistent
    let representation1 = String(describing: cancellationError.boundaryId)
    let representation2 = String(describing: cancellationError.boundaryId)

    XCTAssertEqual(representation1, representation2)
    XCTAssertEqual(representation1, "consistency-test-boundary")
  }

  func testComplexBoundaryTypeSupport() {
    struct ComplexBoundary: LockmanBoundaryId {
      let level1: String
      let level2: Int
      let level3: [String]

      func hash(into hasher: inout Hasher) {
        hasher.combine(level1)
        hasher.combine(level2)
        hasher.combine(level3)
      }

      static func == (lhs: ComplexBoundary, rhs: ComplexBoundary) -> Bool {
        return lhs.level1 == rhs.level1 && lhs.level2 == rhs.level2 && lhs.level3 == rhs.level3
      }
    }

    let action = MockSimpleAction()
    let complexBoundary = ComplexBoundary(
      level1: "complex",
      level2: 123,
      level3: ["a", "b", "c"]
    )
    let reason = MockStrategyError(message: "Complex boundary", code: 20001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: complexBoundary,
      reason: reason
    )

    // Should support complex boundary types
    XCTAssertTrue(cancellationError.boundaryId is ComplexBoundary)
    if let preserved = cancellationError.boundaryId as? ComplexBoundary {
      XCTAssertEqual(preserved.level1, "complex")
      XCTAssertEqual(preserved.level2, 123)
      XCTAssertEqual(preserved.level3, ["a", "b", "c"])
    }
  }

  // MARK: - Strategy Error Integration Tests

  func testStrategySpecificErrorPreservation() {
    let action = MockSimpleAction()
    let boundaryId = "strategy-preservation-test"

    // Test with different strategy error types
    let singleExecutionError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "single-test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let priorityError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("requested"),
        priority: .low(.replaceable)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("existing"),
        priority: .high(.exclusive)
      ),
      boundaryId: "priority-test"
    )

    let singleCancellation = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: singleExecutionError
    )

    let priorityCancellation = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: priorityError
    )

    // Should preserve strategy-specific error information
    XCTAssertTrue(singleCancellation.reason is LockmanSingleExecutionError)
    XCTAssertTrue(priorityCancellation.reason is LockmanPriorityBasedError)

    // Should be able to access strategy-specific error details
    if let singleError = singleCancellation.reason as? LockmanSingleExecutionError {
      switch singleError {
      case .boundaryAlreadyLocked(let boundaryId, let info):
        XCTAssertEqual(String(describing: boundaryId), "single-test")
        XCTAssertEqual(info.mode, .boundary)
      default:
        XCTFail("Expected boundaryAlreadyLocked case")
      }
    }

    if let priorityErr = priorityCancellation.reason as? LockmanPriorityBasedError {
      switch priorityErr {
      case .higherPriorityExists(let requested, let existing, let boundaryId):
        XCTAssertEqual(requested.actionId, LockmanActionId("requested"))
        XCTAssertEqual(existing.actionId, LockmanActionId("existing"))
        XCTAssertEqual(String(describing: boundaryId), "priority-test")
      default:
        XCTFail("Expected higherPriorityExists case")
      }
    }
  }

  func testLockmanSingleExecutionErrorWrapping() {
    let action = MockSimpleAction()
    let boundaryId = "single-execution-test"
    let info = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("single-test"),
      mode: .action
    )

    let singleError = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "single-boundary",
      lockmanInfo: info
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: singleError
    )

    // Should wrap single execution errors correctly
    XCTAssertTrue(cancellationError.reason is LockmanSingleExecutionError)
    XCTAssertTrue(cancellationError.errorDescription!.contains("already running"))

    // Should preserve error context
    if case .actionAlreadyRunning(let errBoundaryId, let errInfo) = singleError {
      XCTAssertEqual(String(describing: errBoundaryId), "single-boundary")
      XCTAssertEqual(errInfo.actionId, LockmanActionId("single-test"))
      XCTAssertEqual(errInfo.mode, .action)
    }
  }

  func testLockmanPriorityBasedErrorWrapping() {
    let action = MockSimpleAction()
    let boundaryId = "priority-wrapping-test"

    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("requested-action"),
      priority: .high(.exclusive)
    )

    let existingInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("existing-action"),
      priority: .high(.exclusive)
    )

    let priorityError = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: requestedInfo,
      lockmanInfo: existingInfo,
      boundaryId: "priority-boundary"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: priorityError
    )

    // Should wrap priority-based errors correctly
    XCTAssertTrue(cancellationError.reason is LockmanPriorityBasedError)
    XCTAssertTrue(cancellationError.errorDescription!.contains("exclusive"))

    // Should preserve priority error context
    if case .samePriorityConflict(let reqInfo, let existInfo, let errBoundaryId) = priorityError {
      XCTAssertEqual(reqInfo.actionId, LockmanActionId("requested-action"))
      XCTAssertEqual(existInfo.actionId, LockmanActionId("existing-action"))
      XCTAssertEqual(String(describing: errBoundaryId), "priority-boundary")
    }
  }

  func testCustomLockmanErrorImplementations() {
    struct CustomBusinessError: LockmanError {
      let businessRule: String
      let violatedValue: String

      var errorDescription: String? {
        "Business rule '\(businessRule)' violated with value: \(violatedValue)"
      }

      var failureReason: String? {
        "Custom business constraint validation failed"
      }
    }

    let action = MockSimpleAction()
    let boundaryId = "custom-error-test"
    let customError = CustomBusinessError(
      businessRule: "max-concurrent-sessions",
      violatedValue: "5"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: customError
    )

    // Should handle custom LockmanError implementations
    XCTAssertTrue(cancellationError.reason is CustomBusinessError)
    XCTAssertEqual(
      cancellationError.errorDescription,
      "Business rule 'max-concurrent-sessions' violated with value: 5"
    )
    XCTAssertEqual(
      cancellationError.failureReason,
      "Custom business constraint validation failed"
    )
  }

  func testErrorTypeCastingAndInspection() {
    let action = MockSimpleAction()
    let boundaryId = "casting-test"

    let errors: [any LockmanError] = [
      MockStrategyError(message: "Mock error", code: 21001),
      LockmanSingleExecutionError.boundaryAlreadyLocked(
        boundaryId: "cast-test",
        lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
      ),
      LockmanRegistrationError.strategyNotRegistered("CastingTestStrategy"),
    ]

    let cancellationErrors = errors.map { error in
      LockmanCancellationError(action: action, boundaryId: boundaryId, reason: error)
    }

    // Should support error type casting and inspection
    XCTAssertTrue(cancellationErrors[0].reason is MockStrategyError)
    XCTAssertTrue(cancellationErrors[1].reason is LockmanSingleExecutionError)
    XCTAssertTrue(cancellationErrors[2].reason is LockmanRegistrationError)

    // Should be able to extract specific error information
    if let mockError = cancellationErrors[0].reason as? MockStrategyError {
      XCTAssertEqual(mockError.message, "Mock error")
      XCTAssertEqual(mockError.code, 21001)
    }

    if let registrationError = cancellationErrors[2].reason as? LockmanRegistrationError {
      XCTAssertTrue(registrationError.errorDescription!.contains("CastingTestStrategy"))
    }
  }

  func testNestedCancellationErrorScenarios() {
    let action = MockSimpleAction()
    let boundaryId = "nested-test"

    // Create a nested cancellation scenario
    let originalError = MockStrategyError(message: "Original error", code: 22001)
    let firstCancellation = LockmanCancellationError(
      action: action,
      boundaryId: "first-level",
      reason: originalError
    )

    let secondCancellation = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: firstCancellation
    )

    // Should handle nested cancellation errors
    XCTAssertTrue(secondCancellation.reason is LockmanCancellationError)

    // Should be able to unwrap nested errors
    if let nestedCancellation = secondCancellation.reason as? LockmanCancellationError {
      XCTAssertTrue(nestedCancellation.reason is MockStrategyError)
      XCTAssertEqual(nestedCancellation.errorDescription, "Original error")

      if let deepError = nestedCancellation.reason as? MockStrategyError {
        XCTAssertEqual(deepError.message, "Original error")
        XCTAssertEqual(deepError.code, 22001)
      }
    }
  }

  // MARK: - Error Handler Integration Tests

  func testErrorHandlerUsagePatternsFromDocumentation() {
    let action = MockComplexAction(
      userId: "handler-user",
      operation: "purchase",
      priority: .high(.exclusive)
    )
    let boundaryId = "purchase-boundary"

    let singleError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "purchase-locked",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let priorityError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("user-purchase"),
        priority: .high(.exclusive)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("system-maintenance"),
        priority: .high(.exclusive)
      ),
      boundaryId: "priority-conflict"
    )

    let singleCancellation = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: singleError
    )

    let priorityCancellation = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: priorityError
    )

    // Simulate error handler pattern from documentation
    func handleLockFailure(_ error: any LockmanError) -> String {
      if let cancellation = error as? LockmanCancellationError {
        // Access the actual action that was cancelled
        let cancelledAction = cancellation.action

        // Check the underlying strategy error
        switch cancellation.reason {
        case _ as LockmanSingleExecutionError:
          return
            "Single execution conflict for action \(cancelledAction.createLockmanInfo().actionId)"
        case let priorityError as LockmanPriorityBasedError:
          return "Priority conflict for action \(cancelledAction.createLockmanInfo().actionId)"
        default:
          return "Other error for action \(cancelledAction.createLockmanInfo().actionId)"
        }
      }
      return "Unknown error"
    }

    let singleResult = handleLockFailure(singleCancellation)
    let priorityResult = handleLockFailure(priorityCancellation)

    XCTAssertEqual(singleResult, "Single execution conflict for action purchase_handler-user")
    XCTAssertEqual(priorityResult, "Priority conflict for action purchase_handler-user")
  }

  func testActionInspectionInErrorHandlers() {
    let action = MockComplexAction(
      userId: "inspection-user",
      operation: "validate",
      priority: .low(.replaceable)
    )
    let boundaryId = "inspection-boundary"
    let reason = MockStrategyError(message: "Inspection test", code: 23001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Simulate action inspection in error handler
    func inspectCancelledAction(_ error: LockmanCancellationError) -> [String: Any] {
      var inspection: [String: Any] = [:]

      let action = error.action
      inspection["actionId"] = action.createLockmanInfo().actionId

      if let complexAction = action as? MockComplexAction {
        inspection["userId"] = complexAction.userId
        inspection["operation"] = complexAction.operation
        inspection["priority"] = String(describing: complexAction.priority)
      }

      inspection["boundaryId"] = String(describing: error.boundaryId)
      inspection["errorMessage"] = error.errorDescription

      return inspection
    }

    let inspection = inspectCancelledAction(cancellationError)

    XCTAssertEqual(
      inspection["actionId"] as? LockmanActionId, LockmanActionId("validate_inspection-user"))
    XCTAssertEqual(inspection["userId"] as? String, "inspection-user")
    XCTAssertEqual(inspection["operation"] as? String, "validate")
    XCTAssertTrue((inspection["priority"] as? String)?.contains("low") == true)
    XCTAssertEqual(inspection["boundaryId"] as? String, "inspection-boundary")
    XCTAssertEqual(inspection["errorMessage"] as? String, "Inspection test")
  }

  func testStrategyErrorSwitchingAndHandling() {
    let action = MockSimpleAction()
    let boundaryId = "switching-test"

    let errors: [any LockmanError] = [
      LockmanSingleExecutionError.actionAlreadyRunning(
        boundaryId: "single-switch",
        lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
      ),
      LockmanPriorityBasedError.precedingActionCancelled(
        lockmanInfo: LockmanPriorityBasedInfo(
          actionId: LockmanActionId("preceding-switch"),
          priority: .high(.exclusive)
        ),
        boundaryId: "priority-switch"
      ),
      LockmanRegistrationError.strategyNotRegistered("SwitchingTestStrategy"),
      MockStrategyError(message: "Custom switching error", code: 24001),
    ]

    let cancellationErrors = errors.map { error in
      LockmanCancellationError(action: action, boundaryId: boundaryId, reason: error)
    }

    // Simulate strategy error switching
    func categorizeStrategyError(_ cancellation: LockmanCancellationError) -> String {
      switch cancellation.reason {
      case is LockmanSingleExecutionError:
        return "single_execution"
      case is LockmanPriorityBasedError:
        return "priority_based"
      case is LockmanRegistrationError:
        return "registration"
      case is MockStrategyError:
        return "custom"
      default:
        return "unknown"
      }
    }

    let categories = cancellationErrors.map(categorizeStrategyError)

    XCTAssertEqual(categories, ["single_execution", "priority_based", "registration", "custom"])
  }

  func testErrorRecoveryScenarioImplementation() {
    let action = MockComplexAction(
      userId: "recovery-user",
      operation: "process",
      priority: .high(.exclusive)
    )
    let boundaryId = "recovery-boundary"

    let priorityError = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("recovery-action"),
        priority: .high(.exclusive)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("blocking-action"),
        priority: .high(.exclusive)
      ),
      boundaryId: "recovery-conflict"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: priorityError
    )

    // Simulate error recovery scenario
    struct RecoveryStrategy {
      static func suggestRecovery(for cancellation: LockmanCancellationError) -> String {
        switch cancellation.reason {
        case let priorityError as LockmanPriorityBasedError:
          switch priorityError {
          case .higherPriorityExists:
            return "retry_with_higher_priority"
          case .samePriorityConflict:
            return "retry_with_different_timing"
          case .precedingActionCancelled:
            return "continue_with_cancellation_handled"
          }
        case is LockmanSingleExecutionError:
          return "retry_after_delay"
        default:
          return "manual_intervention_required"
        }
      }
    }

    let recovery = RecoveryStrategy.suggestRecovery(for: cancellationError)
    XCTAssertEqual(recovery, "retry_with_higher_priority")
  }

  func testErrorContextUtilization() {
    let action = MockComplexAction(
      userId: "context-user",
      operation: "submit",
      priority: .high(.exclusive)
    )
    let boundaryId = MockCustomBoundary(module: "ContextModule", identifier: "context-id")
    let reason = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "context-locked",
      lockmanInfo: LockmanSingleExecutionInfo(
        actionId: LockmanActionId("context-action"),
        mode: .boundary
      )
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Simulate error context utilization
    struct ContextExtractor {
      static func extractFullContext(from cancellation: LockmanCancellationError) -> [String: Any] {
        var context: [String: Any] = [:]

        // Action context
        let actionInfo = cancellation.action.createLockmanInfo()
        context["action_id"] = actionInfo.actionId
        context["action_strategy"] = actionInfo.strategyId

        if let complexAction = cancellation.action as? MockComplexAction {
          context["user_id"] = complexAction.userId
          context["operation"] = complexAction.operation
          context["priority"] = String(describing: complexAction.priority)
        }

        // Boundary context
        if let customBoundary = cancellation.boundaryId as? MockCustomBoundary {
          context["boundary_module"] = customBoundary.module
          context["boundary_id"] = customBoundary.identifier
        } else {
          context["boundary_id"] = String(describing: cancellation.boundaryId)
        }

        // Error context
        context["error_type"] = String(describing: type(of: cancellation.reason))
        context["error_description"] = cancellation.errorDescription

        if let singleError = cancellation.reason as? LockmanSingleExecutionError {
          context["error_category"] = "single_execution"
          switch singleError {
          case .boundaryAlreadyLocked(let errBoundaryId, let errInfo):
            context["conflict_boundary"] = String(describing: errBoundaryId)
            context["conflict_action"] = errInfo.actionId
          case .actionAlreadyRunning(let errBoundaryId, let errInfo):
            context["running_boundary"] = String(describing: errBoundaryId)
            context["running_action"] = errInfo.actionId
          }
        }

        return context
      }
    }

    let context = ContextExtractor.extractFullContext(from: cancellationError)

    XCTAssertEqual(context["action_id"] as? LockmanActionId, LockmanActionId("submit_context-user"))
    XCTAssertEqual(context["user_id"] as? String, "context-user")
    XCTAssertEqual(context["operation"] as? String, "submit")
    XCTAssertEqual(context["boundary_module"] as? String, "ContextModule")
    XCTAssertEqual(context["boundary_id"] as? String, "context-id")
    XCTAssertEqual(context["error_category"] as? String, "single_execution")
    XCTAssertEqual(context["conflict_boundary"] as? String, "context-locked")
    XCTAssertEqual(
      context["conflict_action"] as? LockmanActionId, LockmanActionId("context-action"))
  }

  // MARK: - Thread Safety & Concurrency Tests

  func testConcurrentAccessToErrorProperties() async {
    let action = MockSimpleAction()
    let boundaryId = "concurrent-access-test"
    let reason = MockStrategyError(message: "Concurrent test", code: 25001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      let actionId = cancellationError.action.createLockmanInfo().actionId
      let boundaryStr = String(describing: cancellationError.boundaryId)
      let errorDesc = cancellationError.errorDescription ?? "nil"

      return "\(actionId)|\(boundaryStr)|\(errorDesc)"
    }

    // All results should be identical
    XCTAssertEqual(results.count, 10)
    let expected = "mock-simple|concurrent-access-test|Concurrent test"
    results.forEach { result in
      XCTAssertEqual(result, expected)
    }
  }

  func testThreadSafeErrorPassing() {
    let action = MockSimpleAction()
    let boundaryId = "thread-safe-test"
    let reason = MockStrategyError(message: "Thread safe test", code: 26001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    let expectation = XCTestExpectation(description: "Thread safe error passing")
    expectation.expectedFulfillmentCount = 5

    let lock = NSLock()
    var descriptions: [String] = []

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let description = cancellationError.errorDescription ?? "nil"
        lock.withLock {
          descriptions.append(description)
        }
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)

    // All descriptions should be identical
    XCTAssertEqual(descriptions.count, 5)
    descriptions.forEach { description in
      XCTAssertEqual(description, "Thread safe test")
    }
  }

  func testImmutableErrorInformation() {
    let action = MockComplexAction(
      userId: "immutable-user",
      operation: "immutable-op",
      priority: .low(.replaceable)
    )
    let boundaryId = "immutable-boundary"
    let reason = MockStrategyError(message: "Immutable test", code: 27001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Error information should remain consistent across multiple accesses
    let actionId1 = cancellationError.action.createLockmanInfo().actionId
    let actionId2 = cancellationError.action.createLockmanInfo().actionId
    let boundary1 = String(describing: cancellationError.boundaryId)
    let boundary2 = String(describing: cancellationError.boundaryId)
    let error1 = cancellationError.errorDescription
    let error2 = cancellationError.errorDescription

    XCTAssertEqual(actionId1, actionId2)
    XCTAssertEqual(boundary1, boundary2)
    XCTAssertEqual(error1, error2)

    // Properties should remain unchanged
    XCTAssertEqual(actionId1, LockmanActionId("immutable-op_immutable-user"))
    XCTAssertEqual(boundary1, "immutable-boundary")
    XCTAssertEqual(error1, "Immutable test")
  }

  func testSafeActionAccessAcrossThreads() async {
    let action = MockComplexAction(
      userId: "thread-action-user",
      operation: "thread-action-op",
      priority: .high(.exclusive)
    )
    let boundaryId = "thread-action-test"
    let reason = MockStrategyError(message: "Thread action test", code: 28001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    let results = try! await TestSupport.executeConcurrently(iterations: 8) {
      let actionInfo = cancellationError.action.createLockmanInfo()

      if let complexAction = cancellationError.action as? MockComplexAction {
        return "\(actionInfo.actionId)|\(complexAction.userId)|\(complexAction.operation)"
      } else {
        return "type_error"
      }
    }

    // All results should be identical
    XCTAssertEqual(results.count, 8)
    let expected = "thread-action-op_thread-action-user|thread-action-user|thread-action-op"
    results.forEach { result in
      XCTAssertEqual(result, expected)
    }
  }

  func testMemoryConsistencyAcrossConcurrentContexts() {
    let action = MockSimpleAction()
    let boundaryId = "memory-consistency-test"
    let reason = MockStrategyError(message: "Memory consistency", code: 29001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    let expectation = XCTestExpectation(description: "Memory consistency")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        // Access all properties in concurrent context
        let actionId = cancellationError.action.createLockmanInfo().actionId
        let boundary = String(describing: cancellationError.boundaryId)
        let errorDesc = cancellationError.errorDescription
        let failureReason = cancellationError.failureReason

        // Verify consistency
        XCTAssertEqual(actionId, LockmanActionId("mock-simple"))
        XCTAssertEqual(boundary, "memory-consistency-test")
        XCTAssertEqual(errorDesc, "Memory consistency")
        XCTAssertEqual(failureReason, "Mock strategy failure (code: 29001)")

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 3.0)
  }

  // MARK: - Performance & Memory Tests

  func testErrorCreationPerformance() {
    let action = MockSimpleAction()
    let boundaryId = "performance-test"

    measure {
      for i in 0..<1000 {
        let reason = MockStrategyError(message: "Performance \(i)", code: i)
        _ = LockmanCancellationError(action: action, boundaryId: boundaryId, reason: reason)
      }
    }
  }

  func testMemoryUsageWithPreservedActionReferences() {
    var weakError: LockmanCancellationError?

    autoreleasepool {
      let action = MockComplexAction(
        userId: "memory-user",
        operation: "memory-op",
        priority: .high(.exclusive)
      )
      let boundaryId = "memory-test"
      let reason = MockStrategyError(message: "Memory test", code: 30001)

      let cancellationError = LockmanCancellationError(
        action: action,
        boundaryId: boundaryId,
        reason: reason
      )

      weakError = cancellationError

      // Use error to prevent optimization
      _ = cancellationError.errorDescription
    }

    // Error should be deallocated
    XCTAssertNil(weakError)
  }

  func testLargeScaleErrorHandlingBehavior() {
    let actions = (0..<1000).map { i in
      MockComplexAction(
        userId: "user-\(i)",
        operation: "op-\(i)",
        priority: i % 2 == 0 ? .high(.exclusive) : .low(.replaceable)
      )
    }

    let startTime = CFAbsoluteTimeGetCurrent()

    let cancellationErrors = actions.enumerated().map { (index, action) in
      let reason = MockStrategyError(message: "Large scale \(index)", code: index)
      return LockmanCancellationError(
        action: action,
        boundaryId: "large-scale-\(index)",
        reason: reason
      )
    }

    // Process all errors
    let descriptions = cancellationErrors.map { $0.errorDescription ?? "nil" }

    let duration = CFAbsoluteTimeGetCurrent() - startTime

    XCTAssertEqual(descriptions.count, 1000)
    XCTAssertLessThan(duration, 1.0, "Large scale error creation should be efficient")

    // Verify some sample descriptions
    XCTAssertEqual(descriptions[0], "Large scale 0")
    XCTAssertEqual(descriptions[500], "Large scale 500")
    XCTAssertEqual(descriptions[999], "Large scale 999")
  }

  func testErrorCleanupAndMemoryManagement() {
    var weakActions: [MockComplexAction]?
    var weakErrors: [LockmanCancellationError]?

    autoreleasepool {
      let actions = (0..<100).map { i in
        MockComplexAction(
          userId: "cleanup-user-\(i)",
          operation: "cleanup-op-\(i)",
          priority: .high(.exclusive)
        )
      }

      let errors = actions.enumerated().map { (index, action) in
        let reason = MockStrategyError(message: "Cleanup \(index)", code: index)
        return LockmanCancellationError(
          action: action,
          boundaryId: "cleanup-\(index)",
          reason: reason
        )
      }

      weakActions = actions
      weakErrors = errors

      // Use errors to prevent optimization
      let totalLength = errors.reduce(0) { sum, error in
        sum + (error.errorDescription?.count ?? 0)
      }
      XCTAssertGreaterThan(totalLength, 0)
    }

    // Objects should be deallocated
    XCTAssertNil(weakActions)
    XCTAssertNil(weakErrors)
  }

  func testWeakReferenceScenarios() {
    var weakAction: MockComplexAction?
    var weakError: LockmanCancellationError?

    autoreleasepool {
      let action = MockComplexAction(
        userId: "weak-ref-user",
        operation: "weak-ref-op",
        priority: .low(.replaceable)
      )
      let reason = MockStrategyError(message: "Weak reference test", code: 31001)

      let cancellationError = LockmanCancellationError(
        action: action,
        boundaryId: "weak-ref-test",
        reason: reason
      )

      weakAction = action
      weakError = cancellationError

      // Verify error works while objects are alive
      XCTAssertEqual(cancellationError.errorDescription, "Weak reference test")
      if let complexAction = cancellationError.action as? MockComplexAction {
        XCTAssertEqual(complexAction.userId, "weak-ref-user")
      }
    }

    // Objects should be deallocated
    XCTAssertNil(weakAction)
    XCTAssertNil(weakError)
  }

  // MARK: - Edge Cases & Error Conditions Tests

  func testNilErrorDescriptionsFromUnderlyingReason() {
    struct NilDescriptionError: LockmanError {
      var errorDescription: String? { nil }
      var failureReason: String? { nil }
    }

    let action = MockSimpleAction()
    let boundaryId = "nil-description-test"
    let reason = NilDescriptionError()

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle nil descriptions gracefully
    XCTAssertNil(cancellationError.errorDescription)
    XCTAssertNil(cancellationError.failureReason)

    // localizedDescription should still work
    XCTAssertNotNil(cancellationError.localizedDescription)
  }

  func testComplexNestedActionStructures() {
    struct NestedAction: LockmanAction {
      typealias I = LockmanSingleExecutionInfo

      let level1: String
      let level2: [String]
      let level3: [String: String]

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        return LockmanSingleExecutionInfo(
          actionId: LockmanActionId("nested-\(level1)"),
          mode: .boundary
        )
      }
    }

    let nestedAction = NestedAction(
      level1: "complex",
      level2: ["a", "b", "c"],
      level3: ["key1": "value1", "key2": "42"]
    )
    let boundaryId = "nested-structure-test"
    let reason = MockStrategyError(message: "Nested structure test", code: 32001)

    let cancellationError = LockmanCancellationError(
      action: nestedAction,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle complex nested action structures
    XCTAssertTrue(cancellationError.action is NestedAction)

    if let preservedAction = cancellationError.action as? NestedAction {
      XCTAssertEqual(preservedAction.level1, "complex")
      XCTAssertEqual(preservedAction.level2, ["a", "b", "c"])
      if let stringValue = preservedAction.level3["key1"] {
        XCTAssertEqual(stringValue, "value1")
      }
      if let stringValue = preservedAction.level3["key2"] {
        XCTAssertEqual(stringValue, "42")
      }
    }
  }

  func testVeryLongErrorMessageChains() {
    let action = MockSimpleAction()
    let boundaryId = "long-message-test"

    let longMessage = String(
      repeating: "Very long error message with detailed information. ", count: 100)
    let reason = MockStrategyError(message: longMessage, code: 33001)

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Should handle very long error messages
    XCTAssertEqual(cancellationError.errorDescription, longMessage)
    XCTAssertTrue(cancellationError.errorDescription!.count > 5000)
    XCTAssertTrue(cancellationError.errorDescription!.contains("Very long error message"))
  }

  func testCircularReferencePrevention() {
    let action = MockSimpleAction()
    let boundaryId = "circular-test"

    // Create a potential circular reference scenario
    let reason1 = MockStrategyError(message: "Circular 1", code: 34001)
    let cancellation1 = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason1
    )

    let cancellation2 = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: cancellation1
    )

    // Should not create circular references
    // Note: Different error types should have different descriptions
    XCTAssertNotEqual(cancellation2.errorDescription, cancellation2.reason.localizedDescription)

    // Should be able to unwrap nested errors safely
    if let innerCancellation = cancellation2.reason as? LockmanCancellationError {
      XCTAssertTrue(innerCancellation.reason is MockStrategyError)
      XCTAssertEqual(innerCancellation.errorDescription, "Circular 1")
    }
  }

  func testMemoryPressureScenarios() {
    var weakErrors: [LockmanCancellationError]?

    autoreleasepool {
      let errors = (0..<10000).map { i in
        let action = MockSimpleAction(actionId: LockmanActionId("pressure-\(i)"))
        let reason = MockStrategyError(message: "Memory pressure \(i)", code: i)
        return LockmanCancellationError(
          action: action,
          boundaryId: "pressure-\(i)",
          reason: reason
        )
      }

      weakErrors = errors

      // Process errors under memory pressure
      let processedCount = errors.compactMap { $0.errorDescription }.count
      XCTAssertEqual(processedCount, 10000)
    }

    // Errors should be deallocated
    XCTAssertNil(weakErrors)
  }

  // MARK: - Integration with Error Systems Tests

  func testLockmanResultIntegration() {
    let action = MockSimpleAction()
    let boundaryId = "result-integration-test"
    let reason = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "result-test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    let result = LockmanResult.cancel(cancellationError)

    switch result {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanCancellationError)
      if let cancellation = error as? LockmanCancellationError {
        XCTAssertTrue(cancellation.action is MockSimpleAction)
        XCTAssertTrue(cancellation.reason is LockmanSingleExecutionError)
      }
    default:
      XCTFail("Expected cancel result")
    }
  }

  func testErrorPropagationThroughEffectSystems() {
    let action = MockComplexAction(
      userId: "effect-user",
      operation: "effect-op",
      priority: .high(.exclusive)
    )
    let boundaryId = "effect-test"
    let reason = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("effect-requested"),
        priority: .high(.exclusive)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("effect-existing"),
        priority: .high(.exclusive)
      ),
      boundaryId: "effect-conflict"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Simulate effect system error propagation
    struct EffectErrorHandler {
      static func processError(_ error: any LockmanError) -> [String: Any] {
        var result: [String: Any] = [:]

        if let cancellation = error as? LockmanCancellationError {
          result["type"] = "cancellation"
          result["action_id"] = cancellation.action.createLockmanInfo().actionId
          result["boundary_id"] = String(describing: cancellation.boundaryId)

          if let priorityError = cancellation.reason as? LockmanPriorityBasedError {
            result["strategy"] = "priority_based"
            result["error_description"] = priorityError.errorDescription
          }
        }

        return result
      }
    }

    let effectResult = EffectErrorHandler.processError(cancellationError)

    XCTAssertEqual(effectResult["type"] as? String, "cancellation")
    XCTAssertEqual(
      effectResult["action_id"] as? LockmanActionId, LockmanActionId("effect-op_effect-user"))
    XCTAssertEqual(effectResult["boundary_id"] as? String, "effect-test")
    XCTAssertEqual(effectResult["strategy"] as? String, "priority_based")
    XCTAssertNotNil(effectResult["error_description"])
  }

  func testErrorLoggingAndDebuggingSupport() {
    let action = MockComplexAction(
      userId: "logging-user",
      operation: "logging-op",
      priority: .low(.replaceable)
    )
    let boundaryId = MockCustomBoundary(module: "LoggingModule", identifier: "log-id")
    let reason = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "logging-conflict",
      lockmanInfo: LockmanSingleExecutionInfo(
        actionId: LockmanActionId("logging-action"),
        mode: .action
      )
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Simulate logging support
    struct ErrorLogger {
      static func createLogEntry(for error: LockmanCancellationError) -> [String: Any] {
        var logEntry: [String: Any] = [:]

        logEntry["timestamp"] = Date().timeIntervalSince1970
        logEntry["error_type"] = "LockmanCancellationError"
        logEntry["error_description"] = error.errorDescription
        logEntry["failure_reason"] = error.failureReason

        // Action information
        let actionInfo = error.action.createLockmanInfo()
        logEntry["action_id"] = actionInfo.actionId
        logEntry["action_strategy"] = actionInfo.strategyId

        if let complexAction = error.action as? MockComplexAction {
          logEntry["user_id"] = complexAction.userId
          logEntry["operation"] = complexAction.operation
        }

        // Boundary information
        if let customBoundary = error.boundaryId as? MockCustomBoundary {
          logEntry["boundary_module"] = customBoundary.module
          logEntry["boundary_identifier"] = customBoundary.identifier
        } else {
          logEntry["boundary_id"] = String(describing: error.boundaryId)
        }

        // Strategy error information
        logEntry["strategy_error_type"] = String(describing: type(of: error.reason))

        if let singleError = error.reason as? LockmanSingleExecutionError {
          logEntry["strategy_error_category"] = "single_execution"
          switch singleError {
          case .actionAlreadyRunning(let conflictBoundaryId, let conflictInfo):
            logEntry["conflict_boundary"] = String(describing: conflictBoundaryId)
            logEntry["conflict_action"] = conflictInfo.actionId
          case .boundaryAlreadyLocked(let lockedBoundaryId, let lockedInfo):
            logEntry["locked_boundary"] = String(describing: lockedBoundaryId)
            logEntry["locked_action"] = lockedInfo.actionId
          }
        }

        return logEntry
      }
    }

    let logEntry = ErrorLogger.createLogEntry(for: cancellationError)

    XCTAssertNotNil(logEntry["timestamp"])
    XCTAssertEqual(logEntry["error_type"] as? String, "LockmanCancellationError")
    XCTAssertEqual(
      logEntry["action_id"] as? LockmanActionId, LockmanActionId("logging-op_logging-user"))
    XCTAssertEqual(logEntry["user_id"] as? String, "logging-user")
    XCTAssertEqual(logEntry["operation"] as? String, "logging-op")
    XCTAssertEqual(logEntry["boundary_module"] as? String, "LoggingModule")
    XCTAssertEqual(logEntry["boundary_identifier"] as? String, "log-id")
    XCTAssertEqual(logEntry["strategy_error_category"] as? String, "single_execution")
    XCTAssertEqual(logEntry["conflict_boundary"] as? String, "logging-conflict")
    XCTAssertEqual(
      logEntry["conflict_action"] as? LockmanActionId, LockmanActionId("logging-action"))
  }

  func testErrorCategorizationAndFiltering() {
    let action = MockSimpleAction()
    let boundaryId = "categorization-test"

    let errors: [any LockmanError] = [
      LockmanSingleExecutionError.boundaryAlreadyLocked(
        boundaryId: "cat-single",
        lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
      ),
      LockmanPriorityBasedError.precedingActionCancelled(
        lockmanInfo: LockmanPriorityBasedInfo(
          actionId: LockmanActionId("cat-priority"),
          priority: .high(.exclusive)
        ),
        boundaryId: "cat-priority-boundary"
      ),
      LockmanRegistrationError.strategyNotRegistered("CategoryTestStrategy"),
      MockStrategyError(message: "Custom category error", code: 35001),
    ]

    let cancellationErrors = errors.map { error in
      LockmanCancellationError(action: action, boundaryId: boundaryId, reason: error)
    }

    // Simulate error categorization
    struct ErrorCategorizer {
      enum ErrorCategory: String {
        case configuration = "configuration"
        case strategy = "strategy"
        case concurrency = "concurrency"
        case custom = "custom"
        case unknown = "unknown"
      }

      static func categorize(_ cancellation: LockmanCancellationError) -> ErrorCategory {
        switch cancellation.reason {
        case is LockmanRegistrationError:
          return .configuration
        case is LockmanSingleExecutionError, is LockmanPriorityBasedError:
          return .concurrency
        case is MockStrategyError:
          return .custom
        default:
          return .unknown
        }
      }

      static func filterByCategory(
        _ cancellations: [LockmanCancellationError],
        category: ErrorCategory
      ) -> [LockmanCancellationError] {
        return cancellations.filter { categorize($0) == category }
      }
    }

    let categories = cancellationErrors.map(ErrorCategorizer.categorize)

    XCTAssertEqual(categories[0], .concurrency)  // LockmanSingleExecutionError
    XCTAssertEqual(categories[1], .concurrency)  // LockmanPriorityBasedError
    XCTAssertEqual(categories[2], .configuration)  // LockmanRegistrationError
    XCTAssertEqual(categories[3], .custom)  // MockStrategyError

    // Test filtering
    let concurrencyErrors = ErrorCategorizer.filterByCategory(
      cancellationErrors, category: .concurrency)
    let configErrors = ErrorCategorizer.filterByCategory(
      cancellationErrors, category: .configuration)

    XCTAssertEqual(concurrencyErrors.count, 2)
    XCTAssertEqual(configErrors.count, 1)
  }

  func testErrorCorrelationWithSystemState() {
    let action = MockComplexAction(
      userId: "correlation-user",
      operation: "correlation-op",
      priority: .high(.exclusive)
    )
    let boundaryId = "correlation-boundary"
    let reason = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("correlation-requested"),
        priority: .high(.exclusive)
      ),
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("correlation-existing"),
        priority: .high(.exclusive)
      ),
      boundaryId: "correlation-conflict"
    )

    let cancellationError = LockmanCancellationError(
      action: action,
      boundaryId: boundaryId,
      reason: reason
    )

    // Simulate system state correlation
    struct SystemStateCorrelator {
      static func correlateWithSystemState(
        _ cancellation: LockmanCancellationError
      ) -> [String: Any] {
        var correlation: [String: Any] = [:]

        // Extract system state from error
        correlation["cancelled_action"] = cancellation.action.createLockmanInfo().actionId
        correlation["cancellation_boundary"] = String(describing: cancellation.boundaryId)

        if let complexAction = cancellation.action as? MockComplexAction {
          correlation["affected_user"] = complexAction.userId
          correlation["interrupted_operation"] = complexAction.operation
        }

        if let priorityError = cancellation.reason as? LockmanPriorityBasedError {
          switch priorityError {
          case .samePriorityConflict(let requested, let existing, let conflictBoundary):
            correlation["conflict_type"] = "same_priority"
            correlation["requested_action"] = requested.actionId
            correlation["existing_action"] = existing.actionId
            correlation["conflict_boundary"] = String(describing: conflictBoundary)
            correlation["priority_level"] = String(describing: requested.priority)
          default:
            correlation["conflict_type"] = "other_priority"
          }
        }

        // Reconstruct potential system state
        correlation["system_impact"] = "user_\(correlation["affected_user"] ?? "unknown")_blocked"
        correlation["recovery_suggestion"] = "retry_with_exclusive_priority"

        return correlation
      }
    }

    let correlation = SystemStateCorrelator.correlateWithSystemState(cancellationError)

    XCTAssertEqual(
      correlation["cancelled_action"] as? LockmanActionId,
      LockmanActionId("correlation-op_correlation-user"))
    XCTAssertEqual(correlation["affected_user"] as? String, "correlation-user")
    XCTAssertEqual(correlation["interrupted_operation"] as? String, "correlation-op")
    XCTAssertEqual(correlation["conflict_type"] as? String, "same_priority")
    XCTAssertEqual(
      correlation["requested_action"] as? LockmanActionId, LockmanActionId("correlation-requested"))
    XCTAssertEqual(
      correlation["existing_action"] as? LockmanActionId, LockmanActionId("correlation-existing"))
    XCTAssertEqual(correlation["system_impact"] as? String, "user_correlation-user_blocked")
    XCTAssertEqual(correlation["recovery_suggestion"] as? String, "retry_with_exclusive_priority")
  }
}
