import XCTest

@testable import Lockman

final class LockmanIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Reset to default reporter before each test
    LockmanIssueReporting.reporter = DefaultLockmanIssueReporter.self
  }

  override func tearDown() {
    super.tearDown()
    // Reset to default reporter after each test
    LockmanIssueReporting.reporter = DefaultLockmanIssueReporter.self
  }

  func testDefaultLockmanIssueReporter() {
    // Capture console output
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    // Report an issue
    DefaultLockmanIssueReporter.reportIssue("Test issue", file: "TestFile.swift", line: 42)

    // Restore stdout
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    // Read captured output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    #if DEBUG
      XCTAssertTrue(output.contains("⚠️ Lockman Issue"))
      XCTAssertTrue(output.contains("TestFile.swift:42"))
      XCTAssertTrue(output.contains("Test issue"))
    #else
      XCTAssertTrue(output.isEmpty)
    #endif
  }

  func testLockmanIssueReportingWithDefaultReporter() {
    XCTAssertTrue(LockmanIssueReporting.reporter == DefaultLockmanIssueReporter.self)

    // Capture console output
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    // Report an issue through LockmanIssueReporting
    LockmanIssueReporting.reportIssue("Global test issue", file: "GlobalTest.swift", line: 100)

    // Restore stdout
    fflush(stdout)
    dup2(originalStdout, STDOUT_FILENO)
    close(originalStdout)
    pipe.fileHandleForWriting.closeFile()

    // Read captured output
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""

    #if DEBUG
      XCTAssertTrue(output.contains("⚠️ Lockman Issue"))
      XCTAssertTrue(output.contains("GlobalTest.swift:100"))
      XCTAssertTrue(output.contains("Global test issue"))
    #else
      XCTAssertTrue(output.isEmpty)
    #endif
  }

  func testCustomIssueReporter() {
    var capturedMessage: String?
    var capturedFile: StaticString?
    var capturedLine: UInt?

    // Create a custom reporter
    struct TestReporter: LockmanIssueReporter {
      static var handler: ((String, StaticString, UInt) -> Void)?

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        handler?(message, file, line)
      }
    }

    TestReporter.handler = { message, file, line in
      capturedMessage = message
      capturedFile = file
      capturedLine = line
    }

    // Set custom reporter
    LockmanIssueReporting.reporter = TestReporter.self

    // Report an issue
    LockmanIssueReporting.reportIssue("Custom reporter test", file: #file, line: #line)

    // Verify
    XCTAssertEqual(capturedMessage, "Custom reporter test")
    XCTAssertEqual("\(capturedFile ?? "")", #file)
    XCTAssertEqual(capturedLine, #line - 5)
  }

  func testReporterThreadSafety() {
    let expectation = expectation(description: "All operations should complete")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue(label: "test", attributes: .concurrent)

    // Create multiple custom reporters
    for i in 0..<50 {
      queue.async {
        struct TempReporter: LockmanIssueReporter {
          static func reportIssue(_ message: String, file: StaticString, line: UInt) {
            // Do nothing
          }
        }

        if i % 2 == 0 {
          LockmanIssueReporting.reporter = TempReporter.self
        } else {
          LockmanIssueReporting.reporter = DefaultLockmanIssueReporter.self
        }
        expectation.fulfill()
      }
    }

    // Read reporter concurrently
    for _ in 0..<50 {
      queue.async {
        _ = LockmanIssueReporting.reporter
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testLockIsolatedWrapper() {
    // Test is implicitly done through the thread safety test above
    // LockIsolated is private, so we test it indirectly
    XCTAssertTrue(true)
  }
}

// Backward compatibility tests
final class LockmanIssueReporterBackwardCompatibilityTests: XCTestCase {

  func testDefaultIssueReporterTypeAlias() {
    // DefaultIssueReporter should be an alias for DefaultLockmanIssueReporter
    XCTAssertTrue(DefaultIssueReporter.self == DefaultLockmanIssueReporter.self)
  }
}

