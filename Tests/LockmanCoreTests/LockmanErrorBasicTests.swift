import Foundation
import XCTest

@testable import Lockman

/// Enhanced tests for LockmanError functionality and error handling scenarios
final class LockmanErrorEnhancedTests: XCTestCase {
  func testStrategyNotRegisteredError() async throws {
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyNotRegistered(strategyType)

    XCTAssertTrue(error.localizedDescription.contains("TestStrategy"))
    XCTAssertTrue(error.localizedDescription.contains("not registered"))
  }

  func testStrategyAlreadyRegisteredError() async throws {
    let strategyType = "ExistingStrategy"
    let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)

    XCTAssertTrue(error.localizedDescription.contains("ExistingStrategy"))
    XCTAssertTrue(error.localizedDescription.contains("already registered"))
  }

  func testResolveUnregisteredStrategyThrowsError() async throws {
    let container = LockmanStrategyContainer()

    XCTAssertThrowsError(try container.resolve(LockmanSingleExecutionStrategy.self))
  }

  func testRegisterDuplicateStrategyThrowsError() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    // First registration should succeed
    XCTAssertNoThrow(try container.register(strategy))

    // Second registration should throw error
    XCTAssertThrowsError(try container.register(strategy))
  }

  func testErrorMessageQuality() async throws {
    let error1 = LockmanRegistrationError.strategyNotRegistered("LongStrategyName")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("DuplicateStrategy")

    XCTAssertGreaterThan(error1.localizedDescription.count, 10)
    XCTAssertGreaterThan(error2.localizedDescription.count, 10)
    XCTAssertTrue(error1.localizedDescription.contains("LongStrategyName"))
    XCTAssertTrue(error2.localizedDescription.contains("DuplicateStrategy"))
  }

  // MARK: - LocalizedError Protocol Tests

  func testLocalizedErrorDescription() async throws {
    let error1 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("ExistingStrategy")

    XCTAssertNotEqual(error1.errorDescription, nil)
    XCTAssertNotEqual(error2.errorDescription, nil)
    XCTAssertTrue(error1.errorDescription?.contains("TestStrategy") ?? false)
    XCTAssertTrue(error1.errorDescription?.contains("not registered") ?? false)
    XCTAssertTrue(error2.errorDescription?.contains("ExistingStrategy") ?? false)
    XCTAssertTrue(error2.errorDescription?.contains("already registered") ?? false)
  }

  func testLocalizedErrorFailureReason() async throws {
    let error1 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("ExistingStrategy")

    XCTAssertNotEqual(error1.failureReason, nil)
    XCTAssertNotEqual(error2.failureReason, nil)
    XCTAssertTrue(error1.failureReason?.contains("resolution requires") ?? false)
    XCTAssertTrue(error2.failureReason?.contains("unique strategy") ?? false)
  }

  func testLocalizedErrorRecoverySuggestion() async throws {
    let error1 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("ExistingStrategy")

    XCTAssertNotEqual(error1.recoverySuggestion, nil)
    XCTAssertNotEqual(error2.recoverySuggestion, nil)
    XCTAssertTrue(error1.recoverySuggestion?.contains("register") ?? false)
    XCTAssertTrue(error2.recoverySuggestion?.contains("Check if") ?? false)
    XCTAssertTrue(error1.recoverySuggestion?.contains("TestStrategy") ?? false)
    XCTAssertTrue(error2.recoverySuggestion?.contains("ExistingStrategy") ?? false)
  }

  func testLocalizedErrorHelpAnchor() async throws {
    let error1 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("ExistingStrategy")

    XCTAssertEqual(error1.helpAnchor, "LockmanStrategyContainer")
    XCTAssertEqual(error2.helpAnchor, "LockmanStrategyContainer")
  }

  // MARK: - Error Equality Tests

  func testErrorEqualitySemantics() async throws {
    let error1a = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error1b = LockmanRegistrationError.strategyNotRegistered("TestStrategy")
    let error1c = LockmanRegistrationError.strategyNotRegistered("DifferentStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")

    // Same error type with same value should be equal
    switch (error1a, error1b) {
    case let (.strategyNotRegistered(a), .strategyNotRegistered(b)):
      XCTAssertEqual(a, b)
    default:
      XCTFail("Expected strategyNotRegistered errors")
    }

    // Same error type with different values should not be equal
    switch (error1a, error1c) {
    case let (.strategyNotRegistered(a), .strategyNotRegistered(c)):
      XCTAssertNotEqual(a, c)
    default:
      XCTFail("Expected strategyNotRegistered errors")
    }

    // Different error types should not be equal
    switch (error1a, error2) {
    case (.strategyNotRegistered, .strategyAlreadyRegistered):
      break  // Expected different types
    default:
      XCTFail("Expected different error types")
    }
  }

  // MARK: - Strategy Container Error Scenarios

  func testMultipleConsecutiveRegistrationAttempts() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    // First registration should succeed
    XCTAssertNoThrow(try container.register(strategy))

    // Multiple subsequent registrations should all fail with same error
    for _ in 0..<5 {
      XCTAssertThrowsError(try container.register(strategy))

      do {
        try container.register(strategy)
      } catch let error as LockmanRegistrationError {
        switch error {
        case let .strategyAlreadyRegistered(strategyType):
          XCTAssertTrue(strategyType.contains("LockmanSingleExecutionStrategy"))
        default:
          XCTFail("Expected strategyAlreadyRegistered error")
        }
      } catch {
        XCTFail("Expected LockmanRegistrationError")
      }
    }
  }

  func testRegistrationErrorPreservesContainerState() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()

    // Register first strategy
    try? container.register(strategy)

    // Verify it's registered
    XCTAssertTrue(container.isRegistered(LockmanPriorityBasedStrategy.self))

    // Try to register duplicate
    do {
      try container.register(strategy)
    } catch {
      // Expected to fail
    }

    // Verify original registration is still intact
    XCTAssertTrue(container.isRegistered(LockmanPriorityBasedStrategy.self))

    // Verify we can still resolve the original
    XCTAssertNoThrow(_ = try container.resolve(LockmanPriorityBasedStrategy.self))
  }

  func testResolutionErrorWithDetailedStrategyName() async throws {
    let container = LockmanStrategyContainer()

    do {
      _ = try container.resolve(LockmanPriorityBasedStrategy.self)
      XCTFail("Should have thrown an error")
    } catch let error as LockmanRegistrationError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("LockmanPriorityBasedStrategy"))
        XCTAssertGreaterThan(strategyType.count, 10)  // Should be descriptive
      default:
        XCTFail("Expected strategyNotRegistered error")
      }
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }
  }

  // MARK: - Concurrent Error Scenarios

  func testConcurrentRegistrationErrorConsistency() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()

    // Register once successfully
    try? container.register(strategy)

    await withTaskGroup(of: Bool.self) { group in
      // Try concurrent registrations
      for _ in 0..<10 {
        group.addTask {
          do {
            let newStrategy = LockmanSingleExecutionStrategy()
            try container.register(newStrategy)
            return false  // Should not succeed
          } catch is any LockmanError {
            return true  // Expected
          } catch {
            return false  // Unexpected error type
          }
        }
      }

      var errorCount = 0
      for await didThrowLockmanError in group {
        if didThrowLockmanError {
          errorCount += 1
        }
      }

      // All should have failed with LockmanError
      XCTAssertEqual(errorCount, 10)
    }
  }

  // MARK: - Error Message Edge Cases

  func testErrorMessagesWithSpecialCharacters() async throws {
    let specialStrategyName = "Strategy<With>Special&Characters@#$%"
    let error1 = LockmanRegistrationError.strategyNotRegistered(specialStrategyName)
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered(specialStrategyName)

    XCTAssertTrue(error1.errorDescription?.contains(specialStrategyName) ?? false)
    XCTAssertTrue(error2.errorDescription?.contains(specialStrategyName) ?? false)
    XCTAssertTrue(error1.recoverySuggestion?.contains(specialStrategyName) ?? false)
    XCTAssertTrue(error2.recoverySuggestion?.contains(specialStrategyName) ?? false)
  }

  func testErrorMessagesWithVeryLongStrategyNames() async throws {
    let longStrategyName = String(repeating: "VeryLongStrategyName", count: 10)
    let error = LockmanRegistrationError.strategyNotRegistered(longStrategyName)

    XCTAssertTrue(error.errorDescription?.contains(longStrategyName) ?? false)
    XCTAssertTrue(error.recoverySuggestion?.contains(longStrategyName) ?? false)
    XCTAssertGreaterThan(error.errorDescription!.count, 100)  // Should still be comprehensive
  }

  func testErrorMessagesWithEmptyStrategyName() async throws {
    let emptyName = ""
    let error1 = LockmanRegistrationError.strategyNotRegistered(emptyName)
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered(emptyName)

    // Should still produce valid error messages
    XCTAssertNotEqual(error1.errorDescription, nil)
    XCTAssertNotEqual(error2.errorDescription, nil)
    XCTAssertGreaterThan(error1.errorDescription!.count, 20)
    XCTAssertGreaterThan(error2.errorDescription!.count, 20)
  }

  // MARK: - Error Recovery Tests

  func testErrorRecoveryWorkflow() async throws {
    let container = LockmanStrategyContainer()

    // Step 1: Try to resolve unregistered strategy (should fail)
    do {
      _ = try container.resolve(LockmanSingleExecutionStrategy.self)
      XCTFail("Should have failed")
    } catch is any LockmanError {
      // Expected
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }

    // Step 2: Follow recovery suggestion - register the strategy
    let strategy = LockmanSingleExecutionStrategy.shared
    try? container.register(strategy)

    // Step 3: Now resolution should succeed
    XCTAssertNoThrow(_ = try container.resolve(LockmanSingleExecutionStrategy.self))

    // Step 4: Try duplicate registration (should fail)
    do {
      try container.register(strategy)
      XCTFail("Should have failed")
    } catch is any LockmanError {
      // Expected
    } catch {
      XCTFail("Expected LockmanRegistrationError")
    }

    // Step 5: Verify original registration still works
    XCTAssertNoThrow(_ = try container.resolve(LockmanSingleExecutionStrategy.self))
  }
}
