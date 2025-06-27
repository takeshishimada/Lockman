import XCTest
@testable import Lockman

final class LockmanCompositeStrategy2Tests: XCTestCase {
  
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
    
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    XCTAssertEqual(composite.strategyId.name, "CompositeStrategy2")
    XCTAssertNotNil(composite.strategyId.configuration)
    XCTAssertTrue(composite.strategyId.configuration?.contains("+") ?? false)
  }
  
  func testMakeStrategyIdWithStrategies() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    
    let strategyId = LockmanCompositeStrategy2.makeStrategyId(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    XCTAssertEqual(strategyId.name, "CompositeStrategy2")
    XCTAssertEqual(
      strategyId.configuration,
      "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)"
    )
  }
  
  func testMakeStrategyIdWithoutParameters() {
    let strategyId = LockmanCompositeStrategy2<
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanPriorityBasedInfo,
      LockmanPriorityBasedStrategy
    >.makeStrategyId()
    
    XCTAssertEqual(strategyId.name, "CompositeStrategy2")
    XCTAssertNil(strategyId.configuration)
  }
  
  // MARK: - CanLock Tests
  
  func testCanLockBothSuccess() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }
  
  func testCanLockFirstStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    
    // Lock strategy1 first to make it fail
    strategy1.lockAcquired(id: boundaryId, info: info1)
    
    let compositeInfo = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    let result = composite.canLock(id: boundaryId, info: compositeInfo)
    
    switch result {
    case .failure(let error):
      XCTAssertTrue(error is LockmanSingleExecutionError)
    default:
      XCTFail("Expected failure but got \(result)")
    }
    
    // Cleanup
    strategy1.lockReleased(id: boundaryId, info: info1)
  }
  
  func testCanLockSecondStrategyFails() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let blockingInfo = LockmanPriorityBasedInfo(
      actionId: "blocking",
      priority: .high(.preferLater)
    )
    
    // Lock strategy2 with high priority
    strategy2.lockAcquired(id: boundaryId, info: blockingInfo)
    
    let compositeInfo = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .low)
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
  
  func testCanLockWithSuccessWithPrecedingCancellation() {
    // Create mock strategies
    let strategy1 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.cancellationError)
    )
    let strategy2 = MockLockmanStrategy(canLockResult: .success)
    
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "action1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "action2")
    )
    
    let result = composite.canLock(id: boundaryId, info: info)
    
    switch result {
    case .successWithPrecedingCancellation(let error):
      XCTAssertTrue(error is TestError)
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }
  }
  
  func testCanLockMultipleCancellations() {
    // Both strategies return cancellation, should use first error
    let strategy1 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.firstCancellation)
    )
    let strategy2 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.secondCancellation)
    )
    
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "action1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "action2")
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
    
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "2")
    )
    
    // Lock
    composite.lock(id: boundaryId, info: info)
    XCTAssertEqual(lockOrder, ["1", "2"])
    
    // Unlock (should be LIFO)
    composite.unlock(id: boundaryId, info: info)
    XCTAssertEqual(unlockOrder, ["2", "1"])
  }
  
  func testLockAcquisitionState() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    // Initially no locks
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
    
    // Lock
    composite.lock(id: boundaryId, info: info)
    
    // Both should have locks
    XCTAssertFalse(strategy1.getCurrentLocks().isEmpty)
    XCTAssertFalse(strategy2.getCurrentLocks().isEmpty)
    
    // Unlock
    composite.unlock(id: boundaryId, info: info)
    
    // Both should be cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
  }
  
  // MARK: - CleanUp Tests
  
  func testCleanUpAll() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId1 = TestBoundaryId("boundary1")
    let boundaryId2 = TestBoundaryId("boundary2")
    
    let info1 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    let info2 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action3"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action4", priority: .low)
    )
    
    // Lock multiple boundaries
    composite.lock(id: boundaryId1, info: info1)
    composite.lock(id: boundaryId2, info: info2)
    
    // Clean up all
    composite.cleanUp()
    
    // All locks should be cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }
  
  func testCleanUpSpecificBoundary() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId1 = TestBoundaryId("boundary1")
    let boundaryId2 = TestBoundaryId("boundary2")
    
    let info1 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    let info2 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action3"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action4", priority: .low)
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
    
    // Cleanup
    composite.cleanUp()
  }
  
  // MARK: - GetCurrentLocks Tests
  
  func testGetCurrentLocksEmpty() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let locks = composite.getCurrentLocks()
    XCTAssertTrue(locks.isEmpty)
  }
  
  func testGetCurrentLocksMerged() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )
    
    composite.lock(id: boundaryId, info: info)
    
    let locks = composite.getCurrentLocks()
    let anyBoundaryId = AnyLockmanBoundaryId(boundaryId)
    
    XCTAssertNotNil(locks[anyBoundaryId])
    XCTAssertEqual(locks[anyBoundaryId]?.count, 2)
    
    // Verify both info types are present
    let lockInfos = locks[anyBoundaryId] ?? []
    XCTAssertTrue(lockInfos.contains { $0 is LockmanSingleExecutionInfo })
    XCTAssertTrue(lockInfos.contains { $0 is LockmanPriorityBasedInfo })
    
    // Cleanup
    composite.cleanUp()
  }
  
  // MARK: - Complex Scenario Tests
  
  func testMixedStrategyTypes() {
    // Test with different strategy combinations
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()
    let concurrencyStrategy = LockmanConcurrencyLimitedStrategy()
    let dynamicStrategy = LockmanDynamicConditionStrategy()
    
    // Single + Priority
    let composite1 = LockmanCompositeStrategy2(
      strategy1: singleStrategy,
      strategy2: priorityStrategy
    )
    
    // Concurrency + Dynamic
    let composite2 = LockmanCompositeStrategy2(
      strategy1: concurrencyStrategy,
      strategy2: dynamicStrategy
    )
    
    let boundaryId = TestBoundaryId("test")
    
    // Test composite1
    let info1 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "single"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "priority", priority: .high(.exclusive))
    )
    
    XCTAssertEqual(composite1.canLock(id: boundaryId, info: info1), .success)
    
    // Test composite2
    let info2 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("api"),
        limit: .limited(5)
      ),
      lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
        actionId: "dynamic",
        condition: { .success }
      )
    )
    
    XCTAssertEqual(composite2.canLock(id: boundaryId, info: info2), .success)
  }
  
  func testConcurrentAccess() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let expectation = expectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 100
    
    let queue = DispatchQueue(label: "test", attributes: .concurrent)
    let group = DispatchGroup()
    
    // Perform concurrent operations
    for i in 0..<100 {
      group.enter()
      queue.async {
        let boundaryId = TestBoundaryId("boundary-\(i % 10)")
        let info = LockmanCompositeInfo2(
          lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action-\(i)"),
          lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
            actionId: "priority-\(i)",
            priority: i % 2 == 0 ? .high(.exclusive) : .low
          )
        )
        
        if composite.canLock(id: boundaryId, info: info) == .success {
          composite.lock(id: boundaryId, info: info)
          
          // Simulate some work
          Thread.sleep(forTimeInterval: 0.001)
          
          composite.unlock(id: boundaryId, info: info)
        }
        
        group.leave()
        expectation.fulfill()
      }
    }
    
    wait(for: [expectation], timeout: 10.0)
    
    // Verify no locks remain
    group.wait()
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }
  
  // MARK: - Edge Cases
  
  func testEmptyActionIds() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: ""),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "", priority: .medium)
    )
    
    // Should still work with empty action IDs
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)
    
    composite.lock(id: boundaryId, info: info)
    XCTAssertFalse(composite.getCurrentLocks().isEmpty)
    
    composite.unlock(id: boundaryId, info: info)
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }
  
  func testVeryLongActionIds() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    
    let longActionId = String(repeating: "a", count: 10000)
    let boundaryId = TestBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: longActionId),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: longActionId, priority: .medium)
    )
    
    XCTAssertEqual(composite.canLock(id: boundaryId, info: info), .success)
  }
}

// MARK: - Test Helpers

private enum TestError: Error, Equatable {
  case cancellationError
  case firstCancellation
  case secondCancellation
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