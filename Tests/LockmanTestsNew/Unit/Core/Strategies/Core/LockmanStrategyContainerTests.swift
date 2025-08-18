import XCTest

@testable import Lockman

/// Unit tests for LockmanStrategyContainer
///
/// Tests the thread-safe, Sendable dependency injection container for registering and resolving
/// lock strategies using type erasure and flexible identifiers.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Container Initialization
/// - [ ] Empty container creation and initial state
/// - [ ] Storage is properly initialized with empty dictionary
/// - [ ] Thread-safe initialization from multiple threads
/// - [ ] Container state after initialization
///
/// ### Strategy Registration - Single Strategy
/// - [ ] register(id:strategy:) with unique LockmanStrategyId
/// - [ ] register(_:) using strategy's own strategyId
/// - [ ] StrategyEntry creation with correct metadata (strategy, typeName, registeredAt)
/// - [ ] AnyLockmanStrategy wrapper creation and storage
/// - [ ] Registration timestamp accuracy and consistency
/// - [ ] Thread-safe concurrent registration from multiple threads
///
/// ### Strategy Registration - Error Conditions
/// - [ ] LockmanRegistrationError.strategyAlreadyRegistered on duplicate ID registration
/// - [ ] Exact error message format for already registered strategies
/// - [ ] Registration failure doesn't modify container state
/// - [ ] Error thrown when registering same ID twice
/// - [ ] Error thrown when registering same strategy instance twice
///
/// ### Bulk Strategy Registration
/// - [ ] registerAll([(LockmanStrategyId, S)]) atomic operation success
/// - [ ] registerAll([S]) using strategies' own strategyIds
/// - [ ] All-or-nothing semantics: all succeed or none registered
/// - [ ] Duplicate ID detection within input array
/// - [ ] Conflict detection with existing registrations
/// - [ ] Atomic rollback when any strategy conflicts
/// - [ ] Pre-validation of all strategies before registration
/// - [ ] Thread-safe bulk registration operations
///
/// ### Strategy Resolution by ID
/// - [ ] resolve(id:expecting:) returns correct AnyLockmanStrategy<I>
/// - [ ] Type inference works correctly with expecting parameter
/// - [ ] Successful resolution preserves original strategy behavior
/// - [ ] LockmanRegistrationError.strategyNotRegistered for unregistered ID
/// - [ ] Correct error message format for unregistered strategy
/// - [ ] Thread-safe concurrent resolution operations
///
/// ### Strategy Resolution by Type
/// - [ ] resolve(_:) using concrete strategy type
/// - [ ] Type-to-ID conversion works correctly
/// - [ ] Built-in strategy type resolution
/// - [ ] Custom strategy type resolution
/// - [ ] Error handling for unregistered types
///
/// ### Strategy Information and Queries
/// - [ ] isRegistered(id:) returns true for registered strategies
/// - [ ] isRegistered(id:) returns false for unregistered strategies
/// - [ ] isRegistered(_:) type-based existence checking
/// - [ ] registeredStrategyIds() returns all IDs in sorted order
/// - [ ] registeredStrategyInfo() returns complete metadata
/// - [ ] strategyCount() returns correct count
/// - [ ] Information consistency across concurrent access
///
/// ### Debug Information Access
/// - [ ] getAllStrategies() returns all registered strategies
/// - [ ] Type erasure handling in getAllStrategies()
/// - [ ] Existential type casting for debugging
/// - [ ] SPI(Debugging) access control verification
/// - [ ] Complete strategy collection returned
///
/// ### Cleanup Operations - Global
/// - [ ] cleanUp() calls cleanUp() on all registered strategies
/// - [ ] cleanUp() operates on all strategies regardless of type
/// - [ ] cleanUp() is safe and cannot fail
/// - [ ] cleanUp() performance with many registered strategies
/// - [ ] Thread-safe global cleanup operations
///
/// ### Cleanup Operations - Boundary-Specific
/// - [ ] cleanUp(boundaryId:) calls cleanUp(boundaryId:) on all strategies
/// - [ ] Boundary-specific cleanup preserves other boundaries
/// - [ ] Generic boundary type handling
/// - [ ] Boundary ID type erasure in cleanup closures
/// - [ ] Thread-safe boundary-specific cleanup
///
/// ### Container Management - Unregistration
/// - [ ] unregister(id:) removes strategy and returns true
/// - [ ] unregister(id:) returns false for unregistered strategy
/// - [ ] unregister(_:) type-based strategy removal
/// - [ ] Cleanup called before strategy removal
/// - [ ] Strategy state after unregistration
/// - [ ] Thread-safe unregistration operations
///
/// ### Container Management - Complete Reset
/// - [ ] removeAllStrategies() removes all strategies
/// - [ ] removeAllStrategies() calls cleanUp() on all strategies before removal
/// - [ ] Container returns to initial empty state after reset
/// - [ ] Storage capacity preservation during reset
/// - [ ] Thread-safe complete reset operations
///
/// ### Type Erasure and Casting
/// - [ ] AnyLockmanStrategy<I> wrapper functionality
/// - [ ] Type-safe storage and retrieval across different info types
/// - [ ] Heterogeneous strategy types coexistence
/// - [ ] Generic type parameter preservation
/// - [ ] Type safety maintained through type erasure
///
/// ### Thread Safety and Concurrency
/// - [ ] ManagedCriticalState protection for all operations
/// - [ ] os_unfair_lock synchronization verification
/// - [ ] Concurrent registration and resolution operations
/// - [ ] Concurrent cleanup and query operations
/// - [ ] Race condition prevention in all critical sections
/// - [ ] @unchecked Sendable conformance correctness
///
/// ### Flexible Identification System
/// - [ ] LockmanStrategyId-based identification vs type-based
/// - [ ] Multiple configurations of same strategy type
/// - [ ] User-defined strategy identifiers
/// - [ ] Runtime strategy selection
/// - [ ] ID uniqueness enforcement
/// - [ ] String-based and type-based ID creation
///
/// ### StrategyEntry Metadata Management
/// - [ ] Correct strategy instance storage
/// - [ ] typeName extraction and storage
/// - [ ] registeredAt timestamp accuracy
/// - [ ] cleanUp closure creation and functionality
/// - [ ] cleanUpById closure creation and functionality
/// - [ ] Metadata consistency across operations
///
/// ### Error Handling Edge Cases
/// - [ ] Empty string strategy IDs handling
/// - [ ] Nil or invalid strategy instances
/// - [ ] Memory management during error conditions
/// - [ ] Error message localization and formatting
/// - [ ] Graceful handling of cleanup failures
///
/// ### Integration with Built-in Strategies
/// - [ ] LockmanSingleExecutionStrategy registration and resolution
/// - [ ] LockmanPriorityBasedStrategy registration and resolution
/// - [ ] Built-in strategy ID constants usage
/// - [ ] Multiple strategy type coexistence
/// - [ ] Strategy type hierarchy handling
///
/// ### Performance and Memory Management
/// - [ ] O(1) complexity for registration and resolution
/// - [ ] O(n log n) complexity for sorted queries
/// - [ ] Memory efficiency with many registered strategies
/// - [ ] Cleanup operation performance
/// - [ ] Storage capacity management
/// - [ ] Resource cleanup completeness
///
final class LockmanStrategyContainerTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Infrastructure

  /// Test boundary ID for testing
  struct TestBoundaryId: LockmanBoundaryId {
    let value: String
    
    init(_ value: String) {
      self.value = value
    }
  }

  /// Mock strategy for testing
  final class MockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = LockmanSingleExecutionInfo
    
    let strategyId: LockmanStrategyId
    private let lock = NSLock()
    private var _cleanupCallCount = 0
    private var _boundaryCleanupCallCount = 0
    private var _lastCleanedBoundaryId: String?
    
    var cleanupCallCount: Int {
      lock.withLock { _cleanupCallCount }
    }
    var boundaryCleanupCallCount: Int {
      lock.withLock { _boundaryCleanupCallCount }
    }
    var lastCleanedBoundaryId: String? {
      lock.withLock { _lastCleanedBoundaryId }
    }
    
    init(id: String = "MockStrategy") {
      self.strategyId = LockmanStrategyId(name: id)
    }
    
    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId(name: "MockStrategy")
    }
    
    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo) -> LockmanResult {
      .success
    }
    
    func lock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo) {
      // Mock lock implementation
    }
    
    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo) {
      // Mock unlock implementation
    }
    
    func cleanUp() {
      lock.withLock { _cleanupCallCount += 1 }
    }
    
    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      lock.withLock {
        _boundaryCleanupCallCount += 1
        _lastCleanedBoundaryId = String(describing: boundaryId)
      }
    }
    
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      // Mock implementation returns empty state
      return [:]
    }
  }

  /// Another mock strategy with different info type
  final class SecondMockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = LockmanConcurrencyLimitedInfo
    
    let strategyId: LockmanStrategyId
    private let lock = NSLock()
    private var _cleanupCallCount = 0
    private var _boundaryCleanupCallCount = 0
    private var _lastCleanedBoundaryId: String?
    
    var cleanupCallCount: Int {
      lock.withLock { _cleanupCallCount }
    }
    var boundaryCleanupCallCount: Int {
      lock.withLock { _boundaryCleanupCallCount }
    }
    var lastCleanedBoundaryId: String? {
      lock.withLock { _lastCleanedBoundaryId }
    }
    
    init(id: String = "SecondMockStrategy") {
      self.strategyId = LockmanStrategyId(name: id)
    }
    
    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId(name: "SecondMockStrategy")
    }
    
    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanConcurrencyLimitedInfo) -> LockmanResult {
      .success
    }
    
    func lock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanConcurrencyLimitedInfo) {
      // Mock lock implementation
    }
    
    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanConcurrencyLimitedInfo) {
      // Mock unlock implementation
    }
    
    func cleanUp() {
      lock.withLock { _cleanupCallCount += 1 }
    }
    
    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      lock.withLock {
        _boundaryCleanupCallCount += 1
        _lastCleanedBoundaryId = String(describing: boundaryId)
      }
    }
    
    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      // Mock implementation returns empty state
      return [:]
    }
  }

  // MARK: - Initialization Tests

  func testContainerInitialization() {
    // Given & When
    let container = LockmanStrategyContainer()

    // Then
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertEqual(container.registeredStrategyIds().count, 0)
    XCTAssertEqual(container.registeredStrategyInfo().count, 0)
  }

  // MARK: - Strategy Registration Tests

  func testRegisterStrategyWithId() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy()
    let strategyId = LockmanStrategyId("TestStrategy")

    // When
    XCTAssertNoThrow(try container.register(id: strategyId, strategy: strategy))

    // Then
    XCTAssertEqual(container.strategyCount(), 1)
    XCTAssertTrue(container.isRegistered(id: strategyId))
    XCTAssertTrue(container.registeredStrategyIds().contains(strategyId))
  }

  func testRegisterStrategyWithOwnId() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy(id: "CustomStrategy")

    // When
    XCTAssertNoThrow(try container.register(strategy))

    // Then
    XCTAssertEqual(container.strategyCount(), 1)
    XCTAssertTrue(container.isRegistered(id: strategy.strategyId))
    XCTAssertEqual(container.registeredStrategyIds().first, strategy.strategyId)
  }

  func testRegisterDuplicateStrategyId() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy()
    let strategy2 = MockStrategy()
    let strategyId = LockmanStrategyId("DuplicateStrategy")

    // When & Then
    XCTAssertNoThrow(try container.register(id: strategyId, strategy: strategy1))
    XCTAssertThrowsError(try container.register(id: strategyId, strategy: strategy2)) { error in
      guard let registrationError = error as? LockmanRegistrationError,
            case .strategyAlreadyRegistered(let id) = registrationError else {
        XCTFail("Expected LockmanRegistrationError.strategyAlreadyRegistered")
        return
      }
      XCTAssertEqual(id, strategyId.value)
    }

    // Then - Only first strategy should be registered
    XCTAssertEqual(container.strategyCount(), 1)
  }

  func testRegisterMultipleStrategies() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")

    // When
    XCTAssertNoThrow(try container.register(strategy1))
    XCTAssertNoThrow(try container.register(strategy2))

    // Then
    XCTAssertEqual(container.strategyCount(), 2)
    XCTAssertTrue(container.isRegistered(id: strategy1.strategyId))
    XCTAssertTrue(container.isRegistered(id: strategy2.strategyId))
  }

  // MARK: - Bulk Registration Tests

  func testRegisterAllWithIdPairs() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")
    let id1 = LockmanStrategyId(name: "CustomId1")
    let id2 = LockmanStrategyId(name: "CustomId2")

    // When
    XCTAssertNoThrow(try container.registerAll([
      (id1, strategy1),
      (id2, strategy2)
    ]))

    // Then
    XCTAssertEqual(container.strategyCount(), 2)
    XCTAssertTrue(container.isRegistered(id: id1))
    XCTAssertTrue(container.isRegistered(id: id2))
  }

  func testRegisterAllWithStrategies() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")

    // When
    XCTAssertNoThrow(try container.registerAll([strategy1, strategy2]))

    // Then
    XCTAssertEqual(container.strategyCount(), 2)
    XCTAssertTrue(container.isRegistered(id: strategy1.strategyId))
    XCTAssertTrue(container.isRegistered(id: strategy2.strategyId))
  }

  func testRegisterAllAtomicBehavior() {
    // Given
    let container = LockmanStrategyContainer()
    let existingStrategy = MockStrategy(id: "ExistingStrategy")
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "ExistingStrategy") // Duplicate!
    let strategy3 = MockStrategy(id: "Strategy3")

    try! container.register(existingStrategy)

    // When & Then - Should fail atomically
    XCTAssertThrowsError(try container.registerAll([strategy1, strategy2, strategy3])) { error in
      guard let registrationError = error as? LockmanRegistrationError,
            case .strategyAlreadyRegistered = registrationError else {
        XCTFail("Expected LockmanRegistrationError.strategyAlreadyRegistered")
        return
      }
    }

    // Then - No new strategies should be registered
    XCTAssertEqual(container.strategyCount(), 1)
    XCTAssertFalse(container.isRegistered(id: strategy1.strategyId))
    XCTAssertFalse(container.isRegistered(id: strategy3.strategyId))
  }

  func testRegisterAllDuplicateInInputArray() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy1") // Same ID!

    // When & Then
    XCTAssertThrowsError(try container.registerAll([strategy1, strategy2])) { error in
      guard let registrationError = error as? LockmanRegistrationError,
            case .strategyAlreadyRegistered = registrationError else {
        XCTFail("Expected LockmanRegistrationError.strategyAlreadyRegistered")
        return
      }
    }

    // Then
    XCTAssertEqual(container.strategyCount(), 0)
  }

  // MARK: - Strategy Resolution Tests

  func testResolveStrategyById() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy(id: "TestStrategy")
    let strategyId = strategy.strategyId

    try! container.register(strategy)

    // When & Then
    do {
      let resolvedStrategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: strategyId)
      XCTAssertEqual(resolvedStrategy.strategyId, strategyId)
    } catch {
      XCTFail("Failed to resolve strategy: \(error)")
    }
  }

  func testResolveStrategyByType() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy()

    try! container.register(strategy)

    // When & Then
    XCTAssertNoThrow(try {
      let resolved: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(MockStrategy.self)
      XCTAssertNotNil(resolved)
    }())
  }

  func testResolveNonExistentStrategy() {
    // Given
    let container = LockmanStrategyContainer()
    let nonExistentId = LockmanStrategyId("NonExistent")

    // When & Then
    XCTAssertThrowsError(try container.resolve(id: nonExistentId, expecting: LockmanSingleExecutionInfo.self)) { error in
      guard let registrationError = error as? LockmanRegistrationError,
            case .strategyNotRegistered(let id) = registrationError else {
        XCTFail("Expected LockmanRegistrationError.strategyNotRegistered")
        return
      }
      XCTAssertEqual(id, nonExistentId.value)
    }
  }

  func testResolveWithTypeInference() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy()

    try! container.register(strategy)

    // When & Then
    do {
      let resolvedStrategy: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: strategy.strategyId)
      XCTAssertEqual(resolvedStrategy.strategyId, strategy.strategyId)
    } catch {
      XCTFail("Failed to resolve strategy: \(error)")
    }
  }

  // MARK: - Strategy Information Tests

  func testIsRegisteredById() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy(id: "TestStrategy")
    let registeredId = strategy.strategyId
    let unregisteredId = LockmanStrategyId("UnregisteredStrategy")

    try! container.register(strategy)

    // When & Then
    XCTAssertTrue(container.isRegistered(id: registeredId))
    XCTAssertFalse(container.isRegistered(id: unregisteredId))
  }

  func testIsRegisteredByType() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy()

    try! container.register(strategy)

    // When & Then
    XCTAssertTrue(container.isRegistered(MockStrategy.self))
    XCTAssertFalse(container.isRegistered(SecondMockStrategy.self))
  }

  func testRegisteredStrategyIds() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")

    try! container.register(strategy1)
    try! container.register(strategy2)

    // When
    let registeredIds = container.registeredStrategyIds()

    // Then
    XCTAssertEqual(registeredIds.count, 2)
    XCTAssertTrue(registeredIds.contains(strategy1.strategyId))
    XCTAssertTrue(registeredIds.contains(strategy2.strategyId))
    // Should be sorted
    XCTAssertEqual(registeredIds, registeredIds.sorted { $0.value < $1.value })
  }

  func testRegisteredStrategyInfo() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy(id: "TestStrategy")

    try! container.register(strategy)

    // When
    let strategyInfo = container.registeredStrategyInfo()

    // Then
    XCTAssertEqual(strategyInfo.count, 1)
    let info = strategyInfo.first!
    XCTAssertEqual(info.id, strategy.strategyId)
    XCTAssertTrue(info.typeName.contains("MockStrategy"))
    XCTAssertTrue(info.registeredAt <= Date())
  }

  func testStrategyCount() {
    // Given
    let container = LockmanStrategyContainer()

    // When & Then - Initially empty
    XCTAssertEqual(container.strategyCount(), 0)

    // When & Then - After adding
    try! container.register(MockStrategy(id: "Strategy1"))
    XCTAssertEqual(container.strategyCount(), 1)

    try! container.register(MockStrategy(id: "Strategy2"))
    XCTAssertEqual(container.strategyCount(), 2)
  }

  // MARK: - Cleanup Operations Tests

  func testGlobalCleanup() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")

    try! container.register(strategy1)
    try! container.register(strategy2)

    // When
    container.cleanUp()

    // Then
    XCTAssertEqual(strategy1.cleanupCallCount, 1)
    XCTAssertEqual(strategy2.cleanupCallCount, 1)
  }

  func testBoundarySpecificCleanup() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")
    let boundaryId = TestBoundaryId("TestBoundary")

    try! container.register(strategy1)
    try! container.register(strategy2)

    // When
    container.cleanUp(boundaryId: boundaryId)

    // Then
    XCTAssertEqual(strategy1.boundaryCleanupCallCount, 1)
    XCTAssertEqual(strategy2.boundaryCleanupCallCount, 1)
    XCTAssertEqual(strategy1.lastCleanedBoundaryId, "TestBoundaryId(value: \"TestBoundary\")")
  }

  // MARK: - Container Management Tests

  func testUnregisterById() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy(id: "TestStrategy")
    let strategyId = strategy.strategyId

    try! container.register(strategy)
    XCTAssertEqual(container.strategyCount(), 1)

    // When
    let wasRemoved = container.unregister(id: strategyId)

    // Then
    XCTAssertTrue(wasRemoved)
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertFalse(container.isRegistered(id: strategyId))
    XCTAssertEqual(strategy.cleanupCallCount, 1) // Should be cleaned up
  }

  func testUnregisterByType() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy = MockStrategy()

    try! container.register(strategy)
    XCTAssertEqual(container.strategyCount(), 1)

    // When
    let wasRemoved = container.unregister(MockStrategy.self)

    // Then
    XCTAssertTrue(wasRemoved)
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertFalse(container.isRegistered(MockStrategy.self))
    XCTAssertEqual(strategy.cleanupCallCount, 1)
  }

  func testUnregisterNonExistentStrategy() {
    // Given
    let container = LockmanStrategyContainer()
    let nonExistentId = LockmanStrategyId("NonExistent")

    // When
    let wasRemoved = container.unregister(id: nonExistentId)

    // Then
    XCTAssertFalse(wasRemoved)
    XCTAssertEqual(container.strategyCount(), 0)
  }

  func testRemoveAllStrategies() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "Strategy1")
    let strategy2 = MockStrategy(id: "Strategy2")

    try! container.register(strategy1)
    try! container.register(strategy2)
    XCTAssertEqual(container.strategyCount(), 2)

    // When
    container.removeAllStrategies()

    // Then
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertEqual(container.registeredStrategyIds().count, 0)
    XCTAssertEqual(strategy1.cleanupCallCount, 1)
    XCTAssertEqual(strategy2.cleanupCallCount, 1)
  }

  // MARK: - Thread Safety Tests

  func testConcurrentRegistration() {
    // Given
    let container = LockmanStrategyContainer()
    let expectation = XCTestExpectation(description: "Concurrent registration")
    expectation.expectedFulfillmentCount = 100

    // When - Register strategies concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let strategy = MockStrategy(id: "Strategy\(index)")
      do {
        try container.register(strategy)
        expectation.fulfill()
      } catch {
        XCTFail("Registration should not fail for unique strategies: \(error)")
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Then
    XCTAssertEqual(container.strategyCount(), 100)
  }

  func testConcurrentResolution() {
    // Given
    let container = LockmanStrategyContainer()
    let strategies = (0..<10).map { MockStrategy(id: "Strategy\($0)") }
    
    for strategy in strategies {
      try! container.register(strategy)
    }

    let expectation = XCTestExpectation(description: "Concurrent resolution")
    expectation.expectedFulfillmentCount = 100

    // When - Resolve strategies concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let strategyId = LockmanStrategyId("Strategy\(index % 10)")
      do {
        let _: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: strategyId)
        expectation.fulfill()
      } catch {
        XCTFail("Resolution should not fail for registered strategies: \(error)")
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - No crashes should occur
    XCTAssertEqual(container.strategyCount(), 10)
  }

  func testConcurrentRegistrationAndResolution() {
    // Given
    let container = LockmanStrategyContainer()
    let expectation = XCTestExpectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 200

    // When - Register and resolve concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let strategy = MockStrategy(id: "RegStrategy\(index)")
      do {
        try container.register(strategy)
        expectation.fulfill()
      } catch {
        // Some registrations may fail due to race conditions, that's ok
        expectation.fulfill()
      }
    }

    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let strategyId = LockmanStrategyId("RegStrategy\(index)")
      do {
        let _: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: strategyId)
        expectation.fulfill()
      } catch {
        // Some resolutions may fail if strategy not yet registered, that's ok
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - No crashes should occur
    XCTAssertTrue(container.strategyCount() > 0)
    XCTAssertTrue(container.strategyCount() <= 100)
  }

  func testConcurrentCleanup() {
    // Given
    let container = LockmanStrategyContainer()
    let strategies = (0..<10).map { MockStrategy(id: "Strategy\($0)") }
    
    for strategy in strategies {
      try! container.register(strategy)
    }

    let expectation = XCTestExpectation(description: "Concurrent cleanup")
    expectation.expectedFulfillmentCount = 20

    // When - Call cleanup concurrently
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      container.cleanUp()
      expectation.fulfill()
    }

    DispatchQueue.concurrentPerform(iterations: 10) { index in
      let boundaryId = TestBoundaryId("Boundary\(index)")
      container.cleanUp(boundaryId: boundaryId)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - No crashes should occur, all strategies should have been cleaned
    for strategy in strategies {
      XCTAssertTrue(strategy.cleanupCallCount > 0)
    }
  }

  // MARK: - Performance Tests

  func testRegistrationPerformance() {
    // Given
    let container = LockmanStrategyContainer()
    let strategies = (0..<1000).map { MockStrategy(id: "Strategy\($0)") }

    // When & Then
    measure {
      for strategy in strategies {
        try! container.register(strategy)
      }
    }
  }

  func testResolutionPerformance() {
    // Given
    let container = LockmanStrategyContainer()
    let strategies = (0..<1000).map { MockStrategy(id: "Strategy\($0)") }
    
    for strategy in strategies {
      try! container.register(strategy)
    }

    // When & Then
    measure {
      for strategy in strategies {
        let _: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try! container.resolve(id: strategy.strategyId)
      }
    }
  }

  // MARK: - Edge Cases Tests

  func testEmptyContainerOperations() {
    // Given
    let container = LockmanStrategyContainer()

    // When & Then - Safe operations on empty container
    XCTAssertEqual(container.strategyCount(), 0)
    XCTAssertEqual(container.registeredStrategyIds().count, 0)
    XCTAssertEqual(container.registeredStrategyInfo().count, 0)
    XCTAssertFalse(container.isRegistered(id: LockmanStrategyId("Anything")))
    XCTAssertFalse(container.unregister(id: LockmanStrategyId("Anything")))
    
    // Cleanup operations should be safe
    container.cleanUp()
    container.cleanUp(boundaryId: TestBoundaryId("Test"))
    container.removeAllStrategies()
  }

  func testRegistrationAfterRemoval() {
    // Given
    let container = LockmanStrategyContainer()
    let strategy1 = MockStrategy(id: "TestStrategy")
    let strategy2 = MockStrategy(id: "TestStrategy") // Same ID, different instance
    let strategyId = strategy1.strategyId

    // When & Then - Register, remove, register again
    XCTAssertNoThrow(try container.register(strategy1))
    XCTAssertTrue(container.isRegistered(id: strategyId))

    XCTAssertTrue(container.unregister(id: strategyId))
    XCTAssertFalse(container.isRegistered(id: strategyId))

    XCTAssertNoThrow(try container.register(strategy2))
    XCTAssertTrue(container.isRegistered(id: strategyId))
  }

  func testLargeScaleOperations() {
    // Given
    let container = LockmanStrategyContainer()
    let strategyCount = 10000

    // When - Register many strategies
    for i in 0..<strategyCount {
      let strategy = MockStrategy(id: "Strategy\(i)")
      try! container.register(strategy)
    }

    // Then
    XCTAssertEqual(container.strategyCount(), strategyCount)
    XCTAssertEqual(container.registeredStrategyIds().count, strategyCount)

    // Test bulk operations
    let startTime = Date()
    container.cleanUp()
    let cleanupTime = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(cleanupTime, 1.0, "Cleanup should be reasonably fast")

    container.removeAllStrategies()
    XCTAssertEqual(container.strategyCount(), 0)
  }

  // MARK: - Type Erasure Tests

  func testTypeErasureWithDifferentInfoTypes() {
    // Given
    let container = LockmanStrategyContainer()
    let singleExecutionStrategy = MockStrategy()
    let concurrencyLimitedStrategy = SecondMockStrategy()

    // When
    XCTAssertNoThrow(try container.register(singleExecutionStrategy))
    XCTAssertNoThrow(try container.register(concurrencyLimitedStrategy))

    // Then - Both should coexist despite different info types
    XCTAssertEqual(container.strategyCount(), 2)
    
    // Resolution should work with correct types
    XCTAssertNoThrow({
      let _: AnyLockmanStrategy<LockmanSingleExecutionInfo> = try container.resolve(id: singleExecutionStrategy.strategyId)
    })
    
    XCTAssertNoThrow({
      let _: AnyLockmanStrategy<LockmanConcurrencyLimitedInfo> = try container.resolve(id: concurrencyLimitedStrategy.strategyId)
    })
  }

  func testHeterogeneousStrategyCoexistence() {
    // Given
    let container = LockmanStrategyContainer()
    let mockStrategy1 = MockStrategy(id: "Mock1")
    let secondMockStrategy = SecondMockStrategy(id: "Mock2")
    let mockStrategy2 = MockStrategy(id: "Mock3")

    // When - Register different strategy types
    try! container.register(mockStrategy1)
    try! container.register(secondMockStrategy)
    try! container.register(mockStrategy2)

    // Then
    XCTAssertEqual(container.strategyCount(), 3)
    
    // All strategies should be queryable
    XCTAssertTrue(container.isRegistered(id: mockStrategy1.strategyId))
    XCTAssertTrue(container.isRegistered(id: secondMockStrategy.strategyId))
    XCTAssertTrue(container.isRegistered(id: mockStrategy2.strategyId))
  }
}
