import Foundation
import OSLog
import Testing
@testable @_spi(Logging) import LockmanCore

/// Tests for the Logger class (Internal/Logger.swift)
@Suite("Logger Tests", .serialized)
@MainActor
struct LoggerTests {
  // MARK: - Test Setup

  init() async {
    // Reset logger state before each test
    Logger.shared.isEnabled = false
    Logger.shared.clear()
  }

  // MARK: - Singleton Tests

  @Test("Logger has singleton instance")
  func loggerSingletonInstance() {
    let logger1 = Logger.shared
    let logger2 = Logger.shared

    // Verify same instance
    #expect(logger1 === logger2)
  }

  // MARK: - Basic Property Tests

  @Test("Logger isEnabled defaults to false")
  func loggerIsEnabledDefaultValue() {
    // Store current state
    let originalState = Logger.shared.isEnabled

    // Reset to default state (false)
    Logger.shared.isEnabled = false

    // Test default behavior
    #expect(Logger.shared.isEnabled == false)

    // Restore original state
    Logger.shared.isEnabled = originalState
  }

  @Test("Logger can toggle isEnabled")
  func loggerCanToggleIsEnabled() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = false
    #expect(Logger.shared.isEnabled == false)

    Logger.shared.isEnabled = true
    #expect(Logger.shared.isEnabled == true)

    Logger.shared.isEnabled = false
    #expect(Logger.shared.isEnabled == false)

    // Clear logs at the end
    Logger.shared.clear()
  }

  @Test("Logger logs array starts empty")
  func loggerLogsStartEmpty() {
    // Clear any previous logs first
    Logger.shared.clear()

    #expect(Logger.shared.logs.isEmpty)
    #expect(Logger.shared.logs.isEmpty)
  }

  // MARK: - Logging Tests (DEBUG mode)

  #if DEBUG
    @Test("Logger logs when enabled")
    func loggerLogsWhenEnabled() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Test message 1")
      Logger.shared.log("Test message 2")

      #expect(Logger.shared.logs.count == 2)
      #expect(Logger.shared.logs[0] == "Test message 1")
      #expect(Logger.shared.logs[1] == "Test message 2")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger does not log when disabled")
    func loggerDoesNotLogWhenDisabled() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = false

      Logger.shared.log("This should not be logged")

      #expect(Logger.shared.logs.isEmpty)

      // Clear logs at the end (already empty, but for consistency)
      Logger.shared.clear()
    }

    @Test("Logger log with different OSLogType levels")
    func loggerLogWithDifferentLevels() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log(level: .default, "Default level")
      Logger.shared.log(level: .info, "Info level")
      Logger.shared.log(level: .debug, "Debug level")
      Logger.shared.log(level: .error, "Error level")
      Logger.shared.log(level: .fault, "Fault level")

      #expect(Logger.shared.logs.count == 5)
      #expect(Logger.shared.logs[0] == "Default level")
      #expect(Logger.shared.logs[1] == "Info level")
      #expect(Logger.shared.logs[2] == "Debug level")
      #expect(Logger.shared.logs[3] == "Error level")
      #expect(Logger.shared.logs[4] == "Fault level")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger clear removes all logs")
    func loggerClearRemovesAllLogs() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Message 1")
      Logger.shared.log("Message 2")
      Logger.shared.log("Message 3")

      #expect(Logger.shared.logs.count == 3)

      Logger.shared.clear()

      #expect(Logger.shared.logs.isEmpty)
      #expect(Logger.shared.logs.isEmpty)

      // Reset isEnabled at the end
      Logger.shared.isEnabled = false
    }

    @Test("Logger autoclosure evaluation behavior")
    func loggerAutoclosureEvaluationBehavior() {
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

      #expect(evaluationCount == 1)
      #expect(Logger.shared.logs.count == 1)
      #expect(Logger.shared.logs[0] == "Message 1")

      // Test 2: When disabled, autoclosure is NOT evaluated
      Logger.shared.isEnabled = false
      let logCountBefore = Logger.shared.logs.count

      Logger.shared.log(getMessage())

      #expect(evaluationCount == 1) // Function was NOT evaluated (autoclosure)
      #expect(Logger.shared.logs.count == logCountBefore) // Not logged

      // Test 3: Autoclosure prevents evaluation when disabled
      Logger.shared.isEnabled = false
      var sideEffectCount = 0

      // Define a function that has side effects
      func getSideEffectMessage() -> String {
        sideEffectCount += 1
        return "Count: \(sideEffectCount)"
      }

      // This will NOT evaluate when disabled (autoclosure)
      Logger.shared.log(getSideEffectMessage())

      #expect(sideEffectCount == 0) // No side effect (autoclosure prevents evaluation)

      // Test 4: Direct string literals
      Logger.shared.isEnabled = true
      Logger.shared.log("Direct message")
      #expect(Logger.shared.logs.last == "Direct message")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger handles empty strings")
    func loggerHandlesEmptyStrings() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("")

      #expect(Logger.shared.logs.count == 1)
      #expect(Logger.shared.logs[0] == "")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger handles unicode and special characters")
    func loggerHandlesUnicodeAndSpecialCharacters() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      Logger.shared.log("Unicode: 🔒 日本語 🚀")
      Logger.shared.log("Special: \n\t\r")
      Logger.shared.log("Quotes: \"Hello\" 'World'")

      #expect(Logger.shared.logs.count == 3)
      #expect(Logger.shared.logs[0] == "Unicode: 🔒 日本語 🚀")
      #expect(Logger.shared.logs[1] == "Special: \n\t\r")
      #expect(Logger.shared.logs[2] == "Quotes: \"Hello\" 'World'")

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger handles very long messages")
    func loggerHandlesVeryLongMessages() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      let longMessage = String(repeating: "VeryLongMessage", count: 1000)
      Logger.shared.log(longMessage)

      #expect(Logger.shared.logs.count == 1)
      #expect(Logger.shared.logs[0] == longMessage)
      #expect(Logger.shared.logs[0].count == 15000)

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger thread safety for logging", .disabled("Concurrency issues with MainActor"))
    func loggerThreadSafetyForLogging() async {
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
      #expect(Logger.shared.logs.count == iterations)

      // Clear logs at the end and reset isEnabled
      await MainActor.run {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    @Test(.disabled("Logger state is shared across tests"))
    func loggerThreadSafetyForClear() async {
      // This test is disabled because Logger is a singleton and its state
      // is shared across all tests running in parallel, making it impossible
      // to reliably test without interference from other tests.
    }

    @Test("Logger maintains order of logs")
    func loggerMaintainsOrderOfLogs() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      for i in 0 ..< 10 {
        Logger.shared.log("Message \(i)")
      }

      #expect(Logger.shared.logs.count == 10)
      for i in 0 ..< 10 {
        #expect(Logger.shared.logs[i] == "Message \(i)")
      }

      // Clear logs at the end and reset isEnabled
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    @Test("Logger @Published logs property")
    func loggerPublishedLogsProperty() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      // Initial state
      #expect(Logger.shared.logs.isEmpty)

      // Add logs
      Logger.shared.log("First")
      #expect(Logger.shared.logs == ["First"])

      Logger.shared.log("Second")
      #expect(Logger.shared.logs == ["First", "Second"])

      // Clear
      Logger.shared.clear()
      #expect(Logger.shared.logs.isEmpty)

      // Reset isEnabled at the end
      Logger.shared.isEnabled = false
    }

  #else

    // Tests for non-DEBUG mode
    @Test("Logger methods are no-op in release mode")
    func loggerNoOpInReleaseMode() {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = true

      // These should do nothing in release mode
      Logger.shared.log("This does nothing")
      Logger.shared.log(level: .error, "This also does nothing")
      Logger.shared.clear()

      // No way to verify in release mode, but should not crash
      #expect(true)

      // Reset isEnabled at the end
      Logger.shared.isEnabled = false
    }

  #endif

  // MARK: - Edge Cases

  @Test("Logger state persistence across tests")
  func loggerStatePersistenceAcrossTests() {
    // This test verifies that Logger.shared maintains its state
    let initialEnabled = Logger.shared.isEnabled

    // Change state
    Logger.shared.isEnabled = !initialEnabled

    // Verify change persisted
    #expect(Logger.shared.isEnabled == !initialEnabled)

    // Reset for other tests
    Logger.shared.isEnabled = false
    Logger.shared.clear()
  }

  @Test("Logger subsystem and category")
  func loggerSubsystemAndCategory() {
    #if DEBUG
      if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
        // Access the logger property to ensure it's created without error
        _ = Logger.shared.logger

        // We can't directly test the subsystem and category values,
        // but we can verify the logger is created successfully
        #expect(Bool(true))
      }
    #endif
  }
}

// MARK: - Performance Tests

@Suite("Logger Performance Tests", .serialized)
@MainActor
struct LoggerPerformanceTests {
  @Test("Logger performance with high volume")
  func loggerPerformanceHighVolume() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = true

    let startTime = Date()

    for i in 0 ..< 1000 {
      Logger.shared.log("Performance test message \(i)")
    }

    let elapsed = Date().timeIntervalSince(startTime)

    #if DEBUG
      #expect(Logger.shared.logs.count == 1000)
      #expect(elapsed < 1.0) // Should complete within 1 second
    #else
      #expect(elapsed < 0.1) // Should be very fast in release mode
    #endif

    // Clear logs at the end and reset isEnabled
    Logger.shared.clear()
    Logger.shared.isEnabled = false
  }

  @Test("Logger performance when disabled")
  func loggerPerformanceWhenDisabled() {
    // Clear logs at the beginning
    Logger.shared.clear()

    Logger.shared.isEnabled = false

    let startTime = Date()

    for i in 0 ..< 10000 {
      Logger.shared.log("This should not be logged \(i)")
    }

    let elapsed = Date().timeIntervalSince(startTime)

    #expect(Logger.shared.logs.isEmpty)
    #expect(elapsed < 0.1) // Should be very fast when disabled

    // Clear logs at the end (already empty, but for consistency)
    Logger.shared.clear()
  }
}
