import XCTest

@testable import Lockman

/// Unit tests for LockmanSingleExecutionError
///
/// Tests error handling for single-execution strategy lock conflicts.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Error Case Definitions
/// - [ ] boundaryAlreadyLocked case structure and parameters
/// - [ ] actionAlreadyRunning case structure and parameters
/// - [ ] Error case parameter validation (boundaryId, lockmanInfo)
/// - [ ] Associated values type safety
/// - [ ] Error case pattern matching behavior
///
/// ### Protocol Conformance
/// - [ ] LockmanStrategyError protocol implementation
/// - [ ] LocalizedError protocol implementation
/// - [ ] Error protocol inheritance chain
/// - [ ] Protocol requirement fulfillment verification
/// - [ ] Multiple protocol conformance validation
///
/// ### LocalizedError Implementation
/// - [ ] errorDescription format and content validation
/// - [ ] failureReason explanation accuracy
/// - [ ] Error message localization support
/// - [ ] Boundary and action information inclusion
/// - [ ] User-friendly error message formatting
/// - [ ] Error description uniqueness per case
///
/// ### LockmanStrategyError Implementation
/// - [ ] lockmanInfo property extraction from cases
/// - [ ] boundaryId property extraction from cases
/// - [ ] Property consistency across error cases
/// - [ ] Type erasure handling for boundaryId
/// - [ ] Protocol property access validation
///
/// ### Error Creation & Context
/// - [ ] boundaryAlreadyLocked error creation scenarios
/// - [ ] actionAlreadyRunning error creation scenarios
/// - [ ] Error context preservation during creation
/// - [ ] Associated value immutability
/// - [ ] Error instance equality behavior
///
/// ### Boundary Mode Error Handling
/// - [ ] Boundary-wide lock conflict detection
/// - [ ] Multiple action prevention in boundary mode
/// - [ ] Boundary lock state tracking
/// - [ ] Cross-boundary error isolation
/// - [ ] Boundary cleanup on error scenarios
///
/// ### Action Mode Error Handling
/// - [ ] Same actionId conflict detection
/// - [ ] Action-specific lock management
/// - [ ] Different actionId parallel execution allowance
/// - [ ] Action completion and error resolution
/// - [ ] Action retry after conflict resolution
///
/// ### Error Propagation & Handling
/// - [ ] Error propagation through strategy layers
/// - [ ] Error handling in async contexts
/// - [ ] Error recovery mechanisms
/// - [ ] Error logging and diagnostics
/// - [ ] Error transformation through abstractions
///
/// ### Integration with Strategy System
/// - [ ] Strategy error reporting consistency
/// - [ ] Error handling in lock acquisition
/// - [ ] Error coordination with boundary locks
/// - [ ] Container-level error management
/// - [ ] Error correlation with strategy lifecycle
///
/// ### Thread Safety & Concurrency
/// - [ ] Thread-safe error creation
/// - [ ] Concurrent error reporting scenarios
/// - [ ] Error state consistency under contention
/// - [ ] Race condition error handling
/// - [ ] Error serialization in concurrent contexts
///
/// ### Performance & Memory
/// - [ ] Error creation performance impact
/// - [ ] Memory usage of error instances
/// - [ ] Error string generation performance
/// - [ ] Large-scale error handling behavior
/// - [ ] Error cleanup and garbage collection
///
/// ### Edge Cases & Error Conditions
/// - [ ] Nil boundaryId handling (if possible)
/// - [ ] Invalid lockmanInfo scenarios
/// - [ ] Error chaining and nested errors
/// - [ ] Error state corruption prevention
/// - [ ] Memory pressure error scenarios
///
/// ### Debugging & Diagnostics
/// - [ ] Error debugging information completeness
/// - [ ] Error trace and context preservation
/// - [ ] Developer-friendly error messages
/// - [ ] Error categorization and filtering
/// - [ ] Error correlation with system state
///
/// ### Real-world Error Scenarios
/// - [ ] User action conflicts during authentication
/// - [ ] Data synchronization conflicts
/// - [ ] API request deduplication errors
/// - [ ] File operation exclusive access errors
/// - [ ] Database transaction conflict errors
///
final class LockmanSingleExecutionErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Error Case Creation Tests

  func testBoundaryAlreadyLockedCaseCreation() {
    let boundaryId = TestSupport.StandardBoundaryIds.main
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "boundary-test"),
      mode: .boundary
    )

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId, lockmanInfo: info
    )

    switch error {
    case .boundaryAlreadyLocked(let capturedBoundaryId, let capturedInfo):
      XCTAssertEqual("\(capturedBoundaryId)", "\(boundaryId)")
      XCTAssertEqual(capturedInfo.actionId, info.actionId)
      XCTAssertEqual(capturedInfo.mode, .boundary)
    case .actionAlreadyRunning:
      XCTFail("Expected boundaryAlreadyLocked case")
    }
  }

  func testActionAlreadyRunningCaseCreation() {
    let boundaryId = TestSupport.StandardBoundaryIds.secondary
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "action-test"),
      mode: .action
    )

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundaryId, lockmanInfo: info
    )

    switch error {
    case .actionAlreadyRunning(let capturedBoundaryId, let capturedInfo):
      XCTAssertEqual("\(capturedBoundaryId)", "\(boundaryId)")
      XCTAssertEqual(capturedInfo.actionId, info.actionId)
      XCTAssertEqual(capturedInfo.mode, .action)
    case .boundaryAlreadyLocked:
      XCTFail("Expected actionAlreadyRunning case")
    }
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanStrategyErrorConformance() {
    let boundaryId = "protocol-test-boundary"
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "protocol"),
      mode: .boundary
    )

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId, lockmanInfo: info
    )

    // Test protocol conformance
    XCTAssertTrue(error is any LockmanStrategyError)
    XCTAssertTrue(error is any LockmanError)
    XCTAssertTrue(error is any LocalizedError)
    XCTAssertTrue(error is any Error)

    // Test protocol properties
    XCTAssertEqual(error.lockmanInfo.actionId, info.actionId)
    XCTAssertEqual("\(error.boundaryId)", boundaryId)
  }

  func testLocalizedErrorConformance() {
    let boundaryId = "localization-test"
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "localized"),
      mode: .action
    )

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundaryId, lockmanInfo: info
    )

    // Test LocalizedError properties
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
    XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    XCTAssertFalse(error.failureReason?.isEmpty ?? true)
  }

  // MARK: - LocalizedError Implementation Tests

  func testBoundaryAlreadyLockedErrorDescription() {
    let boundaryId = "test-boundary-123"
    let actionId = TestSupport.uniqueActionId(prefix: "test-action")
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundaryId, lockmanInfo: info
    )

    let description = error.errorDescription!
    XCTAssertTrue(description.contains(boundaryId))
    XCTAssertTrue(description.contains("\(actionId)"))
    XCTAssertTrue(description.contains("already has an active lock"))
    XCTAssertTrue(description.contains("Cannot acquire lock"))
  }

  func testActionAlreadyRunningErrorDescription() {
    let actionId = TestSupport.uniqueActionId(prefix: "running-action")
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "any-boundary", lockmanInfo: info
    )

    let description = error.errorDescription!
    XCTAssertTrue(description.contains("\(actionId)"))
    XCTAssertTrue(description.contains("is already running"))
    XCTAssertTrue(description.contains("Cannot acquire lock"))
  }

  func testBoundaryAlreadyLockedFailureReason() {
    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )

    let reason = error.failureReason!
    XCTAssertTrue(reason.contains("SingleExecutionStrategy"))
    XCTAssertTrue(reason.contains("boundary mode"))
    XCTAssertTrue(reason.contains("prevents multiple operations"))
  }

  func testActionAlreadyRunningFailureReason() {
    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
    )

    let reason = error.failureReason!
    XCTAssertTrue(reason.contains("SingleExecutionStrategy"))
    XCTAssertTrue(reason.contains("action mode"))
    XCTAssertTrue(reason.contains("prevents duplicate action execution"))
  }

  // MARK: - LockmanStrategyError Implementation Tests

  func testLockmanInfoPropertyExtraction() {
    let info1 = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "info1"),
      mode: .boundary
    )
    let info2 = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "info2"),
      mode: .action
    )

    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "boundary1", lockmanInfo: info1
    )
    let error2 = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "boundary2", lockmanInfo: info2
    )

    // Test lockmanInfo extraction
    XCTAssertEqual(error1.lockmanInfo.actionId, info1.actionId)
    XCTAssertEqual(error2.lockmanInfo.actionId, info2.actionId)

    // Type safety check
    if let extractedInfo1 = error1.lockmanInfo as? LockmanSingleExecutionInfo {
      XCTAssertEqual(extractedInfo1.mode, .boundary)
    } else {
      XCTFail("Failed to cast lockmanInfo to LockmanSingleExecutionInfo")
    }

    if let extractedInfo2 = error2.lockmanInfo as? LockmanSingleExecutionInfo {
      XCTAssertEqual(extractedInfo2.mode, .action)
    } else {
      XCTFail("Failed to cast lockmanInfo to LockmanSingleExecutionInfo")
    }
  }

  func testBoundaryIdPropertyExtraction() {
    let boundary1 = "test-boundary-alpha"
    let boundary2 = TestSupport.StandardBoundaryIds.unicode

    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: boundary1,
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )
    let error2 = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: boundary2,
      lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
    )

    XCTAssertEqual("\(error1.boundaryId)", boundary1)
    XCTAssertEqual("\(error2.boundaryId)", boundary2)
  }

  // MARK: - Error Creation Context Tests

  func testErrorCreationWithDifferentModes() {
    let actionId = TestSupport.uniqueActionId(prefix: "mode-test")

    let noneInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .none)
    let boundaryInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    let actionInfo = LockmanSingleExecutionInfo(actionId: actionId, mode: .action)

    // Test that error creation works with all modes
    let error1 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test", lockmanInfo: noneInfo
    )
    let error2 = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test", lockmanInfo: boundaryInfo
    )
    let error3 = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "test", lockmanInfo: actionInfo
    )

    // Verify mode preservation
    if let info1 = error1.lockmanInfo as? LockmanSingleExecutionInfo {
      XCTAssertEqual(info1.mode, .none)
    }
    if let info2 = error2.lockmanInfo as? LockmanSingleExecutionInfo {
      XCTAssertEqual(info2.mode, .boundary)
    }
    if let info3 = error3.lockmanInfo as? LockmanSingleExecutionInfo {
      XCTAssertEqual(info3.mode, .action)
    }
  }

  func testErrorCreationWithUnicodeData() {
    let unicodeBoundary = TestSupport.StandardBoundaryIds.unicode
    let unicodeAction = TestSupport.StandardActionIds.unicode
    let info = LockmanSingleExecutionInfo(actionId: unicodeAction, mode: .boundary)

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: unicodeBoundary, lockmanInfo: info
    )

    let description = error.errorDescription!
    XCTAssertTrue(description.contains(unicodeBoundary))
    XCTAssertTrue(description.contains(unicodeAction))
  }

  // MARK: - Pattern Matching Tests

  func testExhaustivePatternMatching() {
    let errors: [LockmanSingleExecutionError] = [
      .boundaryAlreadyLocked(
        boundaryId: "boundary1",
        lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
      ),
      .actionAlreadyRunning(
        boundaryId: "boundary2",
        lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
      ),
    ]

    for error in errors {
      var handled = false

      switch error {
      case .boundaryAlreadyLocked(let boundaryId, let info):
        XCTAssertNotNil(boundaryId)
        XCTAssertNotNil(info)
        handled = true
      case .actionAlreadyRunning(let boundaryId, let info):
        XCTAssertNotNil(boundaryId)
        XCTAssertNotNil(info)
        handled = true
      }

      XCTAssertTrue(handled, "All error cases should be handled")
    }
  }

  func testIfCasePatternMatching() {
    let boundaryError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .boundary)
    )
    let actionError = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "test",
      lockmanInfo: LockmanSingleExecutionInfo(mode: .action)
    )

    if case .boundaryAlreadyLocked(let boundaryId, let info) = boundaryError {
      XCTAssertEqual("\(boundaryId)", "test")
      XCTAssertNotNil(info)
    } else {
      XCTFail("Should match boundaryAlreadyLocked case")
    }

    if case .actionAlreadyRunning(let boundaryId, let info) = actionError {
      XCTAssertEqual("\(boundaryId)", "test")
      XCTAssertNotNil(info)
    } else {
      XCTFail("Should match actionAlreadyRunning case")
    }
  }

  // MARK: - Edge Cases Tests

  func testErrorsWithEmptyStrings() {
    let emptyBoundary = TestSupport.StandardBoundaryIds.empty
    let emptyAction = TestSupport.StandardActionIds.empty
    let info = LockmanSingleExecutionInfo(actionId: emptyAction, mode: .boundary)

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: emptyBoundary, lockmanInfo: info
    )

    // Error should still be created successfully
    XCTAssertNotNil(error.errorDescription)
    XCTAssertNotNil(error.failureReason)
  }

  func testErrorsWithSpecialCharacters() {
    let specialAction = TestSupport.StandardActionIds.withSpecialChars
    let info = LockmanSingleExecutionInfo(actionId: specialAction, mode: .action)

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "test@boundary#123", lockmanInfo: info
    )

    let description = error.errorDescription!
    XCTAssertTrue(description.contains(specialAction))
    XCTAssertTrue(description.contains("test@boundary#123"))
  }

  func testErrorsWithVeryLongStrings() {
    let longAction = TestSupport.StandardActionIds.veryLong
    let info = LockmanSingleExecutionInfo(actionId: longAction, mode: .boundary)

    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: String(repeating: "longBoundary", count: 50),
      lockmanInfo: info
    )

    // Should handle long strings without issues
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains(longAction))
  }

  // MARK: - Memory and Performance Tests

  func testErrorCreationPerformance() {
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    let executionTime = TestSupport.measureExecutionTime {
      for i in 0..<1000 {
        let _ = LockmanSingleExecutionError.boundaryAlreadyLocked(
          boundaryId: "boundary-\(i)",
          lockmanInfo: info
        )
      }
    }

    XCTAssertLessThan(executionTime, 0.1, "Error creation should be fast")
  }

  func testErrorStringGenerationPerformance() {
    let errors = (0..<100).map { i in
      LockmanSingleExecutionError.actionAlreadyRunning(
        boundaryId: "boundary-\(i)",
        lockmanInfo: LockmanSingleExecutionInfo(
          actionId: TestSupport.uniqueActionId(prefix: "action-\(i)"),
          mode: .action
        )
      )
    }

    let executionTime = TestSupport.measureExecutionTime {
      for error in errors {
        let _ = error.errorDescription
        let _ = error.failureReason
      }
    }

    XCTAssertLessThan(executionTime, 0.1, "Error string generation should be fast")
  }

  // MARK: - Thread Safety Tests

  func testConcurrentErrorCreation() async {
    let results = try! await TestSupport.executeConcurrently(iterations: 50) {
      let actionId = TestSupport.uniqueActionId(prefix: "concurrent")
      let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
      return LockmanSingleExecutionError.boundaryAlreadyLocked(
        boundaryId: "concurrent-boundary",
        lockmanInfo: info
      )
    }

    XCTAssertEqual(results.count, 50)
    for error in results {
      XCTAssertNotNil(error.errorDescription)
      XCTAssertEqual("\(error.boundaryId)", "concurrent-boundary")
    }
  }

  func testConcurrentErrorStringAccess() async {
    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "shared-boundary",
      lockmanInfo: LockmanSingleExecutionInfo(
        actionId: TestSupport.uniqueActionId(prefix: "shared"),
        mode: .action
      )
    )

    let results = try! await TestSupport.executeConcurrently(iterations: 20) {
      return (
        description: error.errorDescription ?? "",
        reason: error.failureReason ?? ""
      )
    }

    XCTAssertEqual(results.count, 20)

    // All results should be identical
    let firstResult = results[0]
    for result in results.dropFirst() {
      XCTAssertEqual(result.description, firstResult.description)
      XCTAssertEqual(result.reason, firstResult.reason)
    }
  }

  // MARK: - Integration Tests

  func testErrorIntegrationWithStrategySystem() {
    // Test that errors can be properly cast and used within the strategy system
    let info = LockmanSingleExecutionInfo(
      actionId: TestSupport.uniqueActionId(prefix: "integration"),
      mode: .boundary
    )
    let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "integration-boundary",
      lockmanInfo: info
    )

    // Test as LockmanError
    let lockmanError: any LockmanError = error
    XCTAssertTrue(lockmanError is LockmanStrategyError)
    
    // Test as LockmanStrategyError
    let strategyError = lockmanError as! LockmanStrategyError
    XCTAssertEqual(strategyError.lockmanInfo.actionId, info.actionId)

    // Test as LocalizedError
    let localizedError: any LocalizedError = error
    XCTAssertNotNil(localizedError.errorDescription)

    // Test in Result type (common usage pattern)
    let result = LockmanResult.cancel(error)
    switch result {
    case .cancel(let resultError):
      XCTAssertTrue(resultError is LockmanSingleExecutionError)
    default:
      XCTFail("Expected cancel result")
    }
  }

  func testErrorUsageInRealWorldScenarios() {
    // Scenario: Login conflict
    let loginInfo = LockmanSingleExecutionInfo(
      actionId: "user-login",
      mode: .boundary
    )
    let loginError = LockmanSingleExecutionError.boundaryAlreadyLocked(
      boundaryId: "authentication",
      lockmanInfo: loginInfo
    )

    XCTAssertTrue(loginError.errorDescription!.contains("user-login"))
    XCTAssertTrue(loginError.errorDescription!.contains("authentication"))

    // Scenario: Data sync conflict
    let syncInfo = LockmanSingleExecutionInfo(
      actionId: "sync-user-data",
      mode: .action
    )
    let syncError = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "data-sync",
      lockmanInfo: syncInfo
    )

    XCTAssertTrue(syncError.errorDescription!.contains("sync-user-data"))
  }
}
