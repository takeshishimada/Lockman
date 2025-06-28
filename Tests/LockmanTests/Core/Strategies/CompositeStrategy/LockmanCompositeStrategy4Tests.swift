import XCTest

@testable import Lockman

final class LockmanCompositeStrategy4Tests: XCTestCase {

  // MARK: - Test Types

  private struct TestBoundaryId: LockmanBoundaryId {
    let value: String

    init(_ value: String) {
      self.value = value
    }
  }

  // MARK: - Basic Tests

  func testInitialization() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    XCTAssertEqual(composite.strategyId.name, "CompositeStrategy4")
    XCTAssertNotNil(composite.strategyId.configuration)

    let config = composite.strategyId.configuration ?? ""
    XCTAssertTrue(config.contains(strategy1.strategyId.value))
    XCTAssertTrue(config.contains(strategy2.strategyId.value))
    XCTAssertTrue(config.contains(strategy3.strategyId.value))
    XCTAssertTrue(config.contains(strategy4.strategyId.value))
    XCTAssertEqual(config.components(separatedBy: "+").count, 4)
  }

  func testMakeStrategyIdWithStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let strategyId = LockmanCompositeStrategy4.makeStrategyId(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    XCTAssertEqual(strategyId.name, "CompositeStrategy4")
    XCTAssertEqual(
      strategyId.configuration,
      "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)+\(strategy4.strategyId.value)"
    )
  }

  func testMakeStrategyIdWithoutParameters() {
    let strategyId = LockmanCompositeStrategy4<
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanPriorityBasedInfo,
      LockmanPriorityBasedStrategy,
      LockmanConcurrencyLimitedInfo,
      LockmanConcurrencyLimitedStrategy,
      LockmanDynamicConditionInfo,
      LockmanDynamicConditionStrategy
    >.makeStrategyId()

    XCTAssertEqual(strategyId.name, "CompositeStrategy4")
    XCTAssertNil(strategyId.configuration)
  }

  // MARK: - CanLock Tests

  func testCanLockAllSuccess() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCanLockFirstStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let blockingInfo = LockmanSingleExecutionInfo(actionId: "action1")

    // Block strategy1
    strategy1.lockAcquired(id: boundaryId, info: blockingInfo)

    let compositeInfo = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: blockingInfo,
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    default:
      XCTFail("Expected failure but got \(result)")
    }

    // Cleanup
    strategy1.lockReleased(id: boundaryId, info: blockingInfo)
  }

  func testCanLockSecondStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let blockingInfo = LockmanPriorityBasedInfo(
      actionId: "blocking",
      priority: .high(.preferLater)
    )

    // Block strategy2 with high priority
    strategy2.lockAcquired(id: boundaryId, info: blockingInfo)

    let compositeInfo = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .low),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure(let error):
      XCTAssertTrue(error is LockmanPriorityBasedError)
    default:
      XCTFail("Expected failure but got \(result)")
    }

    // Cleanup
    strategy2.lockReleased(id: boundaryId, info: blockingInfo)
  }

  func testCanLockThirdStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let groupId = AnyLockmanGroupId("limited-group")

    // Fill up the concurrency limit
    let blockingInfo1 = LockmanConcurrencyLimitedInfo(
      concurrencyId: groupId,
      limit: .limited(2)
    )
    let blockingInfo2 = LockmanConcurrencyLimitedInfo(
      concurrencyId: groupId,
      limit: .limited(2)
    )

    strategy3.lockAcquired(id: boundaryId, info: blockingInfo1)
    strategy3.lockAcquired(id: boundaryId, info: blockingInfo2)

    let compositeInfo = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: groupId,
        limit: .limited(2)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure(let error):
      XCTAssertTrue(error is LockmanConcurrencyLimitedError)
    default:
      XCTFail("Expected failure but got \(result)")
    }

    // Cleanup
    strategy3.lockReleased(id: boundaryId, info: blockingInfo1)
    strategy3.lockReleased(id: boundaryId, info: blockingInfo2)
  }

  func testCanLockFourthStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let compositeInfo = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .failure(TestError.mockError) }
      )
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure(let error):
      XCTAssertTrue(error is TestError)
    default:
      XCTFail("Expected failure but got \(result)")
    }
  }

  func testCanLockWithMultipleCancellations() {
    let strategy1 = MockLockmanStrategy(canLockResult: .success)
    let strategy2 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.firstCancellation)
    )
    let strategy3 = MockLockmanStrategy(canLockResult: .success)
    let strategy4 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.secondCancellation)
    )

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "action1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "action2"),
      lockmanInfoForStrategy3: MockLockmanInfo(actionId: "action3"),
      lockmanInfoForStrategy4: MockLockmanInfo(actionId: "action4")
    )

    let result = composite.canLock(id: boundaryId, info: info)

    switch result {
    case .successWithPrecedingCancellation(let error):
      // Should use the first cancellation error
      XCTAssertEqual(error as? TestError, TestError.firstCancellation)
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }
  }

  // MARK: - Lock/Unlock Tests

  func testLockUnlockOrder() {
    var lockOrder: [String] = []
    var unlockOrder: [String] = []

    let strategy1 = MockOrderTrackingStrategy(
      id: "1",
      lockOrder: &lockOrder,
      unlockOrder: &unlockOrder
    )
    let strategy2 = MockOrderTrackingStrategy(
      id: "2",
      lockOrder: &lockOrder,
      unlockOrder: &unlockOrder
    )
    let strategy3 = MockOrderTrackingStrategy(
      id: "3",
      lockOrder: &lockOrder,
      unlockOrder: &unlockOrder
    )
    let strategy4 = MockOrderTrackingStrategy(
      id: "4",
      lockOrder: &lockOrder,
      unlockOrder: &unlockOrder
    )

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "2"),
      lockmanInfoForStrategy3: MockLockmanInfo(actionId: "3"),
      lockmanInfoForStrategy4: MockLockmanInfo(actionId: "4")
    )

    // Lock
    composite.lock(id: boundaryId, info: info)
    XCTAssertEqual(lockOrder, ["1", "2", "3", "4"])

    // Unlock (should be LIFO)
    composite.unlock(id: boundaryId, info: info)
    XCTAssertEqual(unlockOrder, ["4", "3", "2", "1"])
  }

  func testLockAcquisitionStateAllStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    // Initially no locks
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy3.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy4.getCurrentLocks().isEmpty)

    // Lock
    composite.lock(id: boundaryId, info: info)

    // All should have locks
    XCTAssertFalse(strategy1.getCurrentLocks().isEmpty)
    XCTAssertFalse(strategy2.getCurrentLocks().isEmpty)
    XCTAssertFalse(strategy3.getCurrentLocks().isEmpty)
    XCTAssertFalse(strategy4.getCurrentLocks().isEmpty)

    // Unlock
    composite.unlock(id: boundaryId, info: info)

    // All should be cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy3.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy4.getCurrentLocks().isEmpty)
  }

  // MARK: - CleanUp Tests

  func testCleanUpAll() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId1 = TestBoundaryId("boundary1")
    let boundaryId2 = TestBoundaryId("boundary2")

    let info1 = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let info2 = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action5"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action6", priority: .low),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group2"),
        limit: .limited(10)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action8",
        condition: { .success }
      )
    )

    // Lock multiple boundaries
    composite.lock(id: boundaryId1, info: info1)
    composite.lock(id: boundaryId2, info: info2)

    // Clean up all
    composite.cleanUp()

    // All locks should be cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy3.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy4.getCurrentLocks().isEmpty)
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }

  func testCleanUpSpecificBoundary() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId1 = TestBoundaryId("boundary1")
    let boundaryId2 = TestBoundaryId("boundary2")

    let info1 = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    let info2 = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action5"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action6", priority: .low),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group2"),
        limit: .limited(10)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action8",
        condition: { .success }
      )
    )

    // Lock both boundaries
    composite.lock(id: boundaryId1, info: info1)
    composite.lock(id: boundaryId2, info: info2)

    // Clean up only boundary1
    composite.cleanUp(id: boundaryId1)

    // boundary1 should be cleared, boundary2 should remain
    let currentLocks = composite.getCurrentLocks()
    XCTAssertNil(currentLocks[AnyLockmanBoundaryId(boundaryId1)])
    XCTAssertNotNil(currentLocks[AnyLockmanBoundaryId(boundaryId2)])

    // Verify each strategy cleaned up correctly
    XCTAssertNil(strategy1.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId1)])
    XCTAssertNil(strategy2.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId1)])
    XCTAssertNil(strategy3.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId1)])
    XCTAssertNil(strategy4.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId1)])

    XCTAssertNotNil(strategy1.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId2)])
    XCTAssertNotNil(strategy2.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId2)])
    XCTAssertNotNil(strategy3.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId2)])
    XCTAssertNotNil(strategy4.getCurrentLocks()[AnyLockmanBoundaryId(boundaryId2)])

    // Cleanup
    composite.cleanUp()
  }

  // MARK: - GetCurrentLocks Tests

  func testGetCurrentLocksMergedFromFourStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "action4",
        condition: { .success }
      )
    )

    composite.lock(id: boundaryId, info: info)

    let locks = composite.getCurrentLocks()
    let anyBoundaryId = AnyLockmanBoundaryId(boundaryId)

    XCTAssertNotNil(locks[anyBoundaryId])
    XCTAssertEqual(locks[anyBoundaryId]?.count, 4)

    // Verify all four info types are present
    let lockInfos = locks[anyBoundaryId] ?? []
    XCTAssertTrue(lockInfos.contains { $0 is LockmanSingleExecutionInfo })
    XCTAssertTrue(lockInfos.contains { $0 is LockmanPriorityBasedInfo })
    XCTAssertTrue(lockInfos.contains { $0 is LockmanConcurrencyLimitedInfo })
    XCTAssertTrue(lockInfos.contains { $0 is LockmanDynamicConditionInfo })

    // Cleanup
    composite.cleanUp()
  }

  // MARK: - Complex Scenario Tests

  func testAllBuiltInStrategies() {
    // Test with all built-in strategies
    let composite = LockmanCompositeStrategy4(
      strategy1: LockmanSingleExecutionStrategy(),
      strategy2: LockmanPriorityBasedStrategy(),
      strategy3: LockmanConcurrencyLimitedStrategy(),
      strategy4: LockmanDynamicConditionStrategy()
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "single"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
        actionId: "priority", priority: .high(.exclusive)),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("api"),
        limit: .limited(10)
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "dynamic",
        condition: { .success }
      )
    )

    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)

    composite.lock(id: boundaryId, info: info)
    XCTAssertFalse(composite.getCurrentLocks().isEmpty)

    composite.unlock(id: boundaryId, info: info)
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }

  func testConcurrentAccessFourStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let expectation = expectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 200

    let queue = DispatchQueue(label: "test", attributes: .concurrent)
    let group = DispatchGroup()

    // Perform concurrent operations
    for i in 0..<200 {
      group.enter()
      queue.async {
        let boundaryId = TestBoundaryId("boundary-\(i % 20)")
        let info = LockmanCompositeInfo4(
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action-\(i)"),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: "priority-\(i)",
            priority: i % 4 == 0
              ? .high(.exclusive) : i % 4 == 1 ? .high(.preferLater) : i % 4 == 2 ? .medium : .low
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            concurrencyId: AnyLockmanGroupId("group-\(i % 5)"),
            limit: .limited(4)
          ),
          lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
            actionId: "dynamic-\(i)",
            condition: { i % 10 == 0 ? .failure(TestError.mockError) : .success }
          )
        )

        let result = composite.canLock(id: boundaryId, info: info)
        if result == .success {
          composite.lock(id: boundaryId, info: info)

          // Simulate some work
          Thread.sleep(forTimeInterval: 0.001)

          composite.unlock(id: boundaryId, info: info)
        }

        group.leave()
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 20.0)

    // Verify no locks remain
    group.wait()
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }

  // MARK: - Edge Cases

  func testCoordinateResultsWithAllSuccess() {
    let strategy1 = MockLockmanStrategy(canLockResult: .success)
    let strategy2 = MockLockmanStrategy(canLockResult: .success)
    let strategy3 = MockLockmanStrategy(canLockResult: .success)
    let strategy4 = MockLockmanStrategy(canLockResult: .success)

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "2"),
      lockmanInfoForStrategy3: MockLockmanInfo(actionId: "3"),
      lockmanInfoForStrategy4: MockLockmanInfo(actionId: "4")
    )

    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testDynamicConditionVariations() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("test")

    // Test with condition that changes based on external state
    var shouldSucceed = true

    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group"),
        limit: .unlimited
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
        actionId: "dynamic",
        condition: { shouldSucceed ? .success : .failure(TestError.mockError) }
      )
    )

    // Should succeed
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)

    // Change condition
    shouldSucceed = false

    // Should now fail
    let result = composite.canLock(id: boundaryId, info: info)
    switch result {
    case .failure(let error):
      XCTAssertTrue(error is TestError)
    default:
      XCTFail("Expected failure but got \(result)")
    }
  }

  func testPerformanceWithFourStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()
    let strategy4 = LockmanDynamicConditionStrategy()

    let composite = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    let boundaryId = TestBoundaryId("perf-test")

    measure {
      for i in 0..<1000 {
        let info = LockmanCompositeInfo4(
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action-\(i)"),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: "priority-\(i)",
            priority: .medium
          ),
          lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
            concurrencyId: AnyLockmanGroupId("perf-group"),
            limit: .unlimited
          ),
          lockmanInfoForStrategy4: LockmanDynamicConditionInfo(
            actionId: "dynamic-\(i)",
            condition: { .success }
          )
        )

        if composite.canLock(id: boundaryId, info: info) == .success {
          composite.lock(id: boundaryId, info: info)
          composite.unlock(id: boundaryId, info: info)
        }
      }
    }
  }
}

// MARK: - Test Helpers (Shared with other Strategy tests)

private enum TestError: Error, Equatable {
  case cancellationError
  case firstCancellation
  case secondCancellation
  case thirdCancellation
  case fourthCancellation
  case mockError
}

private struct MockLockmanInfo: LockmanInfo {
  let strategyId: LockmanStrategyId = .singleExecution
  let actionId: LockmanActionId
  let uniqueId: UUID = UUID()
  var debugDescription: String { "MockInfo(\(actionId))" }
}

private final class MockLockmanStrategy: LockmanStrategy {
  typealias I = MockLockmanInfo

  let strategyId: LockmanStrategyId = .singleExecution
  let canLockResult: LockmanResult
  private var locks: [AnyLockmanBoundaryId: [MockLockmanInfo]] = [:]

  init(canLockResult: LockmanResult) {
    self.canLockResult = canLockResult
  }

  func canLock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) -> LockmanResult {
    return canLockResult
  }

  func lock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) {
    locks[AnyLockmanBoundaryId(id), default: []].append(info)
  }

  func unlock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) {
    locks[AnyLockmanBoundaryId(id)]?.removeAll { $0.uniqueId == info.uniqueId }
  }

  func cleanUp() {
    locks.removeAll()
  }

  func cleanUp<B: LockmanBoundaryId>(id: B) {
    locks[AnyLockmanBoundaryId(id)] = nil
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    locks.mapValues { $0 as [any LockmanInfo] }
  }
}

private final class MockOrderTrackingStrategy: LockmanStrategy {
  typealias I = MockLockmanInfo

  let strategyId: LockmanStrategyId
  let id: String
  private var lockOrder: UnsafeMutablePointer<[String]>
  private var unlockOrder: UnsafeMutablePointer<[String]>

  init(id: String, lockOrder: inout [String], unlockOrder: inout [String]) {
    self.id = id
    self.strategyId = LockmanStrategyId("Mock\(id)")
    self.lockOrder = withUnsafeMutablePointer(to: &lockOrder) { $0 }
    self.unlockOrder = withUnsafeMutablePointer(to: &unlockOrder) { $0 }
  }

  func canLock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) -> LockmanResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) {
    lockOrder.pointee.append(self.id)
  }

  func unlock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) {
    unlockOrder.pointee.append(self.id)
  }

  func cleanUp() {}

  func cleanUp<B: LockmanBoundaryId>(id: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    [:]
  }
}
