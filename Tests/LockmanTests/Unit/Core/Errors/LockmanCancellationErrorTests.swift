import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanCancellationError tests with 3-phase approach
// ✅ 15 test methods covering initialization, protocol conformance, and error handling
// ✅ Phase 1: Basic struct properties and initialization testing
// ✅ Phase 2: LocalizedError conformance and error message delegation
// ✅ Phase 3: Integration testing with various error types and edge cases

final class LockmanCancellationErrorTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Basic Properties and Initialization
  
  func testLockmanCancellationErrorBasicInitialization() {
    // Test basic initialization with required properties
    let testAction = TestAction.fetch
    let testBoundary = "testBoundary"
    let testReason = TestLockmanError(message: "Test error", failureDescription: "Test failure")
    
    let cancellationError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    // Verify all properties are correctly set
    XCTAssertTrue(cancellationError.action is TestAction)
    if let action = cancellationError.action as? TestAction {
      XCTAssertEqual(action, .fetch)
    } else {
      XCTFail("Action should be of type TestAction")
    }
    
    XCTAssertEqual(cancellationError.boundaryId as? String, testBoundary)
    XCTAssertTrue(cancellationError.reason is TestLockmanError)
    if let reason = cancellationError.reason as? TestLockmanError {
      XCTAssertEqual(reason.message, "Test error")
    }
  }
  
  func testLockmanCancellationErrorWithDifferentBoundaryTypes() {
    // Test with different boundary types
    let testAction = TestAction.save
    let testReason = TestLockmanError(message: "Multi-boundary test")
    
    // String boundary
    let stringError = LockmanCancellationError(
      action: testAction,
      boundaryId: "stringBoundary",
      reason: testReason
    )
    XCTAssertEqual(stringError.boundaryId as? String, "stringBoundary")
    
    // Int boundary
    let intError = LockmanCancellationError(
      action: testAction,
      boundaryId: 42,
      reason: testReason
    )
    XCTAssertEqual(intError.boundaryId as? Int, 42)
    
    // UUID boundary
    let uuid = UUID()
    let uuidError = LockmanCancellationError(
      action: testAction,
      boundaryId: uuid,
      reason: testReason
    )
    XCTAssertEqual(uuidError.boundaryId as? UUID, uuid)
  }
  
  func testLockmanCancellationErrorWithDifferentActionTypes() {
    // Test with different action types
    let testBoundary = "actionTestBoundary"
    let testReason = TestLockmanError(message: "Action type test")
    
    // Test with enum action
    let enumAction = TestAction.delete
    let enumError = LockmanCancellationError(
      action: enumAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    XCTAssertTrue(enumError.action is TestAction)
    
    // Test with struct action
    let structAction = TestStructAction(id: 123, name: "test")
    let structError = LockmanCancellationError(
      action: structAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    XCTAssertTrue(structError.action is TestStructAction)
    if let action = structError.action as? TestStructAction {
      XCTAssertEqual(action.id, 123)
      XCTAssertEqual(action.name, "test")
    }
  }
  
  func testLockmanCancellationErrorWithDifferentReasonTypes() {
    // Test with different reason error types
    let testAction = TestAction.update
    let testBoundary = "reasonTestBoundary"
    
    // Test with basic LockmanError
    let basicError = TestLockmanError(message: "Basic error")
    let cancellation1 = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: basicError
    )
    XCTAssertTrue(cancellation1.reason is TestLockmanError)
    
    // Test with detailed error
    let detailedError = TestDetailedError(
      code: 500,
      message: "Detailed error",
      failureDescription: "Detailed failure"
    )
    let cancellation2 = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: detailedError
    )
    XCTAssertTrue(cancellation2.reason is TestDetailedError)
    if let detailed = cancellation2.reason as? TestDetailedError {
      XCTAssertEqual(detailed.code, 500)
    }
  }
  
  // MARK: - Phase 2: LocalizedError Conformance
  
  func testLockmanCancellationErrorLocalizedErrorConformance() {
    // Test that LockmanCancellationError conforms to LocalizedError
    let testAction = TestAction.fetch
    let testBoundary = "localizationTest"
    let testReason = TestLockmanError(
      message: "Localized test error",
      failureDescription: "Localized failure description"
    )
    
    let cancellationError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    // Verify LocalizedError protocol conformance
    XCTAssertTrue(cancellationError is LocalizedError)
    
    // Test error description delegation
    XCTAssertEqual(cancellationError.errorDescription, "Localized test error")
    
    // Test failure reason delegation
    XCTAssertEqual(cancellationError.failureReason, "Localized failure description")
  }
  
  func testLockmanCancellationErrorErrorDescriptionDelegation() {
    // Test error description delegation with various underlying errors
    let testAction = TestAction.save
    let testBoundary = "delegationTest"
    
    // Test with nil error description
    let nilDescError = TestLockmanError(message: nil, failureDescription: nil)
    let nilError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: nilDescError
    )
    XCTAssertNil(nilError.errorDescription)
    XCTAssertNil(nilError.failureReason)
    
    // Test with empty string error description
    let emptyDescError = TestLockmanError(message: "", failureDescription: "")
    let emptyError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: emptyDescError
    )
    XCTAssertEqual(emptyError.errorDescription, "")
    XCTAssertEqual(emptyError.failureReason, "")
    
    // Test with detailed error message
    let detailedDescError = TestLockmanError(
      message: "Complex error with details",
      failureDescription: "Complex failure with context"
    )
    let detailedError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: detailedDescError
    )
    XCTAssertEqual(detailedError.errorDescription, "Complex error with details")
    XCTAssertEqual(detailedError.failureReason, "Complex failure with context")
  }
  
  func testLockmanCancellationErrorFailureReasonDelegation() {
    // Test failure reason delegation specifically
    let testAction = TestAction.delete
    
    // Test with multiple failure scenarios
    let scenarios: [(String?, String?)] = [
      ("Simple error", "Simple failure"),
      ("🚨 Critical error", "🔥 Critical failure"),
      ("Multi-line\nerror message", "Multi-line\nfailure reason"),
      (nil, nil),
      ("", ""),
      ("Error only", nil),
      (nil, "Failure only")
    ]
    
    for (index, (errorDesc, failureDesc)) in scenarios.enumerated() {
      let reason = TestLockmanError(message: errorDesc, failureDescription: failureDesc)
      let cancellation = LockmanCancellationError(
        action: testAction,
        boundaryId: "scenario\(index)",
        reason: reason
      )
      
      XCTAssertEqual(cancellation.errorDescription, errorDesc, 
                    "Scenario \(index): error description mismatch")
      XCTAssertEqual(cancellation.failureReason, failureDesc, 
                    "Scenario \(index): failure reason mismatch")
    }
  }
  
  // MARK: - Phase 3: Protocol Conformance and Type Safety
  
  func testLockmanCancellationErrorLockmanErrorConformance() {
    // Test that LockmanCancellationError conforms to LockmanError protocol
    let testAction = TestAction.update
    let testBoundary = "protocolTest"
    let testReason = TestLockmanError(message: "Protocol conformance test")
    
    let cancellationError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    // Verify LockmanError protocol conformance
    XCTAssertTrue(cancellationError is LockmanError)
    
    // Test that it can be used as LockmanError
    let lockmanError: any LockmanError = cancellationError
    XCTAssertTrue(lockmanError is LockmanCancellationError)
    
    // Test Error protocol conformance (inherited)
    XCTAssertTrue(cancellationError is Error)
    let error: any Error = cancellationError
    XCTAssertTrue(error is LockmanCancellationError)
  }
  
  func testLockmanCancellationErrorSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let testAction = TestAction.fetch
    let testBoundary = "sendableTest"
    let testReason = TestLockmanError(message: "Sendable test")
    
    let cancellationError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    await withTaskGroup(of: String.self) { group in
      // Test concurrent access to error properties
      for i in 0..<5 {
        group.addTask {
          // This compiles without warning = Sendable works
          let actionType = String(describing: type(of: cancellationError.action))
          let boundaryDesc = String(describing: cancellationError.boundaryId)
          let errorDesc = cancellationError.errorDescription ?? "nil"
          return "Task\(i): \(actionType)-\(boundaryDesc)-\(errorDesc)"
        }
      }
      
      var results: [String] = []
      for await result in group {
        results.append(result)
      }
      
      XCTAssertEqual(results.count, 5)
      // All results should contain consistent information
      for result in results {
        XCTAssertTrue(result.contains("TestAction"))
        XCTAssertTrue(result.contains("sendableTest"))
        XCTAssertTrue(result.contains("Sendable test"))
      }
    }
  }
  
  func testLockmanCancellationErrorAsGenericError() {
    // Test usage in generic error handling contexts
    let testAction = TestAction.save
    let testBoundary = "genericTest"
    let testReason = TestLockmanError(message: "Generic handling test")
    
    let cancellationError = LockmanCancellationError(
      action: testAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    // Test in generic function that handles Error
    func handleGenericError<E: Error>(_ error: E) -> String {
      if let localizedError = error as? any LocalizedError {
        return localizedError.errorDescription ?? "No description"
      }
      return "Unknown error"
    }
    
    let result = handleGenericError(cancellationError)
    XCTAssertEqual(result, "Generic handling test")
    
    // Test in generic function that handles LockmanError
    func handleLockmanError<E: LockmanError>(_ error: E) -> Bool {
      return error is LockmanCancellationError
    }
    
    let isLockmanCancellation = handleLockmanError(cancellationError)
    XCTAssertTrue(isLockmanCancellation)
  }
  
  // MARK: - Phase 4: Edge Cases and Special Scenarios
  
  func testLockmanCancellationErrorNestedErrorScenarios() {
    // Test scenarios where reason itself might be a LockmanCancellationError
    let innerAction = TestAction.delete
    let innerBoundary = "innerBoundary"
    let innerReason = TestLockmanError(message: "Inner error")
    
    let innerCancellation = LockmanCancellationError(
      action: innerAction,
      boundaryId: innerBoundary,
      reason: innerReason
    )
    
    let outerAction = TestAction.update
    let outerBoundary = "outerBoundary"
    
    let outerCancellation = LockmanCancellationError(
      action: outerAction,
      boundaryId: outerBoundary,
      reason: innerCancellation
    )
    
    // Verify nested structure
    XCTAssertTrue(outerCancellation.reason is LockmanCancellationError)
    if let nestedCancellation = outerCancellation.reason as? LockmanCancellationError {
      XCTAssertTrue(nestedCancellation.action is TestAction)
      XCTAssertEqual(nestedCancellation.boundaryId as? String, "innerBoundary")
      XCTAssertTrue(nestedCancellation.reason is TestLockmanError)
    }
    
    // Test error description delegation through nested structure
    XCTAssertEqual(outerCancellation.errorDescription, "Inner error")
  }
  
  func testLockmanCancellationErrorWithComplexActions() {
    // Test with complex action structures
    let complexAction = TestComplexAction(
      id: UUID(),
      metadata: ["key1": "value1", "key2": "value2"],
      timestamp: Date(),
      priority: .high
    )
    let testBoundary = "complexActionTest"
    let testReason = TestLockmanError(message: "Complex action test")
    
    let cancellationError = LockmanCancellationError(
      action: complexAction,
      boundaryId: testBoundary,
      reason: testReason
    )
    
    // Verify complex action is preserved
    XCTAssertTrue(cancellationError.action is TestComplexAction)
    if let action = cancellationError.action as? TestComplexAction {
      XCTAssertEqual(action.id, complexAction.id)
      XCTAssertEqual(action.metadata, complexAction.metadata)
      XCTAssertEqual(action.timestamp.timeIntervalSince1970, 
                    complexAction.timestamp.timeIntervalSince1970, 
                    accuracy: 0.001)
      XCTAssertEqual(action.priority, complexAction.priority)
    }
  }
  
  // MARK: - Helper Types for Testing
  
  private struct TestLockmanInfo: LockmanInfo {
    let actionId: LockmanActionId
    let strategyId: LockmanStrategyId
    let uniqueId: UUID
    let isCancellationTarget: Bool

    init(
      actionId: LockmanActionId,
      strategyId: LockmanStrategyId,
      uniqueId: UUID = UUID(),
      isCancellationTarget: Bool = false
    ) {
      self.actionId = actionId
      self.strategyId = strategyId
      self.uniqueId = uniqueId
      self.isCancellationTarget = isCancellationTarget
    }

    var debugDescription: String {
      return "TestLockmanInfo(action: \(actionId), strategy: \(strategyId), unique: \(uniqueId), cancellable: \(isCancellationTarget))"
    }
  }
  
  private enum TestAction: LockmanAction, Equatable {
    typealias I = TestLockmanInfo
    
    case fetch
    case save
    case delete
    case update
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: "TestAction.\(self)", strategyId: "TestStrategy")
    }
  }
  
  private struct TestStructAction: LockmanAction, Equatable {
    typealias I = TestLockmanInfo
    
    let id: Int
    let name: String
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: "TestStructAction.\(id).\(name)", strategyId: "TestStrategy")
    }
  }
  
  private struct TestComplexAction: LockmanAction, Equatable {
    typealias I = TestLockmanInfo
    
    let id: UUID
    let metadata: [String: String]
    let timestamp: Date
    let priority: Priority
    
    enum Priority: Equatable {
      case low, medium, high
    }
    
    func createLockmanInfo() -> TestLockmanInfo {
      TestLockmanInfo(actionId: "TestComplexAction.\(id)", strategyId: "TestStrategy")
    }
  }
  
  private struct TestLockmanError: LockmanError {
    let message: String?
    let failureDescription: String?
    
    init(message: String?, failureDescription: String? = nil) {
      self.message = message
      self.failureDescription = failureDescription
    }
    
    var errorDescription: String? { message }
    var failureReason: String? { failureDescription }
  }
  
  private struct TestDetailedError: LockmanError {
    let code: Int
    let message: String
    let failureDescription: String
    
    var errorDescription: String? { message }
    var failureReason: String? { failureDescription }
  }

}