import XCTest

@testable import Lockman

/// Unit tests for LockmanSingleExecutionAction
///
/// Tests the protocol for single-execution locking semantics with actions.
///
/// ## Test Cases Identified from Source Analysis:
///
/// ### Protocol Conformance & Inheritance
/// - [ ] LockmanAction protocol inheritance validation
/// - [ ] Associated type I == LockmanSingleExecutionInfo constraint
/// - [ ] Protocol requirement fulfillment verification
/// - [ ] Protocol default implementation behavior
/// - [ ] Multiple protocol conformance compatibility
///
/// ### ActionName Property Behavior
/// - [ ] actionName property implementation requirement
/// - [ ] actionName uniqueness for conflict detection
/// - [ ] Parameter-specific actionName generation
/// - [ ] Static actionName vs dynamic actionName patterns
/// - [ ] ActionName string validation and constraints
/// - [ ] Empty actionName handling
/// - [ ] Special characters in actionName
///
/// ### Macro Integration Testing
/// - [ ] @LockmanSingleExecution macro generated conformance
/// - [ ] Automatic actionName implementation from enum cases
/// - [ ] Macro-generated vs manual implementation compatibility
/// - [ ] Macro error handling and validation
/// - [ ] Generated code quality and correctness
///
/// ### Manual Implementation Patterns
/// - [ ] Enum-based manual implementation
/// - [ ] Struct-based manual implementation
/// - [ ] Class-based manual implementation
/// - [ ] Associated values in actionName generation
/// - [ ] Parameter separation strategies
/// - [ ] Complex actionName computation logic
///
/// ### Lock Conflict Detection
/// - [ ] Same actionName conflict prevention
/// - [ ] Different actionName parallel execution
/// - [ ] ActionId mapping from actionName
/// - [ ] Boundary-scoped conflict detection
/// - [ ] Cross-boundary isolation verification
/// - [ ] Conflict resolution timing
///
/// ### Execution Mode Integration
/// - [ ] .none mode behavior with actionName
/// - [ ] .boundary mode global conflict detection
/// - [ ] .action mode actionName-specific conflicts
/// - [ ] Mode-specific lockmanInfo implementation
/// - [ ] Execution mode transition behavior
///
/// ### Type Safety & Generics
/// - [ ] Associated type constraint enforcement
/// - [ ] Generic type parameter validation
/// - [ ] Type erasure compatibility
/// - [ ] Compile-time type checking
/// - [ ] Runtime type validation
///
/// ### Performance & Scalability
/// - [ ] ActionName computation performance
/// - [ ] Lock lookup performance by actionName
/// - [ ] Memory usage with many action types
/// - [ ] Concurrent action creation performance
/// - [ ] String interning and optimization
///
/// ### Integration with Strategy System
/// - [ ] Strategy container registration
/// - [ ] Action-strategy coordination
/// - [ ] Boundary lock integration
/// - [ ] Cleanup and lifecycle management
/// - [ ] Error propagation through strategy layers
///
/// ### Real-world Usage Patterns
/// - [ ] User authentication action conflicts
/// - [ ] Data synchronization patterns
/// - [ ] API request deduplication
/// - [ ] File operation exclusive access
/// - [ ] Database transaction coordination
/// - [ ] Cache invalidation patterns
///
/// ### Edge Cases & Error Conditions
/// - [ ] Nil actionName handling
/// - [ ] Very long actionName strings
/// - [ ] ActionName with Unicode characters
/// - [ ] Recursive action execution prevention
/// - [ ] Memory pressure with many actions
/// - [ ] Threading edge cases with actionName access
///
/// ### Documentation Examples Validation
/// - [ ] Pattern 1: Simple enum with macro
/// - [ ] Pattern 2: Manual implementation with parameters
/// - [ ] User action enum example
/// - [ ] Data action enum with parameters
/// - [ ] Code example correctness verification
///
final class LockmanSingleExecutionActionTests: XCTestCase {

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

  /// Simple enum implementing LockmanSingleExecutionAction for testing
  enum TestUserAction: LockmanSingleExecutionAction {
    case login
    case logout
    case refreshProfile
    case updateSettings

    var actionName: String {
      switch self {
      case .login: return "login"
      case .logout: return "logout"
      case .refreshProfile: return "refreshProfile"
      case .updateSettings: return "updateSettings"
      }
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(
        actionId: LockmanActionId(actionName),
        mode: .action
      )
    }
  }

  /// Enum with parameters implementing LockmanSingleExecutionAction
  enum TestDataAction: LockmanSingleExecutionAction {
    case fetchUser(id: String)
    case saveDocument(id: String)
    case deleteFile(path: String)
    case syncData

    var actionName: String {
      switch self {
      case .fetchUser(let id): return "fetchUser_\(id)"
      case .saveDocument(let id): return "saveDocument_\(id)"
      case .deleteFile(let path):
        return "deleteFile_\(path.replacingOccurrences(of: "/", with: "_"))"
      case .syncData: return "syncData"
      }
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(
        actionId: LockmanActionId(actionName),
        mode: .action
      )
    }
  }

  /// Struct implementing LockmanSingleExecutionAction with boundary mode
  struct BoundaryAction: LockmanSingleExecutionAction {
    let operation: String

    var actionName: String {
      operation
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(
        actionId: LockmanActionId(actionName),
        mode: .boundary
      )
    }
  }

  /// Class implementing LockmanSingleExecutionAction with none mode
  final class NoneAction: LockmanSingleExecutionAction, @unchecked Sendable {
    let task: String

    init(task: String) {
      self.task = task
    }

    var actionName: String {
      task
    }

    func createLockmanInfo() -> LockmanSingleExecutionInfo {
      LockmanSingleExecutionInfo(
        actionId: LockmanActionId(actionName),
        mode: .none
      )
    }
  }

  // MARK: - Protocol Conformance Tests

  func testProtocolConformance() {
    // Given
    let testAction = TestUserAction.login

    // Then - Verify protocol conformance
    XCTAssertTrue(testAction is LockmanSingleExecutionAction)
    XCTAssertTrue(testAction is LockmanAction)
    XCTAssertTrue(testAction.createLockmanInfo() is LockmanSingleExecutionInfo)
  }

  func testAssociatedTypeConstraint() {
    // Given
    let testAction = TestUserAction.login

    // When
    let info = testAction.createLockmanInfo()

    // Then - Verify associated type I == LockmanSingleExecutionInfo
    XCTAssertTrue(type(of: info) == LockmanSingleExecutionInfo.self)
  }

  func testLockmanActionInheritance() {
    // Given
    let testAction = TestUserAction.login

    // Then - Verify LockmanAction protocol inheritance
    XCTAssertTrue(testAction is LockmanAction)
    XCTAssertNotNil(testAction.createLockmanInfo())
  }

  // MARK: - ActionName Property Tests

  func testActionNameImplementation() {
    // Given & When & Then
    XCTAssertEqual(TestUserAction.login.actionName, "login")
    XCTAssertEqual(TestUserAction.logout.actionName, "logout")
    XCTAssertEqual(TestUserAction.refreshProfile.actionName, "refreshProfile")
    XCTAssertEqual(TestUserAction.updateSettings.actionName, "updateSettings")
  }

  func testActionNameUniqueness() {
    // Given
    let actions = [
      TestUserAction.login,
      TestUserAction.logout,
      TestUserAction.refreshProfile,
      TestUserAction.updateSettings,
    ]

    // When
    let actionNames = actions.map { $0.actionName }

    // Then - All action names should be unique
    let uniqueNames = Set(actionNames)
    XCTAssertEqual(actionNames.count, uniqueNames.count)
  }

  func testParameterSpecificActionNames() {
    // Given
    let user1Action = TestDataAction.fetchUser(id: "user1")
    let user2Action = TestDataAction.fetchUser(id: "user2")
    let doc1Action = TestDataAction.saveDocument(id: "doc1")

    // When & Then
    XCTAssertEqual(user1Action.actionName, "fetchUser_user1")
    XCTAssertEqual(user2Action.actionName, "fetchUser_user2")
    XCTAssertEqual(doc1Action.actionName, "saveDocument_doc1")
    XCTAssertNotEqual(user1Action.actionName, user2Action.actionName)
  }

  func testActionNameWithComplexParameters() {
    // Given
    let complexPath = "/path/to/complex/file_with_underscores.txt"
    let deleteAction = TestDataAction.deleteFile(path: complexPath)

    // When
    let actionName = deleteAction.actionName

    // Then
    XCTAssertEqual(actionName, "deleteFile__path_to_complex_file_with_underscores.txt")
    XCTAssertFalse(actionName.contains("/"))
  }

  func testActionNameWithSpecialCharacters() {
    // Given
    let specialId = "user!@#$%^&*()_+åäö🚀"
    let userAction = TestDataAction.fetchUser(id: specialId)

    // When
    let actionName = userAction.actionName

    // Then
    XCTAssertEqual(actionName, "fetchUser_user!@#$%^&*()_+åäö🚀")
    XCTAssertTrue(actionName.contains("🚀"))
  }

  func testActionNameWithEmptyParameter() {
    // Given
    let emptyAction = TestDataAction.fetchUser(id: "")

    // When
    let actionName = emptyAction.actionName

    // Then
    XCTAssertEqual(actionName, "fetchUser_")
  }

  func testActionNameWithVeryLongParameter() {
    // Given
    let longId = String(repeating: "a", count: 1000)
    let longAction = TestDataAction.fetchUser(id: longId)

    // When
    let actionName = longAction.actionName

    // Then
    XCTAssertEqual(actionName, "fetchUser_\(longId)")
    XCTAssertTrue(actionName.count > 1000)
  }

  // MARK: - LockmanInfo Integration Tests

  func testActionModeIntegration() {
    // Given
    let actionModeAction = TestUserAction.login
    let boundaryModeAction = BoundaryAction(operation: "test")
    let noneModeAction = NoneAction(task: "background")

    // When
    let actionInfo = actionModeAction.createLockmanInfo()
    let boundaryInfo = boundaryModeAction.createLockmanInfo()
    let noneInfo = noneModeAction.createLockmanInfo()

    // Then
    XCTAssertEqual(actionInfo.mode, .action)
    XCTAssertEqual(boundaryInfo.mode, .boundary)
    XCTAssertEqual(noneInfo.mode, .none)
  }

  func testActionIdMapping() {
    // Given
    let action = TestDataAction.fetchUser(id: "123")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then - ActionName should map to actionId
    XCTAssertEqual(LockmanActionId(actionName), info.actionId)
    XCTAssertEqual(info.actionId, "fetchUser_123")
  }

  func testStrategyIdConsistency() {
    // Given
    let action1 = TestUserAction.login
    let action2 = TestDataAction.syncData

    // When
    let info1 = action1.createLockmanInfo()
    let info2 = action2.createLockmanInfo()

    // Then - Both should use single execution strategy
    XCTAssertEqual(info1.strategyId, LockmanStrategyId.singleExecution)
    XCTAssertEqual(info2.strategyId, LockmanStrategyId.singleExecution)
  }

  func testUniqueIdGeneration() {
    // Given
    let action = TestUserAction.login

    // When
    let info1 = action.createLockmanInfo()
    let info2 = action.createLockmanInfo()

    // Then - Each call should generate unique instance
    XCTAssertNotEqual(info1.uniqueId, info2.uniqueId)
    XCTAssertEqual(info1.actionId, info2.actionId)  // But same actionId
  }

  // MARK: - Execution Mode Behavior Tests

  func testActionModeConflictDetection() {
    // Given
    let action1 = TestUserAction.login
    let action2 = TestUserAction.login
    let differentAction = TestUserAction.logout

    // When
    let name1 = action1.actionName
    let name2 = action2.actionName
    let differentName = differentAction.actionName

    // Then - Same actions should have same name (conflict), different should not
    XCTAssertEqual(name1, name2)  // Should conflict in .action mode
    XCTAssertNotEqual(name1, differentName)  // Should not conflict
  }

  func testBoundaryModeExecution() {
    // Given
    let boundaryAction1 = BoundaryAction(operation: "operation1")
    let boundaryAction2 = BoundaryAction(operation: "operation2")

    // When
    let info1 = boundaryAction1.createLockmanInfo()
    let info2 = boundaryAction2.createLockmanInfo()

    // Then - Both should be in boundary mode
    XCTAssertEqual(info1.mode, .boundary)
    XCTAssertEqual(info2.mode, .boundary)
    // In boundary mode, even different operations should conflict within same boundary
  }

  func testNoneModeExecution() {
    // Given
    let noneAction1 = NoneAction(task: "task1")
    let noneAction2 = NoneAction(task: "task2")

    // When
    let info1 = noneAction1.createLockmanInfo()
    let info2 = noneAction2.createLockmanInfo()

    // Then - Both should be in none mode (no conflicts)
    XCTAssertEqual(info1.mode, .none)
    XCTAssertEqual(info2.mode, .none)
  }

  // MARK: - Implementation Pattern Tests

  func testEnumBasedImplementation() {
    // Given
    let action = TestUserAction.login

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "login")
    XCTAssertEqual(info.actionId, LockmanActionId("login"))
    XCTAssertEqual(info.mode, .action)
  }

  func testEnumWithParametersImplementation() {
    // Given
    let action = TestDataAction.fetchUser(id: "user123")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "fetchUser_user123")
    XCTAssertEqual(info.actionId, LockmanActionId("fetchUser_user123"))
    XCTAssertEqual(info.mode, .action)
  }

  func testStructBasedImplementation() {
    // Given
    let action = BoundaryAction(operation: "criticalOperation")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "criticalOperation")
    XCTAssertEqual(info.actionId, LockmanActionId("criticalOperation"))
    XCTAssertEqual(info.mode, .boundary)
  }

  func testClassBasedImplementation() {
    // Given
    let action = NoneAction(task: "backgroundTask")

    // When
    let actionName = action.actionName
    let info = action.createLockmanInfo()

    // Then
    XCTAssertEqual(actionName, "backgroundTask")
    XCTAssertEqual(info.actionId, LockmanActionId("backgroundTask"))
    XCTAssertEqual(info.mode, .none)
  }

  // MARK: - Real-World Usage Pattern Tests

  func testUserAuthenticationFlow() {
    // Given - User authentication actions
    let loginAction = TestUserAction.login
    let logoutAction = TestUserAction.logout

    // When
    let loginName = loginAction.actionName
    let logoutName = logoutAction.actionName

    // Then - Different auth actions should not conflict
    XCTAssertNotEqual(loginName, logoutName)
    XCTAssertEqual(loginName, "login")
    XCTAssertEqual(logoutName, "logout")
  }

  func testDataSynchronizationPattern() {
    // Given - Data sync actions
    let syncAction = TestDataAction.syncData
    let user1Fetch = TestDataAction.fetchUser(id: "user1")
    let user2Fetch = TestDataAction.fetchUser(id: "user2")

    // When
    let syncName = syncAction.actionName
    let user1Name = user1Fetch.actionName
    let user2Name = user2Fetch.actionName

    // Then
    XCTAssertEqual(syncName, "syncData")
    XCTAssertEqual(user1Name, "fetchUser_user1")
    XCTAssertEqual(user2Name, "fetchUser_user2")
    XCTAssertNotEqual(user1Name, user2Name)  // Different users should not conflict
  }

  func testFileOperationPattern() {
    // Given - File operations
    let save1 = TestDataAction.saveDocument(id: "doc1")
    let save2 = TestDataAction.saveDocument(id: "doc2")
    let delete1 = TestDataAction.deleteFile(path: "/tmp/file1.txt")

    // When
    let save1Name = save1.actionName
    let save2Name = save2.actionName
    let delete1Name = delete1.actionName

    // Then
    XCTAssertNotEqual(save1Name, save2Name)  // Different documents
    XCTAssertNotEqual(save1Name, delete1Name)  // Different operations
    XCTAssertEqual(save1Name, "saveDocument_doc1")
    XCTAssertEqual(delete1Name, "deleteFile__tmp_file1.txt")
  }

  func testAPIRequestDeduplication() {
    // Given - Same API requests that should be deduplicated
    let request1 = TestDataAction.fetchUser(id: "user123")
    let request2 = TestDataAction.fetchUser(id: "user123")
    let differentRequest = TestDataAction.fetchUser(id: "user456")

    // When
    let name1 = request1.actionName
    let name2 = request2.actionName
    let differentName = differentRequest.actionName

    // Then
    XCTAssertEqual(name1, name2)  // Same user requests should be deduplicated
    XCTAssertNotEqual(name1, differentName)  // Different users should run independently
  }

  // MARK: - Performance Tests

  func testActionNamePerformance() {
    // Given
    let action = TestDataAction.fetchUser(id: "performanceTest")

    // When & Then
    measure {
      for _ in 0..<10000 {
        _ = action.actionName
      }
    }
  }

  func testLockmanInfoPerformance() {
    // Given
    let action = TestDataAction.fetchUser(id: "performanceTest")

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
    let action = TestDataAction.fetchUser(id: "consistencyTest")

    // When - Call actionName multiple times
    let name1 = action.actionName
    let name2 = action.actionName
    let name3 = action.actionName

    // Then - Should always return the same value
    XCTAssertEqual(name1, name2)
    XCTAssertEqual(name2, name3)
  }

  func testComplexParameterHandling() {
    // Given
    let complexId = "user_with_complex-data.123!@#$%"
    let action = TestDataAction.fetchUser(id: complexId)

    // When
    let actionName = action.actionName

    // Then
    XCTAssertEqual(actionName, "fetchUser_\(complexId)")
    XCTAssertTrue(actionName.contains("!@#$%"))
  }

  func testNumericsInParameters() {
    // Given
    let numericIds = ["0", "1", "-1", "123456789", String(Int.max)]

    // When & Then
    for id in numericIds {
      let action = TestDataAction.fetchUser(id: id)
      let actionName = action.actionName
      XCTAssertEqual(actionName, "fetchUser_\(id)")
      XCTAssertFalse(actionName.isEmpty)
    }
  }

  // MARK: - Thread Safety Tests

  func testConcurrentActionNameAccess() {
    // Given
    let action = TestDataAction.fetchUser(id: "concurrentTest")
    let expectation = XCTestExpectation(description: "Concurrent access")
    expectation.expectedFulfillmentCount = 10
    var actionNames: [String] = []
    let lock = NSLock()

    // When - Access actionName concurrently
    DispatchQueue.concurrentPerform(iterations: 10) { _ in
      let name = action.actionName

      lock.lock()
      actionNames.append(name)
      lock.unlock()

      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 5.0)

    // Then - All names should be identical
    let uniqueNames = Set(actionNames)
    XCTAssertEqual(uniqueNames.count, 1)
    XCTAssertEqual(actionNames.count, 10)
  }

  func testConcurrentLockmanInfoCreation() {
    // Given
    let action = TestDataAction.fetchUser(id: "concurrentInfoTest")
    let expectation = XCTestExpectation(description: "Concurrent info creation")
    expectation.expectedFulfillmentCount = 10
    var infos: [LockmanSingleExecutionInfo] = []
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
    let modes = Set(infos.map { $0.mode })

    XCTAssertEqual(actionIds.count, 1)  // Same actionId
    XCTAssertEqual(uniqueIds.count, 10)  // Unique uniqueIds
    XCTAssertEqual(modes.count, 1)  // Same mode
    XCTAssertTrue(modes.contains(.action))
  }

  // MARK: - Documentation Example Validation Tests

  func testDocumentationPattern1() {
    // Given - Simple enum with cases
    enum UserAction: LockmanSingleExecutionAction {
      case login
      case logout
      case refreshProfile

      var actionName: String {
        switch self {
        case .login: return "login"
        case .logout: return "logout"
        case .refreshProfile: return "refreshProfile"
        }
      }

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: LockmanActionId(actionName),
          mode: .action
        )
      }
    }

    // When & Then
    XCTAssertEqual(UserAction.login.actionName, "login")
    XCTAssertEqual(UserAction.logout.actionName, "logout")
    XCTAssertEqual(UserAction.refreshProfile.actionName, "refreshProfile")
  }

  func testDocumentationPattern2() {
    // Given - Manual implementation with parameters
    enum DataAction: LockmanSingleExecutionAction {
      case fetchUser(id: String)
      case saveSettings

      var actionName: String {
        switch self {
        case .fetchUser(let id): return "fetchUser_\(id)"
        case .saveSettings: return "saveSettings"
        }
      }

      func createLockmanInfo() -> LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
          actionId: LockmanActionId(actionName),
          mode: .action
        )
      }
    }

    // When & Then
    let fetchAction = DataAction.fetchUser(id: "123")
    let saveAction = DataAction.saveSettings

    XCTAssertEqual(fetchAction.actionName, "fetchUser_123")
    XCTAssertEqual(saveAction.actionName, "saveSettings")
    XCTAssertNotEqual(fetchAction.actionName, saveAction.actionName)
  }
}
