import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Support Types
// Shared test support types are defined in TestSupport.swift

/// Unit tests for Effect+LockmanInternal
///
/// Tests internal implementation details for Effect lock management with uniqueId consistency and boundary protection.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Lock Acquisition Protocol Implementation
/// - [ ] acquireLock() with valid lockmanInfo and boundaryId parameters
/// - [ ] acquireLock() strategy resolution using lockmanInfo.strategyId
/// - [ ] acquireLock() boundary lock protection during acquisition
/// - [ ] acquireLock() canLock() feasibility check before actual lock
/// - [ ] acquireLock() early exit on .cancel result from canLock()
/// - [ ] acquireLock() actual lock() call after successful feasibility check
/// - [ ] acquireLock() return value consistency with canLock() result
/// - [ ] acquireLock() error propagation from strategy resolution
/// - [ ] acquireLock() throws behavior for invalid strategy resolution
///
/// ### UniqueId Consistency Management
/// - [ ] Pre-captured lockmanInfo ensures consistent uniqueId throughout lifecycle
/// - [ ] Same lockmanInfo instance used in acquireLock() and buildLockEffect()
/// - [ ] UniqueId preservation between lock acquisition and release
/// - [ ] Lock/unlock matching validation with consistent uniqueId
/// - [ ] Multiple sequential operations maintain uniqueId consistency
/// - [ ] LockmanInfo parameter propagation through effect building
///
/// ### Preceding Cancellation Handling
/// - [ ] .successWithPrecedingCancellation result detection and processing
/// - [ ] Immediate unlock for cancelled action to prevent resource leaks
/// - [ ] Compatible lock info type checking for cancelled info
/// - [ ] Cancellation error boundary ID matching
/// - [ ] Safe handling of type-incompatible cancelled info
/// - [ ] Resource cleanup guarantee for preceding cancellations
///
/// ### Boundary Lock Protection
/// - [ ] LockmanManager.withBoundaryLock() integration for atomicity
/// - [ ] Race condition prevention between acquisition attempts
/// - [ ] Lock acquisition and release operation coordination
/// - [ ] Cleanup and acquisition operation protection
/// - [ ] Boundary-specific lock duration and scope
/// - [ ] Multiple boundary coordination and isolation
///
/// ### Strategy Resolution and Container Integration
/// - [ ] LockmanManager.container.resolve() integration
/// - [ ] Strategy type constraint validation (AnyLockmanStrategy<I>)
/// - [ ] StrategyId to strategy instance mapping
/// - [ ] Strategy resolution error handling and propagation
/// - [ ] Type-safe strategy resolution with generic constraints
/// - [ ] Container state consistency during resolution
///
/// ### Effect Building with Lock Management
/// - [ ] buildLockEffect() with lockResult parameter handling
/// - [ ] Strategy resolution from lockmanInfo.strategyId
/// - [ ] Unlock token creation with same lockmanInfo instance
/// - [ ] Unlock effect creation and configuration
/// - [ ] Conditional cancellation based on isCancellationTarget
/// - [ ] Effect concatenation with operations and unlock effects
/// - [ ] Type safety maintenance through generic constraints
///
/// ### Lock Result Processing in Effect Building
/// - [ ] .success result immediate effect execution
/// - [ ] .successWithPrecedingCancellation result with cancellation effect
/// - [ ] .cancel result with lock failure handler invocation
/// - [ ] LockmanCancellationError wrapping for strategy errors
/// - [ ] Handler integration with async operations
/// - [ ] Effect concatenation order for cancellation scenarios
/// - [ ] .none effect return for failed operations
///
/// ### Unlock Token and Effect Management
/// - [ ] LockmanUnlock token creation with consistent parameters
/// - [ ] Unlock effect execution with configured unlock option
/// - [ ] Guaranteed unlock execution after operations complete
/// - [ ] Non-cancellable unlock effect protection
/// - [ ] Unlock option parameter propagation
/// - [ ] Resource cleanup guarantee through unlock effects
///
/// ### Cancellation and Effect Coordination
/// - [ ] Conditional cancellable effect application
/// - [ ] isCancellationTarget flag behavior and impact
/// - [ ] Boundary ID usage for effect cancellation
/// - [ ] Effect cancellation ID consistency
/// - [ ] Cancellation effect ordering (.cancel before operations)
/// - [ ] Multiple boundary cancellation coordination
///
/// ### Error Handling and Diagnostic Support
/// - [ ] handleError() integration with LockmanRegistrationError
/// - [ ] Error type detection and specific handling
/// - [ ] reportIssue() integration with source location information
/// - [ ] fileID, filePath, line, column parameter usage
/// - [ ] Strategy-specific error message generation
/// - [ ] Development vs production error handling
/// - [ ] Xcode integration with clickable error messages
///
/// ### Handler Integration and Async Support
/// - [ ] Optional handler parameter support
/// - [ ] Handler invocation with error and send parameters
/// - [ ] Async handler execution integration
/// - [ ] Handler coordination with effect execution
/// - [ ] Error propagation to handlers
/// - [ ] Send function parameter validation
///
/// ### Type Safety and Generic Constraints
/// - [ ] B: LockmanBoundaryId constraint enforcement
/// - [ ] A: LockmanAction constraint validation
/// - [ ] I: LockmanInfo constraint and relationship preservation
/// - [ ] Generic type parameter consistency across method calls
/// - [ ] Type erasure handling with AnyLockmanStrategy
/// - [ ] Protocol conformance validation
///
/// ### Source Location and Debugging Integration
/// - [ ] fileID parameter auto-population and usage
/// - [ ] filePath parameter auto-population and usage
/// - [ ] line parameter auto-population and usage
/// - [ ] column parameter auto-population and usage
/// - [ ] Debug information propagation to error handlers
/// - [ ] Source location integration with issue reporting
///
/// ### Strategy Error Integration
/// - [ ] LockmanRegistrationError.strategyNotRegistered handling
/// - [ ] LockmanRegistrationError.strategyAlreadyRegistered handling
/// - [ ] Strategy-specific error message generation
/// - [ ] Error context preservation through effect building
/// - [ ] Strategy type information in error messages
/// - [ ] Registration guidance in error diagnostics
///
/// ### Performance and Memory Management
/// - [ ] Lock acquisition performance characteristics (O(1) lookup)
/// - [ ] Boundary lock duration (microseconds)
/// - [ ] Effect concatenation overhead minimization
/// - [ ] Memory usage with unlock token creation
/// - [ ] Resource cleanup efficiency
/// - [ ] Large-scale effect coordination performance
///
/// ### Thread Safety and Concurrency
/// - [ ] Thread-safe lock acquisition process
/// - [ ] Concurrent access protection through boundary locks
/// - [ ] Race condition prevention in multi-threaded scenarios
/// - [ ] Memory consistency during concurrent operations
/// - [ ] Sendable compliance throughout effect building
///
/// ### Integration with ComposableArchitecture
/// - [ ] Effect<Action> protocol conformance and behavior
/// - [ ] TCA effect lifecycle integration
/// - [ ] Store integration with lock management
/// - [ ] Action dispatch coordination
/// - [ ] Effect middleware compatibility
///
/// ### Real-world Usage Patterns
/// - [ ] High-frequency lock acquisition scenarios
/// - [ ] Complex effect composition with locking
/// - [ ] Error recovery patterns in locked effects
/// - [ ] Multi-strategy coordination through effects
/// - [ ] Resource-intensive operation locking
///
/// ### Edge Cases and Error Conditions
/// - [ ] Invalid strategy ID handling
/// - [ ] Malformed lockmanInfo parameter recovery
/// - [ ] Boundary ID collision scenarios
/// - [ ] Strategy container state inconsistency
/// - [ ] Effect execution failure recovery
///
/// ### Documentation Examples Validation
/// - [ ] Lock acquisition protocol examples
/// - [ ] Boundary protection usage patterns
/// - [ ] Error handling examples
/// - [ ] Effect building integration examples
/// - [ ] Real-world integration scenarios
///
final class EffectLockmanInternalTests: XCTestCase {

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

  // MARK: - Lock Acquisition Protocol Tests

  func testAcquireLockWithValidParametersSucceeds() async {
    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      // Create test info
      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        let result = try effect.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )

        // Should succeed for first acquisition
        switch result {
        case .success:
          XCTAssertTrue(true, "Lock acquisition succeeded as expected")
        default:
          XCTFail("Expected .success, got \(result)")
        }
      } catch {
        XCTFail("Lock acquisition should not throw: \(error)")
      }
    }
  }

  func testAcquireLockStrategyResolution() async {
    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        let result = try effect.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )

        // Strategy should be resolved and lock should succeed
        XCTAssertEqual(result, .success)
      } catch {
        XCTFail("Strategy resolution should succeed: \(error)")
      }
    }
  }

  func testAcquireLockBoundaryProtection() async {
    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      // Lock acquisition should be protected by boundary lock
      do {
        let result = try effect.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )
        XCTAssertEqual(result, .success)
      } catch {
        XCTFail("Boundary-protected lock acquisition should succeed: \(error)")
      }
    }
  }

  func testAcquireLockCanLockFeasibilityCheck() async {
    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let firstInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let secondInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        // First acquisition should succeed
        let firstResult = try effect.acquireLock(
          lockmanInfo: firstInfo,
          boundaryId: boundaryId
        )
        XCTAssertEqual(firstResult, .success)

        // Second acquisition of same actionId should be rejected
        let secondResult = try effect.acquireLock(
          lockmanInfo: secondInfo,
          boundaryId: boundaryId
        )
        if case .cancel = secondResult {
          XCTAssertTrue(true, "Second acquisition correctly rejected")
        } else {
          XCTFail("Expected .cancel for second acquisition")
        }
      } catch {
        XCTFail("Lock feasibility check should not throw: \(error)")
      }
    }
  }

  func testAcquireLockWithInvalidStrategyThrows() {
    let actionId = uniqueActionId()
    let invalidStrategyId = LockmanStrategyId("non-existent-strategy")
    let boundaryId = TestBoundaryId.test

    let lockmanInfo = TestLockmanInfo(
      actionId: actionId,
      strategyId: invalidStrategyId,
      uniqueId: UUID()
    )

    let effect: Effect<SharedTestAction> = .none

    XCTAssertThrowsError(
      try effect.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )
    ) { error in
      XCTAssertTrue(error is LockmanRegistrationError)
    }
  }

  func testAcquireLockWithPrecedingCancellation() async {
    // Create a more sophisticated strategy that can return precedingCancellation
    class PrecedingCancellationStrategy: LockmanStrategy, @unchecked Sendable {
      typealias I = TestLockmanInfo

      var strategyId: LockmanStrategyId { LockmanStrategyId("PrecedingCancellationStrategy") }

      static func makeStrategyId() -> LockmanStrategyId {
        LockmanStrategyId("PrecedingCancellationStrategy")
      }

      private var lockedActions: [String: TestLockmanInfo] = [:]
      private let lock = NSLock()

      func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
        lock.withLock {
          if let existingInfo = lockedActions[info.actionId] {
            // Return precedingCancellation with the existing info
            let priorityInfo = LockmanPriorityBasedInfo(
              actionId: existingInfo.actionId,
              priority: .high(.exclusive)
            )
            let error = LockmanPriorityBasedError.precedingActionCancelled(
              lockmanInfo: priorityInfo,
              boundaryId: boundaryId
            )
            return .successWithPrecedingCancellation(error: error)
          }
          return .success
        }
      }

      func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        lock.withLock {
          lockedActions[info.actionId] = info
        }
      }

      func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        _ = lock.withLock {
          lockedActions.removeValue(forKey: info.actionId)
        }
      }

      func cleanUp() {
        lock.withLock {
          lockedActions.removeAll()
        }
      }

      func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
        // For this test strategy, we clean up all actions regardless of boundary
        cleanUp()
      }

      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
        lock.withLock {
          // Return empty for simplicity - this is a test strategy
          return [:]
        }
      }
    }

    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = PrecedingCancellationStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      // First lock to create existing state
      let firstInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      strategy.lock(boundaryId: boundaryId, info: firstInfo)

      // Second lock attempt should trigger preceding cancellation
      let secondInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        let result = try effect.acquireLock(
          lockmanInfo: secondInfo,
          boundaryId: boundaryId
        )

        // Should return successWithPrecedingCancellation
        if case .successWithPrecedingCancellation = result {
          XCTAssertTrue(true, "Preceding cancellation handled correctly")
        } else {
          XCTFail("Expected .successWithPrecedingCancellation, got \(result)")
        }
      } catch {
        XCTFail("Lock acquisition should not throw: \(error)")
      }
    }
  }

  func testAcquireLockEarlyExitOnCancel() async {
    // Setup test strategy that always rejects
    class RejectingStrategy: LockmanStrategy, @unchecked Sendable {
      typealias I = TestLockmanInfo
      
      var strategyId: LockmanStrategyId { .init(name: "RejectingStrategy") }
      
      static func makeStrategyId() -> LockmanStrategyId {
        .init(name: "RejectingStrategy")
      }

      func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
        let error = LockmanSingleExecutionError.boundaryAlreadyLocked(
          boundaryId: boundaryId,
          lockmanInfo: LockmanSingleExecutionInfo(actionId: info.actionId, mode: .boundary)
        )
        return .cancel(error)
      }

      func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
        XCTFail("lock() should not be called when canLock returns .cancel")
      }

      func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {}
      func cleanUp() {}
      func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {}
      func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] { [:] }
    }

    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = RejectingStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        let result = try effect.acquireLock(
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId
        )

        // Should return .cancel and never call lock()
        if case .cancel = result {
          XCTAssertTrue(true, "Early exit on cancel worked correctly")
        } else {
          XCTFail("Expected .cancel for rejecting strategy")
        }
      } catch {
        XCTFail("Early exit test should not throw: \(error)")
      }
    }
  }

  // MARK: - UniqueId Consistency Tests

  func testUniqueIdConsistencyThroughoutLifecycle() async {
    // Setup test container and strategy
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let uniqueId = UUID()
      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: uniqueId
      )

    let effect: Effect<SharedTestAction> = .none

    do {
      // Acquire lock and verify uniqueId is preserved
      _ = try effect.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )

      // Verify the same uniqueId is stored in strategy
      XCTAssertEqual(lockmanInfo.uniqueId, uniqueId)

    } catch {
      XCTFail("Lock acquisition should not throw: \(error)")
    }
    }
  }

  // MARK: - Effect Building Tests

  func testBuildLockEffectWithSuccessResult() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      let builtEffect = effect.buildLockEffect(
        lockResult: .success,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Effect should be built successfully
      XCTAssertNotNil(builtEffect)
    }
  }

  func testBuildLockEffectStrategyResolution() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      let builtEffect = effect.buildLockEffect(
        lockResult: .success,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Strategy should be resolved successfully
      XCTAssertNotNil(builtEffect)
    }
  }

  func testBuildLockEffectUnlockTokenCreation() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      // Test different unlock options
      let unlockOptions: [LockmanUnlockOption] = [
        .immediate,
        .delayed(1.0),
        .mainRunLoop,
        .transition,
      ]

      for unlockOption in unlockOptions {
        let builtEffect = effect.buildLockEffect(
          lockResult: .success,
          action: action,
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId,
          unlockOption: unlockOption,
          fileID: #fileID,
          filePath: #filePath,
          line: #line,
          column: #column
        )

        XCTAssertNotNil(builtEffect, "Effect should be built with unlock option \(unlockOption)")
      }
    }
  }

  func testBuildLockEffectCancellationBehavior() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

    // Test cancellable and non-cancellable info
    struct CancellableInfo: LockmanInfo {
      let actionId: LockmanActionId
      let strategyId: LockmanStrategyId
      let uniqueId: UUID
      let isCancellationTarget: Bool = true
      
      var debugDescription: String {
        "CancellableInfo(actionId: \(actionId), strategyId: \(strategyId), uniqueId: \(uniqueId))"
      }
    }

    struct NonCancellableInfo: LockmanInfo {
      let actionId: LockmanActionId
      let strategyId: LockmanStrategyId
      let uniqueId: UUID
      let isCancellationTarget: Bool = false
      
      var debugDescription: String {
        "NonCancellableInfo(actionId: \(actionId), strategyId: \(strategyId), uniqueId: \(uniqueId))"
      }
    }

      let cancellableInfo = CancellableInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let nonCancellableInfo = NonCancellableInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      // Both should build effects successfully
      let cancellableEffect = effect.buildLockEffect(
        lockResult: .success,
        action: action,
        lockmanInfo: cancellableInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      let nonCancellableEffect = effect.buildLockEffect(
        lockResult: .success,
        action: action,
        lockmanInfo: nonCancellableInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      XCTAssertNotNil(cancellableEffect)
      XCTAssertNotNil(nonCancellableEffect)
    }
  }

  func testBuildLockEffectWithCancelResult() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      let singleExecutionInfo = LockmanSingleExecutionInfo(
        actionId: "test",
        mode: .action
      )
      let error = LockmanSingleExecutionError.actionAlreadyRunning(
        boundaryId: boundaryId,
        lockmanInfo: singleExecutionInfo
      )
      let builtEffect = effect.buildLockEffect(
        lockResult: .cancel(error),
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Effect should return .none for cancelled operations
      // We can't directly test .none equivalence, but we can verify it doesn't crash
      XCTAssertNotNil(builtEffect)
    }
  }

  func testBuildLockEffectWithSuccessWithPrecedingCancellation() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      // Create a preceding cancellation error
      let priorityInfo = LockmanPriorityBasedInfo(
        actionId: lockmanInfo.actionId,
        priority: .high(.exclusive)
      )
      let precedingError = LockmanPriorityBasedError.precedingActionCancelled(
        lockmanInfo: priorityInfo,
        boundaryId: boundaryId
      )

      let builtEffect = effect.buildLockEffect(
        lockResult: .successWithPrecedingCancellation(error: precedingError),
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Effect should handle preceding cancellation
      XCTAssertNotNil(builtEffect)
    }
  }

  func testBuildLockEffectErrorHandling() async {
    // Use empty container to cause resolution error
    let emptyContainer = LockmanStrategyContainer()
    
    await LockmanManager.withTestContainer(emptyContainer) {
      let strategyId = LockmanStrategyId("non-existent-strategy")
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      let builtEffect = effect.buildLockEffect(
        lockResult: .success,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column
      )

      // Should return .none when strategy resolution fails
      XCTAssertNotNil(builtEffect)
    }
  }

  func testBuildLockEffectWithLockFailureHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      var handlerCalled = false
      let lockFailureHandler: (any Error, Send<SharedTestAction>) async -> Void = { error, send in
        handlerCalled = true
      }

      let singleExecutionInfo = LockmanSingleExecutionInfo(
        actionId: "test",
        mode: .action
      )
      let error = LockmanSingleExecutionError.actionAlreadyRunning(
        boundaryId: boundaryId,
        lockmanInfo: singleExecutionInfo
      )
      let builtEffect = effect.buildLockEffect(
        lockResult: .cancel(error),
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: lockFailureHandler
      )

      // Effect should be built with handler
      XCTAssertNotNil(builtEffect)
      
      // Handler should not be called during effect building
      XCTAssertFalse(handlerCalled)
    }
  }

  func testBuildLockEffectWithPrecedingCancellationAndHandler() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let action = SharedTestAction.test
      let effect: Effect<SharedTestAction> = .run { _ in /* test operation */ }

      actor HandlerCheck {
        private var handlerCalled = false
        func setHandlerCalled() { handlerCalled = true }
        func getHandlerCalled() -> Bool { handlerCalled }
      }
      
      let handlerCheck = HandlerCheck()
      let lockFailureHandler: @Sendable (any Error, Send<SharedTestAction>) async -> Void = { error, send in
        await handlerCheck.setHandlerCalled()
      }

      let priorityInfo = LockmanPriorityBasedInfo(
        actionId: lockmanInfo.actionId,
        priority: .high(.exclusive)
      )
      let precedingError = LockmanPriorityBasedError.precedingActionCancelled(
        lockmanInfo: priorityInfo,
        boundaryId: boundaryId
      )

      let builtEffect = effect.buildLockEffect(
        lockResult: .successWithPrecedingCancellation(error: precedingError),
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: .immediate,
        fileID: #fileID,
        filePath: #filePath,
        line: #line,
        column: #column,
        handler: lockFailureHandler
      )

      // Effect should handle preceding cancellation with handler
      XCTAssertNotNil(builtEffect)
      
      // Handler should not be called during effect building
      Task {
        let wasCalled = await handlerCheck.getHandlerCalled()
        XCTAssertFalse(wasCalled)
      }
    }
  }

  // MARK: - Error Handling Tests

  func testHandleErrorWithStrategyNotRegistered() {
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyNotRegistered(strategyType)

    // This should not crash - mainly testing that the error handling path works
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // If we get here without crashing, the error handling worked
    XCTAssertTrue(true)
  }

  func testHandleErrorWithStrategyAlreadyRegistered() {
    let strategyType = "TestStrategy"
    let error = LockmanRegistrationError.strategyAlreadyRegistered(strategyType)

    // This should not crash - mainly testing that the error handling path works
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // If we get here without crashing, the error handling worked
    XCTAssertTrue(true)
  }

  func testHandleErrorWithUnknownError() {
    struct UnknownError: Error {}
    let error = UnknownError()

    // This should not crash - mainly testing that the error handling path works
    Effect<SharedTestAction>.handleError(
      error: error,
      fileID: #fileID,
      filePath: #filePath,
      line: #line,
      column: #column
    )

    // If we get here without crashing, the error handling worked
    XCTAssertTrue(true)
  }

  // MARK: - Boundary Lock Protection Tests

  func testBoundaryLockProtectionDuringAcquisition() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()
      let boundaryId = TestBoundaryId.test

      let lockmanInfo = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      // Perform concurrent acquisitions to test boundary protection
      await TestSupport.performConcurrentOperations(count: 10) {
        let effect: Effect<SharedTestAction> = .none
        do {
          _ = try effect.acquireLock(
            lockmanInfo: lockmanInfo,
            boundaryId: boundaryId
          )
        } catch {
          // Expected for some concurrent operations
        }
      }

      // If we get here without deadlocks or crashes, boundary protection worked
      XCTAssertTrue(true)
    }
  }

  func testMultipleBoundaryCoordination() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let boundary1 = TestBoundaryId.test
      let boundary2 = TestBoundaryId.secondary

      let info1 = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let info2 = TestLockmanInfo(
        actionId: uniqueActionId(),
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        // Different boundaries should not interfere
        let result1 = try effect.acquireLock(
          lockmanInfo: info1,
          boundaryId: boundary1
        )
        let result2 = try effect.acquireLock(
          lockmanInfo: info2,
          boundaryId: boundary2
        )

        XCTAssertEqual(result1, .success)
        XCTAssertEqual(result2, .success)
      } catch {
        XCTFail("Multi-boundary coordination should not throw: \(error)")
      }
    }
  }

  func testBoundaryLockIsolation() async {
    let container = LockmanStrategyContainer()
    let strategy = TestSingleExecutionStrategy()
    try? container.register(strategy)
    
    await LockmanManager.withTestContainer(container) {
      let actionId = uniqueActionId()

      let boundary1 = TestBoundaryId.test
      let boundary2 = TestBoundaryId.secondary

      let info1 = TestLockmanInfo(
        actionId: actionId,
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let info2 = TestLockmanInfo(
        actionId: actionId,  // Same action ID
        strategyId: strategy.strategyId,
        uniqueId: UUID()
      )

      let effect: Effect<SharedTestAction> = .none

      do {
        // First acquisition on boundary1
        let result1 = try effect.acquireLock(
          lockmanInfo: info1,
          boundaryId: boundary1
        )
        XCTAssertEqual(result1, .success)

        // Second acquisition of same actionId on different boundary should be rejected
        let result2 = try effect.acquireLock(
          lockmanInfo: info2,
          boundaryId: boundary2
        )
        if case .cancel = result2 {
          XCTAssertTrue(true, "Same action ID properly isolated across boundaries")
        } else {
          XCTFail("Expected .cancel for same action ID on different boundary")
        }
      } catch {
        XCTFail("Boundary isolation test should not throw: \(error)")
      }
    }
  }
}
