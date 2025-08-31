# Lockman Test System Design - Complete Specification

## Document Overview

This document provides the complete architectural design for the Lockman test system, including detailed specifications, implementation patterns, and quality assurance guidelines.

## Architecture Overview

### Design Principles

1. **Separation of Concerns**: Each test category addresses specific aspects of functionality
2. **Backward Compatibility**: New tests coexist with existing tests during transition
3. **Scalability**: Test system grows efficiently with codebase
4. **Reliability**: Tests are deterministic and maintainable
5. **Performance**: Test execution is optimized for CI/CD environments

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Lockman Test System                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │   Test Layers   │  │  Support Tools  │  │   CI/CD      │ │
│  │                 │  │                 │  │   Pipeline   │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │              │ │
│  │ │    Unit     │ │  │ │   Fixtures  │ │  │ ┌──────────┐ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ │   Fast   │ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ │  Tests   │ │ │
│  │ │Integration  │ │  │ │  Assertions │ │  │ └──────────┘ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ ┌──────────┐ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ │   Slow   │ │ │
│  │ │Concurrency  │ │  │ │   Helpers   │ │  │ │  Tests   │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └──────────┘ │ │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌──────────┐ │ │
│  │ │State Mgmt   │ │  │ │    Mocks    │ │  │ │ Reports  │ │ │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └──────────┘ │ │
│  │ ┌─────────────┐ │  │                 │  │              │ │
│  │ │Error Handle │ │  │                 │  │              │ │
│  │ └─────────────┘ │  │                 │  │              │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure Design

### Complete Directory Layout

```
Tests/
├── LockmanTestsNew/                    # NEW: Primary test suite
│   ├── Unit/                          # Unit testing layer
│   │   ├── Core/                      # Core functionality
│   │   │   ├── LockmanManagerTests.swift
│   │   │   ├── LockmanResultTests.swift
│   │   │   ├── LockmanUnlockTests.swift
│   │   │   └── TypeErasure/
│   │   │       ├── AnyLockmanBoundaryIdTests.swift
│   │   │       ├── AnyLockmanGroupIdTests.swift
│   │   │       └── AnyLockmanStrategyTests.swift
│   │   ├── Strategies/                # Strategy implementations
│   │   │   ├── SingleExecution/
│   │   │   │   ├── LockmanSingleExecutionStrategyUnitTests.swift
│   │   │   │   ├── LockmanSingleExecutionInfoUnitTests.swift
│   │   │   │   └── LockmanSingleExecutionActionUnitTests.swift
│   │   │   ├── PriorityBased/
│   │   │   ├── ConcurrencyLimited/
│   │   │   ├── GroupCoordination/
│   │   │   └── Composite/
│   │   ├── Composable/                # TCA integration
│   │   │   ├── EffectLockmanUnitTests.swift
│   │   │   ├── LockmanReducerUnitTests.swift
│   │   │   └── ReducerLockmanUnitTests.swift
│   │   └── Protocols/                 # Protocol conformance
│   │       ├── LockmanActionTests.swift
│   │       ├── LockmanInfoTests.swift
│   │       └── LockmanStrategyTests.swift
│   ├── Integration/                   # Integration testing layer
│   │   ├── StrategyIntegration/
│   │   │   ├── MultiStrategyTests.swift
│   │   │   ├── StrategyCompositionTests.swift
│   │   │   └── BoundaryConflictTests.swift
│   │   ├── TCAIntegration/
│   │   │   ├── EffectChainTests.swift
│   │   │   ├── StateModificationTests.swift
│   │   │   ├── ErrorPropagationTests.swift
│   │   │   └── CancellationTests.swift
│   │   ├── ContainerIntegration/
│   │   │   ├── StrategyRegistrationTests.swift
│   │   │   ├── ContainerConcurrencyTests.swift
│   │   │   └── DynamicStrategyTests.swift
│   │   └── EndToEndTests.swift
│   ├── Concurrency/                   # Concurrency testing layer
│   │   ├── RaceConditionTests.swift
│   │   ├── ThreadSafetyTests.swift
│   │   ├── DeadlockTests.swift
│   │   ├── HighContentionTests.swift
│   │   └── MemoryModelTests.swift
│   ├── StateManagement/               # State management testing
│   │   ├── StateConsistencyTests.swift
│   │   ├── ResourceManagementTests.swift
│   │   ├── EdgeCaseTests.swift
│   │   └── CleanupTests.swift
│   ├── ErrorHandling/                 # Error handling testing
│   │   ├── ErrorRecoveryTests.swift
│   │   ├── ExceptionSafetyTests.swift
│   │   ├── FaultToleranceTests.swift
│   │   └── ErrorPropagationTests.swift
│   └── Performance/                   # Performance testing
│       ├── BaselineTests.swift
│       ├── ScalabilityTests.swift
│       ├── LoadTests.swift
│       └── RegressionTests.swift
├── LockmanTestSupport/                # NEW: Test utilities
│   ├── TestFixtures.swift
│   ├── ConcurrencyTestHelpers.swift
│   ├── LockmanAssertions.swift
│   ├── MockStrategies.swift
│   ├── PerformanceMeasurement.swift
│   └── TestConfiguration.swift
├── LockmanMacrosTests/                # EXISTING: Macro tests
├── LockmanStressTests/                # EXISTING: Stress tests
└── LockmanTests/                      # EXISTING: Legacy tests (preserved)
```

### Directory Design Rationale

#### 1. Parallel Structure Strategy
- **New tests** in `LockmanTestsNew/` avoid conflicts with existing tests
- **Gradual migration** possible without breaking existing functionality
- **Side-by-side validation** during transition period

#### 2. Layered Testing Approach
- **Unit tests** focus on individual components in isolation
- **Integration tests** verify component interactions
- **Concurrency tests** ensure thread safety and race condition prevention
- **State management tests** validate data consistency and cleanup
- **Error handling tests** verify robustness and recovery

#### 3. Support Framework Centralization
- **Shared utilities** in `LockmanTestSupport/` for consistency
- **Reusable components** reduce code duplication
- **Standardized patterns** improve maintainability

## Test Layer Specifications

### 1. Unit Test Layer

#### Purpose
Test individual components in isolation to ensure correctness of basic functionality.

#### Structure Pattern
```swift
// Example: Tests/LockmanTestsNew/Unit/Strategies/SingleExecution/LockmanSingleExecutionStrategyUnitTests.swift

import XCTest
@testable import Lockman
import LockmanTestSupport

final class LockmanSingleExecutionStrategyUnitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Use test fixtures for consistent setup
        LockmanTestSupport.resetGlobalState()
    }
    
    override func tearDown() {
        super.tearDown()
        // Ensure clean state for next test
        LockmanTestSupport.cleanupResources()
    }
    
    // Test naming pattern: test{Component}_{Scenario}_{ExpectedResult}
    func testCanLock_WithAvailableBoundary_ShouldReturnSuccess() {
        // Arrange
        let strategy = LockmanSingleExecutionStrategy.shared
        let boundary = TestFixtures.mockBoundaryId
        let info = TestFixtures.singleExecutionInfo
        
        // Act
        let result = strategy.canLock(boundaryId: boundary, info: info)
        
        // Assert
        LockmanAssertions.assertSuccess(result)
    }
    
    func testCanLock_WithOccupiedBoundary_ShouldReturnCancellation() {
        // Arrange
        let strategy = LockmanSingleExecutionStrategy.shared
        let boundary = TestFixtures.mockBoundaryId
        let info1 = TestFixtures.singleExecutionInfo
        let info2 = TestFixtures.singleExecutionInfo
        
        strategy.lock(boundaryId: boundary, info: info1)
        
        // Act
        let result = strategy.canLock(boundaryId: boundary, info: info2)
        
        // Assert
        LockmanAssertions.assertCancellation(result)
    }
}
```

#### Coverage Requirements
- **All public methods** must have corresponding tests
- **Edge cases** including boundary conditions
- **Error conditions** with appropriate error validation
- **State transitions** for stateful components

### 2. Integration Test Layer

#### Purpose
Verify that components work correctly together and that the system behaves as expected in realistic scenarios.

#### Structure Pattern
```swift
// Example: Tests/LockmanTestsNew/Integration/StrategyIntegration/MultiStrategyTests.swift

import XCTest
@testable import Lockman
import LockmanTestSupport

final class MultiStrategyTests: XCTestCase {
    
    func testCompositeWithPriority_HighPriorityOverride_ShouldSucceedWithCancellation() {
        // Arrange
        let compositeStrategy = LockmanCompositeStrategy([
            LockmanPriorityBasedStrategy.shared,
            LockmanSingleExecutionStrategy.shared
        ])
        
        let boundary = TestFixtures.mockBoundaryId
        let lowPriorityInfo = TestFixtures.lowPriorityInfo
        let highPriorityInfo = TestFixtures.highPriorityInfo
        
        // Act & Assert
        // Test complex interaction between multiple strategies
        XCTAssertEqual(compositeStrategy.canLock(boundaryId: boundary, info: lowPriorityInfo), .success)
        compositeStrategy.lock(boundaryId: boundary, info: lowPriorityInfo)
        
        XCTAssertEqual(compositeStrategy.canLock(boundaryId: boundary, info: highPriorityInfo), .successWithPrecedingCancellation)
        compositeStrategy.lock(boundaryId: boundary, info: highPriorityInfo)
        
        // Verify state consistency across strategies
        LockmanAssertions.assertLockCount(compositeStrategy, expectedCount: 1)
    }
}
```

### 3. Concurrency Test Layer

#### Purpose
Ensure thread safety, prevent race conditions, and validate behavior under concurrent access.

#### Structure Pattern
```swift
// Example: Tests/LockmanTestsNew/Concurrency/RaceConditionTests.swift

import XCTest
@testable import Lockman
import LockmanTestSupport

final class RaceConditionTests: XCTestCase {
    
    func testConcurrentLockAcquisition_SameBoundary_ShouldPreventRaceConditions() {
        // Arrange
        let strategy = LockmanSingleExecutionStrategy.shared
        let boundary = TestFixtures.mockBoundaryId
        let expectation = XCTestExpectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        
        var successCount = 0
        var cancellationCount = 0
        let lock = NSLock()
        
        // Act
        DispatchQueue.concurrentPerform(iterations: 100) { iteration in
            let info = TestFixtures.singleExecutionInfo
            let result = strategy.canLock(boundaryId: boundary, info: info)
            
            lock.lock()
            switch result {
            case .success:
                successCount += 1
                strategy.lock(boundaryId: boundary, info: info)
                // Simulate some work
                Thread.sleep(forTimeInterval: 0.001)
                strategy.unlock(boundaryId: boundary, info: info)
            case .cancel:
                cancellationCount += 1
            case .successWithPrecedingCancellation:
                successCount += 1
                strategy.lock(boundaryId: boundary, info: info)
                Thread.sleep(forTimeInterval: 0.001)
                strategy.unlock(boundaryId: boundary, info: info)
            }
            lock.unlock()
            
            expectation.fulfill()
        }
        
        // Assert
        wait(for: [expectation], timeout: 30.0)
        XCTAssertEqual(successCount + cancellationCount, 100)
        XCTAssertGreaterThan(cancellationCount, 0, "Should have some cancellations due to contention")
        
        // Verify no resources leaked
        LockmanAssertions.assertNoActiveLocksRemaining(strategy)
    }
}
```

### 4. State Management Test Layer

#### Purpose
Validate state consistency, resource management, and cleanup behavior.

#### Structure Pattern
```swift
// Example: Tests/LockmanTestsNew/StateManagement/StateConsistencyTests.swift

import XCTest
@testable import Lockman
import LockmanTestSupport

final class StateConsistencyTests: XCTestCase {
    
    func testStateConsistency_AfterAbnormalTermination_ShouldMaintainIntegrity() {
        // Arrange
        let strategy = LockmanSingleExecutionStrategy.shared
        let boundary = TestFixtures.mockBoundaryId
        let info = TestFixtures.singleExecutionInfo
        
        // Act - Simulate abnormal termination
        strategy.lock(boundaryId: boundary, info: info)
        
        // Force cleanup without proper unlock (simulating crash/termination)
        LockmanTestSupport.simulateAbnormalTermination()
        
        // Attempt new lock after "restart"
        let newInfo = TestFixtures.singleExecutionInfo
        let result = strategy.canLock(boundaryId: boundary, info: newInfo)
        
        // Assert
        // Should be able to acquire lock after cleanup
        LockmanAssertions.assertSuccess(result)
        XCTAssertEqual(strategy.getCurrentLocks().count, 0, "No stale locks should remain")
    }
}
```

### 5. Error Handling Test Layer

#### Purpose
Verify robustness, error recovery, and exception safety.

#### Structure Pattern
```swift
// Example: Tests/LockmanTestsNew/ErrorHandling/ErrorRecoveryTests.swift

import XCTest
@testable import Lockman
import LockmanTestSupport

final class ErrorRecoveryTests: XCTestCase {
    
    func testErrorRecovery_StrategyFailure_ShouldMaintainSystemStability() {
        // Arrange
        let mockStrategy = MockFailingStrategy()
        let container = LockmanStrategyContainer()
        
        // Act & Assert
        XCTAssertThrowsError(try container.register(mockStrategy)) { error in
            XCTAssertTrue(error is LockmanRegistrationError)
        }
        
        // Verify system remains stable after error
        let workingStrategy = LockmanSingleExecutionStrategy.shared
        XCTAssertNoThrow(try container.register(workingStrategy))
        
        // Verify normal operations continue
        let boundary = TestFixtures.mockBoundaryId
        let info = TestFixtures.singleExecutionInfo
        XCTAssertEqual(workingStrategy.canLock(boundaryId: boundary, info: info), .success)
    }
}
```

## Test Support Framework

### TestFixtures.swift
```swift
import Foundation
@testable import Lockman

public struct TestFixtures {
    // Standard test data
    public static let mockBoundaryId = MockBoundaryId("test-boundary")
    public static let singleExecutionInfo = LockmanSingleExecutionInfo(actionId: "test-action", mode: .boundary)
    public static let lowPriorityInfo = LockmanPriorityBasedInfo(actionId: "low-priority", priority: .low(.exclusive))
    public static let highPriorityInfo = LockmanPriorityBasedInfo(actionId: "high-priority", priority: .high(.exclusive))
    
    // Factory methods for different scenarios
    public static func createBoundaryId(_ name: String) -> MockBoundaryId {
        return MockBoundaryId(name)
    }
    
    public static func createSingleExecutionInfo(actionId: String, mode: LockmanSingleExecutionMode = .boundary) -> LockmanSingleExecutionInfo {
        return LockmanSingleExecutionInfo(actionId: actionId, mode: mode)
    }
}

public struct MockBoundaryId: LockmanBoundaryId {
    public let value: String
    
    public init(_ value: String) {
        self.value = value
    }
    
    public var description: String { value }
}
```

### ConcurrencyTestHelpers.swift
```swift
import Foundation
import XCTest

public struct ConcurrencyTestHelpers {
    
    /// Executes a block concurrently with specified thread count and synchronization
    public static func performConcurrent(
        iterations: Int,
        threadCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        timeout: TimeInterval = 30.0,
        block: @escaping (Int) -> Void
    ) {
        let expectation = XCTestExpectation(description: "Concurrent execution")
        expectation.expectedFulfillmentCount = iterations
        
        let queue = DispatchQueue(label: "test-queue", attributes: .concurrent)
        let group = DispatchGroup()
        
        for i in 0..<iterations {
            group.enter()
            queue.async {
                block(i)
                expectation.fulfill()
                group.leave()
            }
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Concurrent execution should complete within timeout")
    }
    
    /// Creates a barrier for thread synchronization
    public static func createSynchronizationBarrier(threadCount: Int) -> SynchronizationBarrier {
        return SynchronizationBarrier(threadCount: threadCount)
    }
}

public class SynchronizationBarrier {
    private let semaphore: DispatchSemaphore
    private let threadCount: Int
    private var arrivedCount = 0
    private let lock = NSLock()
    
    init(threadCount: Int) {
        self.threadCount = threadCount
        self.semaphore = DispatchSemaphore(value: 0)
    }
    
    public func wait() {
        lock.lock()
        arrivedCount += 1
        if arrivedCount == threadCount {
            // Release all waiting threads
            for _ in 0..<threadCount {
                semaphore.signal()
            }
        }
        lock.unlock()
        
        semaphore.wait()
    }
}
```

### LockmanAssertions.swift
```swift
import XCTest
@testable import Lockman

public struct LockmanAssertions {
    
    public static func assertSuccess(_ result: LockmanResult, file: StaticString = #file, line: UInt = #line) {
        switch result {
        case .success:
            break // Success
        case .successWithPrecedingCancellation:
            break // Also success
        case .cancel(let error):
            XCTFail("Expected success, got cancellation: \(error)", file: file, line: line)
        }
    }
    
    public static func assertCancellation(_ result: LockmanResult, file: StaticString = #file, line: UInt = #line) {
        switch result {
        case .cancel:
            break // Expected cancellation
        case .success, .successWithPrecedingCancellation:
            XCTFail("Expected cancellation, got success", file: file, line: line)
        }
    }
    
    public static func assertLockCount<T: LockmanStrategy>(_ strategy: T, expectedCount: Int, file: StaticString = #file, line: UInt = #line) {
        let actualCount = strategy.getCurrentLocks().values.flatMap { $0 }.count
        XCTAssertEqual(actualCount, expectedCount, "Lock count mismatch", file: file, line: line)
    }
    
    public static func assertNoActiveLocksRemaining<T: LockmanStrategy>(_ strategy: T, file: StaticString = #file, line: UInt = #line) {
        let activeLocks = strategy.getCurrentLocks()
        XCTAssertTrue(activeLocks.isEmpty, "Should have no active locks remaining: \(activeLocks)", file: file, line: line)
    }
    
    public static func assertMemoryStable(before: @escaping () -> Void, after: @escaping () -> Void, tolerance: Int = 1024, file: StaticString = #file, line: UInt = #line) {
        let initialMemory = getCurrentMemoryUsage()
        before()
        after()
        let finalMemory = getCurrentMemoryUsage()
        
        let difference = finalMemory - initialMemory
        XCTAssertLessThanOrEqual(difference, tolerance, "Memory usage increased by \(difference) bytes, tolerance: \(tolerance)", file: file, line: line)
    }
    
    private static func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
```

## CI/CD Integration

### Test Execution Strategy

#### Phase-based Execution
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  test-phase-1:
    name: "Phase 1: Unit Tests"
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Run Unit Tests
        run: swift test --filter LockmanTestsNew.Unit
        timeout-minutes: 10

  test-phase-2:
    name: "Phase 2: Integration Tests"
    runs-on: ubuntu-latest
    needs: test-phase-1
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Run Integration Tests
        run: swift test --filter LockmanTestsNew.Integration
        timeout-minutes: 15

  test-phase-3:
    name: "Phase 3: Concurrency Tests"
    runs-on: ubuntu-latest
    needs: test-phase-2
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Run Concurrency Tests
        run: swift test --filter LockmanTestsNew.Concurrency
        timeout-minutes: 20

  test-phase-4:
    name: "Phase 4: State & Error Tests"
    runs-on: ubuntu-latest
    needs: test-phase-2
    steps:
      - uses: actions/checkout@v3
      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
      - name: Run State Management Tests
        run: swift test --filter LockmanTestsNew.StateManagement
      - name: Run Error Handling Tests
        run: swift test --filter LockmanTestsNew.ErrorHandling
        timeout-minutes: 15
```

### Performance Monitoring
- Automated performance regression detection
- Memory leak monitoring
- Test execution time tracking
- Coverage reporting

## Quality Metrics

### Coverage Requirements
- **Unit Tests**: 95%+ line coverage
- **Integration Tests**: 90%+ integration path coverage
- **Concurrency Tests**: 100% critical path coverage
- **Error Handling**: 85%+ error path coverage

### Performance Requirements
- **Test Execution**: <35 minutes total
- **Unit Test Phase**: <10 minutes
- **Integration Phase**: <15 minutes
- **Concurrency Phase**: <20 minutes

### Reliability Requirements
- **Flaky Test Rate**: <1%
- **CI Success Rate**: >98%
- **Test Maintenance**: <10% development time

## Migration Strategy

### Phase 1: Parallel Development
- Develop new tests alongside existing tests
- Validate equivalent functionality
- Ensure no regression in existing test coverage

### Phase 2: Gradual Adoption
- Teams adopt new test patterns for new features
- Existing tests remain unchanged
- Cross-validation between old and new tests

### Phase 3: Complete Migration
- All new development uses new test structure
- Legacy tests marked for deprecation
- Documentation updated

### Phase 4: Legacy Cleanup
- Remove deprecated test files
- Consolidate test execution
- Final validation and optimization

## Conclusion

This comprehensive test system design provides a robust foundation for ensuring the quality, reliability, and performance of the Lockman library. The phased approach allows for gradual implementation while maintaining backward compatibility and ensuring continuous delivery capabilities.

The design emphasizes the critical aspects of concurrency testing while maintaining comprehensive coverage across all functionality areas. The supporting framework and CI/CD integration ensure that the test system is maintainable and provides rapid feedback for development teams.