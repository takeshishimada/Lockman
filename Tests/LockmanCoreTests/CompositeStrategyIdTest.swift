import Testing
@testable import LockmanCore

@Suite("Composite Strategy ID Generation Tests")
struct CompositeStrategyIdTest {
  @Test("CompositeStrategy2 generates correct strategyId")
  func compositeStrategy2GeneratesCorrectId() {
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

    #expect(composite.strategyId == expectedId)
    // The actual IDs include the module name
    #expect(composite.strategyId.value == "CompositeStrategy2:LockmanCore.LockmanPriorityBasedStrategy+LockmanCore.LockmanSingleExecutionStrategy")
  }

  @Test("CompositeStrategy3 generates correct strategyId")
  func compositeStrategy3GeneratesCorrectId() {
    let strategy1 = LockmanPriorityBasedStrategy()
    let strategy2 = LockmanSingleExecutionStrategy()
    let strategy3 = LockmanGroupCoordinationStrategy()

    let composite = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    // Check that the strategyId is correctly generated
    let expectedConfig = "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)"
    let expectedId = LockmanStrategyId(
      name: "CompositeStrategy3",
      configuration: expectedConfig
    )

    #expect(composite.strategyId == expectedId)
    #expect(composite.strategyId.value == "CompositeStrategy3:LockmanCore.LockmanPriorityBasedStrategy+LockmanCore.LockmanSingleExecutionStrategy+LockmanCore.LockmanGroupCoordinationStrategy")
  }

  @Test("makeStrategyId static method works correctly")
  func makeStrategyIdStaticMethodWorks() {
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

    #expect(staticId == composite.strategyId)
  }

  @Test("Different strategy combinations produce different IDs")
  func differentCombinationsProduceDifferentIds() {
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
    #expect(composite1.strategyId != composite2.strategyId)
    #expect(composite1.strategyId != composite3.strategyId)
    #expect(composite2.strategyId != composite3.strategyId)

    // Verify the actual values (include module names)
    #expect(composite1.strategyId.value == "CompositeStrategy2:LockmanCore.LockmanPriorityBasedStrategy+LockmanCore.LockmanSingleExecutionStrategy")
    #expect(composite2.strategyId.value == "CompositeStrategy2:LockmanCore.LockmanSingleExecutionStrategy+LockmanCore.LockmanPriorityBasedStrategy")
    #expect(composite3.strategyId.value == "CompositeStrategy2:LockmanCore.LockmanPriorityBasedStrategy+LockmanCore.LockmanGroupCoordinationStrategy")
  }
}
