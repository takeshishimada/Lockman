import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class MemberGeneratorTests: XCTestCase {

    private var mockContext: MockMacroExpansionContext!

    override func setUp() {
      super.setUp()
      mockContext = MockMacroExpansionContext()
    }

    override func tearDown() {
      super.tearDown()
      mockContext = nil
    }

    func testExtractAccessLevelFromModifiersWithPublic() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.public))
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "public")
    }

    func testExtractAccessLevelFromModifiersWithInternal() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.internal))
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "internal")
    }

    func testExtractAccessLevelFromModifiersWithPrivate() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.private))
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "private")
    }

    func testExtractAccessLevelFromModifiersWithFilePrivate() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.fileprivate))
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "fileprivate")
    }

    func testExtractAccessLevelFromModifiersWithOpen() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.open))
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "open")
    }

    func testExtractAccessLevelFromEmptyModifiers() {
      let modifiers = DeclModifierListSyntax([])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "internal")
    }

    func testExtractAccessLevelFromModifiersReversePriority() {
      let modifiers = DeclModifierListSyntax([
        DeclModifierSyntax(name: .keyword(.public)),
        DeclModifierSyntax(name: .keyword(.private)),
      ])

      let accessLevel = extractAccessLevel(from: modifiers)
      XCTAssertEqual(accessLevel, "private")
    }

    func testGenerateActionNameMembersWithEmptyEnum() {
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )

      let members = generateActionNameMembers(for: enumDecl)
      XCTAssertEqual(members.count, 0)
    }

    func testGenerateActionNameMembersWithSingleCase() {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("login"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let members = generateActionNameMembers(for: enumDecl)
      XCTAssertEqual(members.count, 1)

      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .login: return \"login\""))
    }

    func testGenerateActionNameMembersWithMultipleCases() {
      let loginCase = EnumCaseElementSyntax(name: .identifier("login"))
      let logoutCase = EnumCaseElementSyntax(
        name: .identifier("logout"),
        parameterClause: EnumCaseParameterClauseSyntax(
          parameters: EnumCaseParameterListSyntax([
            EnumCaseParameterSyntax(type: IdentifierTypeSyntax(name: .identifier("String")))
          ])
        )
      )

      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([loginCase, logoutCase])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let members = generateActionNameMembers(for: enumDecl)
      XCTAssertEqual(members.count, 1)

      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("case .login: return \"login\""))
      XCTAssertTrue(generatedCode.contains("case .logout(_): return \"logout\""))
    }

    func testGenerateActionNameMembersWithPublicEnum() {
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
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let members = generateActionNameMembers(for: enumDecl)
      XCTAssertEqual(members.count, 1)

      let generatedCode = members.first!.description
      XCTAssertTrue(generatedCode.contains("public var actionName: String"))
    }

    func testMakeActionNameMemberDeclWithValidEnum() throws {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("login")),
          EnumCaseElementSyntax(name: .identifier("logout")),
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("TestMacro"))
      )

      let result = makeActionNameMemberDecl(
        name: "TestMacro",
        of: attributeNode,
        providingMembersOf: enumDecl,
        in: mockContext
      )

      XCTAssertEqual(result.count, 1)
      let generatedCode = result.first!.description
      XCTAssertTrue(generatedCode.contains("var actionName: String"))
      XCTAssertTrue(generatedCode.contains("case .login: return \"login\""))
      XCTAssertTrue(generatedCode.contains("case .logout: return \"logout\""))
    }

    func testMakeActionNameMemberDeclWithNonEnum() throws {
      let structDecl = StructDeclSyntax(
        name: .identifier("TestStruct"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([]))
      )

      let attributeNode = AttributeSyntax(
        attributeName: IdentifierTypeSyntax(name: .identifier("TestMacro"))
      )

      let result = makeActionNameMemberDecl(
        name: "TestMacro",
        of: attributeNode,
        providingMembersOf: structDecl,
        in: mockContext
      )

      XCTAssertEqual(result.count, 0)
      XCTAssertTrue(mockContext.diagnostics.count > 0)
      let diagnostic = mockContext.diagnostics.first!
      XCTAssertTrue(diagnostic.message.description.contains("can only be attached to an enum"))
    }

    func testGenerateLockmanInfoMembersWithPublicEnum() {
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
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let members = generateLockmanInfoMembers(for: enumDecl)
      XCTAssertEqual(members.count, 1)

      let generatedCode = members.first!.description
      XCTAssertTrue(
        generatedCode.contains("public func createLockmanInfo() -> LockmanSingleExecutionInfo"))
      XCTAssertTrue(generatedCode.contains(".init(actionId: actionName)"))
    }

    func testGenerateLockmanInfoMembersWithInternalEnum() {
      let enumCase = EnumCaseDeclSyntax(
        elements: EnumCaseElementListSyntax([
          EnumCaseElementSyntax(name: .identifier("action"))
        ])
      )
      let memberItem = MemberBlockItemSyntax(decl: enumCase)
      let enumDecl = EnumDeclSyntax(
        name: .identifier("TestAction"),
        memberBlock: MemberBlockSyntax(members: MemberBlockItemListSyntax([memberItem]))
      )

      let members = generateLockmanInfoMembers(for: enumDecl)
      XCTAssertEqual(members.count, 1)

      let generatedCode = members.first!.description
      XCTAssertTrue(
        generatedCode.contains("internal func createLockmanInfo() -> LockmanSingleExecutionInfo"))
    }

    func testLockmanMacroError() {
      let error = LockmanMacroError.invalidDeclaration("Test error message")

      XCTAssertEqual(error.description, "Test error message")
    }

    func testLockmanMacroErrorUnsupportedStrategyCount() {
      let error = LockmanMacroError.unsupportedStrategyCount(10)

      XCTAssertEqual(
        error.description,
        "@LockmanCompositeStrategy supports 2-5 strategies, but 10 were provided.")
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
