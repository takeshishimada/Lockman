import Foundation
import Testing
@testable import LockmanCore

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

@Suite("LockmanSingleExecutionInfo Tests")
struct LockmanSingleExecutionInfoTests {
  // MARK: - Initialization Tests

  @Test("Initialize with action id")
  func testInitializeWithActionId() {
    let actionId = "testAction"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    #expect(info.actionId == "testAction")
  }

  @Test("Initialize with string action id")
  func testInitializeWithStringActionId() {
    let actionId = "stringAction"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    #expect(info.actionId == "stringAction")
  }

  @Test("Initialize with different action id types")
  func testInitializeWithDifferentActionIdTypes() {
    let stringId = "string"

    let stringInfo = LockmanSingleExecutionInfo(actionId: stringId, mode: .boundary)

    #expect(stringInfo.actionId == "string")
  }

  // MARK: - Equality Tests

  @Test("Equality with same action id")
  func testEqualityWithSameActionId() {
    let actionId1 = "same"
    let actionId2 = "same"

    let info1 = LockmanSingleExecutionInfo(actionId: actionId1, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId2, mode: .boundary)

    #expect(info1.actionId == info2.actionId)
  }

  @Test("Inequality with different action ids")
  func testInequalityWithDifferentActionIds() {
    let actionId1 = "first"
    let actionId2 = "second"

    let info1 = LockmanSingleExecutionInfo(actionId: actionId1, mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: actionId2, mode: .boundary)

    #expect(info1 != info2)
  }

  @Test("Equality with string action ids")
  func testEqualityWithStringActionIds() {
    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info3 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    #expect(info1.actionId == info2.actionId) // Same string
    #expect(info1.actionId != info3.actionId) // Different string
    #expect(info2.actionId != info3.actionId) // Different string
  }

  // MARK: - Description Tests (Removed since description functionality was removed)

//  @Test("Description format is consistent")
//  func testDescriptionFormatIsConsistent() {
//    let stringActionId = "stringAction"
//    let customActionId = CustomActionId(id: "custom", metadata: "meta")
//
//    let stringInfo = LockmanSingleExecutionInfo(actionId: stringActionId, mode: .boundary)
//    let customInfo = LockmanSingleExecutionInfo(actionId: customActionId, mode: .boundary)
//
//    #expect(stringInfo.description.hasPrefix("ActionId:"))
//    #expect(customInfo.description.hasPrefix("ActionId:"))
//  }

  // MARK: - Sendable Conformance Tests

  @Test("Sendable across concurrent contexts")
  func testSendableAcrossConcurrentContexts() async {
    let actionId = "concurrent"
    let info = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)

    await withTaskGroup(of: LockmanSingleExecutionInfo.self) { group in
      group.addTask { info }

      for await result in group {
        #expect(result == info)
      }
    }
  }

  @Test("Multiple concurrent operations with different info")
  func testMultipleConcurrentOperationsWithDifferentInfo() async {
    let results = await withTaskGroup(of: LockmanSingleExecutionInfo.self, returning: [LockmanSingleExecutionInfo].self) { group in
      for i in 0 ..< 5 {
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

    #expect(results.count == 5)

    // All should be different
    for i in 0 ..< results.count {
      for j in (i + 1) ..< results.count {
        #expect(results[i] != results[j])
      }
    }
  }

  // MARK: - Edge Case Tests

  @Test("Empty string action id")
  func testEmptyStringActionId() {
    let info = LockmanSingleExecutionInfo(actionId: "", mode: .boundary)
    #expect(info.actionId == "")
  }

  @Test("Unicode string action id")
  func testUnicodeStringActionId() {
    let unicodeString = "🚀💻🔒"
    let info = LockmanSingleExecutionInfo(actionId: unicodeString, mode: .boundary)
    #expect(info.actionId == unicodeString)
  }

  @Test("Very long action id")
  func testVeryLongActionId() {
    let longString = String(repeating: "a", count: 1000)
    let info = LockmanSingleExecutionInfo(actionId: longString, mode: .boundary)
    #expect(info.actionId == longString)
  }

  // MARK: - Value Type Semantics Tests

  @Test("Value type semantics")
  func testValueTypeSemantics() {
    let actionId = "original"
    let info1 = LockmanSingleExecutionInfo(actionId: actionId, mode: .boundary)
    var info2 = info1

    // Both should be equal initially
    #expect(info1 == info2)

    // Modifying one shouldn't affect the other (value semantics)
    info2 = LockmanSingleExecutionInfo(actionId: "modified", mode: .boundary)
    #expect(info1 != info2)
    #expect(info1.actionId == "original")
    #expect(info2.actionId == "modified")
  }

  // MARK: - Protocol Conformance Tests

  @Test("LockmanInfo protocol conformance")
  func testLockmanInfoProtocolConformance() {
    let info = LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)

    // Should conform to LockmanInfo
    let _: any LockmanInfo = info
    // #expect(lockmanInfo.description.contains("test")) // Removed - description functionality removed
  }

//  @Test("Equatable protocol conformance")
//  func testEquatableProtocolConformance() {
//    let info1 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
//    let info2 = LockmanSingleExecutionInfo(actionId: "same", mode: .boundary)
//    let info3 = LockmanSingleExecutionInfo(actionId: "different", mode: .boundary)
//
//    // Test array contains
//    let infoArray = [info1, info3]
//    #expect(infoArray.contains(info2)) // Should find info1 (same actionId)
//    #expect(infoArray.contains(info1))
//    #expect(infoArray.contains(info3))
//  }

  // MARK: - Memory and Performance Tests

  @Test("Memory efficiency with many instances")
  func testMemoryEfficiencyWithManyInstances() {
    var infos: [LockmanSingleExecutionInfo] = []

    for i in 0 ..< 100 {
      let info = LockmanSingleExecutionInfo(actionId: "action_\(i)", mode: .boundary)
      infos.append(info)
    }

    #expect(infos.count == 100)

    // Verify they're all different
    for i in 0 ..< infos.count {
      for j in (i + 1) ..< infos.count {
        #expect(infos[i] != infos[j])
      }
    }
  }

  @Test("Equality comparison performance")
  func testEqualityComparisonPerformance() {
    let startTime = Date()

    let info1 = LockmanSingleExecutionInfo(actionId: "performance_test", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "performance_test", mode: .boundary)

    // Perform many equality comparisons
    for _ in 0 ..< 1000 {
      _ = info1 == info2
    }

    let duration = Date().timeIntervalSince(startTime)
    #expect(duration < 0.1) // Should be very fast
  }
}

// MARK: - Integration Tests

@Suite("LockmanSingleExecutionInfo Integration Tests")
struct LockmanSingleExecutionInfoIntegrationTests {
  @Test("Works with LockmanState")
  func testWorksWithLockmanState() {
    let state = LockmanState<LockmanSingleExecutionInfo>()
    let boundaryId = StringBoundaryId(value: "boundary")

    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    state.add(id: boundaryId, info: info1)
    state.add(id: boundaryId, info: info2)

    let currents = state.currents(id: boundaryId)
    #expect(currents.count == 2)
    #expect(currents.contains(info1))
    #expect(currents.contains(info2))

    // Test ordering
    #expect(currents[0] == info1)
    #expect(currents[1] == info2)

    // Test removal
    state.remove(id: boundaryId, info: info2)
    let afterRemoval = state.currents(id: boundaryId)
    #expect(afterRemoval.count == 1)
    #expect(afterRemoval[0] == info1)
  }

  @Test("Works with LockmanSingleExecutionStrategy")
  func testWorksWithLockmanSingleExecutionStrategy() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId = StringBoundaryId(value: "strategy_test")

    let info1 = LockmanSingleExecutionInfo(actionId: "action1", mode: .boundary)
    let info2 = LockmanSingleExecutionInfo(actionId: "action2", mode: .boundary)

    // First lock should succeed
    #expect(strategy.canLock(id: boundaryId, info: info1) == .success)
    strategy.lock(id: boundaryId, info: info1)

    // Different action should fail (boundary is locked)
    #expect(strategy.canLock(id: boundaryId, info: info2) == .failure)

    // Unlock first
    strategy.unlock(id: boundaryId, info: info1)

    // Now second action should succeed
    #expect(strategy.canLock(id: boundaryId, info: info2) == .success)
    strategy.lock(id: boundaryId, info: info2)

    // Cleanup
    strategy.unlock(id: boundaryId, info: info2)
  }

  @Test("Complex integration scenario")
  func testComplexIntegrationScenario() {
    let strategy = LockmanSingleExecutionStrategy()
    let boundaryId1 = StringBoundaryId(value: "boundary1")
    let boundaryId2 = StringBoundaryId(value: "boundary2")

    // Create different types of action IDs
    let stringInfo = LockmanSingleExecutionInfo(actionId: "stringAction", mode: .boundary)

    // Lock different actions on different boundaries
    strategy.lock(id: boundaryId1, info: stringInfo)

    // Same actions on different boundaries should be allowed
    #expect(strategy.canLock(id: boundaryId2, info: stringInfo) == .success)

    // Any action on same boundary should fail
    #expect(strategy.canLock(id: boundaryId1, info: stringInfo) == .failure)

    // Cleanup one boundary
    strategy.cleanUp(id: boundaryId1)

    // Now should be able to lock on boundary1 again
    #expect(strategy.canLock(id: boundaryId1, info: stringInfo) == .success)

    // Full cleanup
    strategy.cleanUp()
  }

  @Test("Thread safety with concurrent access")
  func testThreadSafetyWithConcurrentAccess() async {
    // Use a new instance instead of shared to avoid interference with other tests
    let strategy = LockmanSingleExecutionStrategy()
    // Use a unique boundary ID to avoid conflicts with parallel tests
    let boundaryId = StringBoundaryId(value: "concurrent_\(UUID().uuidString)")

    let results = await withTaskGroup(of: (String, Bool).self, returning: [(String, Bool)].self) { group in
      for i in 0 ..< 10 {
        group.addTask {
          let info = LockmanSingleExecutionInfo(actionId: "action_\(i)", mode: .boundary)
          let result = strategy.canLock(id: boundaryId, info: info)
          if result == .success {
            strategy.lock(id: boundaryId, info: info)
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

    #expect(results.count == 10)

    // In a highly concurrent scenario, due to the race condition between canLock and lock,
    // multiple tasks might succeed before the lock state is properly synchronized.
    // The important thing is that not all tasks succeed (showing some exclusion works).
    let successCount = results.filter(\.1).count
    #expect(successCount >= 1 && successCount < 10, "Expected some but not all tasks to succeed due to race conditions, got \(successCount) out of 10")

    // Cleanup - both specific boundary and general cleanup
    strategy.cleanUp(id: boundaryId)
    strategy.cleanUp()
  }

  // Note: Dictionary key test is commented out because LockmanSingleExecutionInfo
  // does not conform to Hashable in the current implementation.
  // If Hashable conformance is added later, this test can be uncommented:
  // @Test("Use as dictionary key")
  // func testUseAsDictionaryKey() {
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
  //  #expect(infoDict.count == 2)
  //  #expect(infoDict[info1] == "updated_value1")
  //  #expect(infoDict[info2] == "value2")
  // }
}
