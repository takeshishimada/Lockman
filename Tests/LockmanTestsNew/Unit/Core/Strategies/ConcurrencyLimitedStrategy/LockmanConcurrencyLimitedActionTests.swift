import XCTest

@testable import Lockman

/// Unit tests for LockmanConcurrencyLimitedAction
///
/// Tests the protocol for concurrency-limited locking semantics with actions.
final class LockmanConcurrencyLimitedActionTests: XCTestCase {

  override func setUp() {
    super.setUp()
    // Setup test environment
  }

  override func tearDown() {
    super.tearDown()
    // Cleanup after each test
    LockmanManager.cleanup.all()
  }

  // MARK: - Test Action Types

  /// Simple enum implementing LockmanConcurrencyLimitedAction for testing
  enum TestAction: LockmanConcurrencyLimitedAction {
    case simpleAction
    case actionWithParameter(String)
    case numericAction(Int)

    var actionName: String {
      switch self {
      case .simpleAction:
        return "simpleAction"
      case .actionWithParameter(let param):
        return "actionWithParameter_\(param)"
      case .numericAction(let num):
        return "numericAction_\(num)"
      }
    }

    func createLockmanInfo() -> LockmanConcurrencyLimitedInfo {
      LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId(actionName),
        .limited(3)
      )
    }
    
    var unlockOption: LockmanUnlockOption { .immediate }
  }

  /// Struct implementing LockmanConcurrencyLimitedAction for testing
  struct StructAction: LockmanConcurrencyLimitedAction {
    let id: String
    let category: String

    var actionName: String {
      "\(category)_\(id)"
    }

    func createLockmanInfo() -> LockmanConcurrencyLimitedInfo {
      LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId(actionName),
        .limited(5)
      )
    }
    
    var unlockOption: LockmanUnlockOption { .immediate }
  }

  /// Class implementing LockmanConcurrencyLimitedAction for testing
  final class ClassAction: LockmanConcurrencyLimitedAction {
    let operation: String
    let priority: Int

    init(operation: String, priority: Int) {
      self.operation = operation
      self.priority = priority
    }

    var actionName: String {
      "\(operation)_priority_\(priority)"
    }

    func createLockmanInfo() -> LockmanConcurrencyLimitedInfo {
      LockmanConcurrencyLimitedInfo(
        actionId: LockmanActionId(actionName),
        .limited(10)
      )
    }
    
    var unlockOption: LockmanUnlockOption { .immediate }
  }

  // MARK: - Protocol Conformance Tests

  func testProtocolConformance() {
    // Given
    let testAction = TestAction.simpleAction

    // Then - Verify protocol conformance
    XCTAssertTrue(testAction is LockmanConcurrencyLimitedAction)
    XCTAssertTrue(testAction is LockmanAction)
    XCTAssertTrue(testAction.createLockmanInfo() is LockmanConcurrencyLimitedInfo)
  }

  func testAssociatedTypeConstraint() {
    // Given
    let testAction = TestAction.simpleAction

    // When
    let info = testAction.createLockmanInfo()

    // Then - Verify associated type I == LockmanConcurrencyLimitedInfo
    XCTAssertTrue(type(of: info) == LockmanConcurrencyLimitedInfo.self)
  }

  // MARK: - ActionName Property Tests

  func testActionNameImplementation() {
    // Given & When & Then
    let simpleAction = TestAction.simpleAction
    XCTAssertEqual(simpleAction.actionName, "simpleAction")

    let paramAction = TestAction.actionWithParameter("test")
    XCTAssertEqual(paramAction.actionName, "actionWithParameter_test")

    let numericAction = TestAction.numericAction(42)
    XCTAssertEqual(numericAction.actionName, "numericAction_42")
  }

  func testActionNameUniqueness() {
    // Given
    let action1 = TestAction.actionWithParameter("param1")
    let action2 = TestAction.actionWithParameter("param2")
    let action3 = TestAction.numericAction(1)
    let action4 = TestAction.numericAction(2)

    // When & Then
    XCTAssertNotEqual(action1.actionName, action2.actionName)
    XCTAssertNotEqual(action3.actionName, action4.actionName)
    XCTAssertNotEqual(action1.actionName, action3.actionName)
  }

  func testActionNameParameterSpecific() {
    // Given
    let user1Action = TestAction.actionWithParameter("user1")
    let user2Action = TestAction.actionWithParameter("user2")

    // When & Then
    XCTAssertEqual(user1Action.actionName, "actionWithParameter_user1")
    XCTAssertEqual(user2Action.actionName, "actionWithParameter_user2")
    XCTAssertNotEqual(user1Action.actionName, user2Action.actionName)
  }

  func testActionNameWithSpecialCharacters() {
    // Given
    let specialAction = TestAction.actionWithParameter("special!@#$%^&*()_+åäö🚀")

    // When
    let actionName = specialAction.actionName

    // Then
    XCTAssertEqual(actionName, "actionWithParameter_special!@#$%^&*()_+åäö🚀")
    XCTAssertTrue(actionName.contains("🚀"))
  }

  func testActionNameWithEmptyString() {
    // Given
    let emptyAction = TestAction.actionWithParameter("")

    // When
    let actionName = emptyAction.actionName

    // Then
    XCTAssertEqual(actionName, "actionWithParameter_")
  }

  func testActionNameWithVeryLongString() {
    // Given
    let longParam = String(repeating: "a", count: 1000)
    let longAction = TestAction.actionWithParameter(longParam)

    // When
    let actionName = longAction.actionName

    // Then
    XCTAssertEqual(actionName, "actionWithParameter_\(longParam)")
    XCTAssertTrue(actionName.count > 1000)
  }

  // MARK: - Implementation Pattern Tests

  func testEnumBasedImplementation() {
    // Given
    let action = TestAction.simpleAction

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "simpleAction")
    XCTAssertEqual(info.actionId, LockmanActionId("simpleAction"))
    XCTAssertEqual(info.limit, .limited(3))
  }

  func testStructBasedImplementation() {
    // Given
    let action = StructAction(id: "123", category: "user")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "user_123")
    XCTAssertEqual(info.actionId, LockmanActionId("user_123"))
    XCTAssertEqual(info.limit, .limited(5))
  }

  func testClassBasedImplementation() {
    // Given
    let action = ClassAction(operation: "download", priority: 1)

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "download_priority_1")
    XCTAssertEqual(info.actionId, LockmanActionId("download_priority_1"))
    XCTAssertEqual(info.limit, .limited(10))
  }

  // MARK: - LockmanInfo Integration Tests

  func testLockmanInfoActionIdMapping() {
    // Given
    let action = TestAction.actionWithParameter("testParam")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then - ActionName should map to actionId
    XCTAssertEqual(LockmanActionId(actionName), info.actionId)
  }

  func testLockmanInfoStrategyId() {
    // Given
    let action = TestAction.simpleAction

    // When
    let info = action.createLockmanInfo()

    // Then
    XCTAssertNotNil(info.strategyId)
    XCTAssertFalse(info.strategyId.value.isEmpty)
  }

  func testLockmanInfoUniqueId() {
    // Given
    let action1 = TestAction.simpleAction
    let action2 = TestAction.simpleAction

    // When
    let info1 = action1.createLockmanInfo()
    let info2 = action2.createLockmanInfo()

    // Then - Each call should generate unique instance
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
  }

  // MARK: - Conflict Detection Tests

  func testSameActionNameConflictDetection() {
    // Given
    let action1 = TestAction.simpleAction
    let action2 = TestAction.simpleAction

    // When
    let actionName1 = action1.actionName
    let actionName2 = action2.actionName

    // Then - Same action names should be identical (for conflict detection)
    XCTAssertEqual(actionName1, actionName2)
  }

  func testDifferentActionNameNoConflict() {
    // Given
    let action1 = TestAction.simpleAction
    let action2 = TestAction.actionWithParameter("test")

    // When
    let actionName1 = action1.actionName
    let actionName2 = action2.actionName

    // Then - Different action names should not conflict
    XCTAssertNotEqual(actionName1, actionName2)
  }

  func testParameterizedActionConflicts() {
    // Given
    let sameParamAction1 = TestAction.actionWithParameter("user123")
    let sameParamAction2 = TestAction.actionWithParameter("user123")
    let differentParamAction = TestAction.actionWithParameter("user456")

    // When
    let sameName1 = sameParamAction1.actionName
    let sameName2 = sameParamAction2.actionName
    let differentName = differentParamAction.actionName

    // Then
    XCTAssertEqual(sameName1, sameName2)  // Should conflict
    XCTAssertNotEqual(sameName1, differentName)  // Should not conflict
  }

  // MARK: - Real-World Usage Pattern Tests

  func testUserSpecificActions() {
    // Given - User-specific actions that should run independently
    let user1Action = TestAction.actionWithParameter("user_1")
    let user2Action = TestAction.actionWithParameter("user_2")

    // When
    let user1Name = user1Action.actionName
    let user2Name = user2Action.actionName

    // Then - Different users should not conflict
    XCTAssertNotEqual(user1Name, user2Name)
    XCTAssertEqual(user1Name, "actionWithParameter_user_1")
    XCTAssertEqual(user2Name, "actionWithParameter_user_2")
  }

  func testResourceSpecificActions() {
    // Given - Resource-specific actions
    let download1 = StructAction(id: "file1.pdf", category: "download")
    let download2 = StructAction(id: "file2.pdf", category: "download")
    let upload1 = StructAction(id: "file1.pdf", category: "upload")

    // When
    let download1Name = download1.actionName
    let download2Name = download2.actionName
    let upload1Name = upload1.actionName

    // Then
    XCTAssertNotEqual(download1Name, download2Name)  // Different files
    XCTAssertNotEqual(download1Name, upload1Name)  // Different operations
    XCTAssertEqual(download1Name, "download_file1.pdf")
    XCTAssertEqual(upload1Name, "upload_file1.pdf")
  }

  func testPriorityBasedActions() {
    // Given
    let highPriorityAction = ClassAction(operation: "sync", priority: 1)
    let lowPriorityAction = ClassAction(operation: "sync", priority: 10)

    // When
    let highPriorityName = highPriorityAction.actionName
    let lowPriorityName = lowPriorityAction.actionName

    // Then - Different priorities should create different action names
    XCTAssertNotEqual(highPriorityName, lowPriorityName)
    XCTAssertEqual(highPriorityName, "sync_priority_1")
    XCTAssertEqual(lowPriorityName, "sync_priority_10")
  }

  // MARK: - Performance Tests

  func testActionNamePerformance() {
    // Given
    let action = TestAction.actionWithParameter("performance_test")

    // When & Then
    measure {
      for _ in 0..<10000 {
        _ = action.actionName
      }
    }
  }

  func testLockmanInfoPerformance() {
    // Given
    let action = TestAction.actionWithParameter("performance_test")

    // When & Then
    measure {
      for _ in 0..<1000 {
        _ = action.createLockmanInfo()
      }
    }
  }

  // MARK: - Edge Cases Tests

  func testActionNameConsistency() {
    // Given
    let action = TestAction.actionWithParameter("consistency_test")

    // When - Call actionName multiple times
    let name1 = action.actionName
    let name2 = action.actionName
    let name3 = action.actionName

    // Then - Should always return the same value
    XCTAssertEqual(name1, name2)
    XCTAssertEqual(name2, name3)
  }

  func testActionNameWithNumerics() {
    // Given
    let numericActions = [
      TestAction.numericAction(0),
      TestAction.numericAction(1),
      TestAction.numericAction(-1),
      TestAction.numericAction(Int.max),
      TestAction.numericAction(Int.min),
    ]

    // When & Then
    for action in numericActions {
      let actionName = action.actionName
      XCTAssertTrue(actionName.hasPrefix("numericAction_"))
      XCTAssertFalse(actionName.isEmpty)
    }
  }

  // MARK: - Thread Safety Tests

  func testConcurrentActionNameAccess() async {
    // Given
    let action = TestAction.actionWithParameter("concurrent_test")
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10
    
    actor ActionNameCollector {
      private var actionNames: [String] = []
      func addName(_ name: String) { actionNames.append(name) }
      func getNames() -> [String] { actionNames }
    }
    
    let collector = ActionNameCollector()

    // When - Access actionName concurrently
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      let name = action.actionName

      Task {
        await collector.addName(name)
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - All names should be identical
    let actionNames = await collector.getNames()
    let uniqueNames = Set(actionNames)
    XCTAssertEqual(uniqueNames.count, 1)
    XCTAssertEqual(actionNames.count, 10)
  }

  func testConcurrentLockmanInfoCreation() {
    // Given
    let action = TestAction.actionWithParameter("concurrent_info_test")
    let expectation = XCTestExpectation(description: "Concurrent info creation")
    expectation.expectedFulfillmentCount = 10
    var infos: [LockmanConcurrencyLimitedInfo] = []
    let lock = NSLock()

    // When - Create lockmanInfo concurrently
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      let info = action.createLockmanInfo()

      lock.lock()
      infos.append(info)
      lock.unlock()

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - All infos should have same actionId but unique uniqueIds
    let actionIds = Set(infos.map { $0.actionId })
    let uniqueIds = Set(infos.map { $0.uniqueId })

    XCTAssertEqual(actionIds.count, 1)  // Same actionId
    XCTAssertEqual(uniqueIds.count, 10)  // Unique uniqueIds
  }
}
