import XCTest
@testable import LockmanCore

final class LockmanConfigurationTests: XCTestCase {

  override func tearDown() {
    super.tearDown()
    // Reset configuration after each test
    Lockman.config.reset()
  }

  // MARK: - Default Unlock Option Tests

  func testDefaultUnlockOptionIsTransition() async throws {
    XCTAssertEqual(Lockman.config.defaultUnlockOption, .transition)
  }

  func testDefaultUnlockOptionCanBeModified() async throws {
    // Change to immediate
    Lockman.config.defaultUnlockOption = .immediate
    XCTAssertEqual(Lockman.config.defaultUnlockOption, .immediate)
    
    // Change back to transition
    Lockman.config.defaultUnlockOption = .transition
    XCTAssertEqual(Lockman.config.defaultUnlockOption, .transition)
  }

  // MARK: - Handle Cancellation Errors Tests

  func testDefaultHandleCancellationErrorsIsTrue() async throws {
    XCTAssertTrue(Lockman.config.handleCancellationErrors)
  }

  func testHandleCancellationErrorsCanBeModified() async throws {
    // Disable
    Lockman.config.handleCancellationErrors = false
    XCTAssertFalse(Lockman.config.handleCancellationErrors)
    
    // Enable
    Lockman.config.handleCancellationErrors = true
    XCTAssertTrue(Lockman.config.handleCancellationErrors)
  }

  func testConfigurationResetRestoresDefaults() async throws {
    // Modify configuration
    Lockman.config.defaultUnlockOption = .immediate
    Lockman.config.handleCancellationErrors = false
    
    // Verify changes
    XCTAssertEqual(Lockman.config.defaultUnlockOption, .immediate)
    XCTAssertFalse(Lockman.config.handleCancellationErrors)
    
    // Reset configuration
    Lockman.config.reset()
    
    // Verify defaults are restored
    XCTAssertEqual(Lockman.config.defaultUnlockOption, .transition)
    XCTAssertTrue(Lockman.config.handleCancellationErrors)
  }

  func testConcurrentConfigurationAccess() async throws {
    let iterations = 100
    
    await withTaskGroup(of: Void.self) { group in
      // Task to toggle handleCancellationErrors
      group.addTask {
        for i in 0..<iterations {
          Lockman.config.handleCancellationErrors = (i % 2 == 0)
        }
      }
      
      // Task to toggle defaultUnlockOption
      group.addTask {
        for i in 0..<iterations {
          Lockman.config.defaultUnlockOption = (i % 2 == 0) ? .immediate : .transition
        }
      }
      
      // Task to read configuration
      group.addTask {
        for _ in 0..<iterations {
          _ = Lockman.config.handleCancellationErrors
          _ = Lockman.config.defaultUnlockOption
        }
      }
    }
    
    // Test passes if no crashes occur during concurrent access
    XCTAssertTrue(true)
  }
}