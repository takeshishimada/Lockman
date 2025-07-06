/// Error types that can occur during Lockman macro expansion.
///
/// This enum represents various error conditions that may arise when processing
/// Lockman macros, providing detailed error messages to help developers identify
/// and resolve issues with their macro usage.
public enum LockmanMacroError: Error, CustomStringConvertible {
  /// Indicates that the macro was applied to an invalid declaration type.
  ///
  /// This error occurs when a Lockman macro is applied to something other than
  /// an enum declaration, or when the declaration structure is malformed.
  ///
  /// - Parameter message: A detailed description of why the declaration is invalid
  case invalidDeclaration(String)

  /// Indicates that an enum case name is invalid or unsupported.
  ///
  /// This error occurs when enum cases have names that cannot be properly
  /// processed by the macro, such as cases with associated values that aren't
  /// handled, or cases with invalid Swift identifiers.
  ///
  /// - Parameter message: A detailed description of the case name issue
  case invalidCaseName(String)

  /// Indicates that the arguments provided to the macro are invalid.
  ///
  /// This error occurs when the macro receives arguments that don't match
  /// the expected signature, such as wrong parameter types, missing required
  /// parameters, or invalid strategy specifications.
  ///
  /// - Parameter message: A detailed description of the argument validation failure
  case invalidArguments(String)

  /// Indicates that an unsupported number of strategies was provided.
  ///
  /// This error occurs when the @LockmanCompositeStrategy macro is used with
  /// fewer than 2 or more than 5 strategies, which are the currently supported limits.
  ///
  /// - Parameter count: The actual number of strategies that were provided
  case unsupportedStrategyCount(Int)

  /// Indicates that strategy type resolution failed during macro expansion.
  ///
  /// This error occurs when the macro cannot properly resolve or process
  /// the strategy types provided as arguments, such as when type constraints
  /// aren't met or when strategy types cannot be determined from the context.
  ///
  /// - Parameter message: A detailed description of the strategy resolution failure
  case strategyResolutionFailed(String)

  /// A human-readable description of the error.
  ///
  /// This property provides localized error messages that can be displayed
  /// to developers when macro expansion fails, helping them understand
  /// what went wrong and how to fix their code.
  public var description: String {
    switch self {
    case .invalidDeclaration(let message):
      return message
    case .invalidCaseName(let message):
      return message
    case .invalidArguments(let message):
      return message
    case .unsupportedStrategyCount(let count):
      return "@LockmanCompositeStrategy supports 2-5 strategies, but \(count) were provided."
    case .strategyResolutionFailed(let message):
      return "Failed to resolve strategy: \(message)"
    }
  }
}
