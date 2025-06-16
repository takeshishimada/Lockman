
import Foundation
import XCTest
@testable import LockmanCore

// MARK: - Test Helpers

private struct TestBoundaryId: LockmanBoundaryId {
  let value: String

  init(_ value: String) {
    self.value = value
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: TestBoundaryId, rhs: TestBoundaryId) -> Bool {
    lhs.value == rhs.value
  }
}

private struct TestLockmanInfo: LockmanInfo, Sendable, Equatable {
  let actionId: String
  let uniqueId: UUID = .init()
  var description: String { "ActionId: \(actionId)" }

  var debugDescription: String {
    "TestLockmanInfo(actionId: \(actionId))"
  }
}

// Mock strategy to track unlock calls
private final class MockLockmanStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = TestLockmanInfo

  var strategyId: LockmanStrategyId { LockmanStrategyId(type: Self.self) }

  static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }

  private var unlockCalls: [(boundaryId: Any, info: TestLockmanInfo)] = []
  private let unlockQueue = DispatchQueue(label: "mock.unlock.queue")
  private var lockCallCount = 0
  var unlockCallCount = 0

  var specificUnlockCallCount: Int {
    unlockQueue.sync { unlockCalls.count }
  }

  func getUnlockCalls() -> [(boundaryId: Any, info: TestLockmanInfo)] {
    unlockQueue.sync { unlockCalls }
  }

  func resetCalls() {
    unlockQueue.sync {
      unlockCalls.removeAll()
      lockCallCount = 0
      unlockCallCount = 0
    }
  }

  func canLock<B: LockmanBoundaryId>(
    id _: B,
    info _: TestLockmanInfo
  ) -> LockResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(
    id _: B,
    info _: TestLockmanInfo
  ) {}

  func unlock<B: LockmanBoundaryId>(id: B, info: TestLockmanInfo) {
    unlockQueue.sync {
      unlockCalls.append((boundaryId: id, info: info))
      unlockCallCount += 1
    }
  }

  func cleanUp() {}

  func cleanUp<B: LockmanBoundaryId>(id _: B) {}

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    [:]
  }
}

// MARK: - LockmanUnlock Tests

final class LockmanUnlockTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitializeWithBoundaryIdInfoAndStrategy() async throws {
    let container = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("test")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      // Create type-erased strategy for LockmanUnlock
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      XCTAssertEqual(strategy.unlockCallCount, 0)

      unlock()

      XCTAssertEqual(strategy.unlockCallCount, 1)
    }
  }

  func testInitializeWithDifferentBoundaryIdTypes() async throws {
    struct AnotherBoundaryId: LockmanBoundaryId {
      let name: String
    }

    let container  = LockmanStrategyContainer()
    let boundaryId = AnotherBoundaryId(name: "another")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      XCTAssertEqual(strategy.unlockCallCount, 0)

      unlock()

      XCTAssertEqual(strategy.unlockCallCount, 1)
    }
  }

  func testInitializeWithDifferentInfoTypes() async throws {
    let container  = LockmanStrategyContainer()

    // Register all strategies using the new protocol-based approach
    let singleStrategy = LockmanSingleExecutionStrategy.shared
    let priorityStrategy = LockmanPriorityBasedStrategy.shared
    let customStrategy = MockLockmanStrategy()
    try? container.register(singleStrategy)
    try? container.register(priorityStrategy)
    try? container.register(customStrategy)

    await Lockman.withTestContainer(container) {
      // Test with LockmanSingleExecutionInfo
      let boundaryId1 = TestBoundaryId("single")
      let singleInfo = LockmanSingleExecutionInfo(actionId: "single", mode: .boundary)
      let singleAnyStrategy = AnyLockmanStrategy(singleStrategy)
      let singleUnlock = LockmanUnlock(id: boundaryId1, info: singleInfo, strategy: singleAnyStrategy, unlockOption: .immediate)

      // Test with LockmanPriorityBasedInfo
      let boundaryId2 = TestBoundaryId("priority")
      let priorityInfo = LockmanPriorityBasedInfo(actionId: "priority", priority: .high(.exclusive))
      let priorityAnyStrategy = AnyLockmanStrategy(priorityStrategy)
      let priorityUnlock = LockmanUnlock(id: boundaryId2, info: priorityInfo, strategy: priorityAnyStrategy, unlockOption: .immediate)

      // Test with custom TestLockmanInfo
      let boundaryId3 = TestBoundaryId("custom")
      let customInfo = TestLockmanInfo(actionId: "custom")
      let customAnyStrategy = AnyLockmanStrategy(customStrategy)
      let customUnlock = LockmanUnlock(id: boundaryId3, info: customInfo, strategy: customAnyStrategy, unlockOption: .immediate)

      // All should compile and initialize without issues
      // Type safety ensures info and strategy types are compatible

      // Verify they don't interfere with each other
      singleUnlock() // Should work
      priorityUnlock() // Should work
      customUnlock() // Should work

      // Verify custom strategy received the call
      XCTAssertEqual(customStrategy.unlockCallCount, 1)
    }
  }

  // MARK: - Convenience Initializer Tests

  // MARK: - CallAsFunction Tests

  func testCallAsFunctionInvokesStrategyUnlock() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("test")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      XCTAssertEqual(strategy.unlockCallCount, 0)

      // Call the unlock function
      unlock()

      XCTAssertEqual(strategy.unlockCallCount, 1)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 1)
      XCTAssertEqual((calls[0].boundaryId as? TestBoundaryId)?.value, "test")
      XCTAssertEqual(calls[0].info.actionId, "action")
    }
  }

  func testCallAsFunctionCanBeCalledMultipleTimes() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("test")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      // Call multiple times
      unlock()
      unlock()
      unlock()

      XCTAssertEqual(strategy.unlockCallCount, 3)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 3)

      // All calls should have same parameters
      for call in calls {
        XCTAssertEqual((call.boundaryId as? TestBoundaryId)?.value, "test")
        XCTAssertEqual(call.info.actionId, "action")
      }
    }
  }

  func testCallAsFunctionWithDifferentBoundaryIds() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId1 = TestBoundaryId("test1")
    let boundaryId2 = TestBoundaryId("test2")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock1 = LockmanUnlock(id: boundaryId1, info: info, strategy: anyStrategy, unlockOption: .immediate)
      let unlock2 = LockmanUnlock(id: boundaryId2, info: info, strategy: anyStrategy, unlockOption: .immediate)

      unlock1()
      unlock2()

      XCTAssertEqual(strategy.unlockCallCount, 2)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 2)
      XCTAssertEqual((calls[0].boundaryId as? TestBoundaryId)?.value, "test1")
      XCTAssertEqual((calls[1].boundaryId as? TestBoundaryId)?.value, "test2")
    }
  }

  func testCallAsFunctionWithDifferentInfo() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("test")
    let info1 = TestLockmanInfo(actionId: "action1")
    let info2 = TestLockmanInfo(actionId: "action2")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock1 = LockmanUnlock(id: boundaryId, info: info1, strategy: anyStrategy, unlockOption: .immediate)
      let unlock2 = LockmanUnlock(id: boundaryId, info: info2, strategy: anyStrategy, unlockOption: .immediate)

      unlock1()
      unlock2()

      XCTAssertEqual(strategy.unlockCallCount, 2)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 2)
      XCTAssertEqual(calls[0].info.actionId, "action1")
      XCTAssertEqual(calls[1].info.actionId, "action2")
    }
  }

  func testCallAsFunctionWithDifferentStrategies() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("test")
    let info = TestLockmanInfo(actionId: "action")
    let strategy1 = MockLockmanStrategy()
    let strategy2 = MockLockmanStrategy()

    // Note: Cannot register two instances of the same strategy type in the container
    // This test uses separate strategy instances with type erasure
    try? container.register(strategy1)

    await Lockman.withTestContainer(container) {
      let anyStrategy1 = AnyLockmanStrategy(strategy1)
      let anyStrategy2 = AnyLockmanStrategy(strategy2)

      let unlock1 = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy1, unlockOption: .immediate)
      let unlock2 = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy2, unlockOption: .immediate)

      unlock1()
      unlock2()

      XCTAssertEqual(strategy1.unlockCallCount, 1)
      XCTAssertEqual(strategy2.unlockCallCount, 1)

      let calls1  = strategy1.getUnlockCalls()
      let calls2 = strategy2.getUnlockCalls()

      XCTAssertEqual(calls1.count, 1)
      XCTAssertEqual(calls2.count, 1)
      XCTAssertEqual(calls1[0].info.actionId, "action")
      XCTAssertEqual(calls2[0].info.actionId, "action")
    }
  }

  // MARK: - Integration Tests with Real Strategies

  func testIntegrationWithLockmanSingleExecutionStrategy() async throws {
    let container  = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy.shared
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let boundaryId = TestBoundaryId("single")
      let info = LockmanSingleExecutionInfo(actionId: "action", mode: .boundary)

      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      // Should not crash when called
      unlock()

      // Can be called multiple times without issues
      unlock()
      unlock()
    }
  }

  func testIntegrationWithLockmanPriorityBasedStrategy() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanPriorityBasedStrategy.shared
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let boundaryId = TestBoundaryId("priority")
      let info = LockmanPriorityBasedInfo(actionId: "action", priority: .high(.exclusive))

      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      // Should not crash when called
      unlock()

      // Can be called multiple times without issues
      unlock()
      unlock()
    }
  }

  // MARK: - LockmanAutoUnlock Tests

  func testLockmanAutoUnlockAutomaticCleanup() async throws {
    let container = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("auto-deinit")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      do {
        let anyStrategy = AnyLockmanStrategy(strategy)
        let unlockToken = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)
        let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)

        XCTAssertEqual(strategy.unlockCallCount, 0)
        let isLocked  = await autoUnlock.isLocked
        XCTAssertEqual(isLocked, true)

        // autoUnlock will be deallocated here, triggering deinit
      }

      // Give some time for deinit to be called
      try? await Task.sleep(for: .milliseconds(10))

      XCTAssertEqual(strategy.unlockCallCount, 1)
    }
  }

  // MARK: - Sendable Conformance Tests

  func testSendableAcrossConcurrentContexts() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("concurrent")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      await withTaskGroup(of: Void.self) { group in
        // Test that LockmanUnlock can be passed across concurrent contexts
        for _ in 0 ..< 5 {
          group.addTask {
            unlock()
          }
        }
      }

      XCTAssertEqual(strategy.unlockCallCount, 5)
    }
  }

  func testConcurrentUnlockCallsAreThreadSafe() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("thread-safe")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      // Execute many concurrent unlock calls
      await withTaskGroup(of: Void.self) { group in
        for _ in 0 ..< 100 {
          group.addTask {
            unlock()
          }
        }
      }

      // All calls should be recorded
      XCTAssertEqual(strategy.unlockCallCount, 100)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 100)

      // All calls should have correct parameters
      for call in calls {
        XCTAssertEqual((call.boundaryId as? TestBoundaryId)?.value, "thread-safe")
        XCTAssertEqual(call.info.actionId, "action")
      }
    }
  }

  // MARK: - Memory Management Tests

  func testUnlockInstanceLifecycle() async throws {
    let container  = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("lifecycle")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      var unlock: LockmanUnlock? = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      // Use the unlock
      unlock?()
      XCTAssertEqual(strategy.unlockCallCount, 1)

      // Release the unlock instance
      unlock  = nil

      // Strategy should still have the call recorded
      XCTAssertEqual(strategy.unlockCallCount, 1)
    }
  }

  func testMultipleUnlockInstancesWithSameParameters() async throws {
    let container = LockmanStrategyContainer()
    let boundaryId = TestBoundaryId("multiple")
    let info = TestLockmanInfo(actionId: "action")
    let strategy = MockLockmanStrategy()
    try? container.register(strategy)

    await Lockman.withTestContainer(container) {
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock1 = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)
      let unlock2 = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)
      let unlock3 = LockmanUnlock(id: boundaryId, info: info, strategy: anyStrategy, unlockOption: .immediate)

      unlock1()
      unlock2()
      unlock3()

      XCTAssertEqual(strategy.unlockCallCount, 3)

      let calls  = strategy.getUnlockCalls()
      XCTAssertEqual(calls.count, 3)

      // All should have the same parameters
      for call in calls {
        XCTAssertEqual((call.boundaryId as? TestBoundaryId)?.value, "multiple")
        XCTAssertEqual(call.info.actionId, "action")
      }
    }
  }
}
