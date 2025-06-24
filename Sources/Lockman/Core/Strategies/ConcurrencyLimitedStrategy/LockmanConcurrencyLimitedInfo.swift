import Foundation

/// Information for concurrency-limited locking.
public struct LockmanConcurrencyLimitedInfo: LockmanInfo, Sendable, Equatable {
  /// The action identifier.
  public let actionId: LockmanActionId
  /// The unique identifier for this lock info.
  public let uniqueId: UUID
  /// The concurrency group identifier.
  public let concurrencyId: String
  /// The concurrency limit.
  public let limit: ConcurrencyLimit

  /// Initialize with a predefined concurrency group.
  /// - Parameters:
  ///   - actionId: The action identifier.
  ///   - group: The concurrency group containing id and limit.
  public init(actionId: LockmanActionId, group: any ConcurrencyGroup) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.concurrencyId = group.id
    self.limit = group.limit
  }

  /// Initialize with a direct concurrency limit.
  /// - Parameters:
  ///   - actionId: The action identifier that also serves as the concurrency id.
  ///   - limit: The concurrency limit.
  public init(actionId: LockmanActionId, _ limit: ConcurrencyLimit) {
    self.actionId = actionId
    self.uniqueId = UUID()
    self.concurrencyId = actionId
    self.limit = limit
  }
}

extension LockmanConcurrencyLimitedInfo: CustomDebugStringConvertible {
  public var debugDescription: String {
    "ConcurrencyLimitedInfo(actionId: \(actionId), concurrencyId: \(concurrencyId), limit: \(limit), uniqueId: \(uniqueId))"
  }
}
