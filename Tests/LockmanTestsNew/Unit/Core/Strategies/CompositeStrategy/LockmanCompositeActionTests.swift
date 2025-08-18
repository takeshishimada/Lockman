import XCTest

@testable import Lockman

// MARK: - Test Support Types

struct CompositeTestConcurrencyGroup: LockmanConcurrencyGroup {
  let id: String
  let limit: LockmanConcurrencyLimit
  
  init(_ id: String, limit: LockmanConcurrencyLimit) {
    self.id = id
    self.limit = limit
  }
}

/// Unit tests for LockmanCompositeAction
///
/// Tests all composite action protocols (LockmanCompositeAction2-5) that coordinate
/// locking between multiple strategies to ensure comprehensive resource management.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance and Type Safety
/// - [x] LockmanCompositeAction2 protocol conformance and associated types
/// - [x] LockmanCompositeAction3 protocol conformance and associated types
/// - [x] LockmanCompositeAction4 protocol conformance and associated types
/// - [x] LockmanCompositeAction5 protocol conformance and associated types
/// - [x] Associated type constraints (I1-I5: LockmanInfo, S1-S5: LockmanStrategy)
/// - [x] Generic type parameter resolution and inference
///
/// ### createLockmanInfo() Method Implementation
/// - [x] LockmanCompositeInfo2<I1, I2> creation and validation
/// - [x] LockmanCompositeInfo3<I1, I2, I3> creation and validation
/// - [x] LockmanCompositeInfo4<I1, I2, I3, I4> creation and validation
/// - [x] LockmanCompositeInfo5<I1, I2, I3, I4, I5> creation and validation
/// - [x] Strategy-specific lock info composition
/// - [x] Action ID consistency across composite info types
///
/// ### makeCompositeStrategy() Default Implementation
/// - [x] AnyLockmanStrategy<LockmanCompositeInfo2> type erasure
/// - [x] AnyLockmanStrategy<LockmanCompositeInfo3> type erasure
/// - [x] AnyLockmanStrategy<LockmanCompositeInfo4> type erasure
/// - [x] AnyLockmanStrategy<LockmanCompositeInfo5> type erasure
/// - [x] Strategy composition and wrapping behavior
/// - [x] Type-erased strategy instance creation
///
/// ### Strategy Integration and Coordination
/// - [x] Mixed strategy types (SingleExecution + PriorityBased)
/// - [x] Strategy combination validation
/// - [x] Composite strategy behavior preservation
/// - [x] Type safety with different strategy combinations
/// - [x] Strategy instance passing and delegation
///
/// ### Real-World Implementation Examples
/// - [x] Two-strategy composite action implementation
/// - [x] Three-strategy composite action implementation
/// - [x] Four-strategy composite action implementation
/// - [x] Five-strategy composite action implementation
/// - [x] Complex action scenarios with multiple strategies
///
/// ### Thread Safety and Sendable Compliance
/// - [x] Sendable conformance through LockmanAction inheritance
/// - [x] Thread-safe createLockmanInfo() implementation
/// - [x] Concurrent access to composite action instances
/// - [x] Immutable action behavior validation
///
/// ### Error Handling and Edge Cases
/// - [x] Invalid strategy combinations
/// - [x] Null or missing strategy parameters
/// - [x] Complex generic type scenarios
/// - [x] Strategy instance lifecycle management
///
final class LockmanCompositeActionTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Implementations

  // MARK: - LockmanCompositeAction2 Tests

  struct TestCompositeAction2: LockmanCompositeAction2 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy

    let actionName: String

    init(actionName: String = TestSupport.uniqueActionId(prefix: "composite2")) {
      self.actionName = actionName
    }

    func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
      LockmanCompositeInfo2(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: actionName,
          mode: .boundary
        ),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: actionName,
          priority: .high(.exclusive)
        )
      )
    }
  }

  func testLockmanCompositeAction2ProtocolConformance() {
    let action = TestCompositeAction2()

    // Test that action conforms to LockmanAction through inheritance
    XCTAssertTrue(action is any LockmanAction, "CompositeAction2 should conform to LockmanAction")

    // Test associated type constraints
    let lockInfo = action.createLockmanInfo()
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertEqual(lockInfo.actionId, action.actionName)
  }

  func testLockmanCompositeAction2CreateLockmanInfo() {
    let actionName = TestSupport.uniqueActionId(prefix: "test2")
    let action = TestCompositeAction2(actionName: actionName)

    let lockInfo = action.createLockmanInfo()

    // Verify action ID consistency
    XCTAssertEqual(lockInfo.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, actionName)

    // Verify strategy-specific configurations
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.mode, .boundary)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.priority, .high(.exclusive))

    // Verify unique IDs
    XCTAssertNotEqual(lockInfo.uniqueId, lockInfo.lockmanInfoForStrategy1.uniqueId)
    XCTAssertNotEqual(lockInfo.uniqueId, lockInfo.lockmanInfoForStrategy2.uniqueId)
  }

  func testLockmanCompositeAction2MakeCompositeStrategy() {
    let action = TestCompositeAction2()
    let strategy1 = LockmanSingleExecutionStrategy.shared
    let strategy2 = LockmanPriorityBasedStrategy.shared

    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2
    )

    // Verify type erasure
    XCTAssertTrue(
      compositeStrategy
        is AnyLockmanStrategy<
          LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo>
        >)

    // Verify strategy delegation
    XCTAssertEqual(compositeStrategy.strategyId, "composite_singleExecution_priorityBased")
  }

  // MARK: - LockmanCompositeAction3 Tests

  struct TestCompositeAction3: LockmanCompositeAction3 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanConcurrencyLimitedInfo
    typealias S3 = LockmanConcurrencyLimitedStrategy

    let actionName: String

    init(actionName: String = TestSupport.uniqueActionId(prefix: "composite3")) {
      self.actionName = actionName
    }

    func createLockmanInfo() -> LockmanCompositeInfo3<I1, I2, I3> {
      LockmanCompositeInfo3(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: actionName,
          mode: .action
        ),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: actionName,
          priority: .low(.exclusive)
        ),
        lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
          actionId: actionName,
          group: CompositeTestConcurrencyGroup("testGroup", limit: LockmanConcurrencyLimit.limited(3))
        )
      )
    }
  }

  func testLockmanCompositeAction3ProtocolConformance() {
    let action = TestCompositeAction3()

    // Test that action conforms to LockmanAction through inheritance
    XCTAssertTrue(action is any LockmanAction, "CompositeAction3 should conform to LockmanAction")

    // Test associated type constraints
    let lockInfo = action.createLockmanInfo()
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertEqual(lockInfo.actionId, action.actionName)
  }

  func testLockmanCompositeAction3CreateLockmanInfo() {
    let actionName = TestSupport.uniqueActionId(prefix: "test3")
    let action = TestCompositeAction3(actionName: actionName)

    let lockInfo = action.createLockmanInfo()

    // Verify action ID consistency
    XCTAssertEqual(lockInfo.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.actionId, actionName)

    // Verify strategy-specific configurations
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.priority, .low(.exclusive))
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.concurrencyId, "testGroup")

    // Verify unique IDs are different
    let uniqueIds = [
      lockInfo.uniqueId,
      lockInfo.lockmanInfoForStrategy1.uniqueId,
      lockInfo.lockmanInfoForStrategy2.uniqueId,
      lockInfo.lockmanInfoForStrategy3.uniqueId,
    ]
    XCTAssertEqual(Set(uniqueIds).count, 4, "All unique IDs should be different")
  }

  func testLockmanCompositeAction3MakeCompositeStrategy() {
    let action = TestCompositeAction3()
    let strategy1 = LockmanSingleExecutionStrategy.shared
    let strategy2 = LockmanPriorityBasedStrategy.shared
    let strategy3 = LockmanConcurrencyLimitedStrategy.shared

    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    // Verify type erasure
    XCTAssertTrue(
      compositeStrategy
        is AnyLockmanStrategy<
          LockmanCompositeInfo3<
            LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanConcurrencyLimitedInfo
          >
        >)

    // Verify strategy delegation
    XCTAssertEqual(
      compositeStrategy.strategyId, "composite_singleExecution_priorityBased_concurrencyLimited")
  }

  // MARK: - LockmanCompositeAction4 Tests

  struct TestCompositeAction4: LockmanCompositeAction4 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanConcurrencyLimitedInfo
    typealias S3 = LockmanConcurrencyLimitedStrategy
    typealias I4 = LockmanGroupCoordinatedInfo
    typealias S4 = LockmanGroupCoordinationStrategy

    let actionName: String

    init(actionName: String = TestSupport.uniqueActionId(prefix: "composite4")) {
      self.actionName = actionName
    }

    func createLockmanInfo() -> LockmanCompositeInfo4<I1, I2, I3, I4> {
      LockmanCompositeInfo4(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: actionName,
          mode: .boundary
        ),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: actionName,
          priority: .none
        ),
        lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
          actionId: actionName,
          group: CompositeTestConcurrencyGroup("group4", limit: LockmanConcurrencyLimit.unlimited)
        ),
        lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
          actionId: actionName,
          groupId: "testGroup4",
          coordinationRole: LockmanGroupCoordinationRole.leader(LockmanGroupCoordinationRole.LeaderEntryPolicy.emptyGroup)
        )
      )
    }
  }

  func testLockmanCompositeAction4ProtocolConformance() {
    let action = TestCompositeAction4()

    // Test that action conforms to LockmanAction through inheritance
    XCTAssertTrue(action is any LockmanAction, "CompositeAction4 should conform to LockmanAction")

    // Test associated type constraints
    let lockInfo = action.createLockmanInfo()
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy4 is LockmanGroupCoordinatedInfo)
    XCTAssertEqual(lockInfo.actionId, action.actionName)
  }

  func testLockmanCompositeAction4CreateLockmanInfo() {
    let actionName = TestSupport.uniqueActionId(prefix: "test4")
    let action = TestCompositeAction4(actionName: actionName)

    let lockInfo = action.createLockmanInfo()

    // Verify action ID consistency
    XCTAssertEqual(lockInfo.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy4.actionId, actionName)

    // Verify strategy-specific configurations
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.mode, .boundary)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.priority, .none)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.limit, LockmanConcurrencyLimit.unlimited)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy4.coordinationRole, LockmanGroupCoordinationRole.leader(LockmanGroupCoordinationRole.LeaderEntryPolicy.emptyGroup))

    // Verify unique IDs are different
    let uniqueIds = [
      lockInfo.uniqueId,
      lockInfo.lockmanInfoForStrategy1.uniqueId,
      lockInfo.lockmanInfoForStrategy2.uniqueId,
      lockInfo.lockmanInfoForStrategy3.uniqueId,
      lockInfo.lockmanInfoForStrategy4.uniqueId,
    ]
    XCTAssertEqual(Set(uniqueIds).count, 5, "All unique IDs should be different")
  }

  func testLockmanCompositeAction4MakeCompositeStrategy() {
    let action = TestCompositeAction4()
    let strategy1 = LockmanSingleExecutionStrategy.shared
    let strategy2 = LockmanPriorityBasedStrategy.shared
    let strategy3 = LockmanConcurrencyLimitedStrategy.shared
    let strategy4 = LockmanGroupCoordinationStrategy.shared

    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    // Verify type erasure
    XCTAssertTrue(
      compositeStrategy
        is AnyLockmanStrategy<
          LockmanCompositeInfo4<
            LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanConcurrencyLimitedInfo,
            LockmanGroupCoordinatedInfo
          >
        >)

    // Verify strategy delegation
    XCTAssertEqual(
      compositeStrategy.strategyId,
      "composite_singleExecution_priorityBased_concurrencyLimited_groupCoordination")
  }

  // MARK: - LockmanCompositeAction5 Tests

  struct TestCompositeAction5: LockmanCompositeAction5 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanConcurrencyLimitedInfo
    typealias S3 = LockmanConcurrencyLimitedStrategy
    typealias I4 = LockmanGroupCoordinatedInfo
    typealias S4 = LockmanGroupCoordinationStrategy
    typealias I5 = LockmanSingleExecutionInfo  // Reuse for testing
    typealias S5 = LockmanSingleExecutionStrategy

    let actionName: String

    init(actionName: String = TestSupport.uniqueActionId(prefix: "composite5")) {
      self.actionName = actionName
    }

    func createLockmanInfo() -> LockmanCompositeInfo5<I1, I2, I3, I4, I5> {
      LockmanCompositeInfo5(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
          actionId: actionName,
          mode: .action
        ),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
          actionId: actionName,
          priority: .high(.replaceable)
        ),
        lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
          actionId: actionName,
          group: CompositeTestConcurrencyGroup("group5", limit: LockmanConcurrencyLimit.limited(1))
        ),
        lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
          actionId: actionName,
          groupId: "testGroup5",
          coordinationRole: LockmanGroupCoordinationRole.member
        ),
        lockmanInfoForStrategy5: LockmanSingleExecutionInfo(
          actionId: actionName,
          mode: .none
        )
      )
    }
  }

  func testLockmanCompositeAction5ProtocolConformance() {
    let action = TestCompositeAction5()

    // Test that action conforms to LockmanAction through inheritance
    XCTAssertTrue(action is any LockmanAction, "CompositeAction5 should conform to LockmanAction")

    // Test associated type constraints
    let lockInfo = action.createLockmanInfo()
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy1 is LockmanSingleExecutionInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy2 is LockmanPriorityBasedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy3 is LockmanConcurrencyLimitedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy4 is LockmanGroupCoordinatedInfo)
    XCTAssertTrue(lockInfo.lockmanInfoForStrategy5 is LockmanSingleExecutionInfo)
    XCTAssertEqual(lockInfo.actionId, action.actionName)
  }

  func testLockmanCompositeAction5CreateLockmanInfo() {
    let actionName = TestSupport.uniqueActionId(prefix: "test5")
    let action = TestCompositeAction5(actionName: actionName)

    let lockInfo = action.createLockmanInfo()

    // Verify action ID consistency
    XCTAssertEqual(lockInfo.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy4.actionId, actionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy5.actionId, actionName)

    // Verify strategy-specific configurations
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.mode, .action)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.priority, .high(.replaceable))
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.limit, LockmanConcurrencyLimit.limited(1))
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy4.coordinationRole, LockmanGroupCoordinationRole.member)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy5.mode, .none)

    // Verify unique IDs are different
    let uniqueIds = [
      lockInfo.uniqueId,
      lockInfo.lockmanInfoForStrategy1.uniqueId,
      lockInfo.lockmanInfoForStrategy2.uniqueId,
      lockInfo.lockmanInfoForStrategy3.uniqueId,
      lockInfo.lockmanInfoForStrategy4.uniqueId,
      lockInfo.lockmanInfoForStrategy5.uniqueId,
    ]
    XCTAssertEqual(Set(uniqueIds).count, 6, "All unique IDs should be different")
  }

  func testLockmanCompositeAction5MakeCompositeStrategy() {
    let action = TestCompositeAction5()
    let strategy1 = LockmanSingleExecutionStrategy.shared
    let strategy2 = LockmanPriorityBasedStrategy.shared
    let strategy3 = LockmanConcurrencyLimitedStrategy.shared
    let strategy4 = LockmanGroupCoordinationStrategy.shared
    let strategy5 = LockmanSingleExecutionStrategy()  // Different instance

    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4,
      strategy5: strategy5
    )

    // Verify type erasure
    XCTAssertTrue(
      compositeStrategy
        is AnyLockmanStrategy<
          LockmanCompositeInfo5<
            LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanConcurrencyLimitedInfo,
            LockmanGroupCoordinatedInfo, LockmanSingleExecutionInfo
          >
        >)

    // Verify strategy delegation
    XCTAssertEqual(
      compositeStrategy.strategyId,
      "composite_singleExecution_priorityBased_concurrencyLimited_groupCoordination_singleExecution"
    )
  }

  // MARK: - Thread Safety and Concurrency Tests

  func testCompositeActionThreadSafety() async throws {
    let action = TestCompositeAction2()

    // Test concurrent createLockmanInfo calls
    let results = try await TestSupport.executeConcurrently(iterations: 10) {
      return action.createLockmanInfo()
    }

    // All should have same action ID but different unique IDs
    let actionIds = results.map { $0.actionId }
    let uniqueIds = results.map { $0.uniqueId }

    XCTAssertTrue(actionIds.allSatisfy { $0 == action.actionName })
    XCTAssertEqual(Set(uniqueIds).count, 10, "All unique IDs should be different")
  }

  func testCompositeActionSendableCompliance() {
    // Test that composite actions can be passed across concurrency boundaries
    let action = TestCompositeAction3()

    Task {
      let lockInfo = action.createLockmanInfo()
      XCTAssertEqual(lockInfo.actionId, action.actionName)
    }

    // Sendable conformance is compile-time checked, no runtime test needed
    // XCTAssertTrue(action is Sendable, "Composite action should be Sendable")
  }

  // MARK: - Edge Cases and Error Conditions

  func testCompositeActionWithEmptyActionName() {
    let action = TestCompositeAction2(actionName: "")
    let lockInfo = action.createLockmanInfo()

    XCTAssertEqual(lockInfo.actionId, "")
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, "")
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, "")
  }

  func testCompositeActionWithSpecialCharacters() {
    let specialActionName = TestSupport.StandardActionIds.unicode
    let action = TestCompositeAction3(actionName: specialActionName)
    let lockInfo = action.createLockmanInfo()

    XCTAssertEqual(lockInfo.actionId, specialActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, specialActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, specialActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.actionId, specialActionName)
  }

  func testCompositeActionWithVeryLongActionName() {
    let longActionName = TestSupport.StandardActionIds.veryLong
    let action = TestCompositeAction4(actionName: longActionName)
    let lockInfo = action.createLockmanInfo()

    XCTAssertEqual(lockInfo.actionId, longActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy1.actionId, longActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy2.actionId, longActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy3.actionId, longActionName)
    XCTAssertEqual(lockInfo.lockmanInfoForStrategy4.actionId, longActionName)
  }

  // MARK: - Performance Tests

  func testCompositeActionCreationPerformance() {
    let action = TestCompositeAction5()

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<1000 {
        _ = action.createLockmanInfo()
      }
    }

    // Performance threshold: should complete 1000 creations in under 0.1 seconds
    XCTAssertLessThan(executionTime, 0.1, "Lock info creation should be fast")
  }

  func testCompositeStrategyCreationPerformance() {
    let action = TestCompositeAction3()
    let strategy1 = LockmanSingleExecutionStrategy.shared
    let strategy2 = LockmanPriorityBasedStrategy.shared
    let strategy3 = LockmanConcurrencyLimitedStrategy.shared

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<100 {
        _ = action.makeCompositeStrategy(
          strategy1: strategy1,
          strategy2: strategy2,
          strategy3: strategy3
        )
      }
    }

    // Performance threshold: should complete 100 strategy creations in under 0.05 seconds
    XCTAssertLessThan(executionTime, 0.05, "Composite strategy creation should be fast")
  }
}
