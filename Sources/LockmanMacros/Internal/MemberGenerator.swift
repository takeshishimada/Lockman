import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

// MARK: - Public API

/// Generates `actionName` member declarations for an enum type.
///
/// This function extracts enum case information and generates a computed property
/// that returns the case name as a string. The generated property uses a switch
/// statement to map each enum case to its corresponding string representation.
///
/// ## Generated Code Pattern
/// ```swift
/// var actionName: String {
///   switch self {
///   case .login: return "login"
///   case .logout(_): return "logout"
///   }
/// }
/// ```
///
/// ## Error Handling
/// - Returns empty array if declaration is not an enum
/// - Emits diagnostic messages for invalid declarations
/// - Gracefully handles enums with no cases
///
/// - Parameters:
///   - macroName: The name of the macro being processed (for diagnostic messages)
///   - attributeNode: The attribute syntax node that triggered generation
///   - declaration: The declaration to process (must be an enum)
///   - context: Macro expansion context for emitting diagnostics
/// - Returns: Array of generated member declarations (empty if invalid)
func makeActionNameMemberDecl(
  name macroName: String,
  of attributeNode: AttributeSyntax,
  providingMembersOf declaration: some DeclGroupSyntax,
  in context: some MacroExpansionContext
) -> [DeclSyntax] {
  guard
    let enumDecl = extractEnumDeclaration(
      macroName: macroName,
      from: declaration,
      attributeNode: attributeNode,
      context: context
    )
  else {
    return []
  }

  return generateActionNameMembers(for: enumDecl)
}

// MARK: - Deprecated Functions
// The following functions were used for strategyType generation but are no longer needed.
// They are kept here temporarily for reference.

// MARK: - Enum Declaration Extraction

/// Extracts and validates an enum declaration from a declaration group.
///
/// This function performs type checking to ensure the provided declaration
/// is actually an enum. If validation fails, it emits appropriate diagnostic
/// messages to guide developers toward correct usage.
///
/// ## Validation Process
/// 1. Attempts to cast declaration to `EnumDeclSyntax`
/// 2. If casting fails, emits diagnostic error
/// 3. Returns validated enum declaration or nil
///
/// ## Error Diagnostics
/// When validation fails, the function emits a diagnostic message that:
/// - Clearly states the macro can only be applied to enums
/// - References the specific macro name for context
/// - Points to the exact location of the error
///
/// - Parameters:
///   - macroName: Name of the macro (used in error messages)
///   - declaration: The declaration to validate
///   - attributeNode: The attribute node (for error location)
///   - context: Macro expansion context for emitting diagnostics
/// - Returns: Validated enum declaration or nil if validation fails
private func extractEnumDeclaration(
  macroName: String,
  from declaration: some DeclGroupSyntax,
  attributeNode: AttributeSyntax,
  context: some MacroExpansionContext
) -> EnumDeclSyntax? {
  guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
    let diagnostic = Diagnostic(
      node: Syntax(attributeNode),
      message: MacroValidationError(
        message: "@\(macroName) can only be attached to an enum declaration.",
        macroName: macroName
      )
    )
    context.diagnose(diagnostic)
    return nil
  }

  return enumDecl
}

// MARK: - Enum Analysis

/// Extracts comprehensive information about enum cases.
///
/// This function analyzes an enum declaration and extracts structured information
/// about each case, including the case name and the number of associated values.
/// This information is essential for generating appropriate switch statements.
///
/// ## Parsing Logic
/// - Iterates through all members of the enum
/// - Identifies case declarations among other member types
/// - Extracts case elements from multi-case declarations
/// - Counts associated values for each case
///
/// ## Associated Values Handling
/// The function correctly handles various associated value patterns:
/// - Cases with no associated values: `case login`
/// - Cases with single values: `case failure(Error)`
/// - Cases with multiple values: `case userAction(String, Int)`
/// - Cases with labeled values: `case config(name: String, value: Int)`
///
/// - Parameter enumDecl: The enum declaration to analyze
/// - Returns: Array of case information structures
private func extractEnumCaseInformation(from enumDecl: EnumDeclSyntax) -> [EnumCaseInformation] {
  enumDecl.memberBlock.members.compactMap { member -> [EnumCaseInformation]? in
    guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
      return nil
    }

    return caseDecl.elements.map { element in
      EnumCaseInformation(
        name: element.name.text,
        associatedValueCount: element.parameterClause?.parameters.count ?? 0
      )
    }
  }.flatMap { $0 }
}

/// Determines the access level modifier for generated members.
///
/// This function examines the enum declaration's access modifiers and returns
/// the appropriate access level string that should be applied to generated
/// members. This ensures generated code respects the original type's visibility.
///
/// ## Access Level Priority
/// The function searches modifiers in reverse order to find the most specific
/// access level. Swift allows multiple modifiers, and later ones take precedence.
///
/// ## Supported Access Levels
/// - `public`: Full public access
/// - `internal`: Module-internal access (default)
/// - `fileprivate`: File-private access
/// - `private`: Type-private access
/// - `open`: Open access (inheritance allowed)
///
/// ## Default Behavior
/// If no explicit access modifier is found, the function returns "internal"
/// as this is Swift's default access level for type members.
///
/// - Parameter enumDecl: The enum declaration to examine
/// - Returns: Access level string (e.g., "public", "internal")
func extractAccessLevel(from enumDecl: EnumDeclSyntax) -> String {
  extractAccessLevel(from: enumDecl.modifiers)
}

/// Extracts the access level from modifier list.
///
/// - Parameter modifiers: The modifier list to examine
/// - Returns: Access level string (e.g., "public", "internal")
func extractAccessLevel(from modifiers: DeclModifierListSyntax) -> String {
  let accessLevelKeywords = ["public", "internal", "fileprivate", "private", "open"]

  return
    modifiers
    .reversed()
    .first { modifier in
      accessLevelKeywords.contains(modifier.name.text)
    }?
    .name.text ?? "internal"
}

// MARK: - Member Generation

/// Generates the `actionName` computed property for an enum.
///
/// This function creates a computed property that maps enum cases to their
/// string representations. The generated property uses a switch statement
/// to handle all cases, including those with associated values.
///
/// ## Generated Property Structure
/// ```swift
/// var actionName: String {
///   switch self {
///   case .login: return "login"
///   case .logout(_): return "logout"
///   case .userAction(_, _): return "userAction"
///   }
/// }
/// ```
///
/// ## Associated Values Handling
/// For cases with associated values, the function generates wildcard patterns
/// that ignore the actual values while preserving the case structure.
///
/// ## Edge Cases
/// - Empty enums: Returns empty array (no property generated)
/// - Single case enums: Generates valid switch with one case
/// - Complex associated values: Uses appropriate wildcard patterns
///
/// - Parameter enumDecl: The enum declaration to process
/// - Returns: Array containing the generated property declaration
func generateActionNameMembers(for enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
  let caseInformation = extractEnumCaseInformation(from: enumDecl)

  // Don't generate property for empty enums
  guard !caseInformation.isEmpty else {
    return []
  }

  let accessLevel = extractAccessLevel(from: enumDecl)
  let switchCases = generateSwitchCases(from: caseInformation)

  let propertyDeclaration = DeclSyntax(
    """

    \(raw: accessLevel) var actionName: String {
      switch self {
      \(raw: switchCases)
      }
    }
    """
  )

  return [propertyDeclaration]
}

// Deprecated: generateStrategyTypeMembers is no longer used.
// Strategy identification is now handled through strategyId instead of strategyType.

/// Generates the `lockmanInfo` computed property for single execution actions.
///
/// This function creates a computed property that returns lock information
/// specific to single execution strategies. The generated property creates
/// a `LockmanSingleExecutionInfo` instance using the action name.
///
/// ## Generated Property Structure
/// ```swift
/// var lockmanInfo: LockmanSingleExecutionInfo {
///   .init(actionId: actionName)
/// }
/// ```
///
/// ## Integration
/// The generated property integrates with other generated members:
/// - Uses the `actionName` property for the action identifier
/// - Returns the appropriate info type for the strategy
/// - Maintains consistent access level with other members
///
/// - Parameter enumDecl: The enum declaration to process
/// - Returns: Array containing the generated property declaration
func generateLockmanInfoMembers(for enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
  let accessLevel = extractAccessLevel(from: enumDecl)

  let propertyDeclaration = DeclSyntax(
    """
    \(raw: accessLevel) var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName)
    }
    """
  )

  return [propertyDeclaration]
}

// MARK: - Switch Case Generation

/// Generates switch case clauses for the actionName property.
///
/// This function creates the individual case clauses that make up the switch
/// statement in the generated `actionName` property. Each case maps an enum
/// case to its string representation.
///
/// ## Case Pattern Generation
/// - Simple cases: `case .login: return "login"`
/// - Cases with associated values: `case .logout(_): return "logout"`
/// - Multiple associated values: `case .userAction(_, _): return "userAction"`
///
/// ## Wildcard Pattern Logic
/// For cases with associated values, the function generates wildcard patterns
/// that match the structure without binding the values. This ensures the
/// switch statement compiles correctly while ignoring the associated data.
///
/// - Parameter caseInformation: Array of case information to process
/// - Returns: String containing all switch case clauses
private func generateSwitchCases(from caseInformation: [EnumCaseInformation]) -> String {
  caseInformation.map { caseInfo in
    let pattern = generateCasePattern(for: caseInfo)
    return "case \(pattern): return \"\(caseInfo.name)\""
  }.joined(separator: "\n")
}

/// Generates the appropriate pattern for a single enum case.
///
/// This function creates the pattern string used in switch case clauses.
/// The pattern varies depending on whether the case has associated values.
///
/// ## Pattern Types
/// - No associated values: `.caseName`
/// - With associated values: `.caseName(_, _, ...)`
///
/// ## Wildcard Generation
/// For cases with associated values, the function generates the appropriate
/// number of wildcard patterns to match the case structure.
///
/// - Parameter caseInfo: Information about the enum case
/// - Returns: Pattern string for use in switch case
private func generateCasePattern(for caseInfo: EnumCaseInformation) -> String {
  if caseInfo.associatedValueCount == 0 {
    return ".\(caseInfo.name)"
  } else {
    let wildcards = Array(repeating: "_", count: caseInfo.associatedValueCount)
      .joined(separator: ", ")
    return ".\(caseInfo.name)(\(wildcards))"
  }
}

// MARK: - Supporting Types

/// Diagnostic message for macro validation errors.
///
/// This type provides structured error reporting for macro validation failures.
/// It implements the `DiagnosticMessage` protocol to integrate with SwiftSyntax's
/// diagnostic system.
///
/// ## Message Components
/// - **Primary Message**: Clear description of what went wrong
/// - **Diagnostic ID**: Unique identifier for the error type
/// - **Severity Level**: Always `.error` for validation failures
/// - **Domain Context**: Macro name for error categorization
///
/// ## Integration
/// These diagnostics are emitted through the macro expansion context and
/// appear in Xcode's issue navigator with proper source location information.
private struct MacroValidationError: DiagnosticMessage {
  /// The human-readable error message.
  let message: String

  /// The macro name for error categorization.
  let macroName: String

  /// Unique identifier for this diagnostic type.
  var diagnosticID: MessageID {
    MessageID(domain: macroName, id: "validation_error")
  }

  /// Severity level for this diagnostic.
  var severity: DiagnosticSeverity {
    .error
  }
}

/// Information about a single enum case.
///
/// This structure encapsulates the essential information needed to generate
/// code for an enum case, including the case name and associated value count.
///
/// ## Usage
/// This type is used throughout the member generation process to:
/// - Generate appropriate switch case patterns
/// - Create string representations of case names
/// - Handle associated values correctly
/// - Maintain type safety in code generation
///
/// ## Properties
/// - **name**: The identifier of the enum case
/// - **associatedValueCount**: Number of associated values (0 if none)
private struct EnumCaseInformation {
  /// The name of the enum case as it appears in source code.
  let name: String

  /// The number of associated values for this case.
  /// Zero indicates a simple case with no associated data.
  let associatedValueCount: Int
}

// MARK: - Legacy API Compatibility

/// Legacy function name for backwards compatibility.
///
/// This function maintains compatibility with existing code that uses the
/// original function name. It delegates to the new implementation while
/// preserving the same behavior.
///
/// - Deprecated: Use `extractEnumDeclaration` instead.
func extractEnumDecl(
  name: String,
  from declaration: some DeclGroupSyntax,
  attribute node: AttributeSyntax,
  in context: some MacroExpansionContext
) -> EnumDeclSyntax? {
  extractEnumDeclaration(
    macroName: name,
    from: declaration,
    attributeNode: node,
    context: context
  )
}

/// Legacy function name for backwards compatibility.
///
/// - Deprecated: Use `extractEnumCaseInformation` instead.
func extractCaseInfos(from enumDecl: EnumDeclSyntax) -> [CaseInfo] {
  extractEnumCaseInformation(from: enumDecl).map { caseInfo in
    CaseInfo(name: caseInfo.name, associatedValueCount: caseInfo.associatedValueCount)
  }
}

/// Legacy function name for backwards compatibility.
///
/// - Deprecated: Use `extractAccessLevel` instead.
func extractAccessModifier(from enumDecl: EnumDeclSyntax) -> String {
  extractAccessLevel(from: enumDecl)
}

/// Legacy type for backwards compatibility.
///
/// - Deprecated: Use `EnumCaseInformation` instead.
struct CaseInfo {
  let name: String
  let associatedValueCount: Int
}

/// Legacy error type for backwards compatibility.
///
/// - Deprecated: Use `MacroValidationError` instead.
struct ErrorDiagnostic: DiagnosticMessage {
  init(message: String, domain: String) {
    self.message = message
    self.diagnosticID = .init(domain: domain, id: "error")
  }

  let message: String
  let diagnosticID: MessageID
  let severity: DiagnosticSeverity = .error
}
