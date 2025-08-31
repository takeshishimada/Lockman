import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanStrategyContainerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: registerAll Methods Coverage

  func testRegisterAllWithHomogenousStrategies() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()

    let strategies = [
      (LockmanStrategyId("test1"), strategy1), (LockmanStrategyId("test2"), strategy2),
    ]
    try container.registerAll(strategies)

    XCTAssertTrue(container.isRegistered(id: LockmanStrategyId("test1")))
    XCTAssertTrue(container.isRegistered(id: LockmanStrategyId("test2")))
    XCTAssertEqual(container.strategyCount(), 2)
  }

  func testRegisterAllWithStrategyArrayDifferentTypes() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    try container.registerAll([strategy1])
    try container.registerAll([strategy2])

    XCTAssertEqual(container.strategyCount(), 2)
    XCTAssertTrue(container.isRegistered(LockmanSingleExecutionStrategy.self))
    XCTAssertTrue(container.isRegistered(LockmanPriorityBasedStrategy.self))
  }

  func testRegisterAllDuplicateInArrayThrows() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()

    let duplicateId = LockmanStrategyId("duplicate")
    let strategies = [(duplicateId, strategy1), (duplicateId, strategy2)]

    XCTAssertThrowsError(try container.registerAll(strategies)) { error in
      guard let registrationError = error as? LockmanRegistrationError else {
        XCTFail("Expected LockmanRegistrationError")
        return
      }
      switch registrationError {
      case .strategyAlreadyRegistered(let id):
        XCTAssertEqual(id, "duplicate")
      case .strategyNotRegistered:
        XCTFail("Unexpected strategyNotRegistered error")
      }
    }
  }

  func testRegisterAllConflictWithExistingThrows() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()

    let existingId = LockmanStrategyId("existing")
    try container.register(id: existingId, strategy: strategy1)

    let strategies = [(existingId, strategy2)]

    XCTAssertThrowsError(try container.registerAll(strategies)) { error in
      guard let registrationError = error as? LockmanRegistrationError else {
        XCTFail("Expected LockmanRegistrationError")
        return
      }
      switch registrationError {
      case .strategyAlreadyRegistered(let id):
        XCTAssertEqual(id, "existing")
      case .strategyNotRegistered:
        XCTFail("Unexpected strategyNotRegistered error")
      }
    }
  }

  // MARK: - Phase 1: Information Methods Coverage

  func testIsRegisteredWithId() throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("test")

    XCTAssertFalse(container.isRegistered(id: id))
    try container.register(id: id, strategy: strategy)
    XCTAssertTrue(container.isRegistered(id: id))
  }

  func testIsRegisteredWithType() throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()

    XCTAssertFalse(container.isRegistered(LockmanSingleExecutionStrategy.self))
    try container.register(strategy)
    XCTAssertTrue(container.isRegistered(LockmanSingleExecutionStrategy.self))
  }

  func testRegisteredStrategyIds() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    try container.register(id: LockmanStrategyId("b_second"), strategy: strategy2)
    try container.register(id: LockmanStrategyId("a_first"), strategy: strategy1)

    let ids = container.registeredStrategyIds()
    XCTAssertEqual(ids.count, 2)
    XCTAssertEqual(ids[0].value, "a_first")
    XCTAssertEqual(ids[1].value, "b_second")
  }

  func testRegisteredStrategyInfo() throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    let beforeTime = Date()

    try container.register(id: LockmanStrategyId("test"), strategy: strategy)

    let info = container.registeredStrategyInfo()
    XCTAssertEqual(info.count, 1)
    XCTAssertEqual(info[0].id.value, "test")
    XCTAssertTrue(info[0].typeName.contains("LockmanSingleExecutionStrategy"))
    XCTAssertGreaterThanOrEqual(info[0].registeredAt, beforeTime)
  }

  func testStrategyCount() throws {
    let container = LockmanStrategyContainer()
    XCTAssertEqual(container.strategyCount(), 0)

    try container.register(LockmanSingleExecutionStrategy())
    XCTAssertEqual(container.strategyCount(), 1)

    try container.register(LockmanPriorityBasedStrategy())
    XCTAssertEqual(container.strategyCount(), 2)
  }

  func testGetAllStrategies() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    try container.register(id: LockmanStrategyId("test1"), strategy: strategy1)
    try container.register(id: LockmanStrategyId("test2"), strategy: strategy2)

    let allStrategies = container.getAllStrategies()
    XCTAssertEqual(allStrategies.count, 2)

    let ids = allStrategies.map { $0.0.value }.sorted()
    XCTAssertEqual(ids, ["test1", "test2"])

    // Verify strategies are returned as type-erased but accessible
    let strategyTypes = allStrategies.map { $0.1.strategyId.value }.sorted()
    XCTAssertTrue(strategyTypes.allSatisfy { !$0.isEmpty })
  }

  // MARK: - Phase 1: Unregister Methods Coverage

  func testUnregisterWithId() throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    let id = LockmanStrategyId("test")

    try container.register(id: id, strategy: strategy)
    XCTAssertTrue(container.isRegistered(id: id))

    let wasRemoved = container.unregister(id: id)
    XCTAssertTrue(wasRemoved)
    XCTAssertFalse(container.isRegistered(id: id))
    XCTAssertEqual(container.strategyCount(), 0)
  }

  func testUnregisterWithIdNotFound() throws {
    let container = LockmanStrategyContainer()
    let id = LockmanStrategyId("nonexistent")

    let wasRemoved = container.unregister(id: id)
    XCTAssertFalse(wasRemoved)
  }

  func testUnregisterWithType() throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()

    try container.register(strategy)
    XCTAssertTrue(container.isRegistered(LockmanSingleExecutionStrategy.self))

    let wasRemoved = container.unregister(LockmanSingleExecutionStrategy.self)
    XCTAssertTrue(wasRemoved)
    XCTAssertFalse(container.isRegistered(LockmanSingleExecutionStrategy.self))
  }

  func testRemoveAllStrategies() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    try container.register(strategy1)
    try container.register(strategy2)
    XCTAssertEqual(container.strategyCount(), 2)

    container.removeAllStrategies()
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertFalse(container.isRegistered(LockmanSingleExecutionStrategy.self))
    XCTAssertFalse(container.isRegistered(LockmanPriorityBasedStrategy.self))
  }

  func testGetAllStrategiesWithEmptyContainer() {
    let container = LockmanStrategyContainer()
    let allStrategies = container.getAllStrategies()
    XCTAssertEqual(allStrategies.count, 0)
    XCTAssertTrue(allStrategies.isEmpty)
  }

}
