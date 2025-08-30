import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

#if canImport(LockmanMacros)
  @testable import LockmanMacros

  final class ConformanceExtensionGeneratorTests: XCTestCase {

    override func setUp() {
      super.setUp()
    }

    override func tearDown() {
      super.tearDown()
    }

    func testMakeConformanceExtensionDeclBasic() throws {
      let type = IdentifierTypeSyntax(name: .identifier("UserAction"))
      let protocolName = "LockmanSingleExecutionAction"
      
      let extensionDecl = try makeConformanceExtensionDecl(
        for: type,
        conformingTo: protocolName
      )
      
      let extensionText = extensionDecl.description
      XCTAssertTrue(extensionText.contains("extension UserAction: LockmanSingleExecutionAction"))
      XCTAssertTrue(extensionText.contains("{"))
      XCTAssertTrue(extensionText.contains("}"))
    }

    func testMakeConformanceExtensionDeclWithGenericType() throws {
      let type = IdentifierTypeSyntax(name: .identifier("GenericAction"))
      let protocolName = "LockmanPriorityBasedAction"
      
      let extensionDecl = try makeConformanceExtensionDecl(
        for: type,
        conformingTo: protocolName
      )
      
      let extensionText = extensionDecl.description
      XCTAssertTrue(extensionText.contains("extension GenericAction: LockmanPriorityBasedAction"))
    }

    func testMakeAdvancedConformanceExtensionDeclWithoutWhereClause() throws {
      let type = IdentifierTypeSyntax(name: .identifier("SimpleAction"))
      let protocolName = "LockmanGroupCoordinatedAction"
      
      let extensionDecl = try makeAdvancedConformanceExtensionDecl(
        for: type,
        conformingTo: protocolName
      )
      
      let extensionText = extensionDecl.description
      XCTAssertTrue(extensionText.contains("extension SimpleAction: LockmanGroupCoordinatedAction"))
    }

    func testMakeAdvancedConformanceExtensionDeclWithWhereClause() throws {
      let type = IdentifierTypeSyntax(name: .identifier("ConditionalAction"))
      let protocolName = "LockmanConcurrencyLimitedAction"
      let whereClause = "T: Sendable"
      
      let extensionDecl = try makeAdvancedConformanceExtensionDecl(
        for: type,
        conformingTo: protocolName,
        whereClause: whereClause
      )
      
      let extensionText = extensionDecl.description
      XCTAssertTrue(extensionText.contains("extension ConditionalAction: LockmanConcurrencyLimitedAction where T: Sendable"))
    }

    func testIsValidSwiftIdentifierValid() {
      XCTAssertTrue(isValidSwiftIdentifier("ValidName"))
      XCTAssertTrue(isValidSwiftIdentifier("validName"))
      XCTAssertTrue(isValidSwiftIdentifier("_private"))
      XCTAssertTrue(isValidSwiftIdentifier("CamelCase"))
      XCTAssertTrue(isValidSwiftIdentifier("snake_case"))
      XCTAssertTrue(isValidSwiftIdentifier("with123Numbers"))
    }

    func testIsValidSwiftIdentifierInvalid() {
      XCTAssertFalse(isValidSwiftIdentifier(""))
      XCTAssertFalse(isValidSwiftIdentifier(" "))
      XCTAssertFalse(isValidSwiftIdentifier("123Invalid"))
      XCTAssertFalse(isValidSwiftIdentifier("Invalid Name"))
      XCTAssertFalse(isValidSwiftIdentifier("Invalid-Name"))
      XCTAssertFalse(isValidSwiftIdentifier("Invalid@Name"))
      XCTAssertFalse(isValidSwiftIdentifier(" LeadingSpace"))
      XCTAssertFalse(isValidSwiftIdentifier("TrailingSpace "))
    }

    func testIsValidSwiftIdentifierKeywords() {
      XCTAssertFalse(isValidSwiftIdentifier("class"))
      XCTAssertFalse(isValidSwiftIdentifier("struct"))
      XCTAssertFalse(isValidSwiftIdentifier("enum"))
      XCTAssertFalse(isValidSwiftIdentifier("protocol"))
      XCTAssertFalse(isValidSwiftIdentifier("func"))
      XCTAssertFalse(isValidSwiftIdentifier("var"))
      XCTAssertFalse(isValidSwiftIdentifier("let"))
    }

    func testExtractBaseTypeNameSimple() {
      let type = IdentifierTypeSyntax(name: .identifier("SimpleType"))
      let typeName = extractBaseTypeName(from: type)
      XCTAssertEqual(typeName, "SimpleType")
    }

    func testExtractBaseTypeNameGeneric() {
      let type = IdentifierTypeSyntax(name: .identifier("Array"))
      let typeName = extractBaseTypeName(from: type)
      XCTAssertEqual(typeName, "Array")
    }

    func testExtractBaseTypeNameQualified() {
      let type = IdentifierTypeSyntax(name: .identifier("Module.UserAction"))
      let typeName = extractBaseTypeName(from: type)
      XCTAssertEqual(typeName, "UserAction")
    }

    func testExtractBaseTypeNameWithGenericBrackets() {
      let type = IdentifierTypeSyntax(name: .identifier("Array<String>"))
      let typeName = extractBaseTypeName(from: type)
      XCTAssertEqual(typeName, "Array")
    }

    func testGenerateExtensionErrorMessage() {
      let type = IdentifierTypeSyntax(name: .identifier("TestType"))
      let protocolName = "TestProtocol"
      let error = NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
      
      let message = generateExtensionErrorMessage(
        for: type,
        conformingTo: protocolName,
        underlyingError: error
      )
      
      XCTAssertTrue(message.contains("TestType"))
      XCTAssertTrue(message.contains("TestProtocol"))
      XCTAssertTrue(message.contains("Test error"))
      XCTAssertTrue(message.contains("Failed to generate protocol conformance extension"))
    }

  }

#if DEBUG
  final class ExtensionGeneratorTestUtilsTests: XCTestCase {
    
    func testValidateExtensionStructure() throws {
      let type = IdentifierTypeSyntax(name: .identifier("TestAction"))
      let extensionDecl = try makeConformanceExtensionDecl(
        for: type,
        conformingTo: "TestProtocol"
      )
      
      let isValid = ExtensionGeneratorTestUtils.validateExtensionStructure(
        extensionDecl,
        expectedType: "TestAction",
        expectedProtocol: "TestProtocol"
      )
      
      XCTAssertTrue(isValid)
    }

    func testValidateExtensionStructureInvalid() throws {
      let type = IdentifierTypeSyntax(name: .identifier("TestAction"))
      let extensionDecl = try makeConformanceExtensionDecl(
        for: type,
        conformingTo: "TestProtocol"
      )
      
      let isValid = ExtensionGeneratorTestUtils.validateExtensionStructure(
        extensionDecl,
        expectedType: "WrongType",
        expectedProtocol: "TestProtocol"
      )
      
      XCTAssertFalse(isValid)
    }

    func testTestExtensionGenerationSuccess() {
      let result = ExtensionGeneratorTestUtils.testExtensionGeneration(
        typeName: "ValidType",
        protocolName: "ValidProtocol"
      )
      
      XCTAssertTrue(result.success)
      XCTAssertTrue(result.issues.isEmpty)
    }

    func testTestExtensionGenerationFailure() {
      let result = ExtensionGeneratorTestUtils.testExtensionGeneration(
        typeName: "",
        protocolName: "ValidProtocol"
      )
      
      XCTAssertFalse(result.success)
      XCTAssertFalse(result.issues.isEmpty)
    }

    func testValidateExtensionStructureInvalidProtocol() throws {
      let type = IdentifierTypeSyntax(name: .identifier("TestAction"))
      let extensionDecl = try makeConformanceExtensionDecl(
        for: type,
        conformingTo: "TestProtocol"
      )
      
      let isValid = ExtensionGeneratorTestUtils.validateExtensionStructure(
        extensionDecl,
        expectedType: "TestAction",
        expectedProtocol: "WrongProtocol"
      )
      
      XCTAssertFalse(isValid)
    }
  }
#endif

#endif
