import Foundation

/// A type-safe identifier for Lockman strategies that supports both built-in and user-defined strategies.
///
/// `LockmanStrategyId` provides a flexible way to identify strategies while maintaining type safety.
/// It supports multiple initialization patterns to accommodate different use cases:
///
/// ## Built-in Strategies
/// ```swift
/// // Type-based initialization for compile-time safety
/// let id = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
/// ```
///
/// ## User-defined Strategies
/// ```swift
/// // Direct string initialization for maximum flexibility
/// let customId = LockmanStrategyId("MyApp.CustomStrategy")
///
/// // Name-based initialization for organization
/// let namedId = LockmanStrategyId(
///     name: "RateLimitStrategy"
/// )
/// ```
///
/// ## Configuration Variants
/// ```swift
/// // Same strategy with different configurations
/// let timeout30 = LockmanStrategyId(
///     name: "CacheStrategy",
///     configuration: "timeout-30"
/// )
/// let timeout60 = LockmanStrategyId(
///     name: "CacheStrategy",
///     configuration: "timeout-60"
/// )
/// ```
public struct LockmanStrategyId: Hashable, Sendable, CustomStringConvertible,
  ExpressibleByStringLiteral
{
  /// The unique identifier string for the strategy.
  ///
  /// This value is used as the key when registering and resolving strategies
  /// in the `LockmanStrategyContainer`.
  public let value: String

  // MARK: - Initialization

  /// Creates a strategy ID from a raw string value.
  ///
  /// This is the most flexible initializer, allowing any string to be used as an ID.
  /// Useful for dynamic or user-defined strategies.
  ///
  /// - Parameter value: The unique identifier string
  public init(_ value: String) {
    self.value = value
  }

  /// Creates a strategy ID from a strategy type with an optional custom identifier.
  ///
  /// If no identifier is provided, uses the fully qualified type name (including module).
  /// This ensures uniqueness across different modules.
  ///
  /// - Parameters:
  ///   - type: The strategy type
  ///   - identifier: Optional custom identifier to use instead of the type name
  ///
  /// ## Examples
  /// ```swift
  /// // Uses fully qualified type name
  /// let id1 = LockmanStrategyId(type: MyStrategy.self)
  /// // => "MyModule.MyStrategy"
  ///
  /// // Uses custom identifier
  /// let id2 = LockmanStrategyId(type: MyStrategy.self, identifier: "custom-strategy")
  /// // => "custom-strategy"
  /// ```
  public init<S: LockmanStrategy>(type: S.Type, identifier: String? = nil) {
    if let identifier = identifier {
      self.value = identifier
    } else {
      // Use String(reflecting:) for fully qualified name including module
      self.value = String(reflecting: type)
    }
  }

  /// Creates a strategy ID with name and optional configuration.
  ///
  /// This initializer provides a structured way to create IDs with optional
  /// configuration suffixes.
  ///
  /// - Parameters:
  ///   - name: The strategy name
  ///   - configuration: Optional configuration suffix
  ///
  /// ## Format
  /// - Without configuration: `"name"`
  /// - With configuration: `"name:configuration"`
  ///
  /// ## Examples
  /// ```swift
  /// let id = LockmanStrategyId(
  ///     name: "RateLimitStrategy",
  ///     configuration: "limit-100"
  /// )
  /// // => "RateLimitStrategy:limit-100"
  /// ```
  public init(name: String, configuration: String? = nil) {
    if let config = configuration {
      self.value = "\(name):\(config)"
    } else {
      self.value = name
    }
  }

  // MARK: - ExpressibleByStringLiteral

  /// Creates a strategy ID from a string literal.
  ///
  /// Enables convenient syntax:
  /// ```swift
  /// let id: LockmanStrategyId = "MyApp.CustomStrategy"
  /// ```
  public init(stringLiteral value: StringLiteralType) {
    self.value = value
  }

  // MARK: - CustomStringConvertible

  /// A textual representation of this strategy ID.
  public var description: String {
    value
  }

  // MARK: - Convenience Factory Methods

  /// Creates a strategy ID from a strategy type.
  ///
  /// Convenience method for cleaner syntax:
  /// ```swift
  /// let id = .from(MyStrategy.self)
  /// ```
  public static func from<S: LockmanStrategy>(_ type: S.Type) -> Self {
    Self(type: type)
  }

  /// Creates a strategy ID from a strategy type with a custom identifier.
  ///
  /// Convenience method for cleaner syntax:
  /// ```swift
  /// let id = .from(MyStrategy.self, identifier: "custom-id")
  /// ```
  public static func from<S: LockmanStrategy>(_ type: S.Type, identifier: String) -> Self {
    Self(type: type, identifier: identifier)
  }
}

// MARK: - Common Strategy IDs

extension LockmanStrategyId {
  /// The strategy ID for single execution strategy.
  public static let singleExecution = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)

  /// The strategy ID for priority-based strategy.
  public static let priorityBased = LockmanStrategyId(type: LockmanPriorityBasedStrategy.self)

  /// The strategy ID for group coordination strategy.
  public static let groupCoordination = LockmanStrategyId(
    type: LockmanGroupCoordinationStrategy.self)

  /// The strategy ID for concurrency limited strategy.
  public static let concurrencyLimited = LockmanStrategyId(
    type: LockmanConcurrencyLimitedStrategy.self)
}
