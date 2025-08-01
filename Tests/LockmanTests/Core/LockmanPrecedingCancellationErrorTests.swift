import XCTest

@testable import Lockman

// MARK: - LockmanPrecedingCancellationError Protocol Tests

final class LockmanPrecedingCancellationErrorTests: XCTestCase {

  // MARK: - LockmanPriorityBasedError Protocol Conformance Tests

  func testLockmanPriorityBasedError_ConformsToProtocol() {
    // Test that LockmanPriorityBasedError conforms to LockmanPrecedingCancellationError
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "testAction",
      priority: .high(.exclusive)
    )
    let boundaryId = TestBoundaryId("testBoundary")

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: cancelledInfo,
      boundaryId: boundaryId
    )

    // Protocol conformance check
    XCTAssertTrue(error is any LockmanPrecedingCancellationError)

    // Cast to protocol and verify properties
    let protocolError = error as any LockmanPrecedingCancellationError
    XCTAssertEqual(protocolError.lockmanInfo.actionId, "testAction")
    XCTAssertEqual(
      String(describing: protocolError.boundaryId), "TestBoundaryId(value: \"testBoundary\")")
  }

  func testLockmanPriorityBasedError_PrecedingActionCancelled_LockmanInfo() {
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "cancelledAction",
      priority: LockmanPriorityBasedInfo.Priority.low(.replaceable)
    )
    let boundaryId = TestBoundaryId("boundary123")

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: cancelledInfo,
      boundaryId: boundaryId
    )

    // Test lockmanInfo property
    let retrievedInfo = error.lockmanInfo
    XCTAssertEqual(retrievedInfo.actionId, "cancelledAction")

    // Test type casting
    guard let priorityInfo = retrievedInfo as? LockmanPriorityBasedInfo else {
      XCTFail("lockmanInfo should be castable to LockmanPriorityBasedInfo")
      return
    }
    XCTAssertEqual(priorityInfo.priority, LockmanPriorityBasedInfo.Priority.low(.replaceable))
  }

  func testLockmanPriorityBasedError_PrecedingActionCancelled_BoundaryId() {
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "testAction",
      priority: .high(.exclusive)
    )
    let boundaryId = TestBoundaryId("uniqueBoundary")

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: cancelledInfo,
      boundaryId: boundaryId
    )

    // Test boundaryId property
    XCTAssertEqual(
      String(describing: error.boundaryId), "TestBoundaryId(value: \"uniqueBoundary\")")
  }

  func testLockmanPriorityBasedError_HigherPriorityExists_LockmanInfo() {
    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: "requestedAction",
      priority: LockmanPriorityBasedInfo.Priority.low(.exclusive)
    )
    let existingInfo = LockmanPriorityBasedInfo(
      actionId: "existingAction",
      priority: .high(.exclusive)
    )
    let boundaryId = TestBoundaryId("testBoundary")

    let error = LockmanPriorityBasedError.higherPriorityExists(
      requestedInfo: requestedInfo,
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    // Test lockmanInfo property returns requestedInfo
    let retrievedInfo = error.lockmanInfo
    XCTAssertEqual(retrievedInfo.actionId, "requestedAction")

    // Test type casting
    guard let priorityInfo = retrievedInfo as? LockmanPriorityBasedInfo else {
      XCTFail("lockmanInfo should be castable to LockmanPriorityBasedInfo")
      return
    }
    XCTAssertEqual(priorityInfo.priority, LockmanPriorityBasedInfo.Priority.low(.exclusive))
  }

  func testLockmanPriorityBasedError_SamePriorityConflict_LockmanInfo() {
    let requestedInfo = LockmanPriorityBasedInfo(
      actionId: "requestedAction",
      priority: LockmanPriorityBasedInfo.Priority.low(.exclusive)
    )
    let existingInfo = LockmanPriorityBasedInfo(
      actionId: "existingAction",
      priority: LockmanPriorityBasedInfo.Priority.low(.exclusive)
    )
    let boundaryId = TestBoundaryId("testBoundary")

    let error = LockmanPriorityBasedError.samePriorityConflict(
      requestedInfo: requestedInfo,
      lockmanInfo: existingInfo,
      boundaryId: boundaryId
    )

    // Test lockmanInfo property returns requestedInfo
    let retrievedInfo = error.lockmanInfo
    XCTAssertEqual(retrievedInfo.actionId, "requestedAction")

    // Test type casting
    guard let priorityInfo = retrievedInfo as? LockmanPriorityBasedInfo else {
      XCTFail("lockmanInfo should be castable to LockmanPriorityBasedInfo")
      return
    }
    XCTAssertEqual(priorityInfo.priority, LockmanPriorityBasedInfo.Priority.low(.exclusive))
  }

  // MARK: - LockmanResult Integration Tests

  func testLockmanResult_SuccessWithPrecedingCancellation_TypeSafety() {
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "cancelledAction",
      priority: LockmanPriorityBasedInfo.Priority.low(.exclusive)
    )
    let boundaryId = TestBoundaryId("testBoundary")

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: cancelledInfo,
      boundaryId: boundaryId
    )

    // Test LockmanResult with type-safe error
    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    // Pattern matching test
    switch result {
    case .successWithPrecedingCancellation(let cancellationError):
      XCTAssertEqual(cancellationError.lockmanInfo.actionId, "cancelledAction")
      XCTAssertEqual(
        String(describing: cancellationError.boundaryId), "TestBoundaryId(value: \"testBoundary\")")
    default:
      XCTFail("Result should be successWithPrecedingCancellation")
    }
  }

  func testLockmanResult_SuccessWithPrecedingCancellation_DirectAccess() {
    let cancelledInfo = LockmanPriorityBasedInfo(
      actionId: "directAccessTest",
      priority: LockmanPriorityBasedInfo.Priority.high(.replaceable)
    )
    let boundaryId = TestBoundaryId("directBoundary")

    let error = LockmanPriorityBasedError.precedingActionCancelled(
      lockmanInfo: cancelledInfo,
      boundaryId: boundaryId
    )

    let result = LockmanResult.successWithPrecedingCancellation(error: error)

    // Test direct access without helper functions
    if case .successWithPrecedingCancellation(let cancellationError) = result {
      // Direct access to properties
      XCTAssertEqual(cancellationError.lockmanInfo.actionId, "directAccessTest")
      XCTAssertEqual(
        String(describing: cancellationError.boundaryId),
        "TestBoundaryId(value: \"directBoundary\")")

      // Type casting for specific info
      guard let priorityInfo = cancellationError.lockmanInfo as? LockmanPriorityBasedInfo else {
        XCTFail("Should be able to cast to LockmanPriorityBasedInfo")
        return
      }
      XCTAssertEqual(priorityInfo.priority, LockmanPriorityBasedInfo.Priority.high(.replaceable))
    } else {
      XCTFail("Result should be successWithPrecedingCancellation")
    }
  }

  // MARK: - Test Helper

  struct TestBoundaryId: LockmanBoundaryId {
    let value: String

    init(_ value: String) {
      self.value = value
    }

    var description: String {
      return value
    }
  }
}
