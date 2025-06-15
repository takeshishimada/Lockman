/// A unique identifier used by Lockman actions, combining `Equatable` and `Sendable`
/// to ensure values can be compared and passed safely across concurrent contexts.
public typealias LockmanActionId = String
