import Foundation
import XCTest
@testable import LockmanCore

/// Enhanced tests for LockmanStrategyContainer error handling scenarios
final class StrategyContainerErrorTests: XCTestCase {
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

  func testRegisterSameStrategyTypeTwiceThrowsCorrectError() {
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategyA()
    let strategy2 = MockStrategyA() // Same type, different instance

    // First registration should succeed
    XCTAssertNoThrow(try container.register(strategy1))

    // Second registration should fail with specific error
    XCTAssertTrue(throws: LockmanRegistrationError.self) {
      try container.register(strategy2)
    }

    do {
      try container.register(strategy2)
      XCTFail("Should have thrown error")
    } catch let error as LockmanRegistrationError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("MockStrategyA"))
      default:
        XCTFail("Expected strategyAlreadyRegistered error")
      }
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }
  }

  func testRegisterDifferentStrategyTypesSucceeds() {
    let container = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let strategyC = MockStrategyC()

    // All different types should register successfully
    XCTAssertNoThrow(try container.register(strategyA))
    XCTAssertNoThrow(try container.register(strategyB))
    XCTAssertNoThrow(try container.register(strategyC))

    // Verify all are registered
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))
    XCTAssertTrue(container.isRegistered(MockStrategyB.self))
    XCTAssertTrue(container.isRegistered(MockStrategyC.self))
  }

  func testRegistrationErrorDetailsAreAccurate() {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    try? container.register(strategy)

    do {
      try container.register(strategy)
      XCTFail("Should have thrown error")
    } catch let error as LockmanRegistrationError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("LockmanSingleExecutionStrategy"))
        XCTAssertGreaterThan(strategyType.count, 10) // Should be descriptive
      default:
        XCTFail("Expected strategyAlreadyRegistered error")
      }
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }
  }

  // MARK: - Bulk Registration Error Tests

  func testRegisterMultipleStrategiesWithOneDuplicateFailsAtomically() {
    let container = LockmanStrategyContainer()
    let strategyA1 = MockStrategyA()
    let strategyA2 = MockStrategyA() // Different instance, same type
    let strategyA3 = MockStrategyA() // Another instance

    // Pre-register one strategy
    try? container.register(strategyA1)

    // Bulk registration with same type should fail because type already registered
    XCTAssertTrue(throws: LockmanRegistrationError.self) {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), strategyA2),
        (LockmanStrategyId(type: MockStrategyA.self), strategyA3),
      ])
    }

    // Verify original registration is still intact
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), true) // Original

    // Test with different strategy type for mixed scenario
    let strategyB  = MockStrategyB()
    XCTAssertNoThrow(try container.register(strategyB))
  }

  func testRegisterMultipleInstancesOfSameTypeInBulkOperation() {
    let container = LockmanStrategyContainer()
    let strategyA1 = MockStrategyA()
    let strategyA2 = MockStrategyA() // Same type

    // registerAll with multiple instances of same type would fail due to duplicate IDs
    XCTAssertTrue(throws: LockmanRegistrationError.self) {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), strategyA1),
        (LockmanStrategyId(type: MockStrategyA.self), strategyA2),
      ])
    }

    // The strategy type should not be registered due to failure
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), false)
  }

  func testRegisterMultipleStrategiesOfDifferentTypesIndividually() {
    let container  = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let strategyC = MockStrategyC()

    // Since registerAll requires same type, register different types individually
    XCTAssertNoThrow(try container.register(strategyA))
    XCTAssertNoThrow(try container.register(strategyB))
    XCTAssertNoThrow(try container.register(strategyC))

    // Verify all are registered
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))
    XCTAssertTrue(container.isRegistered(MockStrategyB.self))
    XCTAssertTrue(container.isRegistered(MockStrategyC.self))
  }

  // MARK: - Strategy Resolution Error Tests

  func testResolveUnregisteredStrategyThrowsDetailedError() {
    let container = LockmanStrategyContainer()

    // Try to resolve unregistered strategy
    do {
      _ = try container.resolve(MockStrategyA.self)
      XCTFail("Should have thrown error")
    } catch let error as LockmanRegistrationError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("MockStrategyA"))
        XCTAssertGreaterThan(strategyType.count, 5) // Should be descriptive
      default:
        XCTFail("Expected strategyNotRegistered error")
      }
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }
  }

  func testResolveRegisteredStrategySucceeds() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    try? container.register(strategy)

    XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))
  }

  func testResolutionErrorWithComplexStrategyNames() {
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
        XCTFail("Should have thrown error for \(strategyType)")
      } catch let error as LockmanRegistrationError {
        switch error {
        case let .strategyNotRegistered(name):
          XCTAssertGreaterThan(name.count, 10) // Should be descriptive
          XCTAssertTrue(name.contains("Strategy")) // Should contain strategy identifier
        default:
          XCTFail("Expected strategyNotRegistered error")
        }
      } catch {
        XCTFail("Expected LockmanRegistrationError")
      }
    }
  }

  // MARK: - Thread Safety Error Tests

  func testConcurrentRegistrationWithSameTypeFailsConsistently() async {
    let container = LockmanStrategyContainer()

    await withTaskGroup(of: Bool.self) { group in
      // Try to register the same strategy type concurrently
      for _ in 0 ..< 10 {
        group.addTask {
          do {
            let strategy = MockStrategyA()
            try container.register(strategy)
            return true // Success
          } catch is LockmanRegistrationError {
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
      XCTAssertEqual(successCount, 1)
      XCTAssertEqual(failureCount, 9)
      XCTAssertTrue(container.isRegistered(MockStrategyA.self))
    }
  }

  func testConcurrentResolutionOfUnregisteredStrategies() async {
    let container  = LockmanStrategyContainer()

    await withTaskGroup(of: Bool.self) { group in
      // Try to resolve unregistered strategy concurrently
      for _ in 0 ..< 10 {
        group.addTask {
          do {
            _ = try container.resolve(MockStrategyA.self)
            return false // Should not succeed
          } catch is LockmanRegistrationError {
            return true // Expected error
          } catch {
            return false // Unexpected error type
          }
        }
      }

      var errorCount = 0
      for await threwLockmanRegistrationError in group {
        if threwLockmanRegistrationError {
          errorCount += 1
        }
      }

      // All should throw LockmanRegistrationError
      XCTAssertEqual(errorCount, 10)
    }
  }

  // MARK: - Container State Integrity Tests

  func testFailedRegistrationPreservesExistingRegistrations() {
    let container  = LockmanStrategyContainer()
    let strategyA = MockStrategyA()
    let strategyB = MockStrategyB()
    let duplicateA = MockStrategyA()

    // Register initial strategies
    try? container.register(strategyA)
    try? container.register(strategyB)

    XCTAssertTrue(container.isRegistered(MockStrategyA.self))
    XCTAssertTrue(container.isRegistered(MockStrategyB.self))

    // Try to register duplicate
    do {
      try container.register(duplicateA)
      XCTFail("Should have failed")
    } catch {
      // Expected
    }

    // Verify original registrations are intact
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))
    XCTAssertTrue(container.isRegistered(MockStrategyB.self))

    // Verify we can still resolve original strategies
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyB.self))
  }

  func testFailedBulkRegistrationPreservesContainerState() {
    let container = LockmanStrategyContainer()
    let originalStrategy = MockStrategyA()
    let duplicateA1 = MockStrategyA() // Same type - will cause failure
    let duplicateA2 = MockStrategyA() // Same type

    // Pre-register one strategy
    try? container.register(originalStrategy)
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))

    // Try bulk registration of same type that will fail
    do {
      try container.registerAll([
        (LockmanStrategyId(type: MockStrategyA.self), duplicateA1),
        (LockmanStrategyId(type: MockStrategyA.self), duplicateA2),
      ])
      XCTFail("Should have failed")
    } catch {
      // Expected - already registered
    }

    // Verify original registration is preserved
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))

    // Verify we can still register different type
    let strategyB = MockStrategyB()
    XCTAssertNoThrow(try container.register(strategyB))
  }

  // MARK: - Error Recovery Tests

  func testRegistrationErrorRecoveryWorkflow() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    // Step 1: Register successfully
    try? container.register(strategy)
    XCTAssertTrue(container.isRegistered(MockStrategyA.self))

    // Step 2: Try duplicate registration (should fail)
    do {
      try container.register(strategy)
      XCTFail("Should have failed")
    } catch is LockmanRegistrationError {
      // Expected
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }

    // Step 3: Verify original registration still works
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))

    // Step 4: Register different strategy (should work)
    let strategyB = MockStrategyB()
    XCTAssertNoThrow(try container.register(strategyB))

    // Step 5: Verify both strategies work
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyB.self))
  }

  func testResolutionErrorRecoveryWorkflow() {
    let container = LockmanStrategyContainer()

    // Step 1: Try to resolve unregistered strategy (should fail)
    do {
      _ = try container.resolve(MockStrategyA.self)
      XCTFail("Should have failed")
    } catch is LockmanRegistrationError {
      // Expected
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }

    // Step 2: Register the strategy
    let strategy = MockStrategyA()
    try? container.register(strategy)

    // Step 3: Now resolution should succeed
    XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))

    // Step 4: Multiple resolutions should continue to work
    for _ in 0 ..< 5 {
      XCTAssertNoThrow(_ = try container.resolve(MockStrategyA.self))
    }
  }

  // MARK: - Edge Cases

  func testIsRegisteredMethodAccuracy() {
    let container = LockmanStrategyContainer()
    let strategy = MockStrategyA()

    // Before registration
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), false)
    XCTAssertEqual(container.isRegistered(MockStrategyB.self), false)

    // After registration
    try? container.register(strategy)
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), true)
    XCTAssertEqual(container.isRegistered(MockStrategyB.self), false) // Still false

    // After failed duplicate registration
    do {
      try container.register(strategy)
    } catch {
      // Expected failure
    }
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), true) // Still true
  }

  func testContainerBehaviorWithEmptyState() {
    let container  = LockmanStrategyContainer()

    // All isRegistered checks should return false
    XCTAssertEqual(container.isRegistered(MockStrategyA.self), false)
    XCTAssertEqual(container.isRegistered(MockStrategyB.self), false)
    XCTAssertEqual(container.isRegistered(LockmanSingleExecutionStrategy.self), false)

    // All resolve attempts should throw errors
    XCTAssertTrue(throws: LockmanRegistrationError.self) {
      _  = try container.resolve(MockStrategyA.self)
    }

    XCTAssertTrue(throws: LockmanRegistrationError.self) {
      _ = try container.resolve(MockStrategyB.self)
    }

    // Cleanup should not crash
    container.cleanUp()
    container.cleanUp(id: "test-boundary")
  }
}
