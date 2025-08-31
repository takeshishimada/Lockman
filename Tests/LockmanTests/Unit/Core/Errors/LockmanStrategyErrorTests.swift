import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanStrategyError protocol tests with 3-phase approach
// ✅ 12 test methods covering protocol conformance, inheritance, and concrete implementations
// ✅ Phase 1: Basic protocol requirements and concrete implementation testing
// ✅ Phase 2: Protocol composition and inheritance verification
// ✅ Phase 3: Integration testing with various boundary and info types

final class LockmanStrategyErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Basic Protocol Requirements

  func testLockmanStrategyErrorBasicConcreteImplementation() {
    // Test basic concrete implementation of LockmanStrategyError
    let testInfo = TestLockmanInfo(actionId: "testAction", strategyId: "testStrategy")
    let testBoundary = "testBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Test strategy error",
      failureReason: "Test failure reason"
    )

    // Verify protocol requirements are satisfied
    XCTAssertTrue(testError.lockmanInfo.actionId == "testAction")
    XCTAssertEqual(testError.lockmanInfo.strategyId, "testStrategy")
    XCTAssertEqual(testError.boundaryId as? String, testBoundary)
    XCTAssertEqual(testError.errorDescription, "Test strategy error")
    XCTAssertEqual(testError.failureReason, "Test failure reason")
  }

  func testLockmanStrategyErrorWithDifferentBoundaryTypes() {
    // Test with different boundary ID types
    let testInfo = TestLockmanInfo(actionId: "boundaryTest", strategyId: "testStrategy")

    // String boundary
    let stringError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: "stringBoundary",
      message: "String boundary error"
    )
    XCTAssertEqual(stringError.boundaryId as? String, "stringBoundary")

    // Int boundary
    let intError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: 123,
      message: "Int boundary error"
    )
    XCTAssertEqual(intError.boundaryId as? Int, 123)

    // UUID boundary
    let uuid = UUID()
    let uuidError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: uuid,
      message: "UUID boundary error"
    )
    XCTAssertEqual(uuidError.boundaryId as? UUID, uuid)
  }

  func testLockmanStrategyErrorWithDifferentInfoTypes() {
    // Test with different LockmanInfo implementations
    let testBoundary = "infoBoundary"

    // Basic TestLockmanInfo
    let basicInfo = TestLockmanInfo(actionId: "basicAction", strategyId: "basicStrategy")
    let basicError = TestStrategyError(
      lockmanInfo: basicInfo,
      boundaryId: testBoundary,
      message: "Basic info error"
    )
    XCTAssertEqual(basicError.lockmanInfo.actionId, "basicAction")
    XCTAssertEqual(basicError.lockmanInfo.strategyId, "basicStrategy")

    // Complex TestLockmanInfo
    let complexInfo = TestLockmanInfo(
      actionId: "complexAction",
      strategyId: "complexStrategy",
      uniqueId: UUID(),
      isCancellationTarget: true
    )
    let complexError = TestStrategyError(
      lockmanInfo: complexInfo,
      boundaryId: testBoundary,
      message: "Complex info error"
    )
    XCTAssertEqual(complexError.lockmanInfo.actionId, "complexAction")
    XCTAssertEqual(complexError.lockmanInfo.strategyId, "complexStrategy")
    XCTAssertTrue(complexError.lockmanInfo.isCancellationTarget)
  }

  func testLockmanStrategyErrorPropertiesAccess() {
    // Test access to all protocol required properties
    let testInfo = TestLockmanInfo(actionId: "accessTest", strategyId: "accessStrategy")
    let testBoundary = "accessBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Property access test",
      failureReason: "Property failure"
    )

    // Test lockmanInfo property access
    let retrievedInfo = testError.lockmanInfo
    XCTAssertEqual(retrievedInfo.actionId, "accessTest")
    XCTAssertEqual(retrievedInfo.strategyId, "accessStrategy")

    // Test boundaryId property access
    let retrievedBoundary = testError.boundaryId
    XCTAssertEqual(retrievedBoundary as? String, "accessBoundary")

    // Test LocalizedError properties (inherited through LockmanError)
    XCTAssertEqual(testError.errorDescription, "Property access test")
    XCTAssertEqual(testError.failureReason, "Property failure")
  }

  // MARK: - Phase 2: Protocol Composition and Inheritance

  func testLockmanStrategyErrorLockmanErrorConformance() {
    // Test that LockmanStrategyError inherits from LockmanError
    let testInfo = TestLockmanInfo(actionId: "inheritanceTest", strategyId: "testStrategy")
    let testBoundary = "inheritanceBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Inheritance test error"
    )

    // Verify LockmanError conformance
    XCTAssertTrue(testError is LockmanError)

    // Test as LockmanError
    let lockmanError: any LockmanError = testError
    XCTAssertTrue(lockmanError is TestStrategyError)

    // Verify Error conformance (through LockmanError)
    XCTAssertTrue(testError is Error)
    let error: any Error = testError
    XCTAssertTrue(error is TestStrategyError)
  }

  func testLockmanStrategyErrorLocalizedErrorConformance() {
    // Test LocalizedError conformance (inherited through LockmanError)
    let testInfo = TestLockmanInfo(actionId: "localizedTest", strategyId: "testStrategy")
    let testBoundary = "localizedBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Localized test error",
      failureReason: "Localized failure reason"
    )

    // Verify LocalizedError conformance
    XCTAssertTrue(testError is LocalizedError)

    // Test as LocalizedError
    let localizedError: any LocalizedError = testError
    XCTAssertNotNil(localizedError.errorDescription)
    XCTAssertNotNil(localizedError.failureReason)
    XCTAssertEqual(localizedError.errorDescription, "Localized test error")
    XCTAssertEqual(localizedError.failureReason, "Localized failure reason")
  }

  func testLockmanStrategyErrorProtocolComposition() {
    // Test protocol composition and type constraints
    let testInfo = TestLockmanInfo(actionId: "compositionTest", strategyId: "testStrategy")
    let testBoundary = "compositionBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Composition test error"
    )

    // Test in function that requires LockmanStrategyError
    func processStrategyError(_ error: any LockmanStrategyError) -> String {
      return "Action: \(error.lockmanInfo.actionId), Boundary: \(error.boundaryId)"
    }

    let result = processStrategyError(testError)
    XCTAssertTrue(result.contains("compositionTest"))
    XCTAssertTrue(result.contains("compositionBoundary"))

    // Test in function that requires LockmanError
    func processLockmanError(_ error: any LockmanError) -> Bool {
      return error is LockmanStrategyError
    }

    XCTAssertTrue(processLockmanError(testError))
  }

  func testLockmanStrategyErrorGenericConstraints() {
    // Test with generic constraints
    let testInfo = TestLockmanInfo(actionId: "genericTest", strategyId: "testStrategy")
    let testBoundary = "genericBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Generic constraint test"
    )

    // Test generic function with Error constraint
    func handleError<E: Error>(_ error: E) -> String {
      return String(describing: type(of: error))
    }

    let errorTypeResult = handleError(testError)
    XCTAssertTrue(errorTypeResult.contains("TestStrategyError"))

    // Test generic function with LockmanError constraint
    func handleLockmanError<E: LockmanError>(_ error: E) -> Bool {
      return error is LockmanStrategyError
    }

    XCTAssertTrue(handleLockmanError(testError))

    // Test generic function with LockmanStrategyError constraint
    func handleStrategyError<E: LockmanStrategyError>(_ error: E) -> String {
      return error.lockmanInfo.actionId
    }

    let actionId = handleStrategyError(testError)
    XCTAssertEqual(actionId, "genericTest")
  }

  // MARK: - Phase 3: Sendable and Concurrency

  func testLockmanStrategyErrorSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let testInfo = TestLockmanInfo(actionId: "sendableTest", strategyId: "testStrategy")
    let testBoundary = "sendableBoundary"
    let testError = TestStrategyError(
      lockmanInfo: testInfo,
      boundaryId: testBoundary,
      message: "Sendable test error"
    )

    await withTaskGroup(of: String.self) { group in
      for i in 0..<5 {
        group.addTask {
          // This compiles without warning = Sendable works
          let actionId = testError.lockmanInfo.actionId
          let boundaryDesc = String(describing: testError.boundaryId)
          let errorDesc = testError.errorDescription ?? "No description"
          return "Task\(i): \(actionId)-\(boundaryDesc)-\(errorDesc)"
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 5)
      // All results should contain consistent information
      for result in results {
        XCTAssertTrue(result.contains("sendableTest"))
        XCTAssertTrue(result.contains("sendableBoundary"))
        XCTAssertTrue(result.contains("Sendable test error"))
      }
    }
  }

  // MARK: - Phase 4: Edge Cases and Integration

  func testLockmanStrategyErrorWithComplexScenarios() {
    // Test with complex, real-world scenarios
    let complexInfo = TestLockmanInfo(
      actionId: "complex.action.with.dots",
      strategyId: "ComplexStrategy-With_Special#Characters",
      uniqueId: UUID(),
      isCancellationTarget: true
    )

    let complexBoundary = "boundary/with/slashes"
    let complexError = TestStrategyError(
      lockmanInfo: complexInfo,
      boundaryId: complexBoundary,
      message:
        "Complex scenario: Action '\(complexInfo.actionId)' failed in boundary '\(complexBoundary)'",
      failureReason: "Strategy '\(complexInfo.strategyId)' encountered a conflict"
    )

    // Verify complex values are preserved
    XCTAssertEqual(complexError.lockmanInfo.actionId, "complex.action.with.dots")
    XCTAssertEqual(complexError.lockmanInfo.strategyId, "ComplexStrategy-With_Special#Characters")
    XCTAssertEqual(complexError.boundaryId as? String, "boundary/with/slashes")
    XCTAssertTrue(complexError.lockmanInfo.isCancellationTarget)

    // Verify error message composition
    XCTAssertTrue(complexError.errorDescription?.contains("complex.action.with.dots") == true)
    XCTAssertTrue(complexError.errorDescription?.contains("boundary/with/slashes") == true)
    XCTAssertTrue(
      complexError.failureReason?.contains("ComplexStrategy-With_Special#Characters") == true)
  }

  func testLockmanStrategyErrorCollectionBehavior() {
    // Test behavior in collections and pattern matching
    let testInfo1 = TestLockmanInfo(actionId: "action1", strategyId: "strategy1")
    let testInfo2 = TestLockmanInfo(actionId: "action2", strategyId: "strategy2")

    let errors: [any LockmanStrategyError] = [
      TestStrategyError(lockmanInfo: testInfo1, boundaryId: "boundary1", message: "Error 1"),
      TestStrategyError(lockmanInfo: testInfo2, boundaryId: "boundary2", message: "Error 2"),
      TestStrategyError(lockmanInfo: testInfo1, boundaryId: "boundary3", message: "Error 3"),
    ]

    XCTAssertEqual(errors.count, 3)

    // Test filtering and mapping
    let action1Errors = errors.filter { $0.lockmanInfo.actionId == "action1" }
    XCTAssertEqual(action1Errors.count, 2)

    let strategyNames = errors.map { $0.lockmanInfo.strategyId }
    XCTAssertTrue(strategyNames.contains("strategy1"))
    XCTAssertTrue(strategyNames.contains("strategy2"))

    // Test error message extraction
    let errorMessages = errors.compactMap { $0.errorDescription }
    XCTAssertEqual(errorMessages.count, 3)
    XCTAssertTrue(errorMessages.contains("Error 1"))
    XCTAssertTrue(errorMessages.contains("Error 2"))
    XCTAssertTrue(errorMessages.contains("Error 3"))
  }

  // MARK: - Helper Test Implementation

  private struct TestStrategyError: LockmanStrategyError {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let message: String
    let failureDescription: String?

    init(
      lockmanInfo: any LockmanInfo,
      boundaryId: any LockmanBoundaryId,
      message: String,
      failureReason: String? = nil
    ) {
      self.lockmanInfo = lockmanInfo
      self.boundaryId = boundaryId
      self.message = message
      self.failureDescription = failureReason
    }

    var errorDescription: String? { message }
    var failureReason: String? { failureDescription }
  }

}
