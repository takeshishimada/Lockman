import XCTest

@testable import Lockman

/// Unit tests for LockmanStrategyId
///
/// Tests the type-safe identifier for Lockman strategies that supports both built-in
/// and user-defined strategies with flexible initialization patterns.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Basic Initialization Methods
/// - [ ] init(_:) with raw string value
/// - [ ] init(type:identifier:) with strategy type and optional custom identifier
/// - [ ] init(name:configuration:) with structured name and optional configuration
/// - [ ] init(stringLiteral:) for ExpressibleByStringLiteral conformance
/// - [ ] Value property storage and access
///
/// ### Type-based Initialization
/// - [ ] init(type:) without custom identifier uses fully qualified type name
/// - [ ] init(type:identifier:) with custom identifier overrides type name
/// - [ ] String(reflecting:) usage for fully qualified name including module
/// - [ ] Built-in strategy type initialization
/// - [ ] Custom strategy type initialization
/// - [ ] Generic type parameter handling <S: LockmanStrategy>
///
/// ### Name and Configuration Initialization
/// - [ ] init(name:) without configuration uses simple name format
/// - [ ] init(name:configuration:) with configuration uses "name:configuration" format
/// - [ ] Configuration string formatting and delimiter handling
/// - [ ] Empty configuration string scenarios
/// - [ ] Complex configuration string scenarios
///
/// ### String Literal Support
/// - [ ] ExpressibleByStringLiteral protocol conformance
/// - [ ] Direct assignment from string literals
/// - [ ] String literal compilation and type inference
/// - [ ] String literal syntax convenience
///
/// ### Protocol Conformances
/// - [ ] Hashable conformance for dictionary usage
/// - [ ] Sendable conformance for concurrent usage
/// - [ ] CustomStringConvertible conformance
/// - [ ] Equatable behavior through Hashable
/// - [ ] Hash value consistency across equal instances
///
/// ### CustomStringConvertible Implementation
/// - [ ] description property returns value string
/// - [ ] String representation consistency
/// - [ ] Debug output formatting
/// - [ ] Print statement compatibility
///
/// ### Convenience Factory Methods
/// - [ ] static func from(_:) for strategy type
/// - [ ] static func from(_:identifier:) for strategy type with custom identifier
/// - [ ] Factory method syntax convenience
/// - [ ] Type inference behavior with factory methods
/// - [ ] Method overloading resolution
///
/// ### Common Strategy ID Constants
/// - [ ] static let singleExecution constant
/// - [ ] static let priorityBased constant
/// - [ ] static let groupCoordination constant
/// - [ ] static let concurrencyLimited constant
/// - [ ] Built-in strategy ID consistency
/// - [ ] Constant initialization and lazy evaluation
///
/// ### Equality and Hashing
/// - [ ] Equality comparison between same string values
/// - [ ] Equality comparison between different initialization methods
/// - [ ] Hash consistency for equal strategy IDs
/// - [ ] Hash collision handling
/// - [ ] Set and Dictionary usage scenarios
///
/// ### String Value Generation Patterns
/// - [ ] Fully qualified type names with module information
/// - [ ] Simple string identifiers
/// - [ ] Name:configuration format consistency
/// - [ ] Special character handling in names and configurations
/// - [ ] Unicode string support
///
/// ### Integration with Built-in Strategies
/// - [ ] LockmanSingleExecutionStrategy.self type usage
/// - [ ] LockmanPriorityBasedStrategy.self type usage
/// - [ ] LockmanGroupCoordinationStrategy.self type usage
/// - [ ] LockmanConcurrencyLimitedStrategy.self type usage
/// - [ ] Type safety with built-in strategy types
///
/// ### Dynamic and User-defined Scenarios
/// - [ ] User-defined strategy type initialization
/// - [ ] Runtime string-based ID creation
/// - [ ] Dynamic configuration generation
/// - [ ] Variable-based ID construction
/// - [ ] Complex naming schemes and conventions
///
/// ### Edge Cases and Validation
/// - [ ] Empty string ID handling
/// - [ ] Very long string IDs
/// - [ ] Special characters in strategy names
/// - [ ] Unicode characters in identifiers
/// - [ ] Nil configuration parameter handling
/// - [ ] Empty configuration string behavior
///
/// ### Type Safety and Compile-time Verification
/// - [ ] Generic type constraint enforcement
/// - [ ] LockmanStrategy protocol requirement verification
/// - [ ] Compile-time type checking for strategy types
/// - [ ] Type inference in various contexts
/// - [ ] Generic method resolution
///
/// ### Performance Characteristics
/// - [ ] String initialization performance
/// - [ ] Hash computation efficiency
/// - [ ] Memory efficiency with string storage
/// - [ ] Comparison operation performance
/// - [ ] Factory method overhead
///
/// ### Concurrent Usage and Thread Safety
/// - [ ] Sendable conformance correctness
/// - [ ] Thread-safe access to value property
/// - [ ] Concurrent hash computation
/// - [ ] Concurrent equality comparisons
/// - [ ] Thread-safe constant access
///
/// ### Integration with LockmanStrategyContainer
/// - [ ] Usage as dictionary keys in strategy container
/// - [ ] Registration and resolution key consistency
/// - [ ] Type erasure compatibility
/// - [ ] Container ID lookup performance
/// - [ ] ID uniqueness in container contexts
///
/// ### String Formatting and Representation
/// - [ ] Description property output format
/// - [ ] String interpolation behavior
/// - [ ] Debugging output clarity
/// - [ ] Logging integration compatibility
/// - [ ] Error message formatting
///
/// ### Migration and Compatibility
/// - [ ] Backward compatibility with string-based IDs
/// - [ ] Migration from type-based to configuration-based IDs
/// - [ ] Version compatibility across different identifier formats
/// - [ ] API evolution support
/// - [ ] Legacy ID format handling
///
final class LockmanStrategyIdTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Basic Initialization Tests

  func testInitWithRawStringValue() {
    let strategyId = LockmanStrategyId("custom-strategy")
    XCTAssertEqual(strategyId.value, "custom-strategy")
    XCTAssertEqual(strategyId.description, "custom-strategy")
  }

  func testInitWithEmptyString() {
    let strategyId = LockmanStrategyId("")
    XCTAssertEqual(strategyId.value, "")
    XCTAssertEqual(strategyId.description, "")
  }

  func testInitWithComplexString() {
    let complex = "MyApp.Advanced.CacheStrategy-v2.1"
    let strategyId = LockmanStrategyId(complex)
    XCTAssertEqual(strategyId.value, complex)
    XCTAssertEqual(strategyId.description, complex)
  }

  func testInitWithUnicodeString() {
    let unicode = "戦略_テスト_🚀"
    let strategyId = LockmanStrategyId(unicode)
    XCTAssertEqual(strategyId.value, unicode)
    XCTAssertEqual(strategyId.description, unicode)
  }

  // MARK: - Type-based Initialization Tests

  func testInitWithStrategyTypeWithoutCustomIdentifier() {
    let strategyId = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)

    // Should use fully qualified type name including module
    XCTAssertTrue(strategyId.value.contains("LockmanSingleExecutionStrategy"))
    XCTAssertFalse(strategyId.value.isEmpty)
    XCTAssertEqual(strategyId.description, strategyId.value)
  }

  func testInitWithStrategyTypeWithCustomIdentifier() {
    let customId = "my-custom-single-execution"
    let strategyId = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self, identifier: customId)

    XCTAssertEqual(strategyId.value, customId)
    XCTAssertEqual(strategyId.description, customId)
  }

  func testInitWithDifferentStrategyTypes() {
    let singleExecution = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    let priorityBased = LockmanStrategyId(type: LockmanPriorityBasedStrategy.self)
    let groupCoordination = LockmanStrategyId(type: LockmanGroupCoordinationStrategy.self)
    let concurrencyLimited = LockmanStrategyId(type: LockmanConcurrencyLimitedStrategy.self)

    // All should be different
    XCTAssertNotEqual(singleExecution, priorityBased)
    XCTAssertNotEqual(priorityBased, groupCoordination)
    XCTAssertNotEqual(groupCoordination, concurrencyLimited)
    XCTAssertNotEqual(concurrencyLimited, singleExecution)

    // All should contain their respective type names
    XCTAssertTrue(singleExecution.value.contains("LockmanSingleExecutionStrategy"))
    XCTAssertTrue(priorityBased.value.contains("LockmanPriorityBasedStrategy"))
    XCTAssertTrue(groupCoordination.value.contains("LockmanGroupCoordinationStrategy"))
    XCTAssertTrue(concurrencyLimited.value.contains("LockmanConcurrencyLimitedStrategy"))
  }

  // MARK: - Name and Configuration Initialization Tests

  func testInitWithNameOnly() {
    let strategyId = LockmanStrategyId(name: "RateLimitStrategy")
    XCTAssertEqual(strategyId.value, "RateLimitStrategy")
    XCTAssertEqual(strategyId.description, "RateLimitStrategy")
  }

  func testInitWithNameAndConfiguration() {
    let strategyId = LockmanStrategyId(name: "CacheStrategy", configuration: "timeout-30")
    XCTAssertEqual(strategyId.value, "CacheStrategy:timeout-30")
    XCTAssertEqual(strategyId.description, "CacheStrategy:timeout-30")
  }

  func testInitWithNameAndEmptyConfiguration() {
    let strategyId = LockmanStrategyId(name: "TestStrategy", configuration: "")
    XCTAssertEqual(strategyId.value, "TestStrategy:")
  }

  func testInitWithNameAndNilConfiguration() {
    let strategyId = LockmanStrategyId(name: "SimpleStrategy", configuration: nil)
    XCTAssertEqual(strategyId.value, "SimpleStrategy")
  }

  func testInitWithComplexNameAndConfiguration() {
    let strategyId = LockmanStrategyId(
      name: "MyApp.Advanced.RetryStrategy",
      configuration: "attempts-5,delay-exponential"
    )
    XCTAssertEqual(strategyId.value, "MyApp.Advanced.RetryStrategy:attempts-5,delay-exponential")
  }

  // MARK: - String Literal Support Tests

  func testExpressibleByStringLiteralDirectAssignment() {
    let strategyId: LockmanStrategyId = "direct-assignment"
    XCTAssertEqual(strategyId.value, "direct-assignment")
    XCTAssertEqual(strategyId.description, "direct-assignment")
  }

  func testStringLiteralWithComplexValue() {
    let strategyId: LockmanStrategyId = "MyModule.ComplexStrategy:config=advanced"
    XCTAssertEqual(strategyId.value, "MyModule.ComplexStrategy:config=advanced")
  }

  func testStringLiteralTypeInference() {
    func acceptsStrategyId(_ id: LockmanStrategyId) -> String {
      return id.value
    }

    let result = acceptsStrategyId("inferred-type")
    XCTAssertEqual(result, "inferred-type")
  }

  // MARK: - Protocol Conformances Tests

  func testHashableConformance() {
    let id1 = LockmanStrategyId("same-value")
    let id2 = LockmanStrategyId("same-value")
    let id3 = LockmanStrategyId("different-value")

    // Equal instances should have same hash
    XCTAssertEqual(id1, id2)
    XCTAssertEqual(id1.hashValue, id2.hashValue)

    // Different instances should not be equal
    XCTAssertNotEqual(id1, id3)
    XCTAssertNotEqual(id2, id3)
  }

  func testEquatableBehavior() {
    let id1 = LockmanStrategyId("test-strategy")
    let id2 = LockmanStrategyId("test-strategy")
    let id3 = LockmanStrategyId("other-strategy")

    XCTAssertEqual(id1, id2)
    XCTAssertNotEqual(id1, id3)
    XCTAssertTrue(id1 == id2)
    XCTAssertTrue(id1 != id3)
  }

  func testSendableConformance() async {
    let strategyId = LockmanStrategyId("concurrent-strategy")

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return strategyId.value
    }

    // All results should be the same
    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertEqual(result, "concurrent-strategy")
    }
  }

  func testSetAndDictionaryUsage() {
    let id1 = LockmanStrategyId("strategy-one")
    let id2 = LockmanStrategyId("strategy-two")
    let id1Copy = LockmanStrategyId("strategy-one")

    // Test Set usage
    let strategySet: Set<LockmanStrategyId> = [id1, id2, id1Copy]
    XCTAssertEqual(strategySet.count, 2)  // id1 and id1Copy are the same
    XCTAssertTrue(strategySet.contains(id1))
    XCTAssertTrue(strategySet.contains(id2))
    XCTAssertTrue(strategySet.contains(id1Copy))

    // Test Dictionary usage
    var dictionary: [LockmanStrategyId: String] = [:]
    dictionary[id1] = "first strategy"
    dictionary[id2] = "second strategy"

    XCTAssertEqual(dictionary[id1], "first strategy")
    XCTAssertEqual(dictionary[id2], "second strategy")
    XCTAssertEqual(dictionary[id1Copy], "first strategy")  // Same as id1
  }

  // MARK: - Convenience Factory Methods Tests

  func testFactoryMethodFromType() {
    let strategyId = LockmanStrategyId.from(LockmanSingleExecutionStrategy.self)
    let directInit = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)

    XCTAssertEqual(strategyId, directInit)
    XCTAssertEqual(strategyId.value, directInit.value)
  }

  func testFactoryMethodFromTypeWithIdentifier() {
    let customId = "factory-custom-id"
    let strategyId = LockmanStrategyId.from(LockmanPriorityBasedStrategy.self, identifier: customId)
    let directInit = LockmanStrategyId(
      type: LockmanPriorityBasedStrategy.self, identifier: customId)

    XCTAssertEqual(strategyId, directInit)
    XCTAssertEqual(strategyId.value, customId)
  }

  // MARK: - Common Strategy ID Constants Tests

  func testBuiltInStrategyConstants() {
    // Test that constants are correctly initialized
    XCTAssertFalse(LockmanStrategyId.singleExecution.value.isEmpty)
    XCTAssertFalse(LockmanStrategyId.priorityBased.value.isEmpty)
    XCTAssertFalse(LockmanStrategyId.groupCoordination.value.isEmpty)
    XCTAssertFalse(LockmanStrategyId.concurrencyLimited.value.isEmpty)

    // Test that they're all different
    let constants = [
      LockmanStrategyId.singleExecution,
      LockmanStrategyId.priorityBased,
      LockmanStrategyId.groupCoordination,
      LockmanStrategyId.concurrencyLimited,
    ]

    let uniqueConstants = Set(constants)
    XCTAssertEqual(uniqueConstants.count, constants.count)
  }

  func testBuiltInStrategyConstantsMatchTypeInit() {
    let singleExecution = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    let priorityBased = LockmanStrategyId(type: LockmanPriorityBasedStrategy.self)
    let groupCoordination = LockmanStrategyId(type: LockmanGroupCoordinationStrategy.self)
    let concurrencyLimited = LockmanStrategyId(type: LockmanConcurrencyLimitedStrategy.self)

    XCTAssertEqual(LockmanStrategyId.singleExecution, singleExecution)
    XCTAssertEqual(LockmanStrategyId.priorityBased, priorityBased)
    XCTAssertEqual(LockmanStrategyId.groupCoordination, groupCoordination)
    XCTAssertEqual(LockmanStrategyId.concurrencyLimited, concurrencyLimited)
  }

  // MARK: - Equality Across Different Initialization Methods Tests

  func testEqualityAcrossDifferentInitMethods() {
    let value = "test-strategy"

    let directInit = LockmanStrategyId(value)
    let nameInit = LockmanStrategyId(name: value)
    let stringLiteral: LockmanStrategyId = "test-strategy"

    XCTAssertEqual(directInit, nameInit)
    XCTAssertEqual(nameInit, stringLiteral)
    XCTAssertEqual(directInit, stringLiteral)
  }

  func testEqualityWithTypeBasedAndStringBased() {
    let customId = "single-execution-custom"
    let typeBasedId = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self, identifier: customId)
    let stringBasedId = LockmanStrategyId(customId)

    XCTAssertEqual(typeBasedId, stringBasedId)
    XCTAssertEqual(typeBasedId.value, stringBasedId.value)
  }

  // MARK: - Edge Cases and Validation Tests

  func testVeryLongStringId() {
    let longId = String(repeating: "VeryLongStrategyName", count: 100)
    let strategyId = LockmanStrategyId(longId)

    XCTAssertEqual(strategyId.value, longId)
    XCTAssertEqual(strategyId.description, longId)
  }

  func testSpecialCharactersInNames() {
    let specialChars = "Strategy@#$%^&*(){}[]!<>?.,;:'\"|\\`~"
    let strategyId = LockmanStrategyId(specialChars)

    XCTAssertEqual(strategyId.value, specialChars)
  }

  func testUnicodeCharactersInIdentifiers() {
    let unicode = "策略_اسټراتیژی_стратегия_🎯💻🔐"
    let strategyId = LockmanStrategyId(unicode)

    XCTAssertEqual(strategyId.value, unicode)
    XCTAssertEqual(strategyId.description, unicode)
  }

  func testConfigurationWithSpecialCharacters() {
    let strategyId = LockmanStrategyId(
      name: "ComplexStrategy",
      configuration: "param1=value1&param2=value2,option=true"
    )

    XCTAssertEqual(strategyId.value, "ComplexStrategy:param1=value1&param2=value2,option=true")
  }

  // MARK: - Performance and Memory Tests

  func testStringInitializationPerformance() {
    let testString = "PerformanceTestStrategy"

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<1000 {
        let _ = LockmanStrategyId(testString)
      }
    }

    // Should complete in reasonable time (less than 0.1 seconds)
    XCTAssertLessThan(executionTime, 0.1)
  }

  func testHashComputationPerformance() {
    let strategyIds = (0..<1000).map { LockmanStrategyId("strategy-\($0)") }

    let executionTime = TestSupport.measureExecutionTime {
      var hashes: Set<Int> = []
      for id in strategyIds {
        hashes.insert(id.hashValue)
      }
    }

    // Should complete in reasonable time
    XCTAssertLessThan(executionTime, 0.1)
  }

  func testMemoryEfficiencyWithRepeatedIds() {
    let baseId = "RepeatedStrategy"
    var strategyIds: [LockmanStrategyId] = []

    // Create many references to the same ID
    for _ in 0..<1000 {
      strategyIds.append(LockmanStrategyId(baseId))
    }

    // Verify all are equal
    strategyIds.forEach { id in
      XCTAssertEqual(id.value, baseId)
    }
  }

  // MARK: - Thread Safety and Concurrent Usage Tests

  func testConcurrentAccess() {
    let strategyId = LockmanStrategyId("concurrent-test")
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let value = strategyId.value
        let description = strategyId.description
        let hash = strategyId.hashValue

        XCTAssertEqual(value, "concurrent-test")
        XCTAssertEqual(description, "concurrent-test")
        XCTAssertNotEqual(hash, 0)  // Hash should be computed

        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentEqualityComparisons() async {
    let id1 = LockmanStrategyId("comparison-test")
    let id2 = LockmanStrategyId("comparison-test")
    let id3 = LockmanStrategyId("different-test")

    await TestSupport.performConcurrentOperations(count: 20) {
      XCTAssertEqual(id1, id2)
      XCTAssertNotEqual(id1, id3)
      XCTAssertNotEqual(id2, id3)
    }
  }

  // MARK: - String Representation and Formatting Tests

  func testCustomStringConvertibleImplementation() {
    let strategies = [
      LockmanStrategyId("simple"),
      LockmanStrategyId(name: "complex", configuration: "config"),
      LockmanStrategyId(type: LockmanSingleExecutionStrategy.self),
      LockmanStrategyId.singleExecution,
    ]

    strategies.forEach { strategy in
      XCTAssertEqual(strategy.description, strategy.value)
      XCTAssertFalse(strategy.description.isEmpty)
    }
  }

  func testStringInterpolation() {
    let strategyId = LockmanStrategyId("interpolation-test")
    let interpolated = "Strategy ID: \(strategyId)"

    XCTAssertTrue(interpolated.contains("interpolation-test"))
    XCTAssertEqual(interpolated, "Strategy ID: interpolation-test")
  }

  func testDebuggingOutput() {
    let strategyId = LockmanStrategyId(name: "Debug", configuration: "verbose")
    let debugString = String(describing: strategyId)

    XCTAssertEqual(debugString, "Debug:verbose")
  }

  // MARK: - Integration and Real-world Usage Tests

  func testStrategyContainerKeyUsage() {
    // Simulate dictionary usage like in LockmanStrategyContainer
    var container: [LockmanStrategyId: String] = [:]

    let singleExecution = LockmanStrategyId.singleExecution
    let priorityBased = LockmanStrategyId.priorityBased
    let customStrategy = LockmanStrategyId("CustomStrategy")

    container[singleExecution] = "Single Execution Implementation"
    container[priorityBased] = "Priority Based Implementation"
    container[customStrategy] = "Custom Implementation"

    XCTAssertEqual(container[singleExecution], "Single Execution Implementation")
    XCTAssertEqual(container[priorityBased], "Priority Based Implementation")
    XCTAssertEqual(container[customStrategy], "Custom Implementation")
  }

  func testDynamicIdGeneration() {
    // Test runtime ID generation scenarios
    let timestamp = Date().timeIntervalSince1970
    let dynamicId = LockmanStrategyId("DynamicStrategy-\(timestamp)")

    XCTAssertTrue(dynamicId.value.hasPrefix("DynamicStrategy-"))
    XCTAssertTrue(dynamicId.value.contains(String(timestamp)))
  }

  func testConfigurationVariations() {
    let baseStrategy = "CacheStrategy"
    let configs = ["timeout-30", "timeout-60", "size-100MB", "redis-backend"]

    let strategyIds = configs.map { config in
      LockmanStrategyId(name: baseStrategy, configuration: config)
    }

    // All should be different
    let uniqueIds = Set(strategyIds)
    XCTAssertEqual(uniqueIds.count, configs.count)

    // All should contain the base strategy name
    strategyIds.forEach { id in
      XCTAssertTrue(id.value.hasPrefix(baseStrategy))
    }
  }
}
