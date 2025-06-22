import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(LockmanMacros)
  import LockmanMacros

  final class LockmanGroupCoordinationMacroTests: XCTestCase {
    // MARK: - Basic Tests

    func testBasicMacro() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        enum NavigationAction {
          case navigate(to: String)
          case back
        }
        """,
        expandedSource: """
          enum NavigationAction {
            case navigate(to: String)
            case back

              internal var actionName: String {
                switch self {
                case .navigate(_):
                    return "navigate"
                case .back:
                    return "back"
                }
              }
          }

          extension NavigationAction: LockmanGroupCoordinatedAction {
          }
          """,
        macros: testMacros
      )
    }

    func testSingleCaseEnum() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        enum SimpleAction {
          case action
        }
        """,
        expandedSource: """
          enum SimpleAction {
            case action

              internal var actionName: String {
                switch self {
                case .action:
                    return "action"
                }
              }
          }

          extension SimpleAction: LockmanGroupCoordinatedAction {
          }
          """,
        macros: testMacros
      )
    }

    // MARK: - Complex Enum Cases

    func testComplexEnumCases() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        enum UIAction {
          case showAlert(message: String)
          case updateProgress(value: Double, animated: Bool)
          case navigate(to: String, animated: Bool = true)
        }
        """,
        expandedSource: """
          enum UIAction {
            case showAlert(message: String)
            case updateProgress(value: Double, animated: Bool)
            case navigate(to: String, animated: Bool = true)

              internal var actionName: String {
                switch self {
                case .showAlert(_):
                    return "showAlert"
                case .updateProgress(_, _):
                    return "updateProgress"
                case .navigate(_, _):
                    return "navigate"
                }
              }
          }

          extension UIAction: LockmanGroupCoordinatedAction {
          }
          """,
        macros: testMacros
      )
    }

    // MARK: - Non-Enum Types

    func testNonEnumTypeError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        struct InvalidAction {
          let value: String
        }
        """,
        expandedSource: """
          struct InvalidAction {
            let value: String
          }

          extension InvalidAction: LockmanGroupCoordinatedAction {
          }
          """,
        diagnostics: [
          DiagnosticSpec(
            message: "@LockmanGroupCoordination can only be attached to an enum declaration.",
            line: 1,
            column: 1
          )
        ],
        macros: testMacros
      )
    }

    // MARK: - Public/Internal Cases

    func testPublicEnum() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        public enum PublicAction {
          case action
        }
        """,
        expandedSource: """
          public enum PublicAction {
            case action

              public var actionName: String {
                switch self {
                case .action:
                    return "action"
                }
              }
          }

          extension PublicAction: LockmanGroupCoordinatedAction {
          }
          """,
        macros: testMacros
      )
    }

    func testInternalEnum() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        internal enum InternalAction {
          case action
        }
        """,
        expandedSource: """
          internal enum InternalAction {
            case action

              internal var actionName: String {
                switch self {
                case .action:
                    return "action"
                }
              }
          }

          extension InternalAction: LockmanGroupCoordinatedAction {
          }
          """,
        macros: testMacros
      )
    }
  }

  // MARK: - Test Helpers

  private let testMacros: [String: any Macro.Type] = [
    "LockmanGroupCoordination": LockmanGroupCoordinationMacro.self
  ]
#endif
