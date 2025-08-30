import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class LockmanSingleExecutionMacroTests: XCTestCase {
    
    private var mockContext: MockMacroExpansionContext!

    override func setUp() {
      super.setUp()
      mockContext = MockMacroExpansionContext()
    }

    override func tearDown() {
      super.tearDown()
      mockContext = nil
    }

    // MARK: - ExtensionMacro Tests

    func testExtensionMacroExpansionBasic() throws {
      let type = IdentifierTypeSyntax(name: .identifier("UserAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("UserAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension UserAction: LockmanSingleExecutionAction"))
    }

    func testExtensionMacroExpansionWithGenericType() throws {
      let type = IdentifierTypeSyntax(name: .identifier("GenericAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      let structDecl = StructDeclSyntax(
        name: .identifier("GenericAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        attachedTo: structDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension GenericAction: LockmanSingleExecutionAction"))
    }

    // MARK: - MemberMacro Tests

    func testMemberMacroExpansionWithValidEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("login")),
          EnumCaseElementSyntax(name: .identifier("logout"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("UserAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      
      let members = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .login: return \"login\""))
      XCTAssertTrue(generatedCode.contains("case .logout: return \"logout\""))
    }

    func testMemberMacroExpansionWithNonEnum() throws {
      let structDecl = StructDeclSyntax(
        name: .identifier("InvalidAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      
      let members = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        providingMembersOf: structDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 0)
      XCTAssertTrue(mockContext.diagnostics.count > 0)
    }

    func testMemberMacroExpansionWithPublicEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("action"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        modifiers: DeclModifierListSyntax([
          DeclModifierSyntax(name: .keyword(.public))
        ]),
        name: .identifier("PublicAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      
      let members = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("public var actionName: String"))
    }

    func testMemberMacroExpansionWithEmptyEnum() throws {
      let enumDecl = EnumDeclSyntax(
        name: .identifier("EmptyAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      
      let members = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 0) // Empty enum generates no members
    }

    func testMemberMacroExpansionWithComplexCases() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(
            name: .identifier("fetch"),
            parameterClause: EnumCaseParameterClauseSyntax(
              parameters: EnumCaseParameterListSyntax([
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
              ])
            )
          ),
          EnumCaseElementSyntax(name: .identifier("save"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("DataAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanSingleExecution"))
      )
      
      let members = try LockmanSingleExecutionMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .fetch(_): return \"fetch\""))
      XCTAssertTrue(generatedCode.contains("case .save: return \"save\""))
      
      // Should NOT generate createLockmanInfo method (users implement themselves)
      XCTAssertFalse(generatedCode.contains("createLockmanInfo"))
    }

  }

  // Mock context for testing diagnostic emission
  private class MockMacroExpansionContext: MacroExpansionContext {
    var diagnostics: [Diagnostic] = []
    
    var lexicalContext: [Syntax] = []
    
    func makeUniqueName(_ providedName: String) -> TokenSyntax {
      return TokenSyntax(.identifier(providedName + "_unique"), presence: .present)
    }
    
    func diagnose(_ diagnostic: Diagnostic) {
      diagnostics.append(diagnostic)
    }
    
    func location(
      of node: some SyntaxProtocol,
      at position: PositionInSyntaxNode,
      filePathMode: SourceLocationFilePathMode
    ) -> AbstractSourceLocation? {
      return nil
    }
    
    func location(
      of node: some SyntaxProtocol,
      at position: AbsolutePosition,
      filePathMode: SourceLocationFilePathMode
    ) -> AbstractSourceLocation? {
      return nil
    }
    
    func location(
      of node: some SyntaxProtocol,
      at position: AbsolutePosition,
      filePathMode: SourceLocationFilePathMode
    ) -> SourceLocation? {
      return nil
    }
  }

#endif
