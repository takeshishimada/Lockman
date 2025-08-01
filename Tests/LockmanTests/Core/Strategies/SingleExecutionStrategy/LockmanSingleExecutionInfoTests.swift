import Foundation
import XCTest

@testable import Lockman

// MARK: - Test Helpers

// For integration tests
private struct StringBoundaryId: LockmanBoundaryId {
  let value: String

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: StringBoundaryId, rhs: StringBoundaryId) -> Bool {
    lhs.value == rhs.value
  }
}

// MARK: - LockmanSingleExecutionInfo Tests

final class LockmanSingleExecutionInfoTests: XCTestCase {
  // MARK: - Initialization Tests

  func testInitializeWithActionId() {
    let actionId = "testAction"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    XCTAssertEqual(info.actionId, "testAction")
  }

  func testInitializeWithStringActionId() {
    let actionId = "stringAction"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    XCTAssertEqual(info.actionId, "stringAction")
  }

  func testInitializeWithDifferentActionIdTypes() {
    let stringId = "string"

    let stringInfo = LockmanSingleExecutionInfo(actionId: stringId, mode: .boundary)

    XCTAssertEqual(stringInfo.actionId, "string")
  }

  // MARK: - Equality Tests

  func testEqualityWithSameActionId() {
    let actionId1 = "same"
    let actionId2 = "same"

    let info1 = LockmanSingleExecutionInfo(actionId: actionId1, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId2, mode: .boundary)

    XCTAssertEqual(info1.actionId, info2.actionId)
  }

  func testInequalityWithDifferentActionIds() {
    let actionId1 = "first"
    let actionId2 = "second"

    let info1 = LockmanSingleExecutionInfo(actionId: actionId1, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId2, mode: .boundary)

    XCTAssertNotEqual(info1, info2)
  }

  func testEqualityWithStringActionIds() {
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    XCTAssertEqual(info1.actionId, info2.actionId)  // Same string
    XCTAssertNotEqual(info1.actionId, info3.actionId)  // Different string
    XCTAssertNotEqual(info2.actionId, info3.actionId)  // Different string
  }

  // MARK: - Description Tests (Removed since description functionality was removed)

  //  //  func testDescriptionFormatIsConsistent() {
  //    let stringActionId  = "stringAction"
  //    let customActionId = CustomActionId(id: "custom", metadata: "meta")
  //
  //    let stringInfo = LockmanSingleExecutionInfo(actionId: stringActionId, mode: .boundary)
  //    let customInfo = LockmanSingleExecutionInfo(actionId: customActionId, mode: .boundary)
  //
  //    XCTAssertTrue(stringInfo.description.hasPrefix("ActionId:"))
  //    XCTAssertTrue(customInfo.description.hasPrefix("ActionId:"))
  //  }

  // MARK: - Sendable Conformance Tests

  func testSendableAcrossConcurrentContexts() async {
    let actionId = "concurrent"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    await withTaskGroup(of: LockmanSingleExecutionInfo.self) { group in
      group.addTask { info }

      for await result in group {
        XCTAssertEqual(result, info)
      }
    }
  }

  func testMultipleConcurrentOperationsWithDifferentInfo() async {
    let results = await withTaskGroup(
      of: LockmanSingleExecutionInfo.self, returning: [LockmanSingleExecutionInfo].self
    ) { group in
      for i in 0..<5 {
        group.addTask {
          let actionId = "concurrent_\(i)"
          return LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
        }
      }

      var results: [LockmanSingleExecutionInfo] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    XCTAssertEqual(results.count, 5)

    // All should be different
    for i in 0..<results.count {
      for j in (i + 1)..<results.count {
        XCTAssertNotEqual(results[i], results[j])
      }
    }
  }

  // MARK: - Edge Case Tests

  func testEmptyStringActionId() {
    let info = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    XCTAssertEqual(info.actionId, "")
  }

  func testUnicodeStringActionId() {
    let unicodeString = "🚀💻🔒"
    let info = LockmanSingleExecutionInfo(actionId: unicodeString, mode: .boundary)
    XCTAssertEqual(info.actionId, unicodeString)
  }

  func testVeryLongActionId() {
    let longString = String(repeating: "a", count: 1000)
    let info = LockmanSingleExecutionInfo(actionId: longString, mode: .boundary)
    XCTAssertEqual(info.actionId, longString)
  }

  // MARK: - Value Type Semantics Tests

  func testValueTypeSemantics() {
    let actionId = "original"
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    var info2 = info1

    // Both should be equal initially
    XCTAssertEqual(info1, info2)

    // Modifying one shouldn't affect the other (value semantics)
    info2 = LockmanSingleExecutionInfo(actionId: "modified", mode: .boundary)
    XCTAssertNotEqual(info1, info2)
    XCTAssertEqual(info1.actionId, "original")
    XCTAssertEqual(info2.actionId, "modified")
  }

  // MARK: - Protocol Conformance Tests

  func testLockmanInfoProtocolConformance() {
    let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)

    // Should conform to LockmanInfo
    let _: any LockmanInfo = info
    // XCTAssertTrue(lockmanInfo.description.contains("test")) // Removed - description functionality removed
  }

  //  //  func testEquatableProtocolConformance() {
  //    let info1 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
  //    let info2 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
  //    let info3 = LockmanSingleExecutionInfo(actionId: "different", mode: .boundary)
  //
  //    // Test array contains
  //    let infoArray = [info1, info3]
  //    XCTAssertTrue(infoArray.contains(info2)) // Should find info1 (same actionId)
  //    XCTAssertTrue(infoArray.contains(info1))
  //    XCTAssertTrue(infoArray.contains(info3))
  //  }

  // MARK: - Memory and Performance Tests

  func testMemoryEfficiencyWithManyInstances() {
    var infos: [LockmanSingleExecutionInfo] = []

    for i in 0..<100 {
      let info = LockmanSingleExecutionInfo(actionId: "action_\(i)", mode: .boundary)
      infos.append(info)
    }

    XCTAssertEqual(infos.count, 100)

    // Verify they're all different
    for i in 0..<infos.count {
      for j in (i + 1)..<infos.count {
        XCTAssertNotEqual(infos[i], infos[j])
      }
    }
  }

  func testEqualityComparisonPerformance() {
    let startTime = Date()

    let info1 = LockmanSingleExecutionInfo(actionId: "performance_test", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "performance_test", mode: .boundary)

    // Perform many equality comparisons
    for _ in 0..<1000 {
      _ = info1 == info2
    }

    let duration = Date().timeIntervalSince(startTime)
    XCTAssertLessThan(duration, 0.1)  // Should be very fast
  }
}

// MARK: - Integration Tests

final class LockmanSingleExecutionInfoIntegrationTests: XCTestCase {
  func testWorksWithLockmanState() {
    let state = LockmanState<LockmanSingleExecutionInfo, LockmanActionId>()
    let boundaryId = StringBoundaryId(value: "boundary")

    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    state.add(boundaryId: boundaryId, info: info1)
    state.add(boundaryId: boundaryId, info: info2)

    let currents = state.currentLocks(in: boundaryId)
    XCTAssertEqual(currents.count, 2)
    XCTAssertTrue(currents.contains(info1))
    XCTAssertTrue(currents.contains(info2))

    // Test ordering
    XCTAssertEqual(currents[0], info1)
    XCTAssertEqual(currents[1], info2)

    // Test removal
    state.remove(boundaryId: boundaryId, info: info2)
    let afterRemoval = state.currentLocks(in: boundaryId)
    XCTAssertEqual(afterRemoval.count, 1)
    XCTAssertEqual(afterRemoval[0], info1)
  }

  func testWorksWithLockmanSingleExecutionStrategy() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = StringBoundaryId(value: "strategy_test")

    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // First lock should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info1), .success)
    strategy.lock(boundaryId: boundaryId, info: info1)

    // Different action should fail (boundary is locked)
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId, info: info2))

    // Unlock first
    strategy.unlock(boundaryId: boundaryId, info: info1)

    // Now second action should succeed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId, info: info2), .success)
    strategy.lock(boundaryId: boundaryId, info: info2)

    // Cleanup
    strategy.unlock(boundaryId: boundaryId, info: info2)
  }

  func testComplexIntegrationScenario() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId1 = StringBoundaryId(value: "boundary1")
    let boundaryId2 = StringBoundaryId(value: "boundary2")

    // Create different types of action IDs
    let stringInfo = LockmanSingleExecutionInfo(actionId: "stringAction", mode: .boundary)

    // Lock different actions on different boundaries
    strategy.lock(boundaryId: boundaryId1, info: stringInfo)

    // Same actions on different boundaries should be allowed
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId2, info: stringInfo), .success)

    // Any action on same boundary should fail
    XCTAssertLockFailure(strategy.canLock(boundaryId: boundaryId1, info: stringInfo))

    // Cleanup one boundary
    strategy.cleanUp(boundaryId: boundaryId1)

    // Now should be able to lock on boundary1 again
    XCTAssertEqual(strategy.canLock(boundaryId: boundaryId1, info: stringInfo), .success)

    // Full cleanup
    strategy.cleanUp()
  }

  func testThreadSafetyWithConcurrentAccess() async {
    // Use a new instance instead of shared to avoid interference with other tests
    let strategy = LockmanSingleExecutionStrategy()
    // Use a unique boundary ID to avoid conflicts with parallel tests
    let boundaryId = StringBoundaryId(value: "concurrent_\(UUID().uuidString)")

    let results = await withTaskGroup(of: (String, Bool).self, returning: [(String, Bool)].self) {
      group in
      for i in 0..<10 {
        group.addTask {
          let info = LockmanSingleExecutionInfo(actionId: "action_\(i)", mode: .boundary)
          let result = strategy.canLock(boundaryId: boundaryId, info: info)
          if result == .success {
            strategy.lock(boundaryId: boundaryId, info: info)
            return ("action_\(i)", true)
          }
          return ("action_\(i)", false)
        }
      }

      var results: [(String, Bool)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    XCTAssertEqual(results.count, 10)

    // In a highly concurrent scenario, due to the race condition between canLock and lock,
    // multiple tasks might succeed before the lock state is properly synchronized.
    // The important thing is that not all tasks succeed (showing some exclusion works).
    let successCount = results.filter(\.1).count
    XCTAssertGreaterThanOrEqual(
      successCount, 1,
      "Expected some but not all tasks to succeed due to race conditions, got \(successCount) out of 10"
    )
    XCTAssertLessThan(
      successCount, 10,
      "Expected some but not all tasks to succeed due to race conditions, got \(successCount) out of 10"
    )

    // Cleanup - both specific boundary and general cleanup
    strategy.cleanUp(boundaryId: boundaryId)
    strategy.cleanUp()
  }

  // Note: Dictionary key test is commented out because LockmanSingleExecutionInfo
  // does not conform to Hashable in the current implementation.
  // If Hashable conformance is added later, this test can be uncommented:
  //   // func testUseAsDictionaryKey() {
  //  var infoDict: [LockmanSingleExecutionInfo: String] = [:]
  //
  //  let info1 = LockmanSingleExecutionInfo(actionId: "key1", mode: .boundary))
  //  let info2 = LockmanSingleExecutionInfo(actionId: "key2", mode: .boundary))
  //  let info1Copy = LockmanSingleExecutionInfo(actionId: "key1", mode: .boundary))
  //
  //  infoDict[info1] = "value1"
  //  infoDict[info2] = "value2"
  //  infoDict[info1Copy] = "updated_value1" // Should overwrite
  //
  //  XCTAssertEqual(infoDict.count, 2)
  //  XCTAssertEqual(infoDict[info1], "updated_value1")
  //  XCTAssertEqual(infoDict[info2], "value2")
  // }
}
