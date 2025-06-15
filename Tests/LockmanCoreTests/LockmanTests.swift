
import Foundation
import Testing
@testable import LockmanCore

// MARK: - Helper Extensions

extension AnyLockmanStrategy {
  func checkAndLock<B: LockmanBoundaryId>(
    id: B,
    info: I
  ) -> LockResult {
    let result = canLock(id: id, info: info)
    switch result {
    case .success:
      lock(id: id, info: info)
    case .successWithPrecedingCancellation:
      lock(id: id, info: info)
    case .failure:
      break
    }
    return result
  }
}

// MARK: - Test Helpers

// Mock LockmanInfo for testing
private struct MockLockmanInfo: LockmanInfo {
  let actionId: String
  let uniqueId: UUID = .init()

  var debugDescription: String {
    "MockLockmanInfo(actionId: \(actionId))"
  }
}

// Mock BoundaryId for testing
private struct MockBoundaryId: LockmanBoundaryId {
  let value: String
}

// Mock Strategy for testing cleanup behavior - now conforms to LockmanStrategy protocol
private final class MockLockmanStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }

  static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }

  var cleanUpCallCount = 0
  var cleanUpWithIdCallCount = 0
  var lastCleanUpId: (any LockmanBoundaryId)?
  private let lock = NSLock()

  func canLock<B: LockmanBoundaryId>(
    id _: B,
    info _: MockLockmanInfo
  ) -> LockResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(
    id _: B,
    info _: MockLockmanInfo
  ) {}

  func unlock<B: LockmanBoundaryId>(id _: B, info _: MockLockmanInfo) {}

  func cleanUp() {
    lock.withLock {
      cleanUpCallCount += 1
    }
  }

  func cleanUp<B: LockmanBoundaryId>(id: B) {
    lock.withLock {
      cleanUpWithIdCallCount += 1
      lastCleanUpId = id
    }
  }

  func getCleanUpCallCount() -> Int {
    lock.withLock { cleanUpCallCount }
  }

  func getCleanUpWithIdCallCount() -> Int {
    lock.withLock { cleanUpWithIdCallCount }
  }

  func getLastCleanUpId() -> (any LockmanBoundaryId)? {
    lock.withLock { lastCleanUpId }
  }

  func resetCounts() {
    lock.withLock {
      cleanUpCallCount = 0
      cleanUpWithIdCallCount = 0
      lastCleanUpId = nil
    }
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    [:]
  }
}

// MARK: - Lockman Facade Tests

@Suite("Lockman Facade Tests")
struct LockmanFacadeTests {
  // MARK: - Container Access Tests

  @Test("Default container access")
  func testDefaultContainerAccess() throws {
    let container = Lockman.container

    // The default container should already have strategies registered
    // Let's verify we can resolve the pre-registered strategies
    let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
    let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

    // With type erasure, we verify types instead of identity
    #expect(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    #expect(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  @Test("Default container is singleton")
  func testDefaultContainerIsSingleton() {
    let container1 = Lockman.container
    let container2 = Lockman.container

    #expect(container1 === container2)
  }

  // MARK: - Cleanup Tests

  @Test("Global cleanup delegates to container")
  func testGlobalCleanupDelegatesToContainer() async {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      Lockman.cleanup.all()

      #expect(mockStrategy.getCleanUpCallCount() == 1)
      #expect(mockStrategy.getCleanUpWithIdCallCount() == 0)
    }
  }

  @Test("Targeted cleanup delegates to container")
  func testTargetedCleanupDelegatesToContainer() async {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let boundaryId = MockBoundaryId(value: "test")
    try? testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      Lockman.cleanup.boundary(boundaryId)

      #expect(mockStrategy.getCleanUpCallCount() == 0)
      #expect(mockStrategy.getCleanUpWithIdCallCount() == 1)
      #expect((mockStrategy.getLastCleanUpId() as? MockBoundaryId)?.value == "test")
    }
  }

  @Test("Multiple cleanup calls")
  func testMultipleCleanupCalls() async {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let boundaryId1 = MockBoundaryId(value: "test1")
    let boundaryId2 = MockBoundaryId(value: "test2")
    try? testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      Lockman.cleanup.all()
      Lockman.cleanup.boundary(boundaryId1)
      Lockman.cleanup.all()
      Lockman.cleanup.boundary(boundaryId2)

      #expect(mockStrategy.getCleanUpCallCount() == 2)
      #expect(mockStrategy.getCleanUpWithIdCallCount() == 2)
      #expect((mockStrategy.getLastCleanUpId() as? MockBoundaryId)?.value == "test2")
    }
  }

  // MARK: - Test Container Tests

  @Test("Test container isolation")
  func testTestContainerIsolation() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    // Outside test container scope - should use default container
    let defaultContainer = Lockman.container
    let defaultStrategy = try defaultContainer.resolve(LockmanSingleExecutionStrategy.self)
    #expect(type(of: defaultStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)

    // Inside test container scope - should use test container
    await Lockman.withTestContainer(testContainer) {
      let containerInScope = Lockman.container
      #expect(containerInScope === testContainer)

      do {
        let resolvedMock = try containerInScope.resolve(MockLockmanStrategy.self)
        #expect(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
      } catch {
        #expect(Bool(false), "Should be able to resolve mock strategy")
      }
    }

    // Back outside - should use default container again
    let containerAfter = Lockman.container
    #expect(containerAfter === defaultContainer)
  }

  @Test("Nested test containers")
  func testNestedTestContainers() async {
    let outerContainer = LockmanStrategyContainer()
    let innerContainer = LockmanStrategyContainer()
    let outerStrategy = MockLockmanStrategy()
    let innerStrategy = MockLockmanStrategy()

    try? outerContainer.register(outerStrategy)
    try? innerContainer.register(innerStrategy)

    await Lockman.withTestContainer(outerContainer) {
      let container1 = Lockman.container
      #expect(container1 === outerContainer)

      await Lockman.withTestContainer(innerContainer) {
        let container2 = Lockman.container
        #expect(container2 === innerContainer)

        Lockman.cleanup.all()
        #expect(innerStrategy.getCleanUpCallCount() == 1)
        #expect(outerStrategy.getCleanUpCallCount() == 0)
      }

      // Back to outer container
      let container3 = Lockman.container
      #expect(container3 === outerContainer)

      Lockman.cleanup.all()
      #expect(outerStrategy.getCleanUpCallCount() == 1)
      #expect(innerStrategy.getCleanUpCallCount() == 1) // Should not increase
    }
  }

  @Test("Test container with throwing operation")
  func testTestContainerWithThrowingOperation() async {
    struct TestError: Error {}

    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    do {
      try await Lockman.withTestContainer(testContainer) {
        let container = Lockman.container
        #expect(container === testContainer)

        throw TestError()
      }
      #expect(Bool(false), "Should have thrown TestError")
    } catch is TestError {
      // Expected
    } catch {
      #expect(Bool(false), "Should have thrown TestError, got \(error)")
    }

    // Should be back to default container
    let defaultContainer = Lockman.container
    #expect(defaultContainer !== testContainer)
  }

  @Test("Test container with return value")
  func testTestContainerWithReturnValue() async {
    let testContainer = LockmanStrategyContainer()

    let result = await Lockman.withTestContainer(testContainer) {
      "test result"
    }

    #expect(result == "test result")
  }

  // MARK: - Concurrent Access Tests

  @Test("Concurrent access to default container")
  func testConcurrentAccessToDefaultContainer() async {
    let containers = await withTaskGroup(of: LockmanStrategyContainer.self) { group in
      for _ in 0 ..< 100 {
        group.addTask {
          Lockman.container
        }
      }

      var results: [LockmanStrategyContainer] = []
      for await container in group {
        results.append(container)
      }
      return results
    }

    // All should be the same instance
    guard let firstContainer = containers.first else {
      Issue.record("Expected at least one container")
      return
    }
    #expect(containers.allSatisfy { $0 === firstContainer })
  }

  @Test("Concurrent cleanup operations")
  func testConcurrentCleanupOperations() async {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      await withTaskGroup(of: Void.self) { group in
        // Global cleanup tasks
        for _ in 0 ..< 50 {
          group.addTask {
            Lockman.cleanup.all()
          }
        }

        // Targeted cleanup tasks
        for i in 0 ..< 50 {
          group.addTask {
            Lockman.cleanup.boundary(MockBoundaryId(value: "boundary\(i)"))
          }
        }
      }

      // Should have received all cleanup calls
      #expect(mockStrategy.getCleanUpCallCount() >= 50)
      #expect(mockStrategy.getCleanUpWithIdCallCount() >= 50)
    }
  }

  @Test("Concurrent test container operations")
  func testConcurrentTestContainerOperations() async {
    // Test that multiple concurrent test containers don't interfere
    await withTaskGroup(of: Bool.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          let testContainer = LockmanStrategyContainer()
          let mockStrategy = MockLockmanStrategy()
          try? testContainer.register(mockStrategy)

          return await Lockman.withTestContainer(testContainer) {
            let container = Lockman.container
            let isCorrectContainer = container === testContainer

            Lockman.cleanup.all()
            let wasCleanedUp = mockStrategy.getCleanUpCallCount() == 1

            return isCorrectContainer && wasCleanedUp
          }
        }
      }

      var results: [Bool] = []
      for await result in group {
        results.append(result)
      }

      // All operations should have succeeded
      #expect(results.allSatisfy { $0 })
    }
  }

  // MARK: - Default Container Strategy Tests

  @Test("Default container has required strategies")
  func testDefaultContainerHasRequiredStrategies() throws {
    let container = Lockman.container

    // Should be able to resolve both default strategies
    let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
    let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

    // With type erasure, we verify types instead of identity
    #expect(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    #expect(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  @Test("Default strategies are functional")
  func testDefaultStrategiesAreFunctional() async throws {
    // Test that default strategies can be used for cleanup without errors
    Lockman.cleanup.all()
    Lockman.cleanup.boundary(MockBoundaryId(value: "test"))

    // No assertions needed - just verify no crashes occur
  }

  // MARK: - Type Erasure Tests

  @Test("Type erasure functionality")
  func testTypeErasureFunctionality() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      let resolvedStrategy: AnyLockmanStrategy<MockLockmanInfo>
      do {
        resolvedStrategy = try testContainer.resolve(MockLockmanStrategy.self)
      } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
        return
      }

      // Test checkAndLock helper extension
      let boundaryId = MockBoundaryId(value: "test")
      let info = MockLockmanInfo(actionId: "action")

      let result = resolvedStrategy.checkAndLock(id: boundaryId, info: info)
      #expect(result == .success)

      // Test individual operations
      let canLockResult = resolvedStrategy.canLock(id: boundaryId, info: info)
      #expect(canLockResult == .success)

      resolvedStrategy.lock(id: boundaryId, info: info)
      resolvedStrategy.unlock(id: boundaryId, info: info)
      resolvedStrategy.cleanUp()
      resolvedStrategy.cleanUp(id: boundaryId)

      // Verify calls were made
      #expect(mockStrategy.getCleanUpCallCount() == 1)
      #expect(mockStrategy.getCleanUpWithIdCallCount() == 1)
    }
  }
}

// MARK: - Integration Tests

@Suite("Lockman Integration Tests")
struct LockmanIntegrationTests {
  @Test("Integration with Effect.withLock would work")
  func testIntegrationPotential() async throws {
    // This test verifies that the container setup would work with Effect.withLock
    let testContainer = LockmanStrategyContainer()
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)
    try? testContainer.register(LockmanPriorityBasedStrategy.shared)

    try await Lockman.withTestContainer(testContainer) {
      let container = Lockman.container

      // Should be able to resolve strategies that Effect.withLock would need
      let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
      let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

      #expect(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
      #expect(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
    }
  }

  @Test("Multiple test scenarios in parallel")
  func testMultipleTestScenariosInParallel() async {
    await withTaskGroup(of: Bool.self) { group in
      // Scenario 1: Basic cleanup test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await Lockman.withTestContainer(container) {
          Lockman.cleanup.all()
          return strategy.getCleanUpCallCount() == 1
        }
      }

      // Scenario 2: Targeted cleanup test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await Lockman.withTestContainer(container) {
          Lockman.cleanup.boundary(MockBoundaryId(value: "test"))
          return strategy.getCleanUpWithIdCallCount() == 1
        }
      }

      // Scenario 3: Container isolation test
      group.addTask {
        let container = LockmanStrategyContainer()
        return await Lockman.withTestContainer(container) {
          Lockman.container === container
        }
      }

      // Scenario 4: Type erasure test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await Lockman.withTestContainer(container) {
          do {
            let resolved = try container.resolve(MockLockmanStrategy.self)
            let result = resolved.canLock(
              id: MockBoundaryId(value: "test"),
              info: MockLockmanInfo(actionId: "test")
            )
            return result == .success
          } catch {
            return false
          }
        }
      }

      var results: [Bool] = []
      for await result in group {
        results.append(result)
      }

      #expect(results.count == 4)
      #expect(results.allSatisfy { $0 })
    }
  }
}
