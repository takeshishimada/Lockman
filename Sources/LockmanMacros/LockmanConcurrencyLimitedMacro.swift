import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

/// A macro that adds conformance to `LockmanConcurrencyLimitedAction` by generating
/// an empty extension for the target type.
///
/// When this macro is attached to a type declaration, it produces:
/// ```swift
/// extension <TypeName>: LockmanConcurrencyLimitedAction {
/// }
/// ```
///
/// - Note: Member generation (such as `actionName` property) is provided by the
///         corresponding `MemberMacro` implementation.
public struct LockmanConcurrencyLimitedMacro: ExtensionMacro {
  /// Generates an extension declaration that makes the given type conform to
  /// `LockmanConcurrencyLimitedAction`.
  ///
  /// - Parameters:
  ///   - _: The attribute syntax node (unused).
  ///   - _: The declaration group syntax node to which the attribute is attached (unused).
  ///   - type: The `TypeSyntax` node representing the type to extend.
  ///   - _: An array of `TypeSyntax` representing inherited protocols (unused).
  ///   - _: The macro expansion context (unused).
  /// - Returns: An array containing a single `ExtensionDeclSyntax` that declares
  ///            conformance to `LockmanConcurrencyLimitedAction`.
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
      conformingTo: "LockmanConcurrencyLimitedAction"
    )
    return [extensionDecl]
  }
}

extension LockmanConcurrencyLimitedMacro: MemberMacro {
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
        name: "LockmanConcurrencyLimited",
        from: declaration,
        attribute: node,
        in: context
      )
    else {
      return []
    }

    return generateConcurrencyLimitedMembers(for: enumDecl)
  }
}

// MARK: - Concurrency Limited Specific Member Generation

/// Generates member declarations specific to LockmanConcurrencyLimited actions.
/// Currently generates only the `actionName` property. Users must implement
/// `createLockmanInfo()` themselves to specify the concurrency group or limit.
///
/// - Parameter enumDecl: The `EnumDeclSyntax` representing the enum to process.
/// - Returns: An array of `DeclSyntax` nodes containing the generated member declarations.
private func generateConcurrencyLimitedMembers(for enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
  var members: [DeclSyntax] = []

  // Generate standard actionName property
  members.append(contentsOf: generateActionNameMembers(for: enumDecl))

  // Do NOT generate createLockmanInfo method - users must implement it themselves
  // to specify the concurrency group or limit using the overloaded initializers

  return members
}
