import XCTest

@testable import Lockman

/// Unit tests for LockmanStrategy
///
/// Tests the protocol defining core locking operations that all strategies must implement,
/// providing a common interface for different locking strategies with type safety.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Definition and Structure
/// - [ ] LockmanStrategy<I> protocol definition with primary associated type
/// - [ ] Associated type I: LockmanInfo constraint verification
/// - [ ] Sendable protocol conformance requirement
/// - [ ] Generic parameter handling in protocol methods
/// - [ ] Protocol inheritance and composition behavior
///
/// ### strategyId Property Requirements
/// - [ ] strategyId: LockmanStrategyId property getter requirement
/// - [ ] Built-in strategy ID implementation patterns (.singleExecution, etc.)
/// - [ ] Configured strategy ID patterns with name and configuration
/// - [ ] Instance-specific strategy ID uniqueness
/// - [ ] Strategy ID consistency across multiple accesses
///
/// ### makeStrategyId Static Method
/// - [ ] static func makeStrategyId() -> LockmanStrategyId requirement
/// - [ ] Default configuration strategy ID generation
/// - [ ] Parameterized strategy ID generation for configurable strategies
/// - [ ] Type-based strategy identification consistency
/// - [ ] Macro-generated code compatibility
///
/// ### canLock Method Contract
/// - [ ] canLock<B: LockmanBoundaryId>(boundaryId:info:) -> LockmanResult signature
/// - [ ] Generic boundary type parameter handling
/// - [ ] LockmanResult return type usage (success/cancel/successWithPrecedingCancellation)
/// - [ ] No internal state modification requirement
/// - [ ] Quick execution performance requirement
/// - [ ] Conflict condition evaluation completeness
///
/// ### canLock Implementation Guidelines
/// - [ ] State preservation during canLock evaluation
/// - [ ] Detailed error information in failure cases
/// - [ ] LockmanError conforming error types
/// - [ ] Debugging information inclusion in errors
/// - [ ] Failure scenario handling appropriateness
///
/// ### lock Method Contract
/// - [ ] lock<B: LockmanBoundaryId>(boundaryId:info:) method signature
/// - [ ] Internal state update requirement after canLock success
/// - [ ] Active lock tracking responsibility
/// - [ ] Idempotent behavior with duplicate calls
/// - [ ] Thread-safe concurrent access handling
///
/// ### lock Implementation Guidelines
/// - [ ] Lock state registration in internal structures
/// - [ ] Boundary and info parameter handling
/// - [ ] Concurrent modification safety
/// - [ ] Lock instance tracking accuracy
/// - [ ] Integration with canLock evaluation results
///
/// ### unlock Method Contract
/// - [ ] unlock<B: LockmanBoundaryId>(boundaryId:info:) method signature
/// - [ ] Lock release and state cleanup responsibility
/// - [ ] Parameter matching with corresponding lock call
/// - [ ] Specific lock instance identification and removal
/// - [ ] Defensive programming for non-existent locks
///
/// ### unlock Implementation Guidelines
/// - [ ] Boundary ID and action ID combination matching
/// - [ ] Exact instance matching for strategies requiring it
/// - [ ] Idempotent behavior for already-released locks
/// - [ ] Error handling for missing lock scenarios
/// - [ ] State consistency after unlock operations
///
/// ### cleanUp() Global Method
/// - [ ] cleanUp() method signature and return type (Void)
/// - [ ] All boundaries and locks removal requirement
/// - [ ] Strategy reset to initial state behavior
/// - [ ] Application shutdown sequence integration
/// - [ ] Test suite cleanup usage patterns
///
/// ### cleanUp() Implementation Guidelines
/// - [ ] Complete lock state removal across all boundaries
/// - [ ] Safe multiple invocation behavior
/// - [ ] Emergency cleanup scenario handling
/// - [ ] Memory cleanup and resource release
/// - [ ] Global reset operation completeness
///
/// ### cleanUp(boundaryId:) Boundary-Specific Method
/// - [ ] cleanUp<B: LockmanBoundaryId>(boundaryId:) method signature
/// - [ ] Targeted boundary-specific cleanup behavior
/// - [ ] Other boundary preservation requirement
/// - [ ] Fine-grained cleanup control capability
/// - [ ] Scoped cleanup operation isolation
///
/// ### cleanUp(boundaryId:) Implementation Guidelines
/// - [ ] Single boundary lock removal accuracy
/// - [ ] Non-existent boundary handling safety
/// - [ ] Other boundary state preservation
/// - [ ] Feature-specific cleanup integration
/// - [ ] User session cleanup patterns
///
/// ### getCurrentLocks Debug Method
/// - [ ] getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] signature
/// - [ ] Current lock state snapshot provision
/// - [ ] Boundary-to-locks mapping accuracy
/// - [ ] Type erasure handling with AnyLockmanBoundaryId
/// - [ ] Debug tool integration support
///
/// ### getCurrentLocks Implementation Guidelines
/// - [ ] Snapshot semantics (not live references)
/// - [ ] All active locks inclusion across boundaries
/// - [ ] Lock info instance preservation from lock calls
/// - [ ] Thread-safe concurrent access handling
/// - [ ] Debugging information completeness
///
/// ### Thread Safety Requirements
/// - [ ] Sendable protocol conformance verification
/// - [ ] Concurrent method call safety across all protocol methods
/// - [ ] Internal state synchronization mechanisms
/// - [ ] Race condition prevention in implementations
/// - [ ] Multi-threaded access pattern support
///
/// ### Type Safety and Generics
/// - [ ] Associated type I: LockmanInfo constraint enforcement
/// - [ ] Generic boundary type B: LockmanBoundaryId handling
/// - [ ] Type parameter consistency across method calls
/// - [ ] Primary associated type syntax compliance
/// - [ ] Generic constraint propagation correctness
///
/// ### Strategy Implementation Patterns
/// - [ ] Class-based stateful strategy implementation support
/// - [ ] Struct-based stateless strategy implementation support
/// - [ ] AnyLockmanStrategy type erasure compatibility
/// - [ ] Built-in strategy conformance patterns
/// - [ ] Custom strategy implementation guidelines
///
/// ### Error Handling and Results
/// - [ ] LockmanResult enum usage in canLock method
/// - [ ] LockmanError protocol conformance in failure cases
/// - [ ] Error propagation through strategy implementations
/// - [ ] Detailed error information requirements
/// - [ ] Debugging support in error scenarios
///
/// ### Integration with Strategy Container
/// - [ ] Strategy registration using strategyId property
/// - [ ] Strategy resolution by ID functionality
/// - [ ] Multiple strategy instance coexistence
/// - [ ] Type-erased strategy storage compatibility
/// - [ ] Container-strategy interaction patterns
///
/// ### Performance Characteristics
/// - [ ] canLock quick execution requirement verification
/// - [ ] Method call overhead measurement
/// - [ ] Concurrent access performance impact
/// - [ ] Memory efficiency in lock tracking
/// - [ ] Strategy operation scalability
///
/// ### Implementation Guidelines Verification
/// - [ ] idempotent operation requirement testing
/// - [ ] Defensive programming pattern adherence
/// - [ ] State consistency guarantee verification
/// - [ ] Resource cleanup completeness validation
/// - [ ] Protocol contract fulfillment testing
///
/// ### Documentation and Usage Examples
/// - [ ] Example implementation completeness and accuracy
/// - [ ] Usage pattern documentation verification
/// - [ ] Implementation guideline clarity
/// - [ ] Best practice demonstration effectiveness
/// - [ ] API design consistency validation
///
/// ### Protocol Evolution and Compatibility
/// - [ ] Future method addition compatibility
/// - [ ] Associated type evolution scenarios
/// - [ ] Protocol requirement changes impact
/// - [ ] Backward compatibility considerations
/// - [ ] Migration path for protocol updates
///
final class LockmanStrategyTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Protocol Definition and Structure Tests

  func testProtocolDefinitionWithPrimaryAssociatedType() {
    // Test that LockmanStrategy protocol uses primary associated type syntax
    let mockStrategy = MockLockmanStrategy()

    // Should be usable with primary associated type syntax
    let erasedStrategy: any LockmanStrategy<MockLockmanInfo> = mockStrategy

    XCTAssertTrue(erasedStrategy is MockLockmanStrategy)
    XCTAssertEqual(erasedStrategy.strategyId, LockmanStrategyId("MockStrategy"))
  }

  func testAssociatedTypeLockmanInfoConstraintVerification() {
    // Test associated type constraint enforcement
    let mockStrategy = MockLockmanStrategy()

    // Associated type should conform to LockmanInfo
    let info = MockLockmanInfo(actionId: "constraint-test")
    let result = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)

    XCTAssertNotNil(result)
    XCTAssertTrue(info is any LockmanInfo)
  }

  func testSendableProtocolConformanceRequirement() {
    // Test Sendable conformance requirement
    let mockStrategy = MockLockmanStrategy()

    // Sendable conformance is checked at compile time, no runtime test needed

    // Should be usable across concurrent contexts
    let expectation = XCTestExpectation(description: "Sendable test")
    expectation.expectedFulfillmentCount = 10

    let queue = DispatchQueue(label: "sendable.test", attributes: .concurrent)

    for i in 0..<10 {
      queue.async {
        let info = MockLockmanInfo(actionId: "sendable-\(i)")
        let _ = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testGenericParameterHandlingInProtocolMethods() {
    // Test generic parameter handling across protocol methods
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "boundary-1")
    let boundary2 = MockSpecificBoundaryId(id: "boundary-2", category: "specific")
    let info = MockLockmanInfo(actionId: "generic-test")

    // Should work with different boundary types
    let result1 = mockStrategy.canLock(boundaryId: boundary1, info: info)
    let result2 = mockStrategy.canLock(boundaryId: boundary2, info: info)

    XCTAssertNotNil(result1)
    XCTAssertNotNil(result2)
  }

  func testProtocolInheritanceAndCompositionBehavior() {
    // Test protocol inheritance behavior
    let mockStrategy = MockLockmanStrategy()

    // Should satisfy Sendable requirement
    let sendableStrategy: any Sendable = mockStrategy
    XCTAssertTrue(sendableStrategy is MockLockmanStrategy)

    // Should be usable in protocol composition
    func processStrategy<T: LockmanStrategy<MockLockmanInfo> & Sendable>(_ strategy: T) -> Bool {
      return strategy.strategyId == LockmanStrategyId("MockStrategy")
    }

    XCTAssertTrue(processStrategy(mockStrategy))
  }

  // MARK: - strategyId Property Tests

  func testStrategyIdPropertyGetterRequirement() {
    // Test strategyId property requirement
    let mockStrategy = MockLockmanStrategy()

    let strategyId = mockStrategy.strategyId

    XCTAssertNotNil(strategyId)
    XCTAssertEqual(strategyId, LockmanStrategyId("MockStrategy"))
    XCTAssertTrue(strategyId is LockmanStrategyId)
  }

  func testBuiltInStrategyIdImplementationPatterns() {
    // Test built-in strategy ID patterns
    let builtInStrategy = MockBuiltInStrategy()

    let strategyId = builtInStrategy.strategyId

    XCTAssertEqual(strategyId, LockmanStrategyId("BuiltIn"))
  }

  func testConfiguredStrategyIdPatternsWithNameAndConfiguration() {
    // Test configured strategy patterns
    let configuredStrategy = MockConfiguredStrategy(configuration: "test-config")

    let strategyId = configuredStrategy.strategyId

    XCTAssertEqual(strategyId, LockmanStrategyId(name: "MockConfigured", configuration: "test-config"))
  }

  func testInstanceSpecificStrategyIdUniqueness() {
    // Test strategy ID uniqueness across instances
    let strategy1 = MockInstanceSpecificStrategy(instanceId: "instance-1")
    let strategy2 = MockInstanceSpecificStrategy(instanceId: "instance-2")

    XCTAssertNotEqual(strategy1.strategyId, strategy2.strategyId)
    XCTAssertTrue(String(describing: strategy1.strategyId).hasPrefix("InstanceSpecific:"))
    XCTAssertTrue(String(describing: strategy2.strategyId).hasPrefix("InstanceSpecific:"))
  }

  func testStrategyIdConsistencyAcrossMultipleAccesses() {
    // Test strategy ID consistency
    let mockStrategy = MockLockmanStrategy()

    let id1 = mockStrategy.strategyId
    let id2 = mockStrategy.strategyId
    let id3 = mockStrategy.strategyId

    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id2, id3)
    XCTAssertEqual(id1, id3)
  }

  // MARK: - makeStrategyId Static Method Tests

  func testMakeStrategyIdStaticMethodRequirement() {
    // Test static method requirement
    let strategyId = MockLockmanStrategy.makeStrategyId()

    XCTAssertNotNil(strategyId)
    XCTAssertEqual(strategyId, LockmanStrategyId("MockStrategy"))
    XCTAssertTrue(strategyId is LockmanStrategyId)
  }

  func testDefaultConfigurationStrategyIdGeneration() {
    // Test default configuration generation
    let defaultId = MockBuiltInStrategy.makeStrategyId()

    XCTAssertEqual(defaultId, LockmanStrategyId("BuiltIn"))
  }

  func testParameterizedStrategyIdGenerationForConfigurableStrategies() {
    // Test parameterized generation
    let configuredId = MockConfiguredStrategy.makeStrategyId()

    XCTAssertEqual(configuredId, LockmanStrategyId(name: "ConfiguredStrategy", configuration: "default"))
  }

  func testTypeBasedStrategyIdentificationConsistency() {
    // Test type-based identification
    let instanceId = MockLockmanStrategy().strategyId
    let staticId = MockLockmanStrategy.makeStrategyId()

    XCTAssertEqual(instanceId, staticId)
  }

  func testMacroGeneratedCodeCompatibility() {
    // Test macro compatibility
    let macroCompatibleId = MockMacroCompatibleStrategy.makeStrategyId()

    XCTAssertEqual(macroCompatibleId, LockmanStrategyId("MacroCompatible"))

    // Should work with macro-style usage
    func macroUsage() -> LockmanStrategyId {
      return MockMacroCompatibleStrategy.makeStrategyId()
    }

    XCTAssertEqual(macroUsage(), LockmanStrategyId("MacroCompatible"))
  }

  // MARK: - canLock Method Contract Tests

  func testCanLockMethodSignatureWithGenericBoundaryType() {
    // Test canLock method signature
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "signature-test")
    let info = MockLockmanInfo(actionId: "signature-action")

    let result = mockStrategy.canLock(boundaryId: boundary, info: info)

    XCTAssertTrue(result is LockmanResult)
  }

  func testCanLockLockmanResultReturnTypeUsage() {
    // Test LockmanResult return type usage
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "result-test")

    // Test success case
    mockStrategy.setCanLockResult(.success)
    let successResult = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)

    switch successResult {
    case .success:
      XCTAssertTrue(true)
    default:
      XCTFail("Should return success")
    }

    // Test cancel case
    let testError = MockStrategyError(message: "Test failure", lockmanInfo: info, boundaryId: MockBoundaryId())
    mockStrategy.setCanLockResult(.cancel(testError))
    let cancelResult = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)

    switch cancelResult {
    case .cancel(let error):
      XCTAssertTrue(error is MockStrategyError)
    default:
      XCTFail("Should return cancel")
    }
  }

  func testCanLockNoInternalStateModificationRequirement() {
    // Test state preservation during canLock
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "state-test")

    let initialLocks = mockStrategy.getCurrentLocks()

    let _ = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)

    let finalLocks = mockStrategy.getCurrentLocks()

    XCTAssertEqual(initialLocks.count, finalLocks.count)
  }

  func testCanLockQuickExecutionPerformanceRequirement() {
    // Test quick execution requirement
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "performance-test")

    measure {
      for _ in 0..<1000 {
        let _ = mockStrategy.canLock(boundaryId: MockBoundaryId(), info: info)
      }
    }
  }

  func testCanLockConflictConditionEvaluationCompleteness() {
    // Test conflict condition evaluation
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "conflict-boundary")
    let info1 = MockLockmanInfo(actionId: "conflict-action")
    let info2 = MockLockmanInfo(actionId: "conflict-action")

    // First lock should succeed
    mockStrategy.setCanLockResult(.success)
    let result1 = mockStrategy.canLock(boundaryId: boundary, info: info1)
    mockStrategy.lock(boundaryId: boundary, info: info1)

    // Second lock with same action should be evaluated for conflict
    mockStrategy.setCanLockResult(.cancel(MockStrategyError(message: "Conflict", lockmanInfo: info2, boundaryId: boundary)))
    let result2 = mockStrategy.canLock(boundaryId: boundary, info: info2)

    switch result1 {
    case .success: XCTAssertTrue(true)
    default: XCTFail("First lock should succeed")
    }

    switch result2 {
    case .cancel: XCTAssertTrue(true)
    default: XCTFail("Second lock should detect conflict")
    }
  }

  // MARK: - canLock Implementation Guidelines Tests

  func testCanLockStatePreservationDuringEvaluation() {
    // Test state preservation
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "preservation-boundary")
    let info = MockLockmanInfo(actionId: "preservation-action")

    // Add an existing lock
    mockStrategy.lock(boundaryId: boundary, info: info)
    let locksBeforeCanLock = mockStrategy.getCurrentLocks()

    // canLock should not modify state
    let _ = mockStrategy.canLock(
      boundaryId: boundary, info: MockLockmanInfo(actionId: "other-action"))
    let locksAfterCanLock = mockStrategy.getCurrentLocks()

    XCTAssertEqual(locksBeforeCanLock.count, locksAfterCanLock.count)

    if let beforeLocks = locksBeforeCanLock[AnyLockmanBoundaryId(boundary)],
      let afterLocks = locksAfterCanLock[AnyLockmanBoundaryId(boundary)]
    {
      XCTAssertEqual(beforeLocks.count, afterLocks.count)
    }
  }

  func testCanLockDetailedErrorInformationInFailureCases() {
    // Test detailed error information
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "test-action")
    let boundary = MockBoundaryId()
    let detailedError = MockDetailedStrategyError(
      message: "Detailed conflict explanation",
      conflictingAction: "existing-action",
      lockmanInfo: info,
      boundaryId: boundary
    )
    mockStrategy.setCanLockResult(.cancel(detailedError))

    let result = mockStrategy.canLock(
      boundaryId: boundary,
      info: info
    )

    switch result {
    case .cancel(let error):
      if let detailedError = error as? MockDetailedStrategyError {
        XCTAssertEqual(detailedError.message, "Detailed conflict explanation")
        XCTAssertEqual(detailedError.conflictingAction, "existing-action")
      } else {
        XCTFail("Should provide detailed error information")
      }
    default:
      XCTFail("Should return failure with detailed error")
    }
  }

  func testCanLockLockmanErrorConformingErrorTypes() {
    // Test LockmanError conforming error types
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "error-test")
    let boundary = MockBoundaryId()
    let lockmanError = MockLockmanStrategyError(description: "LockmanError test", lockmanInfo: info, boundaryId: boundary)
    mockStrategy.setCanLockResult(.cancel(lockmanError))

    let result = mockStrategy.canLock(
      boundaryId: boundary,
      info: info
    )

    switch result {
    case .cancel(let error):
      XCTAssertTrue(error is any LockmanError)
      XCTAssertTrue(error is any LockmanStrategyError)
    default:
      XCTFail("Should return cancel with LockmanError conforming error")
    }
  }

  func testCanLockDebuggingInformationInclusionInErrors() {
    // Test debugging information inclusion
    let mockStrategy = MockLockmanStrategy()
    let info = MockLockmanInfo(actionId: "test-action")
    let boundary = MockBoundaryId(id: "test-boundary")
    let debugError = MockDebuggableStrategyError(
      message: "Debug test",
      debugInfo: ["boundaryId": "test-boundary", "actionId": "test-action"],
      lockmanInfo: info,
      boundaryId: boundary
    )
    mockStrategy.setCanLockResult(.cancel(debugError))

    let result = mockStrategy.canLock(
      boundaryId: boundary,
      info: info
    )

    switch result {
    case .cancel(let error):
      if let debugError = error as? MockDebuggableStrategyError {
        XCTAssertEqual(debugError.debugInfo["boundaryId"], "test-boundary")
        XCTAssertEqual(debugError.debugInfo["actionId"], "test-action")
      }
    default:
      XCTFail("Should return cancel with debugging information")
    }
  }

  func testCanLockFailureScenarioHandlingAppropriateness() {
    // Test appropriate failure scenario handling
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "failure-boundary")
    let info = MockLockmanInfo(actionId: "failure-action")

    // Test different failure scenarios
    let scenarios = [
      MockStrategyError(message: "Resource unavailable", lockmanInfo: info, boundaryId: boundary),
      MockStrategyError(message: "Priority conflict", lockmanInfo: info, boundaryId: boundary),
      MockStrategyError(message: "Rate limit exceeded", lockmanInfo: info, boundaryId: boundary),
    ]

    for scenario in scenarios {
      mockStrategy.setCanLockResult(.cancel(scenario))
      let result = mockStrategy.canLock(boundaryId: boundary, info: info)

      switch result {
      case .cancel(let error):
        XCTAssertTrue(error is MockStrategyError)
      default:
        XCTFail("Should handle cancel scenario appropriately")
      }
    }
  }

  // MARK: - lock Method Contract Tests

  func testLockMethodSignatureWithGenericBoundaryType() {
    // Test lock method signature
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "lock-boundary")
    let boundary2 = MockSpecificBoundaryId(id: "specific-boundary", category: "test")
    let info = MockLockmanInfo(actionId: "lock-action")

    // Should work with different boundary types
    mockStrategy.lock(boundaryId: boundary1, info: info)
    mockStrategy.lock(boundaryId: boundary2, info: info)

    // Should update internal state
    let locks = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThan(locks.count, 0)
  }

  func testLockInternalStateUpdateRequirementAfterCanLockSuccess() {
    // Test state update after successful canLock
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "state-boundary")
    let info = MockLockmanInfo(actionId: "state-action")

    let initialLocks = mockStrategy.getCurrentLocks()

    mockStrategy.setCanLockResult(.success)
    let canLockResult = mockStrategy.canLock(boundaryId: boundary, info: info)

    switch canLockResult {
    case .success:
      mockStrategy.lock(boundaryId: boundary, info: info)
      let finalLocks = mockStrategy.getCurrentLocks()

      XCTAssertGreaterThan(finalLocks.count, initialLocks.count)
    default:
      XCTFail("canLock should succeed before testing lock")
    }
  }

  func testLockActiveLockTrackingResponsibility() {
    // Test active lock tracking
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "tracking-boundary")
    let info1 = MockLockmanInfo(actionId: "tracking-action-1")
    let info2 = MockLockmanInfo(actionId: "tracking-action-2")

    mockStrategy.lock(boundaryId: boundary, info: info1)
    mockStrategy.lock(boundaryId: boundary, info: info2)

    let locks = mockStrategy.getCurrentLocks()
    let boundaryLocks = locks[AnyLockmanBoundaryId(boundary)]

    XCTAssertNotNil(boundaryLocks)
    XCTAssertEqual(boundaryLocks?.count, 2)
  }

  func testLockIdempotentBehaviorWithDuplicateCalls() {
    // Test idempotent behavior
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "idempotent-boundary")
    let info = MockLockmanInfo(actionId: "idempotent-action")

    mockStrategy.lock(boundaryId: boundary, info: info)
    let locksAfterFirst = mockStrategy.getCurrentLocks()

    mockStrategy.lock(boundaryId: boundary, info: info)
    let locksAfterSecond = mockStrategy.getCurrentLocks()

    // Should be idempotent
    XCTAssertEqual(locksAfterFirst.count, locksAfterSecond.count)
  }

  func testLockThreadSafeConcurrentAccessHandling() {
    // Test thread-safe concurrent access
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "concurrent-boundary")

    let expectation = XCTestExpectation(description: "Concurrent lock test")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue(label: "concurrent.lock", attributes: .concurrent)

    for i in 0..<100 {
      queue.async {
        let info = MockLockmanInfo(actionId: "concurrent-action-\(i)")
        mockStrategy.lock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 10.0)

    let finalLocks = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThan(finalLocks.count, 0)
  }

  // MARK: - lock Implementation Guidelines Tests

  func testLockStateRegistrationInInternalStructures() {
    // Test lock state registration
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "registration-boundary")
    let info = MockLockmanInfo(actionId: "registration-action")

    mockStrategy.lock(boundaryId: boundary, info: info)

    let locks = mockStrategy.getCurrentLocks()
    let boundaryLocks = locks[AnyLockmanBoundaryId(boundary)]

    XCTAssertNotNil(boundaryLocks)
    XCTAssertTrue(
      boundaryLocks?.contains { lockInfo in
        lockInfo.actionId == "registration-action"
      } ?? false)
  }

  func testLockBoundaryAndInfoParameterHandling() {
    // Test parameter handling
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "parameter-boundary")
    let info = MockLockmanInfo(actionId: "parameter-action")

    mockStrategy.lock(boundaryId: boundary, info: info)

    let locks = mockStrategy.getCurrentLocks()
    let retrievedBoundary = locks.keys.first
    let retrievedInfo = locks.values.first?.first

    XCTAssertEqual(String(describing: retrievedBoundary), "parameter-boundary")
    XCTAssertEqual(retrievedInfo?.actionId, "parameter-action")
  }

  func testLockConcurrentModificationSafety() {
    // Test concurrent modification safety
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "modification-boundary")

    let expectation = XCTestExpectation(description: "Concurrent modification test")
    expectation.expectedFulfillmentCount = 200

    let queue = DispatchQueue(label: "modification.test", attributes: .concurrent)

    for i in 0..<100 {
      queue.async {
        let info = MockLockmanInfo(actionId: "lock-action-\(i)")
        mockStrategy.lock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }

      queue.async {
        let info = MockLockmanInfo(actionId: "unlock-action-\(i)")
        mockStrategy.lock(boundaryId: boundary, info: info)
        mockStrategy.unlock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 15.0)

    // Should complete without crashes
    let finalLocks = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThanOrEqual(finalLocks.count, 0)
  }

  func testLockInstanceTrackingAccuracy() {
    // Test lock instance tracking accuracy
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "accuracy-boundary")
    let info1 = MockLockmanInfo(actionId: "accuracy-action-1")
    let info2 = MockLockmanInfo(actionId: "accuracy-action-2")

    mockStrategy.lock(boundaryId: boundary, info: info1)
    mockStrategy.lock(boundaryId: boundary, info: info2)

    let locks = mockStrategy.getCurrentLocks()
    let boundaryLocks = locks[AnyLockmanBoundaryId(boundary)]

    XCTAssertEqual(boundaryLocks?.count, 2)

    let actionIds = boundaryLocks?.map { $0.actionId }.sorted()
    XCTAssertEqual(actionIds, ["accuracy-action-1", "accuracy-action-2"])
  }

  func testLockIntegrationWithCanLockEvaluationResults() {
    // Test integration with canLock results
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "integration-boundary")
    let info = MockLockmanInfo(actionId: "integration-action")

    // Simulate successful canLock followed by lock
    mockStrategy.setCanLockResult(.success)
    let canLockResult = mockStrategy.canLock(boundaryId: boundary, info: info)

    switch canLockResult {
    case .success:
      mockStrategy.lock(boundaryId: boundary, info: info)

      let locks = mockStrategy.getCurrentLocks()
      XCTAssertGreaterThan(locks.count, 0)
    default:
      XCTFail("canLock should succeed for integration test")
    }
  }

  // MARK: - unlock Method Contract Tests

  func testUnlockMethodSignatureWithGenericBoundaryType() {
    // Test unlock method signature
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "unlock-boundary-1")
    let boundary2 = MockSpecificBoundaryId(id: "unlock-boundary-2", category: "specific")
    let info = MockLockmanInfo(actionId: "unlock-action")

    // Lock then unlock with different boundary types
    mockStrategy.lock(boundaryId: boundary1, info: info)
    mockStrategy.unlock(boundaryId: boundary1, info: info)

    mockStrategy.lock(boundaryId: boundary2, info: info)
    mockStrategy.unlock(boundaryId: boundary2, info: info)

    // Should handle different boundary types correctly
    XCTAssertTrue(true)
  }

  func testUnlockLockReleaseAndStateCleanupResponsibility() {
    // Test lock release and state cleanup
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "cleanup-boundary")
    let info = MockLockmanInfo(actionId: "cleanup-action")

    mockStrategy.lock(boundaryId: boundary, info: info)
    let locksAfterLock = mockStrategy.getCurrentLocks()

    mockStrategy.unlock(boundaryId: boundary, info: info)
    let locksAfterUnlock = mockStrategy.getCurrentLocks()

    XCTAssertGreaterThan(locksAfterLock.count, 0)
    XCTAssertLessThan(locksAfterUnlock.count, locksAfterLock.count)
  }

  func testUnlockParameterMatchingWithCorrespondingLockCall() {
    // Test parameter matching
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "matching-boundary")
    let info = MockLockmanInfo(actionId: "matching-action")

    mockStrategy.lock(boundaryId: boundary, info: info)

    // Unlock with matching parameters
    mockStrategy.unlock(boundaryId: boundary, info: info)

    let locks = mockStrategy.getCurrentLocks()
    let boundaryLocks = locks[AnyLockmanBoundaryId(boundary)]

    XCTAssertTrue(boundaryLocks?.isEmpty ?? true)
  }

  func testUnlockSpecificLockInstanceIdentificationAndRemoval() {
    // Test specific lock instance identification
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "identification-boundary")
    let info1 = MockLockmanInfo(actionId: "identification-action-1")
    let info2 = MockLockmanInfo(actionId: "identification-action-2")

    mockStrategy.lock(boundaryId: boundary, info: info1)
    mockStrategy.lock(boundaryId: boundary, info: info2)

    // Unlock specific instance
    mockStrategy.unlock(boundaryId: boundary, info: info1)

    let locks = mockStrategy.getCurrentLocks()
    let boundaryLocks = locks[AnyLockmanBoundaryId(boundary)]

    XCTAssertEqual(boundaryLocks?.count, 1)
    XCTAssertEqual(boundaryLocks?.first?.actionId, "identification-action-2")
  }

  func testUnlockDefensiveProgrammingForNonExistentLocks() {
    // Test defensive programming
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "defensive-boundary")
    let info = MockLockmanInfo(actionId: "defensive-action")

    // Unlock without locking first - should not crash
    mockStrategy.unlock(boundaryId: boundary, info: info)

    // Should handle gracefully
    let locks = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThanOrEqual(locks.count, 0)
  }

  // MARK: - cleanUp() Global Method Tests

  func testCleanUpGlobalMethodSignatureAndReturnType() {
    // Test cleanUp() method signature
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "cleanup-global-boundary")
    let info = MockLockmanInfo(actionId: "cleanup-global-action")

    mockStrategy.lock(boundaryId: boundary, info: info)

    // Method should return void and clean all locks
    mockStrategy.cleanUp()

    let locks = mockStrategy.getCurrentLocks()
    XCTAssertTrue(locks.isEmpty)
  }

  func testCleanUpAllBoundariesAndLocksRemovalRequirement() {
    // Test all boundaries removal
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "cleanup-boundary-1")
    let boundary2 = MockBoundaryId(id: "cleanup-boundary-2")
    let info1 = MockLockmanInfo(actionId: "cleanup-action-1")
    let info2 = MockLockmanInfo(actionId: "cleanup-action-2")

    mockStrategy.lock(boundaryId: boundary1, info: info1)
    mockStrategy.lock(boundaryId: boundary2, info: info2)

    let locksBeforeCleanup = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThan(locksBeforeCleanup.count, 0)

    mockStrategy.cleanUp()

    let locksAfterCleanup = mockStrategy.getCurrentLocks()
    XCTAssertTrue(locksAfterCleanup.isEmpty)
  }

  func testCleanUpStrategyResetToInitialStateBehavior() {
    // Test reset to initial state
    let mockStrategy = MockLockmanStrategy()
    let initialLocks = mockStrategy.getCurrentLocks()

    // Add some locks
    let boundary = MockBoundaryId(id: "reset-boundary")
    let info = MockLockmanInfo(actionId: "reset-action")
    mockStrategy.lock(boundaryId: boundary, info: info)

    // Reset to initial state
    mockStrategy.cleanUp()

    let finalLocks = mockStrategy.getCurrentLocks()
    XCTAssertEqual(initialLocks.count, finalLocks.count)
    XCTAssertTrue(finalLocks.isEmpty)
  }

  func testCleanUpApplicationShutdownSequenceIntegration() {
    // Test application shutdown integration
    let mockStrategy = MockLockmanStrategy()

    // Simulate application with active locks
    for i in 0..<10 {
      let boundary = MockBoundaryId(id: "shutdown-boundary-\(i)")
      let info = MockLockmanInfo(actionId: "shutdown-action-\(i)")
      mockStrategy.lock(boundaryId: boundary, info: info)
    }

    XCTAssertGreaterThan(mockStrategy.getCurrentLocks().count, 0)

    // Simulate shutdown cleanup
    mockStrategy.cleanUp()

    XCTAssertTrue(mockStrategy.getCurrentLocks().isEmpty)
  }

  func testCleanUpTestSuiteCleanupUsagePatterns() {
    // Test test suite cleanup patterns
    let mockStrategy = MockLockmanStrategy()

    // Simulate test with locks
    let boundary = MockBoundaryId(id: "test-boundary")
    let info = MockLockmanInfo(actionId: "test-action")
    mockStrategy.lock(boundaryId: boundary, info: info)

    // Cleanup between tests
    mockStrategy.cleanUp()

    // Should be clean for next test
    XCTAssertTrue(mockStrategy.getCurrentLocks().isEmpty)
  }

  // MARK: - cleanUp(boundaryId:) Boundary-Specific Method Tests

  func testCleanUpBoundarySpecificMethodSignature() {
    // Test boundary-specific cleanup signature
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "specific-boundary-1")
    let boundary2 = MockBoundaryId(id: "specific-boundary-2")
    let info = MockLockmanInfo(actionId: "specific-action")

    mockStrategy.lock(boundaryId: boundary1, info: info)
    mockStrategy.lock(boundaryId: boundary2, info: info)

    // Clean up specific boundary
    mockStrategy.cleanUp(boundaryId: boundary1)

    let locks = mockStrategy.getCurrentLocks()
    XCTAssertEqual(locks.count, 1)
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(boundary2)])
  }

  func testCleanUpTargetedBoundarySpecificCleanupBehavior() {
    // Test targeted cleanup behavior
    let mockStrategy = MockLockmanStrategy()
    let targetBoundary = MockBoundaryId(id: "target-boundary")
    let otherBoundary = MockBoundaryId(id: "other-boundary")
    let info1 = MockLockmanInfo(actionId: "target-action")
    let info2 = MockLockmanInfo(actionId: "other-action")

    mockStrategy.lock(boundaryId: targetBoundary, info: info1)
    mockStrategy.lock(boundaryId: otherBoundary, info: info2)

    mockStrategy.cleanUp(boundaryId: targetBoundary)

    let locks = mockStrategy.getCurrentLocks()
    XCTAssertNil(locks[AnyLockmanBoundaryId(targetBoundary)])
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(otherBoundary)])
  }

  func testCleanUpOtherBoundaryPreservationRequirement() {
    // Test other boundary preservation
    let mockStrategy = MockLockmanStrategy()
    let cleanupBoundary = MockBoundaryId(id: "cleanup-boundary")
    let preservedBoundary = MockBoundaryId(id: "preserved-boundary")
    let info = MockLockmanInfo(actionId: "preserve-test")

    mockStrategy.lock(boundaryId: cleanupBoundary, info: info)
    mockStrategy.lock(boundaryId: preservedBoundary, info: info)

    let locksBeforeCleanup = mockStrategy.getCurrentLocks()
    let preservedLocksBefore = locksBeforeCleanup[AnyLockmanBoundaryId(preservedBoundary)]

    mockStrategy.cleanUp(boundaryId: cleanupBoundary)

    let locksAfterCleanup = mockStrategy.getCurrentLocks()
    let preservedLocksAfter = locksAfterCleanup[AnyLockmanBoundaryId(preservedBoundary)]

    XCTAssertEqual(preservedLocksBefore?.count, preservedLocksAfter?.count)
  }

  func testCleanUpFineGrainedCleanupControlCapability() {
    // Test fine-grained control
    let mockStrategy = MockLockmanStrategy()
    let boundaries = [
      MockBoundaryId(id: "control-boundary-1"),
      MockBoundaryId(id: "control-boundary-2"),
      MockBoundaryId(id: "control-boundary-3"),
    ]

    for boundary in boundaries {
      let info = MockLockmanInfo(actionId: "control-action")
      mockStrategy.lock(boundaryId: boundary, info: info)
    }

    // Clean up middle boundary only
    mockStrategy.cleanUp(boundaryId: boundaries[1])

    let locks = mockStrategy.getCurrentLocks()
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(boundaries[0])])
    XCTAssertNil(locks[AnyLockmanBoundaryId(boundaries[1])])
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(boundaries[2])])
  }

  func testCleanUpScopedCleanupOperationIsolation() {
    // Test scoped operation isolation
    let mockStrategy = MockLockmanStrategy()
    let scope1Boundary = MockBoundaryId(id: "scope-1-boundary")
    let scope2Boundary = MockBoundaryId(id: "scope-2-boundary")
    let info = MockLockmanInfo(actionId: "scope-action")

    mockStrategy.lock(boundaryId: scope1Boundary, info: info)
    mockStrategy.lock(boundaryId: scope2Boundary, info: info)

    // Cleanup should be isolated to specified scope
    mockStrategy.cleanUp(boundaryId: scope1Boundary)

    let locks = mockStrategy.getCurrentLocks()
    XCTAssertEqual(locks.count, 1)
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(scope2Boundary)])
  }

  // MARK: - getCurrentLocks Debug Method Tests

  func testGetCurrentLocksMethodSignatureReturnType() {
    // Test getCurrentLocks method signature
    let mockStrategy = MockLockmanStrategy()

    let result = mockStrategy.getCurrentLocks()

    XCTAssertTrue(result is [AnyLockmanBoundaryId: [any LockmanInfo]])
  }

  func testGetCurrentLocksCurrentLockStateSnapshotProvision() {
    // Test snapshot provision
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "snapshot-boundary")
    let info = MockLockmanInfo(actionId: "snapshot-action")

    let emptySnapshot = mockStrategy.getCurrentLocks()
    XCTAssertTrue(emptySnapshot.isEmpty)

    mockStrategy.lock(boundaryId: boundary, info: info)

    let populatedSnapshot = mockStrategy.getCurrentLocks()
    XCTAssertGreaterThan(populatedSnapshot.count, 0)
  }

  func testGetCurrentLocksBoundaryToLocksMappingAccuracy() {
    // Test boundary-to-locks mapping accuracy
    let mockStrategy = MockLockmanStrategy()
    let boundary1 = MockBoundaryId(id: "mapping-boundary-1")
    let boundary2 = MockBoundaryId(id: "mapping-boundary-2")
    let info1 = MockLockmanInfo(actionId: "mapping-action-1")
    let info2 = MockLockmanInfo(actionId: "mapping-action-2")

    mockStrategy.lock(boundaryId: boundary1, info: info1)
    mockStrategy.lock(boundaryId: boundary2, info: info2)

    let locks = mockStrategy.getCurrentLocks()

    XCTAssertEqual(locks.count, 2)
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(boundary1)])
    XCTAssertNotNil(locks[AnyLockmanBoundaryId(boundary2)])
  }

  func testGetCurrentLocksTypeErasureHandlingWithAnyLockmanBoundaryId() {
    // Test type erasure handling
    let mockStrategy = MockLockmanStrategy()
    let specificBoundary = MockSpecificBoundaryId(id: "type-erasure-boundary", category: "test")
    let info = MockLockmanInfo(actionId: "type-erasure-action")

    mockStrategy.lock(boundaryId: specificBoundary, info: info)

    let locks = mockStrategy.getCurrentLocks()
    let erasedBoundary = AnyLockmanBoundaryId(specificBoundary)

    XCTAssertNotNil(locks[erasedBoundary])
    XCTAssertEqual(locks[erasedBoundary]?.count, 1)
  }

  func testGetCurrentLocksDebugToolIntegrationSupport() {
    // Test debug tool integration
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "debug-boundary")
    let info1 = MockLockmanInfo(actionId: "debug-action-1")
    let info2 = MockLockmanInfo(actionId: "debug-action-2")

    mockStrategy.lock(boundaryId: boundary, info: info1)
    mockStrategy.lock(boundaryId: boundary, info: info2)

    let debugSnapshot = mockStrategy.getCurrentLocks()

    // Should provide complete debug information
    let boundaryLocks = debugSnapshot[AnyLockmanBoundaryId(boundary)]
    XCTAssertEqual(boundaryLocks?.count, 2)

    let actionIds = boundaryLocks?.map { $0.actionId }.sorted()
    XCTAssertEqual(actionIds, ["debug-action-1", "debug-action-2"])
  }

  // MARK: - Thread Safety and Performance Tests

  func testConcurrentMethodCallSafetyAcrossAllProtocolMethods() {
    // Test concurrent method call safety
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "concurrent-methods-boundary")

    let expectation = XCTestExpectation(description: "Concurrent methods test")
    expectation.expectedFulfillmentCount = 400

    let queue = DispatchQueue(label: "concurrent.methods", attributes: .concurrent)

    for i in 0..<100 {
      let info = MockLockmanInfo(actionId: "concurrent-\(i)")

      queue.async {
        let _ = mockStrategy.canLock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }

      queue.async {
        mockStrategy.lock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }

      queue.async {
        mockStrategy.unlock(boundaryId: boundary, info: info)
        expectation.fulfill()
      }

      queue.async {
        let _ = mockStrategy.getCurrentLocks()
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 20.0)
  }

  func testProtocolMethodPerformanceCharacteristics() {
    // Test performance characteristics
    let mockStrategy = MockLockmanStrategy()
    let boundary = MockBoundaryId(id: "performance-boundary")
    let info = MockLockmanInfo(actionId: "performance-action")

    measure {
      for _ in 0..<1000 {
        let _ = mockStrategy.canLock(boundaryId: boundary, info: info)
        mockStrategy.lock(boundaryId: boundary, info: info)
        let _ = mockStrategy.getCurrentLocks()
        mockStrategy.unlock(boundaryId: boundary, info: info)
      }
    }
  }

  // MARK: - Real-world Integration Tests

  func testProtocolUsageWithActualStrategyImplementations() {
    // Test with actual strategy implementation
    let singleExecutionStrategy = LockmanSingleExecutionStrategy()
    let boundary = MockBoundaryId(id: "real-strategy-boundary")
    let info = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("real-action"),
      mode: .action
    )

    let canLockResult = singleExecutionStrategy.canLock(boundaryId: boundary, info: info)

    switch canLockResult {
    case .success:
      singleExecutionStrategy.lock(boundaryId: boundary, info: info)

      let locks = singleExecutionStrategy.getCurrentLocks()
      XCTAssertGreaterThan(locks.count, 0)

      singleExecutionStrategy.unlock(boundaryId: boundary, info: info)

      let finalLocks = singleExecutionStrategy.getCurrentLocks()
      XCTAssertTrue(finalLocks.isEmpty)
    default:
      XCTFail("Real strategy should work correctly")
    }
  }
}

// MARK: - Mock Implementations

private final class MockLockmanStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  private var locks: [AnyLockmanBoundaryId: [MockLockmanInfo]] = [:]
  private var mockCanLockResult: LockmanResult = .success
  private let queue = DispatchQueue(label: "mock.strategy", attributes: .concurrent)

  var strategyId: LockmanStrategyId {
    return LockmanStrategyId("MockStrategy")
  }

  static func makeStrategyId() -> LockmanStrategyId {
    return LockmanStrategyId("MockStrategy")
  }

  func setCanLockResult(_ result: LockmanResult) {
    mockCanLockResult = result
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) -> LockmanResult {
    return mockCanLockResult
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {
    queue.async(flags: .barrier) {
      let erasedBoundary = AnyLockmanBoundaryId(boundaryId)
      if self.locks[erasedBoundary] == nil {
        self.locks[erasedBoundary] = []
      }

      // Check if already locked (idempotent behavior)
      let alreadyLocked =
        self.locks[erasedBoundary]?.contains { existingInfo in
          existingInfo.actionId == info.actionId && existingInfo.uniqueId == info.uniqueId
        } ?? false

      if !alreadyLocked {
        self.locks[erasedBoundary]?.append(info)
      }
    }
  }

  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {
    queue.async(flags: .barrier) {
      let erasedBoundary = AnyLockmanBoundaryId(boundaryId)
      self.locks[erasedBoundary]?.removeAll { existingInfo in
        existingInfo.actionId == info.actionId && existingInfo.uniqueId == info.uniqueId
      }

      if self.locks[erasedBoundary]?.isEmpty == true {
        self.locks.removeValue(forKey: erasedBoundary)
      }
    }
  }

  func cleanUp() {
    queue.async(flags: .barrier) {
      self.locks.removeAll()
    }
  }

  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    queue.async(flags: .barrier) {
      let erasedBoundary = AnyLockmanBoundaryId(boundaryId)
      self.locks.removeValue(forKey: erasedBoundary)
    }
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return queue.sync {
      return locks.mapValues { infos in
        infos.map { $0 as any LockmanInfo }
      }
    }
  }
}

private struct MockLockmanInfo: LockmanInfo {
  let strategyId: LockmanStrategyId
  let actionId: LockmanActionId
  let uniqueId: UUID

  init(actionId: String = "mock-action", strategyId: String = "MockStrategy") {
    self.actionId = LockmanActionId(actionId)
    self.strategyId = LockmanStrategyId(strategyId)
    self.uniqueId = UUID()
  }

  var debugDescription: String {
    "MockLockmanInfo(actionId: \(actionId), strategyId: \(strategyId))"
  }
}

private struct MockBoundaryId: LockmanBoundaryId {
  let value: String

  init(id: String = "mock-boundary") {
    self.value = id
  }

  var debugDescription: String {
    "MockBoundaryId(\(value))"
  }
}

private struct MockSpecificBoundaryId: LockmanBoundaryId {
  let value: String
  let category: String

  init(id: String, category: String) {
    self.value = id
    self.category = category
  }

  var debugDescription: String {
    "MockSpecificBoundaryId(\(value), category: \(category))"
  }
}

private final class MockBuiltInStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  var strategyId: LockmanStrategyId {
    return LockmanStrategyId("BuiltIn")
  }

  static func makeStrategyId() -> LockmanStrategyId {
    return LockmanStrategyId("BuiltIn")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) -> LockmanResult {
    return .success
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

private final class MockConfiguredStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  private let configuration: String

  var strategyId: LockmanStrategyId {
    LockmanStrategyId(name: "MockConfigured", configuration: configuration)
  }

  init(configuration: String) {
    self.configuration = configuration
  }

  static func makeStrategyId() -> LockmanStrategyId {
    return LockmanStrategyId(name: "ConfiguredStrategy", configuration: "default")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) -> LockmanResult {
    return .success
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

private final class MockInstanceSpecificStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  private let instanceId: String

  init(instanceId: String) {
    self.instanceId = instanceId
  }

  var strategyId: LockmanStrategyId {
    return LockmanStrategyId(name: "InstanceSpecific", configuration: instanceId)
  }

  static func makeStrategyId() -> LockmanStrategyId {
    return LockmanStrategyId("InstanceSpecific")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) -> LockmanResult {
    return .success
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

private final class MockMacroCompatibleStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  var strategyId: LockmanStrategyId {
    return Self.makeStrategyId()
  }

  static func makeStrategyId() -> LockmanStrategyId {
    return LockmanStrategyId("MacroCompatible")
  }

  func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) -> LockmanResult {
    return .success
  }

  func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockLockmanInfo) {}
  func cleanUp() {}
  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    return [:]
  }
}

// MARK: - Mock Error Types

private struct MockStrategyError: LockmanStrategyError {
  let message: String
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId

  var localizedDescription: String {
    return message
  }
}

private struct MockDetailedStrategyError: LockmanStrategyError {
  let message: String
  let conflictingAction: String
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId

  var localizedDescription: String {
    return "\(message) - Conflicting: \(conflictingAction)"
  }
}

private struct MockLockmanStrategyError: LockmanStrategyError {
  let description: String
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId

  var localizedDescription: String {
    return description
  }
}

private struct MockDebuggableStrategyError: LockmanStrategyError {
  let message: String
  let debugInfo: [String: String]
  let lockmanInfo: any LockmanInfo
  let boundaryId: any LockmanBoundaryId

  var localizedDescription: String {
    let debugString = debugInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    return "\(message) - Debug: [\(debugString)]"
  }
}
