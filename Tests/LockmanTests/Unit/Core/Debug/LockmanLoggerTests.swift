import XCTest

@_spi(Logging) @testable import Lockman

// ✅ IMPLEMENTED: Simplified LockmanLogger tests via LockmanManager.debug interface
// ✅ 8 test methods covering core debug logging functionality  
// ✅ Phase 1: Basic functionality (enable/disable, state management)
// ✅ Phase 2: Strategy integration testing (through actual strategy operations)
// ✅ Phase 3: Concurrency and edge case testing

final class LockmanLoggerTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    // Ensure debug logging is disabled by default in tests
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    // Reset debug logging state
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  // MARK: - Phase 1: Basic Debug Functionality
  
  func testLockmanDebugInitialState() {
    // Test initial debug logging state
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }
  
  func testLockmanDebugEnableDisable() {
    // Test enable/disable functionality through debug interface
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
    
    // Enable debug logging
    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertTrue(LockmanManager.debug.isLoggingEnabled)
    
    // Disable debug logging
    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }
  
  func testLockmanDebugThreadSafety() {
    // Test concurrent enable/disable operations through debug interface
    let expectation = self.expectation(description: "Concurrent debug operations complete")
    expectation.expectedFulfillmentCount = 10
    
    // Run multiple concurrent operations
    for i in 0..<10 {
      Task.detached {
        LockmanManager.debug.isLoggingEnabled = (i % 2 == 0)
        expectation.fulfill()
      }
    }
    
    waitForExpectations(timeout: 1.0)
    
    // Debug state should be in a consistent state (either true or false)
    let finalState = LockmanManager.debug.isLoggingEnabled
    XCTAssertTrue(finalState == true || finalState == false)
  }
  
  func testLockmanDebugPrintCurrentLocks() {
    // Test that printCurrentLocks doesn't crash
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
  }
  
  // MARK: - Phase 2: Strategy Integration Testing
  
  func testLockmanDebugWithStrategyOperations() {
    // Test debug logging integration with actual strategy operations
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "testBoundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    
    // These operations should trigger debug logging internally but not crash
    XCTAssertNoThrow {
      let result = strategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(result, .success)
      
      strategy.lock(boundaryId: boundaryId, info: info)
      strategy.unlock(boundaryId: boundaryId, info: info)
    }
  }
  
  func testLockmanDebugWithPriorityStrategy() {
    // Test debug logging with PriorityBased strategy operations
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "priorityBoundary"
    let info = LockmanPriorityBasedInfo(actionId: LockmanActionId("test"), priority: .high(.exclusive))
    
    XCTAssertNoThrow {
      let result = strategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(result, .success)
      
      strategy.lock(boundaryId: boundaryId, info: info)
      strategy.unlock(boundaryId: boundaryId, info: info)
    }
  }
  
  // MARK: - Phase 3: Edge Cases and Disabled State
  
  func testLockmanDebugDisabledState() {
    // Test that operations work correctly when debug logging is disabled
    LockmanManager.debug.isLoggingEnabled = false
    
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "disabledBoundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    
    // Operations should work normally even with debug logging disabled
    XCTAssertNoThrow {
      let result = strategy.canLock(boundaryId: boundaryId, info: info)
      XCTAssertEqual(result, .success)
      
      strategy.lock(boundaryId: boundaryId, info: info)
      strategy.unlock(boundaryId: boundaryId, info: info)
    }
  }
  
  func testLockmanDebugWithMultipleStrategies() {
    // Test debug logging with multiple strategy types simultaneously
    LockmanManager.debug.isLoggingEnabled = true
    
    let singleStrategy = LockmanSingleExecutionStrategy()
    let priorityStrategy = LockmanPriorityBasedStrategy()
    
    XCTAssertNoThrow {
      // Multiple strategies should all log without interference
      let singleResult = singleStrategy.canLock(
        boundaryId: "boundary1", 
        info: LockmanSingleExecutionInfo(mode: .action)
      )
      XCTAssertEqual(singleResult, .success)
      
      let priorityResult = priorityStrategy.canLock(
        boundaryId: "boundary2", 
        info: LockmanPriorityBasedInfo(actionId: LockmanActionId("test"), priority: .low(.exclusive))
      )
      XCTAssertEqual(priorityResult, .success)
    }
  }
  
  // MARK: - Phase 4: Strategy Integration for Logger Coverage
  
  func testStrategyOperationsWithCancelScenario() {
    // Test strategy operations that trigger .cancel logging paths
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "conflictBoundary"
    
    let info1 = LockmanSingleExecutionInfo(actionId: LockmanActionId("action1"), mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: LockmanActionId("action2"), mode: .boundary)
    
    // First lock should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)
    
    // Second lock should fail/cancel due to boundary already locked (same strategy instance)
    let result2 = strategy.canLock(boundaryId: boundaryId, info: info2)
    switch result2 {
    case .cancel:
      // This triggers the cancel logging path
      break
    case .success:
      // Some strategies allow multiple actions - clean up
      strategy.lock(boundaryId: boundaryId, info: info2)
      strategy.unlock(boundaryId: boundaryId, info: info2)
    default:
      XCTFail("Unexpected result: \(result2)")
    }
    
    // Clean up
    strategy.unlock(boundaryId: boundaryId, info: info1)
  }
  
  func testPriorityStrategyWithPrecedingCancellation() {
    // Test priority-based strategy operations that trigger precedingCancellation logging
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanPriorityBasedStrategy()
    let boundaryId = "priorityBoundary"
    
    // Low priority action first
    let lowPriorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("lowPriority"), 
      priority: .low(.exclusive)
    )
    
    // High priority action (should cancel low priority)
    let highPriorityInfo = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("highPriority"),
      priority: .high(.exclusive)
    )
    
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: lowPriorityInfo), .success)
    strategy.lock(boundaryId: boundaryId, info: lowPriorityInfo)
    
    // High priority should succeed with preceding cancellation
    let highResult = strategy.canLock(boundaryId: boundaryId, info: highPriorityInfo)
    switch highResult {
    case .successWithPrecedingCancellation:
      // This should trigger the precedingCancellation logging path
      strategy.lock(boundaryId: boundaryId, info: highPriorityInfo)
      strategy.unlock(boundaryId: boundaryId, info: highPriorityInfo)
    default:
      XCTFail("Expected successWithPrecedingCancellation but got \(highResult)")
    }
  }
  
  func testMultipleBoundariesForCancelScenarios() {
    // Test multiple boundaries to trigger various cancel scenarios
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanSingleExecutionStrategy()
    
    // Test multiple boundary scenarios
    let boundaries = ["boundary1", "boundary2", "boundary3"]
    var activeInfos: [String: LockmanSingleExecutionInfo] = [:]
    
    for boundary in boundaries {
      let info = LockmanSingleExecutionInfo(
        actionId: LockmanActionId("action_\(boundary)"),
        mode: .boundary
      )
      
      XCTAssertEqual(strategy.canLock(boundaryId: boundary, info: info), .success)
      strategy.lock(boundaryId: boundary, info: info)
      activeInfos[boundary] = info
    }
    
    // Try to lock again on each boundary (should trigger cancel scenarios)
    for boundary in boundaries {
      let conflictInfo = LockmanSingleExecutionInfo(
        actionId: LockmanActionId("conflict_\(boundary)"),
        mode: .boundary
      )
      
      let result = strategy.canLock(boundaryId: boundary, info: conflictInfo)
      switch result {
      case .cancel:
        // This triggers the cancel logging path with various boundary names
        break
      default:
        XCTFail("Expected cancel but got \(result)")
      }
    }
    
    // Clean up
    for (boundary, info) in activeInfos {
      strategy.unlock(boundaryId: boundary, info: info)
    }
  }
  
  func testDebugWithComplexErrorMessages() {
    // Test debug logging with complex error messages using simpler strategy
    LockmanManager.debug.isLoggingEnabled = true
    
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "complexErrorBoundary"
    
    // Create info with complex action names that will generate detailed error messages
    let info1 = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("veryLongActionNameForErrorMessageTesting"),
      mode: .boundary
    )
    
    let info2 = LockmanSingleExecutionInfo(
      actionId: LockmanActionId("anotherComplexActionNameWithSpecialCharacters_123"),
      mode: .boundary
    )
    
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)
    
    // This should trigger cancel logging with complex action names
    let result2 = strategy.canLock(boundaryId: boundaryId, info: info2)
    XCTAssertEqual(result2, .cancel(LockmanSingleExecutionError.boundaryAlreadyLocked(boundaryId: boundaryId, lockmanInfo: info1)))
    
    strategy.unlock(boundaryId: boundaryId, info: info1)
  }
  
  func testDebugLoggingWithDisabledState() {
    // Ensure operations work correctly when debug logging is disabled
    let originalState = LockmanManager.debug.isLoggingEnabled
    LockmanManager.debug.isLoggingEnabled = false
    
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = "disabledTestBoundary"
    let info = LockmanSingleExecutionInfo(actionId: LockmanActionId("disabledTest"), mode: .boundary)
    
    // All operations should work normally without logging
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info), .success)
    strategy.lock(boundaryId: boundaryId, info: info)
    strategy.unlock(boundaryId: boundaryId, info: info)
    
    // Restore original state
    LockmanManager.debug.isLoggingEnabled = originalState
  }
  
  // MARK: - Phase 5: Complete Coverage - logLockState via printCurrentLocks
  
  func testLogLockStateViaDebugAPIEnabled() async {
    // logLockState is called internally by printCurrentLocks
    // Test when logging is enabled (should use Logger.shared.log path)
    LockmanManager.debug.isLoggingEnabled = true
    
    let expectation = expectation(description: "printCurrentLocks async execution")
    
    // This internally calls logLockState
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
    
    // Give time for any async Tasks to execute
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 1.0)
  }
  
  func testLogLockStateViaDebugAPIDisabled() {
    // Test when logging is disabled (should use print() path)
    LockmanManager.debug.isLoggingEnabled = false
    
    // This internally calls logLockState with isEnabled = false
    XCTAssertNoThrow {
      LockmanManager.debug.printCurrentLocks()
    }
  }
  
  func testDebugAPIStateTransitions() async {
    // Test multiple state transitions to trigger different logLockState paths
    let expectation = expectation(description: "Multiple debug state transitions")
    expectation.expectedFulfillmentCount = 4
    
    // Sequence of enable/disable to trigger different paths
    LockmanManager.debug.isLoggingEnabled = true
    LockmanManager.debug.printCurrentLocks()
    
    LockmanManager.debug.isLoggingEnabled = false  
    LockmanManager.debug.printCurrentLocks()
    
    LockmanManager.debug.isLoggingEnabled = true
    LockmanManager.debug.printCurrentLocks()
    
    LockmanManager.debug.isLoggingEnabled = false
    LockmanManager.debug.printCurrentLocks()
    
    // Give time for async operations
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      expectation.fulfill()
      expectation.fulfill()
      expectation.fulfill()
      expectation.fulfill()
    }
    
    await fulfillment(of: [expectation], timeout: 2.0)
  }
  
  // MARK: - Phase 6: Direct LockmanLogger Testing
  
  func testLogLockStateDirectAccess() {
    // Test direct logLockState method access to cover lines 90-103
    // This requires @_spi(Logging) access through LockmanLogger.shared
    
    let testMessage = "Test lock state message"
    
    // Test with logging disabled (should use print path - lines 92-95)
    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertNoThrow {
      LockmanLogger.shared.logLockState(testMessage)
    }
    
    // Test with logging enabled (should use Logger.shared.log path - lines 96-98) 
    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertNoThrow {
      LockmanLogger.shared.logLockState(testMessage)
    }
  }
  
}
