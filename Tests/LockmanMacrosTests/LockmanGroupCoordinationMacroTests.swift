import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

#if canImport(LockmanMacros)
  import LockmanMacros

  final class LockmanGroupCoordinationMacroTests: XCTestCase {
    // MARK: - Single Group Tests

    func testSingleGroupLeaderMacro() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupId: "navigation", role: .leader)
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

            var coordinationRole: GroupCoordinationRole {
              .leader
            }

            var groupId: String {
              "navigation"
            }
        }

        extension NavigationAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    func testSingleGroupMemberMacro() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupId: "dataLoading", role: .member)
        enum DataAction {
          case loadData
          case updateProgress
        }
        """,
        expandedSource: """
        enum DataAction {
          case loadData
          case updateProgress

            internal var actionName: String {
              switch self {
              case .loadData:
                  return "loadData"
              case .updateProgress:
                  return "updateProgress"
              }
            }

            var coordinationRole: GroupCoordinationRole {
              .member
            }

            var groupId: String {
              "dataLoading"
            }
        }

        extension DataAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    // MARK: - Multiple Groups Tests

    func testMultipleGroupsMacro() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupIds: ["navigation", "ui"], role: .member)
        enum ComplexAction {
          case complexOperation
        }
        """,
        expandedSource: """
        enum ComplexAction {
          case complexOperation

            internal var actionName: String {
              switch self {
              case .complexOperation:
                  return "complexOperation"
              }
            }

            var coordinationRole: GroupCoordinationRole {
              .member
            }

            var groupIds: Set<String> {
              ["navigation", "ui"]
            }
        }

        extension ComplexAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    func testMaximumGroupsMacro() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupIds: ["group1", "group2", "group3", "group4", "group5"], role: .leader)
        enum MaxGroupsAction {
          case action
        }
        """,
        expandedSource: """
        enum MaxGroupsAction {
          case action

            internal var actionName: String {
              switch self {
              case .action:
                  return "action"
              }
            }

            var coordinationRole: GroupCoordinationRole {
              .leader
            }

            var groupIds: Set<String> {
              ["group1", "group2", "group3", "group4", "group5"]
            }
        }

        extension MaxGroupsAction: LockmanGroupCoordinatedAction {
        }
        """,
        macros: testMacros
      )
    }

    // MARK: - Error Cases

    func testMissingArgumentsError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination
        enum InvalidAction {
          case action
        }
        """,
        expandedSource: """
        enum InvalidAction {
          case action
        }

        extension InvalidAction: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "Missing required arguments for LockmanGroupCoordination macro. Provide either 'groupId' or 'groupIds' parameter along with 'role'",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }

    func testMissingRoleError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupId: "test")
        enum InvalidAction {
          case action
        }
        """,
        expandedSource: """
        enum InvalidAction {
          case action
        }

        extension InvalidAction: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "Missing role argument for LockmanGroupCoordination macro",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }

    func testInvalidRoleError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupId: "test", role: .invalid)
        enum InvalidAction {
          case action
        }
        """,
        expandedSource: """
        enum InvalidAction {
          case action
        }

        extension InvalidAction: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "Role must be .leader or .member for LockmanGroupCoordination macro, got .invalid",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }

    func testTooManyGroupsError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupIds: ["g1", "g2", "g3", "g4", "g5", "g6"], role: .leader)
        enum InvalidAction {
          case action
        }
        """,
        expandedSource: """
        enum InvalidAction {
          case action
        }

        extension InvalidAction: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "Maximum 5 groups allowed for LockmanGroupCoordination macro, got 6",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }

    func testEmptyGroupsError() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupIds: [], role: .leader)
        enum InvalidAction {
          case action
        }
        """,
        expandedSource: """
        enum InvalidAction {
          case action
        }

        extension InvalidAction: LockmanGroupCoordinatedAction {
        }
        """,
        diagnostics: [
          DiagnosticSpec(
            message: "At least one group ID must be provided for LockmanGroupCoordination macro",
            line: 1,
            column: 1
          ),
        ],
        macros: testMacros
      )
    }

    // MARK: - Complex Enum Cases

    func testComplexEnumCases() throws {
      assertMacroExpansion(
        """
        @LockmanGroupCoordination(groupId: "ui", role: .member)
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

            var coordinationRole: GroupCoordinationRole {
              .member
            }

            var groupId: String {
              "ui"
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
        @LockmanGroupCoordination(groupId: "test", role: .leader)
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
          ),
        ],
        macros: testMacros
      )
    }
  }

  // MARK: - Test Helpers

  private let testMacros: [String: any Macro.Type] = [
    "LockmanGroupCoordination": LockmanGroupCoordinationMacro.self,
  ]
#endif
