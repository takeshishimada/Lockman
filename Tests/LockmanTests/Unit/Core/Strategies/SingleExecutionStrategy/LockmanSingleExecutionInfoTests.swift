import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive strategy component tests following 3-phase methodology
// Target: 100% code coverage with systematic 3-phase approach
// 1. Phase 1: Happy path coverage
// 2. Phase 2: Error cases and edge conditions
// 3. Phase 3: Integration testing where applicable

final class LockmanSingleExecutionInfoTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Debug and Additional Properties Coverage

  func testDebugDescription() {
    let info = LockmanSingleExecutionInfo(
      strategyId: LockmanStrategyId.singleExecution,
      actionId: LockmanActionId("testAction"),
      mode: .boundary
    )

    let debugDesc = info.debugDescription

    XCTAssertTrue(debugDesc.contains("LockmanSingleExecutionInfo"))
    XCTAssertTrue(debugDesc.contains("testAction"))
    XCTAssertTrue(debugDesc.contains("boundary"))
    XCTAssertTrue(debugDesc.contains("uniqueId"))
    XCTAssertFalse(debugDesc.isEmpty)
  }

  func testDebugAdditionalInfo() {
    let boundaryModeInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionModeInfo = LockmanSingleExecutionInfo(mode: .action)
    let noneModeInfo = LockmanSingleExecutionInfo(mode: .none)

    XCTAssertEqual(boundaryModeInfo.debugAdditionalInfo, "mode: boundary")
    XCTAssertEqual(actionModeInfo.debugAdditionalInfo, "mode: action")
    XCTAssertEqual(noneModeInfo.debugAdditionalInfo, "mode: none")
  }

  func testIsCancellationTargetWithDifferentModes() {
    let boundaryModeInfo = LockmanSingleExecutionInfo(mode: .boundary)
    let actionModeInfo = LockmanSingleExecutionInfo(mode: .action)
    let noneModeInfo = LockmanSingleExecutionInfo(mode: .none)

    XCTAssertTrue(boundaryModeInfo.isCancellationTarget)
    XCTAssertTrue(actionModeInfo.isCancellationTarget)
    XCTAssertFalse(noneModeInfo.isCancellationTarget)
  }

  func testEqualityOperatorBasedOnUniqueId() {
    let info1 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
    let info3 = info1

    XCTAssertNotEqual(info1, info2)
    XCTAssertEqual(info1, info3)
  }

}
