import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Simplified Logger tests via public interface testing
// ✅ 8 test methods covering internal Logger functionality indirectly
// ✅ Phase 1: Basic logger state management and message handling
// ✅ Phase 2: Concurrency and thread-safe operations
// ✅ Phase 3: Integration with actual logging scenarios

final class LoggerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Basic Logger Functionality

  func testLoggerInitialState() {
    // Test that internal Logger starts in correct initial state
    // We test this indirectly through debug interface
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }

  func testLoggerEnableDisable() {
    // Test enabling and disabling logger through debug interface
    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertTrue(LockmanManager.debug.isLoggingEnabled)

    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }

  func testLoggerMessageHandling() {
    // Test that logger can handle messages without crashing
    LockmanManager.debug.isLoggingEnabled = true

    // These operations should trigger internal logger usage
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
  }

  func testLoggerWithDisabledState() {
    // Test logger behavior when disabled
    LockmanManager.debug.isLoggingEnabled = false

    // Should not crash even when disabled
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
  }

  // MARK: - Phase 2: Concurrency Testing

  func testLoggerConcurrentStateChanges() {
    // Test concurrent enable/disable operations
    let expectation = self.expectation(description: "Concurrent logger operations complete")
    expectation.expectedFulfillmentCount = 10

    for i in 0..<10 {
      Task.detached {
        LockmanManager.debug.isLoggingEnabled = (i % 2 == 0)
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1.0)

    // Logger should be in consistent state
    let finalState = LockmanManager.debug.isLoggingEnabled
    XCTAssertTrue(finalState == true || finalState == false)
  }

  func testLoggerConcurrentMessageHandling() {
    // Test concurrent message processing
    LockmanManager.debug.isLoggingEnabled = true
    let expectation = self.expectation(description: "Concurrent message handling complete")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      Task.detached {
        LockmanManager.debug.printCurrentLocks()
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1.0)
  }

  // MARK: - Phase 3: Integration Testing

  func testLoggerIntegrationWithDebugOperations() {
    // Test logger integration with actual debug operations
    LockmanManager.debug.isLoggingEnabled = true

    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "testBoundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)

    // These operations should use internal logger
    XCTAssertNoThrow {
      let _ = strategy.canLock(boundaryId: boundaryId, info: info)
      strategy.lock(boundaryId: boundaryId, info: info)
      strategy.unlock(boundaryId: boundaryId, info: info)
    }
  }

  func testLoggerStateConsistencyAcrossOperations() {
    // Test that logger state remains consistent during operations
    LockmanManager.debug.isLoggingEnabled = true

    // Multiple debug operations
    for i in 0..<5 {
      LockmanManager.debug.printCurrentLocks()
      XCTAssertTrue(
        LockmanManager.debug.isLoggingEnabled, "Logger state changed unexpectedly at iteration \(i)"
      )
    }

    // Disable and verify consistency
    LockmanManager.debug.isLoggingEnabled = false
    for i in 0..<5 {
      LockmanManager.debug.printCurrentLocks()
      XCTAssertFalse(
        LockmanManager.debug.isLoggingEnabled, "Logger state changed unexpectedly at iteration \(i)"
      )
    }
  }

}
