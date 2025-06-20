import XCTest
@testable import LockmanCore

// MARK: - Test Helpers

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(_ value: String) {
    self.value = value
  }
}

// MARK: - Main Lockman Framework Tests

/// Tests for the main Lockman framework functionality.
///
/// ## Test Coverage
/// - Container management
/// - Strategy resolution
/// - Test container functionality
/// - Global state management
final class LockmanMainTests: XCTestCase {
  // MARK: - Container Management Tests

  // MARK: - Container Management Tests
  func testDefaultContainerAvailable() async throws {
      // The container should always be available
      let container = Lockman.container
      XCTAssertNotNil(container)
    }

  func testCanRegisterStrategiesInContainer() async throws {
      let testContainer = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()

      try testContainer.register(strategy)

      let resolved = try testContainer.resolve(LockmanSingleExecutionStrategy.self)
      // Type erasure returns non-optional, so just verify the type
      XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    }

  func testContainerIsolationInTests() async throws {
      let testContainer1 = LockmanStrategyContainer()
      let testContainer2 = LockmanStrategyContainer()

      let strategy1 = LockmanSingleExecutionStrategy()
      let strategy2 = LockmanPriorityBasedStrategy()

      try testContainer1.register(strategy1)
      try testContainer2.register(strategy2)

      // Test isolation
      await Lockman.withTestContainer(testContainer1) {
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          // Should succeed
        } catch {
          XCTFail("Should resolve strategy in container 1")
        }

        do {
          _ = try Lockman.container.resolve(LockmanPriorityBasedStrategy.self)
          XCTFail("Should not resolve strategy from container 2")
        } catch {
          // Expected to fail
        }
      }
    }
  // MARK: - Strategy Resolution Tests
  func testResolveRegisteredStrategy() async throws {
      let testContainer = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()
      try testContainer.register(strategy)

      await Lockman.withTestContainer(testContainer) {
        do {
          let resolved = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
        } catch {
          XCTFail("Failed to resolve registered strategy: \(error)")
        }
      }
    }

  func testResolveFailsForUnregisteredStrategy() async throws {
      let testContainer = LockmanStrategyContainer()

      await Lockman.withTestContainer(testContainer) {
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          XCTFail("Should have thrown error for unregistered strategy")
        } catch let LockmanError.strategyNotRegistered(type) {
          XCTAssertTrue(type.contains("LockmanSingleExecutionStrategy"))
        } catch {
          XCTFail("Unexpected error type: \(error)")
        }
      }
    }

  func testResolveWithTypeParameter() async throws {
      let testContainer = LockmanStrategyContainer()
      let strategy = LockmanPriorityBasedStrategy()
      try testContainer.register(strategy)

      await Lockman.withTestContainer(testContainer) {
        func genericResolve<S: LockmanStrategy>(_ type: S.Type) throws -> AnyLockmanStrategy<S.I> {
          try Lockman.container.resolve(type)
        }

        do {
          let resolved = try genericResolve(LockmanPriorityBasedStrategy.self)
          XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
        } catch {
          XCTFail("Failed to resolve with generic parameter: \(error)")
        }
      }
    }
  // MARK: - Test Container Tests
  func testTestContainerIsolation() async throws {
      let originalContainer = Lockman.container
      let testContainer = LockmanStrategyContainer()

      var insideTestContainer = false
      var outsideTestContainer = false

      // Before test container
      outsideTestContainer = Lockman.container === originalContainer

      await Lockman.withTestContainer(testContainer) {
        insideTestContainer = Lockman.container === testContainer
      }

      // After test container
      outsideTestContainer = outsideTestContainer && (Lockman.container === originalContainer)

      XCTAssertTrue(insideTestContainer)
      XCTAssertTrue(outsideTestContainer)
    }

  func testNestedTestContainers() async throws {
      let container1 = LockmanStrategyContainer()
      let container2 = LockmanStrategyContainer()

      try container1.register(LockmanSingleExecutionStrategy())
      try container2.register(LockmanPriorityBasedStrategy())

      await Lockman.withTestContainer(container1) {
        // Should be able to resolve from container1
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
        } catch {
          XCTFail("Should resolve from container 1")
        }

        // Nested container
        await Lockman.withTestContainer(container2) {
          // Should be able to resolve from container2
          do {
            _ = try Lockman.container.resolve(LockmanPriorityBasedStrategy.self)
          } catch {
            XCTFail("Should resolve from container 2")
          }

          // Should NOT be able to resolve from container1
          do {
            _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
            XCTFail("Should not resolve from container 1 in nested context")
          } catch {
            // Expected
          }
        }

        // Back to container1 context
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
        } catch {
          XCTFail("Should resolve from container 1 after nested context")
        }
      }
    }

  func testTestContainerWithAsyncOperations() async throws {
      let testContainer = LockmanStrategyContainer()
      try testContainer.register(LockmanSingleExecutionStrategy())

      await Lockman.withTestContainer(testContainer) {
        await withTaskGroup(of: Bool.self) { group in
          for _ in 0 ..< 5 {
            group.addTask {
              do {
                _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
                return true
              } catch {
                return false
              }
            }
          }

          var allResolved = true
          for await result in group {
            allResolved = allResolved && result
          }

          XCTAssertTrue(allResolved)
        }
      }
    }
  // MARK: - TaskLocal Storage Tests
  func testTaskLocalContainerInheritance() async throws {
      let parentContainer = LockmanStrategyContainer()
      let childContainer = LockmanStrategyContainer()

      try parentContainer.register(LockmanSingleExecutionStrategy())
      try childContainer.register(LockmanPriorityBasedStrategy())

      await Lockman.withTestContainer(parentContainer) {
        // Parent task can resolve its strategy
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
        } catch {
          XCTFail("Parent should resolve its strategy")
        }

        // Child task inherits parent's container by default
        await Task {
          do {
            _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          } catch {
            XCTFail("Child task should inherit parent's container")
          }
        }.value

        // Detached task does not inherit test container, but can access default container
        await Task.detached {
          do {
            // This should succeed because detached tasks use the default container
            // which has LockmanSingleExecutionStrategy pre-registered
            _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
            // This is expected behavior - detached tasks fall back to default container
          } catch {
            XCTFail("Detached task should be able to use default container")
          }
        }.value
      }
    }
  // MARK: - Error Handling Tests
  func testProperErrorTypesForResolutionFailures() async throws {
      let testContainer = LockmanStrategyContainer()

      await Lockman.withTestContainer(testContainer) {
        // Test unregistered strategy error
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          XCTFail("Should throw for unregistered strategy")
        } catch let error as LockmanError {
          switch error {
          case let .strategyNotRegistered(type):
            XCTAssertTrue(type.contains("LockmanSingleExecutionStrategy"))
          default:
            XCTFail("Wrong error type")
          }
        } catch {
          XCTFail("Should throw LockmanError")
        }
      }
    }

  func testContainerRegistrationErrors() async throws {
      let container = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()

      // First registration should succeed
      try container.register(strategy)

      // Duplicate registration should fail
      do {
        try container.register(strategy)
        XCTFail("Should throw for duplicate registration")
      } catch let error as LockmanError {
        switch error {
        case let .strategyAlreadyRegistered(type):
          XCTAssertTrue(type.contains("LockmanSingleExecutionStrategy"))
        default:
          XCTFail("Wrong error type")
        }
      } catch {
        XCTFail("Should throw LockmanError")
      }
    }
  // MARK: - Integration Tests
  func testCompleteWorkflowWithStrategies() async throws {
      let container = LockmanStrategyContainer()

      // Register multiple strategies
      try container.register(LockmanSingleExecutionStrategy())
      try container.register(LockmanPriorityBasedStrategy())

      await Lockman.withTestContainer(container) {
        // Test complete workflow
        // 1. Access strategies
        do {
          let singleStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
          let priorityStrategy = try container.resolve(LockmanPriorityBasedStrategy.self)

          // 2. Test single execution strategy
          let singleBoundary = TestBoundaryId("single")
          let singleInfo = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)

          let canLockSingle = singleStrategy.canLock(id: singleBoundary, info: singleInfo)
          XCTAssertEqual(canLockSingle, .success)

          singleStrategy.lock(id: singleBoundary, info: singleInfo)
          let canLockAgain  = singleStrategy.canLock(id: singleBoundary, info: singleInfo)
          XCTAssertEqual(canLockAgain, .failure())

          singleStrategy.unlock(id: singleBoundary, info: singleInfo)

          // 3. Test priority based strategy
          let priorityBoundary  = TestBoundaryId("priority")
          let highPriorityInfo = LockmanPriorityBasedInfo(actionId: "high", priority: .high(.exclusive))
          let lowPriorityInfo = LockmanPriorityBasedInfo(actionId: "low", priority: .low(.replaceable))

          priorityStrategy.lock(id: priorityBoundary, info: lowPriorityInfo)
          let canLockHigh = priorityStrategy.canLock(id: priorityBoundary, info: highPriorityInfo)
          XCTAssertEqual(canLockHigh, .successWithPrecedingCancellation)

          // 4. Clean up
          Lockman.cleanup.all()
        } catch {
          XCTFail("Strategy resolution failed: \(error)")
        }
      }
    }
}
