/// An action that participates in Lockman's locking mechanism.
///
/// Conforming types must provide:
/// - `I`: The concrete `LockmanInfo` type associated with this action.
/// - `lockmanInfo`: An instance of that lock information.
/// - `strategyId`: The identifier for the strategy to use.
///
/// The new design uses `LockmanStrategyId` instead of type references,
/// providing better flexibility for user-defined and configured strategies.
///
/// Example implementation:
/// ```swift
/// struct MyAction: LockmanAction {
///   typealias I = LockmanSingleExecutionInfo
///
///   let lockmanInfo: I
///   let strategyId = LockmanStrategyId.singleExecution
/// }
/// ```
///
/// For custom or configured strategies:
/// ```swift
/// struct ConfiguredAction: LockmanAction {
///   typealias I = CustomLockInfo
///
///   let lockmanInfo: I
///   let strategyId = LockmanStrategyId(
///     name: "RateLimitStrategy",
///     configuration: "limit-100"
///   )
/// }
/// ```
public protocol LockmanAction: Sendable {
  /// The concrete `LockmanInfo` type used by this action.
  /// This defines what kind of lock information this action carries.
  associatedtype I: LockmanInfo

  /// The lock information that defines how this action should be locked or unlocked.
  /// This instance contains all the necessary data for the strategy to make
  /// locking decisions (e.g., action ID, priority, etc.).
  var lockmanInfo: I { get }

  /// The identifier for the strategy to use for lock operations.
  /// This will be used to resolve the appropriate strategy from the container.
  ///
  /// Example:
  /// ```swift
  /// var strategyId: LockmanStrategyId {
  ///   return .singleExecution
  /// }
  /// ```
  var strategyId: LockmanStrategyId { get }
}
