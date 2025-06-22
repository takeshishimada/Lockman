import XCTest

@testable import LockmanCore

// MARK: - LockmanActionId Tests

/// Tests for the LockmanActionId type alias.
///
/// ## Test Coverage
/// - Type alias behavior
/// - String operations
/// - Common usage patterns
final class LockmanActionIdTests: XCTestCase {
  // MARK: - Basic Functionality Tests

  final class BasicFunctionalityTests: XCTestCase {
    func testTypeAliasWorksAsString() {
      let actionId: LockmanActionId = "test-action"
      XCTAssertEqual(actionId, "test-action")
      // LockmanActionId is a type alias for String, so it's always a String
    }

    func testStringOperationsAvailable() {
      let actionId: LockmanActionId = "test-action-123"

      XCTAssertTrue(actionId.contains("action"))
      XCTAssertTrue(actionId.hasPrefix("test"))
      XCTAssertTrue(actionId.hasSuffix("123"))
      XCTAssertEqual(actionId.count, 15)
    }

    func testComparisonOperations() {
      let id1: LockmanActionId = "action-a"
      let id2: LockmanActionId = "action-b"
      let id3: LockmanActionId = "action-a"

      XCTAssertEqual(id1, id3)
      XCTAssertNotEqual(id1, id2)
      XCTAssertLessThan(id1, id2)  // Lexicographic comparison
    }
  }

  // MARK: - Common Usage Patterns

  final class CommonUsagePatternsTests: XCTestCase {
    func testEmptyActionId() {
      let emptyId: LockmanActionId = ""
      XCTAssertTrue(emptyId.isEmpty)
      XCTAssertTrue(emptyId.isEmpty)
    }

    func testActionIdWithSpecialCharacters() {
      let specialId: LockmanActionId = "action/with\\special|chars:123"
      XCTAssertTrue(specialId.contains("/"))
      XCTAssertTrue(specialId.contains("\\"))
      XCTAssertTrue(specialId.contains("|"))
      XCTAssertTrue(specialId.contains(":"))
    }

    func testUnicodeActionIds() {
      let unicodeId: LockmanActionId = "アクション_🔒_test"
      XCTAssertTrue(unicodeId.contains("アクション"))
      XCTAssertTrue(unicodeId.contains("🔒"))
      XCTAssertTrue(unicodeId.contains("test"))
    }

    func testParameterizedActionIds() {
      let userId = 123
      let actionType = "fetch"
      let parameterizedId: LockmanActionId = "\(actionType)_user_\(userId)"

      XCTAssertEqual(parameterizedId, "fetch_user_123")
      XCTAssertTrue(parameterizedId.hasPrefix("fetch"))
      XCTAssertTrue(parameterizedId.hasSuffix("123"))
    }
  }

  // MARK: - String Interpolation Tests

  final class StringInterpolationTests: XCTestCase {
    func testInterpolationWithVariousTypes() {
      let intValue = 42
      let doubleValue = 3.14
      let boolValue = true

      let id1: LockmanActionId = "int_\(intValue)"
      let id2: LockmanActionId = "double_\(doubleValue)"
      let id3: LockmanActionId = "bool_\(boolValue)"

      XCTAssertEqual(id1, "int_42")
      XCTAssertEqual(id2, "double_3.14")
      XCTAssertEqual(id3, "bool_true")
    }

    func testComplexInterpolation() {
      struct User {
        let id: Int
        let name: String
      }

      let user = User(id: 999, name: "TestUser")
      let timestamp = 1_234_567_890

      let complexId: LockmanActionId = "user_\(user.id)_\(user.name)_\(timestamp)"
      XCTAssertEqual(complexId, "user_999_TestUser_1234567890")
    }
  }

  // MARK: - Collection Usage Tests

  final class CollectionUsageTests: XCTestCase {
    func testArrayOfActionIds() {
      let actionIds: [LockmanActionId] = ["action1", "action2", "action3"]

      XCTAssertEqual(actionIds.count, 3)
      XCTAssertTrue(actionIds.contains("action2"))
      XCTAssertEqual(actionIds.first, "action1")
      XCTAssertEqual(actionIds.last, "action3")
    }

    func testSetOfActionIds() {
      var actionSet: Set<LockmanActionId> = ["action1", "action2", "action1"]

      XCTAssertEqual(actionSet.count, 2)  // Duplicates removed
      XCTAssertTrue(actionSet.contains("action1"))
      XCTAssertTrue(actionSet.contains("action2"))

      actionSet.insert("action3")
      XCTAssertEqual(actionSet.count, 3)
    }

    func testDictionaryWithActionIdKeys() {
      let actionData: [LockmanActionId: Int] = [
        "action1": 10,
        "action2": 20,
        "action3": 30,
      ]

      XCTAssertEqual(actionData["action2"], 20)
      XCTAssertTrue(actionData.keys.contains("action1"))
      XCTAssertTrue(actionData.values.contains(30))
    }
  }

  // MARK: - Performance Considerations

  final class PerformanceConsiderationsTests: XCTestCase {
    func testLongActionIds() {
      let longId: LockmanActionId = String(repeating: "a", count: 1000)
      XCTAssertEqual(longId.count, 1000)
      XCTAssertTrue(longId.hasPrefix("aaa"))
      XCTAssertTrue(longId.hasSuffix("aaa"))
    }

    func testFrequentStringOperations() {
      let baseId: LockmanActionId = "base"
      var modifiedId = baseId

      for i in 0..<10 {
        modifiedId += "_\(i)"
      }

      XCTAssertEqual(modifiedId, "base_0_1_2_3_4_5_6_7_8_9")
    }
  }
}
