import ComposableArchitecture
import XCTest

@testable import Lockman

final class ComposableIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Reset to default reporter before each test
    LockmanIssueReporting.reporter = DefaultIssueReporter.self
  }

  override func tearDown() {
    super.tearDown()
    // Reset to default reporter after each test
    LockmanIssueReporting.reporter = DefaultIssueReporter.self
  }

  func testComposableIssueReporterCallsIssueReporting() {
    let expectation = expectation(description: "Issue should be reported")
    var reportedMessage: String?
    var reportedFile: StaticString?
    var reportedLine: UInt?

    // Temporarily override IssueReporting for testing
    let originalReportIssue = IssueReporting.reportIssue
    IssueReporting.reportIssue = { message, fileID, line in
      reportedMessage = message()
      reportedFile = fileID
      reportedLine = line
      expectation.fulfill()
    }

    defer {
      IssueReporting.reportIssue = originalReportIssue
    }

    // Test
    LockmanComposableIssueReporter.reportIssue("Test issue message", file: #file, line: #line)

    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(reportedMessage, "Test issue message")
    XCTAssertEqual("\(reportedFile ?? "")", #file)
    XCTAssertEqual(reportedLine, #line - 5)
  }

  func testConfigureComposableReporting() {
    // Initially should be DefaultIssueReporter
    XCTAssertTrue(LockmanIssueReporting.reporter == DefaultIssueReporter.self)

    // Configure to use ComposableIssueReporter
    LockmanIssueReporting.configureComposableReporting()

    // Should now be LockmanComposableIssueReporter
    XCTAssertTrue(LockmanIssueReporting.reporter == LockmanComposableIssueReporter.self)
  }

  func testComposableReporterIntegration() {
    // Configure Lockman to use ComposableIssueReporter
    LockmanIssueReporting.configureComposableReporting()

    let expectation = expectation(description: "Issue should be reported through Lockman")
    var reportedMessage: String?

    // Temporarily override IssueReporting for testing
    let originalReportIssue = IssueReporting.reportIssue
    IssueReporting.reportIssue = { message, fileID, line in
      reportedMessage = message()
      expectation.fulfill()
    }

    defer {
      IssueReporting.reportIssue = originalReportIssue
    }

    // Use LockmanIssueReporting which should now use LockmanComposableIssueReporter
    LockmanIssueReporting.reportIssue("Integration test message")

    wait(for: [expectation], timeout: 1.0)

    XCTAssertEqual(reportedMessage, "Integration test message")
  }
}
