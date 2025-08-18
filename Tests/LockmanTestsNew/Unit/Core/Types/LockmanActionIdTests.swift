import XCTest

@testable import Lockman

/// Unit tests for LockmanActionId
///
/// Tests the unique identifier typealias for Lockman actions that leverages
/// String's built-in Equatable and Sendable conformance.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Basic Type Properties
/// - [ ] LockmanActionId is String typealias verification
/// - [ ] Equatable conformance through String
/// - [ ] Sendable conformance through String
/// - [ ] Type safety and interchangeability with String
///
/// ### String Operations and Behavior
/// - [ ] String literal assignment to LockmanActionId
/// - [ ] String concatenation and manipulation
/// - [ ] Empty string as valid LockmanActionId
/// - [ ] Unicode and special character support
/// - [ ] String comparison operations (==, !=, <, >)
/// - [ ] Case sensitivity in comparisons
///
/// ### Concurrent Usage
/// - [ ] Safe passing across concurrent contexts
/// - [ ] Thread-safe comparison operations
/// - [ ] Concurrent read access from multiple threads
/// - [ ] Sendable compliance verification
///
/// ### Integration with Lockman Components
/// - [ ] Usage as actionId in LockmanInfo implementations
/// - [ ] Integration with strategy canLock/lock/unlock operations
/// - [ ] Action identification in error messages
/// - [ ] Debug string representation
///
/// ### Edge Cases and Validation
/// - [ ] Very long string action IDs
/// - [ ] Action IDs with newlines and control characters
/// - [ ] Non-ASCII character support
/// - [ ] Memory efficiency with repeated action IDs
/// - [ ] Hashable behavior for dictionary usage
///
final class LockmanActionIdTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Basic Type Properties Tests

  func testLockmanActionIdIsStringTypealias() {
    // Verify that LockmanActionId is actually String
    let actionId: LockmanActionId = "testAction"
    let string: String = actionId

    XCTAssertEqual(actionId, string)
    // Verify type compatibility
    let _: String = actionId  // Should compile without issues
  }

  func testEquatableConformanceThroughString() {
    let actionId1: LockmanActionId = "sameAction"
    let actionId2: LockmanActionId = "sameAction"
    let actionId3: LockmanActionId = "differentAction"

    XCTAssertEqual(actionId1, actionId2)
    XCTAssertNotEqual(actionId1, actionId3)
    XCTAssertTrue(actionId1 == actionId2)
    XCTAssertTrue(actionId1 != actionId3)
  }

  func testSendableConformanceThroughString() {
    // Verify that LockmanActionId can be used in concurrent contexts
    let actionId: LockmanActionId = "concurrentAction"

    let expectation = XCTestExpectation(description: "Concurrent access to action ID")
    expectation.expectedFulfillmentCount = 2

    DispatchQueue.global().async {
      let localActionId = actionId
      XCTAssertEqual(localActionId, "concurrentAction")
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      let localActionId = actionId
      XCTAssertEqual(localActionId, "concurrentAction")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testTypeSafetyAndInterchangeabilityWithString() {
    let stringValue = "testAction"
    let actionId: LockmanActionId = stringValue
    let backToString: String = actionId

    XCTAssertEqual(stringValue, actionId)
    XCTAssertEqual(actionId, backToString)
    XCTAssertEqual(stringValue, backToString)
  }

  // MARK: - String Operations and Behavior Tests

  func testStringLiteralAssignmentToLockmanActionId() {
    let actionId: LockmanActionId = "literal"
    XCTAssertEqual(actionId, "literal")

    let interpolatedActionId: LockmanActionId = "action_\(123)"
    XCTAssertEqual(interpolatedActionId, "action_123")
  }

  func testStringConcatenationAndManipulation() {
    let prefix: LockmanActionId = "user"
    let suffix: LockmanActionId = "login"
    let combined: LockmanActionId = prefix + "_" + suffix

    XCTAssertEqual(combined, "user_login")

    let uppercased: LockmanActionId = LockmanActionId("action").uppercased()
    XCTAssertEqual(uppercased, "ACTION")

    let trimmed: LockmanActionId = LockmanActionId("  spacedAction  ").trimmingCharacters(
      in: .whitespaces)
    XCTAssertEqual(trimmed, "spacedAction")
  }

  func testEmptyStringAsValidLockmanActionId() {
    let emptyActionId: LockmanActionId = ""
    XCTAssertEqual(emptyActionId, "")
    XCTAssertTrue(emptyActionId.isEmpty)
    XCTAssertEqual(emptyActionId.count, 0)
  }

  func testUnicodeAndSpecialCharacterSupport() {
    let unicodeActionId: LockmanActionId = "テスト_アクション_🚀"
    XCTAssertEqual(unicodeActionId, "テスト_アクション_🚀")

    let specialCharsActionId: LockmanActionId = "action@#$%^&*(){}[]"
    XCTAssertEqual(specialCharsActionId, "action@#$%^&*(){}[]")

    let emojiActionId: LockmanActionId = "🎯💻🔐"
    XCTAssertEqual(emojiActionId, "🎯💻🔐")
  }

  func testStringComparisonOperations() {
    let actionA: LockmanActionId = "actionA"
    let actionB: LockmanActionId = "actionB"
    let actionA2: LockmanActionId = "actionA"

    // Equality
    XCTAssertTrue(actionA == actionA2)
    XCTAssertFalse(actionA == actionB)

    // Inequality
    XCTAssertFalse(actionA != actionA2)
    XCTAssertTrue(actionA != actionB)

    // Lexicographic comparison
    XCTAssertTrue(actionA < actionB)
    XCTAssertFalse(actionB < actionA)
    XCTAssertTrue(actionB > actionA)
    XCTAssertFalse(actionA > actionB)
  }

  func testCaseSensitivityInComparisons() {
    let lowerActionId: LockmanActionId = "action"
    let upperActionId: LockmanActionId = "ACTION"
    let mixedActionId: LockmanActionId = "Action"

    XCTAssertNotEqual(lowerActionId, upperActionId)
    XCTAssertNotEqual(lowerActionId, mixedActionId)
    XCTAssertNotEqual(upperActionId, mixedActionId)

    // Case-insensitive comparison
    XCTAssertEqual(lowerActionId.lowercased(), upperActionId.lowercased())
  }

  // MARK: - Concurrent Usage Tests

  func testSafePassingAcrossConcurrentContexts() async {
    let actionId: LockmanActionId = "concurrentTestAction"

    let results = try! await TestSupport.executeConcurrently(iterations: 10) {
      return actionId
    }

    // Verify all results are the same
    XCTAssertEqual(results.count, 10)
    results.forEach { result in
      XCTAssertEqual(result, actionId)
    }
  }

  func testThreadSafeComparisonOperations() async {
    let actionId1: LockmanActionId = "action1"
    let actionId2: LockmanActionId = "action2"

    await TestSupport.performConcurrentOperations(count: 20) {
      XCTAssertEqual(actionId1, "action1")
      XCTAssertNotEqual(actionId1, actionId2)
      XCTAssertTrue(actionId1 < actionId2)
    }
  }

  func testConcurrentReadAccessFromMultipleThreads() {
    let actionId: LockmanActionId = "sharedAction"
    let expectation = XCTestExpectation(description: "Concurrent read access")
    expectation.expectedFulfillmentCount = 5

    for _ in 0..<5 {
      DispatchQueue.global().async {
        let localCopy = actionId
        XCTAssertEqual(localCopy, "sharedAction")
        XCTAssertEqual(localCopy.count, 12)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 2.0)
  }

  // MARK: - Integration with Lockman Components Tests

  func testUsageAsActionIdInLockmanInfoImplementations() {
    let actionId: LockmanActionId = "integrationTestAction"

    // Test with LockmanSingleExecutionInfo
    let singleExecutionInfo = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .action
    )
    XCTAssertEqual(singleExecutionInfo.actionId, actionId)

    // Test with LockmanPriorityBasedInfo
    let priorityInfo = LockmanPriorityBasedInfo(
      actionId: actionId,
      priority: .high(.exclusive)
    )
    XCTAssertEqual(priorityInfo.actionId, actionId)
  }

  func testActionIdentificationInErrorMessages() {
    let actionId: LockmanActionId = "errorTestAction"
    let singleExecutionInfo = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .action
    )

    let error = LockmanSingleExecutionError.actionAlreadyRunning(
      boundaryId: "testBoundary",
      lockmanInfo: singleExecutionInfo
    )

    let errorDescription = error.localizedDescription
    XCTAssertTrue(errorDescription.contains(actionId))
  }

  func testDebugStringRepresentation() {
    let actionId: LockmanActionId = "debugTestAction"
    let singleExecutionInfo = LockmanSingleExecutionInfo(
      actionId: actionId,
      mode: .action
    )

    let debugDescription = singleExecutionInfo.debugDescription
    XCTAssertTrue(debugDescription.contains(actionId))
  }

  // MARK: - Edge Cases and Validation Tests

  func testVeryLongStringActionIds() {
    let longActionId: LockmanActionId = String(repeating: "veryLongAction", count: 1000)

    XCTAssertEqual(longActionId.count, 14000)  // "veryLongAction" = 14 chars
    XCTAssertTrue(longActionId.hasPrefix("veryLongAction"))
    XCTAssertTrue(longActionId.hasSuffix("veryLongAction"))

    // Verify it can still be used normally
    let anotherLongActionId = longActionId
    XCTAssertEqual(longActionId, anotherLongActionId)
  }

  func testActionIdsWithNewlinesAndControlCharacters() {
    let actionIdWithNewlines: LockmanActionId = "action\nwith\nnewlines"
    XCTAssertEqual(actionIdWithNewlines, "action\nwith\nnewlines")
    XCTAssertTrue(actionIdWithNewlines.contains("\n"))

    let actionIdWithTabs: LockmanActionId = "action\twith\ttabs"
    XCTAssertEqual(actionIdWithTabs, "action\twith\ttabs")
    XCTAssertTrue(actionIdWithTabs.contains("\t"))

    let actionIdWithNullChar: LockmanActionId = "action\0with\0null"
    XCTAssertEqual(actionIdWithNullChar, "action\0with\0null")
  }

  func testNonAsciiCharacterSupport() {
    let cyrillicActionId: LockmanActionId = "действие"
    XCTAssertEqual(cyrillicActionId, "действие")

    let arabicActionId: LockmanActionId = "عمل"
    XCTAssertEqual(arabicActionId, "عمل")

    let chineseActionId: LockmanActionId = "行动"
    XCTAssertEqual(chineseActionId, "行动")

    // Mix of different scripts
    let mixedActionId: LockmanActionId = "action_действие_عمل_行动_🌍"
    XCTAssertEqual(mixedActionId, "action_действие_عمل_行动_🌍")
  }

  func testMemoryEfficiencyWithRepeatedActionIds() {
    let baseActionId: LockmanActionId = "repeatedAction"
    var actionIds: [LockmanActionId] = []

    // Create many references to the same string
    for _ in 0..<1000 {
      actionIds.append(baseActionId)
    }

    // Verify all are equal
    actionIds.forEach { actionId in
      XCTAssertEqual(actionId, baseActionId)
    }

    // Test with string literal optimization
    let literalIds = (0..<1000).map { _ in "literalAction" as LockmanActionId }
    literalIds.forEach { actionId in
      XCTAssertEqual(actionId, "literalAction")
    }
  }

  func testHashableBehaviorForDictionaryUsage() {
    let actionId1: LockmanActionId = "hashAction1"
    let actionId2: LockmanActionId = "hashAction2"
    let actionId1Copy: LockmanActionId = "hashAction1"

    var dictionary: [LockmanActionId: String] = [:]
    dictionary[actionId1] = "value1"
    dictionary[actionId2] = "value2"

    XCTAssertEqual(dictionary[actionId1], "value1")
    XCTAssertEqual(dictionary[actionId2], "value2")
    XCTAssertEqual(dictionary[actionId1Copy], "value1")  // Same hash as actionId1

    // Test in Set
    let actionIdSet: Set<LockmanActionId> = [actionId1, actionId2, actionId1Copy]
    XCTAssertEqual(actionIdSet.count, 2)  // actionId1 and actionId1Copy are the same
    XCTAssertTrue(actionIdSet.contains(actionId1))
    XCTAssertTrue(actionIdSet.contains(actionId2))
    XCTAssertTrue(actionIdSet.contains(actionId1Copy))
  }
}
