/// A protocol composition for group identifiers used by Lockman coordination strategies.
///
/// This typealias combines `Hashable` and `Sendable` to ensure group IDs
/// can be used as dictionary keys and passed safely across concurrent contexts.
///
/// Any type that is both `Hashable` and `Sendable` can be used as a group identifier
/// in coordination strategies.
///
/// ## Usage Examples
/// ```swift
/// // Using String as group ID
/// let stringGroupId: any LockmanGroupId = "navigation"
///
/// // Using custom enum as group ID
/// enum AppGroupId: String, LockmanGroupId {
///     case navigation
///     case dataLoading
///     case authentication
/// }
/// let enumGroupId: any LockmanGroupId = AppGroupId.navigation
///
/// // Using struct as group ID
/// struct FeatureGroupId: LockmanGroupId {
///     let feature: String
///     let version: Int
/// }
/// let structGroupId: any LockmanGroupId = FeatureGroupId(feature: "search", version: 2)
/// ```
public typealias LockmanGroupId = Hashable & Sendable
