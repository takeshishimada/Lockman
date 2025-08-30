import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions  
// 3. Phase 3: Integration testing where applicable

final class LockmanGroupCoordinatedInfoTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }
  
  // MARK: - Phase 1: Debug Information Coverage
  
  func testDebugDescription() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "testAction",
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    
    let debugDesc = info.debugDescription
    
    // Just test that it's not empty and has basic components
    XCTAssertFalse(debugDesc.isEmpty)
    XCTAssertTrue(debugDesc.contains("LockmanGroupCoordinatedInfo"))
    XCTAssertTrue(debugDesc.contains("testAction"))
    XCTAssertTrue(debugDesc.contains("group1"))
  }
  
  func testDebugDescriptionWithMultipleGroups() {
    let info = LockmanGroupCoordinatedInfo(
      actionId: "multiAction",
      groupIds: Set(["groupA", "groupB", "groupC"]),
      coordinationRole: .member
    )
    
    let debugDesc = info.debugDescription
    
    // Just test that it's not empty and has basic components
    XCTAssertFalse(debugDesc.isEmpty)
    XCTAssertTrue(debugDesc.contains("LockmanGroupCoordinatedInfo"))
    XCTAssertTrue(debugDesc.contains("multiAction"))
    XCTAssertTrue(debugDesc.contains("groupA"))
    XCTAssertTrue(debugDesc.contains("groupB"))
    XCTAssertTrue(debugDesc.contains("groupC"))
  }
  
  func testDebugAdditionalInfo() {
    let singleGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: "singleAction",
      groupId: "group1", 
      coordinationRole: .leader(.emptyGroup)
    )
    
    let additionalInfo = singleGroupInfo.debugAdditionalInfo
    
    // Just test that it's not empty and contains basic information
    XCTAssertFalse(additionalInfo.isEmpty)
    XCTAssertTrue(additionalInfo.contains("group1"))
    XCTAssertTrue(additionalInfo.contains("groups:"))
    XCTAssertTrue(additionalInfo.contains("r:"))
  }
  
  func testDebugAdditionalInfoWithMultipleGroups() {
    let multiGroupInfo = LockmanGroupCoordinatedInfo(
      actionId: "multiAction",
      groupIds: Set(["groupZ", "groupA", "groupM"]),
      coordinationRole: .none
    )
    
    let additionalInfo = multiGroupInfo.debugAdditionalInfo
    
    // Just test that it's not empty and contains basic information
    XCTAssertFalse(additionalInfo.isEmpty)
    XCTAssertTrue(additionalInfo.contains("groups:"))
    XCTAssertTrue(additionalInfo.contains("r:"))
    XCTAssertTrue(additionalInfo.contains("groupA"))
    XCTAssertTrue(additionalInfo.contains("groupM"))
    XCTAssertTrue(additionalInfo.contains("groupZ"))
  }
  
  // MARK: - Phase 2: Protocol Conformance Coverage
  
  func testEqualityOperatorBasedOnUniqueId() {
    let info1 = LockmanGroupCoordinatedInfo(
      actionId: "same",
      groupId: "group1",
      coordinationRole: .member
    )
    let info2 = LockmanGroupCoordinatedInfo(
      actionId: "same", 
      groupId: "group1",
      coordinationRole: .member
    )
    let info3 = info1
    
    // Different instances with same parameters should not be equal
    XCTAssertNotEqual(info1, info2)
    
    // Same instance should be equal to itself
    XCTAssertEqual(info1, info3)
  }
  
  func testIsCancellationTargetAlwaysTrue() {
    let leaderInfo = LockmanGroupCoordinatedInfo(
      actionId: "leader",
      groupId: "group1",
      coordinationRole: .leader(.emptyGroup)
    )
    
    let memberInfo = LockmanGroupCoordinatedInfo(
      actionId: "member",
      groupId: "group1", 
      coordinationRole: .member
    )
    
    let noneInfo = LockmanGroupCoordinatedInfo(
      actionId: "none",
      groupId: "group1",
      coordinationRole: .none
    )
    
    // All coordination roles should be cancellation targets
    XCTAssertTrue(leaderInfo.isCancellationTarget)
    XCTAssertTrue(memberInfo.isCancellationTarget)
    XCTAssertTrue(noneInfo.isCancellationTarget)
  }
  
}
