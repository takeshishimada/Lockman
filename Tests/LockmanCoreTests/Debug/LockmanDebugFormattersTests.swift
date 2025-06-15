import Foundation
import Testing
@testable @_spi(Debugging) import LockmanCore

struct LockmanDebugFormattersTests {
  @Test("Dynamic column width formatting")
  func testDynamicColumnWidth() throws {
    // Clean up first
    Lockman.cleanup.all()

    // Try to register strategies (ignore if already registered)
    _ = try? Lockman.container.register(LockmanDynamicConditionStrategy.shared)
    _ = try? Lockman.container.register(LockmanSingleExecutionStrategy.shared)

    // Test with DynamicConditionStrategy (long strategy name)
    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: "incrementButtonTapped",
      condition: { true }
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
    #expect(output.contains("DynamicCondition")) // Not truncated to "DynamicConditio"
    #expect(output.contains("condition: <closure>")) // Not truncated to "condition: <clo"
    #expect(output.contains("SingleExecution"))
    #expect(output.contains("veryLongActionIdForTestingDynamicColumnWidth"))
    #expect(output.contains("VeryLongBoundaryIdForTestingColumnWidth"))

    // Clean up
    Lockman.cleanup.all()
  }

  @Test("Format options work correctly")
  func testFormatOptions() {
    // Test compact options
    let compact = Lockman.debug.FormatOptions.compact
    #expect(compact.maxStrategyWidth == 0)
    #expect(compact.maxBoundaryWidth == 0)
    #expect(compact.maxActionIdWidth == 0)
    #expect(compact.maxAdditionalWidth == 0)

    // Test default options
    let defaultOptions = Lockman.debug.FormatOptions.default
    #expect(defaultOptions.maxStrategyWidth == 20)
    #expect(defaultOptions.maxBoundaryWidth == 25)
    #expect(defaultOptions.maxActionIdWidth == 36)
    #expect(defaultOptions.maxAdditionalWidth == 20)
  }
}
