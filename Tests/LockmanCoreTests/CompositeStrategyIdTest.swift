import XCTest

@testable import Lockman

final class CompositeStrategyIdTests: XCTestCase {
  func testCompositeStrategy2GeneratesCorrectStrategyId() async throws {
    let strategy1 = LockmanPriorityBasedStrategy.shared
    let strategy2 = LockmanSingleExecutionStrategy.shared

    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    // Check that the strategyId is correctly generated
    let expectedId = LockmanStrategyId(
      name: "CompositeStrategy2",
      configuration: "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)"
    )

    XCTAssertEqual(composite.strategyId, expectedId)
    // The actual IDs include the module name
    XCTAssertEqual(
      composite.strategyId.value,
      "CompositeStrategy2:Lockman.LockmanPriorityBasedStrategy+Lockman.LockmanSingleExecutionStrategy"
    )
  }

  func testCompositeStrategy3GeneratesCorrectStrategyId() async throws {
    let strategy1 = LockmanPriorityBasedStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()
    let strategy3 = LockmanGroupCoordinationStrategy()

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    // Check that the strategyId is correctly generated
    let expectedConfig =
      "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)"
    let expectedId = LockmanStrategyId(
      name: "CompositeStrategy3",
      configuration: expectedConfig
    )

    XCTAssertEqual(composite.strategyId, expectedId)
    XCTAssertEqual(
      composite.strategyId.value,
      "CompositeStrategy3:Lockman.LockmanPriorityBasedStrategy+Lockman.LockmanSingleExecutionStrategy+Lockman.LockmanGroupCoordinationStrategy"
    )
  }

  func testMakeStrategyIdStaticMethodWorksCorrectly() async throws {
    let strategy1 = LockmanPriorityBasedStrategy.shared
    let strategy2 = LockmanSingleExecutionStrategy.shared

    // Test static makeStrategyId
    let staticId = LockmanCompositeStrategy2.makeStrategyId(
      strategy1: strategy1,
      strategy2: strategy2
    )

    // Create instance and compare
    let composite = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )

    XCTAssertEqual(staticId, composite.strategyId)
  }

  func testDifferentStrategyCombinationsProduceDifferentIDs() async throws {
    let priority = LockmanPriorityBasedStrategy.shared
    let single = LockmanSingleExecutionStrategy.shared
    let group = LockmanGroupCoordinationStrategy.shared

    let composite1 = LockmanCompositeStrategy2(
      strategy1: priority,
      strategy2: single
    )

    let composite2 = LockmanCompositeStrategy2(
      strategy1: single,
      strategy2: priority
    )

    let composite3 = LockmanCompositeStrategy2(
      strategy1: priority,
      strategy2: group
    )

    // All should have different IDs
    XCTAssertNotEqual(composite1.strategyId, composite2.strategyId)
    XCTAssertNotEqual(composite1.strategyId, composite3.strategyId)
    XCTAssertNotEqual(composite2.strategyId, composite3.strategyId)

    // Verify the actual values (include module names)
    XCTAssertEqual(
      composite1.strategyId.value,
      "CompositeStrategy2:Lockman.LockmanPriorityBasedStrategy+Lockman.LockmanSingleExecutionStrategy"
    )
    XCTAssertEqual(
      composite2.strategyId.value,
      "CompositeStrategy2:Lockman.LockmanSingleExecutionStrategy+Lockman.LockmanPriorityBasedStrategy"
    )
    XCTAssertEqual(
      composite3.strategyId.value,
      "CompositeStrategy2:Lockman.LockmanPriorityBasedStrategy+Lockman.LockmanGroupCoordinationStrategy"
    )
  }
}
