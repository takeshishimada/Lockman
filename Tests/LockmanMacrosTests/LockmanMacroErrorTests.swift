import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class LockmanMacroErrorTests: XCTestCase {

    override func setUp() {
      super.setUp()
      // Setup test environment
    }

    override func tearDown() {
      super.tearDown()
      // Cleanup after each test
    }

    // MARK: - Tests

    func testInvalidDeclarationError() {
      let error = LockmanMacroError.invalidDeclaration("Test declaration error")
      XCTAssertEqual(error.description, "Test declaration error")
    }

    func testInvalidCaseNameError() {
      let error = LockmanMacroError.invalidCaseName("Test case name error")
      XCTAssertEqual(error.description, "Test case name error")
    }

    func testInvalidArgumentsError() {
      let error = LockmanMacroError.invalidArguments("Test arguments error")
      XCTAssertEqual(error.description, "Test arguments error")
    }

    func testUnsupportedStrategyCountError() {
      let error = LockmanMacroError.unsupportedStrategyCount(10)
      XCTAssertEqual(
        error.description,
        "@LockmanCompositeStrategy supports 2-5 strategies, but 10 were provided.")
    }

    func testUnsupportedStrategyCountErrorMinimum() {
      let error = LockmanMacroError.unsupportedStrategyCount(1)
      XCTAssertEqual(
        error.description, "@LockmanCompositeStrategy supports 2-5 strategies, but 1 were provided."
      )
    }

    func testStrategyResolutionFailedError() {
      let error = LockmanMacroError.strategyResolutionFailed("Test strategy resolution error")
      XCTAssertEqual(
        error.description, "Failed to resolve strategy: Test strategy resolution error")
    }
  }

#endif
