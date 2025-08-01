import XCTest

@testable @_spi(Logging) @_spi(Debugging) import Lockman

final class DebugTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clean up before each test
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    // Clean up after each test
    LockmanManager.cleanup.all()
    // Disable logging
    LockmanManager.debug.isLoggingEnabled = false
  }

  func testDebugLoggingEnableDisable() {
    // Test that logging can be enabled and disabled
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)

    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertTrue(LockmanManager.debug.isLoggingEnabled)

    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }

  func testPrintCurrentLocksWithNoLocks() {
    // Test that printCurrentLocks works with no active locks
    // This should not crash and should print "No active locks"
    LockmanManager.debug.printCurrentLocks()
  }

  func testPrintCurrentLocksWithActiveLocks() {
    // Create some locks
    let strategy = LockmanSingleExecutionStrategy.shared
    let boundaryId = TestBoundaryId.test
    let info1 = LockmanSingleExecutionInfo(actionId: "testAction1", mode: .boundary)

    // Acquire locks
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // This should print a table with the active lock
    LockmanManager.debug.printCurrentLocks()

    // Clean up
    strategy.unlock(boundaryId: boundaryId, info: info1)
  }

  func testDebugDescriptionForAllInfoTypes() {
    // Test that all info types have proper debug descriptions
    let singleExecInfo = LockmanSingleExecutionInfo(actionId: "testAction", mode: .boundary)
    XCTAssertTrue(singleExecInfo.debugDescription.contains("LockmanSingleExecutionInfo"))
    XCTAssertTrue(singleExecInfo.debugDescription.contains("testAction"))
    XCTAssertTrue(singleExecInfo.debugDescription.contains("boundary"))

    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "priorityAction",
      priority: .high(.exclusive)
    )
    XCTAssertTrue(priorityInfo.debugDescription.contains("LockmanPriorityBasedInfo"))
    XCTAssertTrue(priorityInfo.debugDescription.contains("priorityAction"))
    XCTAssertTrue(priorityInfo.debugDescription.contains("high"))

    let concurrencyInfo = LockmanConcurrencyLimitedInfo(
      actionId: "concurrencyAction",
      .limited(3)
    )
    XCTAssertTrue(concurrencyInfo.debugDescription.contains("ConcurrencyLimitedInfo"))
    XCTAssertTrue(concurrencyInfo.debugDescription.contains("concurrencyAction"))

    let groupInfo = LockmanGroupCoordinatedInfo(
      actionId: "groupAction",
      groupIds: ["group1", "group2"],
      coordinationRole: .none
    )
    XCTAssertTrue(groupInfo.debugDescription.contains("LockmanGroupCoordinatedInfo"))
    XCTAssertTrue(groupInfo.debugDescription.contains("groupAction"))
    XCTAssertTrue(groupInfo.debugDescription.contains("group1"))
    XCTAssertTrue(groupInfo.debugDescription.contains("none"))
  }

  func testGetCurrentLocksForAllStrategies() {
    // Test that getCurrentLocks works for all strategy types
    let strategies: [any LockmanStrategy] = [
      LockmanSingleExecutionStrategy.shared,
      LockmanPriorityBasedStrategy.shared,
      LockmanConcurrencyLimitedStrategy.shared,
      LockmanGroupCoordinationStrategy.shared,
    ]

    for (index, strategy) in strategies.enumerated() {
      // Get current locks (should be empty)
      let currentLocks = strategy.getCurrentLocks()
      XCTAssertTrue(currentLocks.isEmpty, "Strategy \(index) should have no locks initially")
    }
  }
}

// Helper boundary ID for testing
private enum TestBoundaryId: LockmanBoundaryId {
  case test
}
