import Foundation

/// A specialized `LockmanAction` for single-execution locking semantics.
///
/// Actions conforming to this protocol automatically prevent concurrent execution
/// of operations with the same action identifier. Use this for operations that
/// should only run once at a time, such as login processes or data synchronization.
///
/// ## Core Concept
/// The single-execution guarantee is based on the `actionName` property:
/// - Actions with the same `actionName` cannot run concurrently
/// - Actions with different `actionName` values can run in parallel
/// - The `actionName` directly maps to the internal `actionId` used by the strategy
///
/// ## Implementation Patterns
///
/// ### Pattern 1: Simple Enum with Macro (Recommended)
/// ```swift
/// @LockmanSingleExecution
/// enum UserAction {
///   case login
///   case logout
///   case refreshProfile
/// }
/// // Each case gets its own lock: "login", "logout", "refreshProfile"
/// ```
///
/// ### Pattern 2: Manual Implementation for Parameter Separation
/// ```swift
/// enum DataAction: LockmanSingleExecutionAction {
///   case fetchUser(id: String)
///   case saveSettings
///
///   var actionName: String {
///     switch self {
///     case .fetchUser(let id): return "fetchUser_\(id)"  // Per-user locks
///     case .saveSettings: return "saveSettings"         // Shared lock
///     }
///   }
/// }
/// ```
public protocol LockmanSingleExecutionAction: LockmanAction
where I == LockmanSingleExecutionInfo {
  /// The unique name identifying this action for lock conflict detection.
  ///
  /// Actions with the same `actionName` cannot run concurrently on the same boundary.
  /// Use parameter-specific names (e.g., `"fetchUser_123"`) to allow concurrent
  /// execution for different parameters.
  var actionName: String { get }
}

// MARK: - Automatic Implementation

extension LockmanSingleExecutionAction {
  /// The strategy ID for single-execution locking.
  /// Uses the built-in single execution strategy identifier.
  public var strategyId: LockmanStrategyId {
    .singleExecution
  }

  // Note: lockmanInfo must be implemented by the conforming type
  // to specify the execution mode (.none, .boundary, or .action)
}
