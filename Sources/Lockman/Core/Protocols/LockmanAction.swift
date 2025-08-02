/// An action that participates in Lockman's locking mechanism.
///
/// Conforming types must provide:
/// - `I`: The concrete `LockmanInfo` type associated with this action.
/// - `createLockmanInfo()`: A method that creates lock information instances.
///
/// The strategy to use is determined by the `strategyId` property in the
/// `lockmanInfo` instance, providing better flexibility for user-defined
/// and configured strategies.
///
/// ## Important: Use createLockmanInfo() Once Per Lock Operation
/// The `createLockmanInfo()` method should be called once at the beginning of
/// each lock operation and the result should be reused throughout the operation.
/// This ensures consistent `uniqueId` values for proper lock/unlock matching.
///
/// Example implementation:
/// ```swift
/// struct MyAction: LockmanAction {
///   typealias I = LockmanSingleExecutionInfo
///
///   func createLockmanInfo() -> LockmanSingleExecutionInfo {
///     LockmanSingleExecutionInfo(
///       actionId: "myAction",
///       mode: .boundary
///     )
///   }
/// }
/// ```
///
/// For custom unlock timing:
/// ```swift
/// struct TransitionAction: LockmanAction {
///   typealias I = LockmanSingleExecutionInfo
///
///   func createLockmanInfo() -> LockmanSingleExecutionInfo {
///     LockmanSingleExecutionInfo(
///       actionId: "transition",
///       mode: .boundary
///     )
///   }
///
///   // Release lock after screen transition completes
///   var unlockOption: LockmanUnlockOption { .transition }
/// }
/// ```
///
/// For custom or configured strategies:
/// ```swift
/// struct ConfiguredAction: LockmanAction {
///   typealias I = CustomLockInfo
///
///   func createLockmanInfo() -> CustomLockInfo {
///     CustomLockInfo(
///       strategyId: LockmanStrategyId(
///         name: "RateLimitStrategy",
///         configuration: "limit-100"
///       ),
///       actionId: "apiCall"
///     )
///   }
/// }
/// ```
public protocol LockmanAction: Sendable {
  /// The concrete `LockmanInfo` type used by this action.
  /// This defines what kind of lock information this action carries.
  associatedtype I: LockmanInfo

  /// Creates lock information that defines how this action should be locked or unlocked.
  /// This method should be called once at the beginning of each lock operation.
  /// The returned instance contains all the necessary data for the strategy to make
  /// locking decisions (e.g., action ID, priority, strategy ID, etc.).
  ///
  /// ## Important: Call Once Per Lock Operation
  /// To ensure consistent `uniqueId` values throughout the lock lifecycle,
  /// call this method once and reuse the returned instance for both lock
  /// acquisition and release operations.
  func createLockmanInfo() -> I

  /// The unlock timing option for this action.
  /// This specifies when the lock should be released after the action completes.
  /// If not implemented, defaults to `LockmanManager.config.defaultUnlockOption`.
  var unlockOption: LockmanUnlockOption { get }
}

// MARK: - Default Implementation
extension LockmanAction {
  /// Default unlock option uses the global configuration setting.
  public var unlockOption: LockmanUnlockOption {
    LockmanManager.config.defaultUnlockOption
  }
}
