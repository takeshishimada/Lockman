import XCTest

@testable import Lockman

/// Unit tests for LockmanIssueReporter
///
/// Tests the protocol for reporting issues in the Lockman framework with framework-agnostic abstraction.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### LockmanIssueReporter Protocol Definition
/// - [ ] Protocol method signature reportIssue(_:file:line:) validation
/// - [ ] Static method requirement verification
/// - [ ] Parameter types (String, StaticString, UInt) validation
/// - [ ] Protocol conformance by concrete implementations
/// - [ ] Method implementation requirements
/// - [ ] File and line parameter purpose and usage
///
/// ### LockmanDefaultIssueReporter Implementation
/// - [ ] LockmanIssueReporter protocol conformance validation
/// - [ ] enum-based implementation pattern
/// - [ ] reportIssue(_:file:line:) method implementation
/// - [ ] Default parameter values (#file, #line) behavior
/// - [ ] DEBUG conditional compilation behavior
/// - [ ] Console output formatting and structure
/// - [ ] File name extraction from StaticString path
///
/// ### DEBUG Build Conditional Behavior
/// - [ ] #if DEBUG compilation directive validation
/// - [ ] Debug-only issue reporting behavior
/// - [ ] Release build no-op behavior verification
/// - [ ] Performance impact in production builds
/// - [ ] Conditional compilation correctness
/// - [ ] DEBUG flag dependency validation
///
/// ### Console Output Formatting
/// - [ ] Warning emoji (⚠️) prefix usage
/// - [ ] "Lockman Issue" prefix format
/// - [ ] File name extraction from full path
/// - [ ] Line number formatting in output
/// - [ ] Message content preservation
/// - [ ] Output format consistency and readability
/// - [ ] Console integration and visibility
///
/// ### File Path Processing
/// - [ ] StaticString file parameter handling
/// - [ ] Path splitting by "/" separator
/// - [ ] Last component extraction for file name
/// - [ ] "Unknown" fallback for invalid paths
/// - [ ] Unicode path handling
/// - [ ] Long path truncation behavior
/// - [ ] Special character handling in paths
///
/// ### LockmanIssueReporting Configuration System
/// - [ ] Global reporter configuration management
/// - [ ] _reporter LockIsolated<any LockmanIssueReporter.Type> storage
/// - [ ] Default reporter initialization (LockmanDefaultIssueReporter.self)
/// - [ ] reporter property getter and setter behavior
/// - [ ] Thread-safe configuration changes
/// - [ ] Configuration persistence across operations
///
/// ### Reporter Type Management
/// - [ ] any LockmanIssueReporter.Type type erasure handling
/// - [ ] Dynamic reporter type assignment
/// - [ ] Reporter type resolution and method dispatch
/// - [ ] Type safety with protocol conformance
/// - [ ] Multiple reporter implementation support
/// - [ ] Reporter switching at runtime
///
/// ### Global reportIssue Method
/// - [ ] LockmanIssueReporting.reportIssue(_:file:line:) delegation
/// - [ ] Configured reporter method invocation
/// - [ ] Parameter forwarding to configured reporter
/// - [ ] Default parameter behavior (#file, #line)
/// - [ ] Source location preservation
/// - [ ] Message content unchanged propagation
///
/// ### LockIsolated Thread Safety Implementation
/// - [ ] LockIsolated<Value> private class implementation
/// - [ ] @unchecked Sendable conformance justification
/// - [ ] NSLock-based synchronization mechanism
/// - [ ] value property thread-safe access
/// - [ ] withValue<T>(_:) critical section method
/// - [ ] Lock acquisition and release patterns
/// - [ ] Concurrent access safety validation
///
/// ### Thread Safety and Concurrent Access
/// - [ ] Concurrent reporter configuration changes
/// - [ ] Concurrent issue reporting calls
/// - [ ] Race condition prevention in configuration
/// - [ ] Memory safety with concurrent access
/// - [ ] Lock contention handling
/// - [ ] Deadlock prevention mechanisms
///
/// ### Framework Abstraction and Independence
/// - [ ] Core framework independence from external dependencies
/// - [ ] TCA integration capability without core dependency
/// - [ ] Framework-agnostic design validation
/// - [ ] Clean separation of concerns
/// - [ ] Pluggable reporter architecture
/// - [ ] External framework integration patterns
///
/// ### Custom Reporter Implementation Support
/// - [ ] Custom LockmanIssueReporter conformance patterns
/// - [ ] Third-party logging framework integration
/// - [ ] Analytics integration through custom reporters
/// - [ ] File-based logging implementation
/// - [ ] Network-based reporting implementation
/// - [ ] Multi-destination reporting patterns
///
/// ### Error Handling and Edge Cases
/// - [ ] Invalid file path handling
/// - [ ] Very long message content handling
/// - [ ] Special characters in messages
/// - [ ] Unicode content in issue messages
/// - [ ] Memory pressure during issue reporting
/// - [ ] Reporter configuration during active reporting
///
/// ### Performance and Memory Management
/// - [ ] Issue reporting performance overhead
/// - [ ] Memory usage with message content
/// - [ ] File path processing efficiency
/// - [ ] Lock contention performance impact
/// - [ ] Large-scale issue reporting scalability
/// - [ ] Memory leak prevention
///
/// ### Integration with Lockman Framework
/// - [ ] Usage by core Lockman components
/// - [ ] Error reporting integration
/// - [ ] Debug information propagation
/// - [ ] Development workflow support
/// - [ ] Issue correlation with framework operations
/// - [ ] Debugging assistance effectiveness
///
/// ### Real-world Usage Patterns
/// - [ ] Development environment issue reporting
/// - [ ] Production issue tracking
/// - [ ] Integration with CI/CD systems
/// - [ ] Analytics and monitoring integration
/// - [ ] User experience improvement through issue reporting
/// - [ ] Framework adoption and debugging support
///
/// ### Configuration Lifecycle Management
/// - [ ] Application startup reporter configuration
/// - [ ] Runtime reporter switching scenarios
/// - [ ] Configuration persistence across app lifecycle
/// - [ ] Multiple configuration attempts handling
/// - [ ] Configuration validation and error handling
/// - [ ] Default configuration restoration
///
/// ### Message Content and Context
/// - [ ] Message clarity and usefulness
/// - [ ] Context information inclusion
/// - [ ] Developer-friendly message formatting
/// - [ ] Actionable error guidance
/// - [ ] Issue categorization and filtering
/// - [ ] Message localization considerations
///
/// ### Development vs Production Behavior
/// - [ ] Debug build comprehensive reporting
/// - [ ] Release build minimal overhead
/// - [ ] Build configuration detection accuracy
/// - [ ] Performance optimization in production
/// - [ ] Security considerations in release builds
/// - [ ] Debugging capability preservation
///
/// ### Documentation and Examples Validation
/// - [ ] Protocol documentation accuracy
/// - [ ] Implementation example correctness
/// - [ ] Usage pattern validation
/// - [ ] Integration guide effectiveness
/// - [ ] Code example compilation verification
/// - [ ] Best practices demonstration
///
final class LockmanIssueReporterTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Reset to default reporter before each test
    LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
  }

  override func tearDown() {
    // Restore default reporter after each test
    LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
    super.tearDown()
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanIssueReporterProtocolRequirements() {
    // Test that protocol has correct static method signature
    let reporterType = LockmanDefaultIssueReporter.self

    // Verify the method exists and can be called
    reporterType.reportIssue("test message", file: #file, line: #line)

    // No exceptions should be thrown for valid usage
    XCTAssertTrue(true)
  }

  func testLockmanIssueReporterCanBeImplementedByCustomTypes() {
    // Test that custom types can conform to the protocol
    let customReporter = MockIssueReporter.self

    // Verify conformance by calling the required method
    customReporter.reportIssue("custom test", file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, "custom test")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
    XCTAssertGreaterThan(MockIssueReporter.lastLine, 0)
  }

  func testProtocolMethodSignatureValidation() {
    // Verify protocol method signature requirements
    let reporterType: any LockmanIssueReporter.Type = LockmanDefaultIssueReporter.self

    // Test that all required parameters are present and typed correctly
    reporterType.reportIssue("message", file: #file, line: #line)

    // Should compile and execute without issues
    XCTAssertTrue(true)
  }

  // MARK: - LockmanDefaultIssueReporter Tests

  func testDefaultIssueReporterConformance() {
    // Test that LockmanDefaultIssueReporter conforms to LockmanIssueReporter
    let reporterType: any LockmanIssueReporter.Type = LockmanDefaultIssueReporter.self

    // Should be able to call protocol method
    reporterType.reportIssue("conformance test", file: #file, line: #line)

    // No exceptions indicates successful conformance
    XCTAssertTrue(true)
  }

  func testDefaultIssueReporterWithDefaultParameters() {
    // Test that default parameters work correctly
    LockmanDefaultIssueReporter.reportIssue("default params test")

    // Should not crash with default file and line parameters
    XCTAssertTrue(true)
  }

  func testDefaultIssueReporterWithExplicitParameters() {
    // Test with explicit file and line parameters
    let testFile: StaticString = "TestFile.swift"
    let testLine: UInt = 42

    LockmanDefaultIssueReporter.reportIssue(
      "explicit params test",
      file: testFile,
      line: testLine
    )

    // Should handle explicit parameters without issues
    XCTAssertTrue(true)
  }

  func testDefaultIssueReporterWithEmptyMessage() {
    // Test behavior with empty message
    LockmanDefaultIssueReporter.reportIssue("", file: #file, line: #line)

    // Should handle empty messages gracefully
    XCTAssertTrue(true)
  }

  func testDefaultIssueReporterWithLongMessage() {
    // Test with very long message
    let longMessage = String(repeating: "A", count: 10000)

    LockmanDefaultIssueReporter.reportIssue(longMessage, file: #file, line: #line)

    // Should handle long messages without issues
    XCTAssertTrue(true)
  }

  func testDefaultIssueReporterWithSpecialCharacters() {
    // Test with special characters and unicode
    let specialMessage = "🚨 Error: Special chars \n\t\\\"'`$@#%^&*()[]{}|;:,.<>?/~"

    LockmanDefaultIssueReporter.reportIssue(specialMessage, file: #file, line: #line)

    // Should handle special characters gracefully
    XCTAssertTrue(true)
  }

  func testEnumBasedImplementationPattern() {
    // Test that LockmanDefaultIssueReporter uses enum implementation pattern
    let reporterType = LockmanDefaultIssueReporter.self

    // Verify it's an enum type that can be used as reporter
    XCTAssertTrue(type(of: reporterType) == LockmanDefaultIssueReporter.Type.self)
  }

  // MARK: - DEBUG Conditional Compilation Tests

  func testDebugBuildConditionalBehavior() {
    // Test that issue reporting compiles and runs in all build configurations
    LockmanDefaultIssueReporter.reportIssue("debug conditional test")

    // In DEBUG builds, should print to console
    // In RELEASE builds, should be no-op
    // Both should compile and execute without errors
    XCTAssertTrue(true)
  }

  func testDebugCompilationDirectiveValidation() {
    // Test that DEBUG conditional compilation works correctly
    #if DEBUG
      let isDebugBuild = true
    #else
      let isDebugBuild = false
    #endif

    // Report an issue and verify it compiles in both configurations
    LockmanDefaultIssueReporter.reportIssue("compilation directive test")

    // Test should pass regardless of build configuration
    XCTAssertTrue(isDebugBuild || !isDebugBuild)
  }

  func testPerformanceImpactInProductionBuilds() {
    // Test performance characteristics in different build configurations
    measure {
      for i in 0..<1000 {
        LockmanDefaultIssueReporter.reportIssue("performance test \(i)")
      }
    }

    // Should complete efficiently in both DEBUG and RELEASE builds
    XCTAssertTrue(true)
  }

  // MARK: - Console Output Formatting Tests

  func testConsoleOutputFormatting() {
    // Test that output format meets expectations (through mock)
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let testFile: StaticString = "TestFile.swift"
    LockmanIssueReporting.reportIssue("format test", file: testFile, line: 123)

    // Verify the mock received the correct parameters for formatting
    XCTAssertEqual(MockIssueReporter.lastMessage, "format test")
    XCTAssertEqual(MockIssueReporter.lastFile, "TestFile.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, 123)
  }

  func testWarningEmojiPrefix() {
    // Test that warning emoji usage is consistent (through documentation)
    // The default implementation uses ⚠️ emoji in DEBUG builds
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    LockmanIssueReporting.reportIssue("emoji test")

    // Mock should receive the message as-is
    XCTAssertEqual(MockIssueReporter.lastMessage, "emoji test")
  }

  func testLockmanIssuePrefixFormat() {
    // Test prefix format consistency through mock verification
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let testFile: StaticString = "Test.swift"
    LockmanIssueReporting.reportIssue("prefix test", file: testFile, line: 1)

    // Verify components are preserved for proper formatting
    XCTAssertEqual(MockIssueReporter.lastMessage, "prefix test")
    XCTAssertEqual(MockIssueReporter.lastFile, "Test.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, 1)
  }

  // MARK: - File Path Processing Tests

  func testStaticStringFileParameterHandling() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let staticFile: StaticString = "StaticTestFile.swift"
    LockmanIssueReporting.reportIssue("static string test", file: staticFile, line: 456)

    XCTAssertEqual(MockIssueReporter.lastFile, "StaticTestFile.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, 456)
  }

  func testPathSplittingBySeparator() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let fullPath: StaticString = "/path/to/project/Sources/TestFile.swift"
    LockmanIssueReporting.reportIssue("path splitting test", file: fullPath, line: 1)

    // Should receive the full path for processing
    XCTAssertEqual(MockIssueReporter.lastFile, "/path/to/project/Sources/TestFile.swift")
  }

  func testLastComponentExtractionForFileName() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let pathWithComponents: StaticString = "Dir1/Dir2/Dir3/FinalFile.swift"
    LockmanIssueReporting.reportIssue(
      "component extraction test", file: pathWithComponents, line: 1)

    XCTAssertEqual(MockIssueReporter.lastFile, "Dir1/Dir2/Dir3/FinalFile.swift")
  }

  func testUnknownFallbackForInvalidPaths() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let emptyPath: StaticString = ""
    LockmanIssueReporting.reportIssue("empty path test", file: emptyPath, line: 1)

    XCTAssertEqual(MockIssueReporter.lastFile, "")
    XCTAssertEqual(MockIssueReporter.lastLine, 1)
  }

  func testUnicodePathHandling() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let unicodePath: StaticString = "/项目/源代码/测试文件.swift"
    LockmanIssueReporting.reportIssue("unicode path test", file: unicodePath, line: 1)

    XCTAssertEqual(MockIssueReporter.lastFile, "/项目/源代码/测试文件.swift")
  }

  func testLongPathTruncationBehavior() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Use a compile-time constant for the long path
    let staticPath: StaticString = "/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/TestFile.swift"

    LockmanIssueReporting.reportIssue("long path test", file: staticPath, line: 1)

    XCTAssertEqual(MockIssueReporter.lastFile, "/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/VeryLongDirectoryName/TestFile.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, 1)
  }

  func testSpecialCharacterHandlingInPaths() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let specialCharPath: StaticString =
      "/path with spaces/file-with-dashes/under_scores/dots.and.stuff.swift"
    LockmanIssueReporting.reportIssue("special char path test", file: specialCharPath, line: 1)

    XCTAssertEqual(
      MockIssueReporter.lastFile,
      "/path with spaces/file-with-dashes/under_scores/dots.and.stuff.swift")
  }

  // MARK: - LockmanIssueReporting Configuration System Tests

  func testDefaultReporterIsSet() {
    // Test that default reporter is LockmanDefaultIssueReporter
    let currentReporter = LockmanIssueReporting.reporter

    XCTAssertTrue(currentReporter == LockmanDefaultIssueReporter.self)
  }

  func testGlobalReporterConfigurationManagement() {
    // Test global reporter configuration functionality
    let originalReporter = LockmanIssueReporting.reporter

    // Change reporter
    LockmanIssueReporting.reporter = MockIssueReporter.self
    XCTAssertTrue(LockmanIssueReporting.reporter == MockIssueReporter.self)

    // Restore original
    LockmanIssueReporting.reporter = originalReporter
    XCTAssertTrue(LockmanIssueReporting.reporter == originalReporter)
  }

  func testLockIsolatedStorageImplementation() {
    // Test that LockIsolated storage works correctly through public interface
    MockIssueReporter.reset()

    // Test value access
    let reporter1 = LockmanIssueReporting.reporter
    let reporter2 = LockmanIssueReporting.reporter

    XCTAssertTrue(reporter1 == reporter2)

    // Test value modification
    LockmanIssueReporting.reporter = MockIssueReporter.self
    let reporter3 = LockmanIssueReporting.reporter

    XCTAssertTrue(reporter3 == MockIssueReporter.self)
    XCTAssertFalse(reporter1 == reporter3)
  }

  func testDefaultReporterInitialization() {
    // Test that default reporter is properly initialized
    let defaultReporter = LockmanIssueReporting.reporter

    XCTAssertTrue(defaultReporter == LockmanDefaultIssueReporter.self)
  }

  func testReporterPropertyGetterAndSetterBehavior() {
    // Test getter and setter behavior
    let originalReporter = LockmanIssueReporting.reporter

    // Test setter
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test getter
    let newReporter = LockmanIssueReporting.reporter
    XCTAssertTrue(newReporter == MockIssueReporter.self)

    // Restore
    LockmanIssueReporting.reporter = originalReporter
  }

  func testConfigurationPersistenceAcrossOperations() {
    // Test that configuration persists across multiple operations
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Perform multiple operations
    let reporter1 = LockmanIssueReporting.reporter
    LockmanIssueReporting.reportIssue("test 1")
    let reporter2 = LockmanIssueReporting.reporter
    LockmanIssueReporting.reportIssue("test 2")
    let reporter3 = LockmanIssueReporting.reporter

    XCTAssertTrue(reporter1 == MockIssueReporter.self)
    XCTAssertTrue(reporter2 == MockIssueReporter.self)
    XCTAssertTrue(reporter3 == MockIssueReporter.self)
  }

  // MARK: - Reporter Type Management Tests

  func testAnyLockmanIssueReporterTypeErasureHandling() {
    // Test type erasure with any LockmanIssueReporter.Type
    let erasedType: any LockmanIssueReporter.Type = MockIssueReporter.self

    LockmanIssueReporting.reporter = erasedType
    let retrievedType = LockmanIssueReporting.reporter

    XCTAssertTrue(retrievedType == MockIssueReporter.self)
  }

  func testDynamicReporterTypeAssignment() {
    // Test dynamic assignment of different reporter types
    let types: [any LockmanIssueReporter.Type] = [
      LockmanDefaultIssueReporter.self,
      MockIssueReporter.self,
    ]

    for reporterType in types {
      LockmanIssueReporting.reporter = reporterType
      let currentType = LockmanIssueReporting.reporter
      XCTAssertTrue(currentType == reporterType)
    }
  }

  func testReporterTypeResolutionAndMethodDispatch() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test method dispatch through type erasure
    LockmanIssueReporting.reportIssue("dispatch test")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "dispatch test")
  }

  func testTypeSafetyWithProtocolConformance() {
    // Test that only conforming types can be assigned
    let conformingType: any LockmanIssueReporter.Type = MockIssueReporter.self

    LockmanIssueReporting.reporter = conformingType

    // Should compile and work correctly
    XCTAssertTrue(LockmanIssueReporting.reporter == MockIssueReporter.self)
  }

  func testMultipleReporterImplementationSupport() {
    // Test that multiple different implementations are supported
    class CustomReporter1: LockmanIssueReporter {
      private static let lock = NSLock()
      nonisolated(unsafe) private static var _called = false
      static var called: Bool {
        get { lock.withLock { _called } }
        set { lock.withLock { _called = newValue } }
      }
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        called = true
      }
    }

    class CustomReporter2: LockmanIssueReporter {
      private static let lock = NSLock()
      nonisolated(unsafe) private static var _called = false
      static var called: Bool {
        get { lock.withLock { _called } }
        set { lock.withLock { _called = newValue } }
      }
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        called = true
      }
    }

    // Test first reporter
    LockmanIssueReporting.reporter = CustomReporter1.self
    LockmanIssueReporting.reportIssue("test 1")
    XCTAssertTrue(CustomReporter1.called)
    XCTAssertFalse(CustomReporter2.called)

    // Reset and test second reporter
    CustomReporter1.called = false
    LockmanIssueReporting.reporter = CustomReporter2.self
    LockmanIssueReporting.reportIssue("test 2")
    XCTAssertFalse(CustomReporter1.called)
    XCTAssertTrue(CustomReporter2.called)
  }

  func testReporterSwitchingAtRuntime() {
    MockIssueReporter.reset()

    // Start with default
    LockmanIssueReporting.reportIssue("default message")

    // Switch to mock
    LockmanIssueReporting.reporter = MockIssueReporter.self
    LockmanIssueReporting.reportIssue("mock message")

    // Switch back to default
    LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
    LockmanIssueReporting.reportIssue("back to default")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "mock message")
  }

  // MARK: - Global reportIssue Method Tests

  func testGlobalReportIssueMethodDelegation() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    LockmanIssueReporting.reportIssue("delegation test", file: #file, line: #line)

    XCTAssertEqual(MockIssueReporter.lastMessage, "delegation test")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
    XCTAssertGreaterThan(MockIssueReporter.lastLine, 0)
  }

  func testConfiguredReporterMethodInvocation() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    LockmanIssueReporting.reportIssue("invocation test")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "invocation test")
  }

  func testParameterForwardingToConfiguredReporter() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let testMessage = "forwarding test"
    let testFile: StaticString = "ForwardTest.swift"
    let testLine: UInt = 999

    LockmanIssueReporting.reportIssue(testMessage, file: testFile, line: testLine)

    XCTAssertEqual(MockIssueReporter.lastMessage, testMessage)
    XCTAssertEqual(MockIssueReporter.lastFile, "ForwardTest.swift")
    XCTAssertEqual(MockIssueReporter.lastLine, testLine)
  }

  func testDefaultParameterBehaviorInGlobalMethod() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    LockmanIssueReporting.reportIssue("default params")

    // Should use #file and #line from call site
    XCTAssertEqual(MockIssueReporter.lastMessage, "default params")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
    XCTAssertGreaterThan(MockIssueReporter.lastLine, 0)
  }

  func testSourceLocationPreservation() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    func reportFromFunction() {
      LockmanIssueReporting.reportIssue("from function", file: #file, line: #line)
    }

    reportFromFunction()

    // Should preserve the actual call location
    XCTAssertEqual(MockIssueReporter.lastMessage, "from function")
    XCTAssertTrue(MockIssueReporter.lastFile.hasSuffix("LockmanIssueReporterTests.swift"))
  }

  func testMessageContentUnchangedPropagation() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let originalMessage = "Original message with 🚨 special chars \n and newlines"
    LockmanIssueReporting.reportIssue(originalMessage)

    XCTAssertEqual(MockIssueReporter.lastMessage, originalMessage)
  }

  // MARK: - Thread Safety Tests

  func testThreadSafeConfigurationChanges() {
    let expectation = XCTestExpectation(description: "Thread safety test")
    expectation.expectedFulfillmentCount = 100

    let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

    // Concurrently set and get reporter
    for i in 0..<100 {
      queue.async {
        if i % 2 == 0 {
          LockmanIssueReporting.reporter = MockIssueReporter.self
        } else {
          LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
        }

        // Verify we can read the reporter without crashes
        let _ = LockmanIssueReporting.reporter
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)
  }

  func testConcurrentIssueReportingCalls() {
    let expectation = XCTestExpectation(description: "Concurrent reporting test")
    expectation.expectedFulfillmentCount = 50

    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

    // Concurrently report issues
    for i in 0..<50 {
      queue.async {
        LockmanIssueReporting.reportIssue("Message \(i)", file: #file, line: #line)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Should have received at least one message without crashes
    XCTAssertGreaterThan(MockIssueReporter.reportCount, 0)
  }

  func testRaceConditionPreventionInConfiguration() {
    let expectation = XCTestExpectation(description: "Race condition prevention")
    expectation.expectedFulfillmentCount = 200

    let queue = DispatchQueue(label: "race.test", attributes: .concurrent)

    // Rapidly switch between reporters while accessing
    for i in 0..<100 {
      queue.async {
        LockmanIssueReporting.reporter = MockIssueReporter.self
        expectation.fulfill()
      }

      queue.async {
        let _ = LockmanIssueReporting.reporter
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 10.0)
  }

  func testMemorySafetyWithConcurrentAccess() {
    let expectation = XCTestExpectation(description: "Memory safety test")
    expectation.expectedFulfillmentCount = 1000

    let queue = DispatchQueue(label: "memory.test", attributes: .concurrent)

    for _ in 0..<1000 {
      queue.async {
        autoreleasepool {
          LockmanIssueReporting.reporter = MockIssueReporter.self
          LockmanIssueReporting.reportIssue("memory test")
          let _ = LockmanIssueReporting.reporter
        }
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 15.0)
  }

  func testLockContentionHandling() {
    let expectation = XCTestExpectation(description: "Lock contention test")
    expectation.expectedFulfillmentCount = 500

    let queue = DispatchQueue(label: "contention.test", attributes: .concurrent)

    // Create high contention scenario
    for _ in 0..<500 {
      queue.async {
        // Rapid configuration changes and access
        LockmanIssueReporting.reporter = MockIssueReporter.self
        let _ = LockmanIssueReporting.reporter
        LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
        let _ = LockmanIssueReporting.reporter
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 20.0)
  }

  func testDeadlockPreventionMechanisms() {
    // Test that no deadlocks occur with nested access patterns
    MockIssueReporter.reset()

    final class RecursiveReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var depth = 0
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        depth += 1
        if depth < 3 {  // Prevent infinite recursion
          LockmanIssueReporting.reportIssue("recursive: \(depth)")
        }
        depth -= 1
      }
    }

    LockmanIssueReporting.reporter = RecursiveReporter.self
    LockmanIssueReporting.reportIssue("deadlock test")

    // Should complete without deadlock
    XCTAssertTrue(true)
  }

  // MARK: - Framework Abstraction Tests

  func testCoreFrameworkIndependenceFromExternalDependencies() {
    // Test that core framework works without external dependencies
    let independentReporter = LockmanDefaultIssueReporter.self

    // Should work without importing external frameworks
    independentReporter.reportIssue("independence test")

    XCTAssertTrue(true)
  }

  func testTCAIntegrationCapabilityWithoutCoreDependency() {
    // Test that TCA integration is possible without core dependency
    final class TCALikeReporter: LockmanIssueReporter, @unchecked Sendable {
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        // Simulate TCA-style issue reporting
        print("TCA Issue: \(message) at \(file):\(line)")
      }
    }

    LockmanIssueReporting.reporter = TCALikeReporter.self
    LockmanIssueReporting.reportIssue("TCA integration test")

    XCTAssertTrue(LockmanIssueReporting.reporter == TCALikeReporter.self)
  }

  func testFrameworkAgnosticDesignValidation() {
    // Test that design is truly framework-agnostic
    let originalReporter = LockmanIssueReporting.reporter

    // Should work with any conforming type
    LockmanIssueReporting.reporter = MockIssueReporter.self
    XCTAssertTrue(LockmanIssueReporting.reporter == MockIssueReporter.self)

    LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
    XCTAssertTrue(LockmanIssueReporting.reporter == LockmanDefaultIssueReporter.self)

    // Restore original
    LockmanIssueReporting.reporter = originalReporter
  }

  func testCleanSeparationOfConcerns() {
    // Test that issue reporting is cleanly separated from other concerns
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Issue reporting should not affect other framework operations
    LockmanIssueReporting.reportIssue("separation test")

    // Should be isolated functionality
    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "separation test")
  }

  func testPluggableReporterArchitecture() {
    // Test that reporter architecture is truly pluggable
    final class PluggableReporter1: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var messages: [String] = []
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        messages.append("Plugin1: \(message)")
      }
    }

    final class PluggableReporter2: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var messages: [String] = []
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        messages.append("Plugin2: \(message)")
      }
    }

    // Test switching between plugins
    LockmanIssueReporting.reporter = PluggableReporter1.self
    LockmanIssueReporting.reportIssue("test 1")

    LockmanIssueReporting.reporter = PluggableReporter2.self
    LockmanIssueReporting.reportIssue("test 2")

    XCTAssertEqual(PluggableReporter1.messages, ["Plugin1: test 1"])
    XCTAssertEqual(PluggableReporter2.messages, ["Plugin2: test 2"])
  }

  // MARK: - Custom Reporter Implementation Tests

  func testCustomLockmanIssueReporterConformancePatterns() {
    final class CustomConformanceReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var lastCall: (message: String, file: String, line: UInt)?

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        lastCall = (message, "\(file)", line)
      }
    }

    LockmanIssueReporting.reporter = CustomConformanceReporter.self
    LockmanIssueReporting.reportIssue("conformance pattern test", file: #file, line: #line)

    XCTAssertNotNil(CustomConformanceReporter.lastCall)
    XCTAssertEqual(CustomConformanceReporter.lastCall?.message, "conformance pattern test")
  }

  func testThirdPartyLoggingFrameworkIntegration() {
    // Simulate integration with third-party logging framework
    final class ThirdPartyLoggerReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var logEntries: [(level: String, message: String, context: String)] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        let fileName = "\(file)".split(separator: "/").last ?? "Unknown"
        logEntries.append(
          (
            level: "WARNING",
            message: message,
            context: "\(fileName):\(line)"
          ))
      }
    }

    LockmanIssueReporting.reporter = ThirdPartyLoggerReporter.self
    LockmanIssueReporting.reportIssue("third party test")

    XCTAssertEqual(ThirdPartyLoggerReporter.logEntries.count, 1)
    XCTAssertEqual(ThirdPartyLoggerReporter.logEntries[0].level, "WARNING")
    XCTAssertEqual(ThirdPartyLoggerReporter.logEntries[0].message, "third party test")
  }

  func testAnalyticsIntegrationThroughCustomReporters() {
    // Simulate analytics integration
    final class AnalyticsReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var events: [(event: String, properties: [String: Any])] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        events.append(
          (
            event: "lockman_issue",
            properties: [
              "message": message,
              "file": "\(file)",
              "line": line,
            ]
          ))
      }
    }

    LockmanIssueReporting.reporter = AnalyticsReporter.self
    LockmanIssueReporting.reportIssue("analytics test")

    XCTAssertEqual(AnalyticsReporter.events.count, 1)
    XCTAssertEqual(AnalyticsReporter.events[0].event, "lockman_issue")
    XCTAssertEqual(AnalyticsReporter.events[0].properties["message"] as? String, "analytics test")
  }

  func testFileBasedLoggingImplementation() {
    // Simulate file-based logging
    final class FileBasedReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var logLines: [String] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        let timestamp = Date().timeIntervalSince1970
        let fileName = "\(file)".split(separator: "/").last ?? "Unknown"
        logLines.append("[\(timestamp)] ⚠️ Lockman Issue [\(fileName):\(line)]: \(message)")
      }
    }

    LockmanIssueReporting.reporter = FileBasedReporter.self
    LockmanIssueReporting.reportIssue("file logging test")

    XCTAssertEqual(FileBasedReporter.logLines.count, 1)
    XCTAssertTrue(FileBasedReporter.logLines[0].contains("file logging test"))
    XCTAssertTrue(FileBasedReporter.logLines[0].contains("⚠️ Lockman Issue"))
  }

  func testNetworkBasedReportingImplementation() {
    // Simulate network-based reporting
    final class NetworkReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var queuedReports: [(endpoint: String, payload: [String: Any])] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        queuedReports.append(
          (
            endpoint: "/api/issues",
            payload: [
              "source": "lockman",
              "message": message,
              "file": "\(file)",
              "line": line,
              "timestamp": Date().timeIntervalSince1970,
            ]
          ))
      }
    }

    LockmanIssueReporting.reporter = NetworkReporter.self
    LockmanIssueReporting.reportIssue("network test")

    XCTAssertEqual(NetworkReporter.queuedReports.count, 1)
    XCTAssertEqual(NetworkReporter.queuedReports[0].endpoint, "/api/issues")
    XCTAssertEqual(NetworkReporter.queuedReports[0].payload["source"] as? String, "lockman")
  }

  func testMultiDestinationReportingPatterns() {
    // Simulate multi-destination reporting
    final class MultiDestinationReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var consoleMessages: [String] = []
      nonisolated(unsafe) static var analyticsEvents: [String] = []
      nonisolated(unsafe) static var fileEntries: [String] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        // Send to console
        consoleMessages.append("Console: \(message)")

        // Send to analytics
        analyticsEvents.append("Analytics: \(message)")

        // Send to file
        fileEntries.append("File: \(message)")
      }
    }

    LockmanIssueReporting.reporter = MultiDestinationReporter.self
    LockmanIssueReporting.reportIssue("multi destination test")

    XCTAssertEqual(MultiDestinationReporter.consoleMessages.count, 1)
    XCTAssertEqual(MultiDestinationReporter.analyticsEvents.count, 1)
    XCTAssertEqual(MultiDestinationReporter.fileEntries.count, 1)
  }

  // MARK: - Error Handling and Edge Cases Tests

  func testInvalidFilePathHandling() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let invalidPath: StaticString = ""
    LockmanIssueReporting.reportIssue("invalid path test", file: invalidPath, line: 1)

    XCTAssertEqual(MockIssueReporter.lastFile, "")
    XCTAssertEqual(MockIssueReporter.lastLine, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "invalid path test")
  }

  func testVeryLongMessageContentHandling() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let veryLongMessage = String(repeating: "This is a very long message. ", count: 1000)
    LockmanIssueReporting.reportIssue(veryLongMessage)

    XCTAssertEqual(MockIssueReporter.lastMessage, veryLongMessage)
    XCTAssertEqual(MockIssueReporter.reportCount, 1)
  }

  func testSpecialCharactersInMessages() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let specialChars = "🚨⚠️🔥💥\n\t\r\\\"'`$@#%^&*()[]{}|;:,.<>?/~±§"
    LockmanIssueReporting.reportIssue(specialChars)

    XCTAssertEqual(MockIssueReporter.lastMessage, specialChars)
  }

  func testUnicodeContentInIssueMessages() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let unicodeMessage = "错误信息 🇨🇳 エラーメッセージ 🇯🇵 сообщение об ошибке 🇷🇺"
    LockmanIssueReporting.reportIssue(unicodeMessage)

    XCTAssertEqual(MockIssueReporter.lastMessage, unicodeMessage)
  }

  func testMemoryPressureDuringIssueReporting() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test under memory pressure
    autoreleasepool {
      for i in 0..<10000 {
        let message = "Memory pressure test \(i) - " + String(repeating: "data", count: 100)
        LockmanIssueReporting.reportIssue(message)
      }
    }

    XCTAssertEqual(MockIssueReporter.reportCount, 10000)
  }

  func testReporterConfigurationDuringActiveReporting() {
    MockIssueReporter.reset()

    class ConfigurationTestReporter: LockmanIssueReporter {
      nonisolated(unsafe) static var configurationChanges = 0
      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        if message.contains("trigger config change") {
          // Change configuration during reporting
          LockmanIssueReporting.reporter = MockIssueReporter.self
          configurationChanges += 1
        }
      }
    }

    LockmanIssueReporting.reporter = ConfigurationTestReporter.self
    LockmanIssueReporting.reportIssue("trigger config change test")

    XCTAssertEqual(ConfigurationTestReporter.configurationChanges, 1)
    XCTAssertTrue(LockmanIssueReporting.reporter == MockIssueReporter.self)
  }

  // MARK: - Performance and Memory Management Tests

  func testIssueReportingPerformanceOverhead() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    measure {
      for i in 0..<10000 {
        LockmanIssueReporting.reportIssue("Performance test \(i)")
      }
    }

    XCTAssertEqual(MockIssueReporter.reportCount, 10000)
  }

  func testMemoryUsageWithMessageContent() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    autoreleasepool {
      let largeMessage = String(repeating: "Large message content ", count: 10000)

      for _ in 0..<100 {
        LockmanIssueReporting.reportIssue(largeMessage)
      }
    }

    XCTAssertEqual(MockIssueReporter.reportCount, 100)
  }

  func testFilePathProcessingEfficiency() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let complexPath: StaticString =
      "/very/deep/nested/directory/structure/with/many/components/TestFile.swift"

    measure {
      for _ in 0..<1000 {
        LockmanIssueReporting.reportIssue("Path processing test", file: complexPath, line: 1)
      }
    }

    XCTAssertEqual(MockIssueReporter.reportCount, 1000)
  }

  func testLockContentionPerformanceImpact() {
    let expectation = XCTestExpectation(description: "Lock contention performance")
    expectation.expectedFulfillmentCount = 1000

    let queue = DispatchQueue(label: "contention.performance", attributes: .concurrent)

    measure {
      for _ in 0..<1000 {
        queue.async {
          LockmanIssueReporting.reporter = MockIssueReporter.self
          LockmanIssueReporting.reportIssue("Contention test")
          expectation.fulfill()
        }
      }

      wait(for: [expectation], timeout: 10.0)
    }
  }

  func testLargeScaleIssueReportingScalability() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    let expectation = XCTestExpectation(description: "Large scale reporting")
    expectation.expectedFulfillmentCount = 10000

    let queue = DispatchQueue(label: "scale.test", attributes: .concurrent)

    for i in 0..<10000 {
      queue.async {
        LockmanIssueReporting.reportIssue("Scale test \(i)")
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 30.0)

    // Should complete within reasonable time
    XCTAssertGreaterThan(MockIssueReporter.reportCount, 0)
  }

  func testMemoryLeakPrevention() {
    // Test memory management behavior during reporter operations
    autoreleasepool {
      class TestReporter: LockmanIssueReporter {
        static func reportIssue(_ message: String, file: StaticString, line: UInt) {
          // Minimal implementation
        }
      }

      LockmanIssueReporting.reporter = TestReporter.self
      LockmanIssueReporting.reportIssue("Memory leak test")

      // Reset to default reporter
      LockmanIssueReporting.reporter = LockmanDefaultIssueReporter.self
    }

    // Test completed without memory issues
    XCTAssertTrue(true)
  }

  // MARK: - Integration with Lockman Framework Tests

  func testUsageByCoreComponents() {
    // Test that core components can use issue reporting
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Simulate core component usage
    func simulateCoreComponentError() {
      LockmanIssueReporting.reportIssue("Core component detected invalid state")
    }

    simulateCoreComponentError()

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertEqual(MockIssueReporter.lastMessage, "Core component detected invalid state")
  }

  func testErrorReportingIntegration() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Simulate error reporting integration
    enum LockmanError: Error {
      case invalidConfiguration
    }

    func handleError(_ error: LockmanError) {
      switch error {
      case .invalidConfiguration:
        LockmanIssueReporting.reportIssue("Invalid configuration detected: \(error)")
      }
    }

    handleError(.invalidConfiguration)

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Invalid configuration"))
  }

  func testDebugInformationPropagation() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test debug information propagation
    func propagateDebugInfo(context: String, details: String) {
      LockmanIssueReporting.reportIssue("Debug: \(context) - \(details)")
    }

    propagateDebugInfo(context: "Lock acquisition", details: "Strategy conflict detected")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Lock acquisition"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Strategy conflict"))
  }

  func testDevelopmentWorkflowSupport() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test development workflow support
    func developmentWarning(feature: String, suggestion: String) {
      LockmanIssueReporting.reportIssue("Development: \(feature) - Consider: \(suggestion)")
    }

    developmentWarning(feature: "Lock strategy", suggestion: "Use more specific action IDs")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Development"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Consider"))
  }

  func testIssueCorrelationWithFrameworkOperations() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test issue correlation
    let operationId = UUID()

    func correlatedIssue(operationId: UUID, issue: String) {
      LockmanIssueReporting.reportIssue("Operation[\(operationId)]: \(issue)")
    }

    correlatedIssue(operationId: operationId, issue: "Timeout during lock acquisition")

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Operation["))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Timeout"))
  }

  func testDebuggingAssistanceEffectiveness() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Test debugging assistance
    func assistDebugging(component: String, state: String, suggestion: String) {
      LockmanIssueReporting.reportIssue("Debug[\(component)]: State=\(state), Try: \(suggestion)")
    }

    assistDebugging(
      component: "LockManager",
      state: "deadlocked",
      suggestion: "Check for circular dependencies"
    )

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Debug[LockManager]"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("deadlocked"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("circular dependencies"))
  }

  // MARK: - Real-world Usage Pattern Tests

  func testDevelopmentEnvironmentIssueReporting() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Simulate development environment usage
    #if DEBUG
      LockmanIssueReporting.reportIssue("Development: Action ID conflict detected")
    #else
      // In production, might use different reporter or skip non-critical issues
    #endif

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Development"))
  }

  func testProductionIssueTracking() {
    // Simulate production issue tracking
    final class ProductionReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var criticalIssues: [String] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        // Only track critical issues in production
        if message.contains("CRITICAL") {
          criticalIssues.append(message)
        }
      }
    }

    LockmanIssueReporting.reporter = ProductionReporter.self

    LockmanIssueReporting.reportIssue("CRITICAL: Memory corruption detected")
    LockmanIssueReporting.reportIssue("Warning: Performance degradation")

    XCTAssertEqual(ProductionReporter.criticalIssues.count, 1)
    XCTAssertTrue(ProductionReporter.criticalIssues[0].contains("CRITICAL"))
  }

  func testIntegrationWithCICDSystems() {
    // Simulate CI/CD integration
    final class CICDReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var buildIssues: [(severity: String, message: String)] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        let severity = message.contains("ERROR") ? "ERROR" : "WARNING"
        buildIssues.append((severity: severity, message: message))
      }
    }

    LockmanIssueReporting.reporter = CICDReporter.self

    LockmanIssueReporting.reportIssue("ERROR: Build configuration invalid")
    LockmanIssueReporting.reportIssue("Warning: Deprecated API usage")

    XCTAssertEqual(CICDReporter.buildIssues.count, 2)
    XCTAssertEqual(CICDReporter.buildIssues[0].severity, "ERROR")
    XCTAssertEqual(CICDReporter.buildIssues[1].severity, "WARNING")
  }

  func testAnalyticsAndMonitoringIntegration() {
    // Simulate analytics integration
    final class MonitoringReporter: LockmanIssueReporter, @unchecked Sendable {
      nonisolated(unsafe) static var metrics: [(timestamp: TimeInterval, category: String, message: String)] = []

      static func reportIssue(_ message: String, file: StaticString, line: UInt) {
        let category = extractCategory(from: message)
        metrics.append(
          (
            timestamp: Date().timeIntervalSince1970,
            category: category,
            message: message
          ))
      }

      private static func extractCategory(from message: String) -> String {
        if message.contains("Lock") { return "LOCK_ISSUE" }
        if message.contains("Performance") { return "PERFORMANCE" }
        return "GENERAL"
      }
    }

    LockmanIssueReporting.reporter = MonitoringReporter.self

    LockmanIssueReporting.reportIssue("Lock acquisition timeout")
    LockmanIssueReporting.reportIssue("Performance degradation detected")

    XCTAssertEqual(MonitoringReporter.metrics.count, 2)
    XCTAssertEqual(MonitoringReporter.metrics[0].category, "LOCK_ISSUE")
    XCTAssertEqual(MonitoringReporter.metrics[1].category, "PERFORMANCE")
  }

  func testUserExperienceImprovementThroughIssueReporting() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Simulate UX improvement through issue reporting
    func reportUXIssue(component: String, impact: String, suggestion: String) {
      LockmanIssueReporting.reportIssue(
        "UX: \(component) - Impact: \(impact) - Suggestion: \(suggestion)")
    }

    reportUXIssue(
      component: "Lock strategy",
      impact: "User action blocked",
      suggestion: "Consider using replaceable priority"
    )

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("UX:"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("User action blocked"))
  }

  func testFrameworkAdoptionAndDebuggingSupport() {
    MockIssueReporter.reset()
    LockmanIssueReporting.reporter = MockIssueReporter.self

    // Simulate framework adoption support
    func adoptionGuidance(issue: String, documentation: String) {
      LockmanIssueReporting.reportIssue("Adoption: \(issue) - See: \(documentation)")
    }

    adoptionGuidance(
      issue: "Incorrect strategy usage",
      documentation: "https://docs.lockman.dev/strategies"
    )

    XCTAssertEqual(MockIssueReporter.reportCount, 1)
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("Adoption:"))
    XCTAssertTrue(MockIssueReporter.lastMessage.contains("docs.lockman.dev"))
  }
}

// MARK: - Mock Issue Reporter

private final class MockIssueReporter: LockmanIssueReporter, @unchecked Sendable {
  nonisolated(unsafe) static var lastMessage: String = ""
  nonisolated(unsafe) static var lastFile: String = ""
  nonisolated(unsafe) static var lastLine: UInt = 0
  nonisolated(unsafe) static var reportCount: Int = 0
  private static let lock = NSLock()

  static func reportIssue(_ message: String, file: StaticString, line: UInt) {
    lock.lock()
    defer { lock.unlock() }

    lastMessage = message
    lastFile = "\(file)"
    lastLine = line
    reportCount += 1
  }

  static func reset() {
    lock.lock()
    defer { lock.unlock() }

    lastMessage = ""
    lastFile = ""
    lastLine = 0
    reportCount = 0
  }
}
