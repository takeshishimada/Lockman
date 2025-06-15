/// A boundary identifier used by Lockman strategies, combining `Hashable` and `Sendable`
/// to ensure unique and concurrent-safe keys.
public typealias LockmanBoundaryId = Hashable & Sendable
