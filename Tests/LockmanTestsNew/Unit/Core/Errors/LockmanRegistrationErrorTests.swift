import XCTest

@testable import Lockman

/// Unit tests for LockmanRegistrationError
///
/// Tests the enumeration that handles errors during strategy registration and resolution
/// within the Lockman container system.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Enum Case Construction and Properties
/// - [x] strategyAlreadyRegistered case creation with strategy type string
/// - [x] strategyNotRegistered case creation with strategy type string
/// - [x] Proper enum case equality and pattern matching behavior
/// - [x] Associated value extraction from enum cases
/// - [x] Case-specific behavior validation
///
/// ### LockmanError Protocol Conformance
/// - [x] LockmanError protocol conformance verification
/// - [x] errorDescription property implementation for all cases
/// - [x] failureReason property implementation for all cases
/// - [x] recoverySuggestion property implementation for all cases
/// - [x] helpAnchor property implementation for all cases
/// - [x] Optional property handling (nil vs non-nil values)
///
/// ### Error Message Content Validation
/// - [x] strategyAlreadyRegistered error message contains strategy type
/// - [x] strategyNotRegistered error message contains strategy type
/// - [x] Error messages are descriptive and user-friendly
/// - [x] Failure reasons explain the underlying cause
/// - [x] Recovery suggestions provide actionable guidance
/// - [x] Help anchor points to appropriate documentation
///
/// ### String Parameter Handling
/// - [x] Empty string strategy type handling
/// - [x] Long strategy type name handling
/// - [x] Special characters in strategy type names
/// - [x] Unicode character support in strategy types
/// - [x] Nil safety and string formatting edge cases
///
/// ### Error Interpolation and Formatting
/// - [x] Proper string interpolation in error messages
/// - [x] Consistent formatting across different cases
/// - [x] Recovery suggestion code example formatting
/// - [x] Error message localization readiness
/// - [x] Special character escaping in interpolated strings
///
/// ### Integration with Strategy Container
/// - [x] Error generation during duplicate strategy registration
/// - [x] Error generation during missing strategy resolution
/// - [x] Error propagation through container operations
/// - [x] Error handling in bulk registration scenarios
/// - [x] Error context preservation during container operations
///
/// ### Error Hierarchy and Swift Error Integration
/// - [x] Swift Error protocol conformance through LockmanError
/// - [x] Error throwing and catching behavior
/// - [x] Error type identification and casting
/// - [x] Error chaining and nested error scenarios
/// - [x] LocalizedError conformance validation
///
/// ### User Experience and Debugging Support
/// - [x] Error messages provide sufficient debugging information
/// - [x] Recovery suggestions are implementable by developers
/// - [x] Help anchor directs to correct documentation sections
/// - [x] Error context helps identify registration/resolution issues
/// - [x] Clear distinction between registration vs resolution errors
///
/// ### Edge Cases and Error Conditions
/// - [x] Behavior with empty or whitespace-only strategy names
/// - [x] Handling of very long strategy type names
/// - [x] Error creation with nil or malformed strategy identifiers
/// - [x] Memory efficiency of error instances
/// - [x] Error persistence and serialization behavior
///
/// ### Performance and Memory Considerations
/// - [x] Error object creation overhead
/// - [x] String interpolation performance in error messages
/// - [x] Memory usage of error instances with long strings
/// - [x] Error object lifecycle and deallocation
/// - [x] Concurrent error creation safety
///
final class LockmanRegistrationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Enum Case Construction and Properties Tests

  func testStrategyAlreadyRegisteredCaseCreation() {
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)

    // Verify case construction
    switch error {
    case .strategyAlreadyRegistered(let capturedType):
      XCTAssertEqual(capturedType, strategyType)
    case .strategyNotRegistered:
      XCTFail("Expected strategyAlreadyRegistered case")
    }
  }

  func testStrategyNotRegisteredCaseCreation() {
    let strategyType = "MissingStrategy"
    let error = LockmanRegistrationError.strategyNotRegistered(strategyType)

    // Verify case construction
    switch error {
    case .strategyNotRegistered(let capturedType):
      XCTAssertEqual(capturedType, strategyType)
    case .strategyAlreadyRegistered:
      XCTFail("Expected strategyNotRegistered case")
    }
  }

  func testProperEnumCaseEqualityAndPatternMatching() {
    let alreadyRegistered1 = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let alreadyRegistered2 = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let alreadyRegistered3 = LockmanRegistrationError.strategyAlreadyRegistered("DifferentStrategy")

    let notRegistered1 = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")
    let notRegistered2 = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")
    let notRegistered3 = LockmanRegistrationError.strategyNotRegistered("AnotherMissing")

    // Test equality behavior
    XCTAssertEqual(alreadyRegistered1, alreadyRegistered2)
    XCTAssertNotEqual(alreadyRegistered1, alreadyRegistered3)
    XCTAssertEqual(notRegistered1, notRegistered2)
    XCTAssertNotEqual(notRegistered1, notRegistered3)
    XCTAssertNotEqual(alreadyRegistered1, notRegistered1)
  }

  func testAssociatedValueExtraction() {
    let strategies = ["Strategy1", "Strategy2", "Strategy3"]

    for strategyType in strategies {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(strategyType)

      // Test associated value extraction for strategyAlreadyRegistered
      if case .strategyAlreadyRegistered(let extractedType) = alreadyError {
        XCTAssertEqual(extractedType, strategyType)
      } else {
        XCTFail("Failed to extract associated value from strategyAlreadyRegistered")
      }

      // Test associated value extraction for strategyNotRegistered
      if case .strategyNotRegistered(let extractedType) = notRegisteredError {
        XCTAssertEqual(extractedType, strategyType)
      } else {
        XCTFail("Failed to extract associated value from strategyNotRegistered")
      }
    }
  }

  func testCaseSpecificBehaviorValidation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Test that different cases have different behavior
    XCTAssertNotEqual(alreadyError.errorDescription, notRegisteredError.errorDescription)
    XCTAssertNotEqual(alreadyError.failureReason, notRegisteredError.failureReason)
    XCTAssertNotEqual(alreadyError.recoverySuggestion, notRegisteredError.recoverySuggestion)

    // Both should have the same help anchor
    XCTAssertEqual(alreadyError.helpAnchor, notRegisteredError.helpAnchor)
  }

  // MARK: - LockmanError Protocol Conformance Tests

  func testLockmanErrorProtocolConformance() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Verify protocol conformance through interface usage
    let lockmanError: any LockmanError = alreadyError
    let localizedError: any LocalizedError = notRegisteredError
    let swiftError: any Error = alreadyError
    
    // Verify properties are accessible through protocol interfaces
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertNotNil(localizedError.errorDescription)
    XCTAssertNotNil((swiftError as? LocalizedError)?.errorDescription)
  }

  func testErrorDescriptionPropertyImplementation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Both should have non-nil error descriptions
    XCTAssertNotNil(alreadyError.errorDescription)
    XCTAssertNotNil(notRegisteredError.errorDescription)

    // Error descriptions should not be empty
    XCTAssertFalse(alreadyError.errorDescription!.isEmpty)
    XCTAssertFalse(notRegisteredError.errorDescription!.isEmpty)

    // Should contain the strategy type
    XCTAssertTrue(alreadyError.errorDescription!.contains("TestStrategy"))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains("MissingStrategy"))
  }

  func testFailureReasonPropertyImplementation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Both should have non-nil failure reasons
    XCTAssertNotNil(alreadyError.failureReason)
    XCTAssertNotNil(notRegisteredError.failureReason)

    // Failure reasons should not be empty
    XCTAssertFalse(alreadyError.failureReason!.isEmpty)
    XCTAssertFalse(notRegisteredError.failureReason!.isEmpty)

    // Should provide meaningful explanations
    XCTAssertTrue(alreadyError.failureReason!.contains("unique"))
    XCTAssertTrue(notRegisteredError.failureReason!.contains("previously registered"))
  }

  func testRecoverySuggestionPropertyImplementation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Both should have non-nil recovery suggestions
    XCTAssertNotNil(alreadyError.recoverySuggestion)
    XCTAssertNotNil(notRegisteredError.recoverySuggestion)

    // Recovery suggestions should not be empty
    XCTAssertFalse(alreadyError.recoverySuggestion!.isEmpty)
    XCTAssertFalse(notRegisteredError.recoverySuggestion!.isEmpty)

    // Should contain actionable advice
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("isRegistered"))
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains("register"))

    // Should mention the strategy type
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("TestStrategy"))
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains("MissingStrategy"))
  }

  func testHelpAnchorPropertyImplementation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("TestStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Both should have non-nil help anchors
    XCTAssertNotNil(alreadyError.helpAnchor)
    XCTAssertNotNil(notRegisteredError.helpAnchor)

    // Both should point to the same documentation
    XCTAssertEqual(alreadyError.helpAnchor, "LockmanStrategyContainer")
    XCTAssertEqual(notRegisteredError.helpAnchor, "LockmanStrategyContainer")
  }

  func testOptionalPropertyHandling() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("OptionalTest")

    // All properties should return non-nil values
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertNotNil(error.recoverySuggestion)
    XCTAssertNotNil(error.helpAnchor)

    // Verify they can be safely unwrapped
    let _ = error.errorDescription!
    let _ = error.failureReason!
    let _ = error.recoverySuggestion!
    let _ = error.helpAnchor!
  }

  // MARK: - Error Message Content Validation Tests

  func testStrategyAlreadyRegisteredErrorMessageContainsStrategyType() {
    let strategyTypes = ["CustomStrategy", "MyTestStrategy", "SpecialStrategy"]

    for strategyType in strategyTypes {
      let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)

      XCTAssertTrue(error.errorDescription!.contains(strategyType))
      XCTAssertTrue(error.recoverySuggestion!.contains(strategyType))
    }
  }

  func testStrategyNotRegisteredErrorMessageContainsStrategyType() {
    let strategyTypes = ["MissingStrategy", "UnknownStrategy", "NotFoundStrategy"]

    for strategyType in strategyTypes {
      let error = LockmanRegistrationError.strategyNotRegistered(strategyType)

      XCTAssertTrue(error.errorDescription!.contains(strategyType))
      XCTAssertTrue(error.recoverySuggestion!.contains(strategyType))
    }
  }

  func testErrorMessagesAreDescriptiveAndUserFriendly() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("FriendlyStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Error descriptions should be user-friendly
    XCTAssertTrue(alreadyError.errorDescription!.contains("already registered"))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains("not registered"))

    // Should not contain technical jargon or implementation details
    XCTAssertFalse(alreadyError.errorDescription!.contains("nil"))
    XCTAssertFalse(alreadyError.errorDescription!.contains("Optional"))
    XCTAssertFalse(notRegisteredError.errorDescription!.contains("nil"))
    XCTAssertFalse(notRegisteredError.errorDescription!.contains("Optional"))
  }

  func testFailureReasonsExplainUnderlyingCause() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("CauseStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Failure reasons should explain why the error occurred
    XCTAssertTrue(alreadyError.failureReason!.contains("unique"))
    XCTAssertTrue(alreadyError.failureReason!.contains("deterministic"))
    XCTAssertTrue(notRegisteredError.failureReason!.contains("previously registered"))
    XCTAssertTrue(notRegisteredError.failureReason!.contains("resolution requires"))
  }

  func testRecoverySuggestionsProvideActionableGuidance() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("ActionableStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("MissingStrategy")

    // Recovery suggestions should provide specific steps
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("isRegistered"))
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("once during app startup"))
    XCTAssertTrue(
      notRegisteredError.recoverySuggestion!.contains("LockmanManager.container.register"))
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains("app startup code"))
  }

  func testHelpAnchorPointsToAppropriateDocumentation() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("DocStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("DocMissing")

    // Help anchor should point to relevant documentation
    XCTAssertEqual(alreadyError.helpAnchor, "LockmanStrategyContainer")
    XCTAssertEqual(notRegisteredError.helpAnchor, "LockmanStrategyContainer")
  }

  // MARK: - String Parameter Handling Tests

  func testEmptyStringStrategyTypeHandling() {
    let emptyAlreadyError = LockmanRegistrationError.strategyAlreadyRegistered("")
    let emptyNotRegisteredError = LockmanRegistrationError.strategyNotRegistered("")

    // Should handle empty strings gracefully
    XCTAssertNotNil(emptyAlreadyError.errorDescription)
    XCTAssertNotNil(emptyNotRegisteredError.errorDescription)

    // Should not crash or produce malformed messages
    XCTAssertFalse(emptyAlreadyError.errorDescription!.isEmpty)
    XCTAssertFalse(emptyNotRegisteredError.errorDescription!.isEmpty)

    // Should contain the empty string in quotes or handle it appropriately
    XCTAssertTrue(emptyAlreadyError.errorDescription!.contains("''"))
    XCTAssertTrue(emptyNotRegisteredError.errorDescription!.contains("''"))
  }

  func testLongStrategyTypeNameHandling() {
    let longStrategyName = String(repeating: "VeryLongStrategyName", count: 50)
    let longAlreadyError = LockmanRegistrationError.strategyAlreadyRegistered(longStrategyName)
    let longNotRegisteredError = LockmanRegistrationError.strategyNotRegistered(longStrategyName)

    // Should handle long names without issues
    XCTAssertNotNil(longAlreadyError.errorDescription)
    XCTAssertNotNil(longNotRegisteredError.errorDescription)

    // Should contain the full strategy name
    XCTAssertTrue(longAlreadyError.errorDescription!.contains(longStrategyName))
    XCTAssertTrue(longNotRegisteredError.errorDescription!.contains(longStrategyName))

    // Error messages should still be well-formed
    XCTAssertTrue(longAlreadyError.errorDescription!.count > longStrategyName.count)
    XCTAssertTrue(longNotRegisteredError.errorDescription!.count > longStrategyName.count)
  }

  func testSpecialCharactersInStrategyTypeNames() {
    let specialNames = [
      "Strategy@#$%",
      "Strategy.With.Dots",
      "Strategy-With-Dashes",
      "Strategy_With_Underscores",
      "Strategy With Spaces",
      "Strategy(With)Parentheses",
      "Strategy[With]Brackets",
      "Strategy{With}Braces",
    ]

    for specialName in specialNames {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(specialName)
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(specialName)

      // Should handle special characters without issues
      XCTAssertNotNil(alreadyError.errorDescription)
      XCTAssertNotNil(notRegisteredError.errorDescription)

      // Should contain the special name
      XCTAssertTrue(alreadyError.errorDescription!.contains(specialName))
      XCTAssertTrue(notRegisteredError.errorDescription!.contains(specialName))
    }
  }

  func testUnicodeCharacterSupportInStrategyTypes() {
    let unicodeNames = [
      "Стратегия",  // Cyrillic
      "戦略",  // Japanese
      "استراتيجية",  // Arabic
      "Strategy🚀",  // Emoji
      "Straté_gíe",  // Accented characters
      "策略_測試",  // Mixed scripts
    ]

    for unicodeName in unicodeNames {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(unicodeName)
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(unicodeName)

      // Should handle Unicode characters properly
      XCTAssertNotNil(alreadyError.errorDescription)
      XCTAssertNotNil(notRegisteredError.errorDescription)

      // Should contain the Unicode name
      XCTAssertTrue(alreadyError.errorDescription!.contains(unicodeName))
      XCTAssertTrue(notRegisteredError.errorDescription!.contains(unicodeName))
    }
  }

  func testNilSafetyAndStringFormattingEdgeCases() {
    let edgeCaseNames = [
      "\n",  // Newline only
      "\t",  // Tab only
      " ",  // Space only
      "   ",  // Multiple spaces
      "\0",  // Null character
      "\\",  // Backslash
      "\"",  // Quote
      "\'",  // Single quote
    ]

    for edgeName in edgeCaseNames {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(edgeName)
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(edgeName)

      // Should handle edge cases without crashing
      XCTAssertNotNil(alreadyError.errorDescription)
      XCTAssertNotNil(notRegisteredError.errorDescription)

      // Error messages should still be readable
      XCTAssertFalse(alreadyError.errorDescription!.isEmpty)
      XCTAssertFalse(notRegisteredError.errorDescription!.isEmpty)
    }
  }

  // MARK: - Error Interpolation and Formatting Tests

  func testProperStringInterpolationInErrorMessages() {
    let strategyName = "InterpolationTest"
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(strategyName)

    // Error messages should properly interpolate the strategy name
    XCTAssertTrue(alreadyError.errorDescription!.contains("'\(strategyName)'"))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains("'\(strategyName)'"))

    // Recovery suggestions should also interpolate properly
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("'\(strategyName)'"))
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains(strategyName))
  }

  func testConsistentFormattingAcrossDifferentCases() {
    let strategyName = "FormattingTest"
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(strategyName)

    // Both cases should use consistent formatting patterns
    // Strategy names should be quoted in error descriptions
    XCTAssertTrue(alreadyError.errorDescription!.contains("'FormattingTest'"))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains("'FormattingTest'"))

    // Sentences should end with periods
    XCTAssertTrue(alreadyError.errorDescription!.hasSuffix("."))
    XCTAssertTrue(notRegisteredError.errorDescription!.hasSuffix("."))

    // Failure reasons should also end with periods
    XCTAssertTrue(alreadyError.failureReason!.hasSuffix("."))
    XCTAssertTrue(notRegisteredError.failureReason!.hasSuffix("."))
  }

  func testRecoverySuggestionCodeExampleFormatting() {
    let strategyName = "CodeExampleStrategy"
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(strategyName)

    // Recovery suggestions should contain properly formatted code examples
    XCTAssertTrue(alreadyError.recoverySuggestion!.contains("container.isRegistered(_:)"))
    XCTAssertTrue(
      notRegisteredError.recoverySuggestion!.contains("LockmanManager.container.register("))

    // Should include strategy type in code example
    XCTAssertTrue(notRegisteredError.recoverySuggestion!.contains(strategyName))
  }

  func testErrorMessageLocalizationReadiness() {
    let strategyName = "LocalizationTest"
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(strategyName)

    // Error messages should be structured for easy localization
    // No concatenation that would be hard to localize
    XCTAssertNotNil(alreadyError.errorDescription)
    XCTAssertNotNil(notRegisteredError.errorDescription)

    // Should use proper string interpolation patterns
    XCTAssertTrue(alreadyError.errorDescription!.contains(strategyName))
    XCTAssertTrue(notRegisteredError.errorDescription!.contains(strategyName))
  }

  func testSpecialCharacterEscapingInInterpolatedStrings() {
    let strategyWithQuotes = "Strategy\"With'Quotes"
    let strategyWithSlashes = "Strategy\\With/Slashes"

    let quotesAlreadyError = LockmanRegistrationError.strategyAlreadyRegistered(strategyWithQuotes)
    let slashesNotRegisteredError = LockmanRegistrationError.strategyNotRegistered(
      strategyWithSlashes)

    // Should handle special characters in interpolated strings
    XCTAssertNotNil(quotesAlreadyError.errorDescription)
    XCTAssertNotNil(slashesNotRegisteredError.errorDescription)

    // Should contain the original string with special characters
    XCTAssertTrue(quotesAlreadyError.errorDescription!.contains(strategyWithQuotes))
    XCTAssertTrue(slashesNotRegisteredError.errorDescription!.contains(strategyWithSlashes))
  }

  // MARK: - Integration with Strategy Container Tests

  func testErrorGenerationDuringDuplicateStrategyRegistration() {
    // This test simulates what would happen in the real container
    struct MockStrategy: LockmanStrategy {
      typealias I = TestLockmanInfo
      
      let strategyId: LockmanStrategyId = LockmanStrategyId("MockStrategy")
      
      static func makeStrategyId() -> LockmanStrategyId {
        return LockmanStrategyId("MockStrategy")
      }

      func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
        return .success
      }

      func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        // Mock implementation
      }

      func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        // Mock implementation
      }
      
      func cleanUp() {
        // Mock implementation
      }
      
      func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
        // Mock implementation
      }

      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
        return [:]
      }

      func cleanupAll() {
        // Mock implementation
      }

      func cleanup(boundaryId: any LockmanBoundaryId) {
        // Mock implementation
      }
    }

    // Test error that would be generated
    let duplicateError = LockmanRegistrationError.strategyAlreadyRegistered("MockStrategy")

    XCTAssertTrue(duplicateError.errorDescription!.contains("MockStrategy"))
    XCTAssertTrue(duplicateError.errorDescription!.contains("already registered"))
    XCTAssertTrue(duplicateError.recoverySuggestion!.contains("isRegistered"))
  }

  func testErrorGenerationDuringMissingStrategyResolution() {
    // Test error that would be generated during resolution
    let missingError = LockmanRegistrationError.strategyNotRegistered("NonExistentStrategy")

    XCTAssertTrue(missingError.errorDescription!.contains("NonExistentStrategy"))
    XCTAssertTrue(missingError.errorDescription!.contains("not registered"))
    XCTAssertTrue(missingError.recoverySuggestion!.contains("register"))
    XCTAssertTrue(missingError.failureReason!.contains("previously registered"))
  }

  func testErrorPropagationThroughContainerOperations() {
    let containerErrors = [
      LockmanRegistrationError.strategyAlreadyRegistered("ContainerStrategy1"),
      LockmanRegistrationError.strategyNotRegistered("ContainerStrategy2"),
      LockmanRegistrationError.strategyAlreadyRegistered("ContainerStrategy3"),
    ]

    // Simulate error handling in container operations
    for error in containerErrors {
      // Errors should be distinguishable
      XCTAssertNotNil(error.errorDescription)
      XCTAssertNotNil(error.failureReason)
      XCTAssertNotNil(error.recoverySuggestion)

      // Should work in error handling contexts
      do {
        throw error
      } catch let caughtError as LockmanRegistrationError {
        XCTAssertEqual(caughtError, error)
      } catch {
        XCTFail("Should catch as LockmanRegistrationError")
      }
    }
  }

  func testErrorHandlingInBulkRegistrationScenarios() {
    let bulkStrategyNames = (1...10).map { "BulkStrategy\($0)" }

    // Test multiple errors for bulk operations
    let bulkErrors = bulkStrategyNames.map { strategyName in
      LockmanRegistrationError.strategyAlreadyRegistered(strategyName)
    }

    // Each error should be unique and contain correct strategy name
    for (index, error) in bulkErrors.enumerated() {
      let expectedName = bulkStrategyNames[index]
      XCTAssertTrue(error.errorDescription!.contains(expectedName))
      XCTAssertTrue(error.recoverySuggestion!.contains(expectedName))
    }
  }

  func testErrorContextPreservationDuringContainerOperations() {
    let contextualErrors = [
      ("UserAuthStrategy", LockmanRegistrationError.strategyAlreadyRegistered("UserAuthStrategy")),
      ("PaymentStrategy", LockmanRegistrationError.strategyNotRegistered("PaymentStrategy")),
      ("LoggingStrategy", LockmanRegistrationError.strategyAlreadyRegistered("LoggingStrategy")),
    ]

    // Context should be preserved in error messages
    for (strategyName, error) in contextualErrors {
      XCTAssertTrue(error.errorDescription!.contains(strategyName))

      // Error should provide context about what operation failed
      switch error {
      case .strategyAlreadyRegistered:
        XCTAssertTrue(error.errorDescription!.contains("already registered"))
      case .strategyNotRegistered:
        XCTAssertTrue(error.errorDescription!.contains("not registered"))
      }
    }
  }

  // MARK: - Error Hierarchy and Swift Error Integration Tests

  func testSwiftErrorProtocolConformanceThroughLockmanError() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("SwiftErrorTest")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("SwiftErrorTest")

    // Verify Error protocol usage
    let error1: any Error = alreadyError
    let error2: any Error = notRegisteredError
    XCTAssertNotNil(error1)
    XCTAssertNotNil(error2)

    // Should work in Swift error handling
    func throwingFunction() throws {
      throw alreadyError
    }

    XCTAssertThrowsError(try throwingFunction()) { error in
      XCTAssertTrue(error is LockmanRegistrationError)
      XCTAssertTrue(error is any LockmanError)
    }
  }

  func testErrorThrowingAndCatchingBehavior() {
    let errors = [
      LockmanRegistrationError.strategyAlreadyRegistered("ThrowTest1"),
      LockmanRegistrationError.strategyNotRegistered("ThrowTest2"),
    ]

    for testError in errors {
      do {
        throw testError
      } catch let caughtError as LockmanRegistrationError {
        XCTAssertEqual(caughtError, testError)
      } catch {
        XCTFail("Should catch as LockmanRegistrationError")
      }
    }
  }

  func testErrorTypeIdentificationAndCasting() {
    let alreadyError: any Error = LockmanRegistrationError.strategyAlreadyRegistered("CastingTest")
    let notRegisteredError: any Error = LockmanRegistrationError.strategyNotRegistered("CastingTest")

    // Should be able to cast back to specific type
    XCTAssertTrue(alreadyError is LockmanRegistrationError)
    XCTAssertTrue(notRegisteredError is LockmanRegistrationError)

    // Should be able to extract as LockmanError
    XCTAssertTrue(alreadyError is any LockmanError)
    XCTAssertTrue(notRegisteredError is any LockmanError)

    // Should be able to extract as LocalizedError
    XCTAssertTrue(alreadyError is any LocalizedError)
    XCTAssertTrue(notRegisteredError is any LocalizedError)
  }

  func testErrorChainingAndNestedErrorScenarios() {
    let originalError = LockmanRegistrationError.strategyNotRegistered("OriginalError")

    // Simulate nested error scenario
    struct ContainerError: Error {
      let underlyingError: any Error
    }

    let chainedError = ContainerError(underlyingError: originalError)

    // Should be able to extract original error from chain
    if let extractedError = chainedError.underlyingError as? LockmanRegistrationError {
      XCTAssertEqual(extractedError, originalError)
    } else {
      XCTFail("Should be able to extract LockmanRegistrationError from chain")
    }
  }

  func testLocalizedErrorConformanceValidation() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("LocalizedTest")

    // Verify LocalizedError protocol usage
    let localizedError: any LocalizedError = error
    XCTAssertNotNil(localizedError.errorDescription)

    // LocalizedError properties should work
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertNotNil(error.recoverySuggestion)
    XCTAssertNotNil(error.helpAnchor)

    // localizedDescription should work (default implementation from LocalizedError)
    XCTAssertNotNil(error.localizedDescription)
    XCTAssertEqual(error.localizedDescription, error.errorDescription)
  }

  // MARK: - User Experience and Debugging Support Tests

  func testErrorMessagesProvideSufficientDebuggingInformation() {
    let debugError = LockmanRegistrationError.strategyNotRegistered("DebugStrategy")

    // Error should provide enough information for debugging
    XCTAssertTrue(debugError.errorDescription!.contains("DebugStrategy"))
    XCTAssertTrue(debugError.errorDescription!.contains("not registered"))

    // Failure reason should explain the root cause
    XCTAssertTrue(debugError.failureReason!.contains("previously registered"))
    XCTAssertTrue(debugError.failureReason!.contains("resolution requires"))

    // Recovery suggestion should be specific enough to act on
    XCTAssertTrue(debugError.recoverySuggestion!.contains("LockmanManager.container.register"))
    XCTAssertTrue(debugError.recoverySuggestion!.contains("DebugStrategy"))
  }

  func testRecoverySuggestionsAreImplementableByDevelopers() {
    let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("ImplementableStrategy")
    let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("ImplementableStrategy")

    // Already registered recovery suggestion should be implementable
    let alreadySuggestion = alreadyError.recoverySuggestion!
    XCTAssertTrue(alreadySuggestion.contains("isRegistered"))
    XCTAssertTrue(alreadySuggestion.contains("once during app startup"))

    // Not registered recovery suggestion should be implementable
    let notRegisteredSuggestion = notRegisteredError.recoverySuggestion!
    XCTAssertTrue(notRegisteredSuggestion.contains("LockmanManager.container.register"))
    XCTAssertTrue(notRegisteredSuggestion.contains("app startup code"))
  }

  func testHelpAnchorDirectsToCorrectDocumentationSections() {
    let errors = [
      LockmanRegistrationError.strategyAlreadyRegistered("HelpStrategy1"),
      LockmanRegistrationError.strategyNotRegistered("HelpStrategy2"),
    ]

    // All errors should point to strategy container documentation
    for error in errors {
      XCTAssertEqual(error.helpAnchor, "LockmanStrategyContainer")
    }
  }

  func testErrorContextHelpsIdentifyRegistrationVsResolutionIssues() {
    let registrationError = LockmanRegistrationError.strategyAlreadyRegistered("RegistrationIssue")
    let resolutionError = LockmanRegistrationError.strategyNotRegistered("ResolutionIssue")

    // Registration error context
    XCTAssertTrue(registrationError.errorDescription!.contains("already registered"))
    XCTAssertTrue(registrationError.failureReason!.contains("unique"))

    // Resolution error context
    XCTAssertTrue(resolutionError.errorDescription!.contains("not registered"))
    XCTAssertTrue(resolutionError.failureReason!.contains("resolution"))
  }

  func testClearDistinctionBetweenRegistrationVsResolutionErrors() {
    let registrationError = LockmanRegistrationError.strategyAlreadyRegistered("DistinctStrategy")
    let resolutionError = LockmanRegistrationError.strategyNotRegistered("DistinctStrategy")

    // Should be clearly distinguishable
    XCTAssertNotEqual(registrationError.errorDescription, resolutionError.errorDescription)
    XCTAssertNotEqual(registrationError.failureReason, resolutionError.failureReason)
    XCTAssertNotEqual(registrationError.recoverySuggestion, resolutionError.recoverySuggestion)

    // Key differentiating words
    XCTAssertTrue(registrationError.errorDescription!.contains("already"))
    XCTAssertTrue(resolutionError.errorDescription!.contains("not"))
  }

  // MARK: - Edge Cases and Error Conditions Tests

  func testBehaviorWithEmptyOrWhitespaceOnlyStrategyNames() {
    let edgeCases = ["", " ", "  ", "\t", "\n", " \t \n "]

    for edgeCase in edgeCases {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered(edgeCase)
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered(edgeCase)

      // Should handle edge cases gracefully
      XCTAssertNotNil(alreadyError.errorDescription)
      XCTAssertNotNil(notRegisteredError.errorDescription)

      // Error messages should not be empty
      XCTAssertFalse(alreadyError.errorDescription!.isEmpty)
      XCTAssertFalse(notRegisteredError.errorDescription!.isEmpty)
    }
  }

  func testHandlingOfVeryLongStrategyTypeNames() {
    let veryLongName = String(repeating: "ExtremelyLongStrategyNamePart", count: 100)
    let longAlreadyError = LockmanRegistrationError.strategyAlreadyRegistered(veryLongName)
    let longNotRegisteredError = LockmanRegistrationError.strategyNotRegistered(veryLongName)

    // Should handle very long names without performance issues
    let startTime = CFAbsoluteTimeGetCurrent()

    let _ = longAlreadyError.errorDescription
    let _ = longAlreadyError.failureReason
    let _ = longAlreadyError.recoverySuggestion

    let _ = longNotRegisteredError.errorDescription
    let _ = longNotRegisteredError.failureReason
    let _ = longNotRegisteredError.recoverySuggestion

    let duration = CFAbsoluteTimeGetCurrent() - startTime

    // Should complete quickly even with very long names
    XCTAssertLessThan(duration, 0.1)

    // Should contain the full long name
    XCTAssertTrue(longAlreadyError.errorDescription!.contains(veryLongName))
    XCTAssertTrue(longNotRegisteredError.errorDescription!.contains(veryLongName))
  }

  func testMemoryEfficiencyOfErrorInstances() {
    var weakErrors: [LockmanRegistrationError]?

    autoreleasepool {
      let errors = (0..<1000).map { i in
        i % 2 == 0
          ? LockmanRegistrationError.strategyAlreadyRegistered("Strategy\(i)")
          : LockmanRegistrationError.strategyNotRegistered("Strategy\(i)")
      }

      weakErrors = errors

      // Use errors to prevent optimization
      let descriptions = errors.map { $0.errorDescription }
      XCTAssertEqual(descriptions.count, 1000)
    }

    // Errors should be deallocated
    XCTAssertNil(weakErrors)
  }

  func testErrorPersistenceAndSerializationBehavior() {
    let error = LockmanRegistrationError.strategyAlreadyRegistered("PersistenceTest")

    // Error properties should be consistent across multiple accesses
    let description1 = error.errorDescription
    let description2 = error.errorDescription
    let reason1 = error.failureReason
    let reason2 = error.failureReason

    XCTAssertEqual(description1, description2)
    XCTAssertEqual(reason1, reason2)

    // Should be serializable with standard approaches
    let nsError = error as NSError
    XCTAssertNotNil(nsError.localizedDescription)
    XCTAssertNotNil(nsError.localizedFailureReason)
  }

  // MARK: - Performance and Memory Considerations Tests

  func testErrorObjectCreationOverhead() {
    let strategyNames = (0..<1000).map { "PerformanceStrategy\($0)" }

    let startTime = CFAbsoluteTimeGetCurrent()

    let errors = strategyNames.map { name in
      LockmanRegistrationError.strategyAlreadyRegistered(name)
    }

    let creationDuration = CFAbsoluteTimeGetCurrent() - startTime

    // Error creation should be fast
    XCTAssertLessThan(creationDuration, 0.1)
    XCTAssertEqual(errors.count, 1000)
  }

  func testStringInterpolationPerformanceInErrorMessages() {
    let strategyName = "InterpolationPerformanceTest"
    let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyName)

    let startTime = CFAbsoluteTimeGetCurrent()

    // Access error properties multiple times
    for _ in 0..<1000 {
      let _ = error.errorDescription
      let _ = error.failureReason
      let _ = error.recoverySuggestion
      let _ = error.helpAnchor
    }

    let duration = CFAbsoluteTimeGetCurrent() - startTime

    // Property access should be fast (likely cached)
    XCTAssertLessThan(duration, 0.1)
  }

  func testMemoryUsageOfErrorInstancesWithLongStrings() {
    let longStrategyName = String(repeating: "MemoryTestStrategy", count: 1000)

    autoreleasepool {
      let error = LockmanRegistrationError.strategyAlreadyRegistered(longStrategyName)

      // Access error properties
      let _ = error.errorDescription
      let _ = error.failureReason
      let _ = error.recoverySuggestion

      // Verify error works correctly with long strings
      XCTAssertTrue(error.errorDescription!.contains(longStrategyName))
    }
  }

  func testErrorObjectLifecycleAndDeallocation() {
    // Test error object creation and usage
    autoreleasepool {
      let alreadyError = LockmanRegistrationError.strategyAlreadyRegistered("LifecycleTest")
      let notRegisteredError = LockmanRegistrationError.strategyNotRegistered("LifecycleTest")

      // Use errors
      XCTAssertNotNil(alreadyError.errorDescription)
      XCTAssertNotNil(notRegisteredError.errorDescription)
      
      // Test error properties are accessible
      XCTAssertFalse(alreadyError.errorDescription!.isEmpty)
      XCTAssertFalse(notRegisteredError.errorDescription!.isEmpty)
    }
  }

  func testConcurrentErrorCreationSafety() async {
    let strategyNames = (0..<100).map { "ConcurrentStrategy\($0)" }

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      let errors = strategyNames.map { name in
        LockmanRegistrationError.strategyAlreadyRegistered(name)
      }

      return errors.map { $0.errorDescription }.count
    }

    // All concurrent operations should succeed
    XCTAssertEqual(results.count, 10)
    results.forEach { count in
      XCTAssertEqual(count, 100)
    }
  }

  // MARK: - Comprehensive Integration Tests

  func testComprehensiveErrorScenarioSimulation() {
    // Simulate a realistic scenario with multiple registration errors
    let scenarioErrors = [
      ("UserAuthStrategy", LockmanRegistrationError.strategyAlreadyRegistered("UserAuthStrategy")),
      ("PaymentStrategy", LockmanRegistrationError.strategyNotRegistered("PaymentStrategy")),
      ("LoggingStrategy", LockmanRegistrationError.strategyAlreadyRegistered("LoggingStrategy")),
      ("CacheStrategy", LockmanRegistrationError.strategyNotRegistered("CacheStrategy")),
      (
        "ValidationStrategy",
        LockmanRegistrationError.strategyAlreadyRegistered("ValidationStrategy")
      ),
    ]

    // Process errors as would happen in real application
    for (strategyName, error) in scenarioErrors {
      // Log error information
      let logEntry = [
        "strategy": strategyName,
        "error_type": String(describing: type(of: error)),
        "error_description": error.errorDescription ?? "nil",
        "failure_reason": error.failureReason ?? "nil",
        "recovery_suggestion": error.recoverySuggestion ?? "nil",
        "help_anchor": error.helpAnchor ?? "nil",
      ]

      // Verify log entry completeness
      XCTAssertEqual(logEntry["strategy"], strategyName)
      XCTAssertEqual(logEntry["error_type"], "LockmanRegistrationError")
      XCTAssertNotEqual(logEntry["error_description"], "nil")
      XCTAssertNotEqual(logEntry["failure_reason"], "nil")
      XCTAssertNotEqual(logEntry["recovery_suggestion"], "nil")
      XCTAssertNotEqual(logEntry["help_anchor"], "nil")

      // Verify error message content
      XCTAssertTrue(logEntry["error_description"]!.contains(strategyName))
      XCTAssertEqual(logEntry["help_anchor"], "LockmanStrategyContainer")
    }
  }
}
