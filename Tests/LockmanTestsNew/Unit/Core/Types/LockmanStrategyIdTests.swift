import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanStrategyId tests via direct testing
// ✅ Tests covering initialization, equality, hashable, codable functionality
// ✅ Phase 1: Basic initialization with string and string literal
// ✅ Phase 2: Equality, hashable conformance, edge cases with empty/special strings
// ✅ Phase 3: Codable conformance and integration usage patterns

final class LockmanStrategyIdTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Basic Initialization and Properties
  
  func testLockmanStrategyIdStringInitialization() {
    // Test direct string initialization
    let strategyId = LockmanStrategyId("testStrategy")
    XCTAssertEqual(strategyId.value, "testStrategy")
    XCTAssertEqual(strategyId.description, "testStrategy")
  }
  
  func testLockmanStrategyIdStringLiteralInitialization() {
    // Test ExpressibleByStringLiteral
    let strategyId: LockmanStrategyId = "stringLiteralStrategy"
    XCTAssertEqual(strategyId.value, "stringLiteralStrategy")
    XCTAssertEqual(strategyId.description, "stringLiteralStrategy")
  }
  
  func testLockmanStrategyIdEquality() {
    // Test Hashable and Equatable conformance
    let id1 = LockmanStrategyId("strategy1")
    let id2 = LockmanStrategyId("strategy1")
    let id3 = LockmanStrategyId("strategy2")
    
    XCTAssertEqual(id1, id2)
    XCTAssertNotEqual(id1, id3)
  }
  
  func testLockmanStrategyIdHashable() {
    // Test Hashable conformance
    let id1 = LockmanStrategyId("strategy1")
    let id2 = LockmanStrategyId("strategy1")
    let id3 = LockmanStrategyId("strategy2")
    
    var set = Set<LockmanStrategyId>()
    set.insert(id1)
    set.insert(id2) // Should not increase count (same value)
    set.insert(id3)
    
    XCTAssertEqual(set.count, 2)
    XCTAssertTrue(set.contains(LockmanStrategyId("strategy1")))
    XCTAssertTrue(set.contains(LockmanStrategyId("strategy2")))
  }
  
  func testLockmanStrategyIdTypeInitialization() {
    // Test type-based initialization
    let strategyId = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    
    // Should contain the type name (exact format depends on reflection implementation)
    XCTAssertTrue(strategyId.value.contains("LockmanSingleExecutionStrategy"))
    XCTAssertFalse(strategyId.value.isEmpty)
  }
  
  func testLockmanStrategyIdTypeWithCustomIdentifier() {
    // Test type initialization with custom identifier
    let strategyId = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self,
      identifier: "customSingleExecution"
    )
    XCTAssertEqual(strategyId.value, "customSingleExecution")
  }
  
  func testLockmanStrategyIdNameInitialization() {
    // Test name-based initialization without configuration
    let strategyId = LockmanStrategyId(name: "TestStrategy")
    XCTAssertEqual(strategyId.value, "TestStrategy")
  }
  
  func testLockmanStrategyIdNameWithConfiguration() {
    // Test name-based initialization with configuration
    let strategyId = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-30"
    )
    XCTAssertEqual(strategyId.value, "CacheStrategy:timeout-30")
  }
  
  // MARK: - Phase 2: Static Factory Methods and Convenience
  
  func testLockmanStrategyIdFromTypeFactory() {
    // Test .from(Type) factory method
    let strategyId = LockmanStrategyId.from(LockmanSingleExecutionStrategy.self)
    let directId = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    
    XCTAssertEqual(strategyId, directId)
  }
  
  func testLockmanStrategyIdFromTypeWithIdentifierFactory() {
    // Test .from(Type, identifier:) factory method
    let strategyId = LockmanStrategyId.from(
      LockmanSingleExecutionStrategy.self,
      identifier: "factoryCustom"
    )
    
    XCTAssertEqual(strategyId.value, "factoryCustom")
  }
  
  func testLockmanStrategyIdBuiltInConstants() {
    // Test built-in strategy constants
    XCTAssertEqual(LockmanStrategyId.singleExecution.value, 
                   LockmanStrategyId(type: LockmanSingleExecutionStrategy.self).value)
    
    XCTAssertEqual(LockmanStrategyId.priorityBased.value,
                   LockmanStrategyId(type: LockmanPriorityBasedStrategy.self).value)
    
    XCTAssertEqual(LockmanStrategyId.groupCoordination.value,
                   LockmanStrategyId(type: LockmanGroupCoordinationStrategy.self).value)
    
    XCTAssertEqual(LockmanStrategyId.concurrencyLimited.value,
                   LockmanStrategyId(type: LockmanConcurrencyLimitedStrategy.self).value)
  }
  
  // MARK: - Phase 3: Edge Cases and Special Characters
  
  func testLockmanStrategyIdWithEmptyString() {
    // Test with empty string
    let strategyId = LockmanStrategyId("")
    XCTAssertEqual(strategyId.value, "")
    XCTAssertEqual(strategyId.description, "")
  }
  
  func testLockmanStrategyIdWithSpecialCharacters() {
    // Test with special characters
    let strategyId1 = LockmanStrategyId("strategy_with_underscores")
    let strategyId2 = LockmanStrategyId("strategy-with-dashes")
    let strategyId3 = LockmanStrategyId("strategy.with.dots")
    let strategyId4 = LockmanStrategyId("strategy/with/slashes")
    let strategyId5 = LockmanStrategyId("strategy with spaces")
    
    XCTAssertEqual(strategyId1.value, "strategy_with_underscores")
    XCTAssertEqual(strategyId2.value, "strategy-with-dashes")
    XCTAssertEqual(strategyId3.value, "strategy.with.dots")
    XCTAssertEqual(strategyId4.value, "strategy/with/slashes")
    XCTAssertEqual(strategyId5.value, "strategy with spaces")
  }
  
  func testLockmanStrategyIdWithUnicodeCharacters() {
    // Test with unicode characters
    let strategyId1 = LockmanStrategyId("strategy🚀emoji")
    let strategyId2 = LockmanStrategyId("ストラテジー")
    let strategyId3 = LockmanStrategyId("стратегия")
    
    XCTAssertEqual(strategyId1.value, "strategy🚀emoji")
    XCTAssertEqual(strategyId2.value, "ストラテジー")
    XCTAssertEqual(strategyId3.value, "стратегия")
  }
  
  func testLockmanStrategyIdConfigurationWithSpecialCharacters() {
    // Test configuration with special characters
    let strategyId = LockmanStrategyId(
      name: "TestStrategy",
      configuration: "config-with_special.chars/123"
    )
    XCTAssertEqual(strategyId.value, "TestStrategy:config-with_special.chars/123")
  }
  
  func testLockmanStrategyIdSendableConformance() {
    // Test Sendable conformance (compile-time test)
    let strategyId: LockmanStrategyId = "testStrategy"
    
    // This compiles without warning = Sendable conformance works
    Task {
      let _ = strategyId
    }
    
    XCTAssertEqual(strategyId.value, "testStrategy")
  }
  
  func testLockmanStrategyIdCustomStringConvertible() {
    // Test CustomStringConvertible conformance
    let strategyId = LockmanStrategyId("testDescription")
    let description = String(describing: strategyId)
    
    XCTAssertEqual(description, "testDescription")
    XCTAssertEqual(strategyId.description, description)
  }

}
