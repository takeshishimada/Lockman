import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class LockmanGroupCoordinationMacroTests: XCTestCase {
    
    private var mockContext: MockMacroExpansionContext!

    override func setUp() {
      super.setUp()
      mockContext = MockMacroExpansionContext()
    }

    override func tearDown() {
      super.tearDown()
      mockContext = nil
    }

    // MARK: - SimpleDiagnosticMessage Tests

    func testSimpleDiagnosticMessageCreation() {
      let message = SimpleDiagnosticMessage("Test error message")
      
      XCTAssertEqual(message.message, "Test error message")
      XCTAssertEqual(message.severity, .error)
      XCTAssertNotNil(message.diagnosticID)
    }

    func testSimpleDiagnosticMessageWithCustomSeverity() {
      let message = SimpleDiagnosticMessage("Warning message", severity: .warning)
      
      XCTAssertEqual(message.message, "Warning message")
      XCTAssertEqual(message.severity, .warning)
      XCTAssertNotNil(message.diagnosticID)
    }

    // MARK: - ExtensionMacro Tests

    func testExtensionMacroExpansionBasic() throws {
      let type = IdentifierTypeSyntax(name: .identifier("NavigationAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("NavigationAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanGroupCoordinationMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension NavigationAction: LockmanGroupCoordinatedAction"))
    }

    func testExtensionMacroExpansionWithDifferentType() throws {
      let type = IdentifierTypeSyntax(name: .identifier("TeamAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TeamAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanGroupCoordinationMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension TeamAction: LockmanGroupCoordinatedAction"))
    }

    // MARK: - MemberMacro Tests

    func testMemberMacroExpansionWithValidEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("navigate")),
          EnumCaseElementSyntax(name: .identifier("goBack"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("NavigationAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      
      let members = try LockmanGroupCoordinationMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .navigate: return \"navigate\""))
      XCTAssertTrue(generatedCode.contains("case .goBack: return \"goBack\""))
      
      // Should NOT generate createLockmanInfo method (users implement themselves)
      XCTAssertFalse(generatedCode.contains("createLockmanInfo"))
    }

    func testMemberMacroExpansionWithNonEnum() throws {
      let classDecl = ClassDeclSyntax(
        name: .identifier("InvalidAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      
      let members = try LockmanGroupCoordinationMacro.expansion(
        of: attributeNode,
        providingMembersOf: classDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 0)
      XCTAssertTrue(mockContext.diagnostics.count > 0)
    }

    func testMemberMacroExpansionWithPublicEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("coordinate"))
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
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      
      let members = try LockmanGroupCoordinationMacro.expansion(
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
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      
      let members = try LockmanGroupCoordinationMacro.expansion(
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
            name: .identifier("navigateToDetail"),
            parameterClause: EnumCaseParameterClauseSyntax(
              parameters: EnumCaseParameterListSyntax([
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("String"))),
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("Bool")))
              ])
            )
          ),
          EnumCaseElementSyntax(name: .identifier("dismiss"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("ComplexAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanGroupCoordination"))
      )
      
      let members = try LockmanGroupCoordinationMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .navigateToDetail(_, _): return \"navigateToDetail\""))
      XCTAssertTrue(generatedCode.contains("case .dismiss: return \"dismiss\""))
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
