/// A unique identifier for Lockman actions.
///
/// This typealias leverages String's built-in `Equatable` and `Sendable` conformance
/// to ensure values can be compared and passed safely across concurrent contexts.
public typealias LockmanActionId = String
