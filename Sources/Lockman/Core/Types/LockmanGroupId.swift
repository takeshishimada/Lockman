/// A group identifier used by Lockman strategies, combining `Hashable` and `Sendable`
/// to ensure unique and concurrent-safe keys.
///
/// This type alias enables any type that is both `Hashable` and `Sendable` to be used
/// as a group identifier in coordination strategies.
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