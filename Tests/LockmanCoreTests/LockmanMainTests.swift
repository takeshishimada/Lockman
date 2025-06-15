import Testing
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
@Suite("Lockman Framework Tests")
struct LockmanMainTests {
  // MARK: - Container Management Tests

  @Suite("Container Management")
  struct ContainerManagementTests {
    @Test("Default container is available")
    func testDefaultContainerAvailable() {
      // The container should always be available
      let container = Lockman.container
      #expect(container != nil)
    }

    @Test("Can register strategies in container")
    func testCanRegisterStrategies() throws {
      let testContainer = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()

      try testContainer.register(strategy)

      let resolved = try testContainer.resolve(LockmanSingleExecutionStrategy.self)
      #expect(resolved != nil)
    }

    @Test("Container isolation in tests")
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
          Issue.record("Should resolve strategy in container 1")
        }

        do {
          _ = try Lockman.container.resolve(LockmanPriorityBasedStrategy.self)
          Issue.record("Should not resolve strategy from container 2")
        } catch {
          // Expected to fail
        }
      }
    }
  }

  // MARK: - Strategy Resolution Tests

  @Suite("Strategy Resolution")
  struct StrategyResolutionTests {
    @Test("Resolve registered strategy")
    func testResolveRegisteredStrategy() async throws {
      let testContainer = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()
      try testContainer.register(strategy)

      await Lockman.withTestContainer(testContainer) {
        do {
          let resolved = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          #expect(resolved != nil)
        } catch {
          Issue.record("Failed to resolve registered strategy: \(error)")
        }
      }
    }

    @Test("Resolve fails for unregistered strategy")
    func testResolveFailsForUnregisteredStrategy() async throws {
      let testContainer = LockmanStrategyContainer()

      await Lockman.withTestContainer(testContainer) {
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          Issue.record("Should have thrown error for unregistered strategy")
        } catch let LockmanError.strategyNotRegistered(type) {
          #expect(type.contains("LockmanSingleExecutionStrategy"))
        } catch {
          Issue.record("Unexpected error type: \(error)")
        }
      }
    }

    @Test("Resolve with type parameter")
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
          #expect(resolved != nil)
        } catch {
          Issue.record("Failed to resolve with generic parameter: \(error)")
        }
      }
    }
  }

  // MARK: - Test Container Tests

  @Suite("Test Container")
  struct TestContainerTests {
    @Test("Test container isolation")
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

      #expect(insideTestContainer)
      #expect(outsideTestContainer)
    }

    @Test("Nested test containers")
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
          Issue.record("Should resolve from container 1")
        }

        // Nested container
        await Lockman.withTestContainer(container2) {
          // Should be able to resolve from container2
          do {
            _ = try Lockman.container.resolve(LockmanPriorityBasedStrategy.self)
          } catch {
            Issue.record("Should resolve from container 2")
          }

          // Should NOT be able to resolve from container1
          do {
            _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
            Issue.record("Should not resolve from container 1 in nested context")
          } catch {
            // Expected
          }
        }

        // Back to container1 context
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
        } catch {
          Issue.record("Should resolve from container 1 after nested context")
        }
      }
    }

    @Test("Test container with async operations")
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

          #expect(allResolved)
        }
      }
    }
  }

  // MARK: - TaskLocal Storage Tests

  @Suite("TaskLocal Storage")
  struct TaskLocalStorageTests {
    @Test("TaskLocal container inheritance")
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
          Issue.record("Parent should resolve its strategy")
        }

        // Child task inherits parent's container by default
        await Task {
          do {
            _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          } catch {
            Issue.record("Child task should inherit parent's container")
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
            Issue.record("Detached task should be able to use default container")
          }
        }.value
      }
    }
  }

  // MARK: - Error Handling Tests

  @Suite("Error Handling")
  struct ErrorHandlingTests {
    @Test("Proper error types for resolution failures")
    func testProperErrorTypesForResolutionFailures() async throws {
      let testContainer = LockmanStrategyContainer()

      await Lockman.withTestContainer(testContainer) {
        // Test unregistered strategy error
        do {
          _ = try Lockman.container.resolve(LockmanSingleExecutionStrategy.self)
          Issue.record("Should throw for unregistered strategy")
        } catch let error as LockmanError {
          switch error {
          case let .strategyNotRegistered(type):
            #expect(type.contains("LockmanSingleExecutionStrategy"))
          default:
            Issue.record("Wrong error type")
          }
        } catch {
          Issue.record("Should throw LockmanError")
        }
      }
    }

    @Test("Container registration errors")
    func testContainerRegistrationErrors() throws {
      let container = LockmanStrategyContainer()
      let strategy = LockmanSingleExecutionStrategy()

      // First registration should succeed
      try container.register(strategy)

      // Duplicate registration should fail
      do {
        try container.register(strategy)
        Issue.record("Should throw for duplicate registration")
      } catch let error as LockmanError {
        switch error {
        case let .strategyAlreadyRegistered(type):
          #expect(type.contains("LockmanSingleExecutionStrategy"))
        default:
          Issue.record("Wrong error type")
        }
      } catch {
        Issue.record("Should throw LockmanError")
      }
    }
  }

  // MARK: - Integration Tests

  @Suite("Integration")
  struct IntegrationTests {
    @Test("Complete workflow with strategies")
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
          #expect(canLockSingle == .success)

          singleStrategy.lock(id: singleBoundary, info: singleInfo)
          let canLockAgain = singleStrategy.canLock(id: singleBoundary, info: singleInfo)
          #expect(canLockAgain == .failure)

          singleStrategy.unlock(id: singleBoundary, info: singleInfo)

          // 3. Test priority based strategy
          let priorityBoundary = TestBoundaryId("priority")
          let highPriorityInfo = LockmanPriorityBasedInfo(actionId: "high", priority: .high(.exclusive))
          let lowPriorityInfo = LockmanPriorityBasedInfo(actionId: "low", priority: .low(.replaceable))

          priorityStrategy.lock(id: priorityBoundary, info: lowPriorityInfo)
          let canLockHigh = priorityStrategy.canLock(id: priorityBoundary, info: highPriorityInfo)
          #expect(canLockHigh == .successWithPrecedingCancellation)

          // 4. Clean up
          Lockman.cleanup.all()
        } catch {
          #expect(Bool(false), "Strategy resolution failed: \(error)")
        }
      }
    }
  }
}
