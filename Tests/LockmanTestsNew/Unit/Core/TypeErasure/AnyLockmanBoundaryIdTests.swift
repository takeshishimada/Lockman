import XCTest

@testable import Lockman

/// Unit tests for AnyLockmanBoundaryId
///
/// Tests the type-erased wrapper for heterogeneous boundary identifiers.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Type Erasure Implementation
/// - [ ] AnyHashable-based storage validation
/// - [ ] Type erasure wrapper construction
/// - [ ] init(_ value: any LockmanBoundaryId) functionality
/// - [ ] Private base property encapsulation
/// - [ ] Value semantics preservation
///
/// ### Hashable Implementation
/// - [ ] Equality comparison through AnyHashable
/// - [ ] Hash value generation through base.hash(into:)
/// - [ ] Type-aware equality (different types ≠ equal)
/// - [ ] Hash collision prevention with type information
/// - [ ] Consistent hashing behavior
///
/// ### @unchecked Sendable Validation
/// - [ ] Thread-safe usage justification
/// - [ ] AnyHashable thread safety inheritance
/// - [ ] No additional mutable state verification
/// - [ ] Safe concurrent access validation
/// - [ ] Concurrent collection usage safety
///
/// ### Heterogeneous Storage Testing
/// - [ ] Dictionary<AnyLockmanBoundaryId, Value> usage
/// - [ ] Set<AnyLockmanBoundaryId> usage
/// - [ ] Mixed boundary ID types in same collection
/// - [ ] Type safety with heterogeneous storage
/// - [ ] Collection performance with mixed types
///
/// ### Built-in Type Wrapping
/// - [ ] String boundary ID wrapping
/// - [ ] Int boundary ID wrapping
/// - [ ] UUID boundary ID wrapping
/// - [ ] Enum boundary ID wrapping
/// - [ ] Struct boundary ID wrapping
///
/// ### Custom Type Integration
/// - [ ] UserBoundary enum example validation
/// - [ ] SessionBoundary struct example validation
/// - [ ] Complex custom type wrapping
/// - [ ] Raw value preservation
/// - [ ] Custom equality behavior preservation
///
/// ### Equality and Hashing Behavior
/// - [ ] Same type, same value equality
/// - [ ] Same type, different value inequality
/// - [ ] Different type, same value inequality
/// - [ ] Hash consistency for equal instances
/// - [ ] Hash uniqueness for different instances
/// - [ ] Transitivity and reflexivity validation
///
/// ### Performance & Memory
/// - [ ] Wrapping overhead measurement
/// - [ ] Memory footprint with AnyHashable
/// - [ ] Hash computation performance
/// - [ ] Equality comparison performance
/// - [ ] Large-scale type erasure usage
///
/// ### Thread Safety & Concurrency
/// - [ ] Concurrent wrapper creation
/// - [ ] Concurrent equality comparisons
/// - [ ] Concurrent hash operations
/// - [ ] Thread-safe collection operations
/// - [ ] Race condition prevention
///
/// ### Integration with Strategy System
/// - [ ] Strategy boundary management with type erasure
/// - [ ] Lock acquisition with erased boundary IDs
/// - [ ] Cleanup operations with mixed boundary types
/// - [ ] Container storage with heterogeneous boundaries
/// - [ ] Debug output with type-erased boundaries
///
/// ### Real-world Usage Patterns
/// - [ ] Multi-module boundary coordination
/// - [ ] Cross-feature boundary management
/// - [ ] Dynamic boundary type handling
/// - [ ] Plugin-based boundary systems
/// - [ ] Framework-level boundary abstraction
///
/// ### Edge Cases & Error Conditions
/// - [ ] Wrapping nil-equivalent values (if possible)
/// - [ ] Very large boundary ID values
/// - [ ] Complex nested boundary structures
/// - [ ] Memory pressure with many wrapped instances
/// - [ ] Type information preservation edge cases
///
/// ### Documentation Examples Validation
/// - [ ] UserBoundary enum example
/// - [ ] SessionBoundary struct example
/// - [ ] Mixed collection usage example
/// - [ ] Code example correctness verification
/// - [ ] Usage pattern validation from documentation
///
final class AnyLockmanBoundaryIdTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Type Erasure Implementation Tests

  func testAnyHashableBasedStorageValidation() {
    let stringBoundary = "test-boundary"
    let anyBoundary = AnyLockmanBoundaryId(stringBoundary)

    XCTAssertNotNil(anyBoundary)
    // The wrapper should preserve the original value's behavior
    XCTAssertEqual(anyBoundary.hashValue, stringBoundary.hashValue)
  }

  func testTypeErasureWrapperConstruction() {
    let stringId = "string-boundary"
    let intId = 42
    let uuidId = UUID()

    let stringWrapper = AnyLockmanBoundaryId(stringId)
    let intWrapper = AnyLockmanBoundaryId(intId)
    let uuidWrapper = AnyLockmanBoundaryId(uuidId)

    XCTAssertNotNil(stringWrapper)
    XCTAssertNotNil(intWrapper)
    XCTAssertNotNil(uuidWrapper)
  }

  func testInitWithAnyLockmanBoundaryIdFunctionality() {
    func testInitWithValue<T: LockmanBoundaryId>(_ value: T) -> AnyLockmanBoundaryId {
      return AnyLockmanBoundaryId(value)
    }

    let stringResult = testInitWithValue("test")
    let intResult = testInitWithValue(123)
    let uuidResult = testInitWithValue(UUID())

    XCTAssertNotNil(stringResult)
    XCTAssertNotNil(intResult)
    XCTAssertNotNil(uuidResult)
  }

  func testValueSemanticsPreservation() {
    let originalValue = "test-value"
    let wrapper1 = AnyLockmanBoundaryId(originalValue)
    let wrapper2 = AnyLockmanBoundaryId(originalValue)

    // Value semantics: same input should create equal wrappers
    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  // MARK: - Hashable Implementation Tests

  func testEqualityComparisonThroughAnyHashable() {
    let value1 = "same-value"
    let value2 = "same-value"
    let value3 = "different-value"

    let wrapper1 = AnyLockmanBoundaryId(value1)
    let wrapper2 = AnyLockmanBoundaryId(value2)
    let wrapper3 = AnyLockmanBoundaryId(value3)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertNotEqual(wrapper1, wrapper3)
    XCTAssertNotEqual(wrapper2, wrapper3)
  }

  func testHashValueGenerationThroughBase() {
    let stringValue = "hash-test"
    let wrapper = AnyLockmanBoundaryId(stringValue)

    // Should have consistent hash
    let hash1 = wrapper.hashValue
    let hash2 = wrapper.hashValue
    XCTAssertEqual(hash1, hash2)

    // Should not be zero (very unlikely)
    XCTAssertNotEqual(hash1, 0)
  }

  func testTypeAwareEqualityDifferentTypes() {
    // Same value, different types should NOT be equal
    let stringValue = "42"
    let intValue = 42

    let stringWrapper = AnyLockmanBoundaryId(stringValue)
    let intWrapper = AnyLockmanBoundaryId(intValue)

    XCTAssertNotEqual(stringWrapper, intWrapper)
    // Different types should likely have different hashes (though not guaranteed)
    XCTAssertNotEqual(stringWrapper.hashValue, intWrapper.hashValue)
  }

  func testHashCollisionPreventionWithTypeInformation() {
    struct CustomBoundary1: LockmanBoundaryId {
      let value: String
      func hash(into hasher: inout Hasher) { hasher.combine(value) }
      static func == (lhs: CustomBoundary1, rhs: CustomBoundary1) -> Bool { lhs.value == rhs.value }
    }

    struct CustomBoundary2: LockmanBoundaryId {
      let value: String
      func hash(into hasher: inout Hasher) { hasher.combine(value) }
      static func == (lhs: CustomBoundary2, rhs: CustomBoundary2) -> Bool { lhs.value == rhs.value }
    }

    let boundary1 = AnyLockmanBoundaryId(CustomBoundary1(value: "test"))
    let boundary2 = AnyLockmanBoundaryId(CustomBoundary2(value: "test"))

    // Different types with same value should not be equal
    XCTAssertNotEqual(boundary1, boundary2)
  }

  func testConsistentHashingBehavior() {
    let boundaries = ["boundary1", "boundary2", "boundary3"]
    let wrappers = boundaries.map { AnyLockmanBoundaryId($0) }

    // Multiple hash computations should be consistent
    for wrapper in wrappers {
      let hash1 = wrapper.hashValue
      let hash2 = wrapper.hashValue
      let hash3 = wrapper.hashValue

      XCTAssertEqual(hash1, hash2)
      XCTAssertEqual(hash2, hash3)
    }
  }

  // MARK: - @unchecked Sendable Validation Tests

  func testThreadSafeUsageJustification() async {
    let boundary = AnyLockmanBoundaryId("concurrent-test")

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return boundary
    }

    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertEqual(result, boundary)
    }
  }

  func testSafeConcurrentAccessValidation() {
    let boundary = AnyLockmanBoundaryId("thread-safe-boundary")
    let expectation = XCTestExpectation(description: "Safe concurrent access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let hash = boundary.hashValue
        let equalityCheck = boundary == boundary

        XCTAssertNotEqual(hash, 0)
        XCTAssertTrue(equalityCheck)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentCollectionUsageSafety() async {
    let boundaries = ["b1", "b2", "b3", "b4", "b5"]
    let wrappers = boundaries.map { AnyLockmanBoundaryId($0) }

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return wrappers.randomElement()!
    }

    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertTrue(wrappers.contains(result))
    }
  }

  // MARK: - Heterogeneous Storage Testing

  func testDictionaryWithMixedKeyTypes() {
    let stringBoundary = AnyLockmanBoundaryId("string-key")
    let intBoundary = AnyLockmanBoundaryId(42)
    let uuidBoundary = AnyLockmanBoundaryId(UUID())

    var boundaryMap: [AnyLockmanBoundaryId: String] = [:]
    boundaryMap[stringBoundary] = "String Value"
    boundaryMap[intBoundary] = "Int Value"
    boundaryMap[uuidBoundary] = "UUID Value"

    XCTAssertEqual(boundaryMap[stringBoundary], "String Value")
    XCTAssertEqual(boundaryMap[intBoundary], "Int Value")
    XCTAssertEqual(boundaryMap[uuidBoundary], "UUID Value")
    XCTAssertEqual(boundaryMap.count, 3)
  }

  func testSetWithMixedTypes() {
    let stringBoundary = AnyLockmanBoundaryId("string-boundary")
    let intBoundary = AnyLockmanBoundaryId(100)
    let stringBoundaryCopy = AnyLockmanBoundaryId("string-boundary")

    let boundarySet: Set<AnyLockmanBoundaryId> = [stringBoundary, intBoundary, stringBoundaryCopy]

    XCTAssertEqual(boundarySet.count, 2)  // stringBoundary and stringBoundaryCopy are same
    XCTAssertTrue(boundarySet.contains(stringBoundary))
    XCTAssertTrue(boundarySet.contains(intBoundary))
    XCTAssertTrue(boundarySet.contains(stringBoundaryCopy))
  }

  func testMixedBoundaryIdTypesInSameCollection() {
    enum UserBoundary: String, LockmanBoundaryId {
      case profile = "profile"
      case settings = "settings"
    }

    struct SessionBoundary: LockmanBoundaryId {
      let sessionId: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
      }

      static func == (lhs: SessionBoundary, rhs: SessionBoundary) -> Bool {
        return lhs.sessionId == rhs.sessionId
      }
    }

    let userKey = AnyLockmanBoundaryId(UserBoundary.profile)
    let sessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "abc123"))
    let stringKey = AnyLockmanBoundaryId("simple-string")

    var mixedCollection: [AnyLockmanBoundaryId: String] = [:]
    mixedCollection[userKey] = "User Profile"
    mixedCollection[sessionKey] = "Session abc123"
    mixedCollection[stringKey] = "Simple String"

    XCTAssertEqual(mixedCollection[userKey], "User Profile")
    XCTAssertEqual(mixedCollection[sessionKey], "Session abc123")
    XCTAssertEqual(mixedCollection[stringKey], "Simple String")
    XCTAssertEqual(mixedCollection.count, 3)
  }

  func testTypeSafetyWithHeterogeneousStorage() {
    let stringBoundary1 = AnyLockmanBoundaryId("test")
    let stringBoundary2 = AnyLockmanBoundaryId("test")
    let intBoundary = AnyLockmanBoundaryId(42)

    // Same type, same value should be equal
    XCTAssertEqual(stringBoundary1, stringBoundary2)

    // Different types should not be equal
    XCTAssertNotEqual(stringBoundary1, intBoundary)
    XCTAssertNotEqual(stringBoundary2, intBoundary)
  }

  // MARK: - Built-in Type Wrapping Tests

  func testStringBoundaryIdWrapping() {
    let stringValue = "string-boundary-test"
    let wrapper = AnyLockmanBoundaryId(stringValue)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanBoundaryId(stringValue)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testIntBoundaryIdWrapping() {
    let intValue = 12345
    let wrapper = AnyLockmanBoundaryId(intValue)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanBoundaryId(intValue)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testUUIDBoundaryIdWrapping() {
    let uuid = UUID()
    let wrapper = AnyLockmanBoundaryId(uuid)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanBoundaryId(uuid)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testEnumBoundaryIdWrapping() {
    enum TestBoundary: String, LockmanBoundaryId {
      case first = "first"
      case second = "second"
    }

    let enumWrapper1 = AnyLockmanBoundaryId(TestBoundary.first)
    let enumWrapper2 = AnyLockmanBoundaryId(TestBoundary.second)
    let enumWrapper1Copy = AnyLockmanBoundaryId(TestBoundary.first)

    XCTAssertEqual(enumWrapper1, enumWrapper1Copy)
    XCTAssertNotEqual(enumWrapper1, enumWrapper2)
  }

  func testStructBoundaryIdWrapping() {
    struct CustomBoundary: LockmanBoundaryId {
      let id: String
      let category: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(category)
      }

      static func == (lhs: CustomBoundary, rhs: CustomBoundary) -> Bool {
        return lhs.id == rhs.id && lhs.category == rhs.category
      }
    }

    let struct1 = CustomBoundary(id: "test", category: "A")
    let struct2 = CustomBoundary(id: "test", category: "B")
    let struct1Copy = CustomBoundary(id: "test", category: "A")

    let wrapper1 = AnyLockmanBoundaryId(struct1)
    let wrapper2 = AnyLockmanBoundaryId(struct2)
    let wrapper1Copy = AnyLockmanBoundaryId(struct1Copy)

    XCTAssertEqual(wrapper1, wrapper1Copy)
    XCTAssertNotEqual(wrapper1, wrapper2)
  }

  // MARK: - Custom Type Integration Tests

  func testUserBoundaryEnumExampleValidation() {
    // From documentation example
    enum UserBoundary: String, LockmanBoundaryId {
      case profile = "profile"
      case settings = "settings"
    }

    let userKey = AnyLockmanBoundaryId(UserBoundary.profile)
    let anotherUserKey = AnyLockmanBoundaryId(UserBoundary.profile)
    let settingsKey = AnyLockmanBoundaryId(UserBoundary.settings)

    XCTAssertEqual(userKey, anotherUserKey)
    XCTAssertNotEqual(userKey, settingsKey)
  }

  func testSessionBoundaryStructExampleValidation() {
    // From documentation example
    struct SessionBoundary: LockmanBoundaryId {
      let sessionId: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
      }

      static func == (lhs: SessionBoundary, rhs: SessionBoundary) -> Bool {
        return lhs.sessionId == rhs.sessionId
      }
    }

    let sessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "abc123"))
    let anotherSessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "abc123"))
    let differentSessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "xyz789"))

    XCTAssertEqual(sessionKey, anotherSessionKey)
    XCTAssertNotEqual(sessionKey, differentSessionKey)
  }

  func testComplexCustomTypeWrapping() {
    struct ComplexBoundary: LockmanBoundaryId {
      let module: String
      let feature: String
      let version: Int
      let metadata: [String: String]

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(feature)
        hasher.combine(version)
        hasher.combine(metadata.keys.sorted())
        hasher.combine(metadata.values.sorted())
      }

      static func == (lhs: ComplexBoundary, rhs: ComplexBoundary) -> Bool {
        return lhs.module == rhs.module && lhs.feature == rhs.feature && lhs.version == rhs.version
          && lhs.metadata == rhs.metadata
      }
    }

    let complex1 = ComplexBoundary(
      module: "auth",
      feature: "login",
      version: 1,
      metadata: ["env": "prod", "region": "us"]
    )
    let complex2 = ComplexBoundary(
      module: "auth",
      feature: "login",
      version: 1,
      metadata: ["env": "prod", "region": "us"]
    )
    let complex3 = ComplexBoundary(
      module: "auth",
      feature: "login",
      version: 2,
      metadata: ["env": "prod", "region": "us"]
    )

    let wrapper1 = AnyLockmanBoundaryId(complex1)
    let wrapper2 = AnyLockmanBoundaryId(complex2)
    let wrapper3 = AnyLockmanBoundaryId(complex3)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertNotEqual(wrapper1, wrapper3)
  }

  // MARK: - Equality and Hashing Behavior Tests

  func testSameTypeSameValueEquality() {
    let value = "equality-test"
    let wrapper1 = AnyLockmanBoundaryId(value)
    let wrapper2 = AnyLockmanBoundaryId(value)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  func testSameTypeDifferentValueInequality() {
    let value1 = "value1"
    let value2 = "value2"
    let wrapper1 = AnyLockmanBoundaryId(value1)
    let wrapper2 = AnyLockmanBoundaryId(value2)

    XCTAssertNotEqual(wrapper1, wrapper2)
    // Different values should likely have different hashes (not guaranteed but expected)
    XCTAssertNotEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  func testDifferentTypeSameValueInequality() {
    let stringValue = "123"
    let intValue = 123
    let stringWrapper = AnyLockmanBoundaryId(stringValue)
    let intWrapper = AnyLockmanBoundaryId(intValue)

    XCTAssertNotEqual(stringWrapper, intWrapper)
  }

  func testHashConsistencyForEqualInstances() {
    let boundaries = ["test1", "test2", "test3"]

    for boundary in boundaries {
      let wrapper1 = AnyLockmanBoundaryId(boundary)
      let wrapper2 = AnyLockmanBoundaryId(boundary)

      XCTAssertEqual(wrapper1, wrapper2)
      XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
    }
  }

  func testTransitivityAndReflexivityValidation() {
    let value = "reflexivity-test"
    let wrapper1 = AnyLockmanBoundaryId(value)
    let wrapper2 = AnyLockmanBoundaryId(value)
    let wrapper3 = AnyLockmanBoundaryId(value)

    // Reflexivity: a == a
    XCTAssertEqual(wrapper1, wrapper1)

    // Symmetry: a == b implies b == a
    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper2, wrapper1)

    // Transitivity: a == b && b == c implies a == c
    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper2, wrapper3)
    XCTAssertEqual(wrapper1, wrapper3)
  }

  // MARK: - Performance & Memory Tests

  func testWrappingOverheadMeasurement() {
    let values = (0..<1000).map { "boundary-\($0)" }

    let executionTime = TestSupport.measureExecutionTime {
      var wrappers: [AnyLockmanBoundaryId] = []
      for value in values {
        wrappers.append(AnyLockmanBoundaryId(value))
      }
    }

    XCTAssertLessThan(executionTime, 0.1)  // Should be fast
  }

  func testHashComputationPerformance() {
    let wrappers = (0..<1000).map { AnyLockmanBoundaryId("boundary-\($0)") }

    let executionTime = TestSupport.measureExecutionTime {
      var hashes: [Int] = []
      for wrapper in wrappers {
        hashes.append(wrapper.hashValue)
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  func testEqualityComparisonPerformance() {
    let wrapper1 = AnyLockmanBoundaryId("performance-test")
    let wrapper2 = AnyLockmanBoundaryId("performance-test")
    let wrapper3 = AnyLockmanBoundaryId("different")

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<10000 {
        let _ = wrapper1 == wrapper2
        let _ = wrapper1 == wrapper3
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  // MARK: - Thread Safety & Concurrency Tests

  func testConcurrentWrapperCreation() {
    let values = ["v1", "v2", "v3", "v4", "v5"]
    let expectation = XCTestExpectation(description: "Concurrent wrapper creation")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        let randomValue = values.randomElement()!
        let wrapper = AnyLockmanBoundaryId(randomValue)
        XCTAssertNotNil(wrapper)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentEqualityComparisons() {
    let wrapper1 = AnyLockmanBoundaryId("concurrent-equality")
    let wrapper2 = AnyLockmanBoundaryId("concurrent-equality")
    let wrapper3 = AnyLockmanBoundaryId("different-value")

    let expectation = XCTestExpectation(description: "Concurrent equality comparisons")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        XCTAssertEqual(wrapper1, wrapper2)
        XCTAssertNotEqual(wrapper1, wrapper3)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentHashOperations() {
    let wrapper = AnyLockmanBoundaryId("concurrent-hash")
    let expectation = XCTestExpectation(description: "Concurrent hash operations")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        let hash = wrapper.hashValue
        XCTAssertNotEqual(hash, 0)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - Documentation Examples Validation Tests

  func testDocumentationUsageExample() {
    // Exact example from documentation
    enum UserBoundary: String, LockmanBoundaryId {
      case profile, settings
    }

    struct SessionBoundary: LockmanBoundaryId {
      let sessionId: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(sessionId)
      }

      static func == (lhs: SessionBoundary, rhs: SessionBoundary) -> Bool {
        return lhs.sessionId == rhs.sessionId
      }
    }

    // Both can be used as keys in the same collection
    let userKey = AnyLockmanBoundaryId(UserBoundary.profile)
    let sessionKey = AnyLockmanBoundaryId(SessionBoundary(sessionId: "abc123"))

    var mixedCollection: [AnyLockmanBoundaryId: String] = [:]
    mixedCollection[userKey] = "User Profile Data"
    mixedCollection[sessionKey] = "Session Data"

    XCTAssertEqual(mixedCollection[userKey], "User Profile Data")
    XCTAssertEqual(mixedCollection[sessionKey], "Session Data")
    XCTAssertEqual(mixedCollection.count, 2)
  }

  func testCodeExampleCorrectnessVerification() {
    // Verify that the documentation examples actually work as described
    enum TestEnum: String, LockmanBoundaryId {
      case test = "test"
    }

    struct TestStruct: LockmanBoundaryId {
      let value: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(value)
      }

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        return lhs.value == rhs.value
      }
    }

    let enumWrapper = AnyLockmanBoundaryId(TestEnum.test)
    let structWrapper = AnyLockmanBoundaryId(TestStruct(value: "test"))
    let stringWrapper = AnyLockmanBoundaryId("test")

    // All different types, so should all be different
    XCTAssertNotEqual(enumWrapper, structWrapper)
    XCTAssertNotEqual(structWrapper, stringWrapper)
    XCTAssertNotEqual(enumWrapper, stringWrapper)

    // But each should be equal to itself
    XCTAssertEqual(enumWrapper, AnyLockmanBoundaryId(TestEnum.test))
    XCTAssertEqual(structWrapper, AnyLockmanBoundaryId(TestStruct(value: "test")))
    XCTAssertEqual(stringWrapper, AnyLockmanBoundaryId("test"))
  }
}
