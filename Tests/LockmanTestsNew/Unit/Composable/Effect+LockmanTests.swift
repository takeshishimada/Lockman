import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Support Types
// Shared test support types are defined in TestSupport.swift

/// Unit tests for Effect+Lockman
///
/// Tests Effect extensions providing lock management integration with ComposableArchitecture.
final class EffectLockmanTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Tests

  // MARK: - Effect.lock() Concatenating Method Tests

  func testLockConcatenatingWithMultipleEffects() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // First operation
        },
        Effect<SharedTestAction>.run { _ in
          // Second operation
        },
        Effect<SharedTestAction>.run { _ in
          // Third operation
        },
      ]

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithEmptyArray() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects: [Effect<SharedTestAction>] = []

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithSingleEffect() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Single operation
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithDifferentUnlockOptions() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation
        }
      ]

      let unlockOptions: [LockmanUnlockOption] = [
        .immediate,
        .delayed(1.0),
        .mainRunLoop,
        .transition,
      ]

      for unlockOption in unlockOptions {
        let lockedEffect = Effect.lock(
          concatenating: effects,
          unlockOption: unlockOption,
          action: action,
          boundaryId: boundaryId
        )

        XCTAssertNotNil(
          lockedEffect, "Effect should be created with unlock option: \(unlockOption)")
      }
    }
  }

  func testLockConcatenatingWithPriorityParameter() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation
        }
      ]

      let priorities: [TaskPriority?] = [
        nil,
        .high,
        .medium,
        .low,
        .background,
      ]

      for priority in priorities {
        let lockedEffect = Effect.lock(
          concatenating: effects,
          priority: priority,
          unlockOption: .immediate,
          action: action,
          boundaryId: boundaryId
        )

        XCTAssertNotNil(
          lockedEffect, "Effect should be created with priority: \(String(describing: priority))")
      }
    }
  }

  func testLockConcatenatingWithLockFailureHandler() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation
        }
      ]

      var handlerCalled = false
      let lockFailureHandler: (any Error, Send<SharedTestAction>) async -> Void = { _, _ in
        handlerCalled = true
      }

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        lockFailure: lockFailureHandler,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)
      // Handler should not be called during effect creation
      XCTAssertFalse(handlerCalled)
    }
  }

  func testLockConcatenatingWithHandleCancellationErrors() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation
        }
      ]

      // Test concatenating lock
      let effectHandlingErrors = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      // Test another concatenating lock
      let effectIgnoringErrors = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(effectHandlingErrors)
      XCTAssertNotNil(effectIgnoringErrors)
    }
  }

  func testLockConcatenatingWithAllParameters() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation 1
        },
        Effect<SharedTestAction>.run { _ in
          // Test operation 2
        },
      ]

      actor HandlerCheck {
        private var handlerCalled = false
        func setHandlerCalled() { handlerCalled = true }
        func getHandlerCalled() -> Bool { handlerCalled }
      }

      let handlerCheck = HandlerCheck()
      let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = {
        _, _ in
        await handlerCheck.setHandlerCalled()
      }

      let lockedEffect = Effect.lock(
        concatenating: effects,
        priority: .high,
        unlockOption: .delayed(2.0),
        lockFailure: lockFailureHandler,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)

      // Handler should not be called during effect creation
      Task {
        let wasCalled = await handlerCheck.getHandlerCalled()
        XCTAssertFalse(wasCalled)
      }
    }
  }

  // MARK: - Error Handling Tests

  func testLockConcatenatingWithInvalidStrategy() async {
    // Use empty container to force strategy resolution error
    let emptyContainer = LockmanStrategyContainer()

    await LockmanManager.withTestContainer(emptyContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let effects = [
        Effect<SharedTestAction>.run { _ in
          // Test operation
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )

      // Should return effect (likely .none) even with strategy resolution error
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingErrorPropagation() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      var handlerCalledCount = 0
      let lockFailureHandler: (any Error, Send<SharedTestAction>) async -> Void = { _, _ in
        handlerCalledCount += 1
      }

      let effects = [
        Effect<SharedTestAction>.run { _ in
          throw EffectTestError.general
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        lockFailure: lockFailureHandler,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(lockedEffect)
      // Handler call count should be 0 during effect creation
      XCTAssertEqual(handlerCalledCount, 0)
    }
  }

  // MARK: - Integration Tests

  func testLockConcatenatingIntegrationWithLockmanAction() async {
    // Create a test action that conforms to LockmanAction
    struct TestLockmanAction: LockmanAction {
      let actionId: LockmanActionId = "test-lockman-action"

      func createLockmanInfo() -> TestLockmanInfo {
        return TestLockmanInfo(
          actionId: self.actionId,
          strategyId: TestSingleExecutionStrategy.makeStrategyId(),
          uniqueId: UUID()
        )
      }

      var lockmanBoundaryId: TestBoundaryId {
        return TestBoundaryId.test
      }

      var unlockOption: LockmanUnlockOption {
        return .immediate
      }
    }

    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let action = TestLockmanAction()

      let effects = [
        Effect<TestLockmanAction>.run { _ in
          // Test operation
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: action.unlockOption,
        action: action,
        boundaryId: action.lockmanBoundaryId
      )

      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingPerformanceCharacteristics() async {
    // Setup test strategy
    let strategy = TestSingleExecutionStrategy()
    let testContainer = LockmanStrategyContainer()
    try! testContainer.register(strategy)

    await LockmanManager.withTestContainer(testContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      // Create a large number of effects to test performance
      let effectCount = 100
      let effects = (0..<effectCount).map { index in
        Effect<SharedTestAction>.run { _ in
          // Simulated operation \(index)
        }
      }

      let startTime = Date()
      let lockedEffect = Effect.lock(
        concatenating: effects,
        unlockOption: .immediate,
        action: action,
        boundaryId: boundaryId
      )
      let endTime = Date()

      let executionTime = endTime.timeIntervalSince(startTime)

      XCTAssertNotNil(lockedEffect)
      // Performance should be reasonable even with many effects
      XCTAssertLessThan(executionTime, 1.0, "Effect concatenation should complete within 1 second")
    }
  }
}

// MARK: - Test Support

private enum EffectTestError: Error {
  case general
  case specific(String)
}
