import Testing
@testable import LockmanCore

/// Basic tests for LockmanCompositeStrategy implementations
@Suite("Composite Strategy Basic Tests")
struct LockmanCompositeBasicTests {
  @Test("LockmanCompositeStrategy2 basic functionality")
  func compositeStrategy2BasicFunctionality() {
    let priority = LockmanPriorityBasedStrategy.shared
    let single = LockmanSingleExecutionStrategy.shared
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    let boundaryId = "test-boundary"
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(actionId: "test-action", priority: .high(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Test basic lock workflow
    #expect(composite.canLock(id: boundaryId, info: info) == .success)
    composite.lock(id: boundaryId, info: info)
    #expect(composite.canLock(id: boundaryId, info: info) == .failure)
    composite.unlock(id: boundaryId, info: info)
    #expect(composite.canLock(id: boundaryId, info: info) == .success)

    // Cleanup
    composite.cleanUp()
  }

  @Test("LockmanCompositeStrategy3 basic functionality")
  func compositeStrategy3BasicFunctionality() {
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
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(actionId: "test-action", priority: .low(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary),
      lockmanInfoForStrategy3: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Test basic lock workflow
    #expect(composite.canLock(id: boundaryId, info: info) == .success)
    composite.lock(id: boundaryId, info: info)
    #expect(composite.canLock(id: boundaryId, info: info) == .failure)
    composite.unlock(id: boundaryId, info: info)
    #expect(composite.canLock(id: boundaryId, info: info) == .success)

    // Cleanup
    composite.cleanUp()
  }

  @Test("LockmanCompositeInfo2 basic properties")
  func compositeInfo2BasicProperties() {
    let actionId = "test-action"
    let priorityInfo = LockmanPriorityBasedInfo(actionId: actionId, priority: .high(.exclusive))
    let singleInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    let compositeInfo = LockmanCompositeInfo2(
      actionId: actionId,
      lockmanInfoForStrategy1: priorityInfo,
      lockmanInfoForStrategy2: singleInfo
    )

    #expect(compositeInfo.actionId == actionId)
    #expect(compositeInfo.lockmanInfoForStrategy1.actionId == actionId)
    #expect(compositeInfo.lockmanInfoForStrategy2.actionId == actionId)
    #expect(compositeInfo.lockmanInfoForStrategy1.priority == .high(.exclusive))
  }

  @Test("CompositeStrategy2 makeStrategyId")
  func compositeStrategy2MakeStrategyId() {
    let priority = LockmanPriorityBasedStrategy.shared
    let single = LockmanSingleExecutionStrategy.shared

    // Test static method with parameters
    let staticId = LockmanCompositeStrategy2.makeStrategyId(strategy1: priority, strategy2: single)
    let expectedConfig = "\(priority.strategyId.value)+\(single.strategyId.value)"

    #expect(staticId.value == "CompositeStrategy2:\(expectedConfig)")

    // Test instance strategyId matches static method
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)
    #expect(composite.strategyId == staticId)

    // Test parameterless makeStrategyId
    let genericId = LockmanCompositeStrategy2<LockmanPriorityBasedInfo, LockmanPriorityBasedStrategy, LockmanSingleExecutionInfo, LockmanSingleExecutionStrategy>.makeStrategyId()
    #expect(genericId.value == "CompositeStrategy2")
  }

  @Test("CompositeStrategy3 makeStrategyId")
  func compositeStrategy3MakeStrategyId() {
    let s1 = LockmanPriorityBasedStrategy()
    let s2 = LockmanSingleExecutionStrategy()
    let s3 = LockmanGroupCoordinationStrategy()

    // Test static method with parameters
    let staticId = LockmanCompositeStrategy3.makeStrategyId(strategy1: s1, strategy2: s2, strategy3: s3)
    let expectedConfig = "\(s1.strategyId.value)+\(s2.strategyId.value)+\(s3.strategyId.value)"

    #expect(staticId.value == "CompositeStrategy3:\(expectedConfig)")

    // Test instance strategyId matches static method
    let composite = LockmanCompositeStrategy3(strategy1: s1, strategy2: s2, strategy3: s3)
    #expect(composite.strategyId == staticId)
  }

  @Test("Strategy cleanup functionality")
  func strategyCleanupFunctionality() {
    let composite = LockmanCompositeStrategy2(
      strategy1: LockmanPriorityBasedStrategy(),
      strategy2: LockmanSingleExecutionStrategy()
    )

    let boundaryId = "cleanup-test"
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(actionId: "test-action", priority: .low(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    // Lock and verify it's active
    composite.lock(id: boundaryId, info: info)
    #expect(composite.canLock(id: boundaryId, info: info) == .failure)

    // Global cleanup
    composite.cleanUp()
    #expect(composite.canLock(id: boundaryId, info: info) == .success)

    // Test boundary-specific cleanup
    composite.lock(id: boundaryId, info: info)
    composite.cleanUp(id: boundaryId)
    #expect(composite.canLock(id: boundaryId, info: info) == .success)
  }

  @Test("Coordination logic testing")
  func coordinationLogicTesting() {
    let priority = LockmanPriorityBasedStrategy()
    let single = LockmanSingleExecutionStrategy()
    let composite = LockmanCompositeStrategy2(strategy1: priority, strategy2: single)

    let boundaryId = "coordination-test"

    // Setup a lower priority lock
    let lowPriorityInfo1 = LockmanPriorityBasedInfo(actionId: "low-action", priority: .low(.exclusive))
    priority.lock(id: boundaryId, info: lowPriorityInfo1)

    // Create composite info that should trigger cancellation
    let info = LockmanCompositeInfo2(
      actionId: "test-action",
      lockmanInfoForStrategy1: LockmanPriorityBasedInfo(actionId: "test-action", priority: .high(.exclusive)),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    )

    let result = composite.canLock(id: boundaryId, info: info)
    #expect(result == .successWithPrecedingCancellation)

    // Cleanup
    priority.cleanUp(id: boundaryId)
    single.cleanUp(id: boundaryId)
  }
}
