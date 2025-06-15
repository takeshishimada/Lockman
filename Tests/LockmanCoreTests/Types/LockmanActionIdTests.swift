import Testing
@testable import LockmanCore

// MARK: - LockmanActionId Tests

/// Tests for the LockmanActionId type alias.
///
/// ## Test Coverage
/// - Type alias behavior
/// - String operations
/// - Common usage patterns
@Suite("LockmanActionId Tests")
struct LockmanActionIdTests {
  // MARK: - Basic Functionality Tests

  @Suite("Basic Functionality")
  struct BasicFunctionalityTests {
    @Test("Type alias works as String")
    func testTypeAliasWorksAsString() {
      let actionId: LockmanActionId = "test-action"
      #expect(actionId == "test-action")
      // LockmanActionId is a type alias for String, so it's always a String
    }

    @Test("String operations available")
    func testStringOperationsAvailable() {
      let actionId: LockmanActionId = "test-action-123"

      #expect(actionId.contains("action"))
      #expect(actionId.hasPrefix("test"))
      #expect(actionId.hasSuffix("123"))
      #expect(actionId.count == 15)
    }

    @Test("Comparison operations")
    func testComparisonOperations() {
      let id1: LockmanActionId = "action-a"
      let id2: LockmanActionId = "action-b"
      let id3: LockmanActionId = "action-a"

      #expect(id1 == id3)
      #expect(id1 != id2)
      #expect(id1 < id2) // Lexicographic comparison
    }
  }

  // MARK: - Common Usage Patterns

  @Suite("Common Usage Patterns")
  struct CommonUsagePatternsTests {
    @Test("Empty action ID")
    func testEmptyActionId() {
      let emptyId: LockmanActionId = ""
      #expect(emptyId.isEmpty)
      #expect(emptyId.isEmpty)
    }

    @Test("Action ID with special characters")
    func testActionIdWithSpecialCharacters() {
      let specialId: LockmanActionId = "action/with\\special|chars:123"
      #expect(specialId.contains("/"))
      #expect(specialId.contains("\\"))
      #expect(specialId.contains("|"))
      #expect(specialId.contains(":"))
    }

    @Test("Unicode action IDs")
    func testUnicodeActionIds() {
      let unicodeId: LockmanActionId = "アクション_🔒_test"
      #expect(unicodeId.contains("アクション"))
      #expect(unicodeId.contains("🔒"))
      #expect(unicodeId.contains("test"))
    }

    @Test("Parameterized action IDs")
    func testParameterizedActionIds() {
      let userId = 123
      let actionType = "fetch"
      let parameterizedId: LockmanActionId = "\(actionType)_user_\(userId)"

      #expect(parameterizedId == "fetch_user_123")
      #expect(parameterizedId.hasPrefix("fetch"))
      #expect(parameterizedId.hasSuffix("123"))
    }
  }

  // MARK: - String Interpolation Tests

  @Suite("String Interpolation")
  struct StringInterpolationTests {
    @Test("Interpolation with various types")
    func testInterpolationWithVariousTypes() {
      let intValue = 42
      let doubleValue = 3.14
      let boolValue = true

      let id1: LockmanActionId = "int_\(intValue)"
      let id2: LockmanActionId = "double_\(doubleValue)"
      let id3: LockmanActionId = "bool_\(boolValue)"

      #expect(id1 == "int_42")
      #expect(id2 == "double_3.14")
      #expect(id3 == "bool_true")
    }

    @Test("Complex interpolation")
    func testComplexInterpolation() {
      struct User {
        let id: Int
        let name: String
      }

      let user = User(id: 999, name: "TestUser")
      let timestamp = 1234567890

      let complexId: LockmanActionId = "user_\(user.id)_\(user.name)_\(timestamp)"
      #expect(complexId == "user_999_TestUser_1234567890")
    }
  }

  // MARK: - Collection Usage Tests

  @Suite("Collection Usage")
  struct CollectionUsageTests {
    @Test("Array of action IDs")
    func testArrayOfActionIds() {
      let actionIds: [LockmanActionId] = ["action1", "action2", "action3"]

      #expect(actionIds.count == 3)
      #expect(actionIds.contains("action2"))
      #expect(actionIds.first == "action1")
      #expect(actionIds.last == "action3")
    }

    @Test("Set of action IDs")
    func testSetOfActionIds() {
      var actionSet: Set<LockmanActionId> = ["action1", "action2", "action1"]

      #expect(actionSet.count == 2) // Duplicates removed
      #expect(actionSet.contains("action1"))
      #expect(actionSet.contains("action2"))

      actionSet.insert("action3")
      #expect(actionSet.count == 3)
    }

    @Test("Dictionary with action ID keys")
    func testDictionaryWithActionIdKeys() {
      let actionData: [LockmanActionId: Int] = [
        "action1": 10,
        "action2": 20,
        "action3": 30,
      ]

      #expect(actionData["action2"] == 20)
      #expect(actionData.keys.contains("action1"))
      #expect(actionData.values.contains(30))
    }
  }

  // MARK: - Performance Considerations

  @Suite("Performance Considerations")
  struct PerformanceConsiderationsTests {
    @Test("Long action IDs")
    func testLongActionIds() {
      let longId: LockmanActionId = String(repeating: "a", count: 1000)
      #expect(longId.count == 1000)
      #expect(longId.hasPrefix("aaa"))
      #expect(longId.hasSuffix("aaa"))
    }

    @Test("Frequent string operations")
    func testFrequentStringOperations() {
      let baseId: LockmanActionId = "base"
      var modifiedId = baseId

      for i in 0 ..< 10 {
        modifiedId += "_\(i)"
      }

      #expect(modifiedId == "base_0_1_2_3_4_5_6_7_8_9")
    }
  }
}
