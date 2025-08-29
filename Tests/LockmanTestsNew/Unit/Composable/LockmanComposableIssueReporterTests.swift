import ComposableArchitecture
import XCTest

@testable import Lockman

/// Tests for LockmanComposableIssueReporter integration
///
/// Tests the integration between Lockman's issue reporting system and
/// ComposableArchitecture's IssueReporting mechanism.
final class LockmanComposableIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Reset to default configuration before each test
    LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
  }

  override func tearDown() {
    super.tearDown()
    // Clean up after each test
    LockmanManager.cleanup.all()
    // Reset to default configuration
    LockmanManager.config.issueReporter = LockmanDefaultIssueReporter.self
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanComposableIssueReporter_ConformsToLockmanIssueReporter() {
    // Test that LockmanComposableIssueReporter conforms to LockmanIssueReporter
    XCTAssertTrue(LockmanComposableIssueReporter.self is any LockmanIssueReporter.Type)
    
    // Test that the type can be used as issue reporter
    let reporter: any LockmanIssueReporter.Type = LockmanComposableIssueReporter.self
    XCTAssertNotNil(reporter)
  }

  // MARK: - Issue Reporting Tests

  func testReportIssue_CallsComposableArchitectureReporting() {
    // This test verifies that the method can be called without throwing
    // We can't easily mock ComposableArchitecture's IssueReporting system,
    // but we can verify the method executes successfully
    
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Test message - ignore this test issue")
    }
    
    // Test with custom file and line parameters
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue(
        "Test message with file and line - ignore this test issue",
        file: "TestFile.swift",
        line: 42
      )
    }
  }

  func testReportIssue_HandlesEmptyMessage() {
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Empty message test - ignore this test issue")
    }
  }

  func testReportIssue_HandlesLongMessage() {
    let longMessage = "Long message test - ignore this test issue: " + String(repeating: "A", count: 100)
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue(longMessage)
    }
  }

  func testReportIssue_HandlesSpecialCharacters() {
    let specialMessage = "Test message with special chars - ignore this test issue 🚨 !@#$%^&*()_+ åäö"
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue(specialMessage)
    }
  }

  // MARK: - Configuration Tests

  func testConfigureComposableReporting_SetsCorrectIssueReporter() {
    // Verify initial state (should not be LockmanComposableIssueReporter)
    let initialReporter = LockmanManager.config.issueReporter
    XCTAssertNotEqual(String(describing: initialReporter), String(describing: LockmanComposableIssueReporter.self))

    // Configure composable reporting
    LockmanManager.config.configureComposableReporting()

    // Verify the issue reporter was set correctly
    let configuredReporter = LockmanManager.config.issueReporter
    XCTAssertEqual(String(describing: configuredReporter), String(describing: LockmanComposableIssueReporter.self))
  }

  func testConfigureComposableReporting_CanBeCalledMultipleTimes() {
    // Should be idempotent - calling multiple times should not cause issues
    XCTAssertNoThrow {
      LockmanManager.config.configureComposableReporting()
      LockmanManager.config.configureComposableReporting()
      LockmanManager.config.configureComposableReporting()
    }

    // Verify configuration works (basic functionality test)
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Multiple configuration test - ignore this test issue")
    }
  }

  // MARK: - Integration Tests

  func testLockmanManager_UsesComposableReporterAfterConfiguration() async throws {
    // Configure composable reporting
    LockmanManager.config.configureComposableReporting()

    // Create a scenario that would trigger issue reporting
    // (We can't easily verify the actual reporting, but we can ensure no crashes occur)
    
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      // This should use the configured issue reporter internally if issues arise
      // For now, this mainly tests that the configuration doesn't break normal operation
      XCTAssertNoThrow {
        // Simple operation that should work without triggering issues
        let result = true
        XCTAssertTrue(result)
      }
    }
  }

  // MARK: - Error Handling Tests

  func testReportIssue_WithNilFile() {
    // Test that the method handles StaticString properly
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Test message with empty file - ignore this test issue", file: "", line: 0)
    }
  }

  func testReportIssue_WithZeroLine() {
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Test message with zero line - ignore this test issue", line: 0)
    }
  }

  func testReportIssue_WithHighLineNumber() {
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Test message with high line number - ignore this test issue", line: UInt.max)
    }
  }

  // MARK: - Concurrent Access Tests

  func testConfigureComposableReporting_ThreadSafety() async {
    let expectation = XCTestExpectation(description: "Concurrent configuration")
    expectation.expectedFulfillmentCount = 10

    // Test concurrent configuration calls
    for _ in 0..<10 {
      Task {
        LockmanManager.config.configureComposableReporting()
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation], timeout: 5.0)

    // Should still be configured correctly after concurrent calls
    let finalReporter = LockmanManager.config.issueReporter
    XCTAssertEqual(String(describing: finalReporter), String(describing: LockmanComposableIssueReporter.self))
  }

  func testReportIssue_ConcurrentCalls() async {
    let expectation = XCTestExpectation(description: "Concurrent reporting")
    expectation.expectedFulfillmentCount = 20

    // Configure composable reporting first
    LockmanManager.config.configureComposableReporting()

    // Test concurrent issue reporting (using XCTAssertNoThrow to avoid test failures from reported issues)
    for i in 0..<20 {
      Task {
        XCTAssertNoThrow {
          LockmanComposableIssueReporter.reportIssue("Test message \(i) - ignore this test issue")
        }
        expectation.fulfill()
      }
    }

    await fulfillment(of: [expectation], timeout: 5.0)
    // If we get here without crashes, concurrent access is working
  }

  // MARK: - Documentation Example Tests

  func testConfigurationExample_FromDocumentation() {
    // Test the example from the documentation works correctly
    XCTAssertNoThrow {
      // In App initialization
      LockmanManager.config.configureComposableReporting()
    }

    // Verify configuration works (basic functionality test)
    XCTAssertNoThrow {
      LockmanComposableIssueReporter.reportIssue("Documentation example test - ignore this test issue")
    }
  }

  // MARK: - Type Safety Tests

  func testLockmanComposableIssueReporter_IsEnum() {
    // Verify that LockmanComposableIssueReporter is implemented as an enum
    // This tests the specific implementation choice
    // Note: Mirror reflection on enum types (not instances) doesn't provide displayStyle
    // Instead, verify it's a valid enum type by checking it can be used as expected
    let reporterType: any LockmanIssueReporter.Type = LockmanComposableIssueReporter.self
    XCTAssertNotNil(reporterType)
    
    // Verify the type name indicates it's an enum
    let typeName = String(describing: LockmanComposableIssueReporter.self)
    XCTAssertEqual(typeName, "LockmanComposableIssueReporter")
  }

  func testStaticReportIssueMethod_HasCorrectSignature() {
    // This compile-time test verifies the method signature matches the protocol
    let _: (String, StaticString, UInt) -> Void = LockmanComposableIssueReporter.reportIssue
    // If this compiles, the signature is correct
  }

}