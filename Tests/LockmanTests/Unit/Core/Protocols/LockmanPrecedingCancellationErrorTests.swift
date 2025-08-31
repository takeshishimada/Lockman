import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive protocol tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanPrecedingCancellationErrorTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Error Types for Protocol Conformance

  private struct TestLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let priority: String

    init(
      strategyId: LockmanStrategyId = "TestStrategy", actionId: LockmanActionId = "testAction",
      priority: String = "high"
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.priority = priority
    }

    var debugDescription: String {
      "TestLockmanInfo(actionId: '\(actionId)', priority: '\(priority)')"
    }

    var debugAdditionalInfo: String {
      "priority: \(priority)"
    }
  }

  private struct TestPrecedingCancellationError: LockmanPrecedingCancellationError {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let reason: String

    init(
      lockmanInfo: any LockmanInfo, boundaryId: any LockmanBoundaryId, reason: String = "precedence"
    ) {
      self.lockmanInfo = lockmanInfo
      self.boundaryId = boundaryId
      self.reason = reason
    }

    var errorDescription: String? {
      "Preceding action cancelled: \(reason) (action: \(lockmanInfo.actionId))"
    }
  }

  private enum TestEnumPrecedingCancellationError: LockmanPrecedingCancellationError {
    case priorityPreemption(info: any LockmanInfo, boundary: any LockmanBoundaryId)
    case concurrencyLimit(info: any LockmanInfo, boundary: any LockmanBoundaryId)
    case strategySpecific(info: any LockmanInfo, boundary: any LockmanBoundaryId, details: String)

    var lockmanInfo: any LockmanInfo {
      switch self {
      case .priorityPreemption(let info, _):
        return info
      case .concurrencyLimit(let info, _):
        return info
      case .strategySpecific(let info, _, _):
        return info
      }
    }

    var boundaryId: any LockmanBoundaryId {
      switch self {
      case .priorityPreemption(_, let boundary):
        return boundary
      case .concurrencyLimit(_, let boundary):
        return boundary
      case .strategySpecific(_, let boundary, _):
        return boundary
      }
    }

    var errorDescription: String? {
      switch self {
      case .priorityPreemption(let info, _):
        return "Priority preemption cancelled action: \(info.actionId)"
      case .concurrencyLimit(let info, _):
        return "Concurrency limit cancelled action: \(info.actionId)"
      case .strategySpecific(let info, _, let details):
        return "Strategy-specific cancellation of action \(info.actionId): \(details)"
      }
    }
  }

  private final class TestClassPrecedingCancellationError: LockmanPrecedingCancellationError {
    let lockmanInfo: any LockmanInfo
    let boundaryId: any LockmanBoundaryId
    let timestamp: Date

    init(lockmanInfo: any LockmanInfo, boundaryId: any LockmanBoundaryId, timestamp: Date = Date())
    {
      self.lockmanInfo = lockmanInfo
      self.boundaryId = boundaryId
      self.timestamp = timestamp
    }

    var errorDescription: String? {
      "Class-based preceding cancellation at \(timestamp) for action \(lockmanInfo.actionId)"
    }
  }

  // MARK: - Phase 1: Basic Protocol Conformance

  func testLockmanPrecedingCancellationErrorProtocolHierarchy() {
    // Test protocol hierarchy: LockmanPrecedingCancellationError -> LockmanStrategyError -> LockmanError
    let info = TestLockmanInfo(actionId: "hierarchyTest")
    let boundary = "testBoundary"
    let error: any LockmanPrecedingCancellationError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: boundary)

    // Should conform to parent protocols
    XCTAssertNotNil(error as any LockmanStrategyError)
    XCTAssertNotNil(error as any LockmanError)
    XCTAssertNotNil(error as any Error)
    XCTAssertNotNil(error as any LocalizedError)
  }

  func testLockmanPrecedingCancellationErrorRequiredProperties() {
    // Test required properties are accessible
    let info = TestLockmanInfo(actionId: "propertyTest", priority: "medium")
    let boundary = "propertyBoundary"
    let error = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: boundary, reason: "test reason")

    // Test lockmanInfo property
    XCTAssertEqual(error.lockmanInfo.actionId, "propertyTest")
    if let testInfo = error.lockmanInfo as? TestLockmanInfo {
      XCTAssertEqual(testInfo.priority, "medium")
    } else {
      XCTFail("Should be able to cast to TestLockmanInfo")
    }

    // Test boundaryId property
    if let stringBoundary = error.boundaryId as? String {
      XCTAssertEqual(stringBoundary, "propertyBoundary")
    } else {
      XCTFail("Should be able to cast boundaryId to String")
    }

    // Test error description
    XCTAssertEqual(
      error.errorDescription, "Preceding action cancelled: test reason (action: propertyTest)")
  }

  func testLockmanPrecedingCancellationErrorStructConformance() {
    // Test struct conforming to protocol
    let info = TestLockmanInfo(actionId: "structTest")
    let error = TestPrecedingCancellationError(lockmanInfo: info, boundaryId: "structBoundary")

    XCTAssertEqual(error.lockmanInfo.actionId, "structTest")
    XCTAssertNotNil(error.errorDescription)
    XCTAssertTrue(error.errorDescription!.contains("structTest"))
  }

  func testLockmanPrecedingCancellationErrorEnumConformance() {
    // Test enum conforming to protocol
    let info = TestLockmanInfo(actionId: "enumTest")
    let boundary = UUID()
    let error = TestEnumPrecedingCancellationError.priorityPreemption(
      info: info, boundary: boundary)

    XCTAssertEqual(error.lockmanInfo.actionId, "enumTest")
    if let uuidBoundary = error.boundaryId as? UUID {
      XCTAssertEqual(uuidBoundary, boundary)
    }
    XCTAssertEqual(error.errorDescription, "Priority preemption cancelled action: enumTest")
  }

  func testLockmanPrecedingCancellationErrorClassConformance() {
    // Test class conforming to protocol
    let info = TestLockmanInfo(actionId: "classTest")
    let boundary = 42
    let timestamp = Date()
    let error = TestClassPrecedingCancellationError(
      lockmanInfo: info, boundaryId: boundary, timestamp: timestamp)

    XCTAssertEqual(error.lockmanInfo.actionId, "classTest")
    if let intBoundary = error.boundaryId as? Int {
      XCTAssertEqual(intBoundary, 42)
    }
    XCTAssertTrue(error.errorDescription!.contains("classTest"))
  }

  // MARK: - Phase 2: Protocol Inheritance and Error Handling

  func testLockmanPrecedingCancellationErrorAsLockmanStrategyError() {
    // Test access through parent protocol
    let info = TestLockmanInfo(actionId: "strategyErrorTest")
    let boundary = "strategyBoundary"
    let precedingError: any LockmanPrecedingCancellationError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: boundary)
    let strategyError: any LockmanStrategyError = precedingError

    // Should have same properties through parent protocol
    XCTAssertEqual(strategyError.lockmanInfo.actionId, "strategyErrorTest")
    if let stringBoundary = strategyError.boundaryId as? String {
      XCTAssertEqual(stringBoundary, "strategyBoundary")
    }
  }

  func testLockmanPrecedingCancellationErrorAsLockmanError() {
    // Test access through root protocol
    let info = TestLockmanInfo(actionId: "lockmanErrorTest")
    let precedingError: any LockmanPrecedingCancellationError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: "rootBoundary")
    let lockmanError: any LockmanError = precedingError

    // Should be accessible as LockmanError
    XCTAssertNotNil(lockmanError.errorDescription)
    XCTAssertTrue(lockmanError.errorDescription!.contains("lockmanErrorTest"))
  }

  func testLockmanPrecedingCancellationErrorAsStandardError() {
    // Test usage as standard Swift Error
    let info = TestLockmanInfo(actionId: "standardErrorTest")
    let precedingError: any LockmanPrecedingCancellationError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: "errorBoundary")

    func handleError(_ error: any Error) -> String {
      if let precedingCancelError = error as? any LockmanPrecedingCancellationError {
        return "Preceding cancellation: \(precedingCancelError.lockmanInfo.actionId)"
      }
      return "Unknown error"
    }

    let result = handleError(precedingError)
    XCTAssertEqual(result, "Preceding cancellation: standardErrorTest")
  }

  func testLockmanPrecedingCancellationErrorResultPattern() {
    // Test usage in Result pattern
    let info = TestLockmanInfo(actionId: "resultTest")
    let error = TestEnumPrecedingCancellationError.concurrencyLimit(
      info: info, boundary: "resultBoundary")

    let result: Result<String, TestEnumPrecedingCancellationError> = .failure(error)

    switch result {
    case .success:
      XCTFail("Should be failure")
    case .failure(let error):
      XCTAssertEqual(error.lockmanInfo.actionId, "resultTest")
      XCTAssertEqual(error.errorDescription, "Concurrency limit cancelled action: resultTest")
    }
  }

  // MARK: - Phase 3: Type Erasure and Generic Usage

  func testLockmanPrecedingCancellationErrorTypeErasure() {
    // Test different error types in collection
    let info1 = TestLockmanInfo(actionId: "error1")
    let info2 = TestLockmanInfo(actionId: "error2")
    let info3 = TestLockmanInfo(actionId: "error3")

    let errors: [any LockmanPrecedingCancellationError] = [
      TestPrecedingCancellationError(lockmanInfo: info1, boundaryId: "boundary1"),
      TestEnumPrecedingCancellationError.strategySpecific(
        info: info2, boundary: "boundary2", details: "custom"),
      TestClassPrecedingCancellationError(lockmanInfo: info3, boundaryId: "boundary3"),
    ]

    XCTAssertEqual(errors.count, 3)

    // Test processing through type erasure
    let actionIds = errors.map { $0.lockmanInfo.actionId }
    XCTAssertTrue(actionIds.contains("error1"))
    XCTAssertTrue(actionIds.contains("error2"))
    XCTAssertTrue(actionIds.contains("error3"))
  }

  func testLockmanPrecedingCancellationErrorGenericFunction() {
    // Test generic function using the protocol
    func processError<E: LockmanPrecedingCancellationError>(_ error: E) -> String {
      return "Processing \(error.lockmanInfo.actionId) at boundary \(error.boundaryId)"
    }

    let info = TestLockmanInfo(actionId: "genericTest")
    let structError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: "genericBoundary")
    let enumError = TestEnumPrecedingCancellationError.priorityPreemption(
      info: info, boundary: "enumBoundary")

    let structResult = processError(structError)
    let enumResult = processError(enumError)

    XCTAssertEqual(structResult, "Processing genericTest at boundary genericBoundary")
    XCTAssertEqual(enumResult, "Processing genericTest at boundary enumBoundary")
  }

  func testLockmanPrecedingCancellationErrorBoundaryIdTypes() {
    // Test different boundary ID types
    let info = TestLockmanInfo(actionId: "boundaryTest")

    let stringError = TestPrecedingCancellationError(
      lockmanInfo: info, boundaryId: "stringBoundary")
    let uuidError = TestPrecedingCancellationError(lockmanInfo: info, boundaryId: UUID())
    let intError = TestPrecedingCancellationError(lockmanInfo: info, boundaryId: 123)

    XCTAssertTrue(stringError.boundaryId is String)
    XCTAssertTrue(uuidError.boundaryId is UUID)
    XCTAssertTrue(intError.boundaryId is Int)

    // All should have same action ID
    XCTAssertEqual(stringError.lockmanInfo.actionId, "boundaryTest")
    XCTAssertEqual(uuidError.lockmanInfo.actionId, "boundaryTest")
    XCTAssertEqual(intError.lockmanInfo.actionId, "boundaryTest")
  }

  // MARK: - Phase 4: Real-world Usage Patterns

  func testLockmanPrecedingCancellationErrorUnlockPattern() {
    // Test unlock pattern from documentation
    let cancelledInfo = TestLockmanInfo(actionId: "cancelledAction", priority: "medium")
    let boundaryId = "unlockBoundary"
    let error = TestPrecedingCancellationError(lockmanInfo: cancelledInfo, boundaryId: boundaryId)

    // Simulate the unlock pattern from documentation
    func simulateUnlockPattern(error: any Error) -> Bool {
      if let cancellationError = error as? any LockmanPrecedingCancellationError,
        let cancelledInfo = cancellationError.lockmanInfo as? TestLockmanInfo
      {
        // This would normally call strategy.unlock(boundaryId: cancellationError.boundaryId, info: cancelledInfo)
        return true
      }
      return false
    }

    let unlockSuccess = simulateUnlockPattern(error: error)
    XCTAssertTrue(unlockSuccess)
  }

  func testLockmanPrecedingCancellationErrorSuccessWithPrecedingCancellationPattern() {
    // Test usage in successWithPrecedingCancellation scenario
    enum MockLockmanResult {
      case success
      case successWithPrecedingCancellation(any Error)
      case cancel(any Error)
    }

    let precedingInfo = TestLockmanInfo(actionId: "precedingAction")
    let error = TestEnumPrecedingCancellationError.priorityPreemption(
      info: precedingInfo, boundary: "precedingBoundary")
    let result = MockLockmanResult.successWithPrecedingCancellation(error)

    switch result {
    case .successWithPrecedingCancellation(let error):
      if let cancellationError = error as? any LockmanPrecedingCancellationError {
        XCTAssertEqual(cancellationError.lockmanInfo.actionId, "precedingAction")
        XCTAssertTrue(cancellationError.boundaryId is String)
      } else {
        XCTFail("Error should be LockmanPrecedingCancellationError")
      }
    default:
      XCTFail("Should be successWithPrecedingCancellation")
    }
  }

  func testLockmanPrecedingCancellationErrorMultipleInfoTypes() {
    // Test with different LockmanInfo implementations
    struct CustomInfo: LockmanInfo {
      let strategyId: LockmanStrategyId
      let actionId: LockmanActionId
      let uniqueId: UUID
      let customData: [String: Any]

      init(actionId: LockmanActionId, customData: [String: Any] = [:]) {
        self.strategyId = "CustomStrategy"
        self.actionId = actionId
        self.uniqueId = UUID()
        self.customData = customData
      }

      var debugDescription: String {
        "CustomInfo(actionId: \(actionId))"
      }
    }

    let customInfo = CustomInfo(
      actionId: "customAction", customData: ["priority": "high", "timeout": 30])
    let error = TestPrecedingCancellationError(
      lockmanInfo: customInfo, boundaryId: "customBoundary")

    XCTAssertEqual(error.lockmanInfo.actionId, "customAction")
    if let customInfoCast = error.lockmanInfo as? CustomInfo {
      XCTAssertEqual(customInfoCast.customData["priority"] as? String, "high")
    }
  }

  func testLockmanPrecedingCancellationErrorErrorHandlingChain() {
    // Test error handling chain through protocol hierarchy
    let info = TestLockmanInfo(actionId: "chainTest")
    let error = TestClassPrecedingCancellationError(lockmanInfo: info, boundaryId: "chainBoundary")

    var handledBy: [String] = []

    // Handle as specific type
    if let specificError = error as? TestClassPrecedingCancellationError {
      handledBy.append("TestClassPrecedingCancellationError")
      XCTAssertNotNil(specificError.timestamp)
    }

    // Handle as protocol type
    if let protocolError = error as? any LockmanPrecedingCancellationError {
      handledBy.append("LockmanPrecedingCancellationError")
      XCTAssertEqual(protocolError.lockmanInfo.actionId, "chainTest")
    }

    // Handle as parent protocol
    if let strategyError = error as? any LockmanStrategyError {
      handledBy.append("LockmanStrategyError")
      XCTAssertNotNil(strategyError.boundaryId)
    }

    // Handle as root protocol
    if let lockmanError = error as? any LockmanError {
      handledBy.append("LockmanError")
      XCTAssertNotNil(lockmanError.errorDescription)
    }

    XCTAssertEqual(handledBy.count, 4)
    XCTAssertTrue(handledBy.contains("TestClassPrecedingCancellationError"))
    XCTAssertTrue(handledBy.contains("LockmanPrecedingCancellationError"))
    XCTAssertTrue(handledBy.contains("LockmanStrategyError"))
    XCTAssertTrue(handledBy.contains("LockmanError"))
  }

}
