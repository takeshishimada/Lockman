import XCTest
@testable @_spi(Logging) @_spi(Debugging) import LockmanCore

final class DebugTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Clean up before each test
    Lockman.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    // Clean up after each test
    Lockman.cleanup.all()
    // Disable logging
    Lockman.debug.isLoggingEnabled = false
  }

  func testDebugLoggingEnableDisable() {
    // Test that logging can be enabled and disabled
    XCTAssertFalse(Lockman.debug.isLoggingEnabled)

    Lockman.debug.isLoggingEnabled = true
    XCTAssertTrue(Lockman.debug.isLoggingEnabled)

    Lockman.debug.isLoggingEnabled = false
    XCTAssertFalse(Lockman.debug.isLoggingEnabled)
  }

  func testPrintCurrentLocksWithNoLocks() {
    // Test that printCurrentLocks works with no active locks
    // This should not crash and should print "No active locks"
    Lockman.debug.printCurrentLocks()
  }

  func testPrintCurrentLocksWithActiveLocks() {
    // Create some locks
    let strategy = LockmanSingleExecutionStrategy.shared
    let boundaryId = TestBoundaryId.test
    let info1 = LockmanSingleExecutionInfo(actionId: "testAction1", mode: .boundary)

    // Acquire locks
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: info1), .success)
    strategy.lock(id: boundaryId, info: info1)

    // This should print a table with the active lock
    Lockman.debug.printCurrentLocks()

    // Clean up
    strategy.unlock(id: boundaryId, info: info1)
  }

  func testDebugDescriptionForAllInfoTypes() {
    // Test that all info types have proper debug descriptions
    let singleExecInfo  = LockmanSingleExecutionInfo(actionId: "testAction", mode: .boundary)
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

    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: "dynamicAction",
      condition: { true }
    )
    XCTAssertTrue(dynamicInfo.debugDescription.contains("LockmanDynamicConditionInfo"))
    XCTAssertTrue(dynamicInfo.debugDescription.contains("dynamicAction"))

    let groupInfo = LockmanGroupCoordinatedInfo(
      actionId: "groupAction",
      groupIds: ["group1", "group2"],
      coordinationRole: .leader(.none)
    )
    XCTAssertTrue(groupInfo.debugDescription.contains("LockmanGroupCoordinatedInfo"))
    XCTAssertTrue(groupInfo.debugDescription.contains("groupAction"))
    XCTAssertTrue(groupInfo.debugDescription.contains("group1"))
    XCTAssertTrue(groupInfo.debugDescription.contains("leader"))
  }

  func testGetCurrentLocksForAllStrategies() {
    // Test that getCurrentLocks works for all strategy types
    let strategies: [any LockmanStrategy] = [
      LockmanSingleExecutionStrategy.shared,
      LockmanPriorityBasedStrategy.shared,
      LockmanDynamicConditionStrategy.shared,
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
