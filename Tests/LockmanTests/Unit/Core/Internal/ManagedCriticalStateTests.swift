import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive ManagedCriticalState tests via direct testing
// ✅ 12 test methods covering thread-safe state management functionality
// ✅ Phase 1: Basic state operations (initialization, get/set, critical region access)
// ✅ Phase 2: Thread safety and concurrent access testing
// ✅ Phase 3: Error handling and edge case scenarios

final class ManagedCriticalStateTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Basic State Operations

  func testManagedCriticalStateInitialization() {
    // Test initial state setting during initialization
    let initialValue = 42
    let managedState = ManagedCriticalState(initialValue)

    let currentValue = managedState.criticalState
    XCTAssertEqual(currentValue, initialValue)
  }

  func testManagedCriticalStateCriticalStateAccess() {
    // Test getting current state through criticalState property
    let managedState = ManagedCriticalState("initial")

    let value = managedState.criticalState
    XCTAssertEqual(value, "initial")
  }

  func testManagedCriticalStateWithCriticalRegion() {
    // Test read-only critical region access
    let managedState = ManagedCriticalState([1, 2, 3])

    let result = managedState.withCriticalRegion { state in
      return state.count
    }

    XCTAssertEqual(result, 3)
  }

  func testManagedCriticalStateWithCriticalRegionMutation() {
    // Test mutable critical region access
    let managedState = ManagedCriticalState(0)

    let result = managedState.withCriticalRegion { state in
      state += 10
      return state
    }

    XCTAssertEqual(result, 10)
    XCTAssertEqual(managedState.criticalState, 10)
  }

  func testManagedCriticalStateApplyCriticalState() {
    // Test applying new state through apply method
    let managedState = ManagedCriticalState("original")

    managedState.apply(criticalState: "updated")

    XCTAssertEqual(managedState.criticalState, "updated")
  }

  // MARK: - Phase 2: Thread Safety and Concurrent Access

  func testManagedCriticalStateConcurrentAccess() {
    // Test concurrent read/write operations
    let managedState = ManagedCriticalState(0)
    let expectation = self.expectation(description: "Concurrent operations complete")
    expectation.expectedFulfillmentCount = 10

    // Launch multiple concurrent operations
    for i in 0..<10 {
      Task.detached {
        managedState.withCriticalRegion { state in
          state += i
        }
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1.0)

    // Final state should reflect all additions (0+1+2+...+9 = 45)
    XCTAssertEqual(managedState.criticalState, 45)
  }

  func testManagedCriticalStateConcurrentReadWrite() {
    // Test mixing concurrent reads and writes
    let managedState = ManagedCriticalState(100)
    let expectation = self.expectation(description: "Mixed operations complete")
    expectation.expectedFulfillmentCount = 20

    // Mix of read and write operations
    for i in 0..<10 {
      // Write operations
      Task.detached {
        managedState.withCriticalRegion { state in
          state += 1
        }
        expectation.fulfill()
      }

      // Read operations
      Task.detached {
        let _ = managedState.criticalState
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1.0)

    // Should have incremented by 10
    XCTAssertEqual(managedState.criticalState, 110)
  }

  func testManagedCriticalStateApplyConcurrency() {
    // Test concurrent apply operations
    let managedState = ManagedCriticalState(0)
    let expectation = self.expectation(description: "Concurrent apply operations complete")
    expectation.expectedFulfillmentCount = 5

    for i in 1...5 {
      Task.detached {
        managedState.apply(criticalState: i * 10)
        expectation.fulfill()
      }
    }

    waitForExpectations(timeout: 1.0)

    // Final state should be one of the applied values
    let finalValue = managedState.criticalState
    XCTAssertTrue([10, 20, 30, 40, 50].contains(finalValue))
  }

  // MARK: - Phase 3: Error Handling and Edge Cases

  func testManagedCriticalStateWithThrowingOperation() {
    // Test critical region with throwing operations
    let managedState = ManagedCriticalState(5)

    do {
      let result = try managedState.withCriticalRegion { state -> Int in
        if state < 10 {
          throw NSError(domain: "test", code: 1, userInfo: nil)
        }
        return state * 2
      }
      XCTFail("Expected error to be thrown, but got result: \(result)")
    } catch {
      // Expected error
      XCTAssertEqual(managedState.criticalState, 5)  // State should remain unchanged
    }
  }

  func testManagedCriticalStateComplexDataStructure() {
    // Test with complex data structure
    struct TestStruct {
      var id: String
      var values: [Int]
      var isActive: Bool
    }

    let initialStruct = TestStruct(id: "test", values: [1, 2, 3], isActive: false)
    let managedState = ManagedCriticalState(initialStruct)

    managedState.withCriticalRegion { state in
      state.id = "updated"
      state.values.append(4)
      state.isActive = true
    }

    let finalState = managedState.criticalState
    XCTAssertEqual(finalState.id, "updated")
    XCTAssertEqual(finalState.values, [1, 2, 3, 4])
    XCTAssertTrue(finalState.isActive)
  }

  func testManagedCriticalStateOptionalValue() {
    // Test with optional values
    let managedState = ManagedCriticalState<String?>(nil)

    XCTAssertNil(managedState.criticalState)

    managedState.apply(criticalState: "some value")
    XCTAssertEqual(managedState.criticalState, "some value")

    managedState.withCriticalRegion { state in
      state = nil
    }
    XCTAssertNil(managedState.criticalState)
  }

  func testManagedCriticalStateSequentialAccess() {
    // Test sequential critical region operations
    let managedState = ManagedCriticalState(1)

    // First operation
    managedState.withCriticalRegion { state in
      state += 1
    }

    // Verify first operation result
    XCTAssertEqual(managedState.criticalState, 2)

    // Second operation accessing the modified state
    let result = managedState.withCriticalRegion { state in
      state *= 2
      return state
    }

    XCTAssertEqual(result, 4)  // (1 + 1) * 2 = 4
    XCTAssertEqual(managedState.criticalState, 4)
  }

}
