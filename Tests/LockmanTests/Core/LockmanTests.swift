import Foundation
import XCTest

@testable import Lockman

// MARK: - Helper Extensions

extension AnyLockmanStrategy {
  func checkAndLock<B: LockmanBoundaryId>(
    id: B,
    info: I
  ) -> LockmanResult {
    let result = canLock(boundaryId: id, info: info)
    switch result {
    case .success:
      lock(boundaryId: id, info: info)
    case .successWithPrecedingCancellation:
      lock(boundaryId: id, info: info)
    case .cancel(_):
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
  var strategyId: LockmanStrategyId { LockmanStrategyId(type: MockLockmanStrategy.self) }

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
    boundaryId _: B,
    info _: MockLockmanInfo
  ) -> LockmanResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(
    boundaryId _: B,
    info _: MockLockmanInfo
  ) {}

  func unlock<B: LockmanBoundaryId>(boundaryId _: B, info _: MockLockmanInfo) {}

  func cleanUp() {
    lock.withLock {
      cleanUpCallCount += 1
    }
  }

  func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    lock.withLock {
      cleanUpWithIdCallCount += 1
      lastCleanUpId = boundaryId
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

final class LockmanFacadeTests: XCTestCase {
  // MARK: - Container Access Tests

  func testDefaultContainerAccess() async throws {
    let container = LockmanManager.container

    // The default container should already have strategies registered
    // Let's verify we can resolve the pre-registered strategies
    let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
    let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

    // With type erasure, we verify types instead of identity
    XCTAssertTrue(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    XCTAssertTrue(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  func testDefaultContainerIsSingleton() async throws {
    let container1 = LockmanManager.container
    let container2 = LockmanManager.container

    XCTAssertTrue(container1 === container2)
  }

  // MARK: - Cleanup Tests

  func testGlobalCleanupDelegatesToContainer() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await LockmanManager.withTestContainer(testContainer) {
      LockmanManager.cleanup.all()

      XCTAssertEqual(mockStrategy.getCleanUpCallCount(), 1)
      XCTAssertEqual(mockStrategy.getCleanUpWithIdCallCount(), 0)
    }
  }

  func testTargetedCleanupDelegatesToContainer() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let boundaryId = MockBoundaryId(value: "test")
    try? testContainer.register(mockStrategy)

    await LockmanManager.withTestContainer(testContainer) {
      LockmanManager.cleanup.boundary(boundaryId)

      XCTAssertEqual(mockStrategy.getCleanUpCallCount(), 0)
      XCTAssertEqual(mockStrategy.getCleanUpWithIdCallCount(), 1)
      XCTAssertEqual((mockStrategy.getLastCleanUpId() as? MockBoundaryId)?.value, "test")
    }
  }

  func testMultipleCleanupCalls() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let boundaryId1 = MockBoundaryId(value: "test1")
    let boundaryId2 = MockBoundaryId(value: "test2")
    try? testContainer.register(mockStrategy)

    await LockmanManager.withTestContainer(testContainer) {
      LockmanManager.cleanup.all()
      LockmanManager.cleanup.boundary(boundaryId1)
      LockmanManager.cleanup.all()
      LockmanManager.cleanup.boundary(boundaryId2)

      XCTAssertEqual(mockStrategy.getCleanUpCallCount(), 2)
      XCTAssertEqual(mockStrategy.getCleanUpWithIdCallCount(), 2)
      XCTAssertEqual((mockStrategy.getLastCleanUpId() as? MockBoundaryId)?.value, "test2")
    }
  }

  // MARK: - Test Container Tests

  func testTestContainerIsolation() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    // Outside test container scope - should use default container
    let defaultContainer = LockmanManager.container
    let defaultStrategy = try defaultContainer.resolve(LockmanSingleExecutionStrategy.self)
    XCTAssertTrue(type(of: defaultStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)

    // Inside test container scope - should use test container
    await LockmanManager.withTestContainer(testContainer) {
      let containerInScope = LockmanManager.container
      XCTAssertTrue(containerInScope === testContainer)

      do {
        let resolvedMock = try containerInScope.resolve(MockLockmanStrategy.self)
        XCTAssertTrue(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
      } catch {
        XCTFail("Should be able to resolve mock strategy")
      }
    }

    // Back outside - should use default container again
    let containerAfter = LockmanManager.container
    XCTAssertTrue(containerAfter === defaultContainer)
  }

  func testNestedTestContainers() async throws {
    let outerContainer = LockmanStrategyContainer()
    let innerContainer = LockmanStrategyContainer()
    let outerStrategy = MockLockmanStrategy()
    let innerStrategy = MockLockmanStrategy()

    try? outerContainer.register(outerStrategy)
    try? innerContainer.register(innerStrategy)

    await LockmanManager.withTestContainer(outerContainer) {
      let container1 = LockmanManager.container
      XCTAssertTrue(container1 === outerContainer)

      await LockmanManager.withTestContainer(innerContainer) {
        let container2 = LockmanManager.container
        XCTAssertTrue(container2 === innerContainer)

        LockmanManager.cleanup.all()
        XCTAssertEqual(innerStrategy.getCleanUpCallCount(), 1)
        XCTAssertEqual(outerStrategy.getCleanUpCallCount(), 0)
      }

      // Back to outer container
      let container3 = LockmanManager.container
      XCTAssertTrue(container3 === outerContainer)

      LockmanManager.cleanup.all()
      XCTAssertEqual(outerStrategy.getCleanUpCallCount(), 1)
      XCTAssertEqual(innerStrategy.getCleanUpCallCount(), 1)  // Should not increase
    }
  }

  func testTestContainerWithThrowingOperation() async throws {
    struct TestError: Error {}

    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    do {
      try await LockmanManager.withTestContainer(testContainer) {
        let container = LockmanManager.container
        XCTAssertTrue(container === testContainer)

        throw TestError()
      }
      XCTFail("Should have thrown TestError")
    } catch is TestError {
      // Expected
    } catch {
      XCTFail("Should have thrown TestError, got \(error)")
    }

    // Should be back to default container
    let defaultContainer = LockmanManager.container
    XCTAssertFalse(defaultContainer === testContainer)
  }

  func testTestContainerWithReturnValue() async throws {
    let testContainer = LockmanStrategyContainer()

    let result = await LockmanManager.withTestContainer(testContainer) {
      "test result"
    }

    XCTAssertEqual(result, "test result")
  }

  // MARK: - Concurrent Access Tests

  func testConcurrentAccessToDefaultContainer() async throws {
    let containers = await withTaskGroup(of: LockmanStrategyContainer.self) { group in
      for _ in 0..<100 {
        group.addTask {
          LockmanManager.container
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
      XCTFail("Expected at least one container")
      return
    }
    XCTAssertTrue(containers.allSatisfy { $0 === firstContainer })
  }

  func testConcurrentCleanupOperations() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await LockmanManager.withTestContainer(testContainer) {
      await withTaskGroup(of: Void.self) { group in
        // Global cleanup tasks
        for _ in 0..<50 {
          group.addTask {
            LockmanManager.cleanup.all()
          }
        }

        // Targeted cleanup tasks
        for i in 0..<50 {
          group.addTask {
            LockmanManager.cleanup.boundary(MockBoundaryId(value: "boundary\(i)"))
          }
        }
      }

      // Should have received all cleanup calls
      XCTAssertGreaterThanOrEqual(mockStrategy.getCleanUpCallCount(), 50)
      XCTAssertGreaterThanOrEqual(mockStrategy.getCleanUpWithIdCallCount(), 50)
    }
  }

  func testConcurrentTestContainerOperations() async throws {
    // Test that multiple concurrent test containers don't interfere
    await withTaskGroup(of: Bool.self) { group in
      for _ in 0..<10 {
        group.addTask {
          let testContainer = LockmanStrategyContainer()
          let mockStrategy = MockLockmanStrategy()
          try? testContainer.register(mockStrategy)

          return await LockmanManager.withTestContainer(testContainer) {
            let container = LockmanManager.container
            let isCorrectContainer = container === testContainer

            LockmanManager.cleanup.all()
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
      XCTAssertTrue(results.allSatisfy { $0 })
    }
  }

  // MARK: - Default Container Strategy Tests

  func testDefaultContainerHasRequiredStrategies() async throws {
    let container = LockmanManager.container

    // Should be able to resolve both default strategies
    let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
    let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

    // With type erasure, we verify types instead of identity
    XCTAssertTrue(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    XCTAssertTrue(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  func testDefaultStrategiesAreFunctional() async throws {
    // Test that default strategies can be used for cleanup without errors
    LockmanManager.cleanup.all()
    LockmanManager.cleanup.boundary(MockBoundaryId(value: "test"))

    // No assertions needed - just verify no crashes occur
  }

  // MARK: - Type Erasure Tests

  func testTypeErasureFunctionality() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    try? testContainer.register(mockStrategy)

    await LockmanManager.withTestContainer(testContainer) {
      let resolvedStrategy: AnyLockmanStrategy<MockLockmanInfo>
      do {
        resolvedStrategy = try testContainer.resolve(MockLockmanStrategy.self)
      } catch {
        XCTFail("Unexpected error: \(error)")
        return
      }

      // Test checkAndLock helper extension
      let boundaryId = MockBoundaryId(value: "test")
      let info = MockLockmanInfo(actionId: "action")

      let result = resolvedStrategy.checkAndLock(id: boundaryId, info: info)
      XCTAssertEqual(result, .success)

      // Test individual operations
      let canLockResult = resolvedStrategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(canLockResult, .success)

      resolvedStrategy.lock(boundaryId: boundaryId, info: info)
      resolvedStrategy.unlock(boundaryId: boundaryId, info: info)
      resolvedStrategy.cleanUp()
      resolvedStrategy.cleanUp(boundaryId: boundaryId)

      // Verify calls were made
      XCTAssertEqual(mockStrategy.getCleanUpCallCount(), 1)
      XCTAssertEqual(mockStrategy.getCleanUpWithIdCallCount(), 1)
    }
  }
}

// MARK: - Integration Tests

final class LockmanIntegrationTests: XCTestCase {
  func testIntegrationPotential() async throws {
    // This test verifies that the container setup would work with Effect.lock
    let testContainer = LockmanStrategyContainer()
    try? testContainer.register(LockmanSingleExecutionStrategy.shared)
    try? testContainer.register(LockmanPriorityBasedStrategy.shared)

    try await LockmanManager.withTestContainer(testContainer) {
      let container = LockmanManager.container

      // Should be able to resolve strategies that Effect.lock would need
      let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
      let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

      XCTAssertTrue(type(of: singleStrategy) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
      XCTAssertTrue(type(of: priorityStrategy) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
    }
  }

  func testMultipleTestScenariosInParallel() async throws {
    await withTaskGroup(of: Bool.self) { group in
      // Scenario 1: Basic cleanup test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await LockmanManager.withTestContainer(container) {
          LockmanManager.cleanup.all()
          return strategy.getCleanUpCallCount() == 1
        }
      }

      // Scenario 2: Targeted cleanup test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await LockmanManager.withTestContainer(container) {
          LockmanManager.cleanup.boundary(MockBoundaryId(value: "test"))
          return strategy.getCleanUpWithIdCallCount() == 1
        }
      }

      // Scenario 3: Container isolation test
      group.addTask {
        let container = LockmanStrategyContainer()
        return await LockmanManager.withTestContainer(container) {
          LockmanManager.container === container
        }
      }

      // Scenario 4: Type erasure test
      group.addTask {
        let container = LockmanStrategyContainer()
        let strategy = MockLockmanStrategy()
        try? container.register(strategy)

        return await LockmanManager.withTestContainer(container) {
          do {
            let resolved = try container.resolve(MockLockmanStrategy.self)
            let result = resolved.canLock(
              boundaryId: MockBoundaryId(value: "test"),
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

      XCTAssertEqual(results.count, 4)
      XCTAssertTrue(results.allSatisfy { $0 })
    }
  }
}
