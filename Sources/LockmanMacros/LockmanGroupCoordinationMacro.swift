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
/// an extension for the target type with the specified group coordination parameters.
///
/// Usage examples:
/// ```swift
/// // Single group
/// @LockmanGroupCoordination(groupId: "navigation", role: .leader)
/// enum NavigationAction {
///   case navigate(to: String)
/// }
///
/// // Multiple groups
/// @LockmanGroupCoordination(groupIds: ["navigation", "ui"], role: .member)
/// enum UIUpdateAction {
///   case updateProgress(Double)
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
      ) else
    {
      return []
    }

    // Parse macro arguments
    guard let arguments = parseGroupCoordinationArguments(from: node, in: context) else {
      return []
    }

    return generateGroupCoordinationMembers(for: enumDecl, arguments: arguments)
  }
}

// MARK: - Argument Parsing

/// Arguments parsed from the LockmanGroupCoordination macro.
private struct GroupCoordinationArguments {
  let groupIds: [String]
  let role: String

  /// Whether this uses multiple groups.
  var isMultipleGroups: Bool {
    groupIds.count > 1
  }
}

/// Parses arguments from the LockmanGroupCoordination macro attribute.
///
/// - Parameters:
///   - node: The attribute syntax node containing the arguments.
///   - context: The macro expansion context for diagnostics.
/// - Returns: The parsed arguments, or nil if parsing fails.
private func parseGroupCoordinationArguments(
  from node: AttributeSyntax,
  in context: some MacroExpansionContext
) -> GroupCoordinationArguments? {
  guard let arguments = node.arguments,
        case let .argumentList(argumentList) = arguments else
  {
    context.diagnose(
      Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          "Missing required arguments for LockmanGroupCoordination macro. Provide either 'groupId' or 'groupIds' parameter along with 'role'"
        )
      )
    )
    return nil
  }

  var groupIds: [String] = []
  var role: String?

  for argument in argumentList {
    guard let label = argument.label?.text else {
      continue
    }

    switch label {
    case "groupId":
      // Single group: groupId: "navigation"
      if let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self),
         let segment = stringLiteral.segments.first,
         case let .stringSegment(stringSegment) = segment
      {
        groupIds = [stringSegment.content.text]
      }

    case "groupIds":
      // Multiple groups: groupIds: ["navigation", "ui"]
      if let arrayExpr = argument.expression.as(ArrayExprSyntax.self) {
        for element in arrayExpr.elements {
          if let stringLiteral = element.expression.as(StringLiteralExprSyntax.self),
             let segment = stringLiteral.segments.first,
             case let .stringSegment(stringSegment) = segment
          {
            groupIds.append(stringSegment.content.text)
          }
        }
      }

    case "role":
      // role: .leader or role: .member
      if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self) {
        role = memberAccess.declName.baseName.text
      }

    default:
      break
    }
  }

  // Validation
  if groupIds.isEmpty {
    context.diagnose(
      Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          "At least one group ID must be provided for LockmanGroupCoordination macro"
        )
      )
    )
    return nil
  }

  if groupIds.count > 5 {
    context.diagnose(
      Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          "Maximum 5 groups allowed for LockmanGroupCoordination macro, got \(groupIds.count)"
        )
      )
    )
    return nil
  }

  guard let role = role else {
    context.diagnose(
      Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          "Missing role argument for LockmanGroupCoordination macro"
        )
      )
    )
    return nil
  }

  guard role == "leader" || role == "member" else {
    context.diagnose(
      Diagnostic(
        node: node,
        message: SimpleDiagnosticMessage(
          "Role must be .leader or .member for LockmanGroupCoordination macro, got .\(role)"
        )
      )
    )
    return nil
  }

  return GroupCoordinationArguments(groupIds: groupIds, role: role)
}

// MARK: - Member Generation

/// Generates member declarations for group coordination actions.
///
/// - Parameters:
///   - enumDecl: The `EnumDeclSyntax` representing the enum to process.
///   - arguments: The parsed macro arguments.
/// - Returns: An array of `DeclSyntax` nodes containing the generated member declarations.
private func generateGroupCoordinationMembers(
  for enumDecl: EnumDeclSyntax,
  arguments: GroupCoordinationArguments
) -> [DeclSyntax] {
  var members: [DeclSyntax] = []

  // Generate standard actionName property
  members.append(contentsOf: generateActionNameMembers(for: enumDecl))

  // Generate coordinationRole property
  members.append(generateCoordinationRoleProperty(role: arguments.role))

  // Generate group properties (groupId or groupIds)
  if arguments.isMultipleGroups {
    members.append(generateGroupIdsProperty(groupIds: arguments.groupIds))
  } else {
    members.append(generateGroupIdProperty(groupId: arguments.groupIds[0]))
  }

  return members
}

/// Generates the coordinationRole property.
///
/// - Parameter role: The role string ("leader" or "member").
/// - Returns: A `DeclSyntax` for the coordinationRole property.
private func generateCoordinationRoleProperty(role: String) -> DeclSyntax {
  """
  var coordinationRole: GroupCoordinationRole {
    .\(raw: role)
  }
  """
}

/// Generates the groupId property for single group actions.
///
/// - Parameter groupId: The group identifier.
/// - Returns: A `DeclSyntax` for the groupId property.
private func generateGroupIdProperty(groupId: String) -> DeclSyntax {
  """
  var groupId: String {
    "\(raw: groupId)"
  }
  """
}

/// Generates the groupIds property for multiple group actions.
///
/// - Parameter groupIds: The list of group identifiers.
/// - Returns: A `DeclSyntax` for the groupIds property.
private func generateGroupIdsProperty(groupIds: [String]) -> DeclSyntax {
  let groupIdStrings = groupIds.map { "\"\($0)\"" }.joined(separator: ", ")

  return """
  var groupIds: Set<String> {
    [\(raw: groupIdStrings)]
  }
  """
}
