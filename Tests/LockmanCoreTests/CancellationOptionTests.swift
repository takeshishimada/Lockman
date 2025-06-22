import XCTest
@testable import LockmanCore

final class CancellationOptionTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    // Clean up all strategies before each test
    Lockman.cleanup.all()
  }
  
  override func tearDown() {
    // Clean up all strategies after each test
    Lockman.cleanup.all()
    super.tearDown()
  }
  
  // MARK: - GroupCoordinationStrategy Tests
  
  func testGroupCoordinationCancelExistingOption() {
    let strategy = LockmanGroupCoordinationStrategy.shared
    let boundaryId = "testBoundary"
    
    // First, lock with a member that normally couldn't start an empty group
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: "testGroup",
      coordinationRole: .member
    )
    
    // Add a leader first to make the group non-empty
    let existingLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "existingLeader",
      groupId: "testGroup",
      coordinationRole: .leader(.none)
    )
    
    // Leader can start empty group
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: existingLeaderInfo), .success)
    strategy.lock(id: boundaryId, info: existingLeaderInfo)
    
    // Now test that a new leader with cancelExisting can take over
    let newLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "newLeader", 
      groupId: "testGroup",
      coordinationRole: .leader(.none)
    )
    
    // Without cancellation option, should fail
    let resultWithoutOption = strategy.canLock(id: boundaryId, info: newLeaderInfo)
    if case .failure = resultWithoutOption {
      // Expected
    } else {
      XCTFail("Expected failure without cancellation option")
    }
    
    // With cancelExisting option, should succeed with cancellation
    let resultWithCancelOption = strategy.canLock(
      id: boundaryId,
      info: newLeaderInfo,
      cancellationOption: .cancelExisting
    )
    XCTAssertEqual(resultWithCancelOption, .successWithPrecedingCancellation)
  }
  
  func testGroupCoordinationBlockNewOption() {
    let strategy = LockmanGroupCoordinationStrategy.shared
    let boundaryId = "testBoundary"
    
    // Add an existing leader
    let existingLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "existingLeader",
      groupId: "testGroup", 
      coordinationRole: .leader(.none)
    )
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: existingLeaderInfo), .success)
    strategy.lock(id: boundaryId, info: existingLeaderInfo)
    
    // Try to add another leader with blockNew option
    let newLeaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "newLeader",
      groupId: "testGroup",
      coordinationRole: .leader(.none)
    )
    
    let result = strategy.canLock(
      id: boundaryId,
      info: newLeaderInfo,
      cancellationOption: .blockNew
    )
    
    // Should be blocked
    if case .failure = result {
      // Expected
    } else {
      XCTFail("Expected failure with blockNew option")
    }
  }
  
  // MARK: - PriorityBasedStrategy Tests
  
  func testPriorityBasedCancelExistingOption() {
    let strategy = LockmanPriorityBasedStrategy.shared
    let boundaryId = "testBoundary"
    
    // Lock with an exclusive high priority action
    let exclusiveHighInfo = LockmanPriorityBasedInfo(
      actionId: "exclusiveHigh",
      priority: .high(.exclusive)
    )
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: exclusiveHighInfo), .success)
    strategy.lock(id: boundaryId, info: exclusiveHighInfo)
    
    // Try to lock with a low priority action that normally would be blocked
    let lowPriorityInfo = LockmanPriorityBasedInfo(
      actionId: "lowPriority",
      priority: .low(.replaceable)
    )
    
    // Without cancellation option, should fail due to lower priority
    let resultWithoutOption = strategy.canLock(id: boundaryId, info: lowPriorityInfo)
    if case .failure = resultWithoutOption {
      // Expected
    } else {
      XCTFail("Expected failure without cancellation option")
    }
    
    // With cancelExisting option, should succeed with cancellation
    let resultWithCancelOption = strategy.canLock(
      id: boundaryId,
      info: lowPriorityInfo,
      cancellationOption: .cancelExisting
    )
    XCTAssertEqual(resultWithCancelOption, .successWithPrecedingCancellation)
  }
  
  func testPriorityBasedBlockNewOption() {
    let strategy = LockmanPriorityBasedStrategy.shared
    let boundaryId = "testBoundary"
    
    // Lock with a replaceable low priority action
    let replaceableLowInfo = LockmanPriorityBasedInfo(
      actionId: "replaceableLow",
      priority: .low(.replaceable)
    )
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: replaceableLowInfo), .success)
    strategy.lock(id: boundaryId, info: replaceableLowInfo)
    
    // Try to lock with a high priority action that normally would preempt
    let highPriorityInfo = LockmanPriorityBasedInfo(
      actionId: "highPriority",
      priority: .high(.exclusive)
    )
    
    // Without cancellation option, should succeed with cancellation (higher priority wins)
    let resultWithoutOption = strategy.canLock(id: boundaryId, info: highPriorityInfo)
    XCTAssertEqual(resultWithoutOption, .successWithPrecedingCancellation)
    
    // With blockNew option, should be blocked even though it has higher priority
    let resultWithBlockOption = strategy.canLock(
      id: boundaryId,
      info: highPriorityInfo,
      cancellationOption: .blockNew
    )
    
    if case .failure = resultWithBlockOption {
      // Expected
    } else {
      XCTFail("Expected failure with blockNew option")
    }
  }
  
  func testCancellationOptionUseStrategyDefault() {
    let strategy = LockmanPriorityBasedStrategy.shared
    let boundaryId = "testBoundary"
    
    // Lock with an exclusive high priority action
    let exclusiveHighInfo = LockmanPriorityBasedInfo(
      actionId: "exclusiveHigh",
      priority: .high(.exclusive)
    )
    
    XCTAssertEqual(strategy.canLock(id: boundaryId, info: exclusiveHighInfo), .success)
    strategy.lock(id: boundaryId, info: exclusiveHighInfo)
    
    // Try with another high priority action
    let anotherHighInfo = LockmanPriorityBasedInfo(
      actionId: "anotherHigh",
      priority: .high(.replaceable)
    )
    
    // Both with no option and with useStrategyDefault should give the same result
    let resultWithoutOption = strategy.canLock(id: boundaryId, info: anotherHighInfo)
    let resultWithDefault = strategy.canLock(
      id: boundaryId,
      info: anotherHighInfo,
      cancellationOption: .useStrategyDefault
    )
    
    XCTAssertEqual(resultWithoutOption, resultWithDefault)
  }
}