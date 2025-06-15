#if canImport(LockmanMacros)
  import LockmanMacros
  import MacroTesting
  import Testing

  @Suite(.macros([LockmanDynamicConditionMacro.self]))
  struct LockmanDynamicConditionMacroTests {
    // MARK: - Basic Tests

    @Test("Generates conformance and members for simple enum")
    func generatesConformanceAndMembersForSimpleEnum() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum SimpleAction {
          case start
          case stop
        }
        """
      } expansion: {
        """
        enum SimpleAction {
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

          internal var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension SimpleAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    @Test("Generates metadata extraction for associated values")
    func generatesMetadataExtractionForAssociatedValues() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum UserAction {
          case fetchData(userId: String, priority: Int)
          case processTask(size: Int)
          case simple
        }
        """
      } expansion: {
        """
        enum UserAction {
          case fetchData(userId: String, priority: Int)
          case processTask(size: Int)
          case simple

          internal var actionName: String {
            switch self {
            case .fetchData(_, _):
              return "fetchData"
            case .processTask(_):
              return "processTask"
            case .simple:
              return "simple"
            }
          }

          internal var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension UserAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    @Test("Handles unnamed parameters")
    func handlesUnnamedParameters() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum DataAction {
          case process(String, Int, Bool)
          case compute(Double)
        }
        """
      } expansion: {
        """
        enum DataAction {
          case process(String, Int, Bool)
          case compute(Double)

          internal var actionName: String {
            switch self {
            case .process(_, _, _):
              return "process"
            case .compute(_):
              return "compute"
            }
          }

          internal var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension DataAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    @Test("Respects access modifiers")
    func respectsAccessModifiers() {
      assertMacro {
        """
        @LockmanDynamicCondition
        public enum PublicAction {
          case execute(id: String)
        }
        """
      } expansion: {
        """
        public enum PublicAction {
          case execute(id: String)

          public var actionName: String {
            switch self {
            case .execute(_):
              return "execute"
            }
          }

          public var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension PublicAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    @Test("Handles complex associated value types")
    func handlesComplexAssociatedValueTypes() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum ComplexAction {
          case configure(settings: [String: Any], handler: () -> Void)
          case update(data: Data?, completion: ((Bool) -> Void)?)
        }
        """
      } expansion: {
        """
        enum ComplexAction {
          case configure(settings: [String: Any], handler: () -> Void)
          case update(data: Data?, completion: ((Bool) -> Void)?)

          internal var actionName: String {
            switch self {
            case .configure(_, _):
              return "configure"
            case .update(_, _):
              return "update"
            }
          }

          internal var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension ComplexAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    // MARK: - Error Cases

    @Test("Fails on non-enum declaration")
    func failsOnNonEnumDeclaration() {
      assertMacro {
        """
        @LockmanDynamicCondition
        struct NotAnEnum {
          let value: String
        }
        """
      } diagnostics: {
        """
        @LockmanDynamicCondition
        ┬───────────────────────
        ╰─ 🛑 @LockmanDynamicCondition can only be attached to an enum declaration.
        struct NotAnEnum {
          let value: String
        }
        """
      }
    }

    @Test("Fails on class declaration")
    func failsOnClassDeclaration() {
      assertMacro {
        """
        @LockmanDynamicCondition
        class TestClass {
          var name: String = ""
        }
        """
      } diagnostics: {
        """
        @LockmanDynamicCondition
        ┬───────────────────────
        ╰─ 🛑 @LockmanDynamicCondition can only be attached to an enum declaration.
        class TestClass {
          var name: String = ""
        }
        """
      }
    }

    // MARK: - Edge Cases

    @Test("Handles empty enum")
    func handlesEmptyEnum() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum EmptyAction {
        }
        """
      } expansion: {
        """
        enum EmptyAction {
        }

        extension EmptyAction: LockmanDynamicConditionAction {
        }
        """
      }
    }

    @Test("Handles enum with raw values")
    func handlesEnumWithRawValues() {
      assertMacro {
        """
        @LockmanDynamicCondition
        enum RawValueAction: String {
          case first = "FIRST"
          case second = "SECOND"
        }
        """
      } expansion: {
        """
        enum RawValueAction: String {
          case first = "FIRST"
          case second = "SECOND"

          internal var actionName: String {
            switch self {
            case .first:
              return "first"
            case .second:
              return "second"
            }
          }

          internal var lockmanInfo: LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
              actionId: actionName
            )
          }
        }

        extension RawValueAction: LockmanDynamicConditionAction {
        }
        """
      }
    }
  }
#endif
