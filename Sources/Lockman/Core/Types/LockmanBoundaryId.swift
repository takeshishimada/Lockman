/// A protocol composition for boundary identifiers used by Lockman strategies.
///
/// This typealias combines `Hashable` and `Sendable` to ensure boundary IDs
/// can be used as dictionary keys and passed safely across concurrent contexts.
public typealias LockmanBoundaryId = Hashable & Sendable
