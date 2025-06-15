import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

/// A macro that adds conformance to `LockmanDynamicConditionAction` and generates
/// necessary members for dynamic condition-based locking.
///
/// This macro:
/// 1. Adds protocol conformance to `LockmanDynamicConditionAction`
/// 2. Generates `actionName` property
/// 3. Generates `lockmanInfo` property with default condition
public struct LockmanDynamicConditionMacro: ExtensionMacro {
  /// Generates an extension that conforms to `LockmanDynamicConditionAction`.
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo _: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    let extensionDecl = try makeConformanceExtensionDecl(
      for: type,
      conformingTo: "LockmanDynamicConditionAction"
    )
    return [extensionDecl]
  }
}

extension LockmanDynamicConditionMacro: MemberMacro {
  /// Generates member declarations for dynamic condition support.
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard
      let enumDecl = extractEnumDecl(
        name: "LockmanDynamicCondition",
        from: declaration,
        attribute: node,
        in: context
      ) else
    {
      return []
    }

    return generateDynamicConditionMembers(for: enumDecl)
  }
}

// MARK: - Member Generation

/// Generates all necessary members for LockmanDynamicConditionAction conformance.
private func generateDynamicConditionMembers(for enumDecl: EnumDeclSyntax) -> [DeclSyntax] {
  // Check if enum has cases
  let cases = enumDecl.memberBlock.members.compactMap { member in
    member.decl.as(EnumCaseDeclSyntax.self)
  }

  guard !cases.isEmpty else {
    // No cases, no members to generate
    return []
  }

  var members: [DeclSyntax] = []

  // Generate actionName property
  members.append(contentsOf: generateActionNameMembers(for: enumDecl))

  // Generate lockmanInfo property with default condition
  if let lockmanInfo = generateDefaultLockmanInfo(for: enumDecl) {
    members.append(lockmanInfo)
  }

  return members
}

/// Generates the default lockmanInfo property.
private func generateDefaultLockmanInfo(for enumDecl: EnumDeclSyntax) -> DeclSyntax? {
  let accessLevel = extractAccessLevel(from: enumDecl.modifiers)

  let propertyDecl = """

  \(accessLevel) var lockmanInfo: LockmanDynamicConditionInfo {
    LockmanDynamicConditionInfo(
      actionId: actionName
    )
  }
  """

  return DeclSyntax(stringLiteral: propertyDecl)
}
