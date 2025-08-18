import XCTest

@testable import Lockman

/// Unit tests for LockmanResult
///
/// Tests the enumeration that represents the possible outcomes when a strategy attempts
/// to acquire a lock for a given boundary and lock information.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Enum Case Construction and Properties
/// - [ ] LockmanResult.success case creation and equality
/// - [ ] LockmanResult.successWithPrecedingCancellation case creation with LockmanPrecedingCancellationError
/// - [ ] LockmanResult.cancel case creation with LockmanError
/// - [ ] Sendable conformance verification for concurrent usage
/// - [ ] Associated value access for successWithPrecedingCancellation
/// - [ ] Associated value access for cancel case
///
/// ### Pattern Matching and Switch Statement Usage
/// - [ ] Pattern matching with success case
/// - [ ] Pattern matching with successWithPrecedingCancellation case and error extraction
/// - [ ] Pattern matching with cancel case and error extraction
/// - [ ] Exhaustive switch statement coverage
/// - [ ] if case pattern matching for specific cases
/// - [ ] guard case pattern matching for error handling
///
/// ### Error Type Compatibility
/// - [ ] successWithPrecedingCancellation accepts LockmanPrecedingCancellationError types
/// - [ ] cancel accepts LockmanError conforming types
/// - [ ] cancel accepts various strategy-specific error types
/// - [ ] Protocol conformance verification at usage sites
///
/// ### Error Information Access
/// - [ ] LockmanPrecedingCancellationError.lockmanInfo access from successWithPrecedingCancellation
/// - [ ] LockmanPrecedingCancellationError.boundaryId access from successWithPrecedingCancellation
/// - [ ] LockmanError.localizedDescription access from cancel case
/// - [ ] Error casting and type checking for specific error types
///
/// ### Integration with Strategy Results
/// - [ ] Strategy.canLock return value handling for all cases
/// - [ ] Priority-based strategy result scenarios
/// - [ ] Single execution strategy result scenarios
/// - [ ] Error propagation through strategy chain
///
/// ### Edge Cases and Error Conditions
/// - [ ] Empty error messages handling
/// - [ ] Nil error descriptions handling
/// - [ ] Complex error type hierarchies
/// - [ ] Unicode and special characters in error descriptions
///
final class LockmanResultTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Basic Enum Case Tests

  func testSuccessCaseCreation() {
    let result = LockmanResult.success

    switch result {
    case .success:
      XCTAssertTrue(true, "Success case created correctly")
    default:
      XCTFail("Expected success case")
    }
  }

  func testSuccessWithPrecedingCancellationCaseCreation() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test-action"),
      priority: .high(.exclusive)
    )
    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: info,
      boundaryId: "test-boundary"
    )

    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    switch result {
    case .successWithPrecedingCancellation(let capturedError):
      XCTAssertEqual(capturedError.lockmanInfo.actionId, LockmanActionId("test-action"))
      XCTAssertEqual("\(capturedError.boundaryId)", "test-boundary")
    default:
      XCTFail("Expected successWithPrecedingCancellation case")
    }
  }

  func testCancelCaseCreation() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test-boundary",
      lockmanInfo: info
    )

    let result = LockmanResult.cancel(error)

    switch result {
    case .cancel(let capturedError):
      XCTAssertNotNil(capturedError.localizedDescription)
      XCTAssertTrue(capturedError is LockmanSingleExecutionError)
    default:
      XCTFail("Expected cancel case")
    }
  }

  // MARK: - Pattern Matching Tests

  func testExhaustiveSwitchStatement() {
    let results: [LockmanResult] = [
      .success,
      .successWithPrecedingCancellation(error: createTestPrecedingCancellationError()),
      .cancel(createTestLockmanError()),
    ]

    for result in results {
      var handledCorrectly = false

      switch result {
      case .success:
        handledCorrectly = true
      case .successWithPrecedingCancellation(let error):
        XCTAssertNotNil(error.lockmanInfo)
        handledCorrectly = true
      case .cancel(let error):
        XCTAssertNotNil(error.localizedDescription)
        handledCorrectly = true
      }

      XCTAssertTrue(handledCorrectly, "All cases should be handled")
    }
  }

  func testIfCasePatternMatching() {
    let successResult = LockmanResult.success
    let cancelResult = LockmanResult.cancel(createTestLockmanError())

    if case .success = successResult {
      XCTAssertTrue(true, "Success case matched correctly")
    } else {
      XCTFail("Should match success case")
    }

    if case .cancel(let error) = cancelResult {
      XCTAssertNotNil(error.localizedDescription)
    } else {
      XCTFail("Should match cancel case")
    }
  }

  // MARK: - Error Type Tests

  func testLockmanPrecedingCancellationErrorProtocol() {
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("protocol-test"),
      priority: .low(.exclusive)
    )
    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: info,
      boundaryId: "protocol-boundary"
    )

    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    if case .successWithPrecedingCancellation(let precedingError) = result {
      // Test protocol access
      XCTAssertEqual(precedingError.lockmanInfo.actionId, LockmanActionId("protocol-test"))
      XCTAssertEqual("\(precedingError.boundaryId)", "protocol-boundary")

      // Test type conformance
      XCTAssertTrue(precedingError is any LockmanPrecedingCancellationError)
      XCTAssertTrue(precedingError is any LockmanError)
    } else {
      XCTFail("Expected successWithPrecedingCancellation case")
    }
  }

  func testLockmanErrorProtocol() {
    let info = LockmanSingleExecutionInfo(mode: .action)
    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "error-test",
      lockmanInfo: info
    )

    let result = LockmanResult.cancel(error)

    if case .cancel(let lockmanError) = result {
      // Test LocalizedError conformance
      XCTAssertNotNil(lockmanError.localizedDescription)
      XCTAssertNotNil(lockmanError.failureReason)

      // Test type conformance - lockmanError is already any LockmanError
      XCTAssertTrue(lockmanError is any LockmanError)
      XCTAssertTrue(lockmanError is Error)
      XCTAssertTrue(lockmanError is any LocalizedError)
    } else {
      XCTFail("Expected cancel case")
    }
  }

  // MARK: - Integration Tests

  func testPriorityBasedStrategyResultScenarios() {
    // Test high priority preempts low priority
    let preemptionError = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("low-priority"),
        priority: .low(.exclusive)
      ),
      boundaryId: "priority-test"
    )

    let result = LockmanResult.successWithPrecedingCancellation(error: preemptionError)

    switch result {
    case .successWithPrecedingCancellation(let error):
      if let priorityError = error as? LockmanPriorityBasedError,
        case .precedingActionCancelled(let info, _) = priorityError
      {
        XCTAssertEqual(info.priority, .low(.exclusive))
      }
    default:
      XCTFail("Expected priority preemption scenario")
    }
  }

  func testSingleExecutionStrategyResultScenarios() {
    // Test boundary already locked scenario
    let boundaryError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "single-test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let result = LockmanResult.cancel(boundaryError)

    switch result {
    case .cancel(let error):
      if let singleError = error as? LockmanSingleExecutionError,
        case .boundaryAlreadyLocked(let boundaryId, let info) = singleError
      {
        XCTAssertEqual("\(boundaryId)", "single-test")
        XCTAssertEqual(info.mode, .boundary)
      }
    default:
      XCTFail("Expected single execution scenario")
    }
  }

  // MARK: - Sendable Tests

  func testSendableConformance() {
    let results: [LockmanResult] = [
      .success,
      .successWithPrecedingCancellation(error: createTestPrecedingCancellationError()),
      .cancel(createTestLockmanError()),
    ]

    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 3

    for result in results {
      DispatchQueue.global().async {
        // Access result in concurrent context
        switch result {
        case .success, .successWithPrecedingCancellation, .cancel:
          expectation.fulfill()
        }
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - Edge Cases

  func testUnicodeErrorMessages() {
    let unicodeBoundary = "テスト境界🔒"
    let unicodeError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: unicodeBoundary,
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let result = LockmanResult.cancel(unicodeError)

    switch result {
    case .cancel(let error):
      let description = error.localizedDescription
      XCTAssertTrue(description.contains(unicodeBoundary))
    default:
      XCTFail("Expected cancel case")
    }
  }

  func testCustomErrorTypes() {
    struct CustomError: LockmanError {
      var errorDescription: String? { "Custom test error" }
      var failureReason: String? { "Testing custom error types" }
    }

    let result = LockmanResult.cancel(CustomError())

    switch result {
    case .cancel(let error):
      XCTAssertEqual(error.localizedDescription, "Custom test error")
      XCTAssertEqual(error.failureReason, "Testing custom error types")
    default:
      XCTFail("Expected cancel case")
    }
  }

  // MARK: - Helper Methods

  private func createTestPrecedingCancellationError() -> any LockmanPrecedingCancellationError {
    return LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: LockmanPriorityBasedInfo(
        actionId: LockmanActionId("test-precedence"),
        priority: .low(.exclusive)
      ),
      boundaryId: "test-boundary"
    )
  }

  private func createTestLockmanError() -> any LockmanError {
    return LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test-lockman",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )
  }
}
