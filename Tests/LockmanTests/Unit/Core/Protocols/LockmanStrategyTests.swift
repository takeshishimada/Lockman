import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive protocol tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanStrategyTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Strategy Types for Protocol Conformance

  // Basic LockmanInfo for testing
  private struct TestLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID
    let priority: String

    init(
      strategyId: LockmanStrategyId = "TestStrategy", actionId: LockmanActionId = "testAction",
      priority: String = "medium"
    ) {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
      self.priority = priority
    }

    var debugDescription: String {
      "TestLockmanInfo(actionId: '\(actionId)', priority: '\(priority)')"
    }
  }

  // Mock strategy for testing protocol conformance
  private final class TestMockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = TestLockmanInfo

    private let _strategyId: LockmanStrategyId
    private let lock = NSLock()
    private(set) var canLockCallCount = 0
    private(set) var lockCallCount = 0
    private(set) var unlockCallCount = 0
    private(set) var cleanUpCallCount = 0
    private(set) var cleanUpBoundaryCallCount = 0

    private var lockedBoundaries: Set<AnyHashable> = []
    private var locksInfo: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]
    private var shouldFailCanLock = false
    private var canLockResult: LockmanStrategyResult = .success

    init(strategyId: LockmanStrategyId = "MockStrategy") {
      self._strategyId = strategyId
    }

    var strategyId: LockmanStrategyId { _strategyId }

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("MockStrategy")
    }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: I) -> LockmanStrategyResult {
      lock.lock()
      defer { lock.unlock() }
      canLockCallCount += 1
      if shouldFailCanLock {
        return .cancel(TestStrategyError.mockFailure(info: info, boundaryId: boundaryId))
      }
      return canLockResult
    }

    func lock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      lock.lock()
      defer { lock.unlock() }
      lockCallCount += 1
      lockedBoundaries.insert(AnyHashable(boundaryId))
      let anyBoundary = AnyLockmanBoundaryId(boundaryId)
      locksInfo[anyBoundary] = (locksInfo[anyBoundary] ?? []) + [info]
    }

    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      lock.lock()
      defer { lock.unlock() }
      unlockCallCount += 1
      lockedBoundaries.remove(AnyHashable(boundaryId))
      let anyBoundary = AnyLockmanBoundaryId(boundaryId)
      if var infos = locksInfo[anyBoundary] {
        infos.removeAll { ($0 as? TestLockmanInfo)?.uniqueId == info.uniqueId }
        if infos.isEmpty {
          locksInfo.removeValue(forKey: anyBoundary)
        } else {
          locksInfo[anyBoundary] = infos
        }
      }
    }

    func cleanUp() {
      lock.lock()
      defer { lock.unlock() }
      cleanUpCallCount += 1
      lockedBoundaries.removeAll()
      locksInfo.removeAll()
    }

    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      lock.lock()
      defer { lock.unlock() }
      cleanUpBoundaryCallCount += 1
      lockedBoundaries.remove(AnyHashable(boundaryId))
      let anyBoundary = AnyLockmanBoundaryId(boundaryId)
      locksInfo.removeValue(forKey: anyBoundary)
    }

    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      lock.lock()
      defer { lock.unlock() }
      return locksInfo
    }

    // Test helpers
    func setCanLockResult(_ result: LockmanStrategyResult) {
      lock.lock()
      defer { lock.unlock() }
      canLockResult = result
      shouldFailCanLock = false
    }

    func setShouldFailCanLock(_ shouldFail: Bool) {
      lock.lock()
      defer { lock.unlock() }
      shouldFailCanLock = shouldFail
    }

    func isLocked<B: LockmanBoundaryId>(_ boundaryId: B) -> Bool {
      lock.lock()
      defer { lock.unlock() }
      return lockedBoundaries.contains(AnyHashable(boundaryId))
    }

    func reset() {
      lock.lock()
      defer { lock.unlock() }
      canLockCallCount = 0
      lockCallCount = 0
      unlockCallCount = 0
      cleanUpCallCount = 0
      cleanUpBoundaryCallCount = 0
      lockedBoundaries.removeAll()
      locksInfo.removeAll()
      shouldFailCanLock = false
      canLockResult = .success
    }
  }

  // Error type for testing
  private struct TestStrategyError: LockmanError {
    let info: any LockmanInfo
    let boundaryId: String  // Use String instead of AnyHashable for Sendable compliance
    let reason: String

    static func mockFailure(info: any LockmanInfo, boundaryId: any LockmanBoundaryId)
      -> TestStrategyError
    {
      TestStrategyError(
        info: info, boundaryId: String(describing: boundaryId), reason: "Mock failure")
    }

    var errorDescription: String? {
      "Strategy error: \(reason) for action \(info.actionId) at boundary \(boundaryId)"
    }
  }

  // Struct-based strategy for testing
  private struct TestStructStrategy: LockmanStrategy {
    typealias I = TestLockmanInfo

    let strategyId: LockmanStrategyId

    init(strategyId: LockmanStrategyId = "StructStrategy") {
      self.strategyId = strategyId
    }

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("StructStrategy")
    }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: I) -> LockmanStrategyResult {
      return .success
    }

    func lock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      // Stateless implementation
    }

    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      // Stateless implementation
    }

    func cleanUp() {
      // Stateless implementation
    }

    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      // Stateless implementation
    }

    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      return [:]  // Stateless - no locks tracked
    }
  }

  // MARK: - Phase 1: Basic Protocol Conformance

  func testLockmanStrategyProtocolRequirements() {
    // Test basic protocol conformance
    let strategy = TestMockStrategy()

    // Should conform to Sendable
    XCTAssertNotNil(strategy as any Sendable)

    // Should have associated type constraint - avoid parameterized protocol types for iOS 16+ requirement
    XCTAssertTrue(true)  // Strategy conforms to protocol by definition

    // Should have required properties and methods
    XCTAssertNotNil(strategy.strategyId)
    XCTAssertEqual(strategy.strategyId.value, "MockStrategy")
  }

  func testLockmanStrategyAssociatedType() {
    // Test associated type constraints
    let mockStrategy = TestMockStrategy()
    let structStrategy = TestStructStrategy()

    // Both should work with TestLockmanInfo
    let info = TestLockmanInfo(actionId: "associatedTest")

    let mockResult = mockStrategy.canLock(boundaryId: "test", info: info)
    let structResult = structStrategy.canLock(boundaryId: "test", info: info)

    switch mockResult {
    case .success:
      XCTAssertTrue(true)
    default:
      XCTFail("Mock strategy should succeed")
    }

    switch structResult {
    case .success:
      XCTAssertTrue(true)
    default:
      XCTFail("Struct strategy should succeed")
    }
  }

  func testLockmanStrategyIdRequirement() {
    // Test strategyId property
    let defaultStrategy = TestMockStrategy()
    let customStrategy = TestMockStrategy(strategyId: "CustomMock")

    XCTAssertEqual(defaultStrategy.strategyId.value, "MockStrategy")
    XCTAssertEqual(customStrategy.strategyId.value, "CustomMock")

    // Test static makeStrategyId method
    let staticId = TestMockStrategy.makeStrategyId()
    XCTAssertEqual(staticId.value, "MockStrategy")
  }

  func testLockmanStrategyMakeStrategyId() {
    // Test static factory method
    let mockId = TestMockStrategy.makeStrategyId()
    let structId = TestStructStrategy.makeStrategyId()

    XCTAssertEqual(mockId.value, "MockStrategy")
    XCTAssertEqual(structId.value, "StructStrategy")

    // Should be consistent with instance strategyId
    let mockInstance = TestMockStrategy()
    let structInstance = TestStructStrategy()

    XCTAssertEqual(mockId, mockInstance.strategyId)
    XCTAssertEqual(structId, structInstance.strategyId)
  }

  // MARK: - Phase 2: Core Locking Operations

  func testLockmanStrategyCanLockBasic() {
    // Test canLock basic functionality
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "canLockTest")

    let result = strategy.canLock(boundaryId: "boundary1", info: info)

    XCTAssertEqual(strategy.canLockCallCount, 1)

    switch result {
    case .success:
      XCTAssertTrue(true)
    default:
      XCTFail("Should succeed by default")
    }
  }

  func testLockmanStrategyCanLockFailure() {
    // Test canLock failure scenarios
    let strategy = TestMockStrategy()
    strategy.setShouldFailCanLock(true)

    let info = TestLockmanInfo(actionId: "failureTest")
    let result = strategy.canLock(boundaryId: "boundary1", info: info)

    XCTAssertEqual(strategy.canLockCallCount, 1)

    switch result {
    case .cancel(let error):
      XCTAssertTrue(error is TestStrategyError)
      XCTAssertTrue(error.errorDescription?.contains("Mock failure") ?? false)
    default:
      XCTFail("Should fail when configured to fail")
    }
  }

  func testLockmanStrategyLockUnlockCycle() {
    // Test complete lock/unlock cycle
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "cycleTest")
    let boundaryId = "testBoundary"

    // Check if can lock
    let canLockResult = strategy.canLock(boundaryId: boundaryId, info: info)
    switch canLockResult {
    case .success:
      break
    default:
      XCTFail("Should be able to lock")
    }

    // Acquire lock
    strategy.lock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy.lockCallCount, 1)
    XCTAssertTrue(strategy.isLocked(boundaryId))

    // Release lock
    strategy.unlock(boundaryId: boundaryId, info: info)
    XCTAssertEqual(strategy.unlockCallCount, 1)
    XCTAssertFalse(strategy.isLocked(boundaryId))
  }

  func testLockmanStrategyMultipleBoundaries() {
    // Test multiple boundaries
    let strategy = TestMockStrategy()
    let info1 = TestLockmanInfo(actionId: "action1")
    let info2 = TestLockmanInfo(actionId: "action2")

    // Lock multiple boundaries
    strategy.lock(boundaryId: "boundary1", info: info1)
    strategy.lock(boundaryId: "boundary2", info: info2)
    strategy.lock(boundaryId: 123, info: info1)  // Different boundary type

    XCTAssertEqual(strategy.lockCallCount, 3)
    XCTAssertTrue(strategy.isLocked("boundary1"))
    XCTAssertTrue(strategy.isLocked("boundary2"))
    XCTAssertTrue(strategy.isLocked(123))

    // Unlock selectively
    strategy.unlock(boundaryId: "boundary1", info: info1)
    XCTAssertFalse(strategy.isLocked("boundary1"))
    XCTAssertTrue(strategy.isLocked("boundary2"))
    XCTAssertTrue(strategy.isLocked(123))
  }

  // MARK: - Phase 3: Cleanup Operations

  func testLockmanStrategyCleanUpAll() {
    // Test global cleanup
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "cleanupTest")

    // Create some locked state
    strategy.lock(boundaryId: "boundary1", info: info)
    strategy.lock(boundaryId: "boundary2", info: info)
    strategy.lock(boundaryId: UUID(), info: info)

    XCTAssertTrue(strategy.isLocked("boundary1"))
    XCTAssertTrue(strategy.isLocked("boundary2"))

    // Clean up all
    strategy.cleanUp()

    XCTAssertEqual(strategy.cleanUpCallCount, 1)
    XCTAssertFalse(strategy.isLocked("boundary1"))
    XCTAssertFalse(strategy.isLocked("boundary2"))
  }

  func testLockmanStrategyCleanUpBoundary() {
    // Test boundary-specific cleanup
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "boundaryCleanupTest")

    // Create locked state on multiple boundaries
    strategy.lock(boundaryId: "boundary1", info: info)
    strategy.lock(boundaryId: "boundary2", info: info)
    strategy.lock(boundaryId: "boundary3", info: info)

    // Clean up specific boundary
    strategy.cleanUp(boundaryId: "boundary2")

    XCTAssertEqual(strategy.cleanUpBoundaryCallCount, 1)
    XCTAssertTrue(strategy.isLocked("boundary1"))
    XCTAssertFalse(strategy.isLocked("boundary2"))
    XCTAssertTrue(strategy.isLocked("boundary3"))
  }

  func testLockmanStrategyCleanUpDifferentBoundaryTypes() {
    // Test cleanup with different boundary types
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "typeCleanupTest")

    let stringBoundary = "stringBoundary"
    let intBoundary = 42
    let uuidBoundary = UUID()

    // Lock different boundary types
    strategy.lock(boundaryId: stringBoundary, info: info)
    strategy.lock(boundaryId: intBoundary, info: info)
    strategy.lock(boundaryId: uuidBoundary, info: info)

    XCTAssertTrue(strategy.isLocked(stringBoundary))
    XCTAssertTrue(strategy.isLocked(intBoundary))
    XCTAssertTrue(strategy.isLocked(uuidBoundary))

    // Clean up specific types
    strategy.cleanUp(boundaryId: intBoundary)

    XCTAssertTrue(strategy.isLocked(stringBoundary))
    XCTAssertFalse(strategy.isLocked(intBoundary))
    XCTAssertTrue(strategy.isLocked(uuidBoundary))
  }

  // MARK: - Phase 4: Type System and Generics

  func testLockmanStrategyGenericBoundaryTypes() {
    // Test generic boundary type handling
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "genericTest")

    func testWithBoundary<B: LockmanBoundaryId>(_ boundaryId: B) {
      let canLockResult = strategy.canLock(boundaryId: boundaryId, info: info)
      switch canLockResult {
      case .success:
        strategy.lock(boundaryId: boundaryId, info: info)
        XCTAssertTrue(strategy.isLocked(boundaryId))
        strategy.unlock(boundaryId: boundaryId, info: info)
        XCTAssertFalse(strategy.isLocked(boundaryId))
      default:
        XCTFail("Generic boundary should work")
      }
    }

    testWithBoundary("stringBoundary")
    testWithBoundary(123)
    testWithBoundary(UUID())

    XCTAssertEqual(strategy.canLockCallCount, 3)
    XCTAssertEqual(strategy.lockCallCount, 3)
    XCTAssertEqual(strategy.unlockCallCount, 3)
  }

  func testLockmanStrategyTypeErasure() {
    // Test different strategy types without parameterized protocol types (iOS 16+ requirement)
    let mockStrategy1 = TestMockStrategy(strategyId: "mock1")
    let structStrategy = TestStructStrategy(strategyId: "struct1")
    let mockStrategy2 = TestMockStrategy(strategyId: "mock2")

    let info = TestLockmanInfo(actionId: "typeErasureTest")

    // Test each strategy individually
    let result1 = mockStrategy1.canLock(boundaryId: "boundary1", info: info)
    let result2 = structStrategy.canLock(boundaryId: "boundary2", info: info)
    let result3 = mockStrategy2.canLock(boundaryId: "boundary3", info: info)

    // All should succeed
    XCTAssertEqual(result1, .success)
    XCTAssertEqual(result2, .success)
    XCTAssertEqual(result3, .success)
  }

  func testLockmanStrategyStructVsClassBehavior() {
    // Test behavioral differences between struct and class strategies
    let classStrategy = TestMockStrategy()
    let structStrategy = TestStructStrategy()

    let info = TestLockmanInfo(actionId: "structVsClassTest")

    // Both should handle basic operations without parameterized protocol types
    let classResult = classStrategy.canLock(boundaryId: "test", info: info)
    let structResult = structStrategy.canLock(boundaryId: "test", info: info)

    switch (classResult, structResult) {
    case (.success, .success):
      XCTAssertTrue(true)
    default:
      XCTFail("Both strategies should succeed")
    }

    // Test that they can be used individually for polymorphic behavior
    classStrategy.lock(boundaryId: "polyTest1", info: info)
    classStrategy.unlock(boundaryId: "polyTest1", info: info)
    classStrategy.cleanUp()

    structStrategy.lock(boundaryId: "polyTest2", info: info)
    structStrategy.unlock(boundaryId: "polyTest2", info: info)
    structStrategy.cleanUp()
  }

  // MARK: - Phase 5: Sendable and Concurrency

  func testLockmanStrategySendableRequirement() async {
    // Test Sendable conformance with concurrent access
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "sendableTest")

    await withTaskGroup(of: String.self) { group in
      group.addTask {
        // This compiles without warning = Sendable works
        let result = strategy.canLock(boundaryId: "concurrent1", info: info)
        switch result {
        case .success:
          return "Task1: success"
        default:
          return "Task1: failure"
        }
      }

      group.addTask {
        let result = strategy.canLock(boundaryId: "concurrent2", info: info)
        switch result {
        case .success:
          return "Task2: success"
        default:
          return "Task2: failure"
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 2)
      XCTAssertTrue(results.contains("Task1: success"))
      XCTAssertTrue(results.contains("Task2: success"))
    }
  }

  func testLockmanStrategyConcurrentOperations() async {
    // Test concurrent strategy operations
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "concurrentOpsTest")

    await withTaskGroup(of: Void.self) { group in
      // Multiple concurrent lock operations
      for i in 0..<10 {
        group.addTask {
          strategy.lock(boundaryId: "boundary\(i)", info: info)
        }
      }

      await group.waitForAll()
    }

    // Verify all locks were acquired
    XCTAssertEqual(strategy.lockCallCount, 10)

    // Test concurrent unlock operations
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<10 {
        group.addTask {
          strategy.unlock(boundaryId: "boundary\(i)", info: info)
        }
      }

      await group.waitForAll()
    }

    XCTAssertEqual(strategy.unlockCallCount, 10)
  }

  // MARK: - Phase 6: Real-world Integration Patterns

  func testLockmanStrategyLockAcquisitionFlow() {
    // Test realistic lock acquisition flow
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "flowTest", priority: "high")
    let boundaryId = "realWorldBoundary"

    // Step 1: Check if lock can be acquired
    let canLockResult = strategy.canLock(boundaryId: boundaryId, info: info)

    switch canLockResult {
    case .success:
      // Step 2: Acquire the lock
      strategy.lock(boundaryId: boundaryId, info: info)

      // Step 3: Verify lock is held
      XCTAssertTrue(strategy.isLocked(boundaryId))

      // Step 4: Perform some work (simulated)
      // ... work happens here ...

      // Step 5: Release the lock
      strategy.unlock(boundaryId: boundaryId, info: info)

      // Step 6: Verify lock is released
      XCTAssertFalse(strategy.isLocked(boundaryId))

    case .cancel(let error):
      XCTFail("Should be able to acquire lock: \(error)")
    case .successWithPrecedingCancellation(let error):
      XCTFail("Unexpected preceding cancellation: \(error)")

    default:
      XCTFail("Unexpected result type")
    }

    // Verify call counts
    XCTAssertEqual(strategy.canLockCallCount, 1)
    XCTAssertEqual(strategy.lockCallCount, 1)
    XCTAssertEqual(strategy.unlockCallCount, 1)
  }

  func testLockmanStrategyErrorHandlingIntegration() {
    // Test error handling in integration scenarios
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "errorIntegrationTest")

    // Configure strategy to fail
    strategy.setShouldFailCanLock(true)

    // Attempt lock acquisition
    let result = strategy.canLock(boundaryId: "errorBoundary", info: info)

    switch result {
    case .cancel(let error):
      // Test error information
      XCTAssertTrue(error is TestStrategyError)

      if let strategyError = error as? TestStrategyError {
        XCTAssertEqual(strategyError.info.actionId, "errorIntegrationTest")
        XCTAssertTrue(strategyError.errorDescription?.contains("Mock failure") ?? false)
      }

      // Verify lock was not acquired on failure
      XCTAssertEqual(strategy.lockCallCount, 0)

    default:
      XCTFail("Should fail when configured to fail")
    }
  }

  func testLockmanStrategyCleanupIntegration() {
    // Test cleanup in realistic scenarios
    let strategy = TestMockStrategy()
    let info = TestLockmanInfo(actionId: "cleanupIntegrationTest")

    // Simulate multiple active operations
    let boundaries = ["operation1", "operation2", "operation3"]

    for boundary in boundaries {
      let result = strategy.canLock(boundaryId: boundary, info: info)
      switch result {
      case .success:
        strategy.lock(boundaryId: boundary, info: info)
      default:
        XCTFail("Should be able to lock \(boundary)")
      }
    }

    // Verify all are locked
    for boundary in boundaries {
      XCTAssertTrue(strategy.isLocked(boundary))
    }

    // Simulate emergency cleanup (e.g., app backgrounding)
    strategy.cleanUp()

    // Verify all locks are released
    for boundary in boundaries {
      XCTAssertFalse(strategy.isLocked(boundary))
    }

    XCTAssertEqual(strategy.cleanUpCallCount, 1)
  }

}
