import XCTest

@testable import Lockman

final class LockmanCompositeStrategyTests: XCTestCase {

  // MARK: - LockmanCompositeStrategy2 Tests

  func testCompositeStrategy2Initialization() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    XCTAssertEqual(composite.strategyId.name, "CompositeStrategy2")
    XCTAssertTrue(composite.strategyId.value.contains(strategy1.strategyId.value))
    XCTAssertTrue(composite.strategyId.value.contains(strategy2.strategyId.value))
  }

  func testCompositeStrategy2MakeStrategyId() {
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

  func testCompositeStrategy2MakeStrategyIdWithoutParameters() {
    let strategyId = LockmanCompositeStrategy2<
      LockmanSingleExecutionInfo,
      LockmanSingleExecutionStrategy,
      LockmanPriorityBasedInfo,
      LockmanPriorityBasedStrategy
    >.makeStrategyId()

    XCTAssertEqual(strategyId.name, "CompositeStrategy2")
    XCTAssertNil(strategyId.configuration)
  }

  func testCompositeStrategy2CanLockSuccess() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )

    // Both strategies should allow locking
    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCompositeStrategy2CanLockFailureStrategy1() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    let info2 = LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)

    // Lock with strategy1 first
    strategy1.lockAcquired(id: boundaryId, info: info1)

    let compositeInfo = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Should fail because strategy1 already has a lock
    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure:
      // Expected
      break
    default:
      XCTFail("Expected failure but got \(result)")
    }

    // Cleanup
    strategy1.lockReleased(id: boundaryId, info: info1)
  }

  func testCompositeStrategy2CanLockFailureStrategy2() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    let info2 = LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    let blockingInfo2 = LockmanPriorityBasedInfo(
      actionId: "blocking",
      priority: .high(.preferLater)
    )

    // Lock with strategy2 first with higher priority
    strategy2.lockAcquired(id: boundaryId, info: blockingInfo2)

    let compositeInfo = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )

    // Should fail because strategy2 has a higher priority lock
    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .failure:
      // Expected
      break
    default:
      XCTFail("Expected failure but got \(result)")
    }

    // Cleanup
    strategy2.lockReleased(id: boundaryId, info: blockingInfo2)
  }

  func testCompositeStrategy2CanLockWithCancellation() {
    // Create a mock strategy that returns successWithPrecedingCancellation
    let strategy1 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.mockError))
    let strategy2 = LockmanSingleExecutionStrategy()

    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let compositeInfo = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanSingleExecutionInfo(actionId: "action2")
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .successWithPrecedingCancellation(let error):
      XCTAssertTrue(error is TestError)
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }
  }

  func testCompositeStrategy2LockAndUnlock() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Verify both strategies have locks
    XCTAssertFalse(strategy1.getCurrentLocks().isEmpty)
    XCTAssertFalse(strategy2.getCurrentLocks().isEmpty)

    // Unlock
    composite.unlock(id: boundaryId, info: info)

    // Verify both strategies released locks
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
  }

  func testCompositeStrategy2CleanUp() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Clean up all
    composite.cleanUp()

    // Verify all locks are cleared
    XCTAssertTrue(strategy1.getCurrentLocks().isEmpty)
    XCTAssertTrue(strategy2.getCurrentLocks().isEmpty)
  }

  func testCompositeStrategy2CleanUpBoundary() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId1 = AnyLockmanBoundaryId("test1")
    let boundaryId2 = AnyLockmanBoundaryId("test2")

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

    // Verify boundary1 locks are cleared but boundary2 locks remain
    let currentLocks = composite.getCurrentLocks()
    XCTAssertNil(currentLocks[boundaryId1])
    XCTAssertNotNil(currentLocks[boundaryId2])

    // Cleanup
    composite.cleanUp()
  }

  func testCompositeStrategy2GetCurrentLocks() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium)
    )

    // Initially empty
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Should have locks from both strategies
    let currentLocks = composite.getCurrentLocks()
    XCTAssertEqual(currentLocks[boundaryId]?.count, 2)

    // Cleanup
    composite.cleanUp()
  }

  // MARK: - LockmanCompositeStrategy3 Tests

  func testCompositeStrategy3Initialization() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    XCTAssertEqual(composite.strategyId.name, "CompositeStrategy3")
    XCTAssertTrue(composite.strategyId.value.contains(strategy1.strategyId.value))
    XCTAssertTrue(composite.strategyId.value.contains(strategy2.strategyId.value))
    XCTAssertTrue(composite.strategyId.value.contains(strategy3.strategyId.value))
  }

  func testCompositeStrategy3CanLockSuccess() {
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanConcurrencyLimitedStrategy()

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo3(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: 3
      )
    )

    let result = composite.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)
  }

  func testCompositeStrategy3CoordinateResultsWithMixedResults() {
    let strategy1 = MockLockmanStrategy(canLockResult: .success)
    let strategy2 = MockLockmanStrategy(
      canLockResult: .successWithPrecedingCancellation(error: TestError.mockError))
    let strategy3 = MockLockmanStrategy(canLockResult: .success)

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let compositeInfo = LockmanCompositeInfo3(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "action1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "action2"),
      lockmanInfoForStrategy3: MockLockmanInfo(actionId: "action3")
    )

    let result = composite.canLock(id: boundaryId, info: compositeInfo)

    switch result {
    case .successWithPrecedingCancellation(let error):
      XCTAssertTrue(error is TestError)
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(result)")
    }
  }

  // MARK: - LockmanCompositeStrategy4 Tests

  func testCompositeStrategy4Initialization() {
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
    XCTAssertTrue(composite.strategyId.configuration?.contains("+") ?? false)
  }

  func testCompositeStrategy4GetCurrentLocks() {
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

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "action1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "action2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group1"),
        limit: 3
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(actionId: "action4")
    )

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Should have locks from all 4 strategies
    let currentLocks = composite.getCurrentLocks()
    XCTAssertEqual(currentLocks[boundaryId]?.count, 4)

    // Cleanup
    composite.cleanUp()
  }

  // MARK: - LockmanCompositeStrategy5 Tests

  func testCompositeStrategy5Initialization() {
    let strategies = (
      LockmanSingleExecutionStrategy(),
      LockmanPriorityBasedStrategy(),
      LockmanConcurrencyLimitedStrategy(),
      LockmanDynamicConditionStrategy(),
      LockmanGroupCoordinationStrategy()
    )

    let composite = LockmanCompositeStrategy5(
      strategy1: strategies.0,
      strategy2: strategies.1,
      strategy3: strategies.2,
      strategy4: strategies.3,
      strategy5: strategies.4
    )

    XCTAssertEqual(composite.strategyId.name, "CompositeStrategy5")
  }

  func testCompositeStrategy5LockUnlockOrder() {
    var lockOrder: [String] = []
    var unlockOrder: [String] = []

    let strategy1 = MockOrderTrackingStrategy(
      id: "1", lockOrder: &lockOrder, unlockOrder: &unlockOrder)
    let strategy2 = MockOrderTrackingStrategy(
      id: "2", lockOrder: &lockOrder, unlockOrder: &unlockOrder)
    let strategy3 = MockOrderTrackingStrategy(
      id: "3", lockOrder: &lockOrder, unlockOrder: &unlockOrder)
    let strategy4 = MockOrderTrackingStrategy(
      id: "4", lockOrder: &lockOrder, unlockOrder: &unlockOrder)
    let strategy5 = MockOrderTrackingStrategy(
      id: "5", lockOrder: &lockOrder, unlockOrder: &unlockOrder)

    let composite = LockmanCompositeStrategy5(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4,
      strategy5: strategy5
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo5(
      lockmanInfoForStrategy1: MockLockmanInfo(actionId: "1"),
      lockmanInfoForStrategy2: MockLockmanInfo(actionId: "2"),
      lockmanInfoForStrategy3: MockLockmanInfo(actionId: "3"),
      lockmanInfoForStrategy4: MockLockmanInfo(actionId: "4"),
      lockmanInfoForStrategy5: MockLockmanInfo(actionId: "5")
    )

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Verify lock order is 1, 2, 3, 4, 5
    XCTAssertEqual(lockOrder, ["1", "2", "3", "4", "5"])

    // Unlock
    composite.unlock(id: boundaryId, info: info)

    // Verify unlock order is LIFO: 5, 4, 3, 2, 1
    XCTAssertEqual(unlockOrder, ["5", "4", "3", "2", "1"])
  }

  func testCompositeStrategy5CleanUpOrder() {
    let strategies = (
      LockmanSingleExecutionStrategy(),
      LockmanPriorityBasedStrategy(),
      LockmanConcurrencyLimitedStrategy(),
      LockmanDynamicConditionStrategy(),
      LockmanGroupCoordinationStrategy()
    )

    let composite = LockmanCompositeStrategy5(
      strategy1: strategies.0,
      strategy2: strategies.1,
      strategy3: strategies.2,
      strategy4: strategies.3,
      strategy5: strategies.4
    )

    let boundaryId = AnyLockmanBoundaryId("test")
    let info = LockmanCompositeInfo5(
      lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "1"),
      lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "2", priority: .medium),
      lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo(
        concurrencyId: AnyLockmanGroupId("group"),
        limit: 3
      ),
      lockmanInfoForStrategy4: LockmanDynamicConditionInfo(actionId: "4"),
      lockmanInfoForStrategy5: LockmanGroupCoordinatedInfo(
        actionId: "5",
        groupId: AnyLockmanGroupId("coord-group"),
        groupMode: .allOrNone
      )
    )

    // Lock
    composite.lock(id: boundaryId, info: info)

    // Clean up specific boundary
    composite.cleanUp(id: boundaryId)

    // Verify all locks are cleared
    XCTAssertTrue(composite.getCurrentLocks().isEmpty)
  }
}

// MARK: - Mock Types for Testing

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

private enum TestError: Error {
  case mockError
}
