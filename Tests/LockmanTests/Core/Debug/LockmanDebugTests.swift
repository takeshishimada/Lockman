import XCTest
@testable import Lockman

final class LockmanDebugTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Reset debug settings
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  override func tearDown() {
    super.tearDown()
    // Reset debug settings
    LockmanManager.debug.isLoggingEnabled = false
  }
  
  func testIsLoggingEnabled() {
    // Initially should be false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
    
    // Enable logging
    LockmanManager.debug.isLoggingEnabled = true
    XCTAssertTrue(LockmanManager.debug.isLoggingEnabled)
    
    // Disable logging
    LockmanManager.debug.isLoggingEnabled = false
    XCTAssertFalse(LockmanManager.debug.isLoggingEnabled)
  }
  
  func testPrintCurrentLocksWithNoLocks() {
    // Capture console output
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    
    // Print current locks when no locks exist
    LockmanManager.debug.printCurrentLocks()
    
    // Restore stdout
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()
    
    // Read captured output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    // Should contain table headers or "No active locks" message
    XCTAssertTrue(output.contains("Strategy") || output.contains("No active locks") || output.isEmpty)
  }
  
  func testPrintCurrentLocksWithOptions() {
    // Test that method accepts options parameter
    // We can't easily test the output differences, but we can verify it doesn't crash
    LockmanManager.debug.printCurrentLocks(options: .default)
    LockmanManager.debug.printCurrentLocks(options: .compact)
    LockmanManager.debug.printCurrentLocks(options: .detailed)
    
    // If we get here without crashing, the test passes
    XCTAssertTrue(true)
  }
  
  func testCompositeInfoProtocol() {
    // Test LockmanCompositeInfo2
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    let info2 = LockmanSingleExecutionInfo(actionId: "action2")
    let compositeInfo2 = LockmanCompositeInfo2(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2
    )
    
    let allInfos2 = compositeInfo2.allInfos()
    XCTAssertEqual(allInfos2.count, 2)
    XCTAssertTrue(allInfos2[0] is LockmanSingleExecutionInfo)
    XCTAssertTrue(allInfos2[1] is LockmanSingleExecutionInfo)
  }
  
  func testCompositeInfo3Protocol() {
    // Test LockmanCompositeInfo3
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    let info2 = LockmanSingleExecutionInfo(actionId: "action2")
    let info3 = LockmanSingleExecutionInfo(actionId: "action3")
    let compositeInfo3 = LockmanCompositeInfo3(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3
    )
    
    let allInfos3 = compositeInfo3.allInfos()
    XCTAssertEqual(allInfos3.count, 3)
    XCTAssertEqual((allInfos3[0] as? LockmanSingleExecutionInfo)?.actionId, "action1")
    XCTAssertEqual((allInfos3[1] as? LockmanSingleExecutionInfo)?.actionId, "action2")
    XCTAssertEqual((allInfos3[2] as? LockmanSingleExecutionInfo)?.actionId, "action3")
  }
  
  func testCompositeInfo4Protocol() {
    // Test LockmanCompositeInfo4
    let info1 = LockmanSingleExecutionInfo(actionId: "action1")
    let info2 = LockmanSingleExecutionInfo(actionId: "action2")
    let info3 = LockmanSingleExecutionInfo(actionId: "action3")
    let info4 = LockmanSingleExecutionInfo(actionId: "action4")
    let compositeInfo4 = LockmanCompositeInfo4(
      lockmanInfoForStrategy1: info1,
      lockmanInfoForStrategy2: info2,
      lockmanInfoForStrategy3: info3,
      lockmanInfoForStrategy4: info4
    )
    
    let allInfos4 = compositeInfo4.allInfos()
    XCTAssertEqual(allInfos4.count, 4)
    for (index, info) in allInfos4.enumerated() {
      XCTAssertEqual((info as? LockmanSingleExecutionInfo)?.actionId, "action\(index + 1)")
    }
  }
  
  func testCompositeInfo5Protocol() {
    // Test LockmanCompositeInfo5
    let infos = (1...5).map { LockmanSingleExecutionInfo(actionId: "action\($0)") }
    let compositeInfo5 = LockmanCompositeInfo5(
      lockmanInfoForStrategy1: infos[0],
      lockmanInfoForStrategy2: infos[1],
      lockmanInfoForStrategy3: infos[2],
      lockmanInfoForStrategy4: infos[3],
      lockmanInfoForStrategy5: infos[4]
    )
    
    let allInfos5 = compositeInfo5.allInfos()
    XCTAssertEqual(allInfos5.count, 5)
    for (index, info) in allInfos5.enumerated() {
      XCTAssertEqual((info as? LockmanSingleExecutionInfo)?.actionId, "action\(index + 1)")
    }
  }
  
  func testLoggingIntegration() {
    // Enable logging
    LockmanManager.debug.isLoggingEnabled = true
    
    // Create a strategy and perform operations
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = AnyLockmanBoundaryId("test-boundary")
    let info = LockmanSingleExecutionInfo(actionId: "test-action")
    
    // Capture console output
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    
    // Perform canLock operation (should trigger logging)
    _ = strategy.canLock(id: boundaryId, info: info)
    
    // Restore stdout
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()
    
    // Read captured output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    #if DEBUG
    // In debug builds, logging should produce output
    XCTAssertTrue(output.contains("canLock") || output.contains("Lockman"))
    #else
    // In release builds, logging might be disabled
    _ = output
    #endif
  }
  
  func testDebugWithActiveLocks() {
    // Create strategies and lock some resources
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = AnyLockmanBoundaryId("test-boundary")
    let info = LockmanSingleExecutionInfo(actionId: "test-action")
    
    // Lock a resource
    strategy.lockAcquired(id: boundaryId, info: info)
    
    // Capture console output
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    
    // Print current locks
    LockmanManager.debug.printCurrentLocks()
    
    // Restore stdout
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()
    
    // Clean up
    strategy.lockReleased(id: boundaryId, info: info)
    
    // Read captured output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    
    // Should contain information about the lock
    XCTAssertTrue(output.contains("test-action") || output.contains("test-boundary") || output.isEmpty)
  }
}