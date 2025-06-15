#if canImport(LockmanMacros)
  import LockmanMacros
  import MacroTesting
  import Testing

  /// Test suite for `LockmanPriorityBasedMacro` which combines both `ExtensionMacro` and `MemberMacro` functionality.
  ///
  /// This macro generates:
  /// - Protocol conformance to `LockmanPriorityBasedAction`
  /// - `actionName` property that returns the enum case name as a String
  ///
  /// The macro should only be applied to enum declarations and will emit diagnostics for other types.
  @Suite(.macros([LockmanPriorityBasedMacro.self]))
  struct LockmanPriorityBasedMacroTests {
    // MARK: - ExtensionMacro Tests

    /// Tests that the macro generates the correct protocol conformance extension.
    /// The extension should be empty as member generation is handled separately.
    @Test
    func extensionMacroGeneratesConformance() {
      assertMacro {
        """
        @LockmanPriorityBased
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
        }

        extension TaskAction: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        public enum PublicPriorityAction {
          case urgent
          case normal
        }
        """
      } expansion: {
        """
        public enum PublicPriorityAction {
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
        }

        extension PublicPriorityAction: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        enum PriorityLevel {
          case critical
          case important
          case optional
        }
        """
      } expansion: {
        """
        enum PriorityLevel {
          case critical
          case important
          case optional

          internal var actionName: String {
            switch self {
            case .critical:
              return "critical"
            case .important:
              return "important"
            case .optional:
              return "optional"
            }
          }
        }

        extension PriorityLevel: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        enum WorkflowAction {
          case schedule(Date)
          case assignTo(String, Int)
          case complete
        }
        """
      } expansion: {
        """
        enum WorkflowAction {
          case schedule(Date)
          case assignTo(String, Int)
          case complete

          internal var actionName: String {
            switch self {
            case .schedule(_):
              return "schedule"
            case .assignTo(_, _):
              return "assignTo"
            case .complete:
              return "complete"
            }
          }
        }

        extension WorkflowAction: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        public enum PublicWorkflow {
          case process
        }
        """
      } expansion: {
        """
        public enum PublicWorkflow {
          case process

          public var actionName: String {
            switch self {
            case .process:
              return "process"
            }
          }
        }

        extension PublicWorkflow: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        private enum PrivatePriority {
          case execute
        }
        """
      } expansion: {
        """
        private enum PrivatePriority {
          case execute

          private var actionName: String {
            switch self {
            case .execute:
              return "execute"
            }
          }
        }

        extension PrivatePriority: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        enum EmptyPriority {
        }
        """
      } expansion: {
        """
        enum EmptyPriority {
        }

        extension EmptyPriority: LockmanPriorityBasedAction {
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
        @LockmanPriorityBased
        struct NotAnEnum {
          let priority: Int
        }
        """
      } diagnostics: {
        """
        @LockmanPriorityBased
        ┬────────────────────
        ╰─ 🛑 @LockmanPriorityBased can only be attached to an enum declaration.
        struct NotAnEnum {
          let priority: Int
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
        @LockmanPriorityBased
        class PriorityClass {
          var level: String = ""
        }
        """
      } diagnostics: {
        """
        @LockmanPriorityBased
        ┬────────────────────
        ╰─ 🛑 @LockmanPriorityBased can only be attached to an enum declaration.
        class PriorityClass {
          var level: String = ""
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
        @LockmanPriorityBased
        enum ComplexPriorityAction {
          case immediate
          case delayed(() -> Void)
          case scheduled(at: Date, with: String, priority: Int, retries: Bool)
          case conditional(predicate: (String) -> Bool, fallback: String)
        }
        """
      } expansion: {
        """
        enum ComplexPriorityAction {
          case immediate
          case delayed(() -> Void)
          case scheduled(at: Date, with: String, priority: Int, retries: Bool)
          case conditional(predicate: (String) -> Bool, fallback: String)

          internal var actionName: String {
            switch self {
            case .immediate:
              return "immediate"
            case .delayed(_):
              return "delayed"
            case .scheduled(_, _, _, _):
              return "scheduled"
            case .conditional(_, _):
              return "conditional"
            }
          }
        }

        extension ComplexPriorityAction: LockmanPriorityBasedAction {
        }
        """
      }
    }

    // MARK: - Priority-Specific Tests

    /// Tests that the macro works correctly with priority-related enum names and cases.
    /// This ensures the macro is suitable for priority-based workflows.
    @Test
    func memberMacroHandlesPrioritySpecificCases() {
      assertMacro {
        """
        @LockmanPriorityBased
        enum QueuePriority {
          case realtime
          case userInteractive
          case userInitiated
          case `default`
          case utility
          case background
        }
        """
      } expansion: {
        """
        enum QueuePriority {
          case realtime
          case userInteractive
          case userInitiated
          case `default`
          case utility
          case background

          internal var actionName: String {
            switch self {
            case .realtime:
              return "realtime"
            case .userInteractive:
              return "userInteractive"
            case .userInitiated:
              return "userInitiated"
            case .`default`:
              return "`default`"
            case .utility:
              return "utility"
            case .background:
              return "background"
            }
          }
        }

        extension QueuePriority: LockmanPriorityBasedAction {
        }
        """
      }
    }
  }
#endif
