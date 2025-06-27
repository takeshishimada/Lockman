import XCTest

@testable @_spi(Logging) import Lockman

final class LockmanLoggerTests: XCTestCase {

  func testLoggerEnablement() async throws {
    // Given
    let logger = LockmanLogger.shared

    // When: Enable logging
    logger.isEnabled = true

    // Wait for async task to complete
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    // Then: Both loggers should be enabled
    await MainActor.run {
      XCTAssertTrue(logger.isEnabled, "LockmanLogger should be enabled")
      XCTAssertTrue(Logger.shared.isEnabled, "Internal Logger should also be enabled")
    }

    // When: Disable logging
    logger.isEnabled = false

    // Wait for async task to complete
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    // Then: Both loggers should be disabled
    await MainActor.run {
      XCTAssertFalse(logger.isEnabled, "LockmanLogger should be disabled")
      XCTAssertFalse(Logger.shared.isEnabled, "Internal Logger should also be disabled")
    }
  }

  func testLogOutput() async throws {
    // Given
    let logger = LockmanLogger.shared

    // Clear any existing logs
    await MainActor.run {
      Logger.shared.clear()
    }

    // When: Enable logging and log a message
    logger.isEnabled = true
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    // Create a test lock info
    struct TestInfo: LockmanInfo {
      var strategyId: LockmanStrategyId { .init("TestStrategy") }
      var actionId: String { "testAction" }
      var uniqueId: UUID { UUID() }
      var debugDescription: String { "TestInfo(actionId: \(actionId))" }
    }

    let info = TestInfo()
    logger.logCanLock(
      result: LockmanResult.success,
      strategy: "TestStrategy",
      boundaryId: "testBoundary",
      info: info
    )

    // Wait for async logging to complete
    try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds

    // Then: Check if log was recorded
    await MainActor.run {
      let logs = Logger.shared.logs
      XCTAssertFalse(logs.isEmpty, "Logs should not be empty")

      if let lastLog = logs.last {
        XCTAssertTrue(lastLog.contains("✅"), "Log should contain success emoji")
        XCTAssertTrue(lastLog.contains("TestStrategy"), "Log should contain strategy name")
        XCTAssertTrue(lastLog.contains("testBoundary"), "Log should contain boundary ID")
        XCTAssertTrue(lastLog.contains("testAction"), "Log should contain action ID")
      }
    }

    // Cleanup
    logger.isEnabled = false
  }

  func testDebugAPI() async throws {
    // Test the public API
    LockmanManager.debug.isLoggingEnabled = true

    // Wait for async task to complete
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds

    await MainActor.run {
      XCTAssertTrue(LockmanLogger.shared.isEnabled)
      XCTAssertTrue(Logger.shared.isEnabled)
    }

    // Cleanup
    LockmanManager.debug.isLoggingEnabled = false
  }
}
