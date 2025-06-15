import Foundation
import Testing
@testable import LockmanCore

/// Enhanced tests for LockmanError functionality and error handling scenarios
@Suite("Lockman Error Enhanced Tests")
struct LockmanErrorEnhancedTests {
  @Test("Strategy not registered error")
  func strategyNotRegisteredError() {
    let strategyType = "TestStrategy"
    let error = LockmanError.strategyNotRegistered(strategyType)

    #expect(error.localizedDescription.contains("TestStrategy"))
    #expect(error.localizedDescription.contains("not registered"))
  }

  @Test("Strategy already registered error")
  func strategyAlreadyRegisteredError() {
    let strategyType = "ExistingStrategy"
    let error = LockmanError.strategyAlreadyRegistered(strategyType)

    #expect(error.localizedDescription.contains("ExistingStrategy"))
    #expect(error.localizedDescription.contains("already registered"))
  }

  @Test("Resolve unregistered strategy throws error")
  func resolveUnregisteredStrategyThrowsError() {
    let container = LockmanStrategyContainer()

    #expect(throws: LockmanError.self) {
      _ = try container.resolve(LockmanSingleExecutionStrategy.self)
    }
  }

  @Test("Register duplicate strategy throws error")
  func registerDuplicateStrategyThrowsError() {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    // First registration should succeed
    #expect(throws: Never.self) {
      try container.register(strategy)
    }

    // Second registration should throw error
    #expect(throws: LockmanError.self) {
      try container.register(strategy)
    }
  }

  @Test("Error message quality")
  func errorMessageQuality() {
    let error1 = LockmanError.strategyNotRegistered("LongStrategyName")
    let error2 = LockmanError.strategyAlreadyRegistered("DuplicateStrategy")

    #expect(error1.localizedDescription.count > 10)
    #expect(error2.localizedDescription.count > 10)
    #expect(error1.localizedDescription.contains("LongStrategyName"))
    #expect(error2.localizedDescription.contains("DuplicateStrategy"))
  }

  // MARK: - LocalizedError Protocol Tests

  @Test("LocalizedError errorDescription")
  func localizedErrorDescription() {
    let error1 = LockmanError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanError.strategyAlreadyRegistered("ExistingStrategy")

    #expect(error1.errorDescription != nil)
    #expect(error2.errorDescription != nil)
    #expect(error1.errorDescription!.contains("TestStrategy"))
    #expect(error1.errorDescription!.contains("not registered"))
    #expect(error2.errorDescription!.contains("ExistingStrategy"))
    #expect(error2.errorDescription!.contains("already registered"))
  }

  @Test("LocalizedError failureReason")
  func localizedErrorFailureReason() {
    let error1 = LockmanError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanError.strategyAlreadyRegistered("ExistingStrategy")

    #expect(error1.failureReason != nil)
    #expect(error2.failureReason != nil)
    #expect(error1.failureReason!.contains("resolution requires"))
    #expect(error2.failureReason!.contains("unique strategy"))
  }

  @Test("LocalizedError recoverySuggestion")
  func localizedErrorRecoverySuggestion() {
    let error1 = LockmanError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanError.strategyAlreadyRegistered("ExistingStrategy")

    #expect(error1.recoverySuggestion != nil)
    #expect(error2.recoverySuggestion != nil)
    #expect(error1.recoverySuggestion!.contains("register"))
    #expect(error2.recoverySuggestion!.contains("Check if"))
    #expect(error1.recoverySuggestion!.contains("TestStrategy"))
    #expect(error2.recoverySuggestion!.contains("ExistingStrategy"))
  }

  @Test("LocalizedError helpAnchor")
  func localizedErrorHelpAnchor() {
    let error1 = LockmanError.strategyNotRegistered("TestStrategy")
    let error2 = LockmanError.strategyAlreadyRegistered("ExistingStrategy")

    #expect(error1.helpAnchor == "LockmanStrategyContainer")
    #expect(error2.helpAnchor == "LockmanStrategyContainer")
  }

  // MARK: - Error Equality Tests

  @Test("Error equality semantics")
  func errorEqualitySemantics() {
    let error1a = LockmanError.strategyNotRegistered("TestStrategy")
    let error1b = LockmanError.strategyNotRegistered("TestStrategy")
    let error1c = LockmanError.strategyNotRegistered("DifferentStrategy")
    let error2 = LockmanError.strategyAlreadyRegistered("TestStrategy")

    // Same error type with same value should be equal
    switch (error1a, error1b) {
    case let (.strategyNotRegistered(a), .strategyNotRegistered(b)):
      #expect(a == b)
    default:
      #expect(Bool(false), "Expected strategyNotRegistered errors")
    }

    // Same error type with different values should not be equal
    switch (error1a, error1c) {
    case let (.strategyNotRegistered(a), .strategyNotRegistered(c)):
      #expect(a != c)
    default:
      #expect(Bool(false), "Expected strategyNotRegistered errors")
    }

    // Different error types should not be equal
    switch (error1a, error2) {
    case (.strategyNotRegistered, .strategyAlreadyRegistered):
      break // Expected different types
    default:
      #expect(Bool(false), "Expected different error types")
    }
  }

  // MARK: - Strategy Container Error Scenarios

  @Test("Multiple consecutive registration attempts")
  func multipleConsecutiveRegistrationAttempts() {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared

    // First registration should succeed
    #expect(throws: Never.self) {
      try container.register(strategy)
    }

    // Multiple subsequent registrations should all fail with same error
    for _ in 0 ..< 5 {
      #expect(throws: LockmanError.self) {
        try container.register(strategy)
      }

      do {
        try container.register(strategy)
      } catch let error as LockmanError {
        switch error {
        case let .strategyAlreadyRegistered(strategyType):
          #expect(strategyType.contains("LockmanSingleExecutionStrategy"))
        default:
          #expect(Bool(false), "Expected strategyAlreadyRegistered error")
        }
      } catch {
        #expect(Bool(false), "Expected LockmanError")
      }
    }
  }

  @Test("Registration error preserves container state")
  func registrationErrorPreservesContainerState() {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy()

    // Register first strategy
    try? container.register(strategy)

    // Verify it's registered
    #expect(container.isRegistered(LockmanPriorityBasedStrategy.self))

    // Try to register duplicate
    do {
      try container.register(strategy)
    } catch {
      // Expected to fail
    }

    // Verify original registration is still intact
    #expect(container.isRegistered(LockmanPriorityBasedStrategy.self))

    // Verify we can still resolve the original
    #expect(throws: Never.self) {
      _ = try container.resolve(LockmanPriorityBasedStrategy.self)
    }
  }

  @Test("Resolution error with detailed strategy name")
  func resolutionErrorWithDetailedStrategyName() {
    let container = LockmanStrategyContainer()

    do {
      _ = try container.resolve(LockmanPriorityBasedStrategy.self)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        #expect(strategyType.contains("LockmanPriorityBasedStrategy"))
        #expect(strategyType.count > 10) // Should be descriptive
      default:
        #expect(Bool(false), "Expected strategyNotRegistered error")
      }
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }
  }

  // MARK: - Concurrent Error Scenarios

  @Test("Concurrent registration error consistency")
  func concurrentRegistrationErrorConsistency() async {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()

    // Register once successfully
    try? container.register(strategy)

    await withTaskGroup(of: Bool.self) { group in
      // Try concurrent registrations
      for _ in 0 ..< 10 {
        group.addTask {
          do {
            let newStrategy = LockmanSingleExecutionStrategy()
            try container.register(newStrategy)
            return false // Should not succeed
          } catch is LockmanError {
            return true // Expected
          } catch {
            return false // Unexpected error type
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
      #expect(errorCount == 10)
    }
  }

  // MARK: - Error Message Edge Cases

  @Test("Error messages with special characters")
  func errorMessagesWithSpecialCharacters() {
    let specialStrategyName = "Strategy<With>Special&Characters@#$%"
    let error1 = LockmanError.strategyNotRegistered(specialStrategyName)
    let error2 = LockmanError.strategyAlreadyRegistered(specialStrategyName)

    #expect(error1.errorDescription!.contains(specialStrategyName))
    #expect(error2.errorDescription!.contains(specialStrategyName))
    #expect(error1.recoverySuggestion!.contains(specialStrategyName))
    #expect(error2.recoverySuggestion!.contains(specialStrategyName))
  }

  @Test("Error messages with very long strategy names")
  func errorMessagesWithVeryLongStrategyNames() {
    let longStrategyName = String(repeating: "VeryLongStrategyName", count: 10)
    let error = LockmanError.strategyNotRegistered(longStrategyName)

    #expect(error.errorDescription!.contains(longStrategyName))
    #expect(error.recoverySuggestion!.contains(longStrategyName))
    #expect(error.errorDescription!.count > 100) // Should still be comprehensive
  }

  @Test("Error messages with empty strategy name")
  func errorMessagesWithEmptyStrategyName() {
    let emptyName = ""
    let error1 = LockmanError.strategyNotRegistered(emptyName)
    let error2 = LockmanError.strategyAlreadyRegistered(emptyName)

    // Should still produce valid error messages
    #expect(error1.errorDescription != nil)
    #expect(error2.errorDescription != nil)
    #expect(error1.errorDescription!.count > 20)
    #expect(error2.errorDescription!.count > 20)
  }

  // MARK: - Error Recovery Tests

  @Test("Error recovery workflow")
  func errorRecoveryWorkflow() {
    let container = LockmanStrategyContainer()

    // Step 1: Try to resolve unregistered strategy (should fail)
    do {
      _ = try container.resolve(LockmanSingleExecutionStrategy.self)
      #expect(Bool(false), "Should have failed")
    } catch is LockmanError {
      // Expected
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }

    // Step 2: Follow recovery suggestion - register the strategy
    let strategy = LockmanSingleExecutionStrategy.shared
    try? container.register(strategy)

    // Step 3: Now resolution should succeed
    #expect(throws: Never.self) {
      _ = try container.resolve(LockmanSingleExecutionStrategy.self)
    }

    // Step 4: Try duplicate registration (should fail)
    do {
      try container.register(strategy)
      #expect(Bool(false), "Should have failed")
    } catch is LockmanError {
      // Expected
    } catch {
      #expect(Bool(false), "Expected LockmanError")
    }

    // Step 5: Verify original registration still works
    #expect(throws: Never.self) {
      _ = try container.resolve(LockmanSingleExecutionStrategy.self)
    }
  }
}
