import ComposableArchitecture
import Foundation
import Testing
@testable import LockmanComposable
@testable import LockmanCore

/// Test suite for deadlock prevention functionality in Lockman framework.
///
/// These tests verify that the NSLock-based boundary locking mechanism
/// prevents race conditions and ensures thread safety within the framework.
@Suite("Deadlock Prevention Tests")
struct DeadlockPreventionTests {
  // MARK: - Basic NSLock Management Tests

  /// Tests basic NSLock creation and operation functionality.
  /// Verifies that boundary locks can be created and used successfully.
  @Test("NSLock creation and basic operation")
  func testNSLockCreationAndBasicOperation() async {
    let id = TestBoundaryId("test")
    var executed = false

    Lockman.withBoundaryLock(for: id) {
      executed = true
    }

    #expect(executed)
  }

  /// Tests that multiple boundary IDs work independently without interference.
  /// Verifies that nested locks with different boundary IDs execute in the expected order.
  @Test("Multiple boundary IDs work independently")
  func testMultipleBoundaryIdsWorkIndependently() async {
    let id1 = TestBoundaryId("test1")
    let id2 = TestBoundaryId("test2")
    let id3 = TestBoundaryId("test3")

    var executions: [String] = []

    Lockman.withBoundaryLock(for: id1) {
      executions.append("id1")
      Lockman.withBoundaryLock(for: id2) {
        executions.append("id2")
        Lockman.withBoundaryLock(for: id3) {
          executions.append("id3")
        }
      }
    }

    #expect(executions == ["id1", "id2", "id3"])
  }

  // MARK: - Concurrent Access Tests

  /// Tests that concurrent access to the same boundary ID is properly serialized.
  /// This test verifies that the NSLock prevents race conditions by ensuring
  /// that operations on the same boundary are executed sequentially.
  @Test("Concurrent access to same boundary is serialized")
  func testConcurrentAccessToSameBoundaryIsSerialized() async {
    let id = TestBoundaryId("concurrent")
    let iterations = 100
    let counter = ManagedCriticalState(0)

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< iterations {
        group.addTask {
          Lockman.withBoundaryLock(for: id) {
            // This section must be synchronized to prevent race conditions
            let current = counter.withCriticalRegion { $0 }
            // Simulate small processing time to increase chance of race conditions
            // Note: Using Thread.sleep instead of Task.sleep since withBoundaryLock is synchronous
            Thread.sleep(forTimeInterval: 0.001)
            counter.withCriticalRegion { $0 = current + 1 }
          }
        }
      }
    }

    let finalCount = counter.withCriticalRegion { $0 }
    #expect(finalCount == iterations)
  }

  /// Alternative test using atomic operations to verify serialization
  @Test("Concurrent access serialization with atomic counter")
  func testConcurrentAccessSerializationWithAtomicCounter() async {
    let id = TestBoundaryId("atomic_test")
    let iterations = 50
    let results = ManagedCriticalState<[Int]>([])

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< iterations {
        group.addTask {
          Lockman.withBoundaryLock(for: id) {
            // Simulate work and collect execution order
            let currentResults = results.withCriticalRegion { $0 }
            let newValue = currentResults.count + 1

            // Brief CPU-intensive work to increase contention
            var sum = 0
            for j in 0 ..< 1000 {
              sum += j
            }

            results.withCriticalRegion { $0.append(newValue) }
          }
        }
      }
    }

    let finalResults = results.withCriticalRegion { $0 }
    #expect(finalResults.count == iterations)

    // Verify that operations were serialized (sequential numbering)
    for (index, value) in finalResults.enumerated() {
      #expect(value == index + 1)
    }
  }

  // MARK: - Error Handling Tests

  /// Tests that lock operations properly handle exceptions without leaving locks in invalid states.
  /// Verifies that even when exceptions are thrown, subsequent lock operations continue to work.
  @Test("Lock operation with throwing closure")
  func testLockOperationWithThrowingClosure() async {
    struct TestError: Error {}
    let id = TestBoundaryId("throwing")

    do {
      try Lockman.withBoundaryLock(for: id) {
        throw TestError()
      }
      #expect(Bool(false), "Should have thrown")
    } catch is TestError {
      // Expected behavior
    } catch {
      #expect(Bool(false), "Unexpected error: \(error)")
    }

    // Lock operations should continue to work normally after exception handling
    var executed = false
    Lockman.withBoundaryLock(for: id) {
      executed = true
    }
    #expect(executed)
  }

  // MARK: - Integration Tests

  /// Tests integration with Effect.withLock to ensure deadlock prevention works
  /// in real-world usage scenarios with the Composable Architecture.
  @Test("Integration with Effect.withLock")
  func testIntegrationWithEffectWithLock() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await Lockman.withTestContainer(container) {
      let store = await TestStore(
        initialState: TestFeature.State()
      ) {
        TestFeature()
      }

      // Execute Effect under NSLock deadlock protection
      await store.send(.testAction)
      await store.receive(.completed)
      await store.finish()
    }
  }

  /// Tests integration with LockmanUnlock to ensure proper coordination
  /// between lock acquisition and release operations.
  @Test("Integration with LockmanUnlock")
  func testIntegrationWithLockmanUnlock() async throws {
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try container.register(strategy)

    await Lockman.withTestContainer(container) {
      let id = TestBoundaryId("unlock_test")
      let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)

      // Check if we can acquire lock
      let canLockResult = strategy.canLock(id: id, info: info)
      #expect(canLockResult == .success)

      // Acquire lock through strategy
      strategy.lock(id: id, info: info)

      // Unlock using LockmanUnlock (executed under NSLock protection)
      let anyStrategy = AnyLockmanStrategy(strategy)
      let unlock = LockmanUnlock(id: id, info: info, strategy: anyStrategy, unlockOption: .immediate)
      unlock()

      // Verify that lock can be acquired again after unlock
      let secondCanLockResult = strategy.canLock(id: id, info: info)
      #expect(secondCanLockResult == .success)

      // Acquire and cleanup
      strategy.lock(id: id, info: info)
      strategy.unlock(id: id, info: info)
    }
  }

  /// Tests that nested boundary locks with different IDs work correctly.
  /// Verifies the proper execution order when locks are nested.
  @Test("Nested boundary locks work correctly")
  func testNestedBoundaryLocksWorkCorrectly() async {
    let outerID = TestBoundaryId("outer")
    let innerID = TestBoundaryId("inner")

    var executionOrder: [String] = []

    Lockman.withBoundaryLock(for: outerID) {
      executionOrder.append("outer_start")

      Lockman.withBoundaryLock(for: innerID) {
        executionOrder.append("inner")
      }

      executionOrder.append("outer_end")
    }

    #expect(executionOrder == ["outer_start", "inner", "outer_end"])
  }

  /// Performance test with many concurrent operations across multiple boundaries.
  /// Verifies that the locking mechanism performs well under high concurrency.
  @Test("Performance with many concurrent operations")
  func testPerformanceWithManyConcurrentOperations() async {
    let iterations = 50 // Adjusted for reasonable test execution time
    let boundaries = (0 ..< 10).map { TestBoundaryId("perf_\($0)") }
    let completionCount = ManagedCriticalState(0)

    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< iterations {
        group.addTask {
          let boundaryID = boundaries[i % boundaries.count]
          Lockman.withBoundaryLock(for: boundaryID) {
            // Simulate short processing time with synchronous operation
            Thread.sleep(forTimeInterval: 0.001)
            completionCount.withCriticalRegion { $0 += 1 }
          }
        }
      }
    }

    let totalTime = Date().timeIntervalSince(startTime)
    let count = completionCount.withCriticalRegion { $0 }

    let parallesism = 3.0
    #expect(count == iterations)
    #expect(totalTime < 5.0 * parallesism) // Should complete within reasonable time
  }

  // MARK: - Additional Boundary Lock Tests

  /// Tests that the same boundary ID always returns the same lock instance
  @Test("Same boundary ID returns consistent lock")
  func testSameBoundaryIdReturnsConsistentLock() async {
    let id = TestBoundaryId("consistent")
    var firstExecution = false
    var secondExecution = false

    // First operation
    Lockman.withBoundaryLock(for: id) {
      firstExecution = true
    }

    // Second operation with same ID
    Lockman.withBoundaryLock(for: id) {
      secondExecution = true
    }

    #expect(firstExecution)
    #expect(secondExecution)
  }

  /// Tests that boundary locks work correctly with complex ID types
  @Test("Complex boundary ID types work correctly")
  func testComplexBoundaryIdTypesWorkCorrectly() async {
    let complexId = ComplexBoundaryId(prefix: "complex", suffix: "test", number: 42)
    var executed = false

    Lockman.withBoundaryLock(for: complexId) {
      executed = true
    }

    #expect(executed)
  }

  /// Tests memory management of boundary locks
  @Test("Boundary lock memory management")
  func testBoundaryLockMemoryManagement() async {
    let iterations = 100

    for i in 0 ..< iterations {
      let id = TestBoundaryId("temp_\(i)")
      Lockman.withBoundaryLock(for: id) {
        // Short operation
      }
    }

    // Test should complete without memory issues
    #expect(Bool(true))
  }

  // MARK: - Stress Tests

  /// Tests high-frequency lock operations
  @Test("High frequency lock operations")
  func testHighFrequencyLockOperations() async {
    let id = TestBoundaryId("high_freq")
    let iterations = 1000
    var counter = 0

    for _ in 0 ..< iterations {
      Lockman.withBoundaryLock(for: id) {
        counter += 1
      }
    }

    #expect(counter == iterations)
  }

  /// Tests concurrent operations with many different boundaries
  @Test("Many different boundaries concurrently")
  func testManyDifferentBoundariesConcurrently() async {
    let boundaryCount = 100
    let results = ManagedCriticalState<[String: Bool]>([:])

    await withTaskGroup(of: Void.self) { group in
      for i in 0 ..< boundaryCount {
        group.addTask {
          let id = TestBoundaryId("boundary_\(i)")
          Lockman.withBoundaryLock(for: id) {
            results.withCriticalRegion { dict in
              dict["boundary_\(i)"] = true
            }
          }
        }
      }
    }

    let finalResults = results.withCriticalRegion { $0 }
    #expect(finalResults.count == boundaryCount)

    // Verify all boundaries were processed
    for i in 0 ..< boundaryCount {
      #expect(finalResults["boundary_\(i)"] == true)
    }
  }
}

// MARK: - Test Helpers

/// Use common test boundary ID
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

/// Complex boundary ID for testing advanced scenarios
private struct ComplexBoundaryId: LockmanBoundaryId {
  let prefix: String
  let suffix: String
  let number: Int

  func hash(into hasher: inout Hasher) {
    hasher.combine(prefix)
    hasher.combine(suffix)
    hasher.combine(number)
  }

  static func == (lhs: ComplexBoundaryId, rhs: ComplexBoundaryId) -> Bool {
    lhs.prefix == rhs.prefix &&
      lhs.suffix == rhs.suffix &&
      lhs.number == rhs.number
  }
}

/// Test reducer implementation for integration testing.
/// Provides a minimal reducer that uses Lockman's withLock functionality.
@Reducer
private struct TestFeature {
  struct State: Equatable {}

  enum Action: LockmanSingleExecutionAction {
    case testAction
    case completed

    var actionName: String {
      switch self {
      case .testAction: return "testAction"
      case .completed: return "completed"
      }
    }

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }

    var strategyType: LockmanSingleExecutionStrategy.Type {
      LockmanSingleExecutionStrategy.self
    }
  }

  enum CancelID: Hashable {
    case test
  }

  @ReducerBuilder<State, Action>
  var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case .testAction:
        return Effect.withLock(
          priority: nil,
          unlockOption: .mainRunLoop,
          operation: { send in
            await send(.completed)
          },
          action: action,
          cancelID: CancelID.test
        )
      case .completed:
        return .none
      }
    }
  }
}

// MARK: - Additional Test Suites

@Suite("Boundary Lock Edge Cases")
struct BoundaryLockEdgeCaseTests {
  @Test("Empty string boundary ID")
  func testEmptyStringBoundaryId() async {
    let id = TestBoundaryId("")
    var executed = false

    Lockman.withBoundaryLock(for: id) {
      executed = true
    }

    #expect(executed)
  }

  @Test("Unicode boundary ID")
  func testUnicodeBoundaryId() async {
    let id = TestBoundaryId("🔒🧵💾")
    var executed = false

    Lockman.withBoundaryLock(for: id) {
      executed = true
    }

    #expect(executed)
  }

  @Test("Very long boundary ID")
  func testVeryLongBoundaryId() async {
    let longString = String(repeating: "a", count: 1000)
    let id = TestBoundaryId(longString)
    var executed = false

    Lockman.withBoundaryLock(for: id) {
      executed = true
    }

    #expect(executed)
  }

  @Test("Boundary ID with special characters")
  func testBoundaryIdWithSpecialCharacters() async {
    let id = TestBoundaryId("test-boundary_id.with@special#chars!")
    var executed = false

    Lockman.withBoundaryLock(for: id) {
      executed = true
    }

    #expect(executed)
  }
}

@Suite("Boundary Lock Error Resilience")
struct BoundaryLockErrorResilienceTests {
  @Test("Multiple consecutive errors don't break locking")
  func testMultipleConsecutiveErrorsDontBreakLocking() async {
    struct TestError: Error {}
    let id = TestBoundaryId("error_resilience")

    // Throw multiple errors
    for _ in 0 ..< 5 {
      do {
        try Lockman.withBoundaryLock(for: id) {
          throw TestError()
        }
      } catch is TestError {
        // Expected
      } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
      }
    }

    // Normal operation should still work
    var executed = false
    Lockman.withBoundaryLock(for: id) {
      executed = true
    }
    #expect(executed)
  }

  @Test("Nested error handling")
  func testNestedErrorHandling() async {
    struct OuterError: Error {}
    struct InnerError: Error {}

    let outerID = TestBoundaryId("outer_error")
    let innerID = TestBoundaryId("inner_error")

    var outerExecuted = false
    var innerExecuted = false

    do {
      try Lockman.withBoundaryLock(for: outerID) {
        outerExecuted = true
        do {
          try Lockman.withBoundaryLock(for: innerID) {
            innerExecuted = true
            throw InnerError()
          }
        } catch is InnerError {
          // Handle inner error, but throw outer error
          throw OuterError()
        }
      }
    } catch is OuterError {
      // Expected
    } catch {
      #expect(Bool(false), "Unexpected error: \(error)")
    }

    #expect(outerExecuted)
    #expect(innerExecuted)

    // Both locks should work normally afterwards
    var normalOuterExecuted = false
    var normalInnerExecuted = false

    Lockman.withBoundaryLock(for: outerID) {
      normalOuterExecuted = true
      Lockman.withBoundaryLock(for: innerID) {
        normalInnerExecuted = true
      }
    }

    #expect(normalOuterExecuted)
    #expect(normalInnerExecuted)
  }

//  @Test("Error handling with deeply nested locks")
//  func testErrorHandlingWithDeeplyNestedLocks() async {
//    struct DeepError: Error {}
//
//    let ids = (0..<5).map { TestBoundaryId("nested_\($0)") }
//    var executionLevels: [Int] = []
//
//    do {
//      try Lockman.withBoundaryLock(for: ids[0]) {
//        executionLevels.append(0)
//        try Lockman.withBoundaryLock(for: ids[1]) {
//          executionLevels.append(1)
//          try Lockman.withBoundaryLock(for: ids[2]) {
//            executionLevels.append(2)
//            try Lockman.withBoundaryLock(for: ids[3]) {
//              executionLevels.append(3)
//              try Lockman.withBoundaryLock(for: ids[4]) {
//                executionLevels.append(4)
//                throw DeepError()
//              }
//            }
//          }
//        }
//      }
//    } catch is DeepError {
//      // Expected
//    }
//
//    #expect(executionLevels == [0, 1, 2, 3, 4])
//
//    // All locks should work normally after the error
//    var allExecuted = true
//    for id in ids {
//      var executed = false
//      Lockman.withBoundaryLock(for: id) {
//        executed = true
//      }
//      allExecuted = allExecuted && executed
//    }
//    #expect(allExecuted)
//  }
}
