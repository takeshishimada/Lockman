import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(LockmanMacros)
  import LockmanMacros

  final class LockmanGroupCoordinationMacroTests: XCTestCase {
    func testBasicGroupCoordinationMacro() throws {
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
        enum SingleAction {
          case action
        }
        """,
        expandedSource: """
        enum SingleAction {
          case action

            internal var actionName: String {
              switch self {
              case .action:
                  return "action"
              }
            }
        }

        extension SingleAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    func testEnumWithAssociatedValues() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        enum ComplexAction {
          case fetch(id: String, priority: Int)
          case update(data: Data)
          case delete
        }
        """,
        expandedSource: """
        enum ComplexAction {
          case fetch(id: String, priority: Int)
          case update(data: Data)
          case delete

            internal var actionName: String {
              switch self {
              case .fetch(_, _):
                  return "fetch"
              case .update(_):
                  return "update"
              case .delete:
                  return "delete"
              }
            }
        }

        extension ComplexAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    func testAppliedToNonEnum() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        struct NotAnEnum {
          let value: String
        }
        """,
        expandedSource: """
        struct NotAnEnum {
          let value: String
        }

        extension NotAnEnum: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "@LockmanGroupCoordination can only be attached to an enum declaration.",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }
  }

  private let testMacros: [String: any Macro.Type] = [
    "LockmanGroupCoordination": LockmanGroupCoordinationMacro.self,
  ]
#endif