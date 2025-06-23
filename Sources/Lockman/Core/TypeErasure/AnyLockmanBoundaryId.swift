// MARK: - AnyLockmanBoundaryId

/// A type-erased wrapper for any `LockmanBoundaryId`, allowing heterogeneous boundary IDs
/// to be stored and compared in a uniform manner.
///
/// This wrapper enables different types of boundary identifiers to coexist in the same
/// collection while maintaining type safety for hashing and equality operations.
///
/// ## Type Erasure Benefits
/// - Allows `Dictionary<AnyLockmanBoundaryId, Value>` with mixed key types
/// - Maintains value semantics and equality comparison
/// - Preserves hashing behavior from underlying types
///
/// ## Thread Safety
/// Marked as `@unchecked Sendable` because `AnyHashable` is thread-safe for
/// hashing and equality operations, and the wrapper doesn't add mutable state.
///
/// ## Usage Example
/// ```swift
/// enum UserBoundary: String, LockmanBoundaryId {
///   case profile, settings
/// }
///
/// struct SessionBoundary: LockmanBoundaryId {
///   let sessionId: String
/// }
///
/// // Both can be used as keys in the same collection
/// let userKey = AnyLockmanBoundaryId(UserBoundary.profile)
/// let sessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "abc123"))
/// ```
public struct AnyLockmanBoundaryId: Hashable, @unchecked Sendable {
  // MARK: - Private Properties

  /// The type-erased underlying value using `AnyHashable` for uniform storage.
  private let base: AnyHashable

  // MARK: - Initialization

  /// Creates a new `AnyLockmanBoundaryId` by erasing the type of a value that conforms to `LockmanBoundaryId`.
  ///
  /// - Parameter value: An instance conforming to `LockmanBoundaryId` to be wrapped
  ///
  /// ## Design Note
  /// The underlying value is stored as `AnyHashable`, which preserves the original
  /// type's hashing and equality behavior while enabling uniform storage.
  public init(_ value: any LockmanBoundaryId) {
    base = AnyHashable(value)
  }

  // MARK: - Hashable Implementation

  /// Compares two `AnyLockmanBoundaryId` instances for equality by comparing their underlying `AnyHashable` values.
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
  public static func == (lhs: AnyLockmanBoundaryId, rhs: AnyLockmanBoundaryId) -> Bool {
    lhs.base == rhs.base
  }

  /// Generates hash values that include type information to prevent
  /// different boundary ID types with identical values from colliding.
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
