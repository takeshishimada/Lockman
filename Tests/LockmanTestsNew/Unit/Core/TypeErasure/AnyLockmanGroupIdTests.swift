import XCTest

@testable import Lockman

/// Unit tests for AnyLockmanGroupId
///
/// Tests the type-erased wrapper for heterogeneous group identifiers.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Type Erasure Implementation
/// - [ ] AnyHashable-based storage validation
/// - [ ] Type erasure wrapper construction
/// - [ ] init(_ value: any LockmanGroupId) functionality
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
/// - [ ] Concurrent Set operations safety
///
/// ### CustomDebugStringConvertible Implementation
/// - [ ] debugDescription format ("AnyLockmanGroupId(base)")
/// - [ ] Debug output readability
/// - [ ] Wrapped value representation
/// - [ ] Debug string consistency
/// - [ ] Complex type debug representation
///
/// ### Heterogeneous Storage Testing
/// - [ ] Set<AnyLockmanGroupId> with mixed types
/// - [ ] Dictionary values with AnyLockmanGroupId keys
/// - [ ] Collection operations with mixed group types
/// - [ ] Type safety with heterogeneous storage
/// - [ ] Performance with mixed type collections
///
/// ### Built-in Type Wrapping
/// - [ ] String group ID wrapping
/// - [ ] Int group ID wrapping
/// - [ ] UUID group ID wrapping
/// - [ ] Enum group ID wrapping
/// - [ ] Struct group ID wrapping
///
/// ### Custom Type Integration
/// - [ ] FeatureGroup enum example validation
/// - [ ] ModuleGroup struct example validation
/// - [ ] Complex custom type wrapping
/// - [ ] Multi-property struct handling
/// - [ ] Custom equality behavior preservation
///
/// ### Equality and Hashing Behavior
/// - [ ] Same type, same value equality
/// - [ ] Same type, different value inequality
/// - [ ] Different type, same value inequality
/// - [ ] Hash consistency for equal instances
/// - [ ] Hash uniqueness for different instances
/// - [ ] Set membership validation
///
/// ### Performance & Memory
/// - [ ] Wrapping overhead measurement
/// - [ ] Memory footprint with AnyHashable
/// - [ ] Hash computation performance
/// - [ ] Equality comparison performance
/// - [ ] Large-scale type erasure usage
/// - [ ] Debug string generation performance
///
/// ### Thread Safety & Concurrency
/// - [ ] Concurrent wrapper creation
/// - [ ] Concurrent Set operations
/// - [ ] Concurrent equality comparisons
/// - [ ] Thread-safe hash operations
/// - [ ] Race condition prevention
///
/// ### Integration with Group Coordination
/// - [ ] Multi-group coordination with mixed types
/// - [ ] Group strategy with type-erased IDs
/// - [ ] Cross-group type compatibility
/// - [ ] Group lifecycle with heterogeneous IDs
/// - [ ] Group state management with type erasure
///
/// ### Real-world Usage Patterns
/// - [ ] Multi-module group coordination
/// - [ ] Feature-based group management
/// - [ ] Dynamic group type handling
/// - [ ] Plugin-based group systems
/// - [ ] Framework-level group abstraction
///
/// ### Edge Cases & Error Conditions
/// - [ ] Wrapping nil-equivalent values (if possible)
/// - [ ] Very large group ID values
/// - [ ] Complex nested group structures
/// - [ ] Memory pressure with many wrapped instances
/// - [ ] Type information preservation edge cases
///
/// ### Documentation Examples Validation
/// - [ ] FeatureGroup enum example
/// - [ ] ModuleGroup struct example
/// - [ ] Mixed Set<AnyLockmanGroupId> example
/// - [ ] Code example correctness verification
/// - [ ] Usage pattern validation from documentation
///
/// ### Debug Support Validation
/// - [ ] Debug description format consistency
/// - [ ] Wrapped value visibility in debug output
/// - [ ] Complex type debug representation
/// - [ ] Debug string parsing validation
///
final class AnyLockmanGroupIdTests: XCTestCase {

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
    let stringGroup = "feature-group"
    let anyGroup = AnyLockmanGroupId(stringGroup)

    XCTAssertNotNil(anyGroup)
    // The wrapper should preserve the original value's behavior
    XCTAssertEqual(anyGroup.hashValue, stringGroup.hashValue)
  }

  func testTypeErasureWrapperConstruction() {
    let stringId = "navigation"
    let intId = 42
    let uuidId = UUID()

    let stringWrapper = AnyLockmanGroupId(stringId)
    let intWrapper = AnyLockmanGroupId(intId)
    let uuidWrapper = AnyLockmanGroupId(uuidId)

    XCTAssertNotNil(stringWrapper)
    XCTAssertNotNil(intWrapper)
    XCTAssertNotNil(uuidWrapper)
  }

  func testInitWithAnyLockmanGroupIdFunctionality() {
    func testInitWithValue<T: LockmanGroupId>(_ value: T) -> AnyLockmanGroupId {
      return AnyLockmanGroupId(value)
    }

    let stringResult = testInitWithValue("test-group")
    let intResult = testInitWithValue(456)
    let uuidResult = testInitWithValue(UUID())

    XCTAssertNotNil(stringResult)
    XCTAssertNotNil(intResult)
    XCTAssertNotNil(uuidResult)
  }

  func testValueSemanticsPreservation() {
    let originalValue = "group-value"
    let wrapper1 = AnyLockmanGroupId(originalValue)
    let wrapper2 = AnyLockmanGroupId(originalValue)

    // Value semantics: same input should create equal wrappers
    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  // MARK: - Hashable Implementation Tests

  func testEqualityComparisonThroughAnyHashable() {
    let value1 = "same-group"
    let value2 = "same-group"
    let value3 = "different-group"

    let wrapper1 = AnyLockmanGroupId(value1)
    let wrapper2 = AnyLockmanGroupId(value2)
    let wrapper3 = AnyLockmanGroupId(value3)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertNotEqual(wrapper1, wrapper3)
    XCTAssertNotEqual(wrapper2, wrapper3)
  }

  func testHashValueGenerationThroughBase() {
    let stringValue = "hash-test-group"
    let wrapper = AnyLockmanGroupId(stringValue)

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

    let stringWrapper = AnyLockmanGroupId(stringValue)
    let intWrapper = AnyLockmanGroupId(intValue)

    XCTAssertNotEqual(stringWrapper, intWrapper)
    // Different types should likely have different hashes (though not guaranteed)
    XCTAssertNotEqual(stringWrapper.hashValue, intWrapper.hashValue)
  }

  func testHashCollisionPreventionWithTypeInformation() {
    struct CustomGroup1: LockmanGroupId {
      let value: String
      func hash(into hasher: inout Hasher) { hasher.combine(value) }
      static func == (lhs: CustomGroup1, rhs: CustomGroup1) -> Bool { lhs.value == rhs.value }
    }

    struct CustomGroup2: LockmanGroupId {
      let value: String
      func hash(into hasher: inout Hasher) { hasher.combine(value) }
      static func == (lhs: CustomGroup2, rhs: CustomGroup2) -> Bool { lhs.value == rhs.value }
    }

    let group1 = AnyLockmanGroupId(CustomGroup1(value: "test"))
    let group2 = AnyLockmanGroupId(CustomGroup2(value: "test"))

    // Different types with same value should not be equal
    XCTAssertNotEqual(group1, group2)
  }

  func testConsistentHashingBehavior() {
    let groups = ["group1", "group2", "group3"]
    let wrappers = groups.map { AnyLockmanGroupId($0) }

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
    let group = AnyLockmanGroupId("concurrent-group")

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return group
    }

    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertEqual(result, group)
    }
  }

  func testSafeConcurrentAccessValidation() {
    let group = AnyLockmanGroupId("thread-safe-group")
    let expectation = XCTestExpectation(description: "Safe concurrent access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let hash = group.hashValue
        let equalityCheck = group == group

        XCTAssertNotEqual(hash, 0)
        XCTAssertTrue(equalityCheck)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentSetOperationsSafety() async {
    let groups = ["g1", "g2", "g3", "g4", "g5"]
    let wrappers = groups.map { AnyLockmanGroupId($0) }

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return wrappers.randomElement()!
    }

    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertTrue(wrappers.contains(result))
    }
  }

  // MARK: - CustomDebugStringConvertible Tests

  func testDebugDescriptionFormat() {
    let stringGroup = "debug-group"
    let wrapper = AnyLockmanGroupId(stringGroup)

    let debugDescription = wrapper.debugDescription
    XCTAssertTrue(debugDescription.hasPrefix("AnyLockmanGroupId("))
    XCTAssertTrue(debugDescription.hasSuffix(")"))
    XCTAssertTrue(debugDescription.contains(stringGroup))
  }

  func testDebugOutputReadability() {
    let intGroup = 123
    let wrapper = AnyLockmanGroupId(intGroup)

    let debugDescription = wrapper.debugDescription
    XCTAssertTrue(debugDescription.contains("123"))
    XCTAssertTrue(debugDescription.contains("AnyLockmanGroupId"))
  }

  func testWrappedValueRepresentation() {
    enum TestGroup: String, LockmanGroupId {
      case testCase = "test-case"
    }

    let enumWrapper = AnyLockmanGroupId(TestGroup.testCase)
    let debugDescription = enumWrapper.debugDescription

    XCTAssertTrue(debugDescription.contains("AnyLockmanGroupId"))
    XCTAssertTrue(debugDescription.contains("testCase") || debugDescription.contains("test-case"))
  }

  func testComplexTypeDebugRepresentation() {
    struct ComplexGroup: LockmanGroupId {
      let module: String
      let feature: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(feature)
      }

      static func == (lhs: ComplexGroup, rhs: ComplexGroup) -> Bool {
        return lhs.module == rhs.module && lhs.feature == rhs.feature
      }
    }

    let complexGroup = ComplexGroup(module: "auth", feature: "login")
    let wrapper = AnyLockmanGroupId(complexGroup)
    let debugDescription = wrapper.debugDescription

    XCTAssertTrue(debugDescription.contains("AnyLockmanGroupId"))
    XCTAssertNotEqual(debugDescription, "AnyLockmanGroupId()")
  }

  // MARK: - Heterogeneous Storage Testing

  func testSetWithMixedGroupTypes() {
    let stringGroup = AnyLockmanGroupId("string-group")
    let intGroup = AnyLockmanGroupId(200)
    let stringGroupCopy = AnyLockmanGroupId("string-group")

    let groupSet: Set<AnyLockmanGroupId> = [stringGroup, intGroup, stringGroupCopy]

    XCTAssertEqual(groupSet.count, 2)  // stringGroup and stringGroupCopy are same
    XCTAssertTrue(groupSet.contains(stringGroup))
    XCTAssertTrue(groupSet.contains(intGroup))
    XCTAssertTrue(groupSet.contains(stringGroupCopy))
  }

  func testMixedGroupIdTypesInSameCollection() {
    enum FeatureGroup: String, LockmanGroupId {
      case navigation = "navigation"
      case dataSync = "dataSync"
    }

    struct ModuleGroup: LockmanGroupId {
      let module: String
      let submodule: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(submodule)
      }

      static func == (lhs: ModuleGroup, rhs: ModuleGroup) -> Bool {
        return lhs.module == rhs.module && lhs.submodule == rhs.submodule
      }
    }

    let featureGroup = AnyLockmanGroupId(FeatureGroup.navigation)
    let moduleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "profile"))
    let stringGroup = AnyLockmanGroupId("simple-string")

    var mixedGroups: Set<AnyLockmanGroupId> = []
    mixedGroups.insert(featureGroup)
    mixedGroups.insert(moduleGroup)
    mixedGroups.insert(stringGroup)

    XCTAssertEqual(mixedGroups.count, 3)
    XCTAssertTrue(mixedGroups.contains(featureGroup))
    XCTAssertTrue(mixedGroups.contains(moduleGroup))
    XCTAssertTrue(mixedGroups.contains(stringGroup))
  }

  func testTypeSafetyWithHeterogeneousStorage() {
    let stringGroup1 = AnyLockmanGroupId("test")
    let stringGroup2 = AnyLockmanGroupId("test")
    let intGroup = AnyLockmanGroupId(42)

    // Same type, same value should be equal
    XCTAssertEqual(stringGroup1, stringGroup2)

    // Different types should not be equal
    XCTAssertNotEqual(stringGroup1, intGroup)
    XCTAssertNotEqual(stringGroup2, intGroup)
  }

  // MARK: - Built-in Type Wrapping Tests

  func testStringGroupIdWrapping() {
    let stringValue = "string-group-test"
    let wrapper = AnyLockmanGroupId(stringValue)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanGroupId(stringValue)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testIntGroupIdWrapping() {
    let intValue = 54321
    let wrapper = AnyLockmanGroupId(intValue)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanGroupId(intValue)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testUUIDGroupIdWrapping() {
    let uuid = UUID()
    let wrapper = AnyLockmanGroupId(uuid)

    XCTAssertNotNil(wrapper)
    XCTAssertNotEqual(wrapper.hashValue, 0)

    let anotherWrapper = AnyLockmanGroupId(uuid)
    XCTAssertEqual(wrapper, anotherWrapper)
  }

  func testEnumGroupIdWrapping() {
    enum TestGroup: String, LockmanGroupId {
      case first = "first"
      case second = "second"
    }

    let enumWrapper1 = AnyLockmanGroupId(TestGroup.first)
    let enumWrapper2 = AnyLockmanGroupId(TestGroup.second)
    let enumWrapper1Copy = AnyLockmanGroupId(TestGroup.first)

    XCTAssertEqual(enumWrapper1, enumWrapper1Copy)
    XCTAssertNotEqual(enumWrapper1, enumWrapper2)
  }

  func testStructGroupIdWrapping() {
    struct CustomGroup: LockmanGroupId {
      let id: String
      let category: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(category)
      }

      static func == (lhs: CustomGroup, rhs: CustomGroup) -> Bool {
        return lhs.id == rhs.id && lhs.category == rhs.category
      }
    }

    let struct1 = CustomGroup(id: "test", category: "A")
    let struct2 = CustomGroup(id: "test", category: "B")
    let struct1Copy = CustomGroup(id: "test", category: "A")

    let wrapper1 = AnyLockmanGroupId(struct1)
    let wrapper2 = AnyLockmanGroupId(struct2)
    let wrapper1Copy = AnyLockmanGroupId(struct1Copy)

    XCTAssertEqual(wrapper1, wrapper1Copy)
    XCTAssertNotEqual(wrapper1, wrapper2)
  }

  // MARK: - Custom Type Integration Tests

  func testFeatureGroupEnumExampleValidation() {
    // From documentation example
    enum FeatureGroup: String, LockmanGroupId {
      case navigation = "navigation"
      case dataSync = "dataSync"
      case authentication = "authentication"
    }

    let featureGroup = AnyLockmanGroupId(FeatureGroup.navigation)
    let anotherFeatureGroup = AnyLockmanGroupId(FeatureGroup.navigation)
    let dataSyncGroup = AnyLockmanGroupId(FeatureGroup.dataSync)

    XCTAssertEqual(featureGroup, anotherFeatureGroup)
    XCTAssertNotEqual(featureGroup, dataSyncGroup)
  }

  func testModuleGroupStructExampleValidation() {
    // From documentation example
    struct ModuleGroup: LockmanGroupId {
      let module: String
      let submodule: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(submodule)
      }

      static func == (lhs: ModuleGroup, rhs: ModuleGroup) -> Bool {
        return lhs.module == rhs.module && lhs.submodule == rhs.submodule
      }
    }

    let moduleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "profile"))
    let anotherModuleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "profile"))
    let differentModuleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "settings"))

    XCTAssertEqual(moduleGroup, anotherModuleGroup)
    XCTAssertNotEqual(moduleGroup, differentModuleGroup)
  }

  func testComplexCustomTypeWrapping() {
    struct ComplexGroup: LockmanGroupId {
      let domain: String
      let feature: String
      let version: Int
      let metadata: [String: String]

      func hash(into hasher: inout Hasher) {
        hasher.combine(domain)
        hasher.combine(feature)
        hasher.combine(version)
        hasher.combine(metadata.keys.sorted())
        hasher.combine(metadata.values.sorted())
      }

      static func == (lhs: ComplexGroup, rhs: ComplexGroup) -> Bool {
        return lhs.domain == rhs.domain && lhs.feature == rhs.feature && lhs.version == rhs.version
          && lhs.metadata == rhs.metadata
      }
    }

    let complex1 = ComplexGroup(
      domain: "user",
      feature: "authentication",
      version: 1,
      metadata: ["env": "prod", "region": "us"]
    )
    let complex2 = ComplexGroup(
      domain: "user",
      feature: "authentication",
      version: 1,
      metadata: ["env": "prod", "region": "us"]
    )
    let complex3 = ComplexGroup(
      domain: "user",
      feature: "authentication",
      version: 2,
      metadata: ["env": "prod", "region": "us"]
    )

    let wrapper1 = AnyLockmanGroupId(complex1)
    let wrapper2 = AnyLockmanGroupId(complex2)
    let wrapper3 = AnyLockmanGroupId(complex3)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertNotEqual(wrapper1, wrapper3)
  }

  // MARK: - Equality and Hashing Behavior Tests

  func testSameTypeSameValueEquality() {
    let value = "equality-test-group"
    let wrapper1 = AnyLockmanGroupId(value)
    let wrapper2 = AnyLockmanGroupId(value)

    XCTAssertEqual(wrapper1, wrapper2)
    XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  func testSameTypeDifferentValueInequality() {
    let value1 = "group1"
    let value2 = "group2"
    let wrapper1 = AnyLockmanGroupId(value1)
    let wrapper2 = AnyLockmanGroupId(value2)

    XCTAssertNotEqual(wrapper1, wrapper2)
    // Different values should likely have different hashes (not guaranteed but expected)
    XCTAssertNotEqual(wrapper1.hashValue, wrapper2.hashValue)
  }

  func testDifferentTypeSameValueInequality() {
    let stringValue = "123"
    let intValue = 123
    let stringWrapper = AnyLockmanGroupId(stringValue)
    let intWrapper = AnyLockmanGroupId(intValue)

    XCTAssertNotEqual(stringWrapper, intWrapper)
  }

  func testHashConsistencyForEqualInstances() {
    let groups = ["test1", "test2", "test3"]

    for group in groups {
      let wrapper1 = AnyLockmanGroupId(group)
      let wrapper2 = AnyLockmanGroupId(group)

      XCTAssertEqual(wrapper1, wrapper2)
      XCTAssertEqual(wrapper1.hashValue, wrapper2.hashValue)
    }
  }

  func testSetMembershipValidation() {
    let group1 = AnyLockmanGroupId("group1")
    let group2 = AnyLockmanGroupId("group2")
    let group3 = AnyLockmanGroupId("group3")

    let groupSet: Set<AnyLockmanGroupId> = [group1, group2, group3]

    XCTAssertTrue(groupSet.contains(group1))
    XCTAssertTrue(groupSet.contains(group2))
    XCTAssertTrue(groupSet.contains(group3))

    let nonExistentGroup = AnyLockmanGroupId("non-existent")
    XCTAssertFalse(groupSet.contains(nonExistentGroup))
  }

  // MARK: - Performance & Memory Tests

  func testWrappingOverheadMeasurement() {
    let values = (0..<1000).map { "group-\($0)" }

    let executionTime = TestSupport.measureExecutionTime {
      var wrappers: [AnyLockmanGroupId] = []
      for value in values {
        wrappers.append(AnyLockmanGroupId(value))
      }
    }

    XCTAssertLessThan(executionTime, 0.1)  // Should be fast
  }

  func testHashComputationPerformance() {
    let wrappers = (0..<1000).map { AnyLockmanGroupId("group-\($0)") }

    let executionTime = TestSupport.measureExecutionTime {
      var hashes: [Int] = []
      for wrapper in wrappers {
        hashes.append(wrapper.hashValue)
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  func testEqualityComparisonPerformance() {
    let wrapper1 = AnyLockmanGroupId("performance-test-group")
    let wrapper2 = AnyLockmanGroupId("performance-test-group")
    let wrapper3 = AnyLockmanGroupId("different-group")

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<10000 {
        let _ = wrapper1 == wrapper2
        let _ = wrapper1 == wrapper3
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  func testDebugStringGenerationPerformance() {
    let wrapper = AnyLockmanGroupId("debug-performance-test")

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<1000 {
        let _ = wrapper.debugDescription
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
        let wrapper = AnyLockmanGroupId(randomValue)
        XCTAssertNotNil(wrapper)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentSetOperations() {
    let group1 = AnyLockmanGroupId("concurrent-group-1")
    let group2 = AnyLockmanGroupId("concurrent-group-2")
    let group3 = AnyLockmanGroupId("concurrent-group-3")

    let groupSet: Set<AnyLockmanGroupId> = [group1, group2, group3]
    let expectation = XCTestExpectation(description: "Concurrent set operations")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        XCTAssertTrue(groupSet.contains(group1))
        XCTAssertTrue(groupSet.contains(group2))
        XCTAssertTrue(groupSet.contains(group3))
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentEqualityComparisons() {
    let wrapper1 = AnyLockmanGroupId("concurrent-equality")
    let wrapper2 = AnyLockmanGroupId("concurrent-equality")
    let wrapper3 = AnyLockmanGroupId("different-value")

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

  func testThreadSafeHashOperations() {
    let wrapper = AnyLockmanGroupId("concurrent-hash-group")
    let expectation = XCTestExpectation(description: "Thread-safe hash operations")
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
    enum FeatureGroup: String, LockmanGroupId {
      case navigation, dataSync, authentication
    }

    struct ModuleGroup: LockmanGroupId {
      let module: String
      let submodule: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(submodule)
      }

      static func == (lhs: ModuleGroup, rhs: ModuleGroup) -> Bool {
        return lhs.module == rhs.module && lhs.submodule == rhs.submodule
      }
    }

    // Both can be used as group IDs in the same collection
    let featureGroup = AnyLockmanGroupId(FeatureGroup.navigation)
    let moduleGroup = AnyLockmanGroupId(ModuleGroup(module: "user", submodule: "profile"))

    // Can be stored in the same Set
    let groupIds: Set<AnyLockmanGroupId> = [featureGroup, moduleGroup]

    XCTAssertEqual(groupIds.count, 2)
    XCTAssertTrue(groupIds.contains(featureGroup))
    XCTAssertTrue(groupIds.contains(moduleGroup))
  }

  func testCodeExampleCorrectnessVerification() {
    // Verify that the documentation examples actually work as described
    enum TestEnum: String, LockmanGroupId {
      case test = "test"
    }

    struct TestStruct: LockmanGroupId {
      let value: String

      func hash(into hasher: inout Hasher) {
        hasher.combine(value)
      }

      static func == (lhs: TestStruct, rhs: TestStruct) -> Bool {
        return lhs.value == rhs.value
      }
    }

    let enumWrapper = AnyLockmanGroupId(TestEnum.test)
    let structWrapper = AnyLockmanGroupId(TestStruct(value: "test"))
    let stringWrapper = AnyLockmanGroupId("test")

    // All different types, so should all be different
    XCTAssertNotEqual(enumWrapper, structWrapper)
    XCTAssertNotEqual(structWrapper, stringWrapper)
    XCTAssertNotEqual(enumWrapper, stringWrapper)

    // But each should be equal to itself
    XCTAssertEqual(enumWrapper, AnyLockmanGroupId(TestEnum.test))
    XCTAssertEqual(structWrapper, AnyLockmanGroupId(TestStruct(value: "test")))
    XCTAssertEqual(stringWrapper, AnyLockmanGroupId("test"))
  }

  // MARK: - Debug Support Validation Tests

  func testDebugDescriptionFormatConsistency() {
    let values = ["test1", "test2", "test3"]

    for value in values {
      let wrapper = AnyLockmanGroupId(value)
      let debug = wrapper.debugDescription

      XCTAssertTrue(debug.hasPrefix("AnyLockmanGroupId("))
      XCTAssertTrue(debug.hasSuffix(")"))
    }
  }

  func testWrappedValueVisibilityInDebugOutput() {
    let wrapper = AnyLockmanGroupId(42)
    let debug = wrapper.debugDescription

    XCTAssertTrue(debug.contains("42"))
    XCTAssertTrue(debug.contains("AnyLockmanGroupId"))
  }
}
