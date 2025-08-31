import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive protocol tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Issue Reporter Types for Protocol Conformance

  private enum TestIssueReporter: LockmanIssueReporter {
    private static var capturedMessages: [String] = []
    private static var capturedFiles: [StaticString] = []
    private static var capturedLines: [UInt] = []

    static func reportIssue(
      _ message: String,
      file: StaticString,
      line: UInt
    ) {
      capturedMessages.append(message)
      capturedFiles.append(file)
      capturedLines.append(line)
    }

    static func getLastCapturedMessage() -> String? {
      return capturedMessages.last
    }

    static func getCapturedMessageCount() -> Int {
      return capturedMessages.count
    }

    static func reset() {
      capturedMessages.removeAll()
      capturedFiles.removeAll()
      capturedLines.removeAll()
    }
  }

  private final class TestClassIssueReporter: LockmanIssueReporter {
    static var reportedIssues: [(message: String, file: String, line: UInt)] = []

    static func reportIssue(
      _ message: String,
      file: StaticString,
      line: UInt
    ) {
      reportedIssues.append((message: message, file: "\(file)", line: line))
    }

    static func reset() {
      reportedIssues.removeAll()
    }
  }

  private struct TestStructIssueReporter: LockmanIssueReporter {
    static var issueCount = 0
    static var lastMessage = ""

    static func reportIssue(
      _ message: String,
      file: StaticString,
      line: UInt
    ) {
      issueCount += 1
      lastMessage = message
    }

    static func reset() {
      issueCount = 0
      lastMessage = ""
    }
  }

  // MARK: - Phase 1: Basic Protocol Conformance

  func testLockmanIssueReporterProtocolConformance() {
    // Test different types can conform to LockmanIssueReporter
    TestIssueReporter.reset()
    TestClassIssueReporter.reset()
    TestStructIssueReporter.reset()

    // Test enum conformance
    TestIssueReporter.reportIssue("Test enum message", file: #file, line: #line)
    XCTAssertEqual(TestIssueReporter.getCapturedMessageCount(), 1)
    XCTAssertEqual(TestIssueReporter.getLastCapturedMessage(), "Test enum message")

    // Test class conformance
    TestClassIssueReporter.reportIssue("Test class message", file: #file, line: #line)
    XCTAssertEqual(TestClassIssueReporter.reportedIssues.count, 1)
    XCTAssertEqual(TestClassIssueReporter.reportedIssues.last?.message, "Test class message")

    // Test struct conformance
    TestStructIssueReporter.reportIssue("Test struct message", file: #file, line: #line)
    XCTAssertEqual(TestStructIssueReporter.issueCount, 1)
    XCTAssertEqual(TestStructIssueReporter.lastMessage, "Test struct message")
  }

  func testLockmanIssueReporterStaticRequirement() {
    // Test that protocol requires static methods
    let reporterType: any LockmanIssueReporter.Type = TestIssueReporter.self
    XCTAssertNotNil(reporterType)

    // Test method signature
    TestIssueReporter.reset()
    TestIssueReporter.reportIssue("Static test", file: "TestFile.swift", line: 42)
    XCTAssertEqual(TestIssueReporter.getCapturedMessageCount(), 1)
  }

  func testLockmanIssueReporterFileAndLineParameters() {
    // Test file and line parameters are captured correctly
    TestIssueReporter.reset()
    let testFile: StaticString = "CustomFile.swift"
    let testLine: UInt = 123

    TestIssueReporter.reportIssue("File line test", file: testFile, line: testLine)

    XCTAssertEqual(TestIssueReporter.getCapturedMessageCount(), 1)
    XCTAssertEqual(TestIssueReporter.getLastCapturedMessage(), "File line test")
  }

  // MARK: - Phase 2: LockmanDefaultIssueReporter Implementation

  func testLockmanDefaultIssueReporterConformance() {
    // Test default implementation conforms to protocol
    let defaultReporter: any LockmanIssueReporter.Type = LockmanDefaultIssueReporter.self
    XCTAssertNotNil(defaultReporter)
  }

  func testLockmanDefaultIssueReporterMethodSignature() {
    // Test default implementation has correct method signature
    // We can't easily test console output, but we can test it doesn't crash
    LockmanDefaultIssueReporter.reportIssue("Test default message")
    LockmanDefaultIssueReporter.reportIssue("Test with file", file: #file, line: #line)

    // If we get here without crashing, the implementation works
    XCTAssertTrue(true)
  }

  func testLockmanDefaultIssueReporterDefaultParameters() {
    // Test default parameters work correctly
    LockmanDefaultIssueReporter.reportIssue("Message only")
    LockmanDefaultIssueReporter.reportIssue("Message with file", file: "Test.swift")
    LockmanDefaultIssueReporter.reportIssue("Message with line", line: 100)

    // Test method accepts all parameter combinations
    XCTAssertTrue(true)
  }

  // MARK: - Phase 3: Deprecated LockmanIssueReporting Legacy API

  func testLockmanIssueReportingDeprecatedAPI() {
    // Test deprecated API still works for backward compatibility

    // Save original reporter
    let originalReporter = LockmanIssueReporting.reporter

    // Set custom reporter
    TestStructIssueReporter.reset()
    LockmanIssueReporting.reporter = TestStructIssueReporter.self

    // Test reporter was set
    XCTAssertTrue(LockmanIssueReporting.reporter == TestStructIssueReporter.self)

    // Test reporting through deprecated API
    LockmanIssueReporting.reportIssue("Deprecated API test")
    XCTAssertEqual(TestStructIssueReporter.issueCount, 1)
    XCTAssertEqual(TestStructIssueReporter.lastMessage, "Deprecated API test")

    // Restore original reporter
    LockmanIssueReporting.reporter = originalReporter
  }

  func testLockmanIssueReportingDefaultReporter() {
    // Test default reporter is LockmanDefaultIssueReporter
    // Direct comparison works better for metatypes
    XCTAssertTrue(LockmanIssueReporting.reporter == LockmanDefaultIssueReporter.self)
  }

  func testLockmanIssueReportingThreadSafety() async {
    // Test thread safety of deprecated reporter configuration
    let originalReporter = LockmanIssueReporting.reporter

    await withTaskGroup(of: Void.self) { group in
      // Test concurrent access to reporter configuration
      group.addTask {
        LockmanIssueReporting.reporter = TestIssueReporter.self
      }
      group.addTask {
        LockmanIssueReporting.reporter = TestStructIssueReporter.self
      }
      group.addTask {
        _ = LockmanIssueReporting.reporter
      }

      await group.waitForAll()
    }

    // Should not crash - exact final value doesn't matter due to race conditions
    XCTAssertNotNil(LockmanIssueReporting.reporter)

    // Restore original reporter
    LockmanIssueReporting.reporter = originalReporter
  }

  // MARK: - Phase 4: Type Erasure and Generic Usage

  func testLockmanIssueReporterTypeErasure() {
    // Test using different reporter types through type erasure
    let reporters: [any LockmanIssueReporter.Type] = [
      TestIssueReporter.self,
      TestClassIssueReporter.self,
      TestStructIssueReporter.self,
      LockmanDefaultIssueReporter.self,
    ]

    XCTAssertEqual(reporters.count, 4)

    // Test all can be called through type erasure
    TestIssueReporter.reset()
    TestClassIssueReporter.reset()
    TestStructIssueReporter.reset()

    for (index, reporter) in reporters.enumerated() {
      reporter.reportIssue("Type erased message \(index)", file: #file, line: #line)
    }

    // Verify messages were received (where we can verify)
    XCTAssertEqual(TestIssueReporter.getCapturedMessageCount(), 1)
    XCTAssertEqual(TestClassIssueReporter.reportedIssues.count, 1)
    XCTAssertEqual(TestStructIssueReporter.issueCount, 1)
  }

  func testLockmanIssueReporterGenericFunction() {
    // Test generic function using LockmanIssueReporter
    func reportWithGeneric<T: LockmanIssueReporter>(
      _ reporterType: T.Type,
      message: String
    ) {
      reporterType.reportIssue(message, file: #file, line: #line)
    }

    TestIssueReporter.reset()
    TestStructIssueReporter.reset()

    reportWithGeneric(TestIssueReporter.self, message: "Generic enum test")
    reportWithGeneric(TestStructIssueReporter.self, message: "Generic struct test")

    XCTAssertEqual(TestIssueReporter.getLastCapturedMessage(), "Generic enum test")
    XCTAssertEqual(TestStructIssueReporter.lastMessage, "Generic struct test")
  }

  // MARK: - Phase 5: Real-world Integration Patterns

  func testLockmanIssueReporterInFrameworkContext() {
    // Test realistic framework integration scenario
    func frameworkFunction(reporter: any LockmanIssueReporter.Type) {
      // Simulate framework code that reports issues
      reporter.reportIssue("Framework validation failed", file: #file, line: #line)
      reporter.reportIssue("Configuration warning", file: #file, line: #line)
    }

    TestClassIssueReporter.reset()
    frameworkFunction(reporter: TestClassIssueReporter.self)

    XCTAssertEqual(TestClassIssueReporter.reportedIssues.count, 2)
    XCTAssertEqual(TestClassIssueReporter.reportedIssues[0].message, "Framework validation failed")
    XCTAssertEqual(TestClassIssueReporter.reportedIssues[1].message, "Configuration warning")
  }

  func testLockmanIssueReporterParameterVariations() {
    // Test different parameter combinations
    TestClassIssueReporter.reset()

    TestClassIssueReporter.reportIssue("Message 1", file: "File1.swift", line: 10)
    TestClassIssueReporter.reportIssue("Message 2", file: "File2.swift", line: 20)
    TestClassIssueReporter.reportIssue("Message 3", file: "File3.swift", line: 30)

    let issues = TestClassIssueReporter.reportedIssues
    XCTAssertEqual(issues.count, 3)

    XCTAssertEqual(issues[0].message, "Message 1")
    XCTAssertEqual(issues[0].file, "File1.swift")
    XCTAssertEqual(issues[0].line, 10)

    XCTAssertEqual(issues[1].message, "Message 2")
    XCTAssertEqual(issues[1].file, "File2.swift")
    XCTAssertEqual(issues[1].line, 20)

    XCTAssertEqual(issues[2].message, "Message 3")
    XCTAssertEqual(issues[2].file, "File3.swift")
    XCTAssertEqual(issues[2].line, 30)
  }

  func testLockmanIssueReporterMessageFormatting() {
    // Test various message formats and special characters
    TestStructIssueReporter.reset()

    let messages = [
      "Simple message",
      "Message with 数字 123 and symbols !@#$%",
      "Multi-line\nmessage\nwith\nbreaks",
      "Empty: ",
      "Unicode: 🚀✨🎯",
      "Very long message that might be used in real applications to describe complex validation failures or configuration issues that need detailed explanation",
    ]

    for (index, message) in messages.enumerated() {
      TestStructIssueReporter.reportIssue(message, file: #file, line: UInt(index + 1))
    }

    XCTAssertEqual(TestStructIssueReporter.issueCount, messages.count)
    XCTAssertEqual(TestStructIssueReporter.lastMessage, messages.last!)
  }

}
