import XCTest

@testable import LockmanCore

/// Basic tests for LockmanCompositeStrategy implementations
final class LockmanCompositeBasicTests: XCTestCase {
  func testcompositeStrategy2BasicFunctionality() {
    let priority = LockmanPriorityBasedStrategy.shared
    let single = LockmanSingleExecutionStrategy.shared
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    let boundaryId = "test-boundary"
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action", priority: .high(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Test basic lock workflow
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)
    composite.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(composite.canLock(id: boundaryId, info: info))
    composite.unlock(id: boundaryId, info: info)
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)

    // Cleanup
    composite.cleanUp()
  }

  func testcompositeStrategy3BasicFunctionality() {
    let priority = LockmanPriorityBasedStrategy()
    let single1 = LockmanSingleExecutionStrategy()
    let single2 = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy3(
      strategy1: priority,
      strategy2: single1,
      strategy3: single2
    )

    let boundaryId = "test-boundary"
    let info = LockmanCompositeInfo3(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action", priority: .low(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary),
      lockmanInfoForStrategy3: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Test basic lock workflow
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)
    composite.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(composite.canLock(id: boundaryId, info: info))
    composite.unlock(id: boundaryId, info: info)
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)

    // Cleanup
    composite.cleanUp()
  }

  func testcompositeInfo2BasicProperties() {
    let actionId = "test-action"
    let priorityInfo = LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive))
    let singleInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: priorityInfo,
      lockmanInfoForStrategy2: singleInfo
    )

    XCTAssertEqual(compositeInfo.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy2.actionId, actionId)
    XCTAssertEqual(compositeInfo.lockmanInfoForStrategy1.priority, .high(.exclusive))
  }

  func testcompositeStrategy2MakeStrategyId() {
    let priority = LockmanPriorityBasedStrategy.shared
    let single = LockmanSingleExecutionStrategy.shared

    // Test static method with parameters
    let staticId = LockmanCompositeStrategy2.makeStrategyId(strategy1: priority, strategy2: single)
    let expectedConfig = "\(priority.strategyId.value)+\(single.strategyId.value)"

    XCTAssertEqual(staticId.value, "CompositeStrategy2:\(expectedConfig)")

    // Test instance strategyId matches static method
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)
    XCTAssertEqual(composite.strategyId, staticId)

    // Test parameterless makeStrategyId
    let genericId = LockmanCompositeStrategy2<
      LockmanPriorityBasedInfo, LockmanPriorityBasedStrategy, LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy
    >.makeStrategyId()
    XCTAssertEqual(genericId.value, "CompositeStrategy2")
  }

  func testcompositeStrategy3MakeStrategyId() {
    let s1 = LockmanPriorityBasedStrategy()
    let s2 = LockmanSingleExecutionStrategy()
    let s3 = LockmanGroupCoordinationStrategy()

    // Test static method with parameters
    let staticId = LockmanCompositeStrategy3.makeStrategyId(
      strategy1: s1, strategy2: s2, strategy3: s3)
    let expectedConfig = "\(s1.strategyId.value)+\(s2.strategyId.value)+\(s3.strategyId.value)"

    XCTAssertEqual(staticId.value, "CompositeStrategy3:\(expectedConfig)")

    // Test instance strategyId matches static method
    let composite = LockmanCompositeStrategy3(strategy1: s1, strategy2: s2, strategy3: s3)
    XCTAssertEqual(composite.strategyId, staticId)
  }

  func teststrategyCleanupFunctionality() {
    let composite = LockmanCompositeStrategy2(
      strategy1: LockmanPriorityBasedStrategy(),
      strategy2: LockmanSingleExecutionStrategy()
    )

    let boundaryId = "cleanup-test"
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action", priority: .low(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Lock and verify it's active
    composite.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(composite.canLock(id: boundaryId, info: info))

    // Global cleanup
    composite.cleanUp()
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)

    // Test boundary-specific cleanup
    composite.lock(id: boundaryId, info: info)
    composite.cleanUp(id: boundaryId)
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)
  }

  func testcoordinationLogicTesting() {
    let priority = LockmanPriorityBasedStrategy()
    let single = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    let boundaryId = "coordination-test"

    // Setup a lower priority lock
    let lowPriorityInfo1 = LockmanPriorityBasedInfo(
      actionId: "low-action", priority: .low(.exclusive))
    priority.lock(id: boundaryId, info: lowPriorityInfo1)

    // Create composite info that should trigger cancellation
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
        actionId: "test-action", priority: .high(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .successWithPrecedingCancellation)

    // Cleanup
    priority.cleanUp(id: boundaryId)
    single.cleanUp(id: boundaryId)
  }
}
