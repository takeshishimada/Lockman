import XCTest

@testable import Lockman

/// Unit tests for LockmanGroupId
///
/// Tests the typealias protocol composition for group identifiers.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Composition Validation
/// - [ ] Hashable protocol conformance requirement
/// - [ ] Sendable protocol conformance requirement
/// - [ ] Protocol composition behavior (Hashable & Sendable)
/// - [ ] Type constraint enforcement
/// - [ ] Compilation validation with conforming types
///
/// ### Built-in Type Usage Examples
/// - [ ] String as LockmanGroupId ("navigation")
/// - [ ] Int as LockmanGroupId usage
/// - [ ] UUID as LockmanGroupId usage
/// - [ ] Basic type conformance validation
///
/// ### Custom Enum Implementation
/// - [ ] AppGroupId enum conformance example
/// - [ ] String raw value enum pattern
/// - [ ] CaseIterable enum integration
/// - [ ] Multiple case enum validation
/// - [ ] Enum equality and hashing behavior
///
/// ### Custom Struct Implementation
/// - [ ] FeatureGroupId struct conformance example
/// - [ ] Multi-property struct patterns
/// - [ ] Struct equality implementation
/// - [ ] Struct hashing implementation
/// - [ ] Complex struct validation
///
/// ### Hashable Behavior Testing
/// - [ ] Hash value consistency for same instances
/// - [ ] Hash value uniqueness for different instances
/// - [ ] Equality comparison behavior
/// - [ ] Set membership validation
/// - [ ] Dictionary key usage (if applicable)
/// - [ ] Hash collision handling
///
/// ### Sendable Behavior Testing
/// - [ ] Thread-safe concurrent access
/// - [ ] Safe passage across concurrent contexts
/// - [ ] Immutable value semantics
/// - [ ] No shared mutable state validation
/// - [ ] Concurrent Set<LockmanGroupId> usage
///
/// ### Integration with Group Coordination
/// - [ ] Group ID usage in coordination strategies
/// - [ ] Type erasure with AnyLockmanGroupId
/// - [ ] Multi-group coordination with different types
/// - [ ] Group lifecycle management
/// - [ ] Cross-group type compatibility
///
/// ### Performance & Memory
/// - [ ] Hash computation performance
/// - [ ] Equality comparison performance
/// - [ ] Memory usage with various group ID types
/// - [ ] Set performance with group IDs
/// - [ ] Large-scale group ID usage
///
/// ### Thread Safety & Concurrency
/// - [ ] Concurrent Set operations
/// - [ ] Thread-safe hash computation
/// - [ ] Race condition prevention
/// - [ ] Memory consistency across threads
/// - [ ] Concurrent group coordination
///
/// ### Real-world Group ID Patterns
/// - [ ] Feature group identification
/// - [ ] Module group coordination
/// - [ ] User role group patterns
/// - [ ] Workflow group identification
/// - [ ] Resource group management
///
/// ### Edge Cases & Error Conditions
/// - [ ] Empty string group IDs
/// - [ ] Very long string group IDs
/// - [ ] Special characters in group IDs
/// - [ ] Unicode group ID handling
/// - [ ] Hash collision scenarios
///
/// ### Documentation Examples Validation
/// - [ ] String group ID example ("navigation")
/// - [ ] AppGroupId enum example validation
/// - [ ] FeatureGroupId struct example validation
/// - [ ] Code example correctness verification
/// - [ ] Usage pattern validation from documentation
///
/// ### Type Safety Validation
/// - [ ] Compile-time type checking
/// - [ ] Runtime type safety
/// - [ ] Type constraint violation detection
/// - [ ] Generic type parameter validation
/// - [ ] Protocol composition constraint enforcement
///
final class LockmanGroupIdTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Protocol Composition Validation Tests

  func testHashableProtocolConformanceRequirement() {
    // Test that basic Hashable types work as LockmanGroupId
    func acceptsGroupId<T: LockmanGroupId>(_ id: T) -> Int {
      return id.hashValue
    }

    let stringId = "navigation"
    let intId = 100
    let uuidId = UUID()

    // Should compile and work without issues
    XCTAssertNotEqual(acceptsGroupId(stringId), 0)
    XCTAssertNotEqual(acceptsGroupId(intId), 0)
    XCTAssertNotEqual(acceptsGroupId(uuidId), 0)
  }

  func testSendableProtocolConformanceRequirement() async {
    // Test that group IDs can be safely passed across concurrent contexts
    func useGroupIdConcurrently<T: LockmanGroupId>(_ id: T) async -> T {
      return await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
          continuation.resume(returning: id)
        }
      }
    }

    let stringGroup = "concurrent-group"
    let intGroup = 456

    let result1 = await useGroupIdConcurrently(stringGroup)
    let result2 = await useGroupIdConcurrently(intGroup)

    XCTAssertEqual(result1, stringGroup)
    XCTAssertEqual(result2, intGroup)
  }

  func testProtocolCompositionBehavior() {
    // Test that the type requires both Hashable AND Sendable
    func processMultipleGroupIds<T: LockmanGroupId>(_ ids: [T]) -> Set<T> {
      return Set(ids)
    }

    let stringIds = ["group1", "group2", "group1"]
    let intIds = [10, 20, 30, 20, 10]

    let stringSet = processMultipleGroupIds(stringIds)
    let intSet = processMultipleGroupIds(intIds)

    XCTAssertEqual(stringSet.count, 2)  // group1, group2
    XCTAssertEqual(intSet.count, 3)  // 10, 20, 30
  }

  // MARK: - Built-in Type Usage Example Tests

  func testStringAsLockmanGroupId() {
    let navigationGroup = "navigation"

    XCTAssertNotNil(navigationGroup)
    XCTAssertNotEqual(navigationGroup.hashValue, 0)

    // Test usage as described in documentation
    let stringGroupId = navigationGroup
    XCTAssertEqual(stringGroupId, "navigation")

    // Test in Set
    let groupSet: Set<String> = [navigationGroup, "dataLoading", "authentication"]
    XCTAssertEqual(groupSet.count, 3)
    XCTAssertTrue(groupSet.contains(navigationGroup))
  }

  func testIntAsLockmanGroupId() {
    let intGroup = 42

    XCTAssertNotNil(intGroup)
    XCTAssertNotEqual(intGroup.hashValue, 0)

    // Test equality
    let sameGroup = 42
    let differentGroup = 43

    XCTAssertEqual(intGroup.hashValue, sameGroup.hashValue)
    XCTAssertNotEqual(intGroup.hashValue, differentGroup.hashValue)
  }

  func testUUIDAsLockmanGroupId() {
    let uuid = UUID()
    let uuidGroup = uuid

    XCTAssertNotNil(uuidGroup)
    XCTAssertNotEqual(uuidGroup.hashValue, 0)

    // Test uniqueness
    let anotherUUID = UUID()
    let anotherGroup = anotherUUID

    XCTAssertNotEqual(uuidGroup.hashValue, anotherGroup.hashValue)
  }

  // MARK: - Custom Enum Implementation Tests (Documentation Examples)

  func testAppGroupIdEnumConformanceExample() {
    enum AppGroupId: String, CaseIterable, LockmanGroupId {
      case navigation = "navigation"
      case dataLoading = "dataLoading"
      case authentication = "authentication"
    }

    let navigationGroup = AppGroupId.navigation
    let dataLoadingGroup = AppGroupId.dataLoading
    let authGroup = AppGroupId.authentication

    XCTAssertNotEqual(navigationGroup, dataLoadingGroup)
    XCTAssertNotEqual(dataLoadingGroup, authGroup)
    XCTAssertNotEqual(navigationGroup, authGroup)

    // Test all cases are different
    let allCases = AppGroupId.allCases
    let caseSet = Set(allCases)
    XCTAssertEqual(caseSet.count, allCases.count)

    // Test in Set as type-erased
    var groupSet: Set<AppGroupId> = []
    groupSet.insert(navigationGroup)
    groupSet.insert(dataLoadingGroup)
    groupSet.insert(navigationGroup)  // Should not duplicate

    XCTAssertEqual(groupSet.count, 2)
    XCTAssertTrue(groupSet.contains(navigationGroup))
    XCTAssertTrue(groupSet.contains(dataLoadingGroup))
  }

  func testStringRawValueEnumPattern() {
    enum ModuleGroup: String, LockmanGroupId {
      case userInterface = "ui"
      case businessLogic = "logic"
      case dataAccess = "data"
      case networking = "network"
    }

    let uiGroup = ModuleGroup.userInterface
    let logicGroup = ModuleGroup.businessLogic

    XCTAssertNotEqual(uiGroup, logicGroup)
    XCTAssertNotEqual(uiGroup.hashValue, logicGroup.hashValue)

    // Test raw value access
    XCTAssertEqual(uiGroup.rawValue, "ui")
    XCTAssertEqual(logicGroup.rawValue, "logic")
  }

  // MARK: - Custom Struct Implementation Tests (Documentation Examples)

  func testFeatureGroupIdStructConformanceExample() {
    struct FeatureGroupId: LockmanGroupId {
      let feature: String
      let version: Int

      func hash(into hasher: inout Hasher) {
        hasher.combine(feature)
        hasher.combine(version)
      }

      static func == (lhs: FeatureGroupId, rhs: FeatureGroupId) -> Bool {
        return lhs.feature == rhs.feature && lhs.version == rhs.version
      }
    }

    let searchV1 = FeatureGroupId(feature: "search", version: 1)
    let searchV2 = FeatureGroupId(feature: "search", version: 2)
    let searchV2Copy = FeatureGroupId(feature: "search", version: 2)
    let filterV1 = FeatureGroupId(feature: "filter", version: 1)

    // Test equality
    XCTAssertEqual(searchV2, searchV2Copy)
    XCTAssertNotEqual(searchV1, searchV2)
    XCTAssertNotEqual(searchV2, filterV1)

    // Test hashing
    XCTAssertEqual(searchV2.hashValue, searchV2Copy.hashValue)
    XCTAssertNotEqual(searchV1.hashValue, searchV2.hashValue)

    // Test as documented in source
    let structGroupId = FeatureGroupId(feature: "search", version: 2)
    XCTAssertEqual(structGroupId.feature, "search")
    XCTAssertEqual(structGroupId.version, 2)
  }

  func testMultiPropertyStructPatterns() {
    struct ComplexGroupId: LockmanGroupId {
      let module: String
      let submodule: String
      let operation: String
      let priority: Int

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(submodule)
        hasher.combine(operation)
        hasher.combine(priority)
      }

      static func == (lhs: ComplexGroupId, rhs: ComplexGroupId) -> Bool {
        return lhs.module == rhs.module && lhs.submodule == rhs.submodule
          && lhs.operation == rhs.operation && lhs.priority == rhs.priority
      }
    }

    let group1 = ComplexGroupId(
      module: "auth", submodule: "login", operation: "validate", priority: 1)
    let group2 = ComplexGroupId(
      module: "auth", submodule: "login", operation: "validate", priority: 2)
    let group1Copy = ComplexGroupId(
      module: "auth", submodule: "login", operation: "validate", priority: 1)

    XCTAssertEqual(group1, group1Copy)
    XCTAssertNotEqual(group1, group2)
    XCTAssertEqual(group1.hashValue, group1Copy.hashValue)
    XCTAssertNotEqual(group1.hashValue, group2.hashValue)
  }

  // MARK: - Hashable Behavior Testing

  func testHashValueConsistencyForSameInstances() {
    let groupId = "consistent-group"

    let hash1 = groupId.hashValue
    let hash2 = groupId.hashValue
    let hash3 = groupId.hashValue

    XCTAssertEqual(hash1, hash2)
    XCTAssertEqual(hash2, hash3)
    XCTAssertEqual(hash1, hash3)
  }

  func testHashValueUniquenessForDifferentInstances() {
    let groups = ["group1", "group2", "group3", "group4", "group5"]
    let hashes = groups.map { $0.hashValue }

    // Check that most hashes are unique (hash collisions are rare but possible)
    let uniqueHashes = Set(hashes)
    XCTAssertGreaterThanOrEqual(uniqueHashes.count, groups.count - 1)  // Allow at most one collision
  }

  func testEqualityComparisonBehavior() {
    let id1 = "same-group"
    let id2 = "same-group"
    let id3 = "different-group"

    XCTAssertEqual(id1, id2)
    XCTAssertNotEqual(id1, id3)
    XCTAssertNotEqual(id2, id3)
  }

  func testSetMembershipValidation() {
    let groupSet: Set<String> = ["navigation", "authentication", "dataLoading"]

    XCTAssertTrue(groupSet.contains("navigation"))
    XCTAssertTrue(groupSet.contains("authentication"))
    XCTAssertTrue(groupSet.contains("dataLoading"))
    XCTAssertFalse(groupSet.contains("unknown"))
  }

  // MARK: - Sendable Behavior Testing

  func testThreadSafeConcurrentAccess() async {
    let groupId = "concurrent-group"

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return groupId
    }

    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertEqual(result, groupId)
    }
  }

  func testSafePassageAcrossConcurrentContexts() {
    let groupId = "cross-context-group"
    let expectation = XCTestExpectation(description: "Cross-context passage")
    expectation.expectedFulfillmentCount = 3

    for _ in 1...3 {
      DispatchQueue.global().async {
        let localGroup = groupId
        XCTAssertEqual(localGroup, "cross-context-group")
        XCTAssertEqual(localGroup.hashValue, groupId.hashValue)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testConcurrentSetUsage() async {
    let groupIds = ["g1", "g2", "g3", "g4", "g5"]

    let results = try! await TestSupport.executeConcurrently(iterations: 5) {
      return groupIds.randomElement()!
    }

    // Should have some groups returned
    XCTAssertEqual(results.count, 5)
    results.forEach { result in
      XCTAssertTrue(groupIds.contains(result))
    }
  }

  // MARK: - Performance & Memory Tests

  func testHashComputationPerformance() {
    let groups = (0..<1000).map { "group-\($0)" }

    let executionTime = TestSupport.measureExecutionTime {
      var hashes: [Int] = []
      for group in groups {
        hashes.append(group.hashValue)
      }
    }

    XCTAssertLessThan(executionTime, 0.1)  // Should complete in less than 0.1 seconds
  }

  func testEqualityComparisonPerformance() {
    let group1 = "performance-test-group"
    let group2 = "performance-test-group"
    let group3 = "different-group"

    let executionTime = TestSupport.measureExecutionTime {
      for _ in 0..<10000 {
        let _ = group1 == group2
        let _ = group1 == group3
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  func testSetPerformanceWithGroupIds() {
    let groups = (0..<1000).map { "group-\($0)" }

    let executionTime = TestSupport.measureExecutionTime {
      var groupSet: Set<String> = []

      for group in groups {
        groupSet.insert(group)
      }
    }

    XCTAssertLessThan(executionTime, 0.1)
  }

  // MARK: - Thread Safety & Concurrency Tests

  func testConcurrentSetOperations() {
    let initialGroups: Set<String> = ["initial1", "initial2", "initial3"]
    let additionalGroups = ["additional1", "additional2", "additional3"]

    let expectation = XCTestExpectation(description: "Concurrent set operations")
    expectation.expectedFulfillmentCount = 6

    for group in additionalGroups {
      DispatchQueue.global().async {
        XCTAssertFalse(initialGroups.contains(group))
        expectation.fulfill()
      }
    }

    for group in initialGroups {
      DispatchQueue.global().async {
        XCTAssertTrue(initialGroups.contains(group))
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testThreadSafeHashComputation() {
    let groupId = "thread-safe-group"
    let expectation = XCTestExpectation(description: "Thread-safe hash computation")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let hash = groupId.hashValue
        XCTAssertNotEqual(hash, 0)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - Real-world Group ID Pattern Tests

  func testFeatureGroupIdentification() {
    enum FeatureGroup: String, LockmanGroupId {
      case authentication = "auth"
      case userProfile = "profile"
      case contentManagement = "content"
      case analytics = "analytics"
      case notifications = "notifications"
    }

    let authGroup = FeatureGroup.authentication
    let profileGroup = FeatureGroup.userProfile

    XCTAssertNotEqual(authGroup, profileGroup)

    // Test feature isolation
    var featureStates: [FeatureGroup: Bool] = [:]
    featureStates[.authentication] = true
    featureStates[.userProfile] = false
    featureStates[.contentManagement] = true

    XCTAssertEqual(featureStates[.authentication], true)
    XCTAssertEqual(featureStates[.userProfile], false)
    XCTAssertEqual(featureStates[.contentManagement], true)
    XCTAssertNil(featureStates[.analytics])
  }

  func testModuleGroupCoordination() {
    struct ModuleGroupId: LockmanGroupId {
      let module: String
      let layer: String

      init(_ module: String, layer: String) {
        self.module = module
        self.layer = layer
      }

      func hash(into hasher: inout Hasher) {
        hasher.combine(module)
        hasher.combine(layer)
      }

      static func == (lhs: ModuleGroupId, rhs: ModuleGroupId) -> Bool {
        return lhs.module == rhs.module && lhs.layer == rhs.layer
      }
    }

    let uiLayer = ModuleGroupId("user", layer: "ui")
    let logicLayer = ModuleGroupId("user", layer: "logic")
    let dataLayer = ModuleGroupId("user", layer: "data")

    XCTAssertNotEqual(uiLayer, logicLayer)
    XCTAssertNotEqual(logicLayer, dataLayer)
    XCTAssertNotEqual(uiLayer, dataLayer)

    // Test module coordination
    var moduleCoordination: [ModuleGroupId: String] = [:]
    moduleCoordination[uiLayer] = "UI Operations"
    moduleCoordination[logicLayer] = "Business Logic"
    moduleCoordination[dataLayer] = "Data Access"

    XCTAssertEqual(moduleCoordination[uiLayer], "UI Operations")
    XCTAssertEqual(moduleCoordination[logicLayer], "Business Logic")
    XCTAssertEqual(moduleCoordination[dataLayer], "Data Access")
  }

  func testUserRoleGroupPatterns() {
    enum UserRoleGroup: Int, LockmanGroupId {
      case guest = 0
      case member = 1
      case moderator = 2
      case admin = 3
      case superAdmin = 4
    }

    let guestGroup = UserRoleGroup.guest
    let adminGroup = UserRoleGroup.admin

    XCTAssertNotEqual(guestGroup, adminGroup)
    XCTAssertLessThan(guestGroup.rawValue, adminGroup.rawValue)

    // Test role hierarchy
    let roleGroups: [UserRoleGroup] = [.guest, .member, .moderator, .admin, .superAdmin]
    let sortedGroups = roleGroups.sorted { $0.rawValue < $1.rawValue }

    XCTAssertEqual(roleGroups, sortedGroups)
  }

  func testWorkflowGroupIdentification() {
    struct WorkflowGroupId: LockmanGroupId {
      let workflow: String
      let stage: String
      let priority: Int

      func hash(into hasher: inout Hasher) {
        hasher.combine(workflow)
        hasher.combine(stage)
        hasher.combine(priority)
      }

      static func == (lhs: WorkflowGroupId, rhs: WorkflowGroupId) -> Bool {
        return lhs.workflow == rhs.workflow && lhs.stage == rhs.stage
          && lhs.priority == rhs.priority
      }
    }

    let onboardingInit = WorkflowGroupId(workflow: "onboarding", stage: "init", priority: 1)
    let onboardingValidation = WorkflowGroupId(
      workflow: "onboarding", stage: "validation", priority: 2)
    let checkoutPayment = WorkflowGroupId(workflow: "checkout", stage: "payment", priority: 1)

    XCTAssertNotEqual(onboardingInit, onboardingValidation)
    XCTAssertNotEqual(onboardingInit, checkoutPayment)
    XCTAssertNotEqual(onboardingValidation, checkoutPayment)

    // Test workflow coordination
    var workflowGroups: Set<WorkflowGroupId> = []
    workflowGroups.insert(onboardingInit)
    workflowGroups.insert(onboardingValidation)
    workflowGroups.insert(checkoutPayment)

    XCTAssertEqual(workflowGroups.count, 3)
    XCTAssertTrue(workflowGroups.contains(onboardingInit))
    XCTAssertTrue(workflowGroups.contains(onboardingValidation))
    XCTAssertTrue(workflowGroups.contains(checkoutPayment))
  }

  // MARK: - Edge Cases & Error Conditions Tests

  func testEmptyStringGroupIds() {
    let emptyGroup = ""

    XCTAssertNotNil(emptyGroup)
    // Empty string should still have a valid hash
    XCTAssertNotEqual(emptyGroup.hashValue, 0)

    // Should work in collections
    let groupSet: Set<String> = ["", "non-empty"]
    XCTAssertEqual(groupSet.count, 2)
    XCTAssertTrue(groupSet.contains(""))
  }

  func testVeryLongStringGroupIds() {
    let longGroup = String(repeating: "VeryLongGroupId", count: 100)

    XCTAssertNotNil(longGroup)
    XCTAssertNotEqual(longGroup.hashValue, 0)

    // Should work in Set
    var groupSet: Set<String> = []
    groupSet.insert(longGroup)

    XCTAssertEqual(groupSet.count, 1)
    XCTAssertTrue(groupSet.contains(longGroup))
  }

  func testSpecialCharactersInGroupIds() {
    let specialGroup = "group@#$%^&*(){}[]!<>?.,;:'\"|\\`~"

    XCTAssertNotNil(specialGroup)
    XCTAssertNotEqual(specialGroup.hashValue, 0)

    // Should work as Set member
    let groupSet: Set<String> = [specialGroup, "normal"]
    XCTAssertEqual(groupSet.count, 2)
    XCTAssertTrue(groupSet.contains(specialGroup))
  }

  func testUnicodeGroupIdHandling() {
    let unicodeGroup = "グループ_مجموعة_группа_🎯"

    XCTAssertNotNil(unicodeGroup)
    XCTAssertNotEqual(unicodeGroup.hashValue, 0)

    // Should work in set
    let unicodeSet: Set<String> = [unicodeGroup, "english", "日本語"]
    XCTAssertEqual(unicodeSet.count, 3)
    XCTAssertTrue(unicodeSet.contains(unicodeGroup))
  }

  // MARK: - Documentation Examples Validation Tests

  func testDocumentationStringExample() {
    // Test exact example from documentation
    let stringGroupId = "navigation"

    XCTAssertEqual(stringGroupId, "navigation")
    XCTAssertNotNil(stringGroupId)
    XCTAssertNotEqual(stringGroupId.hashValue, 0)
  }

  func testDocumentationEnumExample() {
    // Test exact enum from documentation
    enum AppGroupId: String, LockmanGroupId {
      case navigation
      case dataLoading
      case authentication
    }

    let enumGroupId = AppGroupId.navigation

    XCTAssertEqual(enumGroupId, AppGroupId.navigation)
    XCTAssertNotEqual(enumGroupId, AppGroupId.dataLoading)
    XCTAssertNotEqual(enumGroupId, AppGroupId.authentication)
  }

  func testDocumentationStructExample() {
    // Test exact struct from documentation
    struct FeatureGroupId: LockmanGroupId {
      let feature: String
      let version: Int

      func hash(into hasher: inout Hasher) {
        hasher.combine(feature)
        hasher.combine(version)
      }

      static func == (lhs: FeatureGroupId, rhs: FeatureGroupId) -> Bool {
        return lhs.feature == rhs.feature && lhs.version == rhs.version
      }
    }

    let structGroupId = FeatureGroupId(feature: "search", version: 2)

    XCTAssertEqual(structGroupId.feature, "search")
    XCTAssertEqual(structGroupId.version, 2)

    let anotherStructGroupId = FeatureGroupId(feature: "search", version: 2)
    XCTAssertEqual(structGroupId, anotherStructGroupId)
  }

  // MARK: - Type Safety Validation Tests

  func testCompileTimeTypeChecking() {
    // These should compile without issues
    func acceptsHashableSendable<T: Hashable & Sendable>(_ value: T) -> T {
      return value
    }

    func acceptsLockmanGroupId<T: LockmanGroupId>(_ value: T) -> T {
      return value
    }

    let stringValue = "test"
    let intValue = 42
    let uuidValue = UUID()

    // Both functions should accept the same types
    XCTAssertEqual(acceptsHashableSendable(stringValue), acceptsLockmanGroupId(stringValue))
    XCTAssertEqual(acceptsHashableSendable(intValue), acceptsLockmanGroupId(intValue))
    XCTAssertEqual(acceptsHashableSendable(uuidValue), acceptsLockmanGroupId(uuidValue))
  }

  func testGenericTypeParameterValidation() {
    func processMultipleGroups<T: LockmanGroupId>(_ groups: [T]) -> [Int] {
      return groups.map { $0.hashValue }
    }

    let stringGroups = ["g1", "g2", "g3"]
    let intGroups = [1, 2, 3]

    let stringHashes = processMultipleGroups(stringGroups)
    let intHashes = processMultipleGroups(intGroups)

    XCTAssertEqual(stringHashes.count, 3)
    XCTAssertEqual(intHashes.count, 3)

    // Hashes should be non-zero
    stringHashes.forEach { XCTAssertNotEqual($0, 0) }
    intHashes.forEach { XCTAssertNotEqual($0, 0) }
  }
}
