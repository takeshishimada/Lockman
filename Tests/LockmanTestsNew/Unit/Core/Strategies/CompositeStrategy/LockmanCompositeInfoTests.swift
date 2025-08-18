import XCTest

@testable import Lockman

/// Unit tests for LockmanCompositeInfo
///
/// Tests the information structures for composite locking behavior with 2-5 strategies.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### LockmanCompositeInfo2 Testing
/// - [ ] Protocol conformance (LockmanInfo, Sendable)
/// - [ ] Generic type constraints (I1: LockmanInfo, I2: LockmanInfo)
/// - [ ] Initialization with custom and default strategyId
/// - [ ] Property validation (strategyId, actionId, uniqueId)
/// - [ ] lockmanInfoForStrategy1 and lockmanInfoForStrategy2 handling
/// - [ ] debugDescription format with nested info representations
/// - [ ] debugAdditionalInfo "Composite" value
///
/// ### LockmanCompositeInfo3 Testing
/// - [ ] Protocol conformance with 3 generic constraints
/// - [ ] Three-strategy info coordination
/// - [ ] Default strategyId "Lockman.CompositeStrategy3"
/// - [ ] All three lockmanInfoForStrategy properties
/// - [ ] debugDescription with 3 nested info objects
/// - [ ] Property immutability after initialization
///
/// ### LockmanCompositeInfo4 Testing
/// - [ ] Protocol conformance with 4 generic constraints
/// - [ ] Four-strategy info coordination
/// - [ ] Default strategyId "Lockman.CompositeStrategy4"
/// - [ ] All four lockmanInfoForStrategy properties
/// - [ ] debugDescription with 4 nested info objects
/// - [ ] Complex generic type parameter handling
///
/// ### LockmanCompositeInfo5 Testing
/// - [ ] Protocol conformance with 5 generic constraints
/// - [ ] Five-strategy info coordination (maximum supported)
/// - [ ] Default strategyId "Lockman.CompositeStrategy5"
/// - [ ] All five lockmanInfoForStrategy properties
/// - [ ] debugDescription with 5 nested info objects
/// - [ ] Maximum complexity generic handling
///
/// ### Generic Type System Testing
/// - [ ] Type constraints validation (I1-I5: LockmanInfo)
/// - [ ] Generic type parameter compilation
/// - [ ] Type safety across all info variants
/// - [ ] Mixed strategy type combinations
/// - [ ] Type erasure compatibility
/// - [ ] Generic type inference behavior
///
/// ### Initialization Patterns
/// - [ ] User-specified actionId requirement
/// - [ ] Default strategyId behavior per variant
/// - [ ] Custom strategyId override behavior
/// - [ ] uniqueId automatic generation per instance
/// - [ ] Nested info immutability preservation
/// - [ ] Parameter validation and type checking
///
/// ### Debug Support & Representation
/// - [ ] debugDescription format consistency across variants
/// - [ ] Nested info debugDescription inclusion
/// - [ ] debugAdditionalInfo uniformity ("Composite")
/// - [ ] Long debug string handling with multiple nested infos
/// - [ ] Debug string readability with complex nested structures
///
/// ### Thread Safety & Sendable
/// - [ ] Sendable compliance across all variants
/// - [ ] Immutable properties after initialization
/// - [ ] Safe concurrent access to nested info objects
/// - [ ] Thread-safe UUID generation
/// - [ ] Nested info Sendable requirement enforcement
///
/// ### Protocol Conformance Validation
/// - [ ] LockmanInfo protocol implementation across variants
/// - [ ] CustomDebugStringConvertible implementation
/// - [ ] Protocol requirement fulfillment
/// - [ ] Consistent protocol behavior across 2-5 variants
/// - [ ] Protocol inheritance validation
///
/// ### Integration with Composite Strategy
/// - [ ] Strategy container registration compatibility
/// - [ ] Multi-strategy coordination behavior
/// - [ ] Strategy info distribution to sub-strategies
/// - [ ] Conflict detection across multiple strategies
/// - [ ] Error propagation from sub-strategies
/// - [ ] Lock acquisition coordination
///
/// ### Real-world Composite Scenarios
/// - [ ] SingleExecution + PriorityBased combination
/// - [ ] Complex multi-strategy authentication flow
/// - [ ] Resource coordination across strategy types
/// - [ ] Cross-strategy conflict resolution
/// - [ ] Multi-layered operation coordination
///
/// ### Performance & Memory
/// - [ ] Initialization performance with nested infos
/// - [ ] Memory footprint with multiple strategy infos
/// - [ ] Debug string generation performance
/// - [ ] Generic type dispatch performance
/// - [ ] Large-scale composite info creation
///
/// ### Edge Cases & Error Conditions
/// - [ ] Empty actionId handling
/// - [ ] Very long actionId strings
/// - [ ] Special characters in actionId
/// - [ ] UUID collision probability (theoretical)
/// - [ ] Memory pressure with large nested structures
/// - [ ] Extreme composite nesting scenarios
///
/// ### Boundary and ActionId Coordination
/// - [ ] ActionId consistency across nested infos
/// - [ ] Boundary coordination between strategies
/// - [ ] Cross-strategy action identification
/// - [ ] Composite action identity management
/// - [ ] Nested info actionId relationship validation
///
/// ### Documentation Examples Validation
/// - [ ] userLogin composite example validation
/// - [ ] SingleExecution + PriorityBased combination example
/// - [ ] Code example correctness verification
/// - [ ] Usage pattern validation from documentation
///
final class LockmanCompositeInfoTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - LockmanCompositeInfo2 Tests

  func testLockmanCompositeInfo2Initialization() {
    // Given
    let actionId = LockmanActionId("userLogin")
    let info1 = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .action
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .boundary
    )

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy2")
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.mode, .boundary)
  }

  func testLockmanCompositeInfo2CustomStrategyId() {
    // Given
    let customStrategyId = LockmanStrategyId("MyApp.CompositeStrategy")
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo2(
      strategyId: customStrategyId,
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertEqual(compositeInfo.strategyId, customStrategyId)
    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1, info1)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2, info2)
  }

  func testLockmanCompositeInfo2UniqueIdGeneration() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // When
    let compositeInfo1 = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    let compositeInfo2 = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertNotEqual(compositeInfo1.uniqueId, compositeInfo2.uniqueId)
  }

  func testLockmanCompositeInfo2DebugDescription() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // When
    let debugDescription = compositeInfo.debugDescription

    // Then
    XCTAssertTrue(debugDescription.contains("LockmanCompositeInfo2"))
    XCTAssertTrue(debugDescription.contains("strategyId: 'Lockman.CompositeStrategy2'"))
    XCTAssertTrue(debugDescription.contains("actionId: 'testAction'"))
    XCTAssertTrue(debugDescription.contains("uniqueId: \(compositeInfo.uniqueId)"))
    XCTAssertTrue(debugDescription.contains("info1:"))
    XCTAssertTrue(debugDescription.contains("info2:"))
  }

  func testLockmanCompositeInfo2DebugAdditionalInfo() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // When
    let debugAdditionalInfo = compositeInfo.debugAdditionalInfo

    // Then
    XCTAssertEqual(debugAdditionalInfo, "Composite")
  }

  func testLockmanCompositeInfo2ProtocolConformance() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then - Verify protocol conformance
    XCTAssertTrue(compositeInfo is any LockmanInfo)
    // Sendable conformance is compile-time checked, no runtime test needed
    XCTAssertTrue(compositeInfo is any CustomDebugStringConvertible)
  }

  // MARK: - LockmanCompositeInfo3 Tests

  func testLockmanCompositeInfo3Initialization() {
    // Given
    let actionId = LockmanActionId("complexOperation")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)

    // When
    let compositeInfo = LockmanCompositeInfo3(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy3")
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1, info1)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2, info2)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3, info3)
  }

  func testLockmanCompositeInfo3DebugDescription() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let compositeInfo = LockmanCompositeInfo3(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3
    )

    // When
    let debugDescription = compositeInfo.debugDescription

    // Then
    XCTAssertTrue(debugDescription.contains("LockmanCompositeInfo3"))
    XCTAssertTrue(debugDescription.contains("strategyId: 'Lockman.CompositeStrategy3'"))
    XCTAssertTrue(debugDescription.contains("info1:"))
    XCTAssertTrue(debugDescription.contains("info2:"))
    XCTAssertTrue(debugDescription.contains("info3:"))
  }

  // MARK: - LockmanCompositeInfo4 Tests

  func testLockmanCompositeInfo4Initialization() {
    // Given
    let actionId = LockmanActionId("veryComplexOperation")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let info4 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)

    // When
    let compositeInfo = LockmanCompositeInfo4(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy4")
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1, info1)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2, info2)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3, info3)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy4, info4)
  }

  func testLockmanCompositeInfo4DebugDescription() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let info4 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let compositeInfo = LockmanCompositeInfo4(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4
    )

    // When
    let debugDescription = compositeInfo.debugDescription

    // Then
    XCTAssertTrue(debugDescription.contains("LockmanCompositeInfo4"))
    XCTAssertTrue(debugDescription.contains("strategyId: 'Lockman.CompositeStrategy4'"))
    XCTAssertTrue(debugDescription.contains("info1:"))
    XCTAssertTrue(debugDescription.contains("info2:"))
    XCTAssertTrue(debugDescription.contains("info3:"))
    XCTAssertTrue(debugDescription.contains("info4:"))
  }

  // MARK: - LockmanCompositeInfo5 Tests

  func testLockmanCompositeInfo5Initialization() {
    // Given
    let actionId = LockmanActionId("maximumComplexOperation")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let info4 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info5 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo5(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4,
      lockmanInfoForStrategy5: info5
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.strategyId.value, "Lockman.CompositeStrategy5")
    XCTAssertNotNil(compositeInfo.uniqueId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1, info1)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2, info2)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy3, info3)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy4, info4)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy5, info5)
  }

  func testLockmanCompositeInfo5DebugDescription() {
    // Given
    let actionId = LockmanActionId("testAction")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let info4 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info5 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let compositeInfo = LockmanCompositeInfo5(
      actionId: actionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4,
      lockmanInfoForStrategy5: info5
    )

    // When
    let debugDescription = compositeInfo.debugDescription

    // Then
    XCTAssertTrue(debugDescription.contains("LockmanCompositeInfo5"))
    XCTAssertTrue(debugDescription.contains("strategyId: 'Lockman.CompositeStrategy5'"))
    XCTAssertTrue(debugDescription.contains("info1:"))
    XCTAssertTrue(debugDescription.contains("info2:"))
    XCTAssertTrue(debugDescription.contains("info3:"))
    XCTAssertTrue(debugDescription.contains("info4:"))
    XCTAssertTrue(debugDescription.contains("info5:"))
  }

  // MARK: - Thread Safety Tests

  func testCompositeInfoThreadSafety() {
    // Given
    let actionId = LockmanActionId("threadSafeTest")
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    let expectation = XCTestExpectation(description: "Thread safety test")
    expectation.expectedFulfillmentCount = 10
    var createdInfos:
      [LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanSingleExecutionInfo>] = []
    let lock = NSLock()

    // When - Create composite infos concurrently
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      let compositeInfo = LockmanCompositeInfo2(
        actionId: actionId,
        lockmanInfoForStrategy1: info1,
        lockmanInfoForStrategy2: info2
      )

      lock.lock()
      createdInfos.append(compositeInfo)
      lock.unlock()

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - All infos should have unique IDs
    let uniqueIds = Set(createdInfos.map { $0.uniqueId })
    XCTAssertEqual(uniqueIds.count, 10)
  }

  // MARK: - Generic Type System Tests

  func testMixedStrategyTypes() {
    // Given
    let actionId = LockmanActionId("mixedTypes")
    let singleInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)
    let concurrencyInfo = LockmanConcurrencyLimitedInfo(
      actionId: actionId,
      .limited(3)
    )

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: singleInfo,
      lockmanInfoForStrategy2: concurrencyInfo
    )

    // Then
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.limit, .limited(3))
  }

  // MARK: - Edge Cases Tests

  func testEmptyActionId() {
    // Given
    let emptyActionId = LockmanActionId("")
    let info1 = LockmanSingleExecutionInfo(actionId: emptyActionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: emptyActionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: emptyActionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, "")
    XCTAssertNotNil(compositeInfo.uniqueId)
  }

  func testVeryLongActionId() {
    // Given
    let longActionId = LockmanActionId(String(repeating: "a", count: 1000))
    let info1 = LockmanSingleExecutionInfo(actionId: longActionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: longActionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: longActionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, longActionId)
    XCTAssertEqual(compositeInfo.actionId.count, 1000)
  }

  func testSpecialCharactersInActionId() {
    // Given
    let specialActionId = LockmanActionId("action_with_!@#$%^&*()_+_special_chars_åäö_🚀")
    let info1 = LockmanSingleExecutionInfo(actionId: specialActionId, mode: .action)
    let info2 = LockmanSingleExecutionInfo(actionId: specialActionId, mode: .boundary)

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: specialActionId,
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, specialActionId)
    XCTAssertTrue(compositeInfo.debugDescription.contains("🚀"))
  }

  // MARK: - Integration Tests

  func testRealWorldCompositeScenario() {
    // Given - User login with single execution + priority based
    let actionId = LockmanActionId("userLogin")
    let singleExecutionInfo = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .action
    )

    // Create a mock priority-based info using SingleExecutionInfo as placeholder
    let priorityInfo = LockmanSingleExecutionInfo(
      strategyId: LockmanStrategyId("Lockman.PriorityBasedStrategy"),
      actionId: actionId,
      mode: .boundary
    )

    // When
    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: singleExecutionInfo,
      lockmanInfoForStrategy2: priorityInfo
    )

    // Then
    XCTAssertEqual(compositeInfo.actionId, "userLogin")
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.mode, .boundary)
    XCTAssertEqual(
      compositeInfo.lockmanInfoForStrategy2.strategyId.value, "Lockman.PriorityBasedStrategy")
  }
}
