import SwiftCompilerPlugin
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class MacroPluginTests: XCTestCase {

    override func setUp() {
      super.setUp()
      // Setup test environment
    }

    override func tearDown() {
      super.tearDown()
      // Cleanup after each test
    }

    func testPluginConformsToCompilerPlugin() {
      let plugin = LockmanMacroPlugin()
      XCTAssertTrue(plugin is CompilerPlugin)
    }

    func testProvidingMacrosCount() {
      let plugin = LockmanMacroPlugin()
      XCTAssertEqual(plugin.providingMacros.count, 8)
    }

    func testSingleExecutionMacroIsRegistered() {
      let plugin = LockmanMacroPlugin()
      let containsSingleExecution = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanSingleExecutionMacro"
      }
      XCTAssertTrue(containsSingleExecution)
    }

    func testPriorityBasedMacroIsRegistered() {
      let plugin = LockmanMacroPlugin()
      let containsPriorityBased = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanPriorityBasedMacro"
      }
      XCTAssertTrue(containsPriorityBased)
    }

    func testGroupCoordinationMacroIsRegistered() {
      let plugin = LockmanMacroPlugin()
      let containsGroupCoordination = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanGroupCoordinationMacro"
      }
      XCTAssertTrue(containsGroupCoordination)
    }

    func testCompositeStrategyMacrosAreRegistered() {
      let plugin = LockmanMacroPlugin()

      let composite2 = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanCompositeStrategy2Macro"
      }
      let composite3 = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanCompositeStrategy3Macro"
      }
      let composite4 = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanCompositeStrategy4Macro"
      }
      let composite5 = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanCompositeStrategy5Macro"
      }

      XCTAssertTrue(composite2)
      XCTAssertTrue(composite3)
      XCTAssertTrue(composite4)
      XCTAssertTrue(composite5)
    }

    func testConcurrencyLimitedMacroIsRegistered() {
      let plugin = LockmanMacroPlugin()
      let containsConcurrencyLimited = plugin.providingMacros.contains { macroType in
        return String(describing: macroType) == "LockmanConcurrencyLimitedMacro"
      }
      XCTAssertTrue(containsConcurrencyLimited)
    }

    func testAllMacrosConformToMacroProtocol() {
      let plugin = LockmanMacroPlugin()
      for macroType in plugin.providingMacros {
        XCTAssertTrue(macroType is any Macro.Type)
      }
    }

  }

#endif
