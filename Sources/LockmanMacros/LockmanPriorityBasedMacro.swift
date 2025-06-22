import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

/// A macro that adds conformance to `LockmanPriorityBasedAction` by generating
/// an empty extension for the target type.
///
/// When this macro is attached to a type declaration, it produces:
/// ```swift
/// extension <TypeName>: LockmanPriorityBasedAction {
/// }
/// ```
///
/// - Note: This macro only handles protocol conformance; member generation is
///         provided by the corresponding `MemberMacro` implementation.
public struct LockmanPriorityBasedMacro: ExtensionMacro {
  /// Generates an extension declaration that makes the given type conform to
  /// `LockmanPriorityBasedAction`.
  ///
  /// - Parameters:
  ///   - _: The attribute syntax node (unused).
  ///   - _: The declaration group syntax node to which the attribute is attached (unused).
  ///   - type: The `TypeSyntax` node representing the type to extend.
  ///   - _: An array of `TypeSyntax` representing inherited protocols (unused).
  ///   - _: The macro expansion context (unused).
  /// - Returns: An array containing a single `ExtensionDeclSyntax` that declares
  ///            conformance to `LockmanPriorityBasedAction`.
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
      conformingTo: "LockmanPriorityBasedAction"
    )
    return [extensionDecl]
  }
}

extension LockmanPriorityBasedMacro: MemberMacro {
  /// Generates member declarations (e.g., `actionName` property) for the enum to which
  /// this macro is attached.
  ///
  /// - Parameters:
  ///   - node: The `AttributeSyntax` node that triggered member generation.
  ///   - declaration: The `DeclGroupSyntax` node representing the declaration (expected to be an enum).
  ///   - context: The macro expansion context used for diagnostics.
  /// - Returns: An array of `DeclSyntax` containing the generated members. If the
  ///            declaration is not an enum or has no cases, returns an empty array.
  /// - Throws: An error if member generation fails.
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let enumDecl = extractEnumDecl(
        name: "LockmanPriorityBased",
        from: declaration,
        attribute: node,
        in: context
      )
    else {
      return []
    }

    return generatePriorityBasedMembers(for: enumDecl)
  }
}

// MARK: - Priority Based Specific Member Generation

/// Generates member declarations specific to LockmanPriorityBased actions.
/// Currently generates `actionName` property, but can be extended
/// to include additional priority-based specific members.
///
/// - Parameter enumDecl: The `EnumDeclSyntax` representing the enum to process.
/// - Returns: An array of `DeclSyntax` nodes containing the generated member declarations.
private func generatePriorityBasedMembers(for enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
  var members: [DeclSyntax] = []

  // Generate standard actionName property
  members.append(contentsOf: generateActionNameMembers(for: enumDecl))

  // TODO: Add priority-based specific members here
  // For example:
  // members.append(contentsOf: generatePriorityMembers(for: enumDecl))

  return members
}
