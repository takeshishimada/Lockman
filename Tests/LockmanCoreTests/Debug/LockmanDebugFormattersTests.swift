import Foundation
import XCTest

@testable @_spi(Debugging) import LockmanCore

final class LockmanDebugFormattersTests: XCTestCase {
  func testDynamicColumnWidth() throws {
    // Clean up first
    Lockman.cleanup.all()

    // Try to register strategies (ignore if already registered)
    _ = try? Lockman.container.register(LockmanDynamicConditionStrategy.shared)
    _ = try? Lockman.container.register(LockmanSingleExecutionStrategy.shared)

    // Test with DynamicConditionStrategy (long strategy name)
    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: "incrementButtonTapped",
      condition: { .success }
    )

    // Test with SingleExecution (short name) but long action ID
    let singleInfo = LockmanSingleExecutionInfo(
      actionId: "veryLongActionIdForTestingDynamicColumnWidth",
      mode: .boundary
    )

    let shortBoundaryId = "CancelID.userAction"
    let longBoundaryId = "VeryLongBoundaryIdForTestingColumnWidth"

    // Lock with both strategies
    _ = LockmanDynamicConditionStrategy.shared.canLock(id: shortBoundaryId, info: dynamicInfo)
    LockmanDynamicConditionStrategy.shared.lock(id: shortBoundaryId, info: dynamicInfo)

    _ = LockmanSingleExecutionStrategy.shared.canLock(id: longBoundaryId, info: singleInfo)
    LockmanSingleExecutionStrategy.shared.lock(id: longBoundaryId, info: singleInfo)

    // Capture output
    let originalStdout = dup(STDOUT_FILENO)
    let pipe = Pipe()
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    // Print with compact options
    Lockman.debug.printCurrentLocks(options: .compact)

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
    XCTAssertTrue(output.contains("DynamicCondition"))  // Not truncated to "DynamicConditio"
    XCTAssertTrue(output.contains("condition: <closure"))  // Not truncated to "condition: <clo"
    XCTAssertTrue(output.contains("SingleExecution"))
    XCTAssertTrue(output.contains("veryLongActionIdForTestingDynamicColumnWidth"))
    XCTAssertTrue(output.contains("VeryLongBoundaryIdForTestingColumnWidth"))

    // Clean up
    Lockman.cleanup.all()
  }

  func testFormatOptions() {
    // Test compact options
    let compact = Lockman.debug.FormatOptions.compact
    XCTAssertEqual(compact.maxStrategyWidth, 0)
    XCTAssertEqual(compact.maxBoundaryWidth, 0)
    XCTAssertEqual(compact.maxActionIdWidth, 0)
    XCTAssertEqual(compact.maxAdditionalWidth, 0)

    // Test default options
    let defaultOptions = Lockman.debug.FormatOptions.default
    XCTAssertEqual(defaultOptions.maxStrategyWidth, 20)
    XCTAssertEqual(defaultOptions.maxBoundaryWidth, 25)
    XCTAssertEqual(defaultOptions.maxActionIdWidth, 36)
    XCTAssertEqual(defaultOptions.maxAdditionalWidth, 20)
  }
}
