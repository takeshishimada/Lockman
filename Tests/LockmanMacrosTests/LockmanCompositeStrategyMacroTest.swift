#if canImport(LockmanMacros)
  import LockmanMacros
  import MacroTesting
  import XCTest

  /// Test suite for `LockmanCompositeStrategy2Macro` which combines both `ExtensionMacro` and `MemberMacro` functionality.
  ///
  /// This macro generates:
  /// - Protocol conformance to `LockmanCompositeAction2`
  /// - `actionName` property that returns the enum case name as a String
  /// - `strategyId` property that returns a `LockmanStrategyId` instance
  /// - `lockmanInfo` property that returns composite info for 2 strategies
  ///
  /// The macro should only be applied to enum declarations and will emit diagnostics for other types.
  final class LockmanCompositeStrategy2MacroTest: XCTestCase {
    /// Tests that the macro generates the correct protocol conformance extension and members.
    func testExtensionMacroGeneratesConformance() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy2Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(LockmanPriorityBasedStrategy.self, LockmanSingleExecutionStrategy.self)
          enum TaskAction {
            case high
            case medium
            case low
          }
          """
        } expansion: {
          """
          enum TaskAction {
            case high
            case medium
            case low

            internal var actionName: String {
              switch self {
              case .high:
                return "high"
                case .medium:
                return "medium"
                case .low:
                return "low"
              }
            }

            internal var strategyId: LockmanStrategyId {
              LockmanCompositeStrategy2.makeStrategyId(
                strategy1: LockmanPriorityBasedStrategy.shared,
                strategy2: LockmanSingleExecutionStrategy.shared
              )
            }

            internal typealias I1 = LockmanPriorityBasedStrategy.I

            internal typealias S1 = LockmanPriorityBasedStrategy

            internal typealias I2 = LockmanSingleExecutionStrategy.I

            internal typealias S2 = LockmanSingleExecutionStrategy
          }

          extension TaskAction: LockmanCompositeAction2 {
          }
          """
        }
      }
    }

    /// Tests public enum handling
    func testPublicEnumHandling() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy2Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(LockmanPriorityBasedStrategy.self, LockmanSingleExecutionStrategy.self)
          public enum PublicTaskAction {
            case urgent
            case normal
          }
          """
        } expansion: {
          """
          public enum PublicTaskAction {
            case urgent
            case normal

            public var actionName: String {
              switch self {
              case .urgent:
                return "urgent"
                case .normal:
                return "normal"
              }
            }

            public var strategyId: LockmanStrategyId {
              LockmanCompositeStrategy2.makeStrategyId(
                strategy1: LockmanPriorityBasedStrategy.shared,
                strategy2: LockmanSingleExecutionStrategy.shared
              )
            }

            public typealias I1 = LockmanPriorityBasedStrategy.I

            public typealias S1 = LockmanPriorityBasedStrategy

            public typealias I2 = LockmanSingleExecutionStrategy.I

            public typealias S2 = LockmanSingleExecutionStrategy
          }

          extension PublicTaskAction: LockmanCompositeAction2 {
          }
          """
        }
      }
    }
  }

  /// Test suite for `LockmanCompositeStrategy3Macro`
  final class LockmanCompositeStrategy3MacroTest: XCTestCase {
    func testExtensionMacroGeneratesConformance() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy3Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(Strategy1.self, Strategy2.self, Strategy3.self)
          enum TaskAction {
            case high
            case medium
            case low
          }
          """
        } expansion: {
          """
          enum TaskAction {
            case high
            case medium
            case low

            internal var actionName: String {
              switch self {
              case .high:
                return "high"
                case .medium:
                return "medium"
                case .low:
                return "low"
              }
            }

            internal var strategyId: LockmanStrategyId {
              LockmanCompositeStrategy3.makeStrategyId(
                strategy1: Strategy1.shared,
                strategy2: Strategy2.shared,
                strategy3: Strategy3.shared
              )
            }

            internal typealias I1 = Strategy1.I

            internal typealias S1 = Strategy1

            internal typealias I2 = Strategy2.I

            internal typealias S2 = Strategy2

            internal typealias I3 = Strategy3.I

            internal typealias S3 = Strategy3
          }

          extension TaskAction: LockmanCompositeAction3 {
          }
          """
        }
      }
    }
  }

  /// Test suite for `LockmanCompositeStrategy4Macro`
  final class LockmanCompositeStrategy4MacroTest: XCTestCase {
    func testExtensionMacroGeneratesConformance() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy4Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(Strategy1.self, Strategy2.self, Strategy3.self, Strategy4.self)
          enum TaskAction {
            case execute
            case pause
          }
          """
        } expansion: {
          """
          enum TaskAction {
            case execute
            case pause

            internal var actionName: String {
              switch self {
              case .execute:
                return "execute"
                case .pause:
                return "pause"
              }
            }

            internal var strategyId: LockmanStrategyId {
              LockmanCompositeStrategy4.makeStrategyId(
                strategy1: Strategy1.shared,
                strategy2: Strategy2.shared,
                strategy3: Strategy3.shared,
                strategy4: Strategy4.shared
              )
            }

            internal typealias I1 = Strategy1.I

            internal typealias S1 = Strategy1

            internal typealias I2 = Strategy2.I

            internal typealias S2 = Strategy2

            internal typealias I3 = Strategy3.I

            internal typealias S3 = Strategy3

            internal typealias I4 = Strategy4.I

            internal typealias S4 = Strategy4
          }

          extension TaskAction: LockmanCompositeAction4 {
          }
          """
        }
      }
    }
  }

  /// Test suite for `LockmanCompositeStrategy5Macro`
  final class LockmanCompositeStrategy5MacroTest: XCTestCase {
    func testExtensionMacroGeneratesConformance() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy5Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(Strategy1.self, Strategy2.self, Strategy3.self, Strategy4.self, Strategy5.self)
          enum TaskAction {
            case start
            case stop
          }
          """
        } expansion: {
          """
          enum TaskAction {
            case start
            case stop

            internal var actionName: String {
              switch self {
              case .start:
                return "start"
                case .stop:
                return "stop"
              }
            }

            internal var strategyId: LockmanStrategyId {
              LockmanCompositeStrategy5.makeStrategyId(
                strategy1: Strategy1.shared,
                strategy2: Strategy2.shared,
                strategy3: Strategy3.shared,
                strategy4: Strategy4.shared,
                strategy5: Strategy5.shared
              )
            }

            internal typealias I1 = Strategy1.I

            internal typealias S1 = Strategy1

            internal typealias I2 = Strategy2.I

            internal typealias S2 = Strategy2

            internal typealias I3 = Strategy3.I

            internal typealias S3 = Strategy3

            internal typealias I4 = Strategy4.I

            internal typealias S4 = Strategy4

            internal typealias I5 = Strategy5.I

            internal typealias S5 = Strategy5
          }

          extension TaskAction: LockmanCompositeAction5 {
          }
          """
        }
      }
    }
  }

  /// Test suite for error handling across all macro variants
  final class LockmanCompositeStrategyErrorTests: XCTestCase {
    func testInvalidDeclarationTypeError() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy2Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(Strategy1.self, Strategy2.self)
          struct TaskAction {
            let name: String
          }
          """
        } diagnostics: {
          """
          @LockmanCompositeStrategy(Strategy1.self, Strategy2.self)
          ┬────────────────────────────────────────────────────────
          ├─ 🛑 @LockmanCompositeStrategy can only be attached to an enum declaration.
          ╰─ 🛑 @LockmanCompositeStrategy can only be attached to an enum declaration.
          struct TaskAction {
            let name: String
          }
          """
        }
      }
    }

    func testInvalidArgumentCountError() {
      withMacroTesting(macros: [
        "LockmanCompositeStrategy": LockmanCompositeStrategy2Macro.self,
      ]) {
        assertMacro {
          """
          @LockmanCompositeStrategy(Strategy1.self)
          enum TaskAction {
            case high
          }
          """
        } diagnostics: {
          """
          @LockmanCompositeStrategy(Strategy1.self)
          ┬────────────────────────────────────────
          ╰─ 🛑 @LockmanCompositeStrategy requires exactly 2 strategy arguments, but 1 were provided.
          enum TaskAction {
            case high
          }
          """
        }
      }
    }
  }

#endif
