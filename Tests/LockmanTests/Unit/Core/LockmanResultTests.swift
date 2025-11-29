import XCTest

@testable import Lockman

// ✅ UPDATED: Comprehensive LockmanResult enum tests updated for new API with unlockToken
// ✅ 13 test methods covering all enum cases with unlockToken parameter
// ✅ Phase 1: Basic enum case testing (success, successWithPrecedingCancellation, cancel) with unlockToken
// ✅ Phase 2: Sendable conformance and concurrent access testing
// ✅ Phase 3: Error protocol integration, documentation examples, and type system testing
// ✅ Phase 4: unlockToken functionality and type safety testing

final class LockmanResultTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Error Types and Mock Objects for Testing

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
      boundaryId: any LockmanBoundaryId = TestBoundaryId.test
    ) {
      self.message = message
      self.cancelledInfo = cancelledInfo
      self.boundary = boundaryId
    }
  }

  // Test boundary ID type alias for easier usage
  private typealias TestBoundary = TestBoundaryId

  // Helper method to create unlock token for testing
  private func createTestUnlockToken(
    boundaryId: TestBoundary = TestBoundary.test,
    info: TestLockmanInfo = TestLockmanInfo(
      actionId: "testAction",
      strategyId: "TestSingleExecutionStrategy"
    )
  ) -> LockmanUnlock<TestBoundary, TestLockmanInfo> {
    let strategy = TestSingleExecutionStrategy()
    let anyStrategy = AnyLockmanStrategy(strategy)
    return LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: anyStrategy,
      unlockOption: .immediate
    )
  }

  // MARK: - Phase 1: Basic Enum Cases

  func testLockmanResultSuccessCase() {
    // Test .success case with unlockToken
    let unlockToken = createTestUnlockToken()
    let result = LockmanResult<TestBoundary, TestLockmanInfo>.success(unlockToken: unlockToken)

    // Test pattern matching
    switch result {
    case .success(let token):
      XCTAssertNotNil(token)
    // Verify unlock token exists (info properties are internal)
    default:
      XCTFail("Should match .success case")
    }
  }

  func testLockmanResultSuccessWithPrecedingCancellationCase() {
    // Test .successWithPrecedingCancellation case with unlockToken
    let testInfo = TestLockmanInfo(
      actionId: "testAction", strategyId: "TestSingleExecutionStrategy")
    let error = TestPrecedingError(message: "Previous operation cancelled", cancelledInfo: testInfo)
    let unlockToken = createTestUnlockToken(info: testInfo)
    let result = LockmanResult<TestBoundary, TestLockmanInfo>.successWithPrecedingCancellation(
      unlockToken: unlockToken,
      error: error
    )

    // Test pattern matching
    switch result {
    case .successWithPrecedingCancellation(let token, let precedingError):
      // Test unlock token
      XCTAssertNotNil(token)

      // Test error
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
    // Test .cancel case (no unlock token since lock failed)
    let error = TestBasicError(message: "Operation cancelled")
    let result = LockmanResult<TestBoundary, TestLockmanInfo>.cancel(error)

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
    let testInfo = TestLockmanInfo(
      actionId: "concurrentTest", strategyId: "TestSingleExecutionStrategy")
    let precedingError = TestPrecedingError(
      message: "Concurrent test error", cancelledInfo: testInfo)
    let unlockToken = createTestUnlockToken(info: testInfo)
    let result = LockmanResult<TestBoundary, TestLockmanInfo>.successWithPrecedingCancellation(
      unlockToken: unlockToken,
      error: precedingError
    )

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
    let cancelResult = LockmanResult<TestBoundary, TestLockmanInfo>.cancel(basicError)

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
    let testInfo = TestLockmanInfo(
      actionId: "protocolTest", strategyId: "TestSingleExecutionStrategy")
    let precedingError = TestPrecedingError(
      message: "Preceding error test", cancelledInfo: testInfo)
    let unlockToken = createTestUnlockToken(info: testInfo)
    let result = LockmanResult<TestBoundary, TestLockmanInfo>.successWithPrecedingCancellation(
      unlockToken: unlockToken,
      error: precedingError
    )

    switch result {
    case .successWithPrecedingCancellation(let token, let error):
      // Test unlock token
      XCTAssertNotNil(token)

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
    let testInfo = TestLockmanInfo(
      actionId: "comprehensiveTest", strategyId: "TestSingleExecutionStrategy")
    let unlockToken = createTestUnlockToken(info: testInfo)

    let results: [LockmanResult<TestBoundary, TestLockmanInfo>] = [
      .success(unlockToken: createTestUnlockToken()),
      .successWithPrecedingCancellation(
        unlockToken: unlockToken,
        error: TestPrecedingError(
          message: "Comprehensive preceding error",
          cancelledInfo: testInfo
        )),
      .cancel(TestBasicError(message: "Comprehensive cancel error")),
    ]

    for (index, result) in results.enumerated() {
      switch result {
      case .success(let token):
        XCTAssertEqual(index, 0, "Success should be first result")
        XCTAssertNotNil(token)

      case .successWithPrecedingCancellation(let token, let error):
        XCTAssertEqual(index, 1, "SuccessWithPrecedingCancellation should be second result")
        XCTAssertNotNil(token)
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
    let testInfo = TestLockmanInfo(
      actionId: "nestedTest", strategyId: "TestSingleExecutionStrategy")

    func processResult(_ result: LockmanResult<TestBoundary, TestLockmanInfo>) -> String {
      switch result {
      case .success:
        return "proceed_immediately"

      case .successWithPrecedingCancellation(_, let error):
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
      processResult(.success(unlockToken: createTestUnlockToken())),
      "proceed_immediately"
    )

    XCTAssertEqual(
      processResult(
        .successWithPrecedingCancellation(
          unlockToken: createTestUnlockToken(info: testInfo),
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
    let testInfo = TestLockmanInfo(actionId: "documentationExample", strategyId: "ExampleStrategy")

    // Example 1: Success case (most common)
    let unlockToken = createTestUnlockToken(info: testInfo)
    let successResult = LockmanResult<TestBoundary, TestLockmanInfo>.success(
      unlockToken: unlockToken)
    switch successResult {
    case .success(let token):
      // Operation can proceed immediately without any additional cleanup
      XCTAssertNotNil(token)
    default:
      XCTFail("Documentation example should succeed")
    }

    // Example 2: Success with preceding cancellation (priority-based scenarios)
    let precedingError = TestPrecedingError(
      message: "Lower priority operation cancelled",
      cancelledInfo: testInfo
    )
    let precedingResult = LockmanResult<TestBoundary, TestLockmanInfo>
      .successWithPrecedingCancellation(
        unlockToken: createTestUnlockToken(info: testInfo),
        error: precedingError
      )

    switch precedingResult {
    case .successWithPrecedingCancellation(let token, let error):
      // 1. Cancel the existing operation (usually via Effect cancellation)
      // 2. Immediately unlock the cancelled action to prevent resource leaks
      // 3. Proceed with the new operation
      XCTAssertNotNil(token)
      XCTAssertNotNil(error.lockmanInfo)
      XCTAssertEqual(error.lockmanInfo.actionId, "documentationExample")
    default:
      XCTFail("Should be preceding cancellation case")
    }

    // Example 3: Cancel case (conflict situations)
    let cancelError = TestBasicError(message: "Higher priority operation is already active")
    let cancelResult = LockmanResult<TestBoundary, TestLockmanInfo>.cancel(cancelError)

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

    let testInfo = TestLockmanInfo(
      actionId: "realErrorTest", strategyId: "TestSingleExecutionStrategy")

    // Test with conflict error
    let conflictResult = LockmanResult<TestBoundary, TestLockmanInfo>.cancel(
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
    let priorityResult = LockmanResult<TestBoundary, TestLockmanInfo>
      .successWithPrecedingCancellation(
        unlockToken: createTestUnlockToken(info: testInfo),
        error: PriorityError(
          cancelledInfo: testInfo,
          boundary: TestBoundaryId.test,
          newPriority: 10,
          oldPriority: 5
        )
      )

    switch priorityResult {
    case .successWithPrecedingCancellation(let token, let error):
      // Test unlock token
      XCTAssertNotNil(token)

      // Test priority error
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
