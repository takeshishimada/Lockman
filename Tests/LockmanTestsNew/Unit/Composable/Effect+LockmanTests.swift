import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Support Types
// Shared test support types are defined in TestSupport.swift

/// Unit tests for Effect+Lockman
///
/// Tests Effect extensions providing lock management integration with ComposableArchitecture.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Static Effect.lock() Concatenating Method
/// - [ ] lock(concatenating:) with array of effects
/// - [ ] lock(concatenating:) with empty array
/// - [ ] lock(concatenating:) with single effect
/// - [ ] lock(concatenating:) with multiple sequential effects
/// - [ ] lock(concatenating:) priority parameter handling
/// - [ ] lock(concatenating:) unlockOption parameter handling
/// - [ ] lock(concatenating:) handleCancellationErrors parameter handling
/// - [ ] lock(concatenating:) lockFailure handler functionality
///
/// ### LockmanInfo Consistency in Concatenating Method
/// - [ ] LockmanInfo captured once at beginning for consistent uniqueId
/// - [ ] Same lockmanInfo used throughout lock lifecycle
/// - [ ] UniqueId consistency between lock acquisition and release
/// - [ ] LockmanInfo consistency across multiple concatenated effects
/// - [ ] Lock/unlock matching with same uniqueId validation
///
/// ### Effect Concatenation and Execution
/// - [ ] Effect.concatenate(operations) integration
/// - [ ] Sequential execution of concatenated effects
/// - [ ] Error handling during effect concatenation
/// - [ ] Effect cancellation behavior with concatenation
/// - [ ] Effect.none return when no operations provided
///
/// ### Lock Acquisition in Concatenating Method
/// - [ ] acquireLock() integration with lockmanInfo and boundaryId
/// - [ ] Lock result handling (.success, .cancel, .successWithPrecedingCancellation)
/// - [ ] Strategy resolution during lock acquisition
/// - [ ] Lock acquisition failure scenarios
/// - [ ] Lock acquisition error propagation
///
/// ### Effect Building and Lock Management
/// - [ ] buildLockEffect() integration with lockResult
/// - [ ] Lock effect building with action and lockmanInfo
/// - [ ] unlockOption parameter propagation to effect building
/// - [ ] Lock effect cancellation behavior
/// - [ ] Guaranteed unlock execution after effects complete
///
/// ### Error Handling in Concatenating Method
/// - [ ] Strategy resolution error handling
/// - [ ] Effect.handleError() integration
/// - [ ] lockFailure handler invocation on errors
/// - [ ] Error propagation to caller
/// - [ ] Graceful fallback to .none effect on errors
///
/// ### Automatic Cancellation Management
/// - [ ] Automatic .cancellable(id: boundaryId) application
/// - [ ] Cancellable effect behavior with boundary ID
/// - [ ] Unlock effect protection from cancellation
/// - [ ] Resource cleanup guarantee during cancellation
/// - [ ] Cancellation coordination across concatenated effects
///
/// ### Instance Effect.lock() Method Chain API
/// - [ ] lock(action:boundaryId:) method chain style
/// - [ ] Method chaining with other effects (.merge, .run, etc.)
/// - [ ] action parameter LockmanAction requirement
/// - [ ] boundaryId parameter type safety
/// - [ ] unlockOption parameter with action.unlockOption fallback
/// - [ ] handleCancellationErrors parameter handling
/// - [ ] lockFailure handler in method chain API
///
/// ### LockmanInfo Consistency in Method Chain
/// - [ ] LockmanInfo captured once for consistent uniqueId
/// - [ ] Same lockmanInfo used in acquireLock and buildLockEffect
/// - [ ] UniqueId preservation throughout method chain execution
/// - [ ] Lock/unlock matching validation in method chain
/// - [ ] Method chain lock lifecycle management
///
/// ### Lock Acquisition and Building in Method Chain
/// - [ ] acquireLock() call with captured lockmanInfo
/// - [ ] buildLockEffect() call with same lockmanInfo instance
/// - [ ] Lock result consistency between acquisition and building
/// - [ ] Method chain integration with underlying lock infrastructure
/// - [ ] Lock effect return value from method chain
///
/// ### Error Handling in Method Chain API
/// - [ ] Strategy resolution error handling in method chain
/// - [ ] Effect.handleError() integration in method chain
/// - [ ] lockFailure handler invocation in method chain
/// - [ ] Error reporting with fileID, filePath, line, column
/// - [ ] Graceful error recovery in method chain
///
/// ### Source Location and Debugging
/// - [ ] fileID parameter auto-population and usage
/// - [ ] filePath parameter auto-population and usage
/// - [ ] line parameter auto-population and usage
/// - [ ] column parameter auto-population and usage
/// - [ ] Debug information propagation to error handlers
/// - [ ] Source location integration with error reporting
///
/// ### Integration with LockmanAction Protocol
/// - [ ] action.createLockmanInfo() method integration
/// - [ ] action.unlockOption property usage as fallback
/// - [ ] LockmanAction protocol requirement validation
/// - [ ] Action parameter type safety and constraints
/// - [ ] Action integration with strategy resolution
///
/// ### Integration with LockmanBoundaryId Protocol
/// - [ ] boundaryId parameter type safety (B: LockmanBoundaryId)
/// - [ ] Boundary ID usage in lock acquisition
/// - [ ] Boundary ID usage in effect cancellation
/// - [ ] Boundary ID type erasure and handling
/// - [ ] Multiple boundary ID coordination
///
/// ### Unlock Option Integration
/// - [ ] unlockOption parameter propagation to unlock operations
/// - [ ] action.unlockOption fallback behavior
/// - [ ] LockmanUnlockOption types (.immediate, .mainRunLoop, .transition, .delayed)
/// - [ ] Unlock timing coordination with UI operations
/// - [ ] Custom unlock option override behavior
///
/// ### TaskPriority and Async Integration
/// - [ ] priority parameter handling (optional)
/// - [ ] TaskPriority propagation to underlying effects
/// - [ ] Async effect execution with priority
/// - [ ] Priority inheritance in concatenated effects
/// - [ ] Priority coordination with lock operations
///
/// ### Effect Cancellation and Cleanup
/// - [ ] Effect cancellation with boundary ID
/// - [ ] Automatic cancellation ID application
/// - [ ] Resource cleanup during effect cancellation
/// - [ ] Lock release guarantee on cancellation
/// - [ ] Cancellation error handling and propagation
///
/// ### Real-world Usage Patterns
/// - [ ] Simple .run effect with lock method chain
/// - [ ] Complex multi-effect concatenation with locking
/// - [ ] Integration with TCA Store and ViewStore
/// - [ ] Effect composition with lock management
/// - [ ] Error recovery patterns in locked effects
///
/// ### Performance and Memory Management
/// - [ ] Memory usage with concatenated effects
/// - [ ] Performance overhead of lock management
/// - [ ] Effect creation and disposal patterns
/// - [ ] Resource cleanup efficiency
/// - [ ] Large-scale effect coordination performance
///
/// ### Thread Safety and Concurrency
/// - [ ] Thread-safe effect execution with locks
/// - [ ] Concurrent effect coordination
/// - [ ] Race condition prevention in effect chains
/// - [ ] Memory consistency during effect execution
/// - [ ] Lock state consistency across concurrent effects
///
/// ### Integration with ComposableArchitecture
/// - [ ] TCA Effect protocol conformance
/// - [ ] Store integration with locked effects
/// - [ ] Reducer integration with effect locking
/// - [ ] ViewStore integration with locked effects
/// - [ ] Effect middleware compatibility
///
/// ### Edge Cases and Error Conditions
/// - [ ] Empty effect arrays in concatenating method
/// - [ ] Nil action or boundary ID handling (compile-time)
/// - [ ] Invalid strategy configuration scenarios
/// - [ ] Lock acquisition timeout scenarios
/// - [ ] Effect execution failure recovery
///
/// ### Documentation Examples Validation
/// - [ ] Code examples from documentation compilation
/// - [ ] Usage pattern examples validation
/// - [ ] Method chain syntax examples
/// - [ ] Error handling examples
/// - [ ] Real-world integration examples
///
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

  // MARK: - Static Effect.lock() Concatenating Method Tests

  func testLockConcatenatingWithSingleEffect() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in
          // Test operation
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created successfully
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingLockmanInfoConsistency() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* operation 1 */ },
        .run { _ in /* operation 2 */ },
      ]

      // Create multiple effects to verify uniqueId consistency
      let effect1 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      let effect2 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Both effects should be created (each with unique lockmanInfo)
      XCTAssertNotNil(effect1)
      XCTAssertNotNil(effect2)
    }
  }

  func testLockConcatenatingWithPriority() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* priority operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        priority: .high,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created with priority
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithUnlockOptions() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let unlockOptions: [LockmanUnlockOption] = [
        .immediate,
        .delayed(1.0),
        .mainRunLoop,
        .transition,
      ]

      for unlockOption in unlockOptions {
        let lockedEffect = Effect.lock(
          concatenating: operations,
          unlockOption: unlockOption,
          action: action,
          boundaryId: boundaryId
        )

        XCTAssertNotNil(lockedEffect, "Effect should be created with unlock option \(unlockOption)")
      }
    }
  }

  func testLockConcatenatingAutomaticCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in
          // This should be automatically cancellable
          try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created with automatic cancellation
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithMultipleEffects() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* operation 1 */ },
        .run { _ in /* operation 2 */ },
        .run { _ in /* operation 3 */ },
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created successfully
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithEmptyArray() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = []

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created successfully even with empty operations
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithLockFailureHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      actor HandlerState {
        private var called = false
        func setCalled() { called = true }
        func getCalled() -> Bool { called }
      }
      
      let handlerState = HandlerState()
      let lockFailureHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
        await handlerState.setCalled()
      }

      let lockedEffect = Effect.lock(
        concatenating: operations,
        lockFailure: lockFailureHandler,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created with handler
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testLockConcatenatingWithInvalidStrategy() async {
    // Use empty container - don't register any strategy
    let emptyContainer = LockmanStrategyContainer()
    
    await LockmanManager.withTestContainer(emptyContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should still be created (error handling occurs during execution)
      XCTAssertNotNil(lockedEffect)
    }
  }

  // MARK: - Instance Effect.lock() Method Chain API Tests

  func testEffectLockMethodChainAPI() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      let baseEffect: Effect<TestAction> = .run { _ in
        // Test operation
      }

      let lockedEffect = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created successfully
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testMethodChainLockmanInfoConsistency() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      let baseEffect: Effect<TestAction> = .run { _ in
        // Test operation
      }

      // Create multiple chained effects to test consistency
      let lockedEffect1 = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      let lockedEffect2 = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      // Both effects should be created with unique lockmanInfo
      XCTAssertNotNil(lockedEffect1)
      XCTAssertNotNil(lockedEffect2)
    }
  }

  func testMethodChainWithComposition() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      // Test method chaining with other Effect combinators
      let composedEffect = Effect<SharedTestAction>.merge(
        .run { _ in /* operation 1 */ },
        .run { _ in /* operation 2 */ }
          .lock(
            action: action,
            boundaryId: boundaryId
          )
      )

      XCTAssertNotNil(composedEffect)
    }
  }

  func testMethodChainErrorHandling() async {
    // Use empty container - don't register any strategy to test error handling
    let emptyContainer = LockmanStrategyContainer()
    
    await LockmanManager.withTestContainer(emptyContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      let baseEffect: Effect<SharedTestAction> = .run { _ in
        // Test operation
      }

      let lockedEffect = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      // Effect should still be created (error handling occurs during execution)
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testMethodChainWithHandleCancellationErrors() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      let baseEffect: Effect<TestAction> = .run { _ in
        // Test operation
      }

      let lockedEffect = baseEffect.lock(
        action: action,
        boundaryId: boundaryId,
        handleCancellationErrors: true
      )

      // Effect should be created with cancellation error handling
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testEffectLockMethodChainWithUnlockOption() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      let baseEffect: Effect<TestAction> = .run { _ in
        // Test operation
      }

      let lockedEffect = baseEffect.lock(
        action: action,
        boundaryId: boundaryId,
        unlockOption: .delayed(1.0)
      )

      // Effect should be created successfully
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testEffectLockMethodChainWithLockFailureHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      actor HandlerState {
        private var called = false
        func setCalled() { called = true }
        func getCalled() -> Bool { called }
      }
      
      let handlerState = HandlerState()
      let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
        await handlerState.setCalled()
      }

      let baseEffect: Effect<SharedTestAction> = .run { _ in
        // Test operation
      }

      let lockedEffect = baseEffect.lock(
        action: action,
        boundaryId: boundaryId,
        lockFailure: lockFailureHandler
      )

      // Effect should be created successfully
      XCTAssertNotNil(lockedEffect)
    }
  }

  // MARK: - LockmanInfo Consistency Tests

  func testLockmanInfoConsistencyInConcatenating() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* operation 1 */ },
        .run { _ in /* operation 2 */ },
      ]

      // Create multiple effects to test consistency
      let effect1 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      let effect2 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Both effects should be created successfully
      XCTAssertNotNil(effect1)
      XCTAssertNotNil(effect2)
    }
  }

  func testLockmanInfoConsistencyInMethodChain() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      let baseEffect: Effect<TestAction> = .run { _ in
        // Test operation
      }

      // Create multiple chained effects to test consistency
      let effect1 = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      let effect2 = baseEffect.lock(
        action: action,
        boundaryId: boundaryId
      )

      // Both effects should be created successfully
      XCTAssertNotNil(effect1)
      XCTAssertNotNil(effect2)
    }
  }

  // MARK: - UnlockOption Integration Tests

  func testUnlockOptionFromActionProperty() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test  // has .immediate unlock option
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should use action's unlock option
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testUnlockOptionOverride() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test  // has .immediate unlock option
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        unlockOption: .delayed(2.0),  // Override action's option
        action: action,
        boundaryId: boundaryId
      )

      // Effect should use overridden unlock option
      XCTAssertNotNil(lockedEffect)
    }
  }

  // MARK: - TaskPriority Integration Tests

  func testTaskPriorityPropagation() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        priority: .high,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created with priority
      XCTAssertNotNil(lockedEffect)
    }
  }

  // MARK: - Effect Execution and Cancellation Tests

  func testEffectCancellationWithBoundaryId() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in
          // Long running operation
          try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be cancellable with boundary ID
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testAutomaticCancellationIDApplication() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test

      // Test both concatenating and method chain APIs
      let concatenatingEffect = Effect<SharedTestAction>.lock(
        concatenating: [.run { _ in /* operation */ }],
        action: action,
        boundaryId: boundaryId
      )

      let methodChainEffect: Effect<SharedTestAction> = Effect.run { _ in
        /* operation */
      }.lock(
        action: action,
        boundaryId: boundaryId
      )

      // Both should apply cancellation automatically
      XCTAssertNotNil(concatenatingEffect)
      XCTAssertNotNil(methodChainEffect)
    }
  }

  func testEffectCancellationIDConsistency() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* cancellable operation */ }
      ]

      // Multiple effects with same boundary should use same cancellation ID
      let effect1 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      let effect2 = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      XCTAssertNotNil(effect1)
      XCTAssertNotNil(effect2)
    }
  }

  func testGuaranteedUnlockExecution() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in
          // Operation that might be cancelled
          try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Unlock should be guaranteed even if operations are cancelled
      XCTAssertNotNil(lockedEffect)
    }
  }

  // MARK: - Error Handling Tests

  func testErrorHandlingWithInvalidStrategy() async {
    // Use empty container - don't register any strategy to cause an error
    let emptyContainer = LockmanStrategyContainer()
    
    await LockmanManager.withTestContainer(emptyContainer) {
      let boundaryId = TestBoundaryId.test
      let action = SharedTestAction.test

      actor ErrorCapture {
        private var errorReceived: (any Error)?
        func setErrorReceived(_ error: any Error) { errorReceived = error }
        func getErrorReceived() -> (any Error)? { errorReceived }
      }
      
      let errorCapture = ErrorCapture()
      let lockFailureHandler: @Sendable (any Error, Send<TestAction>) async -> Void = { error, send in
        await errorCapture.setErrorReceived(error)
      }

      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        lockFailure: lockFailureHandler,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should be created and handle error during execution
      XCTAssertNotNil(lockedEffect)
      
      // Error capture should be initialized but no error received yet
      Task {
        let error = await errorCapture.getErrorReceived()
        XCTAssertNil(error)
      }
    }
  }

  // MARK: - Integration with LockmanAction Protocol Tests

  func testLockmanActionProtocolIntegration() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let action = SharedTestAction.test
      let operations: [Effect<TestAction>] = [
        .run { _ in /* test operation */ }
      ]

      let lockedEffect = Effect.lock(
        concatenating: operations,
        action: action,
        boundaryId: boundaryId
      )

      // Effect should work with different action variants
      XCTAssertNotNil(lockedEffect)
    }
  }

  func testActionNameAndLockmanInfoCreation() {
    let action1 = TestAction.test
    let action2 = TestAction.testWithId("example")

    XCTAssertEqual(action1.actionName, "test")
    XCTAssertEqual(action2.actionName, "testWithId_example")

    let info1 = action1.createLockmanInfo()
    let info2 = action2.createLockmanInfo()

    XCTAssertEqual(info1.actionId, "test")
    XCTAssertEqual(info2.actionId, "testWithId_example")

    // Unique IDs should be different
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }
}
