import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

// MARK: - Diagnostic Message Support

/// A simple diagnostic message implementation for macro expansion errors.
///
/// This structure provides a lightweight way to create diagnostic messages
/// during macro expansion, conforming to both `DiagnosticMessage` and `Error`
/// protocols for flexible error handling.
struct SimpleDiagnosticMessage: DiagnosticMessage, Error {
  /// The human-readable diagnostic message.
  let message: String

  /// The unique identifier for this diagnostic.
  let diagnosticID: MessageID

  /// The severity level of the diagnostic (error, warning, etc.).
  let severity: DiagnosticSeverity

  /// Creates a new diagnostic message.
  ///
  /// - Parameters:
  ///   - message: The human-readable diagnostic message.
  ///   - severity: The severity level (defaults to `.error`).
  init(_ message: String, severity: DiagnosticSeverity = .error) {
    self.message = message
    self.diagnosticID = MessageID(domain: "LockmanGroupCoordinationMacro", id: message)
    self.severity = severity
  }
}

/// A macro that adds conformance to `LockmanGroupCoordinatedAction` by generating
/// an extension for the target type.
///
/// Usage example:
/// ```swift
/// @LockmanGroupCoordination
/// enum NavigationAction {
///   case navigate(to: String)
///
///   var lockmanInfo: LockmanGroupCoordinatedInfo {
///     switch self {
///     case .navigate:
///       return LockmanGroupCoordinatedInfo(
///         actionId: actionName,
///         groupId: "navigation",
///         coordinationRole: .leader
///       )
///     }
///   }
/// }
/// ```
public struct LockmanGroupCoordinationMacro: ExtensionMacro {
  /// Generates an extension declaration that makes the given type conform to
  /// `LockmanGroupCoordinatedAction`.
  ///
  /// - Parameters:
  ///   - node: The attribute syntax node containing macro arguments.
  ///   - declaration: The declaration group syntax node to which the attribute is attached.
  ///   - type: The `TypeSyntax` node representing the type to extend.
  ///   - protocols: An array of `TypeSyntax` representing inherited protocols.
  ///   - context: The macro expansion context for diagnostics.
  /// - Returns: An array containing a single `ExtensionDeclSyntax` that declares
  ///            conformance to `LockmanGroupCoordinatedAction`.
  /// - Throws: An error if constructing the `ExtensionDeclSyntax` fails.
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo _: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let extensionDecl = try makeConformanceExtensionDecl(
      for: type,
      conformingTo: "LockmanGroupCoordinatedAction"
    )
    return [extensionDecl]
  }
}

extension LockmanGroupCoordinationMacro: MemberMacro {
  /// Generates member declarations for group coordination actions.
  ///
  /// - Parameters:
  ///   - node: The `AttributeSyntax` node that triggered member generation.
  ///   - declaration: The `DeclGroupSyntax` node representing the declaration.
  ///   - context: The macro expansion context used for diagnostics.
  /// - Returns: An array of `DeclSyntax` containing the generated members.
  /// - Throws: An error if member generation fails.
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let enumDecl = extractEnumDecl(
        name: "LockmanGroupCoordination",
        from: declaration,
        attribute: node,
        in: context
      )
    else {
      return []
    }

    // Generate only actionName property
    return generateActionNameMembers(for: enumDecl)
  }
}
