import XCTest
@testable import Lockman

final class LockmanStrategyContainerTests: XCTestCase {
  
  var container: LockmanStrategyContainer!
  
  override func setUp() {
    super.setUp()
    container = LockmanStrategyContainer()
  }
  
  override func tearDown() {
    container = nil
    super.tearDown()
  }
  
  // MARK: - Basic Registration Tests
  
  func testInitialState() {
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertTrue(container.registeredStrategyIds().isEmpty)
  }
  
  func testRegisterStrategyWithId() throws {
    let strategy = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("test-strategy")
    
    try container.register(id: id, strategy: strategy)
    
    XCTAssertTrue(container.isRegistered(id: id))
    XCTAssertEqual(container.strategyCount(), 1)
    XCTAssertEqual(container.registeredStrategyIds(), [id])
  }
  
  func testRegisterStrategyWithBuiltInId() throws {
    let strategy = LockmanSingleExecutionStrategy()
    
    try container.register(strategy)
    
    XCTAssertTrue(container.isRegistered(id: strategy.strategyId))
    XCTAssertEqual(container.strategyCount(), 1)
  }
  
  func testRegisterDuplicateIdThrows() throws {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("duplicate")
    
    try container.register(id: id, strategy: strategy1)
    
    XCTAssertThrowsError(try container.register(id: id, strategy: strategy2)) { error in
      guard case LockmanRegistrationError.strategyAlreadyRegistered(let registeredId) = error else {
        XCTFail("Expected strategyAlreadyRegistered error")
        return
      }
      XCTAssertEqual(registeredId, id.value)
    }
  }
  
  // MARK: - Bulk Registration Tests
  
  func testRegisterAllWithIds() throws {
    let strategies: [(LockmanStrategyId, LockmanSingleExecutionStrategy)] = [
      (LockmanStrategyId("strategy1"), LockmanSingleExecutionStrategy()),
      (LockmanStrategyId("strategy2"), LockmanSingleExecutionStrategy()),
      (LockmanStrategyId("strategy3"), LockmanSingleExecutionStrategy())
    ]
    
    try container.registerAll(strategies)
    
    XCTAssertEqual(container.strategyCount(), 3)
    for (id, _) in strategies {
      XCTAssertTrue(container.isRegistered(id: id))
    }
  }
  
  func testRegisterAllWithBuiltInIds() throws {
    let strategies = [
      LockmanSingleExecutionStrategy(),
      LockmanPriorityBasedStrategy(),
      LockmanConcurrencyLimitedStrategy()
    ]
    
    try container.registerAll(strategies)
    
    XCTAssertEqual(container.strategyCount(), 3)
    XCTAssertTrue(container.isRegistered(id: .singleExecution))
    XCTAssertTrue(container.isRegistered(id: .priorityBased))
    XCTAssertTrue(container.isRegistered(id: .concurrencyLimited))
  }
  
  func testRegisterAllWithDuplicateIdsInArray() throws {
    let strategies: [(LockmanStrategyId, LockmanSingleExecutionStrategy)] = [
      (LockmanStrategyId("same"), LockmanSingleExecutionStrategy()),
      (LockmanStrategyId("same"), LockmanSingleExecutionStrategy())
    ]
    
    XCTAssertThrowsError(try container.registerAll(strategies)) { error in
      guard case LockmanRegistrationError.strategyAlreadyRegistered = error else {
        XCTFail("Expected strategyAlreadyRegistered error")
        return
      }
    }
    
    // Verify nothing was registered (atomic operation)
    XCTAssertEqual(container.strategyCount(), 0)
  }
  
  func testRegisterAllWithExistingIdThrows() throws {
    let existingId = LockmanStrategyId("existing")
    try container.register(id: existingId, strategy: LockmanSingleExecutionStrategy())
    
    let strategies: [(LockmanStrategyId, LockmanSingleExecutionStrategy)] = [
      (LockmanStrategyId("new1"), LockmanSingleExecutionStrategy()),
      (existingId, LockmanSingleExecutionStrategy()),
      (LockmanStrategyId("new2"), LockmanSingleExecutionStrategy())
    ]
    
    XCTAssertThrowsError(try container.registerAll(strategies)) { error in
      guard case LockmanRegistrationError.strategyAlreadyRegistered = error else {
        XCTFail("Expected strategyAlreadyRegistered error")
        return
      }
    }
    
    // Verify only the existing strategy remains (atomic operation)
    XCTAssertEqual(container.strategyCount(), 1)
    XCTAssertTrue(container.isRegistered(id: existingId))
    XCTAssertFalse(container.isRegistered(id: LockmanStrategyId("new1")))
    XCTAssertFalse(container.isRegistered(id: LockmanStrategyId("new2")))
  }
  
  // MARK: - Resolution Tests
  
  func testResolveRegisteredStrategy() throws {
    let strategy = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("test")
    
    try container.register(id: id, strategy: strategy)
    
    let resolved: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: id)
    XCTAssertNotNil(resolved)
    XCTAssertEqual(resolved.strategyId, strategy.strategyId)
  }
  
  func testResolveByType() throws {
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)
    
    let resolved = try container.resolve(LockmanSingleExecutionStrategy.self)
    XCTAssertNotNil(resolved)
  }
  
  func testResolveUnregisteredIdThrows() {
    let unknownId = LockmanStrategyId("unknown")
    
    XCTAssertThrowsError(
      try container.resolve(id: unknownId, expecting: LockmanSingleExecutionInfo.self)
    ) { error in
      guard case LockmanRegistrationError.strategyNotRegistered(let id) = error else {
        XCTFail("Expected strategyNotRegistered error")
        return
      }
      XCTAssertEqual(id, unknownId.value)
    }
  }
  
  func testResolveWithWrongInfoTypeThrows() throws {
    let strategy = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("test")
    
    try container.register(id: id, strategy: strategy)
    
    // Try to resolve with wrong info type
    XCTAssertThrowsError(
      try container.resolve(id: id, expecting: LockmanPriorityBasedInfo.self)
    ) { error in
      guard case LockmanRegistrationError.strategyNotRegistered = error else {
        XCTFail("Expected strategyNotRegistered error")
        return
      }
    }
  }
  
  // MARK: - Information Query Tests
  
  func testIsRegisteredWithId() throws {
    let id = LockmanStrategyId("test")
    
    XCTAssertFalse(container.isRegistered(id: id))
    
    try container.register(id: id, strategy: LockmanSingleExecutionStrategy())
    
    XCTAssertTrue(container.isRegistered(id: id))
  }
  
  func testIsRegisteredWithType() throws {
    XCTAssertFalse(container.isRegistered(LockmanSingleExecutionStrategy.self))
    
    try container.register(LockmanSingleExecutionStrategy())
    
    XCTAssertTrue(container.isRegistered(LockmanSingleExecutionStrategy.self))
  }
  
  func testRegisteredStrategyInfo() throws {
    let id1 = LockmanStrategyId("first")
    let id2 = LockmanStrategyId("second")
    
    try container.register(id: id1, strategy: LockmanSingleExecutionStrategy())
    Thread.sleep(forTimeInterval: 0.01) // Ensure different timestamps
    try container.register(id: id2, strategy: LockmanPriorityBasedStrategy())
    
    let info = container.registeredStrategyInfo()
    
    XCTAssertEqual(info.count, 2)
    XCTAssertEqual(info[0].id, id1)
    XCTAssertEqual(info[1].id, id2)
    XCTAssertTrue(info[0].registeredAt < info[1].registeredAt)
    XCTAssertTrue(info[0].typeName.contains("SingleExecution"))
    XCTAssertTrue(info[1].typeName.contains("PriorityBased"))
  }
  
  func testGetAllStrategies() throws {
    try container.register(LockmanSingleExecutionStrategy())
    try container.register(LockmanPriorityBasedStrategy())
    try container.register(LockmanConcurrencyLimitedStrategy())
    
    let allStrategies = container.getAllStrategies()
    
    XCTAssertEqual(allStrategies.count, 3)
    
    let strategyIds = Set(allStrategies.map { $0.0 })
    XCTAssertTrue(strategyIds.contains(.singleExecution))
    XCTAssertTrue(strategyIds.contains(.priorityBased))
    XCTAssertTrue(strategyIds.contains(.concurrencyLimited))
  }
  
  // MARK: - Cleanup Tests
  
  func testCleanUpAllStrategies() throws {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let boundaryId = AnyLockmanBoundaryId("test")
    
    try container.register(strategy1)
    try container.register(strategy2)
    
    // Add some locks
    strategy1.lockAcquired(id: boundaryId, info: LockmanSingleExecutionInfo(actionId: "action1"))
    strategy2.lockAcquired(id: boundaryId, info: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium))
    
    // Clean up through container
    container.cleanUp()
    
    // Verify locks were cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
  }
  
  func testCleanUpByBoundaryId() throws {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId1 = AnyLockmanBoundaryId("boundary1")
    let boundaryId2 = AnyLockmanBoundaryId("boundary2")
    
    try container.register(strategy)
    
    // Add locks to both boundaries
    strategy.lockAcquired(id: boundaryId1, info: LockmanSingleExecutionInfo(actionId: "action1"))
    strategy.lockAcquired(id: boundaryId2, info: LockmanSingleExecutionInfo(actionId: "action2"))
    
    // Clean up only boundary1
    container.cleanUp(id: boundaryId1)
    
    // Verify only boundary1 was cleaned
    XCTAssertNil(strategy.getCurrentLocks()[boundaryId1])
    XCTAssertNotNil(strategy.getCurrentLocks()[boundaryId2])
  }
  
  // MARK: - Unregister Tests
  
  func testUnregisterById() throws {
    let id = LockmanStrategyId("test")
    try container.register(id: id, strategy: LockmanSingleExecutionStrategy())
    
    XCTAssertTrue(container.isRegistered(id: id))
    
    let wasRemoved = container.unregister(id: id)
    
    XCTAssertTrue(wasRemoved)
    XCTAssertFalse(container.isRegistered(id: id))
    XCTAssertEqual(container.strategyCount(), 0)
  }
  
  func testUnregisterByType() throws {
    try container.register(LockmanSingleExecutionStrategy())
    
    XCTAssertTrue(container.isRegistered(LockmanSingleExecutionStrategy.self))
    
    let wasRemoved = container.unregister(LockmanSingleExecutionStrategy.self)
    
    XCTAssertTrue(wasRemoved)
    XCTAssertFalse(container.isRegistered(LockmanSingleExecutionStrategy.self))
  }
  
  func testUnregisterNonExistentStrategy() {
    let wasRemoved = container.unregister(id: LockmanStrategyId("nonexistent"))
    
    XCTAssertFalse(wasRemoved)
  }
  
  func testUnregisterCallsCleanUp() throws {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = AnyLockmanBoundaryId("test")
    let id = LockmanStrategyId("test")
    
    try container.register(id: id, strategy: strategy)
    
    // Add a lock
    strategy.lockAcquired(id: boundaryId, info: LockmanSingleExecutionInfo(actionId: "action"))
    XCTAssertFalse(strategy.getCurrentLocks().isEmpty)
    
    // Unregister should clean up
    container.unregister(id: id)
    
    XCTAssertTrue(strategy.getCurrentLocks().isEmpty)
  }
  
  func testRemoveAllStrategies() throws {
    try container.register(LockmanSingleExecutionStrategy())
    try container.register(LockmanPriorityBasedStrategy())
    try container.register(LockmanConcurrencyLimitedStrategy())
    
    XCTAssertEqual(container.strategyCount(), 3)
    
    container.removeAllStrategies()
    
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertTrue(container.registeredStrategyIds().isEmpty)
  }
  
  // MARK: - Thread Safety Tests
  
  func testConcurrentRegistration() throws {
    let expectation = expectation(description: "All registrations complete")
    expectation.expectedFulfillmentCount = 100
    
    let queue = DispatchQueue(label: "test", attributes: .concurrent)
    var errors: [Error] = []
    let errorLock = NSLock()
    
    for i in 0..<100 {
      queue.async {
        do {
          let id = LockmanStrategyId("strategy-\(i)")
          try self.container.register(id: id, strategy: LockmanSingleExecutionStrategy())
        } catch {
          errorLock.lock()
          errors.append(error)
          errorLock.unlock()
        }
        expectation.fulfill()
      }
    }
    
    wait(for: [expectation], timeout: 5.0)
    
    XCTAssertTrue(errors.isEmpty, "Registration errors: \(errors)")
    XCTAssertEqual(container.strategyCount(), 100)
  }
  
  func testConcurrentResolution() throws {
    // Register strategies first
    for i in 0..<10 {
      let id = LockmanStrategyId("strategy-\(i)")
      try container.register(id: id, strategy: LockmanSingleExecutionStrategy())
    }
    
    let expectation = expectation(description: "All resolutions complete")
    expectation.expectedFulfillmentCount = 100
    
    let queue = DispatchQueue(label: "test", attributes: .concurrent)
    
    for _ in 0..<100 {
      queue.async {
        let randomId = LockmanStrategyId("strategy-\(Int.random(in: 0..<10))")
        do {
          let _: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try self.container.resolve(id: randomId)
        } catch {
          XCTFail("Resolution failed: \(error)")
        }
        expectation.fulfill()
      }
    }
    
    wait(for: [expectation], timeout: 5.0)
  }
  
  // MARK: - Complex Scenario Tests
  
  func testMixedStrategyTypes() throws {
    // Register different strategy types
    try container.register(id: .singleExecution, strategy: LockmanSingleExecutionStrategy())
    try container.register(id: .priorityBased, strategy: LockmanPriorityBasedStrategy())
    try container.register(id: .concurrencyLimited, strategy: LockmanConcurrencyLimitedStrategy())
    
    // Custom configured strategies
    try container.register(
      id: LockmanStrategyId("high-concurrency"),
      strategy: LockmanConcurrencyLimitedStrategy()
    )
    
    XCTAssertEqual(container.strategyCount(), 4)
    
    // Resolve each type
    let single: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: .singleExecution)
    let priority: AnyLockmanStrategy<LockmanPriorityBasedInfo> = try container.resolve(id: .priorityBased)
    let concurrent: AnyLockmanStrategy<LockmanConcurrencyLimitedInfo> = try container.resolve(id: .concurrencyLimited)
    
    XCTAssertNotNil(single)
    XCTAssertNotNil(priority)
    XCTAssertNotNil(concurrent)
  }
  
  func testStrategyLifecycle() throws {
    let id = LockmanStrategyId("lifecycle-test")
    let boundaryId = AnyLockmanBoundaryId("test")
    
    // Register
    try container.register(id: id, strategy: LockmanSingleExecutionStrategy())
    
    // Resolve and use
    let strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: id)
    let info = LockmanSingleExecutionInfo(actionId: "test")
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info), .success)
    strategy.lock(id: boundaryId, info: info)
    
    // Clean up through container
    container.cleanUp(id: boundaryId)
    
    // Unregister
    let wasRemoved = container.unregister(id: id)
    XCTAssertTrue(wasRemoved)
    
    // Verify it's gone
    XCTAssertThrowsError(try container.resolve(id: id, expecting: LockmanSingleExecutionInfo.self))
  }
}