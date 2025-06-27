import XCTest

@testable import Lockman

// Test implementation of LockmanInfo
private struct TestLockmanInfo: LockmanInfo {
  let strategyId: LockmanStrategyId
  let actionId: LockmanActionId
  let uniqueId: UUID
  let additionalData: String

  var debugAdditionalInfo: String {
    "test: \(additionalData)"
  }

  var debugDescription: String {
    "TestLockmanInfo(action: \(actionId), strategy: \(strategyId), data: \(additionalData))"
  }
}

final class LockmanInfoTests: XCTestCase {

  func testLockmanInfoProtocolRequirements() {
    // Create test instance
    let info = TestLockmanInfo(
      strategyId: LockmanStrategyId("TestStrategy"),
      actionId: LockmanActionId("testAction"),
      uniqueId: UUID(),
      additionalData: "test data"
    )

    // Verify protocol requirements
    XCTAssertEqual(info.strategyId, LockmanStrategyId("TestStrategy"))
    XCTAssertEqual(info.actionId, LockmanActionId("testAction"))
    XCTAssertEqual(info.additionalData, "test data")

    // Verify debug information
    XCTAssertEqual(info.debugAdditionalInfo, "test: test data")
    XCTAssertTrue(info.debugDescription.contains("testAction"))
    XCTAssertTrue(info.debugDescription.contains("TestStrategy"))
  }

  func testDefaultDebugAdditionalInfo() {
    // Create minimal implementation without overriding debugAdditionalInfo
    struct MinimalLockmanInfo: LockmanInfo {
      let strategyId: LockmanStrategyId = .singleExecution
      let actionId: LockmanActionId = "minimal"
      let uniqueId: UUID = UUID()
      var debugDescription: String { "MinimalInfo" }
    }

    let info = MinimalLockmanInfo()

    // Default implementation should return empty string
    XCTAssertEqual(info.debugAdditionalInfo, "")
  }

  func testUniqueIdUniqueness() {
    // Create multiple instances with same actionId
    let info1 = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "sameAction",
      uniqueId: UUID(),
      additionalData: "data1"
    )

    let info2 = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "sameAction",
      uniqueId: UUID(),
      additionalData: "data2"
    )

    // Same actionId but different uniqueId
    XCTAssertEqual(info1.actionId, info2.actionId)
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  func testStrategyIdExamples() {
    // Test various strategy ID formats
    let singleExecutionInfo = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "test",
      uniqueId: UUID(),
      additionalData: ""
    )
    XCTAssertEqual(singleExecutionInfo.strategyId, .singleExecution)

    let customStrategyInfo = TestLockmanInfo(
      strategyId: LockmanStrategyId("CustomApp.RateLimitStrategy"),
      actionId: "test",
      uniqueId: UUID(),
      additionalData: ""
    )
    XCTAssertEqual(customStrategyInfo.strategyId.rawValue, "CustomApp.RateLimitStrategy")
  }

  func testActionIdExamples() {
    // Test various actionId formats
    let simpleAction = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "login",
      uniqueId: UUID(),
      additionalData: ""
    )
    XCTAssertEqual(simpleAction.actionId, "login")

    let parameterizedAction = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "fetchUser_123",
      uniqueId: UUID(),
      additionalData: ""
    )
    XCTAssertEqual(parameterizedAction.actionId, "fetchUser_123")

    let scopedAction = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "sync_userProfile",
      uniqueId: UUID(),
      additionalData: ""
    )
    XCTAssertEqual(scopedAction.actionId, "sync_userProfile")
  }

  func testSendableConformance() {
    // Test that LockmanInfo is Sendable
    let info = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "test",
      uniqueId: UUID(),
      additionalData: "data"
    )

    // This should compile without warnings if properly Sendable
    Task {
      let capturedInfo = info
      XCTAssertEqual(capturedInfo.actionId, "test")
    }
  }

  func testCustomDebugStringConvertible() {
    let info = TestLockmanInfo(
      strategyId: .singleExecution,
      actionId: "debugTest",
      uniqueId: UUID(),
      additionalData: "debug data"
    )

    // Verify CustomDebugStringConvertible conformance
    let debugString = String(reflecting: info)
    XCTAssertTrue(debugString.contains("debugTest"))
    XCTAssertTrue(debugString.contains("debug data"))
  }
}

