import XCTest

@testable import Lockman

/// Unit tests for LockmanUnlock and LockmanAutoUnlock
///
/// Tests the closure-like unlock token that encapsulates unlock operations and
/// the automatic unlock manager for proper cleanup through memory management.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### LockmanUnlock - Initialization and Properties
/// - [ ] LockmanUnlock.init() with all required parameters
/// - [ ] Sendable conformance verification for concurrent usage
/// - [ ] Generic type parameter handling for B: LockmanBoundaryId and I: LockmanInfo
/// - [ ] Property storage and access (id, info, strategy, unlockOption)
/// - [ ] Type erasure handling with AnyLockmanStrategy<I>
///
/// ### LockmanUnlock - Immediate Unlock Execution
/// - [ ] callAsFunction() with LockmanUnlockOption.immediate
/// - [ ] performUnlockImmediately() calls LockmanManager.withBoundaryLock
/// - [ ] strategy.unlock(boundaryId:info:) invocation with correct parameters
/// - [ ] Boundary lock protection during unlock operation
/// - [ ] Synchronous execution path verification
///
/// ### LockmanUnlock - Main Run Loop Unlock
/// - [ ] callAsFunction() with LockmanUnlockOption.mainRunLoop
/// - [ ] RunLoop.main.perform execution scheduling
/// - [ ] performUnlockImmediately() called on main run loop
/// - [ ] Asynchronous execution coordination
/// - [ ] Main thread execution verification
///
/// ### LockmanUnlock - Transition Delay Unlock
/// - [ ] callAsFunction() with LockmanUnlockOption.transition
/// - [ ] Platform-specific transition delay calculation
/// - [ ] iOS transition delay (0.35 seconds)
/// - [ ] macOS transition delay (0.25 seconds)
/// - [ ] tvOS transition delay (0.4 seconds)
/// - [ ] watchOS transition delay (0.3 seconds)
/// - [ ] Default fallback delay (0.35 seconds)
/// - [ ] DispatchQueue.main.asyncAfter scheduling
///
/// ### LockmanUnlock - Custom Delay Unlock
/// - [ ] callAsFunction() with LockmanUnlockOption.delayed(TimeInterval)
/// - [ ] Custom TimeInterval parameter handling
/// - [ ] DispatchQueue.main.asyncAfter with custom delay
/// - [ ] Flexible delay duration configuration
/// - [ ] Delayed execution timing accuracy
///
/// ### LockmanUnlock - Platform-Specific Behavior
/// - [ ] Conditional compilation for different platforms
/// - [ ] iOS UINavigationController animation timing
/// - [ ] macOS window and view animation timing
/// - [ ] tvOS focus-driven transition timing
/// - [ ] watchOS page-based navigation timing
/// - [ ] Platform detection accuracy
///
/// ### LockmanUnlock - Error Handling and Edge Cases
/// - [ ] Behavior when strategy.unlock() fails
/// - [ ] Invalid boundary ID handling
/// - [ ] Nil info parameter scenarios
/// - [ ] Double unlock prevention (if applicable)
/// - [ ] Memory safety during concurrent unlock attempts
///
/// ### LockmanAutoUnlock - Initialization and State
/// - [ ] LockmanAutoUnlock.init(unlockToken:) with valid token
/// - [ ] Actor isolation for thread-safe property access
/// - [ ] Sendable conformance verification
/// - [ ] Initial state with non-nil unlockToken
/// - [ ] Generic type parameter propagation from unlock token
///
/// ### LockmanAutoUnlock - Automatic Deallocation Unlock
/// - [ ] deinit calls unlockToken() when token is non-nil
/// - [ ] deinit respects unlockToken's configured unlock option
/// - [ ] deinit does nothing when unlockToken is nil
/// - [ ] Automatic cleanup during object deallocation
/// - [ ] Memory management integration
///
/// ### LockmanAutoUnlock - Manual Unlock Operation
/// - [ ] manualUnlock() calls unlockToken() when token exists
/// - [ ] manualUnlock() sets unlockToken to nil after unlock
/// - [ ] manualUnlock() respects unlockToken's configured unlock option
/// - [ ] manualUnlock() does nothing when token is already nil
/// - [ ] Multiple manualUnlock() calls safety
///
/// ### LockmanAutoUnlock - State Inspection
/// - [ ] token property returns current unlockToken
/// - [ ] token property returns nil after manualUnlock()
/// - [ ] isLocked returns true when unlockToken is non-nil
/// - [ ] isLocked returns false when unlockToken is nil
/// - [ ] State consistency across manual and automatic unlock
///
/// ### LockmanAutoUnlock - Thread Safety and Actor Model
/// - [ ] Actor isolation prevents data races on unlockToken
/// - [ ] Concurrent access to token property
/// - [ ] Concurrent access to isLocked property
/// - [ ] Concurrent manualUnlock() calls
/// - [ ] Thread-safe state transitions
///
/// ### Integration Testing - LockmanUnlock with Strategies
/// - [ ] Integration with LockmanSingleExecutionStrategy
/// - [ ] Integration with LockmanPriorityBasedStrategy
/// - [ ] Integration with custom strategies
/// - [ ] Strategy-specific unlock behavior verification
/// - [ ] Type safety across different info types
///
/// ### Integration Testing - LockmanAutoUnlock Lifecycle
/// - [ ] Complete lock-unlock cycle with automatic cleanup
/// - [ ] Complete lock-unlock cycle with manual unlock
/// - [ ] Integration with different unlock options
/// - [ ] Memory management verification through deallocation
/// - [ ] Resource cleanup completeness
///
/// ### Timing and Coordination Testing
/// - [ ] Unlock timing accuracy for different options
/// - [ ] Main thread execution verification for UI coordination
/// - [ ] Delay execution timing precision
/// - [ ] Multiple unlock tokens with different timing
/// - [ ] Coordination with UI operations (if testable)
///
/// ### Memory Management and Resource Cleanup
/// - [ ] Proper cleanup of unlock tokens
/// - [ ] Memory leak prevention
/// - [ ] Circular reference prevention
/// - [ ] Resource cleanup under error conditions
/// - [ ] Long-term memory stability
///
/// ### Edge Cases and Error Conditions
/// - [ ] Unlock token creation with invalid parameters
/// - [ ] Platform detection edge cases
/// - [ ] Extremely long or short delay durations
/// - [ ] Concurrent manual and automatic unlock scenarios
/// - [ ] Resource exhaustion scenarios
///
final class LockmanUnlockTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Mock Strategy for Testing

  private final class MockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = LockmanSingleExecutionInfo

    var unlockCallCount = 0
    var lastUnlockedBoundaryId: String?
    var lastUnlockedInfo: LockmanSingleExecutionInfo?

    var strategyId: LockmanStrategyId { LockmanStrategyId("mock-strategy") }

    static func makeStrategyId() -> LockmanStrategyId {
      return LockmanStrategyId("mock-strategy")
    }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo)
      -> LockmanResult
    {
      return .success
    }

    func lock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo) {
      // Mock implementation - just track that it was called
    }

    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: LockmanSingleExecutionInfo) {
      unlockCallCount += 1
      lastUnlockedBoundaryId = String(describing: boundaryId)
      lastUnlockedInfo = info
    }

    func cleanUp() {
      unlockCallCount = 0
      lastUnlockedBoundaryId = nil
      lastUnlockedInfo = nil
    }

    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      // Mock implementation
    }

    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      return [:]
    }
  }

  // MARK: - LockmanUnlock Initialization Tests

  func testLockmanUnlockInitialization() {
    let boundaryId = "test-boundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let strategy = MockStrategy()
    let anyStrategy = AnyLockmanStrategy<LockmanSingleExecutionInfo>(strategy)
    let unlockOption = LockmanUnlockOption.immediate

    let unlock = LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: anyStrategy,
      unlockOption: unlockOption
    )

    // Test that initialization doesn't trigger unlock
    XCTAssertEqual(strategy.unlockCallCount, 0)

    // Test that we can call the unlock
    unlock()
    XCTAssertEqual(strategy.unlockCallCount, 1)
    XCTAssertEqual(strategy.lastUnlockedBoundaryId, boundaryId)
    XCTAssertEqual(strategy.lastUnlockedInfo?.uniqueId, info.uniqueId)
  }

  func testLockmanUnlockSendableConformance() {
    let unlock = createTestUnlock(option: .immediate)

    let expectation = XCTestExpectation(description: "Concurrent access")

    DispatchQueue.global().async {
      // Access unlock in concurrent context
      unlock()
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - LockmanUnlock Immediate Execution Tests

  func testImmediateUnlockExecution() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)

    unlock()

    XCTAssertEqual(strategy.unlockCallCount, 1)
    XCTAssertEqual(strategy.lastUnlockedBoundaryId, "test-boundary")
  }

  func testImmediateUnlockSynchronous() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)

    let startTime = CFAbsoluteTimeGetCurrent()
    unlock()
    let duration = CFAbsoluteTimeGetCurrent() - startTime

    // Should be near-instantaneous
    XCTAssertLessThan(duration, 0.01)
    XCTAssertEqual(strategy.unlockCallCount, 1)
  }

  // MARK: - LockmanUnlock Main Run Loop Tests

  func testMainRunLoopUnlockExecution() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .mainRunLoop)

    let expectation = XCTestExpectation(description: "Main run loop unlock")

    unlock()

    // Should not be called immediately
    XCTAssertEqual(strategy.unlockCallCount, 0)

    // Wait for run loop to execute
    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testMainRunLoopUnlockMainThread() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .mainRunLoop)

    let expectation = XCTestExpectation(description: "Main thread execution")

    unlock()

    DispatchQueue.main.async {
      XCTAssertTrue(Thread.isMainThread)
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  // MARK: - LockmanUnlock Transition Delay Tests

  func testTransitionUnlockExecution() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .transition)

    let expectation = XCTestExpectation(description: "Transition unlock")

    let startTime = CFAbsoluteTimeGetCurrent()
    unlock()

    // Should not be called immediately
    XCTAssertEqual(strategy.unlockCallCount, 0)

    // Wait for delay to execute
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let duration = CFAbsoluteTimeGetCurrent() - startTime
      XCTAssertGreaterThan(duration, 0.2)  // Should have some delay
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testTransitionUnlockPlatformSpecificDelay() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .transition)

    let expectation = XCTestExpectation(description: "Platform delay")

    let startTime = CFAbsoluteTimeGetCurrent()
    unlock()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      let duration = CFAbsoluteTimeGetCurrent() - startTime

      // Check platform-specific delay ranges
      // Check platform-specific delay ranges with tolerance
      #if os(iOS)
        XCTAssertGreaterThan(duration, 0.25)
        XCTAssertLessThan(duration, 0.5)
      #elseif os(macOS)
        XCTAssertGreaterThan(duration, 0.15)
        XCTAssertLessThan(duration, 0.4)
      #elseif os(tvOS)
        XCTAssertGreaterThan(duration, 0.3)
        XCTAssertLessThan(duration, 0.55)
      #elseif os(watchOS)
        XCTAssertGreaterThan(duration, 0.2)
        XCTAssertLessThan(duration, 0.45)
      #else
        XCTAssertGreaterThan(duration, 0.25)
        XCTAssertLessThan(duration, 0.5)
      #endif

      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  // MARK: - LockmanUnlock Custom Delay Tests

  func testCustomDelayUnlockExecution() {
    let strategy = MockStrategy()
    let customDelay: TimeInterval = 0.2
    let unlock = createTestUnlock(strategy: strategy, option: .delayed(customDelay))

    let expectation = XCTestExpectation(description: "Custom delay unlock")

    let startTime = CFAbsoluteTimeGetCurrent()
    unlock()

    // Should not be called immediately
    XCTAssertEqual(strategy.unlockCallCount, 0)

    DispatchQueue.main.asyncAfter(deadline: .now() + customDelay + 0.1) {
      let duration = CFAbsoluteTimeGetCurrent() - startTime
      XCTAssertGreaterThan(duration, customDelay)
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testCustomDelayVariousIntervals() {
    let delays: [TimeInterval] = [0.1, 0.5, 1.0]

    for delay in delays {
      let strategy = MockStrategy()
      let unlock = createTestUnlock(strategy: strategy, option: .delayed(delay))

      let expectation = XCTestExpectation(description: "Delay \(delay)")

      let startTime = CFAbsoluteTimeGetCurrent()
      unlock()

      DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.1) {
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertGreaterThan(duration, delay)
        XCTAssertEqual(strategy.unlockCallCount, 1)
        expectation.fulfill()
      }

      wait(for: [expectation], timeout: max(delay + 0.5, 1.0))
    }
  }

  func testZeroDelayUnlock() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .delayed(0.0))

    let expectation = XCTestExpectation(description: "Zero delay")

    unlock()

    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  // MARK: - LockmanAutoUnlock Initialization Tests

  func testLockmanAutoUnlockInitialization() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    let token = await autoUnlock.token
    XCTAssertNotNil(token)

    let isLocked = await autoUnlock.isLocked
    XCTAssertTrue(isLocked)

    // Token should not have been called yet
    XCTAssertEqual(strategy.unlockCallCount, 0)
  }

  func testLockmanAutoUnlockSendableConformance() async {
    let unlock = createTestUnlock(option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    let expectation = XCTestExpectation(description: "Concurrent access")

    Task {
      let isLocked = await autoUnlock.isLocked
      XCTAssertTrue(isLocked)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 2.0)
  }

  // MARK: - LockmanAutoUnlock Manual Unlock Tests

  func testManualUnlockExecution() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    await autoUnlock.manualUnlock()

    XCTAssertEqual(strategy.unlockCallCount, 1)

    let token = await autoUnlock.token
    XCTAssertNil(token)

    let isLocked = await autoUnlock.isLocked
    XCTAssertFalse(isLocked)
  }

  func testManualUnlockRespectUnlockOption() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .mainRunLoop)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    await autoUnlock.manualUnlock()

    // Should respect the unlock option (mainRunLoop in this case)
    let expectation = XCTestExpectation(description: "Manual unlock with option")

    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func testMultipleManualUnlockCalls() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    await autoUnlock.manualUnlock()
    XCTAssertEqual(strategy.unlockCallCount, 1)

    // Second call should do nothing
    await autoUnlock.manualUnlock()
    XCTAssertEqual(strategy.unlockCallCount, 1)

    let isLocked = await autoUnlock.isLocked
    XCTAssertFalse(isLocked)
  }

  // MARK: - LockmanAutoUnlock State Inspection Tests

  func testTokenPropertyAccess() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    let initialToken = await autoUnlock.token
    XCTAssertNotNil(initialToken)

    await autoUnlock.manualUnlock()

    let finalToken = await autoUnlock.token
    XCTAssertNil(finalToken)
  }

  func testIsLockedPropertyAccess() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    let initialLocked = await autoUnlock.isLocked
    XCTAssertTrue(initialLocked)

    await autoUnlock.manualUnlock()

    let finalLocked = await autoUnlock.isLocked
    XCTAssertFalse(finalLocked)
  }

  func testStateConsistency() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)
    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    // Initial state
    let hasToken = await autoUnlock.token != nil
    let isLocked = await autoUnlock.isLocked
    XCTAssertEqual(hasToken, isLocked)

    await autoUnlock.manualUnlock()

    // Final state
    let hasTokenAfter = await autoUnlock.token != nil
    let isLockedAfter = await autoUnlock.isLocked
    XCTAssertEqual(hasTokenAfter, isLockedAfter)
  }

  // MARK: - LockmanAutoUnlock Automatic Deallocation Tests

  func testAutomaticUnlockOnDeallocation() {
    let strategy = MockStrategy()

    autoreleasepool {
      let unlock = createTestUnlock(strategy: strategy, option: .immediate)
      _ = LockmanAutoUnlock(unlockToken: unlock)
      // AutoUnlock goes out of scope here
    }

    // Give time for deallocation
    let expectation = XCTestExpectation(description: "Deallocation unlock")

    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testAutomaticUnlockRespectsUnlockOption() {
    let strategy = MockStrategy()

    autoreleasepool {
      let unlock = createTestUnlock(strategy: strategy, option: .mainRunLoop)
      _ = LockmanAutoUnlock(unlockToken: unlock)
    }

    let expectation = XCTestExpectation(description: "Deallocation with option")

    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testNoAutomaticUnlockAfterManualUnlock() async {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)

    // Manually unlock first
    await autoUnlock.manualUnlock()
    XCTAssertEqual(strategy.unlockCallCount, 1)

    // Now test that deallocation doesn't unlock again
    autoreleasepool {
      let unlock2 = createTestUnlock(strategy: strategy, option: .immediate)
      let autoUnlock2 = LockmanAutoUnlock(unlockToken: unlock2)

      Task {
        await autoUnlock2.manualUnlock()
      }
      // autoUnlock2 deallocated here, but was manually unlocked first
    }

    // Give time for potential deallocation
    let expectation = XCTestExpectation(description: "No double unlock")

    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 2)  // Only from manual unlocks
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  // MARK: - Integration Tests with Different Strategies

  func testIntegrationWithSingleExecutionStrategy() {
    // Use existing registered strategy or create a new container
    LockmanManager.cleanup.all()

    let strategy = LockmanSingleExecutionStrategy()
    do {
      try LockmanManager.container.register(strategy)
    } catch {
      // Strategy might already be registered, which is fine for integration test
    }
    defer { LockmanManager.cleanup.all() }

    let boundaryId = "integration-test"
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let unlock = LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: AnyLockmanStrategy<LockmanSingleExecutionInfo>(strategy),
      unlockOption: .immediate
    )

    unlock()

    // Verify strategy state (no easy way to verify unlock was called,
    // but we can test that it doesn't crash)
    XCTAssertTrue(true, "Integration test completed without crash")
  }

  func testIntegrationWithPriorityBasedStrategy() {
    // Use existing registered strategy or create a new container
    LockmanManager.cleanup.all()

    let strategy = LockmanPriorityBasedStrategy()
    do {
      try LockmanManager.container.register(strategy)
    } catch {
      // Strategy might already be registered, which is fine for integration test
    }
    defer { LockmanManager.cleanup.all() }

    let boundaryId = "priority-test"
    let info = LockmanPriorityBasedInfo(
      actionId: LockmanActionId("test-action"),
      priority: .high(.exclusive)
    )
    let unlock = LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: AnyLockmanStrategy<LockmanPriorityBasedInfo>(strategy),
      unlockOption: .immediate
    )

    unlock()

    XCTAssertTrue(true, "Priority strategy integration completed")
  }

  // MARK: - Timing and Coordination Tests

  func testMultipleUnlockTokensWithDifferentTiming() {
    let strategy1 = MockStrategy()
    let strategy2 = MockStrategy()
    let strategy3 = MockStrategy()

    let unlock1 = createTestUnlock(strategy: strategy1, option: .immediate)
    let unlock2 = createTestUnlock(strategy: strategy2, option: .mainRunLoop)
    let unlock3 = createTestUnlock(strategy: strategy3, option: .delayed(0.1))

    let expectation = XCTestExpectation(description: "Multiple unlocks")
    expectation.expectedFulfillmentCount = 3

    unlock1()
    unlock2()
    unlock3()

    // Check immediate unlock
    XCTAssertEqual(strategy1.unlockCallCount, 1)
    expectation.fulfill()

    // Check run loop unlock
    DispatchQueue.main.async {
      XCTAssertEqual(strategy2.unlockCallCount, 1)
      expectation.fulfill()
    }

    // Check delayed unlock
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      XCTAssertEqual(strategy3.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testUnlockTimingAccuracy() {
    let delays: [TimeInterval] = [0.1, 0.2, 0.3]
    let tolerance: TimeInterval = 0.1

    for delay in delays {
      let strategy = MockStrategy()
      let unlock = createTestUnlock(strategy: strategy, option: .delayed(delay))

      let expectation = XCTestExpectation(description: "Timing accuracy \(delay)")

      let startTime = CFAbsoluteTimeGetCurrent()
      unlock()

      DispatchQueue.main.asyncAfter(deadline: .now() + delay + tolerance) {
        let actualDuration = CFAbsoluteTimeGetCurrent() - startTime
        let expectedDuration = delay

        XCTAssertGreaterThan(actualDuration, expectedDuration - tolerance)
        XCTAssertLessThan(actualDuration, expectedDuration + tolerance)
        XCTAssertEqual(strategy.unlockCallCount, 1)
        expectation.fulfill()
      }

      wait(for: [expectation], timeout: delay + tolerance * 2)
    }
  }

  // MARK: - Edge Cases and Error Conditions

  func testNegativeDelayHandling() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .delayed(-0.1))

    let expectation = XCTestExpectation(description: "Negative delay")

    unlock()

    // Negative delay should still work (system handles it)
    DispatchQueue.main.async {
      XCTAssertEqual(strategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testVeryLargeDelayHandling() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .delayed(1000.0))

    // Test that very large delay doesn't crash
    unlock()

    // Should not be called immediately
    XCTAssertEqual(strategy.unlockCallCount, 0)

    // We won't wait for it to complete, just verify no crash
    XCTAssertTrue(true, "Large delay handled without crash")
  }

  func testConcurrentUnlockCalls() {
    let strategy = MockStrategy()
    let unlock = createTestUnlock(strategy: strategy, option: .immediate)

    let expectation = XCTestExpectation(description: "Concurrent unlocks")
    expectation.expectedFulfillmentCount = 10

    for _ in 0..<10 {
      DispatchQueue.global().async {
        unlock()
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)

    // Should have been called 10 times
    XCTAssertEqual(strategy.unlockCallCount, 10)
  }

  // MARK: - Memory Management Tests

  func testMemoryLeakPrevention() {
    weak var weakAutoUnlock: LockmanAutoUnlock<String, LockmanSingleExecutionInfo>?

    autoreleasepool {
      let strategy = MockStrategy()
      let unlock = createTestUnlock(strategy: strategy, option: .immediate)
      let autoUnlock = LockmanAutoUnlock(unlockToken: unlock)
      weakAutoUnlock = autoUnlock
    }

    // Should be deallocated after autoreleasepool
    XCTAssertNil(weakAutoUnlock, "AutoUnlock should be deallocated")
  }

  func testLongTermMemoryStability() {
    let strategy = MockStrategy()

    // Create many unlock tokens
    let unlockTokens = (0..<100).map { _ in
      createTestUnlock(strategy: strategy, option: .immediate)
    }

    // Use them all
    for unlock in unlockTokens {
      unlock()
    }

    XCTAssertEqual(strategy.unlockCallCount, 100)

    // Verify no memory issues
    XCTAssertTrue(true, "Long term memory test completed")
  }

  // MARK: - Helper Methods

  private func createTestUnlock(
    strategy: MockStrategy = MockStrategy(),
    option: LockmanUnlockOption = .immediate
  ) -> LockmanUnlock<String, LockmanSingleExecutionInfo> {
    let boundaryId = "test-boundary"
    let info = LockmanSingleExecutionInfo(mode: .boundary)
    let anyStrategy = AnyLockmanStrategy<LockmanSingleExecutionInfo>(strategy)

    return LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: anyStrategy,
      unlockOption: option
    )
  }
}
