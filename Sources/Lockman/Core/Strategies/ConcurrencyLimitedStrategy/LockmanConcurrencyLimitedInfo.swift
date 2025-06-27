import Foundation

/// Information for concurrency-limited locking.
public struct LockmanConcurrencyLimitedInfo: LockmanInfo, Sendable, Equatable {
  /// The strategy identifier for this lock info.
  public let strategyId: LockmanStrategyId
  /// The action identifier.
  public let actionId: LockmanActionId
  /// The unique identifier for this lock info.
  public let uniqueId: UUID
  /// The concurrency group identifier.
  public let concurrencyId: String
  /// The concurrency limit.
  public let limit: LockmanConcurrencyLimit

  /// Initialize with a predefined concurrency group.
  /// - Parameters:
  ///   - strategyId: The strategy identifier. Defaults to the standard concurrency-limited strategy.
  ///   - actionId: The action identifier.
  ///   - group: The concurrency group containing id and limit.
  public init(
    strategyId: LockmanStrategyId = LockmanConcurrencyLimitedStrategy.makeStrategyId(),
    actionId: LockmanActionId,
    group: any LockmanConcurrencyGroup
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.concurrencyId = group.id
    self.limit = group.limit
  }

  /// Initialize with a direct concurrency limit.
  /// - Parameters:
  ///   - strategyId: The strategy identifier. Defaults to the standard concurrency-limited strategy.
  ///   - actionId: The action identifier that also serves as the concurrency id.
  ///   - limit: The concurrency limit.
  public init(
    strategyId: LockmanStrategyId = LockmanConcurrencyLimitedStrategy.makeStrategyId(),
    actionId: LockmanActionId,
    _ limit: LockmanConcurrencyLimit
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.concurrencyId = actionId
    self.limit = limit
  }
}

extension LockmanConcurrencyLimitedInfo: CustomDebugStringConvertible {
  public var debugDescription: String {
    "ConcurrencyLimitedInfo(strategyId: \(strategyId), actionId: \(actionId), concurrencyId: \(concurrencyId), limit: \(limit), uniqueId: \(uniqueId))"
  }

  public var debugAdditionalInfo: String {
    "concurrency: \(concurrencyId) limit: \(limit)"
  }
}
