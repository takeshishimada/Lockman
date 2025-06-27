/// Protocol for defining concurrency groups with their limits.
public protocol LockmanConcurrencyGroup: Sendable {
  /// Unique identifier for this concurrency group.
  var id: String { get }
  /// The concurrency limit for this group.
  var limit: LockmanConcurrencyLimit { get }
}
