import XCTest
import ComposableArchitecture
@testable import LockmanComposable
@testable import LockmanCore

final class EffectWithLockCancellationOptionSimpleTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    Lockman.cleanup.all()
  }
  
  override func tearDown() {
    Lockman.cleanup.all()
    super.tearDown()
  }
  
  func testCancellationOptionParameterExists() {
    // This test verifies that the cancellationOption parameter is available
    // and that the code compiles successfully
    
    struct TestAction: LockmanAction, Sendable {
      typealias I = LockmanGroupCoordinatedInfo
      
      let actionId: LockmanActionId
      let lockmanInfo: LockmanGroupCoordinatedInfo
      var strategyId: LockmanStrategyId { .groupCoordination }
      
      init(actionId: LockmanActionId) {
        self.actionId = actionId
        self.lockmanInfo = LockmanGroupCoordinatedInfo(
          actionId: actionId,
          groupId: "test",
          coordinationRole: .leader(.none)
        )
      }
    }
    
    // Test that all cancellation options compile successfully
    let action = TestAction(actionId: "test")
    
    // Test cancelExisting option
    let _: Effect<Never> = .withLock(
      cancellationOption: .cancelExisting,
      operation: { _ in },
      action: action,
      cancelID: "test1"
    )
    
    // Test blockNew option  
    let _: Effect<Never> = .withLock(
      cancellationOption: .blockNew,
      operation: { _ in },
      action: action,
      cancelID: "test2"
    )
    
    // Test useStrategyDefault option
    let _: Effect<Never> = .withLock(
      cancellationOption: .useStrategyDefault,
      operation: { _ in },
      action: action,
      cancelID: "test3"
    )
    
    // Test nil (default behavior)
    let _: Effect<Never> = .withLock(
      cancellationOption: nil,
      operation: { _ in },
      action: action,
      cancelID: "test4"
    )
    
    // Test omitting the parameter entirely (should use default)
    let _: Effect<Never> = .withLock(
      operation: { _ in },
      action: action,
      cancelID: "test5"
    )
    
    // Test manual unlock variant with cancellation option
    let _: Effect<Never> = .withLock(
      cancellationOption: .cancelExisting,
      operation: { _, unlock in
        // Manual unlock control with cancellation option
        await unlock()
      },
      action: action,
      cancelID: "test6"
    )
    
    // Test concatenateWithLock with cancellation option
    let _: Effect<Never> = .concatenateWithLock(
      cancellationOption: .blockNew,
      operations: [.none],
      action: action,
      cancelID: "test7"
    )
    
    // If we reach this point without compilation errors, the API works
    XCTAssertTrue(true, "All cancellation option APIs compile successfully")
  }
  
  func testCancellationOptionDocumentationExample() {
    // This test demonstrates the usage shown in the documentation
    
    struct MyGroupAction: LockmanAction, Sendable {
      typealias I = LockmanGroupCoordinatedInfo
      
      let actionId: LockmanActionId
      let lockmanInfo: LockmanGroupCoordinatedInfo
      var strategyId: LockmanStrategyId { .groupCoordination }
      
      init(actionId: LockmanActionId) {
        self.actionId = actionId
        self.lockmanInfo = LockmanGroupCoordinatedInfo(
          actionId: actionId,
          groupId: "navigation",
          coordinationRole: .leader(.none)
        )
      }
    }
    
    // Example: Cancel existing action and allow new one to proceed
    let _: Effect<Never> = .withLock(
      cancellationOption: .cancelExisting,
      operation: { _ in
        // New navigation action takes precedence
      },
      action: MyGroupAction(actionId: "navigate"),
      cancelID: "navigation"
    )
    
    // Example: Block new action and let existing one continue
    let _: Effect<Never> = .withLock(
      cancellationOption: .blockNew,
      operation: { _ in
        // This won't execute if existing action is running
      },
      action: MyGroupAction(actionId: "navigate"),
      cancelID: "navigation"
    )
    
    // Example: Use the strategy's default behavior
    let _: Effect<Never> = .withLock(
      cancellationOption: .useStrategyDefault,
      operation: { _ in
        // Follows GroupCoordinationStrategy rules
      },
      action: MyGroupAction(actionId: "navigate"),
      cancelID: "navigation"
    )
    
    XCTAssertTrue(true, "Documentation examples compile successfully")
  }
}