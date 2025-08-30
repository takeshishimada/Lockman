import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive protocol tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanErrorTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Test Error Types for Protocol Conformance
  
  private struct TestBasicError: LockmanError {
    let message: String
    
    var errorDescription: String? {
      return message
    }
  }
  
  private enum TestErrorEnum: LockmanError, Equatable {
    case networkFailure
    case invalidInput(String)
    case timeout(seconds: Int)
    
    var errorDescription: String? {
      switch self {
      case .networkFailure:
        return "Network connection failed"
      case .invalidInput(let input):
        return "Invalid input: \(input)"
      case .timeout(let seconds):
        return "Operation timed out after \(seconds) seconds"
      }
    }
  }
  
  private final class TestErrorClass: LockmanError {
    let code: Int
    let details: String
    
    init(code: Int, details: String) {
      self.code = code
      self.details = details
    }
    
    var errorDescription: String? {
      return "Error \(code): \(details)"
    }
  }
  
  // MARK: - Phase 1: Basic Protocol Conformance
  
  func testLockmanErrorBasicConformance() {
    // Test basic LockmanError conformance
    let error: any LockmanError = TestBasicError(message: "Test error")
    
    // Should conform to Error and LocalizedError protocols
    XCTAssertNotNil(error as any Error)
    XCTAssertNotNil(error as any LocalizedError)
    // Should have error description
    XCTAssertEqual(error.errorDescription, "Test error")
  }
  
  func testLockmanErrorEnumConformance() {
    // Test enum conforming to LockmanError
    let networkError: any LockmanError = TestErrorEnum.networkFailure
    let inputError: any LockmanError = TestErrorEnum.invalidInput("invalid data")
    let timeoutError: any LockmanError = TestErrorEnum.timeout(seconds: 30)
    
    XCTAssertEqual(networkError.errorDescription, "Network connection failed")
    XCTAssertEqual(inputError.errorDescription, "Invalid input: invalid data")
    XCTAssertEqual(timeoutError.errorDescription, "Operation timed out after 30 seconds")
  }
  
  func testLockmanErrorClassConformance() {
    // Test class conforming to LockmanError
    let error: any LockmanError = TestErrorClass(code: 404, details: "Not found")
    
    XCTAssertEqual(error.errorDescription, "Error 404: Not found")
    XCTAssertTrue(error is TestErrorClass)
  }
  
  func testLockmanErrorAsError() {
    // Test using LockmanError as standard Error
    let lockmanError: any LockmanError = TestBasicError(message: "Lockman test error")
    let standardError: any Error = lockmanError
    
    XCTAssertNotNil(standardError)
    
    // Test error casting
    if let localizedError = standardError as? any LocalizedError {
      XCTAssertEqual(localizedError.errorDescription, "Lockman test error")
    } else {
      XCTFail("LockmanError should be castable to LocalizedError")
    }
  }
  
  // MARK: - Phase 2: LocalizedError Protocol Requirements
  
  func testLockmanErrorLocalizedDescription() {
    // Test LocalizedError protocol requirements
    let error = TestBasicError(message: "Localized test message")
    
    XCTAssertEqual(error.errorDescription, "Localized test message")
    XCTAssertEqual(error.localizedDescription, "Localized test message")
  }
  
  func testLockmanErrorFailureReason() {
    // Test failure reason (optional LocalizedError method)
    struct DetailedError: LockmanError {
      var errorDescription: String? { "Operation failed" }
      var failureReason: String? { "Network timeout occurred" }
      var recoverySuggestion: String? { "Check network connection and retry" }
    }
    
    let error = DetailedError()
    XCTAssertEqual(error.errorDescription, "Operation failed")
    XCTAssertEqual(error.failureReason, "Network timeout occurred")
    XCTAssertEqual(error.recoverySuggestion, "Check network connection and retry")
  }
  
  func testLockmanErrorNilDescription() {
    // Test error with nil description
    struct MinimalError: LockmanError {
      var errorDescription: String? { nil }
    }
    
    let error = MinimalError()
    XCTAssertNil(error.errorDescription)
    // localizedDescription should still work (default implementation)
    XCTAssertFalse(error.localizedDescription.isEmpty)
  }
  
  // MARK: - Phase 3: Error Handling and Throwing
  
  func testLockmanErrorThrowAndCatch() {
    // Test throwing and catching LockmanError
    func throwLockmanError() throws {
      throw TestBasicError(message: "Thrown error")
    }
    
    do {
      try throwLockmanError()
      XCTFail("Should have thrown an error")
    } catch let lockmanError as any LockmanError {
      XCTAssertEqual(lockmanError.errorDescription, "Thrown error")
    } catch {
      XCTFail("Should have caught LockmanError, but caught: \(error)")
    }
  }
  
  func testLockmanErrorInResult() {
    // Test using LockmanError in Result type
    func operationThatFails() -> Result<String, TestErrorEnum> {
      return .failure(TestErrorEnum.networkFailure)
    }
    
    let result = operationThatFails()
    
    switch result {
    case .success:
      XCTFail("Should have failed")
    case .failure(let error):
      XCTAssertEqual(error.errorDescription, "Network connection failed")
    }
  }
  
  func testLockmanErrorEquality() {
    // Test error equality (where applicable)
    let error1 = TestErrorEnum.networkFailure
    let error2 = TestErrorEnum.networkFailure
    let error3 = TestErrorEnum.timeout(seconds: 30)
    
    XCTAssertEqual(error1, error2)
    XCTAssertNotEqual(error1, error3)
  }
  
  // MARK: - Phase 4: Type Erasure and Collections
  
  func testLockmanErrorInCollection() {
    // Test storing different LockmanError types in collection
    let errors: [any LockmanError] = [
      TestBasicError(message: "Basic error"),
      TestErrorEnum.networkFailure,
      TestErrorClass(code: 500, details: "Server error")
    ]
    
    XCTAssertEqual(errors.count, 3)
    
    // Test processing mixed error types
    let descriptions = errors.compactMap { $0.errorDescription }
    XCTAssertEqual(descriptions.count, 3)
    XCTAssertTrue(descriptions.contains("Basic error"))
    XCTAssertTrue(descriptions.contains("Network connection failed"))
    XCTAssertTrue(descriptions.contains("Error 500: Server error"))
  }
  
  func testLockmanErrorTypeChecking() {
    // Test runtime type checking of LockmanError
    let errors: [any LockmanError] = [
      TestBasicError(message: "Struct error"),
      TestErrorEnum.invalidInput("bad data"),
      TestErrorClass(code: 403, details: "Forbidden")
    ]
    
    var structCount = 0
    var enumCount = 0
    var classCount = 0
    
    for error in errors {
      if error is TestBasicError {
        structCount += 1
      } else if error is TestErrorEnum {
        enumCount += 1
      } else if error is TestErrorClass {
        classCount += 1
      }
    }
    
    XCTAssertEqual(structCount, 1)
    XCTAssertEqual(enumCount, 1)
    XCTAssertEqual(classCount, 1)
  }
  
  // MARK: - Phase 5: Real-world Lockman Error Patterns
  
  func testLockmanErrorInLockingScenario() {
    // Test error in realistic locking scenario
    enum LockingError: LockmanError {
      case boundaryAlreadyLocked(boundaryId: String)
      case strategyNotFound(strategyId: String)
      case configurationInvalid(reason: String)
      
      var errorDescription: String? {
        switch self {
        case .boundaryAlreadyLocked(let boundaryId):
          return "Boundary '\(boundaryId)' is already locked"
        case .strategyNotFound(let strategyId):
          return "Strategy '\(strategyId)' not found"
        case .configurationInvalid(let reason):
          return "Configuration invalid: \(reason)"
        }
      }
    }
    
    func attemptLock(boundaryId: String) -> Result<Void, LockingError> {
      if boundaryId == "busy" {
        return .failure(LockingError.boundaryAlreadyLocked(boundaryId: boundaryId))
      }
      return .success(())
    }
    
    let successResult = attemptLock(boundaryId: "free")
    let failureResult = attemptLock(boundaryId: "busy")
    
    switch successResult {
    case .success:
      XCTAssertTrue(true) // Success case
    case .failure:
      XCTFail("Should have succeeded")
    }
    
    switch failureResult {
    case .success:
      XCTFail("Should have failed")
    case .failure:
      XCTAssertTrue(true) // Failure case
    }
    
    if case .failure(let error) = failureResult {
      XCTAssertEqual(error.errorDescription, "Boundary 'busy' is already locked")
    }
  }

}
