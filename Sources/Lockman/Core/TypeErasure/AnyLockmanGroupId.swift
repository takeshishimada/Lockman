// MARK: - AnyLockmanGroupId

/// A type-erased wrapper for any `LockmanGroupId`, allowing heterogeneous group IDs
/// to be stored and compared in a uniform manner.
///
/// This wrapper enables different types of group identifiers to coexist in the same
/// collection while maintaining type safety for hashing and equality operations.
///
/// ## Type Erasure Benefits
/// - Allows `Set<AnyLockmanGroupId>` with mixed group ID types
/// - Maintains value semantics and equality comparison
/// - Preserves hashing behavior from underlying types
///
/// ## Thread Safety
/// Marked as `@unchecked Sendable` because `AnyHashable` is thread-safe for
/// hashing and equality operations, and the wrapper doesn't add mutable state.
///
/// ## Usage Example
/// ```swift
/// enum FeatureGroup: String, LockmanGroupId {
///   case navigation, dataSync, authentication
/// }
///
/// struct ModuleGroup: LockmanGroupId {
///   let module: String
///   let submodule: String
/// }
///
/// // Both can be used as group IDs in the same collection
/// let featureGroup = AnyLockmanGroupId(FeatureGroup.navigation)
/// let moduleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "profile"))
///
/// // Can be stored in the same Set
/// let groupIds: Set<AnyLockmanGroupId> = [featureGroup, moduleGroup]
/// ```
public struct AnyLockmanGroupId: Hashable, @unchecked Sendable {
  // MARK: - Private Properties

  /// The type-erased underlying value using `AnyHashable` for uniform storage.
  private let base: AnyHashable

  // MARK: - Initialization

  /// Creates a new `AnyLockmanGroupId` by erasing the type of a value that conforms to `LockmanGroupId`.
  ///
  /// - Parameter value: An instance conforming to `LockmanGroupId` to be wrapped
  ///
  /// ## Design Note
  /// The underlying value is stored as `AnyHashable`, which preserves the original
  /// type's hashing and equality behavior while enabling uniform storage.
  public init(_ value: any LockmanGroupId) {
    base = AnyHashable(value)
  }

  // MARK: - Hashable Implementation

  /// Compares two `AnyLockmanGroupId` instances for equality by comparing their underlying `AnyHashable` values.
  ///
  /// Two instances are equal if their wrapped values are equal according to
  /// the underlying type's equality implementation.
  ///
  /// - Parameters:
  ///   - lhs: The left-hand side wrapper to compare
  ///   - rhs: The right-hand side wrapper to compare
  /// - Returns: `true` if the wrapped values are equal; otherwise, `false`
  ///
  /// ## Type Safety
  /// Different types with identical values will not be equal due to `AnyHashable`'s
  /// type-aware equality comparison.
  public static func == (lhs: AnyLockmanGroupId, rhs: AnyLockmanGroupId) -> Bool {
    lhs.base == rhs.base
  }

  /// Generates hash values that include type information to prevent
  /// different group ID types with identical values from colliding.
  ///
  /// - Parameter hasher: The hasher to use when combining the components of this instance
  ///
  /// ## Hash Collision Prevention
  /// Since `AnyHashable` includes type information in its hash, two different
  /// types with the same value will produce different hash values, preventing
  /// unintended collisions in hash-based collections.
  public func hash(into hasher: inout Hasher) {
    base.hash(into: &hasher)
  }
}

// MARK: - CustomDebugStringConvertible

extension AnyLockmanGroupId: CustomDebugStringConvertible {
  /// A textual representation suitable for debugging.
  public var debugDescription: String {
    "AnyLockmanGroupId(\(base))"
  }
}
