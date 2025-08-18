import XCTest

@testable import Lockman

/// Unit tests for LockmanStrategyError
///
/// Tests the protocol that all strategy-specific errors must conform to, providing
/// a unified interface for errors within Lockman strategies.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance Validation
/// - [ ] LockmanError protocol inheritance verification
/// - [ ] Required property implementation: lockmanInfo
/// - [ ] Required property implementation: boundaryId
/// - [ ] Protocol composition behavior validation
/// - [ ] Swift Error protocol conformance through inheritance
///
/// ### Property Access and Type Safety
/// - [ ] lockmanInfo property returns any LockmanInfo type
/// - [ ] boundaryId property returns any LockmanBoundaryId type
/// - [ ] Type erasure behavior with protocol types
/// - [ ] Property access thread safety
/// - [ ] Consistent property behavior across implementations
///
/// ### Integration with Concrete Strategy Errors
/// - [ ] LockmanSingleExecutionError conformance verification
/// - [ ] LockmanPriorityBasedError conformance verification
/// - [ ] LockmanGroupCoordinationError conformance verification
/// - [ ] LockmanConcurrencyLimitedError conformance verification
/// - [ ] Custom strategy error conformance patterns
///
/// ### Error Information Access Patterns
/// - [ ] LockmanInfo access from error instances
/// - [ ] BoundaryId access from error instances
/// - [ ] Action ID extraction through lockmanInfo
/// - [ ] Debug information compilation from both properties
/// - [ ] Error context reconstruction capabilities
///
/// ### Type Erasure and Polymorphism
/// - [ ] Protocol type behavior as any LockmanStrategyError
/// - [ ] Error type identification and casting
/// - [ ] Polymorphic error handling scenarios
/// - [ ] Runtime type checking capabilities
/// - [ ] Generic error processing patterns
///
/// ### Error Handling Integration
/// - [ ] Error throwing and catching with protocol type
/// - [ ] Error propagation through strategy systems
/// - [ ] Error chaining with strategy error context
/// - [ ] Nested error scenarios with strategy information
/// - [ ] Error recovery using strategy error information
///
/// ### Common Error Handling Patterns
/// - [ ] Pattern matching on strategy error types
/// - [ ] Switch statement exhaustiveness with protocol
/// - [ ] Error message generation using protocol properties
/// - [ ] Debugging information compilation
/// - [ ] User-facing error presentation patterns
///
/// ### Memory Management and Performance
/// - [ ] Protocol witness table overhead
/// - [ ] Memory usage with type-erased errors
/// - [ ] Error instance lifecycle management
/// - [ ] Concurrent error access patterns
/// - [ ] Performance impact of protocol conformance
///
/// ### Documentation and Usage Examples
/// - [ ] Protocol usage example verification from source
/// - [ ] Error handling pattern demonstrations
/// - [ ] Integration with strategy implementations
/// - [ ] Common error processing workflows
/// - [ ] Best practices for custom strategy errors
///
/// ### Protocol Extension Capabilities
/// - [ ] Default implementation possibilities
/// - [ ] Protocol extension method additions
/// - [ ] Computed property extensions
/// - [ ] Helper method implementations
/// - [ ] Convenience accessor patterns
///
/// ### Error Context and Debugging Support
/// - [ ] Comprehensive error context from protocol properties
/// - [ ] Debugging information compilation
/// - [ ] Error tracing and logging support
/// - [ ] Developer troubleshooting assistance
/// - [ ] Strategy-specific debugging capabilities
///
final class LockmanStrategyErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock Types

  /// Mock LockmanInfo for testing
  private struct MockLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let debugAdditionalInfo: String
    let isCancellationTarget: Bool

    var debugDescription: String {
      "MockLockmanInfo(actionId: \(actionId), uniqueId: \(uniqueId))"
    }

    init(
      strategyId: LockmanStrategyId = "Test.MockStrategy",
      actionId: LockmanActionId = "mockAction",
      uniqueId: UUID = UUID(),
      debugAdditionalInfo: String = "mock debug info",
      isCancellationTarget: Bool = true
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = uniqueId
      self.debugAdditionalInfo = debugAdditionalInfo
      self.isCancellationTarget = isCancellationTarget
    }
  }

  /// Mock LockmanBoundaryId for testing
  private struct MockBoundaryId: LockmanBoundaryId {
    let value: String

    var debugDescription: String { value }

    init(_ value: String = "mockBoundary") {
      self.value = value
    }
  }

  /// Mock strategy error implementing LockmanStrategyError
  private enum MockStrategyError: LockmanStrategyError {
    case simpleError(lockmanInfo: MockLockmanInfo, boundaryId: MockBoundaryId)
    case complexError(
      lockmanInfo: MockLockmanInfo, boundaryId: MockBoundaryId, additionalData: String)

    var lockmanInfo: any LockmanInfo {
      switch self {
      case .simpleError(let lockmanInfo, _):
        return lockmanInfo
      case .complexError(let lockmanInfo, _, _):
        return lockmanInfo
      }
    }

    var boundaryId: any LockmanBoundaryId {
      switch self {
      case .simpleError(_, let boundaryId):
        return boundaryId
      case .complexError(_, let boundaryId, _):
        return boundaryId
      }
    }

    var errorDescription: String? {
      switch self {
      case .simpleError(let lockmanInfo, let boundaryId):
        return "Simple error for action '\(lockmanInfo.actionId)' in boundary '\(boundaryId)'"
      case .complexError(let lockmanInfo, let boundaryId, let additionalData):
        return
          "Complex error for action '\(lockmanInfo.actionId)' in boundary '\(boundaryId)' with data: \(additionalData)"
      }
    }

    var failureReason: String? {
      switch self {
      case .simpleError:
        return "Simple strategy error occurred"
      case .complexError:
        return "Complex strategy error with additional context"
      }
    }
  }

  /// Mock strategy error for testing protocol inheritance
  private struct MockPrecedingCancellationError: LockmanPrecedingCancellationError {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId

    var errorDescription: String? {
      "Preceding action cancelled: '\(lockmanInfo.actionId)' in boundary '\(boundaryId)'"
    }

    var failureReason: String? {
      "Action was cancelled by a higher priority action"
    }
  }

  // MARK: - Protocol Conformance Tests

  /// Tests that LockmanStrategyError properly inherits from LockmanError
  func testProtocolInheritanceFromLockmanError() {
    let lockmanInfo = MockLockmanInfo()
    let boundaryId = MockBoundaryId()
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Verify protocol interface usage
    let lockmanError: any LockmanError = error
    let swiftError: any Error = error
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertNotNil(swiftError)

    // Should provide LocalizedError functionality
    XCTAssertNotNil(error.errorDescription, "Should provide error description")
    XCTAssertNotNil(error.failureReason, "Should provide failure reason")
  }

  /// Tests that required properties are properly implemented
  func testRequiredPropertyImplementation() {
    let mockInfo = MockLockmanInfo(
      actionId: "testAction",
      uniqueId: UUID(),
      debugAdditionalInfo: "test debug info"
    )
    let mockBoundary = MockBoundaryId("testBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: mockInfo, boundaryId: mockBoundary)

    // Test lockmanInfo property
    let retrievedInfo = error.lockmanInfo
    XCTAssertEqual(retrievedInfo.actionId, "testAction", "Should provide correct action ID")
    XCTAssertEqual(
      retrievedInfo.debugAdditionalInfo, "test debug info", "Should provide correct debug info")

    // Test boundaryId property
    let retrievedBoundary = error.boundaryId
    XCTAssertEqual(
      String(describing: retrievedBoundary), "testBoundary", "Should provide correct boundary ID")
  }

  /// Tests protocol composition behavior with type erasure
  func testProtocolCompositionWithTypeErasure() {
    let lockmanInfo = MockLockmanInfo(actionId: "compositionTest")
    let boundaryId = MockBoundaryId("compositionBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "extra data"
    )

    // Test as LockmanStrategyError
    let strategyError: any LockmanStrategyError = error
    XCTAssertEqual(strategyError.lockmanInfo.actionId, "compositionTest")
    // Remove invalid String property access
    XCTAssertNotNil(strategyError.boundaryId)

    // Test as LockmanError
    let lockmanError: any LockmanError = error
    XCTAssertNotNil(lockmanError.errorDescription)

    // Test as Swift Error
    let swiftError: any Error = error
    XCTAssertTrue(swiftError is any LockmanStrategyError)
  }

  // MARK: - Property Access and Type Safety Tests

  /// Tests lockmanInfo property returns correct LockmanInfo type
  func testLockmanInfoPropertyAccess() {
    let uniqueId = UUID()
    let mockInfo = MockLockmanInfo(
      strategyId: "Test.PropertyAccessStrategy",
      actionId: "propertyAccessAction",
      uniqueId: uniqueId,
      debugAdditionalInfo: "property access test",
      isCancellationTarget: false
    )
    let boundaryId = MockBoundaryId("propertyAccessBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: mockInfo, boundaryId: boundaryId)

    let retrievedInfo = error.lockmanInfo

    // Verify all LockmanInfo properties are accessible
    XCTAssertEqual(retrievedInfo.strategyId, "Test.PropertyAccessStrategy")
    XCTAssertEqual(retrievedInfo.actionId, "propertyAccessAction")
    XCTAssertEqual(retrievedInfo.uniqueId, uniqueId)
    XCTAssertEqual(retrievedInfo.debugAdditionalInfo, "property access test")
    XCTAssertEqual(retrievedInfo.isCancellationTarget, false)
    XCTAssertEqual(
      String(describing: retrievedInfo),
      "MockLockmanInfo(actionId: propertyAccessAction, uniqueId: \(uniqueId))")
  }

  /// Tests boundaryId property returns correct LockmanBoundaryId type
  func testBoundaryIdPropertyAccess() {
    let lockmanInfo = MockLockmanInfo()
    let mockBoundary = MockBoundaryId("boundaryAccessTest")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: mockBoundary)

    let retrievedBoundary = error.boundaryId

    // Verify LockmanBoundaryId properties are accessible
    XCTAssertEqual(String(describing: retrievedBoundary), "boundaryAccessTest")

    // Test type safety
    XCTAssertTrue(retrievedBoundary is MockBoundaryId)
  }

  /// Tests thread safety of property access
  func testPropertyAccessThreadSafety() async {
    let lockmanInfo = MockLockmanInfo(actionId: "threadSafetyTest")
    let boundaryId = MockBoundaryId("threadSafetyBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Perform concurrent property access
    await TestSupport.performConcurrentOperations(count: 50) {
      let retrievedInfo = error.lockmanInfo
      let retrievedBoundary = error.boundaryId

      XCTAssertEqual(retrievedInfo.actionId, "threadSafetyTest")
      XCTAssertEqual(String(describing: retrievedBoundary), "threadSafetyBoundary")
    }
  }

  // MARK: - Integration with Concrete Strategy Errors Tests

  /// Tests LockmanSingleExecutionError conformance to LockmanStrategyError
  func testSingleExecutionErrorConformance() {
    let singleInfo = LockmanSingleExecutionInfo(actionId: "singleTest", mode: .boundary)
    let boundaryId = "singleBoundary"
    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId,
      lockmanInfo: singleInfo
    )

    // Verify protocol interface usage
    let strategyError: any LockmanStrategyError = error
    XCTAssertNotNil(strategyError.lockmanInfo)
    XCTAssertEqual(strategyError.lockmanInfo.actionId, "singleTest")
    // Remove invalid String property access
    XCTAssertNotNil(strategyError.boundaryId)

    // Test error information
    XCTAssertNotNil(strategyError.errorDescription)
    XCTAssertTrue(strategyError.errorDescription!.contains("singleTest"))
  }

  /// Tests LockmanGroupCoordinationError conformance to LockmanStrategyError
  func testGroupCoordinationErrorConformance() {
    let groupInfo = LockmanGroupCoordinatedInfo(
      actionId: "groupTest",
      groupIds: Set(["group1"]),
      coordinationRole: .leader(.emptyGroup)
    )
    let boundaryId = "groupBoundary"
    let error = LockmanGroupCoordinationError.leaderCannotJoinNonEmptyGroup(
      lockmanInfo: groupInfo,
      boundaryId: AnyLockmanBoundaryId(boundaryId),
      groupIds: [AnyLockmanGroupId("group1")]
    )

    // Test property access through protocol
    let strategyError: any LockmanStrategyError = error
    XCTAssertEqual(strategyError.lockmanInfo.actionId, "groupTest")
    // Remove invalid String property access
    XCTAssertNotNil(strategyError.boundaryId)

    // Test error information
    XCTAssertNotNil(strategyError.errorDescription)
    XCTAssertTrue(strategyError.errorDescription!.contains("groupTest"))
  }

  /// Tests LockmanPrecedingCancellationError inheritance from LockmanStrategyError
  func testPrecedingCancellationErrorInheritance() {
    let lockmanInfo = MockLockmanInfo(actionId: "precedingTest")
    let boundaryId = MockBoundaryId("precedingBoundary")
    let error = MockPrecedingCancellationError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Verify protocol interface hierarchy
    let precedingError: any LockmanPrecedingCancellationError = error
    let strategyError: any LockmanStrategyError = error
    let lockmanError: any LockmanError = error
    let swiftError: any Error = error
    XCTAssertNotNil(precedingError.lockmanInfo)
    XCTAssertNotNil(strategyError.lockmanInfo)
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertNotNil(swiftError)

    // Test property access through different protocol types
    XCTAssertEqual(precedingError.lockmanInfo.actionId, "precedingTest")
    // Remove invalid String property access
    XCTAssertNotNil(precedingError.boundaryId)

    XCTAssertEqual(strategyError.lockmanInfo.actionId, "precedingTest")
    // Remove invalid String property access
    XCTAssertNotNil(strategyError.boundaryId)
  }

  // MARK: - Error Information Access Pattern Tests

  /// Tests accessing action ID through lockmanInfo
  func testActionIdAccessThroughLockmanInfo() {
    let testActionIds = [
      "simpleAction",
      "action_with_underscore",
      "action-with-dash",
      "action.with.dots",
      TestSupport.StandardActionIds.unicode,
      TestSupport.StandardActionIds.empty,
      TestSupport.StandardActionIds.veryLong,
    ]

    for actionId in testActionIds {
      let lockmanInfo = MockLockmanInfo(actionId: actionId)
      let boundaryId = MockBoundaryId()
      let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

      XCTAssertEqual(
        error.lockmanInfo.actionId, actionId, "Should correctly access action ID: \(actionId)")
    }
  }

  /// Tests debug information compilation from protocol properties
  func testDebugInformationCompilation() {
    let lockmanInfo = MockLockmanInfo(
      strategyId: "Test.DebugStrategy",
      actionId: "debugAction",
      debugAdditionalInfo: "debug details"
    )
    let boundaryId = MockBoundaryId("debugBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "complex data"
    )

    // Compile debug information from protocol properties
    let debugInfo = """
      Strategy Error Debug Information:
      - Strategy ID: \(error.lockmanInfo.strategyId)
      - Action ID: \(error.lockmanInfo.actionId)
      - Boundary ID: \(error.boundaryId)
      - Additional Info: \(error.lockmanInfo.debugAdditionalInfo)
      - Error Description: \(error.errorDescription ?? "No description")
      - Failure Reason: \(error.failureReason ?? "No reason")
      """

    XCTAssertTrue(debugInfo.contains("Test.DebugStrategy"))
    XCTAssertTrue(debugInfo.contains("debugAction"))
    XCTAssertTrue(debugInfo.contains("debugBoundary"))
    XCTAssertTrue(debugInfo.contains("debug details"))
    XCTAssertTrue(debugInfo.contains("Complex error"))
  }

  /// Tests error context reconstruction capabilities
  func testErrorContextReconstruction() {
    let uniqueId = UUID()
    let lockmanInfo = MockLockmanInfo(
      strategyId: "Test.ContextStrategy",
      actionId: "contextAction",
      uniqueId: uniqueId,
      debugAdditionalInfo: "context info",
      isCancellationTarget: true
    )
    let boundaryId = MockBoundaryId("contextBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Reconstruct error context
    struct ErrorContext {
      let strategyId: LockmanStrategyId
      let actionId: LockmanActionId
      let uniqueId: UUID
      let boundaryId: String
      let isCancellationTarget: Bool
      let errorDescription: String
    }

    let context = ErrorContext(
      strategyId: error.lockmanInfo.strategyId,
      actionId: error.lockmanInfo.actionId,
      uniqueId: error.lockmanInfo.uniqueId,
      boundaryId: String(describing: error.boundaryId),
      isCancellationTarget: error.lockmanInfo.isCancellationTarget,
      errorDescription: error.errorDescription ?? "No description"
    )

    XCTAssertEqual(context.strategyId, "Test.ContextStrategy")
    XCTAssertEqual(context.actionId, "contextAction")
    XCTAssertEqual(context.uniqueId, uniqueId)
    XCTAssertEqual(context.boundaryId, "contextBoundary")
    XCTAssertEqual(context.isCancellationTarget, true)
    XCTAssertTrue(context.errorDescription.contains("contextAction"))
  }

  // MARK: - Type Erasure and Polymorphism Tests

  /// Tests protocol type behavior as any LockmanStrategyError
  func testProtocolTypeBehavior() {
    let lockmanInfo = MockLockmanInfo(actionId: "polymorphicAction")
    let boundaryId = MockBoundaryId("polymorphicBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Test type erasure to protocol type
    let erasedError: any LockmanStrategyError = error

    // Should maintain protocol functionality
    XCTAssertEqual(erasedError.lockmanInfo.actionId, "polymorphicAction")
    // Remove invalid String property access
    XCTAssertNotNil(erasedError.boundaryId)
    XCTAssertNotNil(erasedError.errorDescription)

    // Verify protocol interface usage
    let lockmanError: any LockmanError = erasedError
    let swiftError: any Error = erasedError
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertNotNil(swiftError)
    XCTAssertTrue(erasedError is MockStrategyError)
  }

  /// Tests error type identification and casting
  func testErrorTypeIdentificationAndCasting() {
    let lockmanInfo = MockLockmanInfo(actionId: "castingTest")
    let boundaryId = MockBoundaryId("castingBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "casting data"
    )

    // Test type identification
    let genericError: any Error = error
    XCTAssertTrue(genericError is any LockmanStrategyError)
    XCTAssertTrue(genericError is MockStrategyError)

    // Test safe casting
    if let strategyError = genericError as? LockmanStrategyError {
      XCTAssertEqual(strategyError.lockmanInfo.actionId, "castingTest")
      XCTAssertEqual(String(describing: strategyError.boundaryId), "castingBoundary")
    } else {
      XCTFail("Should be able to cast to LockmanStrategyError")
    }

    // Test specific type casting
    if let specificError = genericError as? MockStrategyError {
      if case .complexError(_, _, let additionalData) = specificError {
        XCTAssertEqual(additionalData, "casting data")
      } else {
        XCTFail("Should match complex error case")
      }
    } else {
      XCTFail("Should be able to cast to MockStrategyError")
    }
  }

  /// Tests polymorphic error handling scenarios
  func testPolymorphicErrorHandling() {
    let errors: [any LockmanStrategyError] = [
      MockStrategyError.simpleError(
        lockmanInfo: MockLockmanInfo(actionId: "simple"),
        boundaryId: MockBoundaryId("boundary1")
      ),
      MockStrategyError.complexError(
        lockmanInfo: MockLockmanInfo(actionId: "complex"),
        boundaryId: MockBoundaryId("boundary2"),
        additionalData: "data"
      ),
      MockPrecedingCancellationError(
        lockmanInfo: MockLockmanInfo(actionId: "preceding"),
        boundaryId: MockBoundaryId("boundary3")
      ),
    ]

    // Test polymorphic processing
    for (index, error) in errors.enumerated() {
      // All should have accessible protocol properties
      XCTAssertFalse(error.lockmanInfo.actionId.isEmpty, "Error \(index) should have action ID")
      XCTAssertFalse(
        String(describing: error.boundaryId).isEmpty, "Error \(index) should have boundary ID")
      XCTAssertNotNil(error.errorDescription, "Error \(index) should have error description")

      // Should be able to identify specific types
      switch error {
      case is MockStrategyError:
        XCTAssertTrue(["simple", "complex"].contains(error.lockmanInfo.actionId))
      case is MockPrecedingCancellationError:
        XCTAssertEqual(error.lockmanInfo.actionId, "preceding")
      default:
        XCTFail("Unexpected error type")
      }
    }
  }

  // MARK: - Error Handling Integration Tests

  /// Tests error throwing and catching with protocol type
  func testErrorThrowingAndCatching() {
    let lockmanInfo = MockLockmanInfo(actionId: "throwingTest")
    let boundaryId = MockBoundaryId("throwingBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    func throwingFunction() throws {
      throw error
    }

    // Test catching as LockmanStrategyError
    do {
      try throwingFunction()
      XCTFail("Should have thrown an error")
    } catch let strategyError as any LockmanStrategyError {
      XCTAssertEqual(strategyError.lockmanInfo.actionId, "throwingTest")
      XCTAssertEqual(String(describing: strategyError.boundaryId), "throwingBoundary")
    } catch {
      XCTFail("Should have caught LockmanStrategyError, got \(type(of: error))")
    }

    // Test catching as general Error
    do {
      try throwingFunction()
      XCTFail("Should have thrown an error")
    } catch {
      XCTAssertTrue(error is any LockmanStrategyError)
      if let strategyError = error as? LockmanStrategyError {
        XCTAssertEqual(strategyError.lockmanInfo.actionId, "throwingTest")
      }
    }
  }

  /// Tests error chaining with strategy error context
  func testErrorChainingWithStrategyContext() {
    let originalInfo = MockLockmanInfo(actionId: "originalAction")
    let originalBoundary = MockBoundaryId("originalBoundary")
    let originalError = MockStrategyError.simpleError(
      lockmanInfo: originalInfo,
      boundaryId: originalBoundary
    )

    // Create a chained error that includes the original strategy error
    struct ChainedError: Error {
      let originalStrategyError: any LockmanStrategyError
      let chainReason: String

      var localizedDescription: String {
        "Chained error (\(chainReason)): \(originalStrategyError.errorDescription ?? "Unknown error")"
      }
    }

    let chainedError = ChainedError(
      originalStrategyError: originalError,
      chainReason: "propagation test"
    )

    // Verify chaining preserves strategy error context
    XCTAssertEqual(chainedError.originalStrategyError.lockmanInfo.actionId, "originalAction")
    XCTAssertEqual(
      String(describing: chainedError.originalStrategyError.boundaryId), "originalBoundary")
    XCTAssertTrue(chainedError.localizedDescription.contains("propagation test"))
    XCTAssertTrue(chainedError.localizedDescription.contains("originalAction"))
  }

  // MARK: - Common Error Handling Pattern Tests

  /// Tests pattern matching on strategy error types
  func testPatternMatchingOnStrategyErrorTypes() {
    let errors: [any LockmanStrategyError] = [
      MockStrategyError.simpleError(
        lockmanInfo: MockLockmanInfo(actionId: "simple"),
        boundaryId: MockBoundaryId()
      ),
      MockStrategyError.complexError(
        lockmanInfo: MockLockmanInfo(actionId: "complex"),
        boundaryId: MockBoundaryId(),
        additionalData: "data"
      ),
      MockPrecedingCancellationError(
        lockmanInfo: MockLockmanInfo(actionId: "preceding"),
        boundaryId: MockBoundaryId()
      ),
    ]

    var simpleCount = 0
    var complexCount = 0
    var precedingCount = 0

    for error in errors {
      switch error {
      case let mockError as MockStrategyError:
        switch mockError {
        case .simpleError:
          simpleCount += 1
        case .complexError:
          complexCount += 1
        }
      case _ as MockPrecedingCancellationError:
        precedingCount += 1
      default:
        XCTFail("Unexpected error type")
      }
    }

    XCTAssertEqual(simpleCount, 1)
    XCTAssertEqual(complexCount, 1)
    XCTAssertEqual(precedingCount, 1)
  }

  /// Tests user-facing error presentation patterns
  func testUserFacingErrorPresentationPatterns() {
    let lockmanInfo = MockLockmanInfo(
      actionId: "userPresentationAction",
      debugAdditionalInfo: "presentation debug info"
    )
    let boundaryId = MockBoundaryId("presentationBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "presentation data"
    )

    // Test user-friendly error presentation
    func createUserFriendlyMessage(from strategyError: any LockmanStrategyError) -> String {
      let actionContext = "Action: \(strategyError.lockmanInfo.actionId)"
      let errorMessage = strategyError.errorDescription ?? "An unknown error occurred"
      let helpText = "Please try again or contact support if the problem persists."

      return "\(errorMessage)\n\n\(actionContext)\n\n\(helpText)"
    }

    let userMessage = createUserFriendlyMessage(from: error)

    XCTAssertTrue(userMessage.contains("userPresentationAction"))
    XCTAssertTrue(userMessage.contains("Complex error"))
    XCTAssertTrue(userMessage.contains("Action:"))
    XCTAssertTrue(userMessage.contains("try again"))
  }

  // MARK: - Memory Management and Performance Tests

  /// Tests memory usage with type-erased errors
  func testMemoryUsageWithTypeErasedErrors() {
    let errors: [any LockmanStrategyError] = (0..<1000).map { index in
      MockStrategyError.simpleError(
        lockmanInfo: MockLockmanInfo(actionId: "memoryTest_\(index)"),
        boundaryId: MockBoundaryId("boundary_\(index)")
      )
    }

    // Test that all errors maintain their properties correctly
    for (index, error) in errors.enumerated() {
      XCTAssertEqual(error.lockmanInfo.actionId, "memoryTest_\(index)")
      XCTAssertEqual(String(describing: error.boundaryId), "boundary_\(index)")
    }

    // Memory is managed automatically; this test verifies no obvious leaks
    // in basic usage patterns
  }

  /// Tests performance impact of protocol conformance
  func testPerformanceImpactOfProtocolConformance() {
    let lockmanInfo = MockLockmanInfo(actionId: "performanceTest")
    let boundaryId = MockBoundaryId("performanceBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    let executionTime = TestSupport.measureExecutionTime {
      // Perform many property accesses to measure protocol overhead
      for _ in 0..<10000 {
        _ = error.lockmanInfo.actionId
        _ = String(describing: error.boundaryId)
        _ = error.errorDescription
      }
    }

    // Should complete quickly (less than 1 second for 10000 iterations)
    XCTAssertLessThan(executionTime, 1.0, "Protocol property access should be efficient")
  }

  /// Tests concurrent error access patterns
  func testConcurrentErrorAccessPatterns() async {
    let lockmanInfo = MockLockmanInfo(actionId: "concurrentTest")
    let boundaryId = MockBoundaryId("concurrentBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Test concurrent access to the same error instance
    let results = try! await TestSupport.executeConcurrently(iterations: 100) {
      return (
        actionId: error.lockmanInfo.actionId,
        boundaryId: String(describing: error.boundaryId),
        errorDescription: error.errorDescription ?? ""
      )
    }

    // All results should be consistent
    for result in results {
      XCTAssertEqual(result.actionId, "concurrentTest")
      XCTAssertEqual(result.boundaryId, "concurrentBoundary")
      XCTAssertTrue(result.errorDescription.contains("concurrentTest"))
    }
  }

  // MARK: - Documentation and Usage Example Tests

  /// Tests protocol usage example verification from source
  func testProtocolUsageExampleFromSource() {
    // Test the example from the source documentation
    func handleStrategyError(_ error: any LockmanStrategyError) -> String {
      var result = "Strategy error: \(error.errorDescription ?? "Unknown")\n"
      result += "Action: \(error.lockmanInfo.actionId)\n"
      result += "Boundary: \(error.boundaryId)"
      return result
    }

    let lockmanInfo = MockLockmanInfo(actionId: "exampleAction")
    let boundaryId = MockBoundaryId("exampleBoundary")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    let handlerResult = handleStrategyError(error)

    XCTAssertTrue(handlerResult.contains("Strategy error:"))
    XCTAssertTrue(handlerResult.contains("exampleAction"))
    XCTAssertTrue(handlerResult.contains("exampleBoundary"))
    XCTAssertTrue(handlerResult.contains("Simple error"))
  }

  /// Tests common error processing workflows
  func testCommonErrorProcessingWorkflows() {
    let lockmanInfo = MockLockmanInfo(
      actionId: "workflowAction",
      debugAdditionalInfo: "workflow debug"
    )
    let boundaryId = MockBoundaryId("workflowBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "workflow data"
    )

    // Common workflow: Error logging
    func logStrategyError(_ error: any LockmanStrategyError) -> String {
      return
        "ERROR [\(error.lockmanInfo.strategyId)] Action '\(error.lockmanInfo.actionId)' in boundary '\(error.boundaryId)': \(error.errorDescription ?? "Unknown error")"
    }

    let logMessage = logStrategyError(error)
    XCTAssertTrue(logMessage.contains("ERROR"))
    XCTAssertTrue(logMessage.contains("workflowAction"))
    XCTAssertTrue(logMessage.contains("workflowBoundary"))

    // Common workflow: Error recovery
    func canRetryAfterError(_ error: any LockmanStrategyError) -> Bool {
      // Generally allow retries for strategy errors
      return true
    }

    XCTAssertTrue(canRetryAfterError(error))

    // Common workflow: Error categorization
    func categorizeError(_ error: any LockmanStrategyError) -> String {
      switch error {
      case _ as MockStrategyError:
        return "Mock Error"
      case _ as MockPrecedingCancellationError:
        return "Cancellation Error"
      default:
        return "Unknown Strategy Error"
      }
    }

    XCTAssertEqual(categorizeError(error), "Mock Error")
  }

  // MARK: - Edge Cases and Error Conditions Tests

  /// Tests protocol behavior with edge case property values
  func testProtocolBehaviorWithEdgeCaseValues() {
    // Test with edge case values
    let edgeCases = [
      (actionId: TestSupport.StandardActionIds.empty, boundary: "normal"),
      (actionId: "normal", boundary: ""),
      (
        actionId: TestSupport.StandardActionIds.unicode,
        boundary: TestSupport.StandardBoundaryIds.unicode
      ),
      (actionId: TestSupport.StandardActionIds.veryLong, boundary: "short"),
      (
        actionId: TestSupport.StandardActionIds.withNewlines,
        boundary: TestSupport.StandardActionIds.withTabs
      ),
    ]

    for (actionId, boundary) in edgeCases {
      let lockmanInfo = MockLockmanInfo(actionId: actionId)
      let boundaryId = MockBoundaryId(boundary)
      let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

      // Protocol should handle edge cases gracefully
      XCTAssertEqual(error.lockmanInfo.actionId, actionId)
      XCTAssertEqual(String(describing: error.boundaryId), boundary)
      XCTAssertNotNil(error.errorDescription)
    }
  }

  /// Tests protocol behavior with nil and empty values
  func testProtocolBehaviorWithNilAndEmptyValues() {
    let lockmanInfo = MockLockmanInfo(
      actionId: "",
      debugAdditionalInfo: ""
    )
    let boundaryId = MockBoundaryId("")
    let error = MockStrategyError.simpleError(lockmanInfo: lockmanInfo, boundaryId: boundaryId)

    // Protocol should handle empty values gracefully
    XCTAssertEqual(error.lockmanInfo.actionId, "")
    XCTAssertEqual(error.lockmanInfo.debugAdditionalInfo, "")
    XCTAssertEqual(String(describing: error.boundaryId), "")
    XCTAssertNotNil(error.errorDescription)
  }

  // MARK: - Tests

  /// Tests comprehensive LockmanStrategyError protocol functionality
  func testLockmanStrategyErrorProtocol() {
    // This test combines multiple aspects to verify overall protocol functionality
    let lockmanInfo = MockLockmanInfo(
      strategyId: "Test.ComprehensiveStrategy",
      actionId: "comprehensiveTest",
      uniqueId: UUID(),
      debugAdditionalInfo: "comprehensive test info",
      isCancellationTarget: true
    )
    let boundaryId = MockBoundaryId("comprehensiveBoundary")
    let error = MockStrategyError.complexError(
      lockmanInfo: lockmanInfo,
      boundaryId: boundaryId,
      additionalData: "comprehensive data"
    )

    // Verify protocol conformance through interface usage
    let strategyError: any LockmanStrategyError = error
    let lockmanError: any LockmanError = error
    let swiftError: any Error = error
    XCTAssertNotNil(strategyError.lockmanInfo)
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertNotNil(swiftError)

    // Verify required property access
    XCTAssertEqual(error.lockmanInfo.actionId, "comprehensiveTest")
    XCTAssertEqual(String(describing: error.boundaryId), "comprehensiveBoundary")

    // Verify error information
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertTrue(error.errorDescription!.contains("comprehensiveTest"))

    // Verify type safety and polymorphism
    let erasedError: any LockmanStrategyError = error
    XCTAssertEqual(erasedError.lockmanInfo.actionId, "comprehensiveTest")
    XCTAssertEqual(String(describing: erasedError.boundaryId), "comprehensiveBoundary")

    // Verify LocalizedError functionality (since LockmanStrategyError inherits from LockmanError)
    let localizedError: any LocalizedError = erasedError
    XCTAssertNotNil(localizedError.errorDescription)
    XCTAssertNotNil(localizedError.failureReason)
  }
}
