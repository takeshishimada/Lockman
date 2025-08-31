import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanRegistrationError tests with 3-phase approach
// ✅ 15 test methods covering all enum cases and LocalizedError implementation
// ✅ Phase 1: Basic enum cases and properties testing
// ✅ Phase 2: LocalizedError conformance and message testing
// ✅ Phase 3: Protocol conformance, edge cases, and pattern matching

final class LockmanRegistrationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Basic Enum Cases

  func testLockmanRegistrationErrorStrategyAlreadyRegisteredCase() {
    // Test .strategyAlreadyRegistered case with various strategy names
    let testCases = [
      "TestStrategy",
      "LockmanSingleExecutionStrategy",
      "MyCustomStrategy",
      "Strategy-With-Dashes",
      "Strategy_With_Underscores",
      "StrategyWith123Numbers",
      "",
    ]

    for strategyName in testCases {
      let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)

      // Test pattern matching
      switch error {
      case .strategyAlreadyRegistered(let name):
        XCTAssertEqual(name, strategyName, "Strategy name should match for: '\(strategyName)'")
      case .strategyNotRegistered:
        XCTFail("Should match .strategyAlreadyRegistered case for: '\(strategyName)'")
      }
    }
  }

  func testLockmanRegistrationErrorStrategyNotRegisteredCase() {
    // Test .strategyNotRegistered case with various strategy names
    let testCases = [
      "UnregisteredStrategy",
      "NonExistentStrategy",
      "Missing-Strategy",
      "Strategy_Not_Found",
      "UnknownStrategy123",
      "",
    ]

    for strategyName in testCases {
      let error = LockmanRegistrationError.strategyNotRegistered(strategyName)

      // Test pattern matching
      switch error {
      case .strategyNotRegistered(let name):
        XCTAssertEqual(name, strategyName, "Strategy name should match for: '\(strategyName)'")
      case .strategyAlreadyRegistered:
        XCTFail("Should match .strategyNotRegistered case for: '\(strategyName)'")
      }
    }
  }

  func testLockmanRegistrationErrorEquatableConformance() {
    // Test Equatable conformance (inherited from enum)
    let error1 = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let error2 = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let error3 = LockmanRegistrationError.strategyAlreadyRegistered("DifferentStrategy")
    let error4 = LockmanRegistrationError.strategyNotRegistered("TestStrategy")

    // Test equality
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
    XCTAssertNotEqual(error1, error4)

    let notRegError1 = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")
    let notRegError2 = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")
    let notRegError3 = LockmanRegistrationError.strategyNotRegistered("DifferentUnknown")

    XCTAssertEqual(notRegError1, notRegError2)
    XCTAssertNotEqual(notRegError1, notRegError3)
    XCTAssertNotEqual(notRegError1, error1)
  }

  // MARK: - Phase 2: LocalizedError Conformance

  func testLockmanRegistrationErrorDescription() {
    // Test errorDescription for .strategyAlreadyRegistered
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let expectedAlreadyRegDesc =
      "Strategy 'TestStrategy' is already registered. Each strategy type can only be registered once."
    XCTAssertEqual(alreadyRegError.errorDescription, expectedAlreadyRegDesc)

    // Test errorDescription for .strategyNotRegistered
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")
    let expectedNotRegDesc =
      "Strategy 'UnknownStrategy' is not registered. Please register the strategy before attempting to resolve it."
    XCTAssertEqual(notRegError.errorDescription, expectedNotRegDesc)

    // Test with empty string
    let emptyAlreadyReg = LockmanRegistrationError.strategyAlreadyRegistered("")
    let expectedEmptyAlreadyReg =
      "Strategy '' is already registered. Each strategy type can only be registered once."
    XCTAssertEqual(emptyAlreadyReg.errorDescription, expectedEmptyAlreadyReg)

    let emptyNotReg = LockmanRegistrationError.strategyNotRegistered("")
    let expectedEmptyNotReg =
      "Strategy '' is not registered. Please register the strategy before attempting to resolve it."
    XCTAssertEqual(emptyNotReg.errorDescription, expectedEmptyNotReg)
  }

  func testLockmanRegistrationErrorFailureReason() {
    // Test failureReason for .strategyAlreadyRegistered
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let expectedAlreadyRegReason =
      "The container enforces unique strategy type registration to prevent conflicts and ensure deterministic behavior."
    XCTAssertEqual(alreadyRegError.failureReason, expectedAlreadyRegReason)

    // Test failureReason for .strategyNotRegistered
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")
    let expectedNotRegReason =
      "Strategy resolution requires that the strategy type has been previously registered in the container."
    XCTAssertEqual(notRegError.failureReason, expectedNotRegReason)

    // Test that failure reason doesn't depend on strategy name
    let differentNameError = LockmanRegistrationError.strategyAlreadyRegistered("DifferentName")
    XCTAssertEqual(differentNameError.failureReason, expectedAlreadyRegReason)
  }

  func testLockmanRegistrationErrorRecoverySuggestion() {
    // Test recoverySuggestion for .strategyAlreadyRegistered
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let expectedAlreadyRegSuggestion =
      "Check if 'TestStrategy' is being registered multiple times. Use container.isRegistered(_:) to check before registration, or ensure registration happens only once during app startup."
    XCTAssertEqual(alreadyRegError.recoverySuggestion, expectedAlreadyRegSuggestion)

    // Test recoverySuggestion for .strategyNotRegistered
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")
    let expectedNotRegSuggestion =
      "Add 'try LockmanManager.container.register(UnknownStrategy.shared)' to your app startup code, or verify that registration is happening before this resolution attempt."
    XCTAssertEqual(notRegError.recoverySuggestion, expectedNotRegSuggestion)

    // Test with different strategy names
    let customStrategyError = LockmanRegistrationError.strategyAlreadyRegistered("MyCustomStrategy")
    let expectedCustomSuggestion =
      "Check if 'MyCustomStrategy' is being registered multiple times. Use container.isRegistered(_:) to check before registration, or ensure registration happens only once during app startup."
    XCTAssertEqual(customStrategyError.recoverySuggestion, expectedCustomSuggestion)
  }

  func testLockmanRegistrationErrorHelpAnchor() {
    // Test helpAnchor for all cases
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")

    let expectedHelpAnchor = "LockmanStrategyContainer"
    XCTAssertEqual(alreadyRegError.helpAnchor, expectedHelpAnchor)
    XCTAssertEqual(notRegError.helpAnchor, expectedHelpAnchor)

    // Test that help anchor is consistent across different strategy names
    let differentNameError1 = LockmanRegistrationError.strategyAlreadyRegistered(
      "DifferentStrategy")
    let differentNameError2 = LockmanRegistrationError.strategyNotRegistered("AnotherStrategy")

    XCTAssertEqual(differentNameError1.helpAnchor, expectedHelpAnchor)
    XCTAssertEqual(differentNameError2.helpAnchor, expectedHelpAnchor)
  }

  func testLockmanRegistrationErrorLocalizedErrorConformance() {
    // Test that LockmanRegistrationError conforms to LocalizedError
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")

    // Verify LocalizedError conformance
    XCTAssertTrue(alreadyRegError is LocalizedError)
    XCTAssertTrue(notRegError is LocalizedError)

    // Test as LocalizedError
    let localizedError1: any LocalizedError = alreadyRegError
    let localizedError2: any LocalizedError = notRegError

    XCTAssertNotNil(localizedError1.errorDescription)
    XCTAssertNotNil(localizedError1.failureReason)
    XCTAssertNotNil(localizedError1.recoverySuggestion)
    XCTAssertNotNil(localizedError1.helpAnchor)

    XCTAssertNotNil(localizedError2.errorDescription)
    XCTAssertNotNil(localizedError2.failureReason)
    XCTAssertNotNil(localizedError2.recoverySuggestion)
    XCTAssertNotNil(localizedError2.helpAnchor)
  }

  // MARK: - Phase 3: Protocol Conformance and Type Safety

  func testLockmanRegistrationErrorLockmanErrorConformance() {
    // Test that LockmanRegistrationError conforms to LockmanError
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegError = LockmanRegistrationError.strategyNotRegistered("UnknownStrategy")

    // Verify LockmanError conformance
    XCTAssertTrue(alreadyRegError is LockmanError)
    XCTAssertTrue(notRegError is LockmanError)

    // Test that they can be used as LockmanError
    let lockmanError1: any LockmanError = alreadyRegError
    let lockmanError2: any LockmanError = notRegError

    XCTAssertTrue(lockmanError1 is LockmanRegistrationError)
    XCTAssertTrue(lockmanError2 is LockmanRegistrationError)

    // Test Error conformance (inherited)
    XCTAssertTrue(alreadyRegError is Error)
    XCTAssertTrue(notRegError is Error)

    let error1: any Error = alreadyRegError
    let error2: any Error = notRegError

    XCTAssertTrue(error1 is LockmanRegistrationError)
    XCTAssertTrue(error2 is LockmanRegistrationError)
  }

  func testLockmanRegistrationErrorSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let errors: [LockmanRegistrationError] = [
      .strategyAlreadyRegistered("ConcurrentStrategy1"),
      .strategyNotRegistered("ConcurrentStrategy2"),
      .strategyAlreadyRegistered("ConcurrentStrategy3"),
      .strategyNotRegistered("ConcurrentStrategy4"),
    ]

    await withTaskGroup(of: String.self) { group in
      for (index, error) in errors.enumerated() {
        group.addTask {
          // This compiles without warning = Sendable works
          let description = error.errorDescription ?? "No description"
          let reason = error.failureReason ?? "No reason"
          return "Task\(index): \(description) | \(reason)"
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 4)
      // Verify all results contain expected information
      for result in results {
        XCTAssertTrue(result.contains("Strategy") || result.contains("No description"))
        XCTAssertTrue(
          result.contains("registered") || result.contains("container")
            || result.contains("No reason"))
      }
    }
  }

  func testLockmanRegistrationErrorAsGenericError() {
    // Test usage in generic error handling contexts
    let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered("GenericTestStrategy")
    let notRegError = LockmanRegistrationError.strategyNotRegistered("GenericUnknownStrategy")

    // Test in generic function that handles Error
    func handleGenericError<E: Error>(_ error: E) -> String {
      if let localizedError = error as? any LocalizedError {
        return localizedError.errorDescription ?? "No description"
      }
      return "Unknown error"
    }

    let result1 = handleGenericError(alreadyRegError)
    let result2 = handleGenericError(notRegError)

    XCTAssertTrue(result1.contains("GenericTestStrategy"))
    XCTAssertTrue(result1.contains("already registered"))

    XCTAssertTrue(result2.contains("GenericUnknownStrategy"))
    XCTAssertTrue(result2.contains("not registered"))

    // Test in generic function that handles LockmanError
    func handleLockmanError<E: LockmanError>(_ error: E) -> Bool {
      return error is LockmanRegistrationError
    }

    XCTAssertTrue(handleLockmanError(alreadyRegError))
    XCTAssertTrue(handleLockmanError(notRegError))
  }

  // MARK: - Phase 4: Edge Cases and Special Scenarios

  func testLockmanRegistrationErrorWithSpecialCharacters() {
    // Test with special characters in strategy names
    let specialCases: [String] = [
      "Strategy@Special",
      "Strategy#Hash",
      "Strategy$Dollar",
      "Strategy%Percent",
      "Strategy^Caret",
      "Strategy&Ampersand",
      "Strategy*Asterisk",
      "Strategy(Parentheses)",
      "Strategy[Brackets]",
      "Strategy{Braces}",
      "Strategy|Pipe",
      "Strategy\\Backslash",
      "Strategy/Forward-Slash",
      "Strategy:Colon",
      "Strategy;Semicolon",
      "Strategy\"Quote",
      "Strategy'Apostrophe",
      "Strategy<Less>",
      "Strategy=Equal",
      "Strategy?Question",
      "Strategy,Comma",
      "Strategy.Dot",
      "Strategy~Tilde",
      "Strategy`Backtick",
    ]

    for strategyName in specialCases {
      let alreadyRegError = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
      let notRegError = LockmanRegistrationError.strategyNotRegistered(strategyName)

      // Verify error descriptions contain the strategy name
      XCTAssertTrue(
        alreadyRegError.errorDescription?.contains(strategyName) == true,
        "Error description should contain strategy name: '\(strategyName)'")
      XCTAssertTrue(
        notRegError.errorDescription?.contains(strategyName) == true,
        "Error description should contain strategy name: '\(strategyName)'")

      // Verify recovery suggestions contain the strategy name
      XCTAssertTrue(
        alreadyRegError.recoverySuggestion?.contains(strategyName) == true,
        "Recovery suggestion should contain strategy name: '\(strategyName)'")
      XCTAssertTrue(
        notRegError.recoverySuggestion?.contains(strategyName) == true,
        "Recovery suggestion should contain strategy name: '\(strategyName)'")
    }
  }

  func testLockmanRegistrationErrorExhaustivePatternMatching() {
    // Test comprehensive pattern matching
    let allErrors: [LockmanRegistrationError] = [
      .strategyAlreadyRegistered("Pattern1"),
      .strategyNotRegistered("Pattern2"),
      .strategyAlreadyRegistered("Pattern3"),
      .strategyNotRegistered("Pattern4"),
    ]

    for (index, error) in allErrors.enumerated() {
      let result = classifyRegistrationError(error)

      switch index {
      case 0, 2:
        XCTAssertEqual(result.type, "already_registered")
        XCTAssertTrue(result.strategyName.hasPrefix("Pattern"))
      case 1, 3:
        XCTAssertEqual(result.type, "not_registered")
        XCTAssertTrue(result.strategyName.hasPrefix("Pattern"))
      default:
        XCTFail("Unexpected index: \(index)")
      }
    }
  }

  func testLockmanRegistrationErrorInCollections() {
    // Test behavior in collections (using Equatable/Hashable)
    let errors: [LockmanRegistrationError] = [
      .strategyAlreadyRegistered("CollectionStrategy1"),
      .strategyNotRegistered("CollectionStrategy2"),
      .strategyAlreadyRegistered("CollectionStrategy1"),  // duplicate
      .strategyNotRegistered("CollectionStrategy3"),
    ]

    XCTAssertEqual(errors.count, 4)

    // Test filtering
    let alreadyRegisteredErrors = errors.filter { error in
      if case .strategyAlreadyRegistered = error { return true }
      return false
    }
    XCTAssertEqual(alreadyRegisteredErrors.count, 2)

    let notRegisteredErrors = errors.filter { error in
      if case .strategyNotRegistered = error { return true }
      return false
    }
    XCTAssertEqual(notRegisteredErrors.count, 2)

    // Test contains (uses Equatable)
    XCTAssertTrue(errors.contains(.strategyAlreadyRegistered("CollectionStrategy1")))
    XCTAssertTrue(errors.contains(.strategyNotRegistered("CollectionStrategy2")))
    XCTAssertFalse(errors.contains(.strategyNotRegistered("NonExistent")))
  }

  // MARK: - Helper Functions

  private func classifyRegistrationError(_ error: LockmanRegistrationError) -> (
    type: String, strategyName: String
  ) {
    switch error {
    case .strategyAlreadyRegistered(let name):
      return ("already_registered", name)
    case .strategyNotRegistered(let name):
      return ("not_registered", name)
    }
  }

}
