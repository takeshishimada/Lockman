import SwiftCompilerPlugin
import SwiftSyntaxMacros

/// The macro plugin that provides all Lockman macros to the Swift compiler.
///
/// This plugin registers all available Lockman macros including:
/// - Single execution macros for preventing concurrent action execution
/// - Priority-based macros for handling action priorities and conflicts
/// - Composite strategy macros for combining multiple locking strategies
///
/// The plugin handles macro resolution and delegates to the appropriate
/// macro implementation based on the macro name and argument count.
@main
struct LockmanMacroPlugin: CompilerPlugin {
  /// The list of all macros provided by this plugin.
  ///
  /// Each macro is registered with its name and corresponding implementation type.
  /// The Swift compiler uses this information to resolve macro invocations
  /// and delegate to the appropriate macro implementation.
  let providingMacros: [any Macro.Type] = [
    // Single execution strategy macro
    LockmanSingleExecutionMacro.self,

    // Priority-based strategy macro
    LockmanPriorityBasedMacro.self,

    // Group coordination strategy macro
    LockmanGroupCoordinationMacro.self,

    // Composite strategy macros (2-5 strategies)
    LockmanCompositeStrategy2Macro.self,
    LockmanCompositeStrategy3Macro.self,
    LockmanCompositeStrategy4Macro.self,
    LockmanCompositeStrategy5Macro.self,

    // Concurrency limited strategy macro
    LockmanConcurrencyLimitedMacro.self,
  ]
}
