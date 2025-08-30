import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanState tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Basic functionality (add, remove, query operations)
// 2. Phase 2: Error cases, edge conditions, and bulk operations  
// 3. Phase 3: Integration testing and complex scenarios

// MARK: - Test Helpers

private struct StateTestLockmanInfo: LockmanInfo {
  let actionId: LockmanActionId
  let strategyId: LockmanStrategyId
  let uniqueId: UUID
  let testKey: String
  let isCancellationTarget: Bool
  
  init(actionId: LockmanActionId, testKey: String, isCancellationTarget: Bool = true) {
    self.actionId = actionId
    self.strategyId = LockmanStrategyId(name: "StateTestStrategy")
    self.testKey = testKey
    self.isCancellationTarget = isCancellationTarget
    self.uniqueId = UUID()
  }
  
  var debugDescription: String {
    return "StateTestLockmanInfo(action: \(actionId), testKey: \(testKey), unique: \(uniqueId))"
  }
}

final class LockmanStateTests: XCTestCase {
  
  private var state: LockmanState<StateTestLockmanInfo, String>!
  private var actionIdState: LockmanState<StateTestLockmanInfo, LockmanActionId>!
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
    state = LockmanState<StateTestLockmanInfo, String>(keyExtractor: { $0.testKey })
    actionIdState = LockmanState<StateTestLockmanInfo, LockmanActionId>(keyExtractor: { $0.actionId })
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
    state = nil
    actionIdState = nil
  }
  
  // MARK: - Phase 1: Basic Functionality Tests
  
  func testLockmanStateInitialization() {
    // Test custom key extractor initialization
    let customState = LockmanState<StateTestLockmanInfo, String>(keyExtractor: { $0.testKey })
    XCTAssertNotNil(customState)
    
    // Test actionId convenience initializer
    let actionState = LockmanState<StateTestLockmanInfo, LockmanActionId>()
    XCTAssertNotNil(actionState)
  }
  
  func testLockmanStateBasicAddOperation() {
    // Test basic add operation
    let boundaryId = "testBoundary"
    let info = StateTestLockmanInfo(actionId: "testAction", testKey: "key1")
    
    state.add(boundaryId: boundaryId, info: info)
    
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 1)
    XCTAssertEqual(currentLocks.first?.actionId, info.actionId)
    XCTAssertEqual(currentLocks.first?.testKey, info.testKey)
  }
  
  func testLockmanStateMultipleAddOperations() {
    // Test multiple add operations preserve order
    let boundaryId = "testBoundary"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action3", testKey: "key1") // Same key as info1
    
    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)
    
    let currentLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currentLocks.count, 3)
    XCTAssertEqual(currentLocks[0].actionId, info1.actionId)
    XCTAssertEqual(currentLocks[1].actionId, info2.actionId)
    XCTAssertEqual(currentLocks[2].actionId, info3.actionId)
  }
  
  func testLockmanStateBasicRemoveOperation() {
    // Test basic remove operation
    let boundaryId = "testBoundary"
    let info = StateTestLockmanInfo(actionId: "testAction", testKey: "key1")
    
    state.add(boundaryId: boundaryId, info: info)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1)
    
    state.remove(boundaryId: boundaryId, info: info)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 0)
  }
  
  func testLockmanStateKeyBasedQueries() {
    // Test key-based query operations
    let boundaryId = "testBoundary"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action3", testKey: "key1") // Same key as info1
    
    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)
    
    // Test hasActiveLocks
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "key1"))
    XCTAssertTrue(state.hasActiveLocks(in: boundaryId, matching: "key2"))
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "nonexistent"))
    
    // Test activeLockCount
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "key1"), 2)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "key2"), 1)
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "nonexistent"), 0)
    
    // Test currentLocks with key filtering
    let key1Locks = state.currentLocks(in: boundaryId, matching: "key1")
    XCTAssertEqual(key1Locks.count, 2)
    XCTAssertTrue(key1Locks.contains { $0.actionId == info1.actionId })
    XCTAssertTrue(key1Locks.contains { $0.actionId == info3.actionId })
    
    let key2Locks = state.currentLocks(in: boundaryId, matching: "key2")
    XCTAssertEqual(key2Locks.count, 1)
    XCTAssertEqual(key2Locks.first?.actionId, info2.actionId)
  }
  
  func testLockmanStateActiveKeysQuery() {
    // Test activeKeys operation
    let boundaryId = "testBoundary"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action3", testKey: "key1")
    
    // Initially no active keys
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, 0)
    
    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)
    
    let activeKeys = state.activeKeys(in: boundaryId)
    XCTAssertEqual(activeKeys.count, 2)
    XCTAssertTrue(activeKeys.contains("key1"))
    XCTAssertTrue(activeKeys.contains("key2"))
  }
  
  // MARK: - Phase 2: Error Cases and Edge Conditions
  
  func testLockmanStateEmptyBoundaryQueries() {
    // Test queries on empty boundary
    let boundaryId = "emptyBoundary"
    
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 0)
    XCTAssertFalse(state.hasActiveLocks(in: boundaryId, matching: "anyKey"))
    XCTAssertEqual(state.activeLockCount(in: boundaryId, matching: "anyKey"), 0)
    XCTAssertEqual(state.currentLocks(in: boundaryId, matching: "anyKey").count, 0)
    XCTAssertEqual(state.activeKeys(in: boundaryId).count, 0)
  }
  
  func testLockmanStateRemoveNonexistentLock() {
    // Test removing a lock that doesn't exist
    let boundaryId = "testBoundary"
    let existingInfo = StateTestLockmanInfo(actionId: "existing", testKey: "key1")
    let nonexistentInfo = StateTestLockmanInfo(actionId: "nonexistent", testKey: "key1")
    
    state.add(boundaryId: boundaryId, info: existingInfo)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1)
    
    // Remove non-existent lock should be safe
    state.remove(boundaryId: boundaryId, info: nonexistentInfo)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1)
  }
  
  func testLockmanStateRemoveAllByKey() {
    // Test removeAll by key
    let boundaryId = "testBoundary"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action3", testKey: "key1")
    
    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)
    state.add(boundaryId: boundaryId, info: info3)
    
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 3)
    
    // Remove all locks with key1
    state.removeAll(boundaryId: boundaryId, key: "key1")
    
    let remainingLocks = state.currentLocks(in: boundaryId)
    XCTAssertEqual(remainingLocks.count, 1)
    XCTAssertEqual(remainingLocks.first?.actionId, info2.actionId)
  }
  
  func testLockmanStateRemoveAllByKeyNonexistent() {
    // Test removeAll with non-existent key
    let boundaryId = "testBoundary"
    let info = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    
    state.add(boundaryId: boundaryId, info: info)
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1)
    
    // Remove all locks with non-existent key
    state.removeAll(boundaryId: boundaryId, key: "nonexistent")
    XCTAssertEqual(state.currentLocks(in: boundaryId).count, 1) // Should remain unchanged
  }
  
  func testLockmanStateBulkOperations() {
    // Test bulk operations
    let boundary1 = "boundary1"
    let boundary2 = "boundary2"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    
    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary2, info: info2)
    
    XCTAssertEqual(state.totalActiveLockCount(), 2)
    XCTAssertEqual(state.activeBoundaryIds().count, 2)
    
    // Test removeAll for specific boundary
    state.removeAll(boundaryId: boundary1)
    XCTAssertEqual(state.totalActiveLockCount(), 1)
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 0)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 1)
    
    // Test global removeAll
    state.removeAll()
    XCTAssertEqual(state.totalActiveLockCount(), 0)
    XCTAssertEqual(state.activeBoundaryIds().count, 0)
  }
  
  func testLockmanStateAllActiveLocksOperation() {
    // Test allActiveLocks operation
    let boundary1 = "boundary1"
    let boundary2 = "boundary2"
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action3", testKey: "key3")
    
    state.add(boundaryId: boundary1, info: info1)
    state.add(boundaryId: boundary1, info: info2)
    state.add(boundaryId: boundary2, info: info3)
    
    let allLocks = state.allActiveLocks()
    XCTAssertEqual(allLocks.count, 2)
    
    let boundary1Locks = allLocks[AnyLockmanBoundaryId(boundary1)]
    XCTAssertEqual(boundary1Locks?.count, 2)
    
    let boundary2Locks = allLocks[AnyLockmanBoundaryId(boundary2)]
    XCTAssertEqual(boundary2Locks?.count, 1)
  }
  
  // MARK: - Phase 3: Integration Testing and ActionId Convenience
  
  func testLockmanStateActionIdConvenienceInitializer() {
    // Test ActionId convenience initializer
    let actionState = LockmanState<StateTestLockmanInfo, LockmanActionId>()
    let boundaryId = "testBoundary"
    let info = StateTestLockmanInfo(actionId: "testAction", testKey: "key1")
    
    actionState.add(boundaryId: boundaryId, info: info)
    
    XCTAssertTrue(actionState.hasActiveLocks(in: boundaryId, matching: info.actionId))
    XCTAssertEqual(actionState.activeLockCount(in: boundaryId, matching: info.actionId), 1)
  }
  
  func testLockmanStateActionIdConvenienceMethod() {
    // Test ActionId convenience removeAllLocks method
    let info1 = StateTestLockmanInfo(actionId: "action1", testKey: "key1")
    let info2 = StateTestLockmanInfo(actionId: "action2", testKey: "key2")
    let info3 = StateTestLockmanInfo(actionId: "action1", testKey: "key3") // Same actionId
    let boundaryId = "testBoundary"
    
    actionIdState.add(boundaryId: boundaryId, info: info1)
    actionIdState.add(boundaryId: boundaryId, info: info2)
    actionIdState.add(boundaryId: boundaryId, info: info3)
    
    XCTAssertEqual(actionIdState.totalActiveLockCount(), 3)
    
    // Use convenience method to remove all locks with action1
    actionIdState.removeAllLocks(in: boundaryId, matching: "action1")
    
    let remainingLocks = actionIdState.currentLocks(in: boundaryId)
    XCTAssertEqual(remainingLocks.count, 1)
    XCTAssertEqual(remainingLocks.first?.actionId, "action2")
  }
  
  func testLockmanStateMultipleBoundaryIsolation() {
    // Test that boundaries are properly isolated
    let boundary1 = "boundary1"
    let boundary2 = "boundary2"
    let boundary3 = "boundary3"
    let info = StateTestLockmanInfo(actionId: "testAction", testKey: "key1")
    
    // Add same info to different boundaries
    state.add(boundaryId: boundary1, info: info)
    state.add(boundaryId: boundary2, info: info)
    state.add(boundaryId: boundary3, info: info)
    
    // Verify isolation
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 1)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 1)
    XCTAssertEqual(state.currentLocks(in: boundary3).count, 1)
    
    // Remove from one boundary
    state.remove(boundaryId: boundary1, info: info)
    
    // Verify others remain unaffected
    XCTAssertEqual(state.currentLocks(in: boundary1).count, 0)
    XCTAssertEqual(state.currentLocks(in: boundary2).count, 1)
    XCTAssertEqual(state.currentLocks(in: boundary3).count, 1)
  }
  
  func testLockmanStateComplexIntegrationScenario() {
    // Test complex scenario with mixed operations
    let boundary = "complexBoundary"
    let infos = (0..<10).map { i in
      StateTestLockmanInfo(actionId: "action\(i)", testKey: "key\(i % 3)")
    }
    
    // Add all infos
    for info in infos {
      state.add(boundaryId: boundary, info: info)
    }
    
    XCTAssertEqual(state.totalActiveLockCount(), 10)
    XCTAssertEqual(state.activeKeys(in: boundary).count, 3)
    
    // Remove all key0 locks (should be ~3-4 locks)
    state.removeAll(boundaryId: boundary, key: "key0")
    
    // Remove specific key1 locks individually
    let key1Locks = state.currentLocks(in: boundary, matching: "key1")
    for lock in key1Locks {
      state.remove(boundaryId: boundary, info: lock)
    }
    
    // Only key2 locks should remain
    let remainingLocks = state.currentLocks(in: boundary)
    XCTAssertTrue(remainingLocks.allSatisfy { $0.testKey == "key2" })
    XCTAssertEqual(state.activeKeys(in: boundary), Set(["key2"]))
  }
  
}
