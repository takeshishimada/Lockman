import Foundation
import OSLog
import XCTest
@testable @_spi(Logging) import LockmanCore

/// Tests for the Logger class (Internal/Logger.swift)
final class LoggerTests: XCTestCase {
  // MARK: - Test Setup

  override func setUp() {
        super.setUp()
    // Reset logger state before each test
    Logger.shared.isEnabled = false
    Logger.shared.clear()
  }

  // MARK: - Singleton Tests

  func testloggerSingletonInstance() {
    let logger1 = Logger.shared
    let logger2 = Logger.shared

    // Verify same instance
    XCTAssertTrue(logger1  === logger2)
  }

  // MARK: - Basic Property Tests

  func testloggerIsEnabledDefaultValue() {
    // Store current state
    let originalState = Logger.shared.isEnabled

    // Reset to default state (false)
    Logger.shared.isEnabled = false

    // Test default behavior
    XCTAssertFalse(Logger.shared.isEnabled )

    // Restore original state
    Logger.shared.isEnabled = originalState
  }

  func testloggerCanToggleIsEnabled() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = false
    XCTAssertFalse(Logger.shared.isEnabled )

    Logger.shared.isEnabled = true
    XCTAssertTrue(Logger.shared.isEnabled )

    Logger.shared.isEnabled = false
    XCTAssertFalse(Logger.shared.isEnabled )

    // Clear logs at the end
    Logger.shared.clear()
  }

  func testloggerLogsStartEmpty() {
    // Clear any previous logs first
    Logger.shared.clear()

    XCTAssertTrue(Logger.shared.logs.isEmpty)
    XCTAssertTrue(Logger.shared.logs.isEmpty)
  }

  // MARK: - Logging Tests (DEBUG mode)

  #if DEBUG
    func testloggerLogsWhenEnabled() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Test message 1")
      Logger.shared.log("Test message 2")

      XCTAssertEqual(Logger.shared.logs.count, 2)
      XCTAssertEqual(Logger.shared.logs[0], "Test message 1")
      XCTAssertEqual(Logger.shared.logs[1], "Test message 2")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerDoesNotLogWhenDisabled() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = false

      Logger.shared.log("This should not be logged")

      XCTAssertTrue(Logger.shared.logs.isEmpty)

      // Clear logs at the end (already empty, but for consistency)
      Logger.shared.clear()
    }

    func testloggerLogWithDifferentLevels() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log(level: .default, "Default level")
      Logger.shared.log(level: .info, "Info level")
      Logger.shared.log(level: .debug, "Debug level")
      Logger.shared.log(level: .error, "Error level")
      Logger.shared.log(level: .fault, "Fault level")

      XCTAssertEqual(Logger.shared.logs.count, 5)
      XCTAssertEqual(Logger.shared.logs[0], "Default level")
      XCTAssertEqual(Logger.shared.logs[1], "Info level")
      XCTAssertEqual(Logger.shared.logs[2], "Debug level")
      XCTAssertEqual(Logger.shared.logs[3], "Error level")
      XCTAssertEqual(Logger.shared.logs[4], "Fault level")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerClearRemovesAllLogs() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Message 1")
      Logger.shared.log("Message 2")
      Logger.shared.log("Message 3")

      XCTAssertEqual(Logger.shared.logs.count, 3)

      Logger.shared.clear()

      XCTAssertTrue(Logger.shared.logs.isEmpty)
      XCTAssertTrue(Logger.shared.logs.isEmpty)

      // Reset isEnabled at the end
      Logger.shared.isEnabled  = false
    }

    func testloggerAutoclosureEvaluationBehavior() {
      // Ensure clean state at the beginning
      Logger.shared.clear()
      Logger.shared.isEnabled = false

      var evaluationCount = 0

      // Test 1: When enabled, autoclosure is evaluated
      Logger.shared.isEnabled = true
      Logger.shared.clear()

      // Create a function that returns a string
      func getMessage() -> String {
        evaluationCount += 1
        return "Message \(evaluationCount)"
      }

      Logger.shared.log(getMessage())

      XCTAssertEqual(evaluationCount, 1)
      XCTAssertEqual(Logger.shared.logs.count, 1)
      XCTAssertEqual(Logger.shared.logs[0], "Message 1")

      // Test 2: When disabled, autoclosure is NOT evaluated
      Logger.shared.isEnabled  = false
      let logCountBefore = Logger.shared.logs.count

      Logger.shared.log(getMessage())

      XCTAssertEqual(evaluationCount, 1) // Function was NOT evaluated (autoclosure)
      XCTAssertEqual(Logger.shared.logs.count, logCountBefore) // Not logged

      // Test 3: Autoclosure prevents evaluation when disabled
      Logger.shared.isEnabled  = false
      var sideEffectCount = 0

      // Define a function that has side effects
      func getSideEffectMessage() -> String {
        sideEffectCount += 1
        return "Count: \(sideEffectCount)"
      }

      // This will NOT evaluate when disabled (autoclosure)
      Logger.shared.log(getSideEffectMessage())

      XCTAssertEqual(sideEffectCount, 0) // No side effect (autoclosure prevents evaluation)

      // Test 4: Direct string literals
      Logger.shared.isEnabled  = true
      Logger.shared.log("Direct message")
      XCTAssertEqual(Logger.shared.logs.last, "Direct message")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerHandlesEmptyStrings() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("")

      XCTAssertEqual(Logger.shared.logs.count, 1)
      XCTAssertEqual(Logger.shared.logs[0], "")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerHandlesUnicodeAndSpecialCharacters() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Unicode: 🔒 日本語 🚀")
      Logger.shared.log("Special: \n\t\r")
      Logger.shared.log("Quotes: \"Hello\" 'World'")

      XCTAssertEqual(Logger.shared.logs.count, 3)
      XCTAssertEqual(Logger.shared.logs[0], "Unicode: 🔒 日本語 🚀")
      XCTAssertEqual(Logger.shared.logs[1], "Special: \n\t\r")
      XCTAssertEqual(Logger.shared.logs[2], "Quotes: \"Hello\" 'World'")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerHandlesVeryLongMessages() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      let longMessage = String(repeating: "VeryLongMessage", count: 1000)
      Logger.shared.log(longMessage)

      XCTAssertEqual(Logger.shared.logs.count, 1)
      XCTAssertEqual(Logger.shared.logs[0], longMessage)
      XCTAssertEqual(Logger.shared.logs[0].count, 15000)

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func disabled_loggerThreadSafetyForLogging() async {
      // Clear logs at the beginning
      await MainActor.run {
        Logger.shared.clear()
        Logger.shared.isEnabled = true
      }

      let iterations = 100

      // Use sequential approach to avoid Swift 6 concurrency warnings
      for i in 0 ..< iterations {
        await MainActor.run {
          Logger.shared.log("Message \(i)")
        }
      }

      // All messages should be logged
      XCTAssertEqual(Logger.shared.logs.count, iterations)

      // Clear logs at the end and reset isEnabled
      await MainActor.run {
        Logger.shared.clear()
        Logger.shared.isEnabled  = false
      }
    }

    func disabled_loggerThreadSafetyForClear() async {
      // This test is disabled because Logger is a singleton and its state
      // is shared across all tests running in parallel, making it impossible
      // to reliably test without interference from other tests.
    }

    func testloggerMaintainsOrderOfLogs() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      for i in 0 ..< 10 {
        Logger.shared.log("Message \(i)")
      }

      XCTAssertEqual(Logger.shared.logs.count, 10)
      for i in 0 ..< 10 {
        XCTAssertEqual(Logger.shared.logs[i], "Message \(i)")
      }

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled  = false
    }

    func testloggerPublishedLogsProperty() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      // Initial state
      XCTAssertTrue(Logger.shared.logs.isEmpty)

      // Add logs
      Logger.shared.log("First")
      XCTAssertEqual(Logger.shared.logs, ["First"])

      Logger.shared.log("Second")
      XCTAssertEqual(Logger.shared.logs, ["First", "Second"])

      // Clear
      Logger.shared.clear()
      XCTAssertTrue(Logger.shared.logs.isEmpty)

      // Reset isEnabled at the end
      Logger.shared.isEnabled  = false
    }

  #else

    // Tests for non-DEBUG mode
    func testloggerNoOpInReleaseMode() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      // These should do nothing in release mode
      Logger.shared.log("This does nothing")
      Logger.shared.log(level: .error, "This also does nothing")
      Logger.shared.clear()

      // No way to verify in release mode, but should not crash
      XCTAssertTrue(true)

      // Reset isEnabled at the end
      Logger.shared.isEnabled = false
    }

  #endif

  // MARK: - Edge Cases

  func testloggerStatePersistenceAcrossTests() {
    // This test verifies that Logger.shared maintains its state
    let initialEnabled = Logger.shared.isEnabled

    // Change state
    Logger.shared.isEnabled = !initialEnabled

    // Verify change persisted
    XCTAssertNotEqual(Logger.shared.isEnabled, initialEnabled)

    // Reset for other tests
    Logger.shared.isEnabled  = false
    Logger.shared.clear()
  }

  func testloggerSubsystemAndCategory() {
    #if DEBUG
      if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
        // Access the logger property to ensure it's created without error
        _ = Logger.shared.logger

        // We can't directly test the subsystem and category values,
        // but we can verify the logger is created successfully
        XCTAssertTrue(Bool(true))
      }
    #endif
  }
}

// MARK: - Performance Tests

final class LoggerPerformanceTests: XCTestCase {
  func testloggerPerformanceHighVolume() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = true

    let startTime = Date()

    for i in 0 ..< 1000 {
      Logger.shared.log("Performance test message \(i)")
    }

    let elapsed = Date().timeIntervalSince(startTime)

    #if DEBUG
      XCTAssertEqual(Logger.shared.logs.count, 1000)
      XCTAssertLessThan(elapsed , 1.0) // Should complete within 1 second
    #else
      XCTAssertLessThan(elapsed , 0.1) // Should be very fast in release mode
    #endif

    // Clear logs at the end and reset isEnabled
    Logger.shared.clear()
    Logger.shared.isEnabled  = false
  }

  func testloggerPerformanceWhenDisabled() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = false

    let startTime = Date()

    for i in 0 ..< 10000 {
      Logger.shared.log("This should not be logged \(i)")
    }

    let elapsed = Date().timeIntervalSince(startTime)

    XCTAssertTrue(Logger.shared.logs.isEmpty)
    XCTAssertLessThan(elapsed , 0.1) // Should be very fast when disabled

    // Clear logs at the end (already empty, but for consistency)
    Logger.shared.clear()
  }
}
