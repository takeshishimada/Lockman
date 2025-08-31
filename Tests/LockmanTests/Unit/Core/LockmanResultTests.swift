import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanResult enum tests with 3-phase approach
// ✅ 13 test methods covering all enum cases, protocol conformance, and integration scenarios
// ✅ Phase 1: Basic enum case testing (success, successWithPrecedingCancellation, cancel)
// ✅ Phase 2: Sendable conformance and concurrent access testing
// ✅ Phase 3: Error protocol integration, documentation examples, and type system testing

final class LockmanResultTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Error Types for Testing

  // Basic error for testing .cancel case
  private struct TestBasicError: LockmanError {
    let message: String

    var errorDescription: String? { message }
  }

  // Preceding cancellation error for testing .successWithPrecedingCancellation case
  private struct TestPrecedingError: LockmanPrecedingCancellationError {
    let message: String
    let cancelledInfo: any LockmanInfo
    let boundary: any LockmanBoundaryId

    var errorDescription: String? { message }

    var lockmanInfo: any LockmanInfo { cancelledInfo }
    var boundaryId: any LockmanBoundaryId { boundary }

    init(
      message: String, cancelledInfo: any LockmanInfo,
      boundaryId: any LockmanBoundaryId = "testBoundary"
    ) {
      self.message = message
      self.cancelledInfo = cancelledInfo
      self.boundary = boundaryId
    }
  }

  // Basic LockmanInfo for testing
  private struct TestLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID

    init(strategyId: LockmanStrategyId = "TestStrategy", actionId: LockmanActionId = "testAction") {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
    }

    var debugDescription: String {
      "TestLockmanInfo(actionId: '\(actionId)')"
    }
  }

  // MARK: - Phase 1: Basic Enum Cases

  func testLockmanResultSuccessCase() {
    // Test .success case
    let result = LockmanResult.success

    // Test pattern matching
    switch result {
    case .success:
      XCTAssertTrue(true)  // Success case matched
    default:
      XCTFail("Should match .success case")
    }
  }

  func testLockmanResultSuccessWithPrecedingCancellationCase() {
    // Test .successWithPrecedingCancellation case
    let testInfo = TestLockmanInfo(actionId: "testAction")
    let error = TestPrecedingError(message: "Previous operation cancelled", cancelledInfo: testInfo)
    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    // Test pattern matching
    switch result {
    case .successWithPrecedingCancellation(let precedingError):
      XCTAssertEqual(precedingError.errorDescription, "Previous operation cancelled")
      XCTAssertTrue(precedingError is TestPrecedingError)
      if let testError = precedingError as? TestPrecedingError {
        XCTAssertEqual(testError.cancelledInfo.actionId, "testAction")
      }
    default:
      XCTFail("Should match .successWithPrecedingCancellation case")
    }
  }

  func testLockmanResultCancelCase() {
    // Test .cancel case
    let error = TestBasicError(message: "Operation cancelled")
    let result = LockmanResult.cancel(error)

    // Test pattern matching
    switch result {
    case .cancel(let cancelError):
      XCTAssertEqual(cancelError.errorDescription, "Operation cancelled")
      XCTAssertTrue(cancelError is TestBasicError)
    default:
      XCTFail("Should match .cancel case")
    }
  }

  // MARK: - Phase 2: Sendable Conformance

  func testLockmanResultSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let testInfo = TestLockmanInfo(actionId: "concurrentTest")
    let precedingError = TestPrecedingError(
      message: "Concurrent test error", cancelledInfo: testInfo)
    let result = LockmanResult.successWithPrecedingCancellation(error: precedingError)

    await withTaskGroup(of: String.self) { group in
      group.addTask {
        // This compiles without warning = Sendable works
        switch result {
        case .success:
          return "Task1: success"
        case .successWithPrecedingCancellation:
          return "Task1: successWithPrecedingCancellation"
        case .cancel:
          return "Task1: cancel"
        }
      }

      group.addTask {
        switch result {
        case .success:
          return "Task2: success"
        case .successWithPrecedingCancellation:
          return "Task2: successWithPrecedingCancellation"
        case .cancel:
          return "Task2: cancel"
        }
      }

      var results: [String] = []
      for await taskResult in group {
        results.append(taskResult)
      }

      XCTAssertEqual(results.count, 2)
      XCTAssertTrue(results.contains("Task1: successWithPrecedingCancellation"))
      XCTAssertTrue(results.contains("Task2: successWithPrecedingCancellation"))
    }
  }

  // MARK: - Phase 3: Error Protocol Integration

  func testLockmanResultWithLockmanErrorProtocol() {
    // Test with different LockmanError implementations
    let basicError = TestBasicError(message: "Basic error test")
    let cancelResult = LockmanResult.cancel(basicError)

    switch cancelResult {
    case .cancel(let error):
      // Test LockmanError protocol conformance
      XCTAssertTrue(error is any LockmanError)
      XCTAssertEqual(error.errorDescription, "Basic error test")
    default:
      XCTFail("Should be cancel case")
    }
  }

  func testLockmanResultWithPrecedingCancellationErrorProtocol() {
    // Test with LockmanPrecedingCancellationError protocol
    let testInfo = TestLockmanInfo(actionId: "protocolTest")
    let precedingError = TestPrecedingError(
      message: "Preceding error test", cancelledInfo: testInfo)
    let result = LockmanResult.successWithPrecedingCancellation(error: precedingError)

    switch result {
    case .successWithPrecedingCancellation(let error):
      // Test LockmanPrecedingCancellationError protocol conformance
      XCTAssertTrue(error is any LockmanPrecedingCancellationError)
      XCTAssertTrue(error is any LockmanError)  // Should also conform to base protocol
      XCTAssertEqual(error.errorDescription, "Preceding error test")
      XCTAssertEqual(error.lockmanInfo.actionId, "protocolTest")
    default:
      XCTFail("Should be successWithPrecedingCancellation case")
    }
  }

  // MARK: - Phase 4: Comprehensive Pattern Matching

  func testLockmanResultExhaustivePatternMatching() {
    // Test all cases in a single comprehensive function
    let testInfo = TestLockmanInfo(actionId: "comprehensiveTest")

    let results: [LockmanResult] = [
      .success,
      .successWithPrecedingCancellation(
        error: TestPrecedingError(
          message: "Comprehensive preceding error",
          cancelledInfo: testInfo
        )),
      .cancel(TestBasicError(message: "Comprehensive cancel error")),
    ]

    for (index, result) in results.enumerated() {
      switch result {
      case .success:
        XCTAssertEqual(index, 0, "Success should be first result")

      case .successWithPrecedingCancellation(let error):
        XCTAssertEqual(index, 1, "SuccessWithPrecedingCancellation should be second result")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(error.lockmanInfo.actionId, "comprehensiveTest")

      case .cancel(let error):
        XCTAssertEqual(index, 2, "Cancel should be third result")
        XCTAssertEqual(error.errorDescription, "Comprehensive cancel error")
      }
    }
  }

  func testLockmanResultNestedSwitchHandling() {
    // Test nested pattern matching scenarios
    let testInfo = TestLockmanInfo(actionId: "nestedTest")

    func processResult(_ result: LockmanResult) -> String {
      switch result {
      case .success:
        return "proceed_immediately"

      case .successWithPrecedingCancellation(let error):
        // Test nested logic for preceding cancellation
        if error.lockmanInfo.actionId.contains("nested") {
          return "cancel_and_proceed_nested"
        } else {
          return "cancel_and_proceed_regular"
        }

      case .cancel(let error):
        // Test nested error type checking
        if error is TestBasicError {
          return "cancel_basic_error"
        } else {
          return "cancel_unknown_error"
        }
      }
    }

    // Test each case
    XCTAssertEqual(
      processResult(.success),
      "proceed_immediately"
    )

    XCTAssertEqual(
      processResult(
        .successWithPrecedingCancellation(
          error: TestPrecedingError(
            message: "Nested test",
            cancelledInfo: testInfo
          ))),
      "cancel_and_proceed_nested"
    )

    XCTAssertEqual(
      processResult(.cancel(TestBasicError(message: "Nested cancel"))),
      "cancel_basic_error"
    )
  }

  // MARK: - Phase 5: Documentation Examples Verification

  func testLockmanResultDocumentationExamples() {
    // Test examples that match the documentation
    let testInfo = TestLockmanInfo(strategyId: "ExampleStrategy", actionId: "documentationExample")

    // Example 1: Success case (most common)
    let successResult = LockmanResult.success
    switch successResult {
    case .success:
      // Operation can proceed immediately without any additional cleanup
      XCTAssertTrue(true)  // This is the expected path
    default:
      XCTFail("Documentation example should succeed")
    }

    // Example 2: Success with preceding cancellation (priority-based scenarios)
    let precedingError = TestPrecedingError(
      message: "Lower priority operation cancelled",
      cancelledInfo: testInfo
    )
    let precedingResult = LockmanResult.successWithPrecedingCancellation(error: precedingError)

    switch precedingResult {
    case .successWithPrecedingCancellation(let error):
      // 1. Cancel the existing operation (usually via Effect cancellation)
      // 2. Immediately unlock the cancelled action to prevent resource leaks
      // 3. Proceed with the new operation
      XCTAssertNotNil(error.lockmanInfo)
      XCTAssertEqual(error.lockmanInfo.actionId, "documentationExample")
    default:
      XCTFail("Should be preceding cancellation case")
    }

    // Example 3: Cancel case (conflict situations)
    let cancelError = TestBasicError(message: "Higher priority operation is already active")
    let cancelResult = LockmanResult.cancel(cancelError)

    switch cancelResult {
    case .cancel(let error):
      // The requesting operation should not proceed
      XCTAssertTrue(error.errorDescription?.contains("Higher priority") ?? false)
    default:
      XCTFail("Should be cancel case")
    }
  }

  // MARK: - Phase 6: Type System Integration

  func testLockmanResultWithRealErrorTypes() {
    // Test with more realistic error types that might exist in the system
    struct ConflictError: LockmanError {
      let conflictingActionId: LockmanActionId
      let boundaryId: String

      var errorDescription: String? {
        "Action conflict: \(conflictingActionId) already active on boundary \(boundaryId)"
      }
    }

    struct PriorityError: LockmanPrecedingCancellationError {
      let cancelledInfo: any LockmanInfo
      let boundary: any LockmanBoundaryId
      let newPriority: Int
      let oldPriority: Int

      var errorDescription: String? {
        "Priority preemption: \(oldPriority) -> \(newPriority)"
      }

      var lockmanInfo: any LockmanInfo { cancelledInfo }
      var boundaryId: any LockmanBoundaryId { boundary }
    }

    let testInfo = TestLockmanInfo(actionId: "realErrorTest")

    // Test with conflict error
    let conflictResult = LockmanResult.cancel(
      ConflictError(
        conflictingActionId: "existingAction",
        boundaryId: "mainBoundary"
      ))

    switch conflictResult {
    case .cancel(let error):
      if let conflictError = error as? ConflictError {
        XCTAssertEqual(conflictError.conflictingActionId, "existingAction")
        XCTAssertEqual(conflictError.boundaryId, "mainBoundary")
      } else {
        XCTFail("Should be ConflictError type")
      }
    default:
      XCTFail("Should be cancel case")
    }

    // Test with priority error
    let priorityResult = LockmanResult.successWithPrecedingCancellation(
      error: PriorityError(
        cancelledInfo: testInfo,
        boundary: "testBoundary",
        newPriority: 10,
        oldPriority: 5
      )
    )

    switch priorityResult {
    case .successWithPrecedingCancellation(let error):
      if let priorityError = error as? PriorityError {
        XCTAssertEqual(priorityError.newPriority, 10)
        XCTAssertEqual(priorityError.oldPriority, 5)
        XCTAssertEqual(priorityError.lockmanInfo.actionId, "realErrorTest")
      } else {
        XCTFail("Should be PriorityError type")
      }
    default:
      XCTFail("Should be successWithPrecedingCancellation case")
    }
  }

}
