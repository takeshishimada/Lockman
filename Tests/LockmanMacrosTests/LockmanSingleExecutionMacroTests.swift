#if canImport(LockmanMacros)
  import LockmanMacros
  import MacroTesting
  import Testing

  /// Test suite for `LockmanSingleExecutionMacro` which combines both `ExtensionMacro` and `MemberMacro` functionality.
  ///
  /// This macro generates:
  /// - Protocol conformance to `LockmanSingleExecutionAction`
  /// - `actionName` property that returns the enum case name as a String
  ///
  /// The macro should only be applied to enum declarations and will emit diagnostics for other types.
  @Suite(.macros([LockmanSingleExecutionMacro.self]))
  struct LockmanSingleExecutionMacroTests {
    // MARK: - ExtensionMacro Tests

    /// Tests that the macro generates the correct protocol conformance extension.
    /// The extension should be empty as member generation is handled separately.
    @Test
    func extensionMacroGeneratesConformance() {
      assertMacro {
        """
        @LockmanSingleExecution
        enum TestAction {
          case start
          case stop
        }
        """
      } expansion: {
        """
        enum TestAction {
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
        }

        extension TestAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    /// Tests that the extension macro preserves access modifiers when generating conformance.
    /// Public enums should generate public conformance extensions.
    @Test
    func extensionMacroWorksWithPublicEnum() {
      assertMacro {
        """
        @LockmanSingleExecution
        public enum PublicTestAction {
          case initialize
          case cleanup
        }
        """
      } expansion: {
        """
        public enum PublicTestAction {
          case initialize
          case cleanup

          public var actionName: String {
            switch self {
            case .initialize:
              return "initialize"
            case .cleanup:
              return "cleanup"
            }
          }
        }

        extension PublicTestAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    // MARK: - MemberMacro Tests

    /// Tests member generation for enums with simple cases (no associated values).
    /// Should generate:
    /// - `actionName` property with switch statement returning case names
    @Test
    func memberMacroGeneratesActionNameForSimpleCases() {
      assertMacro {
        """
        @LockmanSingleExecution
        enum SimpleAction {
          case start
          case stop
          case pause
        }
        """
      } expansion: {
        """
        enum SimpleAction {
          case start
          case stop
          case pause

          internal var actionName: String {
            switch self {
            case .start:
              return "start"
            case .stop:
              return "stop"
            case .pause:
              return "pause"
            }
          }
        }

        extension SimpleAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    /// Tests member generation for enum cases with associated values.
    /// Associated values should be ignored with underscore placeholders in the switch cases.
    @Test
    func memberMacroGeneratesActionNameForCasesWithAssociatedValues() {
      assertMacro {
        """
        @LockmanSingleExecution
        enum ActionWithValues {
          case load(String)
          case save(String, Int)
          case delete
        }
        """
      } expansion: {
        """
        enum ActionWithValues {
          case load(String)
          case save(String, Int)
          case delete

          internal var actionName: String {
            switch self {
            case .load(_):
              return "load"
            case .save(_, _):
              return "save"
            case .delete:
              return "delete"
            }
          }
        }

        extension ActionWithValues: LockmanSingleExecutionAction {
        }
        """
      }
    }

    /// Tests that generated members respect the access level of the enum declaration.
    /// Public enums should generate public properties.
    @Test
    func memberMacroRespectsAccessModifiers() {
      assertMacro {
        """
        @LockmanSingleExecution
        public enum PublicAction {
          case execute
        }
        """
      } expansion: {
        """
        public enum PublicAction {
          case execute

          public var actionName: String {
            switch self {
            case .execute:
              return "execute"
            }
          }
        }

        extension PublicAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    /// Tests that private enums generate private properties.
    /// Ensures access control is properly propagated to generated members.
    @Test
    func memberMacroHandlesPrivateEnum() {
      assertMacro {
        """
        @LockmanSingleExecution
        private enum PrivateAction {
          case process
        }
        """
      } expansion: {
        """
        private enum PrivateAction {
          case process

          private var actionName: String {
            switch self {
            case .process:
              return "process"
            }
          }
        }

        extension PrivateAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    /// Tests behavior with enums that have no cases.
    /// Should generate the extension but no actionName property since there are no cases.
    @Test
    func memberMacroHandlesEmptyEnum() {
      assertMacro {
        """
        @LockmanSingleExecution
        enum EmptyAction {
        }
        """
      } expansion: {
        """
        enum EmptyAction {
        }

        extension EmptyAction: LockmanSingleExecutionAction {
        }
        """
      }
    }

    // MARK: - Error Cases

    /// Tests that applying the macro to a struct produces an appropriate diagnostic.
    /// The macro should only work on enum declarations.
    @Test
    func macroFailsOnNonEnumDeclaration() {
      assertMacro {
        """
        @LockmanSingleExecution
        struct NotAnEnum {
          let value: String
        }
        """
      } diagnostics: {
        """
        @LockmanSingleExecution
        ┬──────────────────────
        ╰─ 🛑 @LockmanSingleExecution can only be attached to an enum declaration.
        struct NotAnEnum {
          let value: String
        }
        """
      }
    }

    /// Tests that applying the macro to a class produces an appropriate diagnostic.
    /// Verifies the macro properly validates the target declaration type.
    @Test
    func macroFailsOnClass() {
      assertMacro {
        """
        @LockmanSingleExecution
        class TestClass {
          var name: String = ""
        }
        """
      } diagnostics: {
        """
        @LockmanSingleExecution
        ┬──────────────────────
        ╰─ 🛑 @LockmanSingleExecution can only be attached to an enum declaration.
        class TestClass {
          var name: String = ""
        }
        """
      }
    }

    // MARK: - Complex Cases

    /// Tests member generation for enum cases with complex associated value types.
    /// This includes closures, multiple parameters, and named parameters.
    /// All associated values should be properly ignored with the correct number of underscores.
    @Test
    func memberMacroHandlesComplexAssociatedValues() {
      assertMacro {
        """
        @LockmanSingleExecution
        enum ComplexAction {
          case simple
          case withClosure(() -> Void)
          case withMultipleTypes(String, Int, Bool, Double)
          case withNamedParameters(name: String, age: Int)
        }
        """
      } expansion: {
        """
        enum ComplexAction {
          case simple
          case withClosure(() -> Void)
          case withMultipleTypes(String, Int, Bool, Double)
          case withNamedParameters(name: String, age: Int)

          internal var actionName: String {
            switch self {
            case .simple:
              return "simple"
            case .withClosure(_):
              return "withClosure"
            case .withMultipleTypes(_, _, _, _):
              return "withMultipleTypes"
            case .withNamedParameters(_, _):
              return "withNamedParameters"
            }
          }
        }

        extension ComplexAction: LockmanSingleExecutionAction {
        }
        """
      }
    }
  }
#endif
