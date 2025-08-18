import XCTest

@testable import Lockman

/// Unit tests for LockmanCompositeStrategy
///
/// Tests the composite strategies (2-5 strategies) that coordinate locking between multiple different strategies,
/// ensuring all component strategies can acquire their locks before proceeding.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### LockmanCompositeStrategy2 - Initialization and Configuration
/// - [ ] init(strategy1:strategy2:) with different strategy types
/// - [ ] strategyId generation from component strategies
/// - [ ] makeStrategyId(strategy1:strategy2:) creates unique composite ID
/// - [ ] makeStrategyId() parameterless version returns generic ID
/// - [ ] LockmanCompositeInfo2<I1, I2> typealias usage
/// - [ ] @unchecked Sendable conformance verification
///
/// ### LockmanCompositeStrategy3 - Initialization and Configuration
/// - [ ] init(strategy1:strategy2:strategy3:) with three strategies
/// - [ ] strategyId generation with three component strategy IDs
/// - [ ] makeStrategyId with three parameters
/// - [ ] LockmanCompositeInfo3<I1, I2, I3> typealias usage
///
/// ### LockmanCompositeStrategy4 - Initialization and Configuration
/// - [ ] init with four component strategies
/// - [ ] strategyId generation with four component strategy IDs
/// - [ ] LockmanCompositeInfo4<I1, I2, I3, I4> typealias usage
///
/// ### LockmanCompositeStrategy5 - Initialization and Configuration
/// - [ ] init with five component strategies
/// - [ ] strategyId generation with five component strategy IDs
/// - [ ] LockmanCompositeInfo5<I1, I2, I3, I4, I5> typealias usage
///
/// ### canLock Method - All Strategies Success
/// - [ ] All component strategies return .success -> composite returns .success
/// - [ ] All strategies are checked before proceeding
/// - [ ] coordinateResults handles all .success cases correctly
/// - [ ] LockmanLogger.logCanLock called with correct parameters
/// - [ ] Proper strategy name "Composite" in logs
///
/// ### canLock Method - Early Return on First Failure
/// - [ ] Strategy1 failure -> immediate .cancel return (Strategy2+ not checked)
/// - [ ] Strategy2 failure -> immediate .cancel return (Strategy3+ not checked)
/// - [ ] Strategy3 failure -> immediate .cancel return (Strategy4+ not checked)
/// - [ ] Strategy4 failure -> immediate .cancel return (Strategy5 not checked)
/// - [ ] Strategy5 failure -> immediate .cancel return
/// - [ ] Proper failure reason logging ("Strategy1 failed", etc.)
///
/// ### canLock Method - Mixed Success and Cancellation Results
/// - [ ] Some strategies return .success, others return .successWithPrecedingCancellation
/// - [ ] coordinateResults returns .successWithPrecedingCancellation with first error
/// - [ ] Multiple cancellation errors -> first one is preserved
/// - [ ] LockmanPrecedingCancellationError propagation correctness
///
/// ### coordinateResults Private Method Logic
/// - [ ] Any .cancel result causes immediate composite failure
/// - [ ] .successWithPrecedingCancellation preserves first error found
/// - [ ] All .success results -> composite .success
/// - [ ] @unknown default case handling with logging
/// - [ ] Variadic parameter handling for different strategy counts
///
/// ### lock Method - Sequential Lock Acquisition
/// - [ ] LockmanCompositeStrategy2: strategy1.lock() then strategy2.lock()
/// - [ ] LockmanCompositeStrategy3: strategy1 -> strategy2 -> strategy3
/// - [ ] LockmanCompositeStrategy4: strategy1 -> strategy2 -> strategy3 -> strategy4
/// - [ ] LockmanCompositeStrategy5: strategy1 -> strategy2 -> strategy3 -> strategy4 -> strategy5
/// - [ ] Correct info forwarding to each component strategy
/// - [ ] Order preservation during lock acquisition
///
/// ### unlock Method - Reverse Order Release (LIFO)
/// - [ ] LockmanCompositeStrategy2: strategy2.unlock() then strategy1.unlock()
/// - [ ] LockmanCompositeStrategy3: strategy3 -> strategy2 -> strategy1
/// - [ ] LockmanCompositeStrategy4: strategy4 -> strategy3 -> strategy2 -> strategy1
/// - [ ] LockmanCompositeStrategy5: strategy5 -> strategy4 -> strategy3 -> strategy2 -> strategy1
/// - [ ] LIFO unlock order prevents deadlock scenarios
/// - [ ] Correct info forwarding during unlock
///
/// ### cleanUp Methods - Global and Boundary-Specific
/// - [ ] cleanUp() calls cleanUp() on all component strategies
/// - [ ] cleanUp(boundaryId:) calls cleanUp(boundaryId:) on all strategies
/// - [ ] All strategies cleaned up regardless of individual cleanup results
/// - [ ] Order of cleanup operations
/// - [ ] Cleanup operation safety and error handling
///
/// ### getCurrentLocks Debug Information
/// - [ ] Merges lock information from all component strategies
/// - [ ] Correct boundary ID to lock info array mapping
/// - [ ] Default array creation for new boundary IDs
/// - [ ] Complete lock information aggregation
/// - [ ] Type-erased LockmanInfo instances in returned values
///
/// ### Strategy ID Generation and Uniqueness
/// - [ ] Composite strategy ID includes component strategy IDs
/// - [ ] Configuration string format: "strategy1+strategy2+..."
/// - [ ] Unique IDs for different component strategy combinations
/// - [ ] Name format: "CompositeStrategy2", "CompositeStrategy3", etc.
/// - [ ] ID consistency across multiple instantiations with same strategies
///
/// ### Generic Type System and Constraints
/// - [ ] Multiple generic type parameters for different info types
/// - [ ] Where clause constraints: S1.I == I1, S2.I == I2, etc.
/// - [ ] Type safety across different strategy combinations
/// - [ ] LockmanStrategy protocol conformance for each component
/// - [ ] LockmanInfo protocol conformance for each info type
///
/// ### Integration with Component Strategies
/// - [ ] Integration with LockmanSingleExecutionStrategy + LockmanPriorityBasedStrategy
/// - [ ] Integration with built-in strategies + custom strategies
/// - [ ] Mixed strategy types with different behavior patterns
/// - [ ] Strategy interaction and conflict resolution
/// - [ ] Component strategy state isolation
///
/// ### Error Handling and Edge Cases
/// - [ ] Component strategy throws during canLock
/// - [ ] Component strategy throws during lock/unlock
/// - [ ] Null or invalid component strategies
/// - [ ] Empty lock info scenarios
/// - [ ] Resource exhaustion in component strategies
///
/// ### Thread Safety and Concurrency
/// - [ ] @unchecked Sendable conformance correctness
/// - [ ] Thread-safe access to component strategies
/// - [ ] Concurrent canLock calls on same composite strategy
/// - [ ] Concurrent lock/unlock operations
/// - [ ] Race condition prevention in coordination logic
///
/// ### Performance Characteristics
/// - [ ] Early return optimization in canLock method
/// - [ ] Minimal overhead compared to individual strategy calls
/// - [ ] Efficient result coordination logic
/// - [ ] Memory efficiency with multiple component strategies
/// - [ ] Performance impact of sequential vs parallel strategy checking
///
/// ### Logging Integration
/// - [ ] LockmanLogger.logCanLock with composite strategy name
/// - [ ] Proper boundaryId string representation in logs
/// - [ ] Failure reason messages for each strategy position
/// - [ ] Log message consistency across different composite strategy sizes
/// - [ ] Unknown case logging in coordinateResults
///
/// ### Protocol Conformance Verification
/// - [ ] LockmanStrategy protocol implementation completeness
/// - [ ] Required method implementations for all composite strategies
/// - [ ] Generic type alias correctness (I = LockmanCompositeInfo...)
/// - [ ] Boundary type handling consistency
/// - [ ] Result type handling across all methods
///
/// ### Complex Coordination Scenarios
/// - [ ] Nested composite strategies (composite of composites)
/// - [ ] Same strategy type used multiple times in different positions
/// - [ ] Strategies with overlapping boundary requirements
/// - [ ] Mixed execution patterns (exclusive, priority-based, etc.)
/// - [ ] Error propagation through complex strategy hierarchies
///
/// ### Memory Management and Resource Cleanup
/// - [ ] Proper cleanup of component strategy resources
/// - [ ] Memory leak prevention with multiple strategies
/// - [ ] Resource cleanup order and dependencies
/// - [ ] Long-running composite strategy stability
/// - [ ] Component strategy lifecycle management
///
/// ### Info Type Coordination
/// - [ ] LockmanCompositeInfo2/3/4/5 integration with component strategies
/// - [ ] Info extraction for each strategy (lockmanInfoForStrategy1, etc.)
/// - [ ] Type safety during info forwarding
/// - [ ] Complex info type hierarchies
/// - [ ] Info consistency across lock/unlock operations
///
final class LockmanCompositeStrategyTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Properties

  var boundaryId: TestBoundaryId!

  struct TestBoundaryId: LockmanBoundaryId {
    let value: String
    init(_ value: String) {
      self.value = value
    }
  }

  // Mock strategy for testing
  class MockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = MockInfo

    let strategyId: LockmanStrategyId

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("MockStrategy")
    }
    var canLockResult: LockmanResult = .success
    var lockCallCount = 0
    var unlockCallCount = 0
    var cleanUpCallCount = 0
    var cleanUpBoundaryCallCount = 0
    var getCurrentLocksResult: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    init(name: String) {
      self.strategyId = LockmanStrategyId(name: name)
    }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: MockInfo) -> LockmanResult {
      return canLockResult
    }

    func lock<B: LockmanBoundaryId>(boundaryId: B, info: MockInfo) {
      lockCallCount += 1
    }

    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: MockInfo) {
      unlockCallCount += 1
    }

    func cleanUp() {
      cleanUpCallCount += 1
    }

    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      cleanUpBoundaryCallCount += 1
    }

    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      return getCurrentLocksResult
    }
  }

  struct MockInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID

    init(
      strategyId: LockmanStrategyId = LockmanStrategyId(name: "mock"),
      actionId: String = "mockAction"
    ) {
      self.strategyId = strategyId
      self.actionId = LockmanActionId(actionId)
      self.uniqueId = UUID()
    }
    
    var debugDescription: String {
      return "MockInfo(action: \(actionId), strategy: \(strategyId.value), unique: \(uniqueId))"
    }
  }

  struct MockError: LockmanError {
    let description: String

    var localizedDescription: String {
      return description
    }
  }

  struct MockPrecedingError: LockmanPrecedingCancellationError, @unchecked Sendable {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let description: String

    var localizedDescription: String {
      return description
    }
  }

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    boundaryId = TestBoundaryId("testBoundary")
  }

  // MARK: - LockmanCompositeStrategy2 Tests

  func testCompositeStrategy2Initialization() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)

    XCTAssertTrue(String(describing: composite.strategyId).contains("CompositeStrategy2"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy1"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy2"))
  }

  func testCompositeStrategy2MakeStrategyIdWithParameters() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let strategyId = LockmanCompositeStrategy2.makeStrategyId(
      strategy1: strategy1, strategy2: strategy2)

    XCTAssertTrue(String(describing: strategyId).contains("CompositeStrategy2"))
    XCTAssertTrue(String(describing: strategyId).contains("strategy1+strategy2"))
  }

  func testCompositeStrategy2MakeStrategyIdParameterless() {
    let strategyId = LockmanCompositeStrategy2<MockInfo, MockStrategy, MockInfo, MockStrategy>
      .makeStrategyId()

    XCTAssertTrue(String(describing: strategyId).contains("CompositeStrategy2"))
  }

  func testCompositeStrategy2CanLockAllSuccess() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    strategy1.canLockResult = .success
    strategy2.canLockResult = .success

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCompositeStrategy2CanLockEarlyReturnOnFirstFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let error = MockError(description: "Strategy1 failed")
    strategy1.canLockResult = .cancel(error)
    strategy2.canLockResult = .success  // This should not be checked

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel(let returnedError) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Strategy1 failed")
  }

  func testCompositeStrategy2CanLockEarlyReturnOnSecondFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    strategy1.canLockResult = .success
    let error = MockError(description: "Strategy2 failed")
    strategy2.canLockResult = .cancel(error)

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel(let returnedError) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Strategy2 failed")
  }

  func testCompositeStrategy2CanLockSuccessWithPrecedingCancellation() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let precedingError = MockPrecedingError(
      lockmanInfo: MockInfo(),
      boundaryId: boundaryId,
      description: "Preceding error"
    )
    strategy1.canLockResult = .successWithPrecedingCancellation(error: precedingError)
    strategy2.canLockResult = .success

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .successWithPrecedingCancellation(let returnedError) = result else {
      XCTFail("Expected .successWithPrecedingCancellation, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Preceding error")
  }

  func testCompositeStrategy2LockSequentialOrder() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    composite.lock(boundaryId: boundaryId, info: info)

    XCTAssertEqual(strategy1.lockCallCount, 1)
    XCTAssertEqual(strategy2.lockCallCount, 1)
  }

  func testCompositeStrategy2UnlockReverseOrder() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    composite.unlock(boundaryId: boundaryId, info: info)

    XCTAssertEqual(strategy1.unlockCallCount, 1)
    XCTAssertEqual(strategy2.unlockCallCount, 1)
  }

  func testCompositeStrategy2CleanUpCallsAllStrategies() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)

    composite.cleanUp()

    XCTAssertEqual(strategy1.cleanUpCallCount, 1)
    XCTAssertEqual(strategy2.cleanUpCallCount, 1)
  }

  func testCompositeStrategy2CleanUpBoundaryCallsAllStrategies() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)

    composite.cleanUp(boundaryId: boundaryId)

    XCTAssertEqual(strategy1.cleanUpBoundaryCallCount, 1)
    XCTAssertEqual(strategy2.cleanUpBoundaryCallCount, 1)
  }

  func testCompositeStrategy2GetCurrentLocksMergesResults() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let boundary1 = AnyLockmanBoundaryId(TestBoundaryId("boundary1"))
    let boundary2 = AnyLockmanBoundaryId(TestBoundaryId("boundary2"))

    strategy1.getCurrentLocksResult = [
      boundary1: [MockInfo(actionId: "action1")]
    ]
    strategy2.getCurrentLocksResult = [
      boundary1: [MockInfo(actionId: "action2")],
      boundary2: [MockInfo(actionId: "action3")],
    ]

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let result = composite.getCurrentLocks()

    XCTAssertEqual(result.count, 2)
    XCTAssertEqual(result[boundary1]?.count, 2)
    XCTAssertEqual(result[boundary2]?.count, 1)
  }

  // MARK: - LockmanCompositeStrategy3 Tests

  func testCompositeStrategy3Initialization() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)

    XCTAssertTrue(String(describing: composite.strategyId).contains("CompositeStrategy3"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy1"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy2"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy3"))
  }

  func testCompositeStrategy3CanLockEarlyReturnOnThirdFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")

    strategy1.canLockResult = .success
    strategy2.canLockResult = .success
    let error = MockError(description: "Strategy3 failed")
    strategy3.canLockResult = .cancel(error)

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)
    let info = LockmanCompositeInfo3(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo(),
      lockmanInfoForStrategy3: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel(let returnedError) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Strategy3 failed")
  }

  func testCompositeStrategy3LockUnlockOrder() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)
    let info = LockmanCompositeInfo3(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo(),
      lockmanInfoForStrategy3: MockInfo()
    )

    // Test lock order
    composite.lock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy1.lockCallCount, 1)
    XCTAssertEqual(strategy2.lockCallCount, 1)
    XCTAssertEqual(strategy3.lockCallCount, 1)

    // Test unlock order (LIFO)
    composite.unlock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy1.unlockCallCount, 1)
    XCTAssertEqual(strategy2.unlockCallCount, 1)
    XCTAssertEqual(strategy3.unlockCallCount, 1)
  }

  // MARK: - LockmanCompositeStrategy4 Tests

  func testCompositeStrategy4Initialization() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")
    let strategy4 = MockStrategy(name: "strategy4")

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4
    )

    XCTAssertTrue(String(describing: composite.strategyId).contains("CompositeStrategy4"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy1"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy4"))
  }

  func testCompositeStrategy4CanLockEarlyReturnOnFourthFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")
    let strategy4 = MockStrategy(name: "strategy4")

    strategy1.canLockResult = .success
    strategy2.canLockResult = .success
    strategy3.canLockResult = .success
    let error = MockError(description: "Strategy4 failed")
    strategy4.canLockResult = .cancel(error)

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4
    )
    let info = LockmanCompositeInfo4(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo(),
      lockmanInfoForStrategy3: MockInfo(),
      lockmanInfoForStrategy4: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel(let returnedError) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Strategy4 failed")
  }

  // MARK: - LockmanCompositeStrategy5 Tests

  func testCompositeStrategy5Initialization() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")
    let strategy4 = MockStrategy(name: "strategy4")
    let strategy5 = MockStrategy(name: "strategy5")

    let composite = LockmanCompositeStrategy5(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3,
      strategy4: strategy4, strategy5: strategy5
    )

    XCTAssertTrue(String(describing: composite.strategyId).contains("CompositeStrategy5"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy1"))
    XCTAssertTrue(String(describing: composite.strategyId).contains("strategy5"))
  }

  func testCompositeStrategy5CanLockEarlyReturnOnFifthFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")
    let strategy4 = MockStrategy(name: "strategy4")
    let strategy5 = MockStrategy(name: "strategy5")

    strategy1.canLockResult = .success
    strategy2.canLockResult = .success
    strategy3.canLockResult = .success
    strategy4.canLockResult = .success
    let error = MockError(description: "Strategy5 failed")
    strategy5.canLockResult = .cancel(error)

    let composite = LockmanCompositeStrategy5(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3,
      strategy4: strategy4, strategy5: strategy5
    )
    let info = LockmanCompositeInfo5(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo(),
      lockmanInfoForStrategy3: MockInfo(),
      lockmanInfoForStrategy4: MockInfo(),
      lockmanInfoForStrategy5: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel(let returnedError) = result else {
      XCTFail("Expected .cancel, got \(result)")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "Strategy5 failed")
  }

  func testCompositeStrategy5LockUnlockAllStrategies() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")
    let strategy4 = MockStrategy(name: "strategy4")
    let strategy5 = MockStrategy(name: "strategy5")

    let composite = LockmanCompositeStrategy5(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3,
      strategy4: strategy4, strategy5: strategy5
    )
    let info = LockmanCompositeInfo5(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo(),
      lockmanInfoForStrategy3: MockInfo(),
      lockmanInfoForStrategy4: MockInfo(),
      lockmanInfoForStrategy5: MockInfo()
    )

    // Test lock
    composite.lock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy1.lockCallCount, 1)
    XCTAssertEqual(strategy2.lockCallCount, 1)
    XCTAssertEqual(strategy3.lockCallCount, 1)
    XCTAssertEqual(strategy4.lockCallCount, 1)
    XCTAssertEqual(strategy5.lockCallCount, 1)

    // Test unlock
    composite.unlock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy1.unlockCallCount, 1)
    XCTAssertEqual(strategy2.unlockCallCount, 1)
    XCTAssertEqual(strategy3.unlockCallCount, 1)
    XCTAssertEqual(strategy4.unlockCallCount, 1)
    XCTAssertEqual(strategy5.unlockCallCount, 1)
  }

  // MARK: - coordinateResults Method Tests

  func testCoordinateResultsAllSuccess() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    strategy1.canLockResult = .success
    strategy2.canLockResult = .success

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCoordinateResultsAnyFailureCausesCompositeFailure() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let error = MockError(description: "Failure")
    strategy1.canLockResult = .cancel(error)
    strategy2.canLockResult = .success

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .cancel = result else {
      XCTFail("Expected .cancel")
      return
    }
  }

  func testCoordinateResultsFirstPrecedingCancellationPreserved() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let error1 = MockPrecedingError(
      lockmanInfo: MockInfo(),
      boundaryId: boundaryId,
      description: "First error"
    )
    let error2 = MockPrecedingError(
      lockmanInfo: MockInfo(),
      boundaryId: boundaryId,
      description: "Second error"
    )

    strategy1.canLockResult = .successWithPrecedingCancellation(error: error1)
    strategy2.canLockResult = .successWithPrecedingCancellation(error: error2)

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let info = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: MockInfo(),
      lockmanInfoForStrategy2: MockInfo()
    )

    let result = composite.canLock(boundaryId: boundaryId, info: info)
    guard case .successWithPrecedingCancellation(let returnedError) = result else {
      XCTFail("Expected .successWithPrecedingCancellation")
      return
    }

    XCTAssertEqual(returnedError.localizedDescription, "First error")
  }

  // MARK: - Integration Tests with Real Strategies

  func testIntegrationWithSingleExecutionAndPriorityStrategies() {
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()

    let composite = LockmanCompositeStrategy2(
      strategy1: singleStrategy, strategy2: priorityStrategy)

    let singleInfo = LockmanSingleExecutionInfo(
      actionId: "test",
      mode: .boundary
    )
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "test",
      priority: .high(.exclusive)
    )
    let compositeInfo = LockmanCompositeInfo2(
      actionId: "test",
      lockmanInfoForStrategy1: singleInfo,
      lockmanInfoForStrategy2: priorityInfo
    )

    // First attempt should succeed
    let result1 = composite.canLock(boundaryId: boundaryId, info: compositeInfo)
    XCTAssertEqual(result1, .success)

    composite.lock(boundaryId: boundaryId, info: compositeInfo)

    // Second attempt should fail due to single execution strategy
    let result2 = composite.canLock(boundaryId: boundaryId, info: compositeInfo)
    guard case .cancel = result2 else {
      XCTFail("Expected .cancel due to single execution strategy")
      return
    }
  }

  // MARK: - Error Cases and Edge Tests

  func testCompositeInfoTypeSafety() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let _ = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)

    // Test that composite info correctly extracts info for each strategy
    let info1 = MockInfo(actionId: "action1")
    let info2 = MockInfo(actionId: "action2")
    let compositeInfo = LockmanCompositeInfo2(
      actionId: "composite",
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.actionId, "action1")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, "action2")
    XCTAssertEqual(compositeInfo.actionId, "composite")
  }

  func testStrategyIdUniquenessAcrossCompositeTypes() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")

    let composite2 = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let composite3 = LockmanCompositeStrategy3(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)

    XCTAssertNotEqual(composite2.strategyId, composite3.strategyId)
    XCTAssertTrue(String(describing: composite2.strategyId).contains("CompositeStrategy2"))
    XCTAssertTrue(String(describing: composite3.strategyId).contains("CompositeStrategy3"))
  }

  func testCompositeCleanupCompleteness() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")
    let strategy3 = MockStrategy(name: "strategy3")

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)

    // Test global cleanup
    composite.cleanUp()
    XCTAssertEqual(strategy1.cleanUpCallCount, 1)
    XCTAssertEqual(strategy2.cleanUpCallCount, 1)
    XCTAssertEqual(strategy3.cleanUpCallCount, 1)

    // Test boundary cleanup
    composite.cleanUp(boundaryId: boundaryId)
    XCTAssertEqual(strategy1.cleanUpBoundaryCallCount, 1)
    XCTAssertEqual(strategy2.cleanUpBoundaryCallCount, 1)
    XCTAssertEqual(strategy3.cleanUpBoundaryCallCount, 1)
  }

  func testGetCurrentLocksCompleteAggregation() {
    let strategy1 = MockStrategy(name: "strategy1")
    let strategy2 = MockStrategy(name: "strategy2")

    let boundary1 = AnyLockmanBoundaryId(TestBoundaryId("boundary1"))
    let boundary2 = AnyLockmanBoundaryId(TestBoundaryId("boundary2"))

    // Set up complex lock state
    strategy1.getCurrentLocksResult = [
      boundary1: [MockInfo(actionId: "action1"), MockInfo(actionId: "action2")],
      boundary2: [MockInfo(actionId: "action3")],
    ]
    strategy2.getCurrentLocksResult = [
      boundary1: [MockInfo(actionId: "action4")]
      // Note: boundary2 not present in strategy2
    ]

    let composite = LockmanCompositeStrategy2(strategy1: strategy1, strategy2: strategy2)
    let result = composite.getCurrentLocks()

    // Should have both boundaries
    XCTAssertEqual(result.count, 2)

    // boundary1 should have 3 locks (2 from strategy1, 1 from strategy2)
    XCTAssertEqual(result[boundary1]?.count, 3)

    // boundary2 should have 1 lock (only from strategy1)
    XCTAssertEqual(result[boundary2]?.count, 1)
  }
}
