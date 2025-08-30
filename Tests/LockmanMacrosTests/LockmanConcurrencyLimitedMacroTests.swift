import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class LockmanConcurrencyLimitedMacroTests: XCTestCase {
    
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
      let type = IdentifierTypeSyntax(name: .identifier("NetworkAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("NetworkAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanConcurrencyLimitedMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension NetworkAction: LockmanConcurrencyLimitedAction"))
    }

    func testExtensionMacroExpansionWithDifferentType() throws {
      let type = IdentifierTypeSyntax(name: .identifier("DataAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("DataAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanConcurrencyLimitedMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension DataAction: LockmanConcurrencyLimitedAction"))
    }

    // MARK: - MemberMacro Tests

    func testMemberMacroExpansionWithValidEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("upload")),
          EnumCaseElementSyntax(name: .identifier("download"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("NetworkAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      
      let members = try LockmanConcurrencyLimitedMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .upload: return \"upload\""))
      XCTAssertTrue(generatedCode.contains("case .download: return \"download\""))
    }

    func testMemberMacroExpansionWithNonEnum() throws {
      let structDecl = StructDeclSyntax(
        name: .identifier("InvalidAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      
      let members = try LockmanConcurrencyLimitedMacro.expansion(
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
          EnumCaseElementSyntax(name: .identifier("process"))
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
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      
      let members = try LockmanConcurrencyLimitedMacro.expansion(
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
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      
      let members = try LockmanConcurrencyLimitedMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 0) // Empty enum generates no members
    }

    func testMemberMacroExpansionWithAssociatedValues() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(
            name: .identifier("uploadFile"),
            parameterClause: EnumCaseParameterClauseSyntax(
              parameters: EnumCaseParameterListSyntax([
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("String"))),
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("Int")))
              ])
            )
          ),
          EnumCaseElementSyntax(name: .identifier("cancel"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("FileAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanConcurrencyLimited"))
      )
      
      let members = try LockmanConcurrencyLimitedMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .uploadFile(_, _): return \"uploadFile\""))
      XCTAssertTrue(generatedCode.contains("case .cancel: return \"cancel\""))
      
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
