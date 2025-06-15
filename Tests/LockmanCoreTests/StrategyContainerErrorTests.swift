import Foundation
import Testing
@testable import LockmanCore

/// Enhanced tests for LockmanStrategyContainer error handling scenarios
@Suite("Strategy Container Error Tests")
struct StrategyContainerErrorTests {
  // MARK: - Mock Strategies for Testing

  private struct MockStrategyA: LockmanStrategy {
    typealias I = LockmanSingleExecutionInfo
    var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockResult { .success }
    func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(id _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  private struct MockStrategyB: LockmanStrategy {
    typealias I = LockmanPriorityBasedInfo
    var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) -> LockResult { .success }
    func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
    func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanPriorityBasedInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(id _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  private struct MockStrategyC: LockmanStrategy {
    typealias I = LockmanSingleExecutionInfo
    var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: Self.self) }
    func canLock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) -> LockResult { .success }
    func lock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func unlock<B: LockmanBoundaryId>(id _: B, info _: LockmanSingleExecutionInfo) {}
    func cleanUp() {}
    func cleanUp<B: LockmanBoundaryId>(id _: B) {}
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
  }

  // MARK: - Single Strategy Registration Error Tests

  @Test("Register same strategy type twice throws correct error")
  func registerSameStrategyTypeTwiceThrowsCorrectError() {
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategyA()
    let strategy2 = MockStrategyA() // Same type, different instance

    // First registration should succeed
    #expect(throws: Never.self) {
      try container.register(strategy1)
    }

    // Second registration should fail with specific error
    #expect(throws: LockmanError.self) {
      try container.register(strategy2)
    }

    do {
      try container.register(strategy2)
      #expect(Bool(false), "Should have thrown error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        #expect(strategyType.contains("MockStrategyA"))
      default:
        #expect(Bool(false), "Expected strategyAlreadyRegistered error")
      }
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }
  }

  @Test("Register different strategy types succeeds")
  func registerDifferentStrategyTypesSucceeds() {
    let container = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let strategyC = MockStrategyC()

    // All different types should register successfully
    #expect(throws: Never.self) {
      try container.register(strategyA)
      try container.register(strategyB)
      try container.register(strategyC)
    }

    // Verify all are registered
    #expect(container.isRegistered(MockStrategyA.self))
    #expect(container.isRegistered(MockStrategyB.self))
    #expect(container.isRegistered(MockStrategyC.self))
  }

  @Test("Registration error details are accurate")
  func registrationErrorDetailsAreAccurate() {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    try? container.register(strategy)

    do {
      try container.register(strategy)
      #expect(Bool(false), "Should have thrown error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        #expect(strategyType.contains("LockmanSingleExecutionStrategy"))
        #expect(strategyType.count > 10) // Should be descriptive
      default:
        #expect(Bool(false), "Expected strategyAlreadyRegistered error")
      }
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }
  }

  // MARK: - Bulk Registration Error Tests

  @Test("Register multiple strategies of same type with one duplicate fails atomically")
  func registerMultipleStrategiesWithOneDuplicateFailsAtomically() {
    let container = LockmanStrategyContainer()
    let strategyA1 = MockStrategyA()
    let strategyA2 = MockStrategyA() // Different instance, same type
    let strategyA3 = MockStrategyA() // Another instance

    // Pre-register one strategy
    try? container.register(strategyA1)

    // Bulk registration with same type should fail because type already registered
    #expect(throws: LockmanError.self) {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), strategyA2),
        (LockmanStrategyId(type: MockStrategyA.self), strategyA3),
      ])
    }

    // Verify original registration is still intact
    #expect(container.isRegistered(MockStrategyA.self) == true) // Original

    // Test with different strategy type for mixed scenario
    let strategyB = MockStrategyB()
    #expect(throws: Never.self) {
      try container.register(strategyB)
    }
  }

  @Test("Register multiple instances of same type in bulk operation")
  func registerMultipleInstancesOfSameTypeInBulkOperation() {
    let container = LockmanStrategyContainer()
    let strategyA1 = MockStrategyA()
    let strategyA2 = MockStrategyA() // Same type

    // registerAll with multiple instances of same type would fail due to duplicate IDs
    #expect(throws: LockmanError.self) {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), strategyA1),
        (LockmanStrategyId(type: MockStrategyA.self), strategyA2),
      ])
    }

    // The strategy type should not be registered due to failure
    #expect(container.isRegistered(MockStrategyA.self) == false)
  }

  @Test("Register multiple strategies of different types individually")
  func registerMultipleStrategiesOfDifferentTypesIndividually() {
    let container = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let strategyC = MockStrategyC()

    // Since registerAll requires same type, register different types individually
    #expect(throws: Never.self) {
      try container.register(strategyA)
      try container.register(strategyB)
      try container.register(strategyC)
    }

    // Verify all are registered
    #expect(container.isRegistered(MockStrategyA.self))
    #expect(container.isRegistered(MockStrategyB.self))
    #expect(container.isRegistered(MockStrategyC.self))
  }

  // MARK: - Strategy Resolution Error Tests

  @Test("Resolve unregistered strategy throws detailed error")
  func resolveUnregisteredStrategyThrowsDetailedError() {
    let container = LockmanStrategyContainer()

    // Try to resolve unregistered strategy
    do {
      _ = try container.resolve(MockStrategyA.self)
      #expect(Bool(false), "Should have thrown error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        #expect(strategyType.contains("MockStrategyA"))
        #expect(strategyType.count > 5) // Should be descriptive
      default:
        #expect(Bool(false), "Expected strategyNotRegistered error")
      }
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }
  }

  @Test("Resolve registered strategy succeeds")
  func resolveRegisteredStrategySucceeds() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    try? container.register(strategy)

    #expect(throws: Never.self) {
      let resolved = try container.resolve(MockStrategyA.self)
      #expect(resolved != nil)
    }
  }

  @Test("Resolution error with complex strategy names")
  func resolutionErrorWithComplexStrategyNames() {
    let container = LockmanStrategyContainer()

    // Test with various built-in strategy types
    let strategyTypes: [Any.Type] = [
      LockmanSingleExecutionStrategy.self,
      LockmanPriorityBasedStrategy.self,
    ]

    for strategyType in strategyTypes {
      do {
        // This will fail for both since nothing is registered
        if strategyType == LockmanSingleExecutionStrategy.self {
          _ = try container.resolve(LockmanSingleExecutionStrategy.self)
        } else if strategyType == LockmanPriorityBasedStrategy.self {
          _ = try container.resolve(LockmanPriorityBasedStrategy.self)
        }
        #expect(Bool(false), "Should have thrown error for \(strategyType)")
      } catch let error as LockmanError {
        switch error {
        case let .strategyNotRegistered(name):
          #expect(name.count > 10) // Should be descriptive
          #expect(name.contains("Strategy")) // Should contain strategy identifier
        default:
          #expect(Bool(false), "Expected strategyNotRegistered error")
        }
      } catch {
        #expect(Bool(false), "Expected LockmanError")
      }
    }
  }

  // MARK: - Thread Safety Error Tests

  @Test("Concurrent registration with same type fails consistently")
  func concurrentRegistrationWithSameTypeFailsConsistently() async {
    let container = LockmanStrategyContainer()

    await withTaskGroup(of: Bool.self) { group in
      // Try to register the same strategy type concurrently
      for _ in 0 ..< 10 {
        group.addTask {
          do {
            let strategy = MockStrategyA()
            try container.register(strategy)
            return true // Success
          } catch is LockmanError {
            return false // Expected failure
          } catch {
            return false // Unexpected error
          }
        }
      }

      var successCount = 0
      var failureCount = 0

      for await success in group {
        if success {
          successCount += 1
        } else {
          failureCount += 1
        }
      }

      // Exactly one should succeed, others should fail
      #expect(successCount == 1)
      #expect(failureCount == 9)
      #expect(container.isRegistered(MockStrategyA.self))
    }
  }

  @Test("Concurrent resolution of unregistered strategies")
  func concurrentResolutionOfUnregisteredStrategies() async {
    let container = LockmanStrategyContainer()

    await withTaskGroup(of: Bool.self) { group in
      // Try to resolve unregistered strategy concurrently
      for _ in 0 ..< 10 {
        group.addTask {
          do {
            _ = try container.resolve(MockStrategyA.self)
            return false // Should not succeed
          } catch is LockmanError {
            return true // Expected error
          } catch {
            return false // Unexpected error type
          }
        }
      }

      var errorCount = 0
      for await threwLockmanError in group {
        if threwLockmanError {
          errorCount += 1
        }
      }

      // All should throw LockmanError
      #expect(errorCount == 10)
    }
  }

  // MARK: - Container State Integrity Tests

  @Test("Failed registration preserves existing registrations")
  func failedRegistrationPreservesExistingRegistrations() {
    let container = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let duplicateA = MockStrategyA()

    // Register initial strategies
    try? container.register(strategyA)
    try? container.register(strategyB)

    #expect(container.isRegistered(MockStrategyA.self))
    #expect(container.isRegistered(MockStrategyB.self))

    // Try to register duplicate
    do {
      try container.register(duplicateA)
      #expect(Bool(false), "Should have failed")
    } catch {
      // Expected
    }

    // Verify original registrations are intact
    #expect(container.isRegistered(MockStrategyA.self))
    #expect(container.isRegistered(MockStrategyB.self))

    // Verify we can still resolve original strategies
    #expect(throws: Never.self) {
      _ = try container.resolve(MockStrategyA.self)
      _ = try container.resolve(MockStrategyB.self)
    }
  }

  @Test("Failed bulk registration preserves container state")
  func failedBulkRegistrationPreservesContainerState() {
    let container = LockmanStrategyContainer()
    let originalStrategy = MockStrategyA()
    let duplicateA1 = MockStrategyA() // Same type - will cause failure
    let duplicateA2 = MockStrategyA() // Same type

    // Pre-register one strategy
    try? container.register(originalStrategy)
    #expect(container.isRegistered(MockStrategyA.self))

    // Try bulk registration of same type that will fail
    do {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), duplicateA1),
        (LockmanStrategyId(type: MockStrategyA.self), duplicateA2),
      ])
      #expect(Bool(false), "Should have failed")
    } catch {
      // Expected - already registered
    }

    // Verify original registration is preserved
    #expect(container.isRegistered(MockStrategyA.self))

    // Verify we can still register different type
    let strategyB = MockStrategyB()
    #expect(throws: Never.self) {
      try container.register(strategyB)
    }
  }

  // MARK: - Error Recovery Tests

  @Test("Registration error recovery workflow")
  func registrationErrorRecoveryWorkflow() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    // Step 1: Register successfully
    try? container.register(strategy)
    #expect(container.isRegistered(MockStrategyA.self))

    // Step 2: Try duplicate registration (should fail)
    do {
      try container.register(strategy)
      #expect(Bool(false), "Should have failed")
    } catch is LockmanError {
      // Expected
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }

    // Step 3: Verify original registration still works
    #expect(throws: Never.self) {
      _ = try container.resolve(MockStrategyA.self)
    }

    // Step 4: Register different strategy (should work)
    let strategyB = MockStrategyB()
    #expect(throws: Never.self) {
      try container.register(strategyB)
    }

    // Step 5: Verify both strategies work
    #expect(throws: Never.self) {
      _ = try container.resolve(MockStrategyA.self)
      _ = try container.resolve(MockStrategyB.self)
    }
  }

  @Test("Resolution error recovery workflow")
  func resolutionErrorRecoveryWorkflow() {
    let container = LockmanStrategyContainer()

    // Step 1: Try to resolve unregistered strategy (should fail)
    do {
      _ = try container.resolve(MockStrategyA.self)
      #expect(Bool(false), "Should have failed")
    } catch is LockmanError {
      // Expected
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }

    // Step 2: Register the strategy
    let strategy = MockStrategyA()
    try? container.register(strategy)

    // Step 3: Now resolution should succeed
    #expect(throws: Never.self) {
      _ = try container.resolve(MockStrategyA.self)
    }

    // Step 4: Multiple resolutions should continue to work
    for _ in 0 ..< 5 {
      #expect(throws: Never.self) {
        _ = try container.resolve(MockStrategyA.self)
      }
    }
  }

  // MARK: - Edge Cases

  @Test("isRegistered method accuracy")
  func isRegisteredMethodAccuracy() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    // Before registration
    #expect(container.isRegistered(MockStrategyA.self) == false)
    #expect(container.isRegistered(MockStrategyB.self) == false)

    // After registration
    try? container.register(strategy)
    #expect(container.isRegistered(MockStrategyA.self) == true)
    #expect(container.isRegistered(MockStrategyB.self) == false) // Still false

    // After failed duplicate registration
    do {
      try container.register(strategy)
    } catch {
      // Expected failure
    }
    #expect(container.isRegistered(MockStrategyA.self) == true) // Still true
  }

  @Test("Container behavior with empty state")
  func containerBehaviorWithEmptyState() {
    let container = LockmanStrategyContainer()

    // All isRegistered checks should return false
    #expect(container.isRegistered(MockStrategyA.self) == false)
    #expect(container.isRegistered(MockStrategyB.self) == false)
    #expect(container.isRegistered(LockmanSingleExecutionStrategy.self) == false)

    // All resolve attempts should throw errors
    #expect(throws: LockmanError.self) {
      _ = try container.resolve(MockStrategyA.self)
    }

    #expect(throws: LockmanError.self) {
      _ = try container.resolve(MockStrategyB.self)
    }

    // Cleanup should not crash
    container.cleanUp()
    container.cleanUp(id: "test-boundary")
  }
}
