/// An action that participates in Lockman's locking mechanism.
///
/// Conforming types must provide:
/// - `I`: The concrete `LockmanInfo` type associated with this action.
/// - `lockmanInfo`: An instance of that lock information.
///
/// The strategy to use is determined by the `strategyId` property in the
/// `lockmanInfo` instance, providing better flexibility for user-defined
/// and configured strategies.
///
/// Example implementation:
/// ```swift
/// struct MyAction: LockmanAction {
///   typealias I = LockmanSingleExecutionInfo
///
///   let lockmanInfo = LockmanSingleExecutionInfo(
///     actionId: "myAction",
///     mode: .boundary
///   )
/// }
/// ```
///
/// For custom or configured strategies:
/// ```swift
/// struct ConfiguredAction: LockmanAction {
///   typealias I = CustomLockInfo
///
///   let lockmanInfo = CustomLockInfo(
///     strategyId: LockmanStrategyId(
///       name: "RateLimitStrategy",
///       configuration: "limit-100"
///     ),
///     actionId: "apiCall"
///   )
/// }
/// ```
public protocol LockmanAction: Sendable {
  /// The concrete `LockmanInfo` type used by this action.
  /// This defines what kind of lock information this action carries.
  associatedtype I: LockmanInfo

  /// The lock information that defines how this action should be locked or unlocked.
  /// This instance contains all the necessary data for the strategy to make
  /// locking decisions (e.g., action ID, priority, strategy ID, etc.).
  var lockmanInfo: I { get }
}
