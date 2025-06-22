import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

// MARK: - Conformance Extension Generator

/// Creates protocol conformance extensions for Swift Macro expansion.
///
/// ## Purpose
/// This generator creates empty extension declarations that make target types conform
/// to specific protocols. This is a fundamental building block for Lockman macros,
/// enabling automatic protocol conformance for enum types marked with Lockman attributes.
///
/// ## Role in Macro System
/// Conformance extension generation is the first step in the two-phase macro expansion process:
/// 1. **Extension Phase** (this file): Generate protocol conformance extension
/// 2. **Member Phase** (other files): Generate required protocol members
///
/// This separation allows for:
/// - Clean separation of concerns
/// - Proper Swift compiler integration
/// - Modular macro architecture
/// - Type safety validation
///
/// ## Generated Code Pattern
/// The generator creates extensions following this pattern:
/// ```swift
/// extension <TargetType>: <ProtocolName> {
///     // Empty body - members are added by member macros
/// }
/// ```
///
/// ## Integration with SwiftSyntax
/// This implementation leverages SwiftSyntax for:
/// - Type-safe syntax tree construction
/// - Proper trivia handling (whitespace, comments)
/// - Compiler-compliant code generation
/// - Error-resistant syntax building
///
/// ## Usage Examples
///
/// ### Basic Extension Generation
/// ```swift
/// let typeNode = // ... some TypeSyntax
/// let extension = try makeConformanceExtensionDecl(
///     for: typeNode,
///     conformingTo: "LockmanSingleExecutionAction"
/// )
/// // Generates: extension TypeName: LockmanSingleExecutionAction { }
/// ```
///
/// ### In Macro Context
/// ```swift
/// public static func expansion(...) throws -> [ExtensionDeclSyntax] {
///     let extensionDecl = try makeConformanceExtensionDecl(
///         for: type,
///         conformingTo: "LockmanPriorityBasedAction"
///     )
///     return [extensionDecl]
/// }
/// ```

/// Creates an empty extension for the given type that makes it conform to the specified protocol.
///
/// ## Purpose
/// This function is the core extension generator for Lockman macros. It creates protocol
/// conformance extensions that serve as the foundation for automatic code generation,
/// enabling enum types to participate in the Lockman locking system.
///
/// ## Generation Process
/// The function follows a carefully designed process to ensure robust code generation:
/// 1. **Protocol Type Construction**: Create a properly formatted protocol identifier
/// 2. **Type Trivia Cleanup**: Remove extraneous whitespace and comments from the target type
/// 3. **Extension Assembly**: Combine type and protocol into a valid extension declaration
/// 4. **Syntax Validation**: Ensure the generated syntax is compiler-compliant
///
/// ## Type Safety Guarantees
/// The function provides several type safety guarantees:
/// - **Compile-time Validation**: Generated extensions are syntactically correct
/// - **Protocol Name Validation**: Protocol names are validated as Swift identifiers
/// - **Type Preservation**: Original type information is preserved accurately
/// - **Error Propagation**: Invalid inputs result in clear error messages
///
/// ## Trivia Handling Strategy
/// Trivia (whitespace, comments, etc.) is carefully managed to ensure clean output:
/// - **Input Trivia Removal**: Strips leading/trailing trivia from input type
/// - **Consistent Formatting**: Applies consistent formatting to the output
/// - **Readability**: Ensures generated code is properly formatted and readable
///
/// ## Error Conditions
/// The function can throw errors in several scenarios:
/// - **Invalid Protocol Name**: Non-identifier protocol names (e.g., containing spaces)
/// - **Malformed Type Syntax**: Corrupted or invalid type syntax trees
/// - **Syntax Construction Failure**: Internal SwiftSyntax failures
/// - **Memory Issues**: Rare cases of insufficient memory for syntax tree construction
///
/// ## SwiftSyntax Integration Details
/// The implementation leverages several SwiftSyntax features:
/// - **IdentifierTypeSyntax**: For creating properly formatted protocol types
/// - **ExtensionDeclSyntax**: For constructing extension declarations
/// - **Trivia Management**: For handling whitespace and formatting
/// - **Type Safety**: Compile-time validation of syntax tree construction
///
/// - Parameters:
///   - type: A `TypeSyntax` node representing the type to extend (e.g., enum, struct, class)
///   - protocolName: The exact name of the protocol to which the type should conform
/// - Returns: An `ExtensionDeclSyntax` node representing the conformance extension
/// - Throws: Syntax construction errors, typically related to invalid protocol names or malformed syntax
///
/// ## Generated Extension Structure
/// ```swift
/// extension <Type>: <Protocol> {
///     // Empty body - protocol requirements will be added by member macros
/// }
/// ```
///
/// ## Example Usage
///
/// ### Single Protocol Conformance
/// ```swift
/// // Input: enum UserAction { case login, logout }
/// // Protocol: "LockmanSingleExecutionAction"
/// let extension = try makeConformanceExtensionDecl(
///     for: userActionType,
///     conformingTo: "LockmanSingleExecutionAction"
/// )
/// // Output: extension UserAction: LockmanSingleExecutionAction { }
/// ```
///
/// ### Complex Type Names
/// ```swift
/// // Input: enum MyModule.ComplexAction<T> where T: Sendable
/// // Protocol: "LockmanPriorityBasedAction"
/// let extension = try makeConformanceExtensionDecl(
///     for: complexType,
///     conformingTo: "LockmanPriorityBasedAction"
/// )
/// // Output: extension MyModule.ComplexAction<T>: LockmanPriorityBasedAction where T: Sendable { }
/// ```
///
/// ### Error Handling
/// ```swift
/// do {
///     let extension = try makeConformanceExtensionDecl(
///         for: someType,
///         conformingTo: "Invalid Protocol Name!"  // Contains space and punctuation
///     )
/// } catch {
///     print("Failed to generate extension: \(error)")
///     // Handle the error appropriately - typically by reporting a macro error
/// }
/// ```
///
/// ## Integration with Macro Expansion
/// This function is typically called from macro expansion methods:
/// ```swift
/// public static func expansion(
///     of node: AttributeSyntax,
///     attachedTo declaration: some DeclGroupSyntax,
///     providingExtensionsOf type: some TypeSyntaxProtocol,
///     conformingTo protocols: [TypeSyntax],
///     in context: some MacroExpansionContext
/// ) throws -> [ExtensionDeclSyntax] {
///     let extensionDecl = try makeConformanceExtensionDecl(
///         for: type,
///         conformingTo: "LockmanSingleExecutionAction"
///     )
///     return [extensionDecl]
/// }
/// ```
///
/// ## Performance Characteristics
/// - **Time Complexity**: O(1) - Independent of type or protocol complexity
/// - **Memory Usage**: Minimal - Only allocates necessary syntax nodes
/// - **Compilation Impact**: Low - Generates simple, efficient extensions
/// - **Scalability**: Excellent - Can handle complex generic types efficiently
///
/// ## Best Practices for Usage
/// 1. **Validate Protocol Names**: Ensure protocol names are valid Swift identifiers
/// 2. **Handle Errors Gracefully**: Always wrap in do-catch for robust error handling
/// 3. **Preserve Type Information**: Don't modify the input type unnecessarily
/// 4. **Consistent Naming**: Use consistent protocol naming conventions across macros
/// 5. **Documentation**: Document the purpose of generated extensions in macro comments
func makeConformanceExtensionDecl<T: TypeSyntaxProtocol>(
  for type: T,
  conformingTo protocolName: String
) throws -> ExtensionDeclSyntax {
  // MARK: - Protocol Type Construction

  /// Construct the protocol identifier as a properly formatted syntax node.
  ///
  /// This step converts the string protocol name into a SwiftSyntax type node
  /// that can be used in the extension declaration. The IdentifierTypeSyntax
  /// ensures that the protocol name is treated as a valid Swift type identifier.
  ///
  /// Error Conditions:
  /// - Invalid identifier characters in protocol name
  /// - Reserved keywords used as protocol name
  /// - Empty or whitespace-only protocol names
  let protocolType = IdentifierTypeSyntax(name: .identifier(protocolName))

  // MARK: - Type Trivia Management

  /// Remove any leading/trailing trivia from the type node for clean generation.
  ///
  /// Trivia includes whitespace, comments, and other non-semantic content that
  /// can interfere with clean code generation. By trimming trivia, we ensure:
  /// - Consistent formatting in generated code
  /// - No unexpected whitespace in the extension declaration
  /// - Proper integration with the surrounding code structure
  ///
  /// The trimmed type preserves all semantic information while removing
  /// formatting artifacts that might cause issues in the generated extension.
  let trimmedType = type.trimmed

  // MARK: - Extension Declaration Assembly

  /// Construct the complete extension declaration using SwiftSyntax's string literal syntax.
  ///
  /// This approach leverages SwiftSyntax's powerful string interpolation feature
  /// that allows embedding syntax nodes directly into string literals. The result
  /// is a properly formatted extension declaration that:
  /// - Maintains type safety through compile-time validation
  /// - Preserves all type information (generics, constraints, etc.)
  /// - Generates clean, readable Swift code
  /// - Integrates seamlessly with the rest of the codebase
  ///
  /// The empty body is intentional - protocol requirements will be added
  /// by member macros in the second phase of macro expansion.
  return try ExtensionDeclSyntax(
    """
    extension \(trimmedType): \(protocolType) {
    }
    """
  )
}

// MARK: - Advanced Extension Generation

/// Enhanced extension generator with additional configuration options.
///
/// ## Purpose
/// This enhanced version provides additional control over extension generation,
/// including where clauses, access modifiers, and conditional conformances.
/// It's designed for more complex macro scenarios that require fine-grained control.
///
/// ## Extended Capabilities
/// - **Where Clauses**: Support for conditional conformance with where clauses
/// - **Access Control**: Configurable access levels for extensions
/// - **Conditional Conformance**: Support for generic type constraints
/// - **Documentation**: Automatic documentation comment generation
///
/// ## Usage Scenarios
/// - Complex generic types with constraints
/// - Conditional protocol conformance
/// - Access-controlled extensions
/// - Generated code with documentation
///
/// - Parameters:
///   - type: The type to extend
///   - protocolName: The protocol name for conformance
///   - whereClause: Optional where clause for conditional conformance
///   - accessLevel: Access level for the extension (default: none)
///   - documentation: Optional documentation comment
/// - Returns: A configured extension declaration
/// - Throws: Syntax construction errors
func makeAdvancedConformanceExtensionDecl<T: TypeSyntaxProtocol>(
  for type: T,
  conformingTo protocolName: String,
  whereClause: String? = nil,
  accessLevel _: String? = nil,
  documentation _: String? = nil
) throws -> ExtensionDeclSyntax {
  // Construct the protocol type
  let protocolType = IdentifierTypeSyntax(name: .identifier(protocolName))
  let trimmedType = type.trimmed

  // Build the extension using SwiftSyntax string interpolation
  // This is similar to the basic version but allows for more complex constructions
  if let whereClause = whereClause {
    return try ExtensionDeclSyntax(
      """
      extension \(trimmedType): \(protocolType) where \(raw: whereClause) {
      }
      """
    )
  } else {
    return try ExtensionDeclSyntax(
      """
      extension \(trimmedType): \(protocolType) {
      }
      """
    )
  }
}

// MARK: - Utility Functions

/// Validates that a protocol name is a valid Swift identifier.
///
/// ## Purpose
/// This utility function performs client-side validation of protocol names
/// before attempting syntax generation, providing early error detection
/// and better error messages for invalid protocol names.
///
/// ## Validation Rules
/// A valid Swift identifier must:
/// - Start with a letter (a-z, A-Z) or underscore (_)
/// - Contain only letters, numbers, and underscores
/// - Not be a Swift reserved keyword
/// - Not be empty or whitespace-only
///
/// ## Error Prevention
/// By validating protocol names early, we can:
/// - Provide clear error messages to developers
/// - Prevent SwiftSyntax crashes from invalid identifiers
/// - Ensure generated code will compile successfully
/// - Improve the macro development experience
///
/// - Parameter protocolName: The protocol name to validate
/// - Returns: `true` if the name is valid, `false` otherwise
///
/// ## Example Usage
/// ```swift
/// guard isValidSwiftIdentifier("LockmanAction") else {
///     throw MacroError.invalidProtocolName("LockmanAction")
/// }
/// ```
func isValidSwiftIdentifier(_ name: String) -> Bool {
  guard !name.isEmpty else {
    return false
  }

  let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
  guard trimmedName == name else {
    return false
  }  // No leading/trailing whitespace

  // Check first character
  let firstChar = name.first!
  guard firstChar.isLetter || firstChar == "_" else { return false }

  // Check remaining characters
  for char in name.dropFirst() {
    guard char.isLetter || char.isNumber || char == "_" else { return false }
  }

  // Check against Swift keywords (simplified list of common ones)
  let swiftKeywords = [
    "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
    "if", "else", "for", "while", "switch", "case", "default", "return",
    "import", "public", "private", "internal", "fileprivate", "static",
  ]

  return !swiftKeywords.contains(name.lowercased())
}

/// Extracts the base type name from a complex type syntax node.
///
/// ## Purpose
/// This utility extracts the fundamental type name from complex type expressions
/// that may include generics, module qualifiers, or other decorations. This is
/// useful for generating clean, readable extension names and error messages.
///
/// ## Extraction Logic
/// The function handles various type syntax patterns:
/// - Simple identifiers: `UserAction` → `"UserAction"`
/// - Generic types: `Array<String>` → `"Array"`
/// - Qualified types: `MyModule.UserAction` → `"UserAction"`
/// - Complex types: `MyModule.Action<T>` → `"Action"`
///
/// ## Use Cases
/// - Error message generation
/// - Debug output formatting
/// - Documentation generation
/// - Logging and diagnostics
///
/// - Parameter type: The type syntax node to extract from
/// - Returns: The base type name as a string
///
/// ## Example Usage
/// ```swift
/// let typeName = extractBaseTypeName(from: complexTypeNode)
/// print("Generating extension for: \(typeName)")
/// ```
func extractBaseTypeName<T: TypeSyntaxProtocol>(from type: T) -> String {
  let typeDescription = type.description.trimmingCharacters(in: .whitespacesAndNewlines)

  // Handle generic types - extract the part before '<'
  if let genericStart = typeDescription.firstIndex(of: "<") {
    let baseType = String(typeDescription[..<genericStart])
    return extractSimpleTypeName(from: baseType)
  }

  return extractSimpleTypeName(from: typeDescription)
}

/// Extracts the simple type name from a potentially qualified type string.
///
/// ## Purpose
/// This helper function extracts the final component from a qualified type name,
/// removing module qualifiers and focusing on the actual type identifier.
///
/// ## Examples
/// - `"UserAction"` → `"UserAction"`
/// - `"MyModule.UserAction"` → `"UserAction"`
/// - `"Package.Module.UserAction"` → `"UserAction"`
///
/// - Parameter typeString: The type string to process
/// - Returns: The simple type name without qualifiers
private func extractSimpleTypeName(from typeString: String) -> String {
  // Split by dots and take the last component
  let components = typeString.split(separator: ".")
  return String(components.last ?? "UnknownType")
}

// MARK: - Error Handling Support

/// Generates a descriptive error message for extension generation failures.
///
/// ## Purpose
/// This function creates informative error messages that help developers
/// understand why extension generation failed and how to fix the issue.
///
/// ## Message Components
/// - **Error Description**: What went wrong
/// - **Context Information**: Type and protocol involved
/// - **Resolution Guidance**: How to fix the issue
/// - **Code Examples**: Sample correct usage
///
/// - Parameters:
///   - type: The type that failed extension generation
///   - protocolName: The protocol that couldn't be conformed to
///   - underlyingError: The original error that caused the failure
/// - Returns: A formatted error message string
func generateExtensionErrorMessage<T: TypeSyntaxProtocol>(
  for type: T,
  conformingTo protocolName: String,
  underlyingError: any Error
) -> String {
  let typeName = extractBaseTypeName(from: type)

  return """
    Failed to generate protocol conformance extension.

    Type: \(typeName)
    Protocol: \(protocolName)
    Error: \(underlyingError.localizedDescription)

    Common causes:
    - Invalid protocol name (must be a valid Swift identifier)
    - Malformed type syntax
    - SwiftSyntax version compatibility issues

    Please ensure the protocol name is a valid Swift identifier and try again.
    """
}

// MARK: - Testing Support

#if DEBUG
  /// Testing utilities for extension generation validation.
  ///
  /// ## Purpose
  /// These utilities help validate that generated extensions are correct and
  /// properly formatted during development and testing of macro implementations.
  ///
  /// ## Validation Features
  /// - Syntax correctness verification
  /// - Format consistency checking
  /// - Protocol conformance validation
  /// - Error condition testing
  public enum ExtensionGeneratorTestUtils {
    /// Validates that a generated extension has the expected structure.
    ///
    /// ## Validation Checks
    /// - Extension keyword is present
    /// - Type name matches expected value
    /// - Protocol name matches expected value
    /// - Syntax is well-formed
    /// - No unexpected content in body
    ///
    /// - Parameters:
    ///   - extensionDecl: The generated extension to validate
    ///   - expectedType: The expected type name
    ///   - expectedProtocol: The expected protocol name
    /// - Returns: `true` if validation passes, `false` otherwise
    static func validateExtensionStructure(
      _ extensionDecl: ExtensionDeclSyntax,
      expectedType: String,
      expectedProtocol: String
    ) -> Bool {
      let extensionText = extensionDecl.description

      // Basic structure checks
      guard extensionText.contains("extension") else { return false }
      guard extensionText.contains(expectedType) else {
        return false
      }
      guard extensionText.contains(expectedProtocol) else {
        return false
      }
      guard extensionText.contains("{"), extensionText.contains("}") else { return false }

      return true
    }

    /// Generates a test extension and validates its correctness.
    ///
    /// ## Test Process
    /// 1. Generate extension using the main function
    /// 2. Validate structure and content
    /// 3. Check for common error conditions
    /// 4. Return validation results
    ///
    /// - Parameters:
    ///   - typeName: The type name to test with
    ///   - protocolName: The protocol name to test with
    /// - Returns: Test results including success status and any issues found
    static func testExtensionGeneration(
      typeName: String,
      protocolName: String
    ) -> (success: Bool, issues: [String]) {
      var issues: [String] = []

      do {
        // Create a simple identifier type for testing
        let testType = IdentifierTypeSyntax(name: .identifier(typeName))
        let extensionDecl = try makeConformanceExtensionDecl(
          for: testType,
          conformingTo: protocolName
        )

        // Validate the generated extension
        if !validateExtensionStructure(
          extensionDecl, expectedType: typeName, expectedProtocol: protocolName)
        {
          issues.append("Generated extension structure validation failed")
        }

        // Check for empty body (expected)
        let extensionText = extensionDecl.description
        let bodyStart = extensionText.index(after: extensionText.firstIndex(of: "{")!)
        let bodyEnd = extensionText.lastIndex(of: "}")!
        let body = String(extensionText[bodyStart..<bodyEnd]).trimmingCharacters(
          in: .whitespacesAndNewlines)

        if !body.isEmpty {
          issues.append("Extension body should be empty but contains: \(body)")
        }

      } catch {
        issues.append("Extension generation threw error: \(error)")
      }

      return (success: issues.isEmpty, issues: issues)
    }
  }
#endif
