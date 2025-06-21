import Foundation
import OSLog
import XCTest
@testable @_spi(Logging) import LockmanCore

// Helper class for thread-safe mutable state in tests
private final class Atomic<Value>: @unchecked Sendable {
  private var _value: Value
  private let lock = NSLock()
  
  init(_ value: Value) {
    self._value = value
  }
  
  var value: Value {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _value
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _value = newValue
    }
  }
}

/// Tests for the Logger class (Internal/Logger.swift)
final class LoggerTests: XCTestCase {
  // MARK: - Helper Methods
  
  /// Execute a closure on the MainActor and return the result
  private func onMainActor<T: Sendable>(_ closure: @MainActor @Sendable () throws -> T) async rethrows -> T {
    try await MainActor.run {
      try closure()
    }
  }
  
  // MARK: - Test Setup

  override func setUp() async throws {
    try await super.setUp()
    // Reset logger state before each test
    await onMainActor {
      Logger.shared.isEnabled = false
      Logger.shared.clear()
    }
  }

  // MARK: - Singleton Tests

  func testloggerSingletonInstance() async {
    let isSameInstance = await onMainActor {
      let logger1 = Logger.shared
      let logger2 = Logger.shared
      // Verify same instance
      return logger1 === logger2
    }
    XCTAssertTrue(isSameInstance)
  }

  // MARK: - Basic Property Tests

  func testloggerIsEnabledDefaultValue() async {
    await onMainActor {
      // Store current state
      let originalState = Logger.shared.isEnabled

      // Reset to default state (false)
      Logger.shared.isEnabled = false

      // Test default behavior
      XCTAssertFalse(Logger.shared.isEnabled)

      // Restore original state
      Logger.shared.isEnabled = originalState
    }
  }

  func testloggerCanToggleIsEnabled() async {
    await onMainActor {
      // Clear logs at the beginning
      Logger.shared.clear()

      Logger.shared.isEnabled = false
      XCTAssertFalse(Logger.shared.isEnabled)

      Logger.shared.isEnabled = true
      XCTAssertTrue(Logger.shared.isEnabled)

      Logger.shared.isEnabled = false
      XCTAssertFalse(Logger.shared.isEnabled)

      // Clear logs at the end
      Logger.shared.clear()
    }
  }

  func testloggerLogsStartEmpty() async {
    // Clear any previous logs first
    await onMainActor {
      Logger.shared.clear()
    }

    let logsEmpty = await onMainActor {
      Logger.shared.logs.isEmpty
    }
    XCTAssertTrue(logsEmpty)
  }

  // MARK: - Logging Tests (DEBUG mode)

  #if DEBUG
    func testloggerLogsWhenEnabled() async {
      // Clear logs at the beginning
      await Logger.shared.clear()

      await MainActor.run {
        Logger.shared.isEnabled = true

        Logger.shared.log("Test message 1")
        Logger.shared.log("Test message 2")
      }

      let logs = await Logger.shared.logs
      XCTAssertEqual(logs.count, 2)
      XCTAssertEqual(logs[0], "Test message 1")
      XCTAssertEqual(logs[1], "Test message 2")

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerDoesNotLogWhenDisabled() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
        Logger.shared.log("This should not be logged")
      }

      let logsEmpty = await onMainActor {
        Logger.shared.logs.isEmpty
      }
      XCTAssertTrue(logsEmpty)

      // Clear logs at the end (already empty, but for consistency)
      await onMainActor {
        Logger.shared.clear()
      }
    }

    func testloggerLogWithDifferentLevels() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true

        Logger.shared.log(level: .default, "Default level")
        Logger.shared.log(level: .info, "Info level")
        Logger.shared.log(level: .debug, "Debug level")
        Logger.shared.log(level: .error, "Error level")
        Logger.shared.log(level: .fault, "Fault level")
      }

      let logs = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logs.count, 5)
      XCTAssertEqual(logs[0], "Default level")
      XCTAssertEqual(logs[1], "Info level")
      XCTAssertEqual(logs[2], "Debug level")
      XCTAssertEqual(logs[3], "Error level")
      XCTAssertEqual(logs[4], "Fault level")

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerClearRemovesAllLogs() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true

        Logger.shared.log("Message 1")
        Logger.shared.log("Message 2")
        Logger.shared.log("Message 3")
      }

      let logCount = await onMainActor {
        Logger.shared.logs.count
      }
      XCTAssertEqual(logCount, 3)

      await onMainActor {
        Logger.shared.clear()
      }

      let logsEmpty = await onMainActor {
        Logger.shared.logs.isEmpty
      }
      XCTAssertTrue(logsEmpty)

      // Reset isEnabled at the end
      await onMainActor {
        Logger.shared.isEnabled = false
      }
    }

    func testloggerAutoclosureEvaluationBehavior() async {
      // Ensure clean state at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }

      let evaluationCount = Atomic(0)

      // Test 1: When enabled, autoclosure is evaluated
      await onMainActor {
        Logger.shared.isEnabled = true
        Logger.shared.clear()
      }

      // Create a @Sendable function that returns a string  
      let getMessage: @Sendable () -> String = { [evaluationCount] in
        evaluationCount.value += 1
        return "Message \(evaluationCount.value)"
      }

      await onMainActor { [getMessage] in
        Logger.shared.log(getMessage())
      }

      let (logCount1, logs1) = await onMainActor {
        (Logger.shared.logs.count, Logger.shared.logs)
      }
      XCTAssertEqual(evaluationCount.value, 1)
      XCTAssertEqual(logCount1, 1)
      XCTAssertEqual(logs1[0], "Message 1")

      // Test 2: When disabled, autoclosure is NOT evaluated
      let logCountBefore = await onMainActor {
        Logger.shared.isEnabled = false
        return Logger.shared.logs.count
      }

      await onMainActor { [getMessage] in
        Logger.shared.log(getMessage())
      }

      let logCountAfter = await onMainActor {
        Logger.shared.logs.count
      }
      XCTAssertEqual(evaluationCount.value, 1) // Function was NOT evaluated (autoclosure)
      XCTAssertEqual(logCountAfter, logCountBefore) // Not logged

      // Test 3: Autoclosure prevents evaluation when disabled
      await onMainActor {
        Logger.shared.isEnabled = false
      }
      let sideEffectCount = Atomic(0)

      // Define a @Sendable function that has side effects
      let getSideEffectMessage: @Sendable () -> String = { [sideEffectCount] in
        sideEffectCount.value += 1
        return "Count: \(sideEffectCount.value)"
      }

      // This will NOT evaluate when disabled (autoclosure)
      await onMainActor { [getSideEffectMessage] in
        Logger.shared.log(getSideEffectMessage())
      }

      XCTAssertEqual(sideEffectCount.value, 0) // No side effect (autoclosure prevents evaluation)

      // Test 4: Direct string literals
      await onMainActor {
        Logger.shared.isEnabled = true
        Logger.shared.log("Direct message")
      }
      
      let lastLog = await onMainActor {
        Logger.shared.logs.last
      }
      XCTAssertEqual(lastLog, "Direct message")

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerHandlesEmptyStrings() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true
        Logger.shared.log("")
      }

      let logs = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logs.count, 1)
      XCTAssertEqual(logs[0], "")

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerHandlesUnicodeAndSpecialCharacters() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true

        Logger.shared.log("Unicode: 🔒 日本語 🚀")
        Logger.shared.log("Special: \n\t\r")
        Logger.shared.log("Quotes: \"Hello\" 'World'")
      }

      let logs = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logs.count, 3)
      XCTAssertEqual(logs[0], "Unicode: 🔒 日本語 🚀")
      XCTAssertEqual(logs[1], "Special: \n\t\r")
      XCTAssertEqual(logs[2], "Quotes: \"Hello\" 'World'")

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerHandlesVeryLongMessages() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true
      }

      let longMessage = String(repeating: "VeryLongMessage", count: 1000)
      await onMainActor {
        Logger.shared.log(longMessage)
      }

      let logs = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logs.count, 1)
      XCTAssertEqual(logs[0], longMessage)
      XCTAssertEqual(logs[0].count, 15000)

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
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
      let logCount = await onMainActor {
        Logger.shared.logs.count
      }
      XCTAssertEqual(logCount, iterations)

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

    func testloggerMaintainsOrderOfLogs() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true

        for i in 0 ..< 10 {
          Logger.shared.log("Message \(i)")
        }
      }

      let logs = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logs.count, 10)
      for i in 0 ..< 10 {
        XCTAssertEqual(logs[i], "Message \(i)")
      }

      // Clear logs at the end and reset isEnabled
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = false
      }
    }

    func testloggerPublishedLogsProperty() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true
      }

      // Initial state
      let initialEmpty = await onMainActor {
        Logger.shared.logs.isEmpty
      }
      XCTAssertTrue(initialEmpty)

      // Add logs
      await onMainActor {
        Logger.shared.log("First")
      }
      let logsAfterFirst = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logsAfterFirst, ["First"])

      await onMainActor {
        Logger.shared.log("Second")
      }
      let logsAfterSecond = await onMainActor {
        Logger.shared.logs
      }
      XCTAssertEqual(logsAfterSecond, ["First", "Second"])

      // Clear
      await onMainActor {
        Logger.shared.clear()
      }
      let finalEmpty = await onMainActor {
        Logger.shared.logs.isEmpty
      }
      XCTAssertTrue(finalEmpty)

      // Reset isEnabled at the end
      await onMainActor {
        Logger.shared.isEnabled = false
      }
    }

  #else

    // Tests for non-DEBUG mode
    func testloggerNoOpInReleaseMode() async {
      // Clear logs at the beginning
      await onMainActor {
        Logger.shared.clear()
        Logger.shared.isEnabled = true

        // These should do nothing in release mode
        Logger.shared.log("This does nothing")
        Logger.shared.log(level: .error, "This also does nothing")
        Logger.shared.clear()
      }

      // No way to verify in release mode, but should not crash
      XCTAssertTrue(true)

      // Reset isEnabled at the end
      await onMainActor {
        Logger.shared.isEnabled = false
      }
    }

  #endif

  // MARK: - Edge Cases

  func testloggerStatePersistenceAcrossTests() async {
    // This test verifies that Logger.shared maintains its state
    let initialEnabled = await onMainActor {
      Logger.shared.isEnabled
    }

    // Change state
    await onMainActor {
      Logger.shared.isEnabled = !initialEnabled
    }

    // Verify change persisted
    let currentEnabled = await onMainActor {
      Logger.shared.isEnabled
    }
    XCTAssertNotEqual(currentEnabled, initialEnabled)

    // Reset for other tests
    await onMainActor {
      Logger.shared.isEnabled = false
      Logger.shared.clear()
    }
  }

  func testloggerSubsystemAndCategory() async {
    #if DEBUG
      if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
        // Access the logger property to ensure it's created without error
        await onMainActor {
          _ = Logger.shared.logger
        }

        // We can't directly test the subsystem and category values,
        // but we can verify the logger is created successfully
        XCTAssertTrue(Bool(true))
      }
    #endif
  }
}

// MARK: - Performance Tests

final class LoggerPerformanceTests: XCTestCase {
  private func onMainActor<T: Sendable>(_ closure: @MainActor @Sendable () throws -> T) async rethrows -> T {
    try await MainActor.run {
      try closure()
    }
  }
  
  func testloggerPerformanceHighVolume() async {
    // Clear logs at the beginning
    await onMainActor {
      Logger.shared.clear()
      Logger.shared.isEnabled = true
    }

    let startTime = Date()

    await onMainActor {
      for i in 0 ..< 1000 {
        Logger.shared.log("Performance test message \(i)")
      }
    }

    let elapsed = Date().timeIntervalSince(startTime)

    #if DEBUG
      let logCount = await onMainActor {
        Logger.shared.logs.count
      }
      XCTAssertEqual(logCount, 1000)
      XCTAssertLessThan(elapsed , 1.0) // Should complete within 1 second
    #else
      XCTAssertLessThan(elapsed , 0.1) // Should be very fast in release mode
    #endif

    // Clear logs at the end and reset isEnabled
    await onMainActor {
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }
  }

  func testloggerPerformanceWhenDisabled() async {
    // Clear logs at the beginning
    await onMainActor {
      Logger.shared.clear()
      Logger.shared.isEnabled = false
    }

    let startTime = Date()

    await onMainActor {
      for i in 0 ..< 10000 {
        Logger.shared.log("This should not be logged \(i)")
      }
    }

    let elapsed = Date().timeIntervalSince(startTime)

    let logsEmpty = await onMainActor {
      Logger.shared.logs.isEmpty
    }
    XCTAssertTrue(logsEmpty)
    XCTAssertLessThan(elapsed , 0.1) // Should be very fast when disabled

    // Clear logs at the end (already empty, but for consistency)
    await onMainActor {
      Logger.shared.clear()
    }
  }
}
