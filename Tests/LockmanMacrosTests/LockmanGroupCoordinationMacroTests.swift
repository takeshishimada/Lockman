#if canImport(LockmanMacros)
  import LockmanMacros
  import MacroTesting
  import XCTest

  final class LockmanGroupCoordinationMacroTests: XCTestCase {
    func testBasicGroupCoordinationMacro() {
      withMacroTesting(macros: [LockmanGroupCoordinationMacro.self]) {
        assertMacro {
          """
          @LockmanGroupCoordination
          enum NavigationAction {
            case navigate(to: String)
            case back
          }
          """
        } expansion: {
          """
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
          """
        }
      }
    }

    func testSingleCaseEnum() {
      withMacroTesting(macros: [LockmanGroupCoordinationMacro.self]) {
        assertMacro {
          """
          @LockmanGroupCoordination
          enum SingleAction {
            case action
          }
          """
        } expansion: {
          """
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
          """
        }
      }
    }

    func testEnumWithAssociatedValues() {
      withMacroTesting(macros: [LockmanGroupCoordinationMacro.self]) {
        assertMacro {
          """
          @LockmanGroupCoordination
          enum ComplexAction {
            case fetch(id: String, priority: Int)
            case update(data: Data)
            case delete
          }
          """
        } expansion: {
          """
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
          """
        }
      }
    }

    func testAppliedToNonEnum() {
      withMacroTesting(macros: [LockmanGroupCoordinationMacro.self]) {
        assertMacro {
          """
          @LockmanGroupCoordination
          struct NotAnEnum {
            let value: String
          }
          """
        } diagnostics: {
          """
          @LockmanGroupCoordination
          ┬────────────────────────
          ╰─ 🛑 @LockmanGroupCoordination can only be attached to an enum declaration.
          struct NotAnEnum {
            let value: String
          }
          """
        }
      }
    }
  }
#endif