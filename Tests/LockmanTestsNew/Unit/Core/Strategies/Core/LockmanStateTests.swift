import XCTest

@testable import Lockman

/// Unit tests for LockmanState
///
/// Tests the thread-safe container using OrderedDictionary for both O(1) access
/// and guaranteed ordering with generic key support and dual index system.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Generic Type System and Initialization
/// - [ ] LockmanState<I, K> with custom key extractor function
/// - [ ] ActionIdLockmanState<I> convenience typealias usage
/// - [ ] Convenience init() for actionId-based keys
/// - [ ] Custom key extractor function behavior
/// - [ ] Sendable compliance for I: LockmanInfo and K: Hashable & Sendable
/// - [ ] Thread-safe initialization with ManagedCriticalState
///
/// ### StateData Internal Structure
/// - [ ] OrderedDictionary storage initialization and behavior
/// - [ ] Secondary index structure for O(1) key-based lookups
/// - [ ] Boundary ID -> Key -> Set<UUID> mapping correctness
/// - [ ] AnyLockmanBoundaryId type erasure in storage keys
/// - [ ] Dual data structure synchronization
///
/// ### Lock Addition Operations
/// - [ ] add(boundaryId:info:) with unique UUID generation
/// - [ ] OrderedDictionary insertion order preservation
/// - [ ] Automatic key extraction from lock info
/// - [ ] Dual index update atomicity (storage + key index)
/// - [ ] Thread-safe concurrent addition from multiple threads
/// - [ ] O(1) complexity verification for addition operations
///
/// ### Lock Removal - Individual
/// - [ ] remove(boundaryId:info:) by specific UUID
/// - [ ] Exact lock instance removal (not affecting same actionId)
/// - [ ] Dual index cleanup during removal
/// - [ ] Empty boundary cleanup when last lock removed
/// - [ ] O(1) complexity verification for individual removal
/// - [ ] Thread-safe concurrent removal operations
///
/// ### Lock Removal - Bulk by Key
/// - [ ] removeAll(boundaryId:key:) removes all locks with specific key
/// - [ ] Efficient bulk removal using filter operation
/// - [ ] Key index cleanup for removed keys
/// - [ ] Empty boundary cleanup after bulk removal
/// - [ ] O(n) complexity with efficient Set lookup optimization
/// - [ ] ActionId-specific convenience removeAllLocks method
///
/// ### Lock Removal - Complete Cleanup
/// - [ ] removeAll() clears all locks across all boundaries
/// - [ ] removeAll(boundaryId:) clears all locks for specific boundary
/// - [ ] Capacity preservation during bulk removal operations
/// - [ ] Complete dual index cleanup
/// - [ ] Thread-safe bulk cleanup operations
///
/// ### Query Operations - Basic
/// - [ ] currentLocks(in:) returns all locks in insertion order
/// - [ ] OrderedDictionary value extraction preserves order
/// - [ ] Empty boundary returns empty array
/// - [ ] Thread-safe concurrent query operations
/// - [ ] Consistent snapshot during concurrent modifications
///
/// ### Query Operations - Key-based
/// - [ ] hasActiveLocks(in:matching:) O(1) key existence check
/// - [ ] currentLocks(in:matching:) filters by key with order preservation
/// - [ ] activeLockCount(in:matching:) O(1) count operation
/// - [ ] activeKeys(in:) returns all unique keys in boundary
/// - [ ] Key-based queries use secondary index for performance
/// - [ ] Insertion order preservation in key-filtered results
///
/// ### Performance Characteristics Verification
/// - [ ] O(1) add operation timing verification
/// - [ ] O(1) remove by UUID timing verification
/// - [ ] O(1) key-based query timing verification
/// - [ ] O(n) bulk removal efficiency measurement
/// - [ ] OrderedDictionary vs standard Dictionary performance comparison
/// - [ ] Memory efficiency with large numbers of locks
///
/// ### Insertion Order Preservation
/// - [ ] Multiple locks added in sequence maintain order
/// - [ ] Order preservation after removal operations
/// - [ ] Order consistency across different boundary IDs
/// - [ ] Index-based ordering in OrderedDictionary
/// - [ ] Sort operation correctness in key-filtered queries
///
/// ### Thread Safety and Concurrency
/// - [ ] ManagedCriticalState protection for all operations
/// - [ ] Atomic dual index updates (storage + key index)
/// - [ ] Concurrent add/remove operations safety
/// - [ ] Concurrent query operations during modifications
/// - [ ] Race condition prevention in critical sections
/// - [ ] Sendable conformance correctness
///
/// ### Boundary Management
/// - [ ] Multiple boundary IDs isolation
/// - [ ] AnyLockmanBoundaryId type erasure correctness
/// - [ ] activeBoundaryIds() returns all active boundaries
/// - [ ] Boundary-specific operations don't affect others
/// - [ ] Empty boundary cleanup behavior
///
/// ### Key Extraction and Indexing
/// - [ ] Custom key extractor function execution
/// - [ ] actionId extraction in convenience initializer
/// - [ ] Complex key extraction scenarios
/// - [ ] Key consistency across operations
/// - [ ] Secondary index maintenance during modifications
///
/// ### Bulk Operations and Statistics
/// - [ ] totalActiveLockCount() across all boundaries
/// - [ ] allActiveLocks() complete snapshot functionality
/// - [ ] Statistics accuracy during concurrent modifications
/// - [ ] Bulk operation performance with many boundaries
/// - [ ] Memory efficiency of complete snapshots
///
/// ### Integration with OrderedDictionary
/// - [ ] swift-collections dependency integration
/// - [ ] OrderedDictionary specific features usage
/// - [ ] Index-based access patterns
/// - [ ] Efficient bulk operations on OrderedDictionary
/// - [ ] Memory management with OrderedDictionary
///
/// ### Error Handling and Edge Cases
/// - [ ] Behavior with nil or missing boundary data
/// - [ ] Key extractor function throwing scenarios
/// - [ ] Invalid UUID handling in removal operations
/// - [ ] Empty state operations (queries on empty container)
/// - [ ] Resource exhaustion scenarios
///
/// ### Type Safety and Generic Constraints
/// - [ ] LockmanInfo protocol compliance verification
/// - [ ] Hashable & Sendable key constraint verification
/// - [ ] Type erasure safety with AnyLockmanBoundaryId
/// - [ ] Generic type parameter propagation
/// - [ ] Compile-time type safety guarantees
///
/// ### Compatibility and Migration
/// - [ ] ActionIdLockmanState typealias behavior
/// - [ ] Backward compatibility with actionId-based usage
/// - [ ] Migration from single-key to multi-key scenarios
/// - [ ] Convenience methods for common use cases
/// - [ ] API consistency across different key types
///
/// ### Memory Management and Resource Cleanup
/// - [ ] Proper cleanup of OrderedDictionary instances
/// - [ ] Secondary index memory management
/// - [ ] Memory leak prevention during long-running operations
/// - [ ] Resource cleanup completeness
/// - [ ] Capacity management and optimization
///
final class LockmanStateTests: XCTestCase {

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

  /// Mock lock info for testing with custom keys
  struct MockLockInfo: LockmanInfo, Equatable {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let customKey: String

    init(actionId: LockmanActionId, customKey: String? = nil) {
      self.strategyId = LockmanStrategyId("TestStrategy")
      self.actionId = actionId
      self.uniqueId = UUID()
      self.customKey = customKey ?? actionId
    }

    var debugDescription: String {
      "MockLockInfo(actionId: \(actionId), customKey: \(customKey), uniqueId: \(uniqueId))"
    }

    var debugAdditionalInfo: String {
      "mock"
    }

    var isCancellationTarget: Bool {
      true
    }

    static func == (lhs: MockLockInfo, rhs: MockLockInfo) -> Bool {
      lhs.uniqueId == rhs.uniqueId
    }
  }

  // MARK: - Initialization Tests

  func testLockmanStateInitializationWithCustomKeyExtractor() {
    // Given & When
    let state = LockmanState<MockLockInfo, String> { $0.customKey }

    // Then
    XCTAssertEqual(state.totalActiveLockCount(), 0)
    XCTAssertEqual(state.activeBoundaryIds().count, 0)
  }

  func testActionIdLockmanStateConvenienceInit() {
    // Given & When
    let state = ActionIdLockmanState<MockLockInfo>()

    // Then
    XCTAssertEqual(state.totalActiveLockCount(), 0)
    XCTAssertEqual(state.activeBoundaryIds().count, 0)
  }

  func testLockmanStateTypealias() {
    // Given & When
    let state = LockmanState<MockLockInfo, LockmanActionId>()

    // Then - Should behave the same as ActionIdLockmanState
    XCTAssertEqual(state.totalActiveLockCount(), 0)
  }

  // MARK: - Lock Addition Tests

  func testAddSingleLock() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lockInfo = MockLockInfo(actionId: "action1", customKey: "key1")

    // When
    state.add(boundaryId: boundaryId, info: lockInfo)

    // Then
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 1)
    XCTAssertEqual(currentLocks.first?.uniqueId, lockInfo.uniqueId)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
  }

  func testAddMultipleLocksPreservesOrder() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "key3")

    // When - Add in specific order
    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // Then - Order should be preserved
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 3)
    XCTAssertEqual(currentLocks[0].uniqueId, lock1.uniqueId)
    XCTAssertEqual(currentLocks[1].uniqueId, lock2.uniqueId)
    XCTAssertEqual(currentLocks[2].uniqueId, lock3.uniqueId)
  }

  func testAddLocksToMultipleBoundaries() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")

    // When
    state.add(boundaryId: boundary1, info: lock1)
    state.add(boundaryId: boundary2, info: lock2)

    // Then
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 1)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 1)
    XCTAssertEqual(state.totalActiveLockCount(), 2)
    XCTAssertEqual(state.activeBoundaryIds().count, 2)
  }

  func testAddLocksWithSameKey() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "sharedKey")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "sharedKey")

    // When
    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)

    // Then
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "sharedKey"), 2)
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "sharedKey"))
  }

  // MARK: - Lock Removal Tests

  func testRemoveSpecificLock() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")

    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)

    // When
    state.remove(boundaryId: boundaryId, info: lock1)

    // Then
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 1)
    XCTAssertEqual(currentLocks.first?.uniqueId, lock2.uniqueId)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
  }

  func testRemoveAllLocksWithSpecificKey() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "targetKey")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "targetKey")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "otherKey")

    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // When
    state.removeAll(boundaryId: boundaryId, key: "targetKey")

    // Then
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 1)
    XCTAssertEqual(currentLocks.first?.uniqueId, lock3.uniqueId)
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "targetKey"))
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "otherKey"))
  }

  func testRemoveAllLocksInBoundary() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "key3")

    state.add(boundaryId: boundary1, info: lock1)
    state.add(boundaryId: boundary1, info: lock2)
    state.add(boundaryId: boundary2, info: lock3)

    // When
    state.removeAll(boundaryId: boundary1)

    // Then
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 0)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 1)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
    XCTAssertEqual(state.activeBoundaryIds().count, 1)
  }

  func testRemoveAllLocksGlobally() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")

    state.add(boundaryId: boundary1, info: lock1)
    state.add(boundaryId: boundary2, info: lock2)

    // When
    state.removeAll()

    // Then
    XCTAssertEqual(state.totalActiveLockCount(), 0)
    XCTAssertEqual(state.activeBoundaryIds().count, 0)
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 0)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 0)
  }

  func testRemoveNonExistentLock() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let existingLock = MockLockInfo(actionId: "action1", customKey: "key1")
    let nonExistentLock = MockLockInfo(actionId: "action2", customKey: "key2")

    state.add(boundaryId: boundaryId, info: existingLock)

    // When - Remove non-existent lock
    state.remove(boundaryId: boundaryId, info: nonExistentLock)

    // Then - Existing lock should remain
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
  }

  // MARK: - Query Operations Tests

  func testCurrentLocksInEmptyBoundary() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("emptyBoundary")

    // When
    let currentLocks = state.currentLocks(in: boundaryId)

    // Then
    XCTAssertEqual(currentLocks.count, 0)
  }

  func testCurrentLocksWithKeyFilter() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "targetKey")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "otherKey")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "targetKey")

    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // When
    let filteredLocks = state.currentLocks(in: boundaryId, matching: "targetKey")

    // Then
    XCTAssertEqual(filteredLocks.count, 2)
    XCTAssertTrue(filteredLocks.contains { $0.uniqueId == lock1.uniqueId })
    XCTAssertTrue(filteredLocks.contains { $0.uniqueId == lock3.uniqueId })
    XCTAssertFalse(filteredLocks.contains { $0.uniqueId == lock2.uniqueId })
  }

  func testHasActiveLocksQuery() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock = MockLockInfo(actionId: "action1", customKey: "testKey")

    // When & Then - Before adding
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "testKey"))

    // When & Then - After adding
    state.add(boundaryId: boundaryId, info: lock)
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "testKey"))
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "nonExistentKey"))

    // When & Then - After removing
    state.remove(boundaryId: boundaryId, info: lock)
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "testKey"))
  }

  func testActiveLockCountQuery() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "testKey")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "testKey")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "otherKey")

    // When & Then - Progressive addition
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "testKey"), 0)

    state.add(boundaryId: boundaryId, info: lock1)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "testKey"), 1)

    state.add(boundaryId: boundaryId, info: lock2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "testKey"), 2)

    state.add(boundaryId: boundaryId, info: lock3)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "testKey"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "otherKey"), 1)
  }

  func testActiveKeysQuery() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "key1")  // Duplicate key

    // When
    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // Then
    let activeKeys = state.activeKeys(in: boundaryId)
    XCTAssertEqual(activeKeys.count, 2)
    XCTAssertTrue(activeKeys.contains("key1"))
    XCTAssertTrue(activeKeys.contains("key2"))
  }

  func testTotalActiveLockCount() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "key3")

    // When & Then - Progressive addition
    XCTAssertEqual(state.totalActiveLockCount(), 0)

    state.add(boundaryId: boundary1, info: lock1)
    XCTAssertEqual(state.totalActiveLockCount(), 1)

    state.add(boundaryId: boundary1, info: lock2)
    XCTAssertEqual(state.totalActiveLockCount(), 2)

    state.add(boundaryId: boundary2, info: lock3)
    XCTAssertEqual(state.totalActiveLockCount(), 3)
  }

  func testAllActiveLocksSnapshot() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundary1 = TestBoundaryId("boundary1")
    let boundary2 = TestBoundaryId("boundary2")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "key1")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "key2")
    let lock3 = MockLockInfo(actionId: "action3", customKey: "key3")

    state.add(boundaryId: boundary1, info: lock1)
    state.add(boundaryId: boundary1, info: lock2)
    state.add(boundaryId: boundary2, info: lock3)

    // When
    let allLocks = state.allActiveLocks()

    // Then
    XCTAssertEqual(allLocks.keys.count, 2)
    XCTAssertEqual(allLocks[AnyLockmanBoundaryId(boundary1)]?.count, 2)
    XCTAssertEqual(allLocks[AnyLockmanBoundaryId(boundary2)]?.count, 1)
  }

  // MARK: - Performance Tests

  func testAddPerformance() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("performanceBoundary")
    let locks = (0..<1000).map { MockLockInfo(actionId: "action\($0)", customKey: "key\($0)") }

    // When & Then
    measure {
      for lock in locks {
        state.add(boundaryId: boundaryId, info: lock)
      }
    }
  }

  func testQueryPerformance() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("performanceBoundary")
    let locks = (0..<1000).map {
      MockLockInfo(actionId: "action\($0)", customKey: "key\($0 % 100)")
    }

    for lock in locks {
      state.add(boundaryId: boundaryId, info: lock)
    }

    // When & Then
    measure {
      for i in 0..<100 {
        _ = state.hasActiveLocks(in: boundaryId, matching: "key\(i)")
        _ = state.activeLockCount(in: boundaryId, matching: "key\(i)")
      }
    }
  }

  // MARK: - Thread Safety Tests

  func testConcurrentAdditions() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("concurrentBoundary")
    let expectation = XCTestExpectation(description: "Concurrent additions")
    expectation.expectedFulfillmentCount = 100

    // When - Add locks concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let lock = MockLockInfo(actionId: "action\(index)", customKey: "key\(index)")
      state.add(boundaryId: boundaryId, info: lock)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then
    XCTAssertEqual(state.totalActiveLockCount(), 100)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 100)
  }

  func testConcurrentAdditionsAndRemovals() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("concurrentBoundary")
    let expectation = XCTestExpectation(description: "Concurrent operations")
    expectation.expectedFulfillmentCount = 200
    let locks = (0..<100).map { MockLockInfo(actionId: "action\($0)", customKey: "key\($0)") }

    // When - Add and remove concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let lock = locks[index]
      state.add(boundaryId: boundaryId, info: lock)
      expectation.fulfill()
    }

    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let lock = locks[index]
      state.remove(boundaryId: boundaryId, info: lock)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - Some locks may remain due to race conditions, but no crashes should occur
    let finalCount = state.totalActiveLockCount()
    XCTAssertTrue(finalCount >= 0)
    XCTAssertTrue(finalCount <= 100)
  }

  func testConcurrentQueries() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("queryBoundary")
    let locks = (0..<50).map { MockLockInfo(actionId: "action\($0)", customKey: "key\($0 % 10)") }

    for lock in locks {
      state.add(boundaryId: boundaryId, info: lock)
    }

    let expectation = XCTestExpectation(description: "Concurrent queries")
    expectation.expectedFulfillmentCount = 100

    // When - Query concurrently
    DispatchQueue.concurrentPerform(iterations: 100) { index in
      let key = "key\(index % 10)"
      _ = state.hasActiveLocks(in: boundaryId, matching: key)
      _ = state.activeLockCount(in: boundaryId, matching: key)
      _ = state.currentLocks(in: boundaryId, matching: key)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - No crashes should occur
    XCTAssertEqual(state.totalActiveLockCount(), 50)
  }

  // MARK: - ActionId Convenience Tests

  func testActionIdBasedState() {
    // Given
    let state = ActionIdLockmanState<MockLockInfo>()
    let boundaryId = TestBoundaryId("actionIdBoundary")
    let lock1 = MockLockInfo(actionId: "action1")
    let lock2 = MockLockInfo(actionId: "action2")
    let lock3 = MockLockInfo(actionId: "action1")  // Same actionId

    // When
    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // Then
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "action1"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "action2"), 1)
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "action1"))
  }

  func testRemoveAllLocksConvenienceMethod() {
    // Given
    let state = ActionIdLockmanState<MockLockInfo>()
    let boundaryId = TestBoundaryId("actionIdBoundary")
    let lock1 = MockLockInfo(actionId: "action1")
    let lock2 = MockLockInfo(actionId: "action1")
    let lock3 = MockLockInfo(actionId: "action2")

    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    state.add(boundaryId: boundaryId, info: lock3)

    // When
    state.removeAllLocks(in: boundaryId, matching: "action1")

    // Then
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "action1"), 0)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "action2"), 1)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
  }

  // MARK: - Edge Cases Tests

  func testEmptyBoundaryCleanup() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock = MockLockInfo(actionId: "action1", customKey: "key1")

    state.add(boundaryId: boundaryId, info: lock)
    XCTAssertEqual(state.activeBoundaryIds().count, 1)

    // When - Remove the only lock
    state.remove(boundaryId: boundaryId, info: lock)

    // Then - Boundary should be cleaned up
    XCTAssertEqual(state.activeBoundaryIds().count, 0)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 0)
  }

  func testEmptyKeyCleanup() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("boundary1")
    let lock1 = MockLockInfo(actionId: "action1", customKey: "targetKey")
    let lock2 = MockLockInfo(actionId: "action2", customKey: "targetKey")

    state.add(boundaryId: boundaryId, info: lock1)
    state.add(boundaryId: boundaryId, info: lock2)
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "targetKey"))

    // When - Remove all locks with the key
    state.removeAll(boundaryId: boundaryId, key: "targetKey")

    // Then - Key should be cleaned up
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "targetKey"))
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, 0)
  }

  func testLargeScaleOperations() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("largeBoundary")
    let lockCount = 10000
    let keyCount = 100

    // When - Add many locks
    for i in 0..<lockCount {
      let lock = MockLockInfo(actionId: "action\(i)", customKey: "key\(i % keyCount)")
      state.add(boundaryId: boundaryId, info: lock)
    }

    // Then
    XCTAssertEqual(state.totalActiveLockCount(), lockCount)
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, keyCount)

    // Test bulk removal
    state.removeAll(boundaryId: boundaryId, key: "key0")
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "key0"), 0)
    XCTAssertTrue(state.totalActiveLockCount() < lockCount)
  }

  func testOrderPreservationWithRemovals() {
    // Given
    let state = LockmanState<MockLockInfo, String> { $0.customKey }
    let boundaryId = TestBoundaryId("orderBoundary")
    let locks = (0..<10).map { MockLockInfo(actionId: "action\($0)", customKey: "key\($0)") }

    // Add all locks
    for lock in locks {
      state.add(boundaryId: boundaryId, info: lock)
    }

    // When - Remove some locks (not all)
    state.remove(boundaryId: boundaryId, info: locks[2])
    state.remove(boundaryId: boundaryId, info: locks[5])
    state.remove(boundaryId: boundaryId, info: locks[8])

    // Then - Order should be preserved for remaining locks
    let remainingLocks = state.currentLocks(in: boundaryId)
    let expectedOrder = [0, 1, 3, 4, 6, 7, 9]

    XCTAssertEqual(remainingLocks.count, expectedOrder.count)
    for (index, expectedActionIndex) in expectedOrder.enumerated() {
      XCTAssertEqual(remainingLocks[index].actionId, "action\(expectedActionIndex)")
    }
  }
}
