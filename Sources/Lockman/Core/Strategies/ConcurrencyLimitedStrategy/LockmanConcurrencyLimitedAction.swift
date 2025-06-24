/// Protocol for actions that support concurrency limiting.
public protocol LockmanConcurrencyLimitedAction: LockmanAction
where I == LockmanConcurrencyLimitedInfo {
  /// The name of the action (typically the case name).
  var actionName: String { get }
}

extension LockmanConcurrencyLimitedAction {
  /// The strategy identifier for concurrency-limited locking.
  public var strategyId: LockmanStrategyId {
    LockmanConcurrencyLimitedStrategy.makeStrategyId()
  }
}
