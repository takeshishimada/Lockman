import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Shared Test Support Types

/// Common test reducer state used across all Composable tests
public struct TestReducerState: Equatable, Sendable {
  public var counter: Int = 0
  public var isProcessing: Bool = false
  public var lastActionId: String = ""
  public var isAuthenticated: Bool = true
  public var balance: Double = 100.0

  public init(
    counter: Int = 0,
    isProcessing: Bool = false,
    lastActionId: String = "",
    isAuthenticated: Bool = true,
    balance: Double = 100.0
  ) {
    self.counter = counter
    self.isProcessing = isProcessing
    self.lastActionId = lastActionId
    self.isAuthenticated = isAuthenticated
    self.balance = balance
  }
}

/// Common test boundary ID used across all Composable tests
public struct TestBoundaryId: LockmanBoundaryId {
  public let value: String

  public init(value: String) {
    self.value = value
  }

  public static let test = TestBoundaryId(value: "test")
  public static let feature = TestBoundaryId(value: "feature")
  public static let navigation = TestBoundaryId(value: "navigation")
  public static let secondary = TestBoundaryId(value: "secondary")
}

/// Common test lockman info used across all Composable tests
public struct TestLockmanInfo: LockmanInfo {
  public let actionId: LockmanActionId
  public let strategyId: LockmanStrategyId
  public let uniqueId: UUID
  public let isCancellationTarget: Bool

  public init(
    actionId: LockmanActionId,
    strategyId: LockmanStrategyId,
    uniqueId: UUID = UUID(),
    isCancellationTarget: Bool = false
  ) {
    self.actionId = actionId
    self.strategyId = strategyId
    self.uniqueId = uniqueId
    self.isCancellationTarget = isCancellationTarget
  }

  public var debugDescription: String {
    return
      "TestLockmanInfo(action: \(actionId), strategy: \(strategyId), unique: \(uniqueId), cancellable: \(isCancellationTarget))"
  }
}

/// Common test action used across all Composable tests
public enum SharedTestAction: LockmanAction, Sendable, Equatable {
  case test
  case increment
  case decrement
  case setProcessing(Bool)
  case nonLockmanAction

  public var actionName: String {
    switch self {
    case .test: return "test"
    case .increment: return "increment"
    case .decrement: return "decrement"
    case .setProcessing: return "setProcessing"
    case .nonLockmanAction: return "nonLockmanAction"
    }
  }

  public func createLockmanInfo() -> TestLockmanInfo {
    return TestLockmanInfo(
      actionId: actionName,
      strategyId: LockmanStrategyId(name: "TestSingleExecutionStrategy")
    )
  }

  public var unlockOption: LockmanUnlockOption { .immediate }
}

// MARK: - Test-Only Equatable Conformances

extension LockmanRegistrationError: Equatable {
  public static func == (lhs: LockmanRegistrationError, rhs: LockmanRegistrationError) -> Bool {
    switch (lhs, rhs) {
    case (.strategyAlreadyRegistered(let lhsType), .strategyAlreadyRegistered(let rhsType)):
      return lhsType == rhsType
    case (.strategyNotRegistered(let lhsType), .strategyNotRegistered(let rhsType)):
      return lhsType == rhsType
    default:
      return false
    }
  }
}

extension LockmanResult: Equatable {
  public static func == (lhs: LockmanResult, rhs: LockmanResult) -> Bool {
    switch (lhs, rhs) {
    case (.success, .success):
      return true
    case (
      .successWithPrecedingCancellation(let lhsError),
      .successWithPrecedingCancellation(let rhsError)
    ):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription
    case (.cancel(let lhsError), .cancel(let rhsError)):
      // Compare errors by their localized description since Error is not Equatable
      return lhsError.localizedDescription == rhsError.localizedDescription
    default:
      return false
    }
  }
}

/// Common test reducer used across all Composable tests
public struct TestReducer: Reducer {
  public typealias State = TestReducerState
  public typealias Action = SharedTestAction

  public init() {}

  public var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .test:
        state.lastActionId = action.actionName
        return .none

      case .increment:
        state.counter += 1
        state.lastActionId = action.actionName
        return .none

      case .decrement:
        state.counter -= 1
        state.lastActionId = action.actionName
        return .none

      case .setProcessing(let isProcessing):
        state.isProcessing = isProcessing
        state.lastActionId = action.actionName
        return .none

      case .nonLockmanAction:
        state.lastActionId = action.actionName
        return .none
      }
    }
  }
}

/// Common test strategy used across all Composable tests
public final class TestSingleExecutionStrategy: LockmanStrategy, @unchecked Sendable {
  public typealias I = TestLockmanInfo

  private var lockedActions: Set<String> = []
  private let lock = NSLock()

  public var strategyId: LockmanStrategyId {
    LockmanStrategyId(name: "TestSingleExecutionStrategy")
  }

  public init() {}

  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "TestSingleExecutionStrategy")
  }

  public func canLock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) -> LockmanResult {
    lock.withLock {
      if lockedActions.contains(info.actionId) {
        let error = LockmanCancellationError(
          action: SharedTestAction.test,
          boundaryId: boundaryId,
          reason: LockmanRegistrationError.strategyAlreadyRegistered("Action already locked")
        )
        return .cancel(error)
      }
      return .success
    }
  }

  public func lock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    _ = lock.withLock {
      lockedActions.insert(info.actionId)
    }
  }

  public func unlock<B: LockmanBoundaryId>(boundaryId: B, info: TestLockmanInfo) {
    _ = lock.withLock {
      lockedActions.remove(info.actionId)
    }
  }

  public func cleanUp() {
    lock.withLock {
      lockedActions.removeAll()
    }
  }

  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    // Mock implementation - remove all for simplicity
    cleanUp()
  }

  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    // Mock implementation returns empty state
    return [:]
  }
}

/// Common test support utilities for LockmanTestsNew
public final class TestSupport {

  // MARK: - Test Data Generation

  /// Generates unique test action IDs with optional prefix
  public static func uniqueActionId(prefix: String = "test") -> LockmanActionId {
    return "\(prefix)_\(UUID().uuidString)"
  }

  /// Generates multiple unique action IDs
  public static func uniqueActionIds(count: Int, prefix: String = "test") -> [LockmanActionId] {
    return (0..<count).map { _ in uniqueActionId(prefix: prefix) }
  }

  /// Standard test action IDs for consistent testing
  public enum StandardActionIds {
    public static let simple = "testAction"
    public static let empty = ""
    public static let unicode = "テスト_アクション_🚀"
    public static let withNumbers = "action123"
    public static let withSpecialChars = "action-with.special@chars"
    public static let veryLong = String(repeating: "longAction", count: 100)
    public static let withNewlines = "action\nwith\nnewlines"
    public static let withTabs = "action\twith\ttabs"
  }

  // MARK: - Test Boundary IDs

  /// Standard test boundary IDs
  public enum StandardBoundaryIds {
    public static let main = "main"
    public static let secondary = "secondary"
    public static let unicode = "境界_🌟"
    public static let empty = ""
    public static let numeric = "123"
  }

  // MARK: - Concurrency Test Helpers

  /// Executes a block of code concurrently and waits for completion
  public static func executeConcurrently<T: Sendable>(
    iterations: Int = 10,
    operation: @escaping @Sendable () throws -> T
  ) async throws -> [T] {
    return try await withThrowingTaskGroup(of: T.self) { group in
      for _ in 0..<iterations {
        group.addTask {
          try operation()
        }
      }

      var results: [T] = []
      for try await result in group {
        results.append(result)
      }
      return results
    }
  }

  /// Performs concurrent operations on the same resource
  public static func performConcurrentOperations(
    count: Int = 10,
    operation: @escaping @Sendable () -> Void
  ) async {
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<count {
        group.addTask {
          operation()
        }
      }
    }
  }

  // MARK: - Assertion Helpers

  /// Asserts that two collections contain the same elements regardless of order
  public static func assertContainsSameElements<T: Equatable & Hashable>(
    _ actual: [T],
    _ expected: [T],
    file: StaticString = #file,
    line: UInt = #line
  ) {
    XCTAssertEqual(Set(actual), Set(expected), file: file, line: line)
  }

  /// Asserts that a throwing operation produces a specific error type
  public static func assertThrows<T: Error>(
    _ expectedErrorType: T.Type,
    _ operation: () throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    do {
      try operation()
      XCTFail("Expected operation to throw \(expectedErrorType)", file: file, line: line)
    } catch {
      XCTAssertTrue(
        error is T,
        "Expected \(expectedErrorType), got \(type(of: error))",
        file: file,
        line: line
      )
    }
  }

  // MARK: - Performance Helpers

  /// Measures execution time of an operation
  public static func measureExecutionTime(
    operation: () throws -> Void
  ) rethrows -> TimeInterval {
    let startTime = CFAbsoluteTimeGetCurrent()
    try operation()
    let endTime = CFAbsoluteTimeGetCurrent()
    return endTime - startTime
  }

  // MARK: - Test Cleanup

  /// Performs standard test cleanup
  public static func performStandardCleanup() {
    LockmanManager.cleanup.all()
  }
}

// MARK: - XCTestCase Extensions

extension XCTestCase {

  /// Convenience method to get unique action ID
  public func uniqueActionId(prefix: String = "test") -> LockmanActionId {
    return TestSupport.uniqueActionId(prefix: prefix)
  }

  /// Convenience method to perform standard cleanup
  public func performStandardCleanup() {
    TestSupport.performStandardCleanup()
  }

  /// Waits for a condition to be true with timeout
  public func waitForCondition(
    timeout: TimeInterval = 1.0,
    condition: @escaping @Sendable () -> Bool
  ) async -> Bool {
    let endTime = Date().addingTimeInterval(timeout)

    while Date() < endTime {
      if condition() {
        return true
      }
      try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
    }

    return false
  }
}
