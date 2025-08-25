import XCTest

@testable import Lockman

/// Unit tests for LockmanIssueReporter protocol and implementations
final class LockmanIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
  }

  override func tearDown() {
    LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
    super.tearDown()
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanDefaultIssueReporterConformance() {
    // Test that LockmanDefaultIssueReporter conforms to LockmanIssueReporter
    let reporterType: any LockmanIssueReporter.Type = LockmanDefaultIssueReporter.self

    // Should be able to call protocol method without crashing
    reporterType.reportIssue("test message", file: #file, line: #line)

    XCTAssertTrue(true)
  }

  func testCustomReporterConformance() {
    // Test that custom types can conform to the protocol
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    LockmanManager.config.issueReporter.reportIssue("custom test", file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, "custom test")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
    XCTAssertGreaterThan(MockIssueReporter.lastLine, 0)
  }

  // MARK: - Configuration Tests

  func testDefaultReporterConfiguration() {
    // Test that default reporter is properly set
    let defaultReporter = LockmanManager.config.issueReporter

    XCTAssertTrue(defaultReporter == LockmanDefaultIssueReporter.self)
  }

  func testReporterConfigurationChange() {
    // Test that reporter can be changed and retrieved
    let originalReporter = LockmanManager.config.issueReporter

    LockmanManager.config.issueReporter = MockIssueReporter.self
    XCTAssertTrue(LockmanManager.config.issueReporter == MockIssueReporter.self)

    LockmanManager.config.issueReporter = originalReporter
    XCTAssertTrue(LockmanManager.config.issueReporter == originalReporter)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentConfiguration() {
    let expectation = XCTestExpectation(description: "Concurrent configuration")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

    for i in 0..<100 {
      queue.async {
        if i % 2 == 0 {
          LockmanManager.config.issueReporter = MockIssueReporter.self
        } else {
          LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
        }

        let _ = LockmanManager.config.issueReporter
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testConcurrentReporting() {
    let expectation = XCTestExpectation(description: "Concurrent reporting")
    expectation.expectedFulfillmentCount = 50

    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    let queue = DispatchQueue(label: "test.reporting", attributes: .concurrent)

    for i in 0..<50 {
      queue.async {
        LockmanManager.config.issueReporter.reportIssue("Message \(i)", file: #file, line: #line)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Should complete without crashes and receive at least one report
    XCTAssertGreaterThan(MockIssueReporter.reportCount, 0)
  }

  // MARK: - Parameter Handling Tests

  func testParameterForwarding() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    let testMessage = "test message"
    let testFile: StaticString = "TestFile.swift"
    let testLine: UInt = 123

    LockmanManager.config.issueReporter.reportIssue(testMessage, file: testFile, line: testLine)

    XCTAssertEqual(MockIssueReporter.lastMessage, testMessage)
    XCTAssertEqual(MockIssueReporter.lastFile, "TestFile.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, testLine)
  }

  func testDefaultParameterBehavior() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    // Test default parameter handling for LockmanDefaultIssueReporter
    LockmanDefaultIssueReporter.reportIssue("default params test")

    // Should not crash - default parameters work correctly
    XCTAssertTrue(true)
  }

  // MARK: - Edge Cases Tests

  func testEmptyMessage() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    LockmanManager.config.issueReporter.reportIssue("", file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, "")
    XCTAssertEqual(MockIssueReporter.reportCount, 1)
  }

  func testSpecialCharacters() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    let specialMessage = "🚨 Error: \n\t\"Special\" chars"
    LockmanManager.config.issueReporter.reportIssue(specialMessage, file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, specialMessage)
  }

  func testLongMessage() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    let longMessage = String(repeating: "Long message ", count: 1000)
    LockmanManager.config.issueReporter.reportIssue(longMessage, file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, longMessage)
  }

  // MARK: - LockIsolated Tests

  func testLockIsolatedThreadSafety() {
    let lockIsolated = LockIsolated<Int>(0)
    let expectation = XCTestExpectation(description: "LockIsolated thread safety")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue(label: "test.lockisolated", attributes: .concurrent)

    for i in 0..<100 {
      queue.async {
        lockIsolated.withValue { value in
          value += 1
        }
        let _ = lockIsolated.value
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
    XCTAssertEqual(lockIsolated.value, 100)
  }

  // MARK: - Deprecated API Tests

  @available(*, deprecated)
  func testDeprecatedLockmanIssueReporting() {
    MockIssueReporter.reset()

    // Test deprecated LockmanIssueReporting configuration
    LockmanIssueReporting.reporter = MockIssueReporter.self
    XCTAssertTrue(LockmanIssueReporting.reporter == MockIssueReporter.self)

    // Test deprecated reportIssue method
    LockmanIssueReporting.reportIssue("deprecated test", file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, "deprecated test")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
    XCTAssertGreaterThan(MockIssueReporter.lastLine, 0)
    XCTAssertEqual(MockIssueReporter.reportCount, 1)
  }

  @available(*, deprecated)
  func testDeprecatedReportIssueWithDefaultParameters() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test with default file and line parameters
    LockmanIssueReporting.reportIssue("default params deprecated")

    XCTAssertEqual(MockIssueReporter.lastMessage, "default params deprecated")
    XCTAssertEqual(MockIssueReporter.reportCount, 1)
  }

  // MARK: - Performance Tests

  func testReportingPerformance() {
    MockIssueReporter.reset()
    LockmanManager.config.issueReporter = MockIssueReporter.self

    measure {
      for i in 0..<1000 {
        LockmanManager.config.issueReporter.reportIssue(
          "Performance test \(i)", file: #file, line: #line)
      }
    }

    // Since measure{} runs multiple times, reportCount will be higher
    XCTAssertGreaterThanOrEqual(MockIssueReporter.reportCount, 1000)
  }
}

// MARK: - Test Helper for LockIsolated

private final class LockIsolated<Value>: @unchecked Sendable {
  private var _value: Value
  private let lock = NSLock()

  init(_ value: Value) {
    self._value = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func withValue<T>(_ operation: (inout Value) throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try operation(&_value)
  }
}

// MARK: - Mock Implementation

private final class MockIssueReporter: LockmanIssueReporter, @unchecked Sendable {
  private static let lock = NSLock()
  nonisolated(unsafe) static var lastMessage: String = ""
  nonisolated(unsafe) static var lastFile: String = ""
  nonisolated(unsafe) static var lastLine: UInt = 0
  nonisolated(unsafe) static var reportCount: Int = 0

  static func reportIssue(_ message: String, file: StaticString, line: UInt) {
    lock.withLock {
      lastMessage = message
      lastFile = "\(file)"
      lastLine = line
      reportCount += 1
    }
  }

  static func reset() {
    lock.withLock {
      lastMessage = ""
      lastFile = ""
      lastLine = 0
      reportCount = 0
    }
  }
}
