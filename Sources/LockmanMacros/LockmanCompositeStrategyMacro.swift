import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

#if !canImport(SwiftSyntax600)
  import SwiftSyntaxMacroExpansion
#endif

// MARK: - Core Types

/// Represents an enum case with its structural information.
///
/// This type encapsulates the essential information needed to generate
/// appropriate code for enum cases in composite strategy macros.
///
/// ## Usage
/// Used throughout the macro expansion process to:
/// - Generate switch case patterns for `actionName` properties
/// - Handle associated values correctly in generated code
/// - Maintain type safety during code generation
///
/// ## Properties
/// - **name**: The identifier of the enum case as it appears in source
/// - **associatedValueCount**: Number of associated values (0 for simple cases)
struct EnumCaseDefinition {
  /// The name of the enum case as written in source code.
  let name: String

  /// The number of associated values for this case.
  /// Zero indicates a simple case with no associated data.
  let associatedValueCount: Int
}

// MARK: - Enum Analysis Utilities

/// Extracts comprehensive case information from an enum declaration.
///
/// This function analyzes the member block of an enum and extracts all case
/// declarations, handling both simple cases and cases with associated values.
/// It's designed to work with Swift's enum syntax including multi-case
/// declarations and complex associated value patterns.
///
/// ## Parsing Strategy
/// 1. Iterates through all members in the enum's member block
/// 2. Identifies case declaration members among other types
/// 3. Extracts individual case elements from case declarations
/// 4. Analyzes parameter clauses to count associated values
///
/// ## Supported Case Patterns
/// - Simple cases: `case login, logout`
/// - Cases with associated values: `case failure(Error)`
/// - Multiple associated values: `case userAction(String, Int)`
/// - Labeled associated values: `case config(name: String, value: Int)`
///
/// ## Error Resilience
/// The function is designed to be resilient to various enum structures:
/// - Handles enums with no cases gracefully
/// - Ignores non-case members (computed properties, methods, etc.)
/// - Processes malformed case declarations without crashing
///
/// - Parameter enumDecl: The enum declaration to analyze
/// - Returns: Array of case definitions extracted from the enum
/// - Throws: `LockmanMacroError.invalidDeclaration` if enum structure is malformed
private func extractEnumCaseDefinitions(from enumDecl: EnumDeclSyntax) throws -> [EnumCaseDefinition] {
  var caseDefinitions: [EnumCaseDefinition] = []

  for member in enumDecl.memberBlock.members {
    guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
      // Skip non-case members (computed properties, methods, etc.)
      continue
    }

    for element in caseDecl.elements {
      let caseName = element.name.text
      let associatedValueCount = element.parameterClause?.parameters.count ?? 0

      // Validate case name is a valid Swift identifier
      guard !caseName.isEmpty, caseName.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        throw LockmanMacroError.invalidCaseName("Invalid case name '\(caseName)'. Case names must be valid Swift identifiers.")
      }

      caseDefinitions.append(EnumCaseDefinition(
        name: caseName,
        associatedValueCount: associatedValueCount
      ))
    }
  }

  return caseDefinitions
}

/// Determines the appropriate access level for generated members.
///
/// This function examines the enum declaration's modifiers to determine what
/// access level should be applied to generated members. It ensures that
/// generated code respects the visibility constraints of the original type.
///
/// ## Access Level Resolution Strategy
/// The function searches through modifiers to find explicit access level
/// declarations. It handles the precedence rules where later modifiers
/// override earlier ones, following Swift's access control semantics.
///
/// ## Supported Access Levels
/// - `public`: Accessible from any module
/// - `internal`: Accessible within the same module (Swift default)
/// - `fileprivate`: Accessible within the same source file
/// - `private`: Accessible within the same type or extension
/// - `open`: Public with inheritance permissions (treated as public here)
///
/// ## Default Behavior
/// When no explicit access modifier is found, returns "internal" as this
/// matches Swift's default access level for enum members.
///
/// - Parameter enumDecl: The enum declaration to examine
/// - Returns: Access level string suitable for code generation
private func determineAccessLevel(from enumDecl: EnumDeclSyntax) -> String {
  let recognizedAccessLevels = ["public", "internal", "fileprivate", "private", "open"]

  // Search in reverse order as later modifiers take precedence
  for modifier in enumDecl.modifiers.reversed() {
    let modifierText = modifier.name.text
    if recognizedAccessLevels.contains(modifierText) {
      // Treat 'open' as 'public' for member generation purposes
      return modifierText == "open" ? "public" : modifierText
    }
  }

  return "internal"
}

/// Generates the switch statement body for the actionName property.
///
/// This function creates the individual case clauses that comprise the switch
/// statement in generated `actionName` properties. Each case maps an enum case
/// to its string representation, handling associated values appropriately.
///
/// ## Case Pattern Generation Strategy
/// - **Simple cases**: Generate direct patterns like `.login`
/// - **Associated values**: Generate wildcard patterns like `.failure(_)`
/// - **Multiple values**: Generate multiple wildcards like `.config(_, _)`
///
/// ## Wildcard Pattern Logic
/// For cases with associated values, the function generates wildcard patterns
/// that match the case structure without binding the values. This ensures:
/// - The switch statement compiles correctly
/// - Associated values are ignored (as they're not needed for naming)
/// - The pattern matches the exact case structure
///
/// ## Output Format
/// The generated switch body follows this pattern:
/// ```swift
/// case .login: return "login"
/// case .failure(_): return "failure"
/// case .config(_, _): return "config"
/// ```
///
/// - Parameter caseDefinitions: Array of case definitions to process
/// - Returns: Complete switch statement body as a string
/// - Throws: `LockmanMacroError.invalidCaseName` if any case name is invalid
private func generateActionNameSwitchBody(from caseDefinitions: [EnumCaseDefinition]) throws -> String {
  guard !caseDefinitions.isEmpty else {
    throw LockmanMacroError.invalidDeclaration("Enum must have at least one case to generate actionName property.")
  }

  let switchCases = caseDefinitions.map { caseDefinition in
    let pattern = generateCasePattern(for: caseDefinition)
    return "case \(pattern): return \"\(caseDefinition.name)\""
  }

  return switchCases.joined(separator: "\n    ")
}

/// Generates the appropriate pattern for a single enum case.
///
/// This function creates the pattern string used in switch case clauses,
/// adapting the pattern based on whether the case has associated values.
///
/// ## Pattern Generation Rules
/// - **No associated values**: Simple pattern like `.caseName`
/// - **With associated values**: Wildcard pattern like `.caseName(_, _, ...)`
///
/// ## Wildcard Count Logic
/// For cases with associated values, generates exactly the right number
/// of wildcard patterns to match the case structure. This ensures the
/// switch pattern is syntactically correct and matches all variants.
///
/// - Parameter caseDefinition: The case definition to generate a pattern for
/// - Returns: Pattern string suitable for use in switch statements
private func generateCasePattern(for caseDefinition: EnumCaseDefinition) -> String {
  if caseDefinition.associatedValueCount == 0 {
    return ".\(caseDefinition.name)"
  } else {
    let wildcards = Array(repeating: "_", count: caseDefinition.associatedValueCount)
      .joined(separator: ", ")
    return ".\(caseDefinition.name)(\(wildcards))"
  }
}

/// Generates a complete actionName property declaration.
///
/// This function creates the full computed property that maps enum cases
/// to their string representations. The property uses a switch statement
/// to handle all cases systematically.
///
/// ## Generated Property Structure
/// ```swift
/// public var actionName: String {
///   switch self {
///   case .login: return "login"
///   case .logout: return "logout"
///   case .failure(_): return "failure"
///   }
/// }
/// ```
///
/// ## Access Level Integration
/// The generated property respects the access level of the containing enum,
/// ensuring proper visibility constraints are maintained.
///
/// - Parameters:
///   - caseDefinitions: Array of case definitions to include
///   - accessLevel: Access level string for the property
/// - Returns: Complete property declaration
/// - Throws: Errors from switch body generation
private func generateActionNameProperty(
  caseDefinitions: [EnumCaseDefinition],
  accessLevel: String
) throws -> DeclSyntax {
  let switchBody = try generateActionNameSwitchBody(from: caseDefinitions)

  return """
  \(raw: accessLevel) var actionName: String {
    switch self {
    \(raw: switchBody)
    }
  }
  """
}

// MARK: - Strategy Type Parsing

/// Extracts strategy type names from macro attribute arguments.
///
/// This function parses the arguments passed to a composite strategy macro
/// and extracts the names of the strategy types. It handles the standard
/// Swift syntax for type references in macro arguments.
///
/// ## Supported Argument Formats
/// The function supports strategy arguments in these formats:
/// - Type references with `.self`: `StrategyName.self`
/// - Direct type references: `StrategyName` (fallback)
///
/// ## Parsing Strategy
/// 1. Validates that arguments are provided in the expected format
/// 2. Iterates through each argument expression
/// 3. Extracts strategy type names from member access expressions
/// 4. Falls back to direct identifier extraction if needed
/// 5. Validates the total count matches expectations
///
/// ## Error Conditions
/// - Missing arguments: Throws when no arguments provided
/// - Wrong argument count: Throws when count doesn't match expected
/// - Invalid format: Throws when arguments aren't in recognized format
/// - Malformed expressions: Throws when argument expressions are corrupted
///
/// - Parameters:
///   - attributeNode: The macro attribute node containing arguments
///   - expectedCount: The expected number of strategy arguments
/// - Returns: Array of strategy type names in order
/// - Throws: `LockmanMacroError.invalidArguments` for various argument issues
private func extractStrategyTypeNames(
  from attributeNode: AttributeSyntax,
  expectedCount: Int
) throws -> [String] {
  guard case let .argumentList(arguments) = attributeNode.arguments else {
    throw LockmanMacroError.invalidArguments(
      "@LockmanCompositeStrategy requires \(expectedCount) strategy arguments."
    )
  }

  var strategyTypeNames: [String] = []

  for argument in arguments {
    let strategyName: String

    // Handle Strategy.self format (preferred)
    if let memberAccess = argument.expression.as(MemberAccessExprSyntax.self),
       let base = memberAccess.base,
       memberAccess.declName.baseName.text == "self"
    {
      strategyName = base.description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    // Handle direct type references (fallback)
    else if let identifier = argument.expression.as(DeclReferenceExprSyntax.self) {
      strategyName = identifier.baseName.text
    } else {
      throw LockmanMacroError.invalidArguments(
        "Strategy argument must be in the format 'StrategyName.self'. " +
          "Found: \(argument.expression.description.trimmingCharacters(in: .whitespacesAndNewlines))"
      )
    }

    // Validate strategy name is not empty
    guard !strategyName.isEmpty else {
      throw LockmanMacroError.invalidArguments("Strategy name cannot be empty.")
    }

    strategyTypeNames.append(strategyName)
  }

  guard strategyTypeNames.count == expectedCount else {
    throw LockmanMacroError.invalidArguments(
      "@LockmanCompositeStrategy requires exactly \(expectedCount) strategy arguments, " +
        "but \(strategyTypeNames.count) were provided."
    )
  }

  return strategyTypeNames
}

// MARK: - Property Generation

/// Generates the strategyId property for 2-strategy compositions.
///
/// This function creates a computed property that returns the strategy identifier
/// for 2-strategy combinations. The property uses the makeStrategyId method
/// from the composite strategy to generate the correct identifier.
///
/// ## Generated Property Structure
/// ```swift
/// public var strategyId: LockmanStrategyId {
///   LockmanCompositeStrategy2.makeStrategyId(
///     strategy1: Strategy1.shared,
///     strategy2: Strategy2.shared
///   )
/// }
/// ```
///
/// - Parameters:
///   - strategy1: Name of the first strategy type
///   - strategy2: Name of the second strategy type
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateStrategyIdProperty2(
  strategy1: String,
  strategy2: String,
  accessLevel: String
) -> DeclSyntax {
  """
  \(raw: accessLevel) var strategyId: LockmanStrategyId {
    LockmanCompositeStrategy2.makeStrategyId(
      strategy1: \(raw: strategy1).shared,
      strategy2: \(raw: strategy2).shared
    )
  }
  """
}

/// Generates the strategyId property for multi-strategy compositions (3-5 strategies).
///
/// This function creates a computed property that returns the strategy identifier
/// for 3-5 strategy combinations. The property uses the makeStrategyId method
/// from the composite strategy to generate the correct identifier.
///
/// ## Generated Property Structure
/// ```swift
/// public var strategyId: LockmanStrategyId {
///   LockmanCompositeStrategy3.makeStrategyId(
///     strategy1: Strategy1.shared,
///     strategy2: Strategy2.shared,
///     strategy3: Strategy3.shared
///   )
/// }
/// ```
///
/// - Parameters:
///   - strategyNames: Array of strategy type names
///   - strategyCount: Number of strategies (used for naming)
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateStrategyIdPropertyMulti(
  strategyNames: [String],
  strategyCount: Int,
  accessLevel: String
) -> DeclSyntax {
  let strategyParams = strategyNames.enumerated().map { index, name in
    "    strategy\(index + 1): \(name).shared"
  }.joined(separator: ",\n")

  return """
  \(raw: accessLevel) var strategyId: LockmanStrategyId {
    LockmanCompositeStrategy\(raw: strategyCount).makeStrategyId(
  \(raw: strategyParams)
    )
  }
  """
}

/// Generates the lockmanInfo property for 2-strategy compositions.
///
/// This function creates a computed property that returns the composite
/// lock information for 2-strategy combinations. The property integrates
/// with the protocol requirements to provide the necessary lock data.
///
/// ## Generated Property Structure
/// ```swift
/// public var lockmanInfo: LockmanCompositeInfo2<S1.I, S2.I> {
///   return LockmanCompositeInfo2(
///     actionId: actionName,
///     lockmanInfoForStrategy1: lockmanInfoForStrategy1,
///     lockmanInfoForStrategy2: lockmanInfoForStrategy2
///   )
/// }
/// ```
///
/// ## Integration Points
/// The generated property integrates with:
/// - `actionName` property for the action identifier
/// - `lockmanInfoForStrategy1` and `lockmanInfoForStrategy2` protocol requirements
/// - The composite info type system for type safety
///
/// - Parameters:
///   - strategy1: Name of the first strategy type
///   - strategy2: Name of the second strategy type
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateLockmanInfoProperty2(
  strategy1: String,
  strategy2: String,
  accessLevel: String
) -> DeclSyntax {
  """
  \(raw: accessLevel) var lockmanInfo: LockmanCompositeInfo2<\(raw: strategy1).I, \(raw: strategy2).I> {
    return LockmanCompositeInfo2(
      actionId: actionName,
      lockmanInfoForStrategy1: lockmanInfoForStrategy1,
      lockmanInfoForStrategy2: lockmanInfoForStrategy2
    )
  }
  """
}

/// Generates the lockmanInfo property for 3-strategy compositions.
///
/// This function creates a computed property that returns the composite
/// lock information for 3-strategy combinations.
///
/// - Parameters:
///   - strategyNames: Array of strategy type names
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateLockmanInfoProperty3(
  strategyNames: [String],
  accessLevel: String
) -> DeclSyntax {
  let strategy1 = strategyNames[0]
  let strategy2 = strategyNames[1]
  let strategy3 = strategyNames[2]

  return """
  \(raw: accessLevel) var lockmanInfo: LockmanCompositeInfo3<\(raw: strategy1).I, \(raw: strategy2).I, \(raw: strategy3).I> {
    return LockmanCompositeInfo3(
      actionId: actionName,
      lockmanInfoForStrategy1: lockmanInfoForStrategy1,
      lockmanInfoForStrategy2: lockmanInfoForStrategy2,
      lockmanInfoForStrategy3: lockmanInfoForStrategy3
    )
  }
  """
}

/// Generates the lockmanInfo property for 4-strategy compositions.
///
/// - Parameters:
///   - strategyNames: Array of strategy type names
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateLockmanInfoProperty4(
  strategyNames: [String],
  accessLevel: String
) -> DeclSyntax {
  let strategy1 = strategyNames[0]
  let strategy2 = strategyNames[1]
  let strategy3 = strategyNames[2]
  let strategy4 = strategyNames[3]

  return """
  \(raw: accessLevel) var lockmanInfo: LockmanCompositeInfo4<\(raw: strategy1).I, \(raw: strategy2).I, \(raw: strategy3).I, \(raw: strategy4).I> {
    return LockmanCompositeInfo4(
      actionId: actionName,
      lockmanInfoForStrategy1: lockmanInfoForStrategy1,
      lockmanInfoForStrategy2: lockmanInfoForStrategy2,
      lockmanInfoForStrategy3: lockmanInfoForStrategy3,
      lockmanInfoForStrategy4: lockmanInfoForStrategy4
    )
  }
  """
}

/// Generates the lockmanInfo property for 5-strategy compositions.
///
/// - Parameters:
///   - strategyNames: Array of strategy type names
///   - accessLevel: Access level for the property
/// - Returns: Complete property declaration
private func generateLockmanInfoProperty5(
  strategyNames: [String],
  accessLevel: String
) -> DeclSyntax {
  let strategy1 = strategyNames[0]
  let strategy2 = strategyNames[1]
  let strategy3 = strategyNames[2]
  let strategy4 = strategyNames[3]
  let strategy5 = strategyNames[4]

  return """
  \(raw: accessLevel) var lockmanInfo: LockmanCompositeInfo5<\(raw: strategy1).I, \(raw: strategy2).I, \(raw: strategy3).I, \(raw: strategy4).I, \(raw: strategy5).I> {
    return LockmanCompositeInfo5(
      actionId: actionName,
      lockmanInfoForStrategy1: lockmanInfoForStrategy1,
      lockmanInfoForStrategy2: lockmanInfoForStrategy2,
      lockmanInfoForStrategy3: lockmanInfoForStrategy3,
      lockmanInfoForStrategy4: lockmanInfoForStrategy4,
      lockmanInfoForStrategy5: lockmanInfoForStrategy5
    )
  }
  """
}

// MARK: - Macro Implementations

/// Macro implementation for `@LockmanCompositeStrategy` with 2 strategy arguments.
///
/// This macro generates protocol conformance to `LockmanCompositeAction2` and provides
/// complete implementations for all required protocol members. It handles the coordination
/// between two different locking strategies in a type-safe manner.
///
/// ## Generated Members
/// - `actionName`: Maps enum cases to string identifiers
/// - `strategyType`: Returns the composite strategy type
/// - `lockmanInfo`: Provides composite lock information
///
/// ## Protocol Conformance
/// The macro adds conformance to `LockmanCompositeAction2` which requires:
/// - Implementation of all base protocol requirements
/// - Type aliases for the two strategy types
/// - Integration with the composite strategy system
///
/// ## Usage Example
/// ```swift
/// @LockmanCompositeStrategy(Strategy1.self, Strategy2.self)
/// enum UserAction {
///   case login
///   case logout
/// }
/// ```
///
/// ## Error Handling
/// The macro performs comprehensive validation:
/// - Ensures attachment to enum declarations only
/// - Validates strategy argument format and count
/// - Checks for proper enum case structure
/// - Provides detailed error messages for common issues
public struct LockmanCompositeStrategy2Macro: ExtensionMacro, MemberMacro {
  /// Generates the extension declaration for protocol conformance.
  ///
  /// This method creates an empty extension that declares conformance to
  /// `LockmanCompositeAction2`. The actual protocol members are added
  /// by the member macro implementation.
  ///
  /// ## Extension Structure
  /// ```swift
  /// extension EnumName: LockmanCompositeAction2 {
  ///   // Members added by MemberMacro
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - node: The macro attribute syntax node
  ///   - declaration: The declaration being extended
  ///   - type: The type being extended
  ///   - protocols: Inherited protocols (unused)
  ///   - context: Macro expansion context
  /// - Returns: Array containing the conformance extension
  /// - Throws: `LockmanMacroError.invalidDeclaration` if not applied to an enum
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.is(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let extensionDecl = try ExtensionDeclSyntax("extension \(type): LockmanCompositeAction2") {}
    return [extensionDecl]
  }

  /// Generates the required protocol members for the enum.
  ///
  /// This method creates all the members required by the `LockmanCompositeAction2`
  /// protocol, including computed properties for action names, strategy types,
  /// and lock information.
  ///
  /// ## Generated Members
  /// 1. `actionName`: Switch-based property mapping cases to strings
  /// 2. `strategyType`: Property returning the composite strategy type
  /// 3. `lockmanInfo`: Property providing composite lock information
  ///
  /// ## Validation Process
  /// The method performs several validation steps:
  /// - Confirms the declaration is an enum
  /// - Extracts and validates strategy type arguments
  /// - Analyzes enum case structure
  /// - Determines appropriate access levels
  ///
  /// - Parameters:
  ///   - node: The macro attribute syntax node
  ///   - declaration: The declaration to add members to
  ///   - context: Macro expansion context
  /// - Returns: Array of generated member declarations
  /// - Throws: Various `LockmanMacroError` types for validation failures
  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let strategyNames = try extractStrategyTypeNames(from: node, expectedCount: 2)
    let strategy1 = strategyNames[0]
    let strategy2 = strategyNames[1]

    let caseDefinitions = try extractEnumCaseDefinitions(from: enumDecl)
    let accessLevel = determineAccessLevel(from: enumDecl)

    var members: [DeclSyntax] = []

    // Generate actionName property if cases exist
    if !caseDefinitions.isEmpty {
      let actionNameProperty = try generateActionNameProperty(
        caseDefinitions: caseDefinitions,
        accessLevel: accessLevel
      )
      members.append(actionNameProperty)
    }

    // Generate strategyId property
    let strategyIdProperty = generateStrategyIdProperty2(
      strategy1: strategy1,
      strategy2: strategy2,
      accessLevel: accessLevel
    )
    members.append(strategyIdProperty)

    // Do not generate lockmanInfo property - user must implement it
    // This allows users to specify strategy-specific details like mode

    // Generate type aliases for protocol conformance
    let typeAliases: [DeclSyntax] = [
      "\(raw: accessLevel) typealias I1 = \(raw: strategy1).I",
      "\(raw: accessLevel) typealias S1 = \(raw: strategy1)",
      "\(raw: accessLevel) typealias I2 = \(raw: strategy2).I",
      "\(raw: accessLevel) typealias S2 = \(raw: strategy2)",
    ]
    members.append(contentsOf: typeAliases)

    return members
  }
}

/// Macro implementation for `@LockmanCompositeStrategy` with 3 strategy arguments.
///
/// This macro extends the composite strategy concept to coordinate three different
/// locking strategies, providing all the necessary infrastructure for triple-strategy
/// coordination in the Lockman framework.
///
/// ## Usage Example
/// ```swift
/// @LockmanCompositeStrategy(Strategy1.self, Strategy2.self, Strategy3.self)
/// enum ComplexAction {
///   case initialize
///   case process
///   case finalize
/// }
/// ```
public struct LockmanCompositeStrategy3Macro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.is(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let extensionDecl = try ExtensionDeclSyntax("extension \(type): LockmanCompositeAction3") {}
    return [extensionDecl]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let strategyNames = try extractStrategyTypeNames(from: node, expectedCount: 3)
    let caseDefinitions = try extractEnumCaseDefinitions(from: enumDecl)
    let accessLevel = determineAccessLevel(from: enumDecl)

    var members: [DeclSyntax] = []

    if !caseDefinitions.isEmpty {
      let actionNameProperty = try generateActionNameProperty(
        caseDefinitions: caseDefinitions,
        accessLevel: accessLevel
      )
      members.append(actionNameProperty)
    }

    let strategyIdProperty = generateStrategyIdPropertyMulti(
      strategyNames: strategyNames,
      strategyCount: 3,
      accessLevel: accessLevel
    )
    members.append(strategyIdProperty)

    // Do not generate lockmanInfo property - user must implement it
    // This allows users to specify strategy-specific details

    // Generate type aliases for protocol conformance
    let typeAliases: [DeclSyntax] = [
      "\(raw: accessLevel) typealias I1 = \(raw: strategyNames[0]).I",
      "\(raw: accessLevel) typealias S1 = \(raw: strategyNames[0])",
      "\(raw: accessLevel) typealias I2 = \(raw: strategyNames[1]).I",
      "\(raw: accessLevel) typealias S2 = \(raw: strategyNames[1])",
      "\(raw: accessLevel) typealias I3 = \(raw: strategyNames[2]).I",
      "\(raw: accessLevel) typealias S3 = \(raw: strategyNames[2])",
    ]
    members.append(contentsOf: typeAliases)

    return members
  }
}

/// Macro implementation for `@LockmanCompositeStrategy` with 4 strategy arguments.
///
/// This macro handles coordination between four different locking strategies,
/// representing the upper range of practical multi-strategy coordination.
public struct LockmanCompositeStrategy4Macro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.is(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let extensionDecl = try ExtensionDeclSyntax("extension \(type): LockmanCompositeAction4") {}
    return [extensionDecl]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let strategyNames = try extractStrategyTypeNames(from: node, expectedCount: 4)
    let caseDefinitions = try extractEnumCaseDefinitions(from: enumDecl)
    let accessLevel = determineAccessLevel(from: enumDecl)

    var members: [DeclSyntax] = []

    if !caseDefinitions.isEmpty {
      let actionNameProperty = try generateActionNameProperty(
        caseDefinitions: caseDefinitions,
        accessLevel: accessLevel
      )
      members.append(actionNameProperty)
    }

    let strategyIdProperty = generateStrategyIdPropertyMulti(
      strategyNames: strategyNames,
      strategyCount: 4,
      accessLevel: accessLevel
    )
    members.append(strategyIdProperty)

    // Do not generate lockmanInfo property - user must implement it
    // This allows users to specify strategy-specific details

    // Generate type aliases for protocol conformance
    let typeAliases: [DeclSyntax] = [
      "\(raw: accessLevel) typealias I1 = \(raw: strategyNames[0]).I",
      "\(raw: accessLevel) typealias S1 = \(raw: strategyNames[0])",
      "\(raw: accessLevel) typealias I2 = \(raw: strategyNames[1]).I",
      "\(raw: accessLevel) typealias S2 = \(raw: strategyNames[1])",
      "\(raw: accessLevel) typealias I3 = \(raw: strategyNames[2]).I",
      "\(raw: accessLevel) typealias S3 = \(raw: strategyNames[2])",
      "\(raw: accessLevel) typealias I4 = \(raw: strategyNames[3]).I",
      "\(raw: accessLevel) typealias S4 = \(raw: strategyNames[3])",
    ]
    members.append(contentsOf: typeAliases)

    return members
  }
}

/// Macro implementation for `@LockmanCompositeStrategy` with 5 strategy arguments.
///
/// This macro represents the maximum supported number of strategy coordination,
/// handling the most complex scenarios in the Lockman framework.
public struct LockmanCompositeStrategy5Macro: ExtensionMacro, MemberMacro {
  public static func expansion(
    of _: AttributeSyntax,
    attachedTo declaration: some DeclGroupSyntax,
    providingExtensionsOf type: some TypeSyntaxProtocol,
    conformingTo _: [TypeSyntax],
    in _: some MacroExpansionContext
  ) throws -> [ExtensionDeclSyntax] {
    guard declaration.is(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let extensionDecl = try ExtensionDeclSyntax("extension \(type): LockmanCompositeAction5") {}
    return [extensionDecl]
  }

  public static func expansion(
    of node: AttributeSyntax,
    providingMembersOf declaration: some DeclGroupSyntax,
    in _: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
      throw LockmanMacroError.invalidDeclaration(
        "@LockmanCompositeStrategy can only be attached to an enum declaration."
      )
    }

    let strategyNames = try extractStrategyTypeNames(from: node, expectedCount: 5)
    let caseDefinitions = try extractEnumCaseDefinitions(from: enumDecl)
    let accessLevel = determineAccessLevel(from: enumDecl)

    var members: [DeclSyntax] = []

    if !caseDefinitions.isEmpty {
      let actionNameProperty = try generateActionNameProperty(
        caseDefinitions: caseDefinitions,
        accessLevel: accessLevel
      )
      members.append(actionNameProperty)
    }

    let strategyIdProperty = generateStrategyIdPropertyMulti(
      strategyNames: strategyNames,
      strategyCount: 5,
      accessLevel: accessLevel
    )
    members.append(strategyIdProperty)

    // Do not generate lockmanInfo property - user must implement it
    // This allows users to specify strategy-specific details

    // Generate type aliases for protocol conformance
    let typeAliases: [DeclSyntax] = [
      "\(raw: accessLevel) typealias I1 = \(raw: strategyNames[0]).I",
      "\(raw: accessLevel) typealias S1 = \(raw: strategyNames[0])",
      "\(raw: accessLevel) typealias I2 = \(raw: strategyNames[1]).I",
      "\(raw: accessLevel) typealias S2 = \(raw: strategyNames[1])",
      "\(raw: accessLevel) typealias I3 = \(raw: strategyNames[2]).I",
      "\(raw: accessLevel) typealias S3 = \(raw: strategyNames[2])",
      "\(raw: accessLevel) typealias I4 = \(raw: strategyNames[3]).I",
      "\(raw: accessLevel) typealias S4 = \(raw: strategyNames[3])",
      "\(raw: accessLevel) typealias I5 = \(raw: strategyNames[4]).I",
      "\(raw: accessLevel) typealias S5 = \(raw: strategyNames[4])",
    ]
    members.append(contentsOf: typeAliases)

    return members
  }
}

// MARK: - Legacy Compatibility

/// Legacy function maintained for backwards compatibility.
///
/// - Deprecated: Use `extractEnumCaseDefinitions` instead.
func extractEnumCases(from enumDecl: EnumDeclSyntax) throws -> [EnumCase] {
  let definitions = try extractEnumCaseDefinitions(from: enumDecl)
  return definitions.map { definition in
    EnumCase(name: definition.name, associatedValueCount: definition.associatedValueCount)
  }
}

/// Legacy function maintained for backwards compatibility.
///
/// - Deprecated: Use `determineAccessLevel` instead.
func getAccessLevel(from decl: some DeclGroupSyntax) -> String {
  if let enumDecl = decl.as(EnumDeclSyntax.self) {
    return determineAccessLevel(from: enumDecl)
  }
  return "internal"
}

/// Legacy function maintained for backwards compatibility.
///
/// - Deprecated: Use `generateActionNameProperty` instead.
func generateActionNameProperty(cases: [EnumCase], accessLevel: String) throws -> DeclSyntax {
  let definitions = cases.map { enumCase in
    EnumCaseDefinition(name: enumCase.name, associatedValueCount: enumCase.associatedValueCount)
  }
  return try generateActionNameProperty(caseDefinitions: definitions, accessLevel: accessLevel)
}

/// Legacy type maintained for backwards compatibility.
///
/// - Deprecated: Use `EnumCaseDefinition` instead.
struct EnumCase {
  let name: String
  let associatedValueCount: Int
}
