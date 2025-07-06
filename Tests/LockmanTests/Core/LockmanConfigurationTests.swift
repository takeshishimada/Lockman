import Foundation
import XCTest

@testable import Lockman

final class LockmanConfigurationTests: XCTestCase {
  // MARK: - Test Setup

  override func setUp() {
    // Reset configuration to default before each test
    LockmanManager.config.reset()
  }

  // MARK: - Configuration Tests

  func testDefaultConfigurationHasImmediateUnlockOption() async throws {
    // Default configuration should use .immediate
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)
  }

  func testConfigurationCanBeModified() async throws {
    // Change to immediate
    LockmanManager.config.defaultUnlockOption = .immediate
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)

    // Change to mainRunLoop
    LockmanManager.config.defaultUnlockOption = .mainRunLoop
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .mainRunLoop)

    // Change to delayed
    LockmanManager.config.defaultUnlockOption = .delayed(0.5)
    if case .delayed(let interval) = LockmanManager.config.defaultUnlockOption {
      XCTAssertEqual(interval, 0.5)
    } else {
      XCTFail("Expected delayed unlock option")
    }
  }

  func testConfigurationCanBeReset() async throws {
    // Modify configuration
    LockmanManager.config.defaultUnlockOption = .immediate
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)

    // Reset to default
    LockmanManager.config.reset()
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)
  }

  func testConfigurationIsThreadSafe() async throws {
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      // Multiple readers
      for _ in 0..<iterations {
        group.addTask {
          _ = LockmanManager.config.defaultUnlockOption
        }
      }

      // Multiple writers
      for i in 0..<iterations {
        group.addTask {
          let options: [LockmanUnlockOption] = [
            .immediate, .mainRunLoop, .transition, .delayed(0.1),
          ]
          LockmanManager.config.defaultUnlockOption = options[i % options.count]
        }
      }

      await group.waitForAll()
    }

    // Should not crash and configuration should be valid
    let finalOption = LockmanManager.config.defaultUnlockOption
    XCTAssertTrue(
      finalOption == .immediate || finalOption == .mainRunLoop || finalOption == .transition
        || {
          if case .delayed = finalOption {
            return true
          }
          return false
        }())
  }

  func testDefaultUnlockOptionPropertyWorksCorrectly() async throws {
    // Set and verify immediate
    LockmanManager.config.defaultUnlockOption = .immediate
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)

    // Change to mainRunLoop
    LockmanManager.config.defaultUnlockOption = .mainRunLoop
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .mainRunLoop)
  }

  func testConfigurationChangesPersistAcrossMultipleAccesses() async throws {
    // Set configuration
    LockmanManager.config.defaultUnlockOption = .delayed(1.0)

    // Access multiple times
    for _ in 0..<10 {
      if case .delayed(let interval) = LockmanManager.config.defaultUnlockOption {
        XCTAssertEqual(interval, 1.0)
      } else {
        XCTFail("Expected delayed unlock option with 1.0 second interval")
      }
    }
  }

  // MARK: - Handle Cancellation Errors Tests

  func testDefaultHandleCancellationErrorsIsFalse() async throws {
    XCTAssertFalse(LockmanManager.config.handleCancellationErrors)
  }

  func testHandleCancellationErrorsCanBeModified() async throws {
    // Enable (default is false)
    LockmanManager.config.handleCancellationErrors = true
    XCTAssertTrue(LockmanManager.config.handleCancellationErrors)

    // Disable
    LockmanManager.config.handleCancellationErrors = false
    XCTAssertFalse(LockmanManager.config.handleCancellationErrors)
  }

  func testHandleCancellationErrorsResetRestoresDefault() async throws {
    // Modify configuration
    LockmanManager.config.handleCancellationErrors = true
    XCTAssertTrue(LockmanManager.config.handleCancellationErrors)

    // Reset to default
    LockmanManager.config.reset()
    XCTAssertFalse(LockmanManager.config.handleCancellationErrors)
  }

  func testHandleCancellationErrorsThreadSafe() async throws {
    let iterations = 100

    await withTaskGroup(of: Void.self) { group in
      // Task to toggle handleCancellationErrors
      for _ in 0..<iterations {
        group.addTask {
          LockmanManager.config.handleCancellationErrors = Bool.random()
        }
      }

      // Task to read handleCancellationErrors
      for _ in 0..<iterations {
        group.addTask {
          _ = LockmanManager.config.handleCancellationErrors
        }
      }
    }

    // Test passes if no crashes occur
    XCTAssertTrue(true)
  }
}

final class LockmanConfigurationIntegrationTests: XCTestCase {
  // MARK: - Test Setup

  override func setUp() {
    // Reset configuration to default before each test
    LockmanManager.config.reset()
  }

  func testConfigurationAffectsLockmanUnlockBehavior() async throws {
    // Reset to ensure clean state
    LockmanManager.config.reset()

    // Test with immediate option
    LockmanManager.config.defaultUnlockOption = .immediate

    // Verify configuration is set correctly
    XCTAssertEqual(LockmanManager.config.defaultUnlockOption, .immediate)

    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = TestBoundaryId("test")
    let info = LockmanSingleExecutionInfo(actionId: "test-immediate", mode: .boundary)

    // Lock
    strategy.lock(boundaryId: boundaryId, info: info)

    // Verify it's locked - another instance with same actionId should fail
    let anotherInfo = LockmanSingleExecutionInfo(actionId: "test-immediate", mode: .boundary)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: anotherInfo))

    // Create unlock token with immediate option
    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: AnyLockmanStrategy(strategy),
      unlockOption: .immediate  // Use explicit immediate option
    )

    // Unlock should be immediate
    unlockToken()

    // For immediate unlock, no wait is needed
    // Should be able to lock again with a new info instance (same actionId)
    let newInfo = LockmanSingleExecutionInfo(actionId: "test-immediate", mode: .boundary)
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: newInfo), .success)

    // Clean up
    strategy.cleanUp()
  }

  @MainActor
  func testConfigurationWithTransitionOptionDelaysUnlock() async throws {
    // Use a unique boundary ID to avoid interference from other tests
    let boundaryId = TestBoundaryId("test-transition-\(UUID().uuidString)")

    // Create a fresh strategy instance
    let strategy = LockmanSingleExecutionStrategy()
    defer { strategy.cleanUp() }

    // Use a unique action ID
    let actionId = "test-transition-\(UUID().uuidString)"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    // Create unlock token with explicit transition option
    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: info,
      strategy: AnyLockmanStrategy(strategy),
      unlockOption: .transition
    )

    // Lock
    strategy.lock(boundaryId: boundaryId, info: info)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: info))

    // Call unlock (should be delayed)
    unlockToken()

    // Verify still locked immediately after
    XCTAssertLockFailure(
      strategy.canLock(boundaryId: boundaryId, info: info),
      "Lock should not be released immediately")

    // Wait a small amount to ensure we're testing the delay
    try await Task.sleep(nanoseconds: 100_000_000)  // 100ms

    // For transition delay, we should still be locked at this point on all platforms
    XCTAssertLockFailure(
      strategy.canLock(boundaryId: boundaryId, info: info),
      "Lock should still be held during transition delay")

    // Wait for the maximum possible transition delay across all platforms
    try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second (well beyond any platform's transition delay)

    // Now it should definitely be unlocked
    XCTAssertEqual(
      strategy.canLock(boundaryId: boundaryId, info: info), .success,
      "Lock should be released after transition delay")
  }
}

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
