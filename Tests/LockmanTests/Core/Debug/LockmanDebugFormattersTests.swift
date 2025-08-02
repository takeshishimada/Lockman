import Foundation
import XCTest

@testable @_spi(Debugging) import Lockman

final class LockmanDebugFormattersTests: XCTestCase {
  func testDynamicColumnWidth() throws {
    // Clean up first
    LockmanManager.cleanup.all()

    // Try to register strategies (ignore if already registered)
    _ = try? LockmanManager.container.register(LockmanSingleExecutionStrategy.shared)
    _ = try? LockmanManager.container.register(LockmanPriorityBasedStrategy.shared)

    // Test with SingleExecution (short name) but long action ID
    let singleInfo = LockmanSingleExecutionInfo(
      actionId: "veryLongActionIdForTestingDynamicColumnWidth",
      mode: .boundary
    )

    // Test with PriorityBased (longer strategy name)
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: "incrementButtonTapped",
      priority: .high(.exclusive)
    )

    let shortBoundaryId = "CancelID.userAction"
    let longBoundaryId = "VeryLongBoundaryIdForTestingColumnWidth"

    // Lock with both strategies
    _ = LockmanSingleExecutionStrategy.shared.canLock(boundaryId: longBoundaryId, info: singleInfo)
    LockmanSingleExecutionStrategy.shared.lock(boundaryId: longBoundaryId, info: singleInfo)

    _ = LockmanPriorityBasedStrategy.shared.canLock(boundaryId: shortBoundaryId, info: priorityInfo)
    LockmanPriorityBasedStrategy.shared.lock(boundaryId: shortBoundaryId, info: priorityInfo)

    // Capture output
    let originalStdout = dup(STDOUT_FILENO)
    let pipe = Pipe()
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    // Print with compact options
    LockmanManager.debug.printCurrentLocks(options: .compact)

    // Restore stdout and read output
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    print("Debug output:")
    print(output)

    // Verify no truncation
    XCTAssertTrue(output.contains("PriorityBased"))  // Not truncated
    XCTAssertTrue(output.contains("priority: high(.exclusive)"))  // Not truncated
    XCTAssertTrue(output.contains("SingleExecution"))
    XCTAssertTrue(output.contains("veryLongActionIdForTestingDynamicColumnWidth"))
    XCTAssertTrue(output.contains("VeryLongBoundaryIdForTestingColumnWidth"))

    // Clean up
    LockmanManager.cleanup.all()
  }

  func testFormatOptions() {
    // Test compact options
    let compact = LockmanManager.debug.FormatOptions.compact
    XCTAssertEqual(compact.maxStrategyWidth, 0)
    XCTAssertEqual(compact.maxBoundaryWidth, 0)
    XCTAssertEqual(compact.maxActionIdWidth, 0)
    XCTAssertEqual(compact.maxAdditionalWidth, 0)

    // Test default options
    let defaultOptions = LockmanManager.debug.FormatOptions.default
    XCTAssertEqual(defaultOptions.maxStrategyWidth, 20)
    XCTAssertEqual(defaultOptions.maxBoundaryWidth, 25)
    XCTAssertEqual(defaultOptions.maxActionIdWidth, 36)
    XCTAssertEqual(defaultOptions.maxAdditionalWidth, 20)
  }
}
