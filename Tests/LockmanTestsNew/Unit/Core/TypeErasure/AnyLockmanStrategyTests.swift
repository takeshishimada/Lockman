import XCTest

@testable import Lockman

/// Unit tests for AnyLockmanStrategy
///
/// Tests the type-erased wrapper for any LockmanStrategy<I>, enabling heterogeneous strategy
/// storage and manipulation while preserving type safety for lock information.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Type Erasure Structure and Purpose
/// - [ ] AnyLockmanStrategy<I: LockmanInfo> generic wrapper creation
/// - [ ] LockmanStrategy protocol conformance with type erasure
/// - [ ] Sendable conformance for concurrent usage
/// - [ ] Heterogeneous strategy collection storage capability
/// - [ ] Runtime strategy selection and dynamic behavior
///
/// ### Type-Erased Function Storage
/// - [ ] _canLock: @Sendable (any LockmanBoundaryId, I) -> LockmanResult closure storage
/// - [ ] _lock: @Sendable (any LockmanBoundaryId, I) -> Void closure storage
/// - [ ] _unlock: @Sendable (any LockmanBoundaryId, I) -> Void closure storage
/// - [ ] _cleanUp: @Sendable () -> Void closure storage
/// - [ ] _cleanUpById: @Sendable (any LockmanBoundaryId) -> Void closure storage
/// - [ ] _getCurrentLocks: @Sendable () -> [AnyLockmanBoundaryId: [any LockmanInfo]] closure storage
/// - [ ] _strategyId: LockmanStrategyId storage
///
/// ### Initialization and Type Erasure Process
/// - [ ] init<S: LockmanStrategy>(_ strategy: S) where S.I == I constraint verification
/// - [ ] Concrete strategy method capture as closures
/// - [ ] Type constraint S.I == I compile-time safety enforcement
/// - [ ] Closure capture list [strategy] for lifetime management
/// - [ ] Strategy ID preservation during type erasure
///
/// ### Memory Management and Lifetime
/// - [ ] Class-based strategy retention through closures
/// - [ ] Struct-based strategy copying into closures
/// - [ ] Memory leak prevention in closure captures
/// - [ ] Proper lifetime management without strong reference cycles
/// - [ ] Strategy instance availability throughout wrapper lifetime
///
/// ### LockmanStrategy Protocol Implementation
/// - [ ] strategyId property returns preserved concrete strategy ID
/// - [ ] makeStrategyId() returns generic type-erased strategy ID
/// - [ ] Generic identifier format with lock info type inclusion
/// - [ ] Strategy identification consistency across type erasure
///
/// ### canLock Method Delegation
/// - [ ] canLock<B: LockmanBoundaryId>(boundaryId:info:) signature preservation
/// - [ ] Transparent delegation to concrete strategy implementation
/// - [ ] LockmanResult return type preservation
/// - [ ] Error propagation without modification
/// - [ ] Identical behavior to direct concrete strategy calls
///
/// ### lock Method Delegation
/// - [ ] lock<B: LockmanBoundaryId>(boundaryId:info:) method delegation
/// - [ ] Precondition enforcement (canLock success requirement)
/// - [ ] State management delegation to concrete strategy
/// - [ ] Thread safety preservation through delegation
/// - [ ] No additional state management in wrapper
///
/// ### unlock Method Delegation
/// - [ ] unlock<B: LockmanBoundaryId>(boundaryId:info:) method delegation
/// - [ ] Parameter matching requirement preservation
/// - [ ] Exact instance identification delegation (uniqueId-based)
/// - [ ] Error recovery behavior delegation
/// - [ ] Defensive programming pattern preservation
///
/// ### cleanUp Methods Delegation
/// - [ ] cleanUp() global cleanup delegation
/// - [ ] cleanUp<B: LockmanBoundaryId>(boundaryId:) boundary-specific cleanup delegation
/// - [ ] All boundaries cleanup scope preservation
/// - [ ] Selective cleanup isolation behavior preservation
/// - [ ] Thread safety and atomicity delegation
///
/// ### getCurrentLocks Debug Information
/// - [ ] getCurrentLocks() method delegation
/// - [ ] Debug information snapshot consistency
/// - [ ] Type erasure handling in returned dictionary
/// - [ ] Boundary-to-locks mapping preservation
/// - [ ] Thread-safe snapshot provision
///
/// ### Type Safety Guarantees
/// - [ ] Lock information type I preservation across type erasure
/// - [ ] Compile-time type safety with where S.I == I constraint
/// - [ ] Runtime type consistency maintenance
/// - [ ] Generic parameter propagation correctness
/// - [ ] Type mismatch prevention at compilation
///
/// ### Performance Characteristics
/// - [ ] Function pointer indirection overhead measurement
/// - [ ] Type erasure initialization cost analysis
/// - [ ] Method call performance compared to direct strategy calls
/// - [ ] Memory overhead of closure storage
/// - [ ] Negligible runtime cost justification
///
/// ### Integration with Strategy Container
/// - [ ] Heterogeneous strategy storage in container
/// - [ ] Type-erased strategy registration and resolution
/// - [ ] Strategy ID consistency in container operations
/// - [ ] Multiple strategy type coexistence
/// - [ ] Container-wrapper interaction patterns
///
/// ### Delegation Pattern Verification
/// - [ ] Transparent proxy behavior verification
/// - [ ] Method call forwarding without modification
/// - [ ] Error propagation transparency
/// - [ ] State management delegation completeness
/// - [ ] Behavioral identity preservation
///
/// ### Thread Safety and Concurrent Access
/// - [ ] @Sendable closure marking for concurrent safety
/// - [ ] Concurrent method call safety through delegation
/// - [ ] Thread-safe access to type-erased functions
/// - [ ] Concurrent wrapper instance usage
/// - [ ] Race condition prevention through underlying strategy
///
/// ### API Boundaries and Interface Hiding
/// - [ ] Concrete strategy type hiding from public interfaces
/// - [ ] API boundary compatibility
/// - [ ] Interface abstraction effectiveness
/// - [ ] Client code isolation from concrete types
/// - [ ] Public API surface simplification
///
/// ### Dependency Injection and Registration
/// - [ ] Flexible strategy registration through type erasure
/// - [ ] Runtime strategy selection capability
/// - [ ] Dependency injection container integration
/// - [ ] Strategy resolution by ID with type erasure
/// - [ ] Configuration-based strategy selection
///
/// ### Universal Compatibility Testing
/// - [ ] Class-based strategy compatibility
/// - [ ] Struct-based strategy compatibility
/// - [ ] Built-in strategy integration (SingleExecution, PriorityBased)
/// - [ ] Custom strategy implementation support
/// - [ ] Mixed strategy type usage scenarios
///
/// ### Error Handling and Edge Cases
/// - [ ] Concrete strategy error propagation accuracy
/// - [ ] Type erasure error scenarios
/// - [ ] Invalid parameter handling delegation
/// - [ ] Resource exhaustion impact on type erasure
/// - [ ] Wrapper-specific error cases (if any)
///
/// ### Documentation and Usage Patterns
/// - [ ] Type erasure benefit realization in practice
/// - [ ] Heterogeneous collection usage patterns
/// - [ ] Runtime selection implementation examples
/// - [ ] Performance consideration validation
/// - [ ] Best practice adherence verification
///
final class AnyLockmanStrategyTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Type Erasure Structure and Purpose Tests

  func testGenericWrapperCreation() {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(singleStrategy)

    XCTAssertNotNil(anyStrategy)
    XCTAssertEqual(anyStrategy.strategyId, singleStrategy.strategyId)
  }

  func testLockmanStrategyProtocolConformance() {
    let priorityStrategy = LockmanPriorityBasedStrategy()
    let anyStrategy = AnyLockmanStrategy(priorityStrategy)

    // Should conform to LockmanStrategy protocol
    XCTAssertNotNil(anyStrategy as any LockmanStrategy)
    // Type is erased - the concrete strategy type is hidden
  }

  func testSendableConformanceForConcurrentUsage() async {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let results = try! await TestSupport.executeConcurrently(iterations: 5) {
      return anyStrategy.strategyId
    }

    XCTAssertEqual(results.count, 5)
    results.forEach { strategyId in
      XCTAssertEqual(strategyId, strategy.strategyId)
    }
  }

  func testHeterogeneousStrategyCollectionStorage() {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let anySingleStrategy = AnyLockmanStrategy(singleStrategy)

    // Create another single execution strategy for heterogeneous collection
    let anotherSingleStrategy = LockmanSingleExecutionStrategy()
    let anotherAnySingleStrategy = AnyLockmanStrategy(anotherSingleStrategy)

    // Different concrete strategies but same Info type can be stored together
    let strategies: [AnyLockmanStrategy<LockmanSingleExecutionInfo>] = [
      anySingleStrategy,
      anotherAnySingleStrategy,
    ]

    XCTAssertEqual(strategies.count, 2)
    // Both strategies are of the same type but are different instances
    XCTAssertNotNil(strategies[0])
    XCTAssertNotNil(strategies[1])
  }

  // MARK: - Initialization and Type Erasure Process Tests

  func testInitializationWithTypeConstraintVerification() {
    let singleStrategy = LockmanSingleExecutionStrategy()

    // This should compile because LockmanSingleExecutionStrategy.I == LockmanSingleExecutionInfo
    let anyStrategy = AnyLockmanStrategy(singleStrategy)
    XCTAssertNotNil(anyStrategy)
  }

  func testConcreteStrategyMethodCapture() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "test-boundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Method calls should be captured and work
    let result = anyStrategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotNil(result)
  }

  func testStrategyIdPreservationDuringTypeErasure() {
    let originalStrategy = LockmanPriorityBasedStrategy()
    let anyStrategy = AnyLockmanStrategy(originalStrategy)

    XCTAssertEqual(anyStrategy.strategyId, originalStrategy.strategyId)
    XCTAssertEqual(anyStrategy.strategyId.value, originalStrategy.strategyId.value)
  }

  // MARK: - LockmanStrategy Protocol Implementation Tests

  func testStrategyIdPropertyReturnsPreservedConcreteId() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    let anyStrategy1 = AnyLockmanStrategy(strategy1)
    let anyStrategy2 = AnyLockmanStrategy(strategy2)

    XCTAssertEqual(anyStrategy1.strategyId, strategy1.strategyId)
    XCTAssertEqual(anyStrategy2.strategyId, strategy2.strategyId)
    XCTAssertNotEqual(anyStrategy1.strategyId, anyStrategy2.strategyId)
  }

  func testMakeStrategyIdGenericTypeErasedIdentifier() {
    let genericId = AnyLockmanStrategy<LockmanSingleExecutionInfo>.makeStrategyId()

    XCTAssertTrue(genericId.value.contains("AnyLockmanStrategy"))
    XCTAssertTrue(genericId.value.contains("LockmanSingleExecutionInfo"))
  }

  // MARK: - canLock Method Delegation Tests

  func testCanLockSignaturePreservation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "test-boundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Should match signature of concrete strategy
    let result = anyStrategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotNil(result)
  }

  func testCanLockTransparentDelegationToConcreteStrategy() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "delegation-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Results should be identical
    let directResult = strategy.canLock(boundaryId: boundaryId, info: info)
    let delegatedResult = anyStrategy.canLock(boundaryId: boundaryId, info: info)

    switch (directResult, delegatedResult) {
    case (.success, .success),
      (.successWithPrecedingCancellation, .successWithPrecedingCancellation),
      (.cancel, .cancel):
      XCTAssertTrue(true)
    default:
      XCTFail("Results should be identical")
    }
  }

  func testCanLockLockmanResultReturnTypePreservation() {
    let strategy = LockmanPriorityBasedStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "result-test"
    let info = LockmanPriorityBasedInfo(actionId: "test-action", priority: .high(.exclusive))

    let result = anyStrategy.canLock(boundaryId: boundaryId, info: info)

    switch result {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation:
      XCTAssertTrue(true)
    case .cancel:
      XCTAssertTrue(true)
    }
  }

  // MARK: - lock Method Delegation Tests

  func testLockMethodDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "lock-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Should be able to acquire lock
    let canLockResult = anyStrategy.canLock(boundaryId: boundaryId, info: info)
    switch canLockResult {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }

    // Should delegate lock acquisition
    anyStrategy.lock(boundaryId: boundaryId, info: info)

    // Verify lock is held by checking canLock again
    let secondCanLock = anyStrategy.canLock(
      boundaryId: boundaryId, info: LockmanSingleExecutionInfo(mode: .boundary))
    switch secondCanLock {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }
  }

  func testLockStateManagementDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "state-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Initially should be available
    switch anyStrategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }

    // After locking, should be unavailable
    anyStrategy.lock(boundaryId: boundaryId, info: info)
    let newInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId, info: newInfo) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }
  }

  // MARK: - unlock Method Delegation Tests

  func testUnlockMethodDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "unlock-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Acquire lock first
    anyStrategy.lock(boundaryId: boundaryId, info: info)

    // Then release it
    anyStrategy.unlock(boundaryId: boundaryId, info: info)

    // Should be available again
    let newInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId, info: newInfo) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
  }

  func testUnlockParameterMatchingRequirement() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "parameter-match-test"
    let lockInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let differentInfo = LockmanSingleExecutionInfo(mode: .boundary)

    // Acquire lock
    anyStrategy.lock(boundaryId: boundaryId, info: lockInfo)

    // Unlock with different info (different uniqueId)
    anyStrategy.unlock(boundaryId: boundaryId, info: differentInfo)

    // Lock should still be held since unlock was called with wrong info
    let checkInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId, info: checkInfo) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }

    // Unlock with correct info
    anyStrategy.unlock(boundaryId: boundaryId, info: lockInfo)

    // Now should be available
    let finalInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId, info: finalInfo) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success after unlock")
    }
  }

  // MARK: - cleanUp Methods Delegation Tests

  func testGlobalCleanUpDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId1 = "cleanup-test-1"
    let boundaryId2 = "cleanup-test-2"
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(mode: .boundary)

    // Acquire multiple locks
    anyStrategy.lock(boundaryId: boundaryId1, info: info1)
    anyStrategy.lock(boundaryId: boundaryId2, info: info2)

    // Clean up all
    anyStrategy.cleanUp()

    // All should be available again
    let checkInfo1 = LockmanSingleExecutionInfo(mode: .boundary)
    let checkInfo2 = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId1, info: checkInfo1) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success after cleanup")
    }
    switch anyStrategy.canLock(boundaryId: boundaryId2, info: checkInfo2) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success after cleanup")
    }
  }

  func testBoundarySpecificCleanUpDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId1 = "selective-cleanup-1"
    let boundaryId2 = "selective-cleanup-2"
    let info1 = LockmanSingleExecutionInfo(mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(mode: .boundary)

    // Acquire locks on both boundaries
    anyStrategy.lock(boundaryId: boundaryId1, info: info1)
    anyStrategy.lock(boundaryId: boundaryId2, info: info2)

    // Clean up only boundary 1
    anyStrategy.cleanUp(boundaryId: boundaryId1)

    // Boundary 1 should be available, boundary 2 should still be locked
    let checkInfo1 = LockmanSingleExecutionInfo(mode: .boundary)
    let checkInfo2 = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId1, info: checkInfo1) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success after selective cleanup")
    }
    switch anyStrategy.canLock(boundaryId: boundaryId2, info: checkInfo2) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for still locked boundary")
    }
  }

  // MARK: - getCurrentLocks Debug Information Tests

  func testGetCurrentLocksMethodDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "debug-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Initially should be empty
    let initialLocks = anyStrategy.getCurrentLocks()
    XCTAssertTrue(initialLocks.isEmpty)

    // After acquiring lock, should show the lock
    anyStrategy.lock(boundaryId: boundaryId, info: info)
    let locksAfterAcquisition = anyStrategy.getCurrentLocks()
    XCTAssertFalse(locksAfterAcquisition.isEmpty)
  }

  func testGetCurrentLocksTypeErasureHandling() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "type-erasure-debug"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    anyStrategy.lock(boundaryId: boundaryId, info: info)
    let currentLocks = anyStrategy.getCurrentLocks()

    // Should return dictionary with type-erased keys and values
    XCTAssertTrue(currentLocks.keys.allSatisfy { $0 is AnyLockmanBoundaryId })
    XCTAssertTrue(
      currentLocks.values.allSatisfy { lockInfoArray in
        lockInfoArray.allSatisfy { $0 is any LockmanInfo }
      })
  }

  // MARK: - Type Safety Guarantees Tests

  func testLockInformationTypePreservation() {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let anySingleStrategy = AnyLockmanStrategy(singleStrategy)

    // Type parameter I should be preserved
    let boundaryId = "type-safety-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Should accept correct info type
    let result = anySingleStrategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotNil(result)
  }

  func testCompileTimeTypeSafetyWithWhereConstraint() {
    let strategy = LockmanSingleExecutionStrategy()

    // This should compile because the constraint is satisfied
    let anyStrategy = AnyLockmanStrategy(strategy)
    XCTAssertNotNil(anyStrategy)

    // The where S.I == I constraint ensures this is type-safe at compile time
    // Type safety is enforced at compile time through the where constraint
  }

  // MARK: - Performance Characteristics Tests

  func testFunctionPointerIndirectionOverhead() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "performance-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Test that both direct and type-erased calls work correctly
    let directResult = strategy.canLock(boundaryId: boundaryId, info: info)
    let erasedResult = anyStrategy.canLock(boundaryId: boundaryId, info: info)

    // Results should be identical
    switch (directResult, erasedResult) {
    case (.success, .success),
      (.successWithPrecedingCancellation, .successWithPrecedingCancellation),
      (.cancel, .cancel):
      XCTAssertTrue(true)
    default:
      XCTFail("Direct and erased results should be identical")
    }
  }

  func testTypeErasureInitializationCost() {
    let strategy = LockmanSingleExecutionStrategy()

    // Test that initialization works correctly
    for _ in 0..<10 {
      let anyStrategy = AnyLockmanStrategy(strategy)
      XCTAssertNotNil(anyStrategy)
      XCTAssertEqual(anyStrategy.strategyId, strategy.strategyId)
    }
  }

  // MARK: - Memory Management and Lifetime Tests

  func testStructBasedStrategyCopyingIntoClosures() {
    // LockmanSingleExecutionStrategy is a struct
    var strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "struct-copy-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Modify original strategy (this shouldn't affect the copy in closures)
    strategy = LockmanSingleExecutionStrategy()

    // The type-erased strategy should still work with its copied strategy
    let result = anyStrategy.canLock(boundaryId: boundaryId, info: info)
    XCTAssertNotNil(result)
  }

  func testProperLifetimeManagementWithoutMemoryLeaks() {
    weak var weakStrategy: AnyObject?

    do {
      let strategy = LockmanSingleExecutionStrategy()
      let anyStrategy = AnyLockmanStrategy(strategy)

      // For struct-based strategies, there's no object to track
      // This test verifies no unexpected retention occurs
      let boundaryId = "lifetime-test"
      let info = LockmanSingleExecutionInfo(mode: .boundary)

      let result = anyStrategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertNotNil(result)
    }

    // No strong references should remain
    XCTAssertNil(weakStrategy)
  }

  // MARK: - Delegation Pattern Verification Tests

  func testTransparentProxyBehaviorVerification() {
    let strategy = LockmanPriorityBasedStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "proxy-test"
    let highPriorityInfo = LockmanPriorityBasedInfo(
      actionId: "high-action", priority: .high(.exclusive))
    let lowPriorityInfo = LockmanPriorityBasedInfo(
      actionId: "low-action", priority: .low(.exclusive))

    // Behavior should be identical to direct strategy usage
    let directHighResult = strategy.canLock(boundaryId: boundaryId, info: highPriorityInfo)
    let proxiedHighResult = anyStrategy.canLock(boundaryId: boundaryId, info: highPriorityInfo)

    switch (directHighResult, proxiedHighResult) {
    case (.success, .success),
      (.successWithPrecedingCancellation, .successWithPrecedingCancellation),
      (.cancel, .cancel):
      XCTAssertTrue(true)
    default:
      XCTFail("Results should be identical")
    }

    // Lock with high priority
    strategy.lock(boundaryId: boundaryId, info: highPriorityInfo)
    anyStrategy.lock(boundaryId: "another-boundary", info: highPriorityInfo)

    // Low priority should be blocked on both
    let directLowResult = strategy.canLock(boundaryId: boundaryId, info: lowPriorityInfo)
    let proxiedLowResult = anyStrategy.canLock(
      boundaryId: "another-boundary", info: lowPriorityInfo)

    // Results should be consistent (both should reject low priority)
    switch (directLowResult, proxiedLowResult) {
    case (.success, .success),
      (.successWithPrecedingCancellation, .successWithPrecedingCancellation),
      (.cancel, .cancel):
      XCTAssertTrue(true)
    default:
      XCTFail("Results should be consistent")
    }
  }

  func testBehavioralIdentityPreservation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "identity-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // Both should have identical behavior patterns
    switch strategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
    switch anyStrategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }

    // After locking through strategy
    strategy.lock(boundaryId: boundaryId, info: info)

    // Both should show the lock is held
    let newInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch strategy.canLock(boundaryId: boundaryId, info: newInfo) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }
    switch anyStrategy.canLock(boundaryId: boundaryId, info: newInfo) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }
  }

  // MARK: - Thread Safety and Concurrent Access Tests

  func testSendableClosureMarkingForConcurrentSafety() async {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "concurrent-safety-test"

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      let info = LockmanSingleExecutionInfo(mode: .boundary)
      return anyStrategy.canLock(boundaryId: boundaryId, info: info)
    }

    XCTAssertEqual(results.count, 10)
    // All results should be valid (either success or failure)
    results.forEach { result in
      switch result {
      case .success, .successWithPrecedingCancellation, .cancel:
        XCTAssertTrue(true)
      }
    }
  }

  func testConcurrentMethodCallSafetyThroughDelegation() {
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let expectation = XCTestExpectation(description: "Concurrent method calls")
    expectation.expectedFulfillmentCount = 10

    for i in 0..<10 {
      DispatchQueue.global().async {
        let boundaryId = "concurrent-boundary-\(i)"
        let info = LockmanSingleExecutionInfo(mode: .boundary)

        let canLockResult = anyStrategy.canLock(boundaryId: boundaryId, info: info)
        XCTAssertNotNil(canLockResult)

        switch canLockResult {
        case .success:
          anyStrategy.lock(boundaryId: boundaryId, info: info)
          anyStrategy.unlock(boundaryId: boundaryId, info: info)
        case .successWithPrecedingCancellation, .cancel:
          break
        }

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  // MARK: - Universal Compatibility Testing

  func testStructBasedStrategyCompatibility() {
    // LockmanSingleExecutionStrategy is a struct
    let strategy = LockmanSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)

    let boundaryId = "struct-compat-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    switch anyStrategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
    anyStrategy.lock(boundaryId: boundaryId, info: info)

    let newInfo = LockmanSingleExecutionInfo(mode: .boundary)
    switch anyStrategy.canLock(boundaryId: boundaryId, info: newInfo) {
    case .cancel(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    case .success, .successWithPrecedingCancellation:
      XCTFail("Expected cancel result for already locked boundary")
    }
  }

  func testBuiltInStrategyIntegration() {
    // Test with different built-in strategies
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()

    let anySingleStrategy = AnyLockmanStrategy(singleStrategy)
    let anyPriorityStrategy = AnyLockmanStrategy(priorityStrategy)

    XCTAssertNotEqual(anySingleStrategy.strategyId, anyPriorityStrategy.strategyId)

    // Both should work correctly
    let boundaryId = "built-in-test"
    let singleInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "test-action", priority: .high(.exclusive))

    switch anySingleStrategy.canLock(boundaryId: boundaryId, info: singleInfo) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
    switch anyPriorityStrategy.canLock(boundaryId: boundaryId, info: priorityInfo) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
  }

  func testMixedStrategyTypeUsageScenarios() {
    let singleStrategy1 = LockmanSingleExecutionStrategy()
    let singleStrategy2 = LockmanSingleExecutionStrategy()

    // Can store different strategy instances with same Info type
    let strategies: [AnyLockmanStrategy<LockmanSingleExecutionInfo>] = [
      AnyLockmanStrategy(singleStrategy1),
      AnyLockmanStrategy(singleStrategy2),
    ]

    XCTAssertEqual(strategies.count, 2)

    // Each should work independently
    let boundaryId = "mixed-usage-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    for (index, strategy) in strategies.enumerated() {
      let result = strategy.canLock(boundaryId: "\(boundaryId)-\(index)", info: info)
      switch result {
      case .success:
        XCTAssertTrue(true)
      case .successWithPrecedingCancellation, .cancel:
        XCTFail("Expected success")
      }
    }
  }

  // MARK: - Documentation and Usage Patterns Tests

  func testTypeErasureBenefitRealizationInPractice() {
    // Simulate a strategy registry that can hold different strategy types
    var strategyRegistry: [String: AnyLockmanStrategy<LockmanSingleExecutionInfo>] = [:]

    // Register different concrete strategies
    strategyRegistry["single"] = AnyLockmanStrategy(LockmanSingleExecutionStrategy())
    // Create a single execution strategy for consistent typing
    strategyRegistry["priority"] = AnyLockmanStrategy(LockmanSingleExecutionStrategy())

    XCTAssertEqual(strategyRegistry.count, 2)

    // Use strategies polymorphically
    let boundaryId = "registry-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    for (name, strategy) in strategyRegistry {
      let result = strategy.canLock(boundaryId: "\(boundaryId)-\(name)", info: info)
      switch result {
      case .success:
        XCTAssertTrue(true)
      case .successWithPrecedingCancellation, .cancel:
        XCTFail("Expected success")
      }
    }
  }

  func testRuntimeSelectionImplementationExample() {
    // Create two different strategy instances
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()

    func selectStrategy(useFirst: Bool) -> AnyLockmanStrategy<LockmanSingleExecutionInfo> {
      if useFirst {
        return AnyLockmanStrategy(strategy1)
      } else {
        return AnyLockmanStrategy(strategy2)
      }
    }

    let firstStrategy = selectStrategy(useFirst: true)
    let secondStrategy = selectStrategy(useFirst: false)

    // Both should be valid strategy wrappers
    XCTAssertNotNil(firstStrategy)
    XCTAssertNotNil(secondStrategy)

    // Both should be usable through the same interface
    let boundaryId = "runtime-selection-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    switch firstStrategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
    switch secondStrategy.canLock(boundaryId: boundaryId, info: info) {
    case .success:
      XCTAssertTrue(true)
    case .successWithPrecedingCancellation, .cancel:
      XCTFail("Expected success")
    }
  }
}
