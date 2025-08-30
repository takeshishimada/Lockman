import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class LockmanPriorityBasedMacroTests: XCTestCase {
    
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
      let type = IdentifierTypeSyntax(name: .identifier("TaskAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TaskAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanPriorityBasedMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension TaskAction: LockmanPriorityBasedAction"))
    }

    func testExtensionMacroExpansionWithDifferentType() throws {
      let type = IdentifierTypeSyntax(name: .identifier("QueueAction"))
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      let enumDecl = EnumDeclSyntax(
        name: .identifier("QueueAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let extensions = try LockmanPriorityBasedMacro.expansion(
        of: attributeNode,
        attachedTo: enumDecl,
        providingExtensionsOf: type,
        conformingTo: [],
        in: mockContext
      )
      
      XCTAssertEqual(extensions.count, 1)
      let extensionText = extensions.first!.description
      XCTAssertTrue(extensionText.contains("extension QueueAction: LockmanPriorityBasedAction"))
    }

    // MARK: - MemberMacro Tests

    func testMemberMacroExpansionWithValidEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("highPriority")),
          EnumCaseElementSyntax(name: .identifier("normalPriority")),
          EnumCaseElementSyntax(name: .identifier("lowPriority"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TaskAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      
      let members = try LockmanPriorityBasedMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .highPriority: return \"highPriority\""))
      XCTAssertTrue(generatedCode.contains("case .normalPriority: return \"normalPriority\""))
      XCTAssertTrue(generatedCode.contains("case .lowPriority: return \"lowPriority\""))
    }

    func testMemberMacroExpansionWithNonEnum() throws {
      let classDecl = ClassDeclSyntax(
        name: .identifier("InvalidAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      
      let members = try LockmanPriorityBasedMacro.expansion(
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
          EnumCaseElementSyntax(name: .identifier("urgent"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        modifiers: DeclModifierListSyntax([
          DeclModifierSyntax(name: .keyword(.public))
        ]),
        name: .identifier("UrgentAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      
      let members = try LockmanPriorityBasedMacro.expansion(
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
        name: .identifier("EmptyTaskAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      
      let members = try LockmanPriorityBasedMacro.expansion(
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
            name: .identifier("processTask"),
            parameterClause: EnumCaseParameterClauseSyntax(
              parameters: EnumCaseParameterListSyntax([
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("Int"))),
                EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
              ])
            )
          ),
          EnumCaseElementSyntax(name: .identifier("cancelTask"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("WorkflowAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )
      
      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("LockmanPriorityBased"))
      )
      
      let members = try LockmanPriorityBasedMacro.expansion(
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )
      
      XCTAssertEqual(members.count, 1)
      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .processTask(_, _): return \"processTask\""))
      XCTAssertTrue(generatedCode.contains("case .cancelTask: return \"cancelTask\""))
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
