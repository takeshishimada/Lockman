import Foundation
import XCTest
@testable import LockmanCore

// MARK: - Test Helpers

// Mock LockmanInfo
private struct MockLockmanInfo: LockmanInfo, Equatable {
  let actionId: String
  let uniqueId: UUID = .init()

  var description: String {
    "MockLockmanInfo(id: \(actionId))"
  }

  var debugDescription: String {
    "MockLockmanInfo(actionId: \(actionId))"
  }

  static func == (lhs: MockLockmanInfo, rhs: MockLockmanInfo) -> Bool {
    lhs.actionId == rhs.actionId
  }
}

// Mock BoundaryId
private struct MockBoundaryId: LockmanBoundaryId {
  let value: String

  func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }

  static func == (lhs: MockBoundaryId, rhs: MockBoundaryId) -> Bool {
    lhs.value == rhs.value
  }
}

// Mock Strategy for testing - Changed from final to open class
private class MockLockmanStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = MockLockmanInfo

  var strategyId: LockmanStrategyId { LockmanStrategyId(type: type(of: self)) }

  static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }

  var cleanUpCallCount = 0
  var cleanUpWithIdCallCount = 0
  var lastCleanUpId: (any LockmanBoundaryId)?
  var identifier: String

  private var lockState: [AnyLockmanBoundaryId: [MockLockmanInfo]] = [:]

  init(identifier: String = "default") {
    self.identifier = identifier
  }

  func canLock<B: LockmanBoundaryId>(id _: B, info _: MockLockmanInfo) -> LockResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(id: B, info: MockLockmanInfo) {
    let anyId = AnyLockmanBoundaryId(id)
    lockState[anyId, default: []].append(info)
  }

  func unlock<B: LockmanBoundaryId>(id: B, info _: MockLockmanInfo) {
    let anyId = AnyLockmanBoundaryId(id)
    lockState[anyId]?.removeLast()
    if lockState[anyId]?.isEmpty == true {
      lockState.removeValue(forKey: anyId)
    }
  }

  func cleanUp() {
    cleanUpCallCount += 1
    lockState.removeAll()
  }

  func cleanUp<B: LockmanBoundaryId>(id: B) {
    cleanUpWithIdCallCount += 1
    lastCleanUpId = id
    let anyId = AnyLockmanBoundaryId(id)
    lockState.removeValue(forKey: anyId)
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]
    for (boundaryId, infos) in lockState {
      result[boundaryId] = infos.map { $0 as any LockmanInfo }
    }
    return result
  }
}

// Another mock strategy with different info type
private struct AnotherMockLockmanInfo: LockmanInfo {
  let actionId: LockmanActionId
  let uniqueId: UUID = .init()

  var description: String {
    "AnotherMockLockmanInfo(actionId: \(actionId))"
  }

  var debugDescription: String {
    "AnotherMockLockmanInfo(actionId: \(actionId))"
  }
}

private final class AnotherMockLockmanStrategy: LockmanStrategy, @unchecked Sendable {
  typealias I = AnotherMockLockmanInfo

  var strategyId: LockmanStrategyId { LockmanStrategyId(type: type(of: self)) }

  static func makeStrategyId() -> LockmanStrategyId { LockmanStrategyId(type: self) }

  var identifier: String
  var cleanUpCallCount = 0
  var cleanUpWithIdCallCount = 0
  var lastCleanUpId: (any LockmanBoundaryId)?

  private var lockState: [AnyLockmanBoundaryId: [AnotherMockLockmanInfo]] = [:]

  init(identifier: String) {
    self.identifier = identifier
  }

  func canLock<B: LockmanBoundaryId>(id _: B, info _: AnotherMockLockmanInfo) -> LockResult {
    .success
  }

  func lock<B: LockmanBoundaryId>(id: B, info: AnotherMockLockmanInfo) {
    let anyId = AnyLockmanBoundaryId(id)
    lockState[anyId, default: []].append(info)
  }

  func unlock<B: LockmanBoundaryId>(id: B, info _: AnotherMockLockmanInfo) {
    let anyId = AnyLockmanBoundaryId(id)
    lockState[anyId]?.removeLast()
    if lockState[anyId]?.isEmpty == true {
      lockState.removeValue(forKey: anyId)
    }
  }

  func cleanUp() {
    cleanUpCallCount += 1
    lockState.removeAll()
  }

  func cleanUp<B: LockmanBoundaryId>(id: B) {
    cleanUpWithIdCallCount += 1
    lastCleanUpId = id
    let anyId = AnyLockmanBoundaryId(id)
    lockState.removeValue(forKey: anyId)
  }

  func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]
    for (boundaryId, infos) in lockState {
      result[boundaryId] = infos.map { $0 as any LockmanInfo }
    }
    return result
  }
}

// Additional mock strategy types for testing different concrete types
private final class FirstMockStrategy: MockLockmanStrategy, @unchecked Sendable {
  override init(identifier: String = "first") {
    super.init(identifier: identifier)
  }
}

private final class SecondMockStrategy: MockLockmanStrategy, @unchecked Sendable {
  override init(identifier: String = "second") {
    super.init(identifier: identifier)
  }
}

private final class ThirdMockStrategy: MockLockmanStrategy, @unchecked Sendable {
  override init(identifier: String = "third") {
    super.init(identifier: identifier)
  }
}

// MARK: - LockmanStrategyContainer Tests

final class LockmanStrategyContainerTests: XCTestCase {
  // MARK: - Basic Operations

  func testtestRegisterAndResolveSingleStrategy() throws {
    let container = LockmanStrategyContainer()
    let strategy = MockLockmanStrategy()

    try container.register(strategy)

    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  func testtestRegisterAndResolveMultipleDifferentStrategies() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    let resolvedMock = try container.resolve(MockLockmanStrategy.self)
    let resolvedAnother = try container.resolve(AnotherMockLockmanStrategy.self)

    XCTAssertTrue(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    XCTAssertTrue(type(of: resolvedAnother) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  func testtestResolveUnregisteredStrategyThrowsError() {
    let container = LockmanStrategyContainer()

    XCTAssertTrue(throws: LockmanError.self) {
      _ = try container.resolve(MockLockmanStrategy.self)
    }
  }

  func testtestResolveUnregisteredStrategyThrowsCorrectError() {
    let container = LockmanStrategyContainer()

    do {
      _ = try container.resolve(MockLockmanStrategy.self)
      XCTAssertTrue(Bool(false), "Should have thrown an error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("MockLockmanStrategy"))
      default:
        XCTAssertTrue(Bool(false), "Wrong error type")
      }
    } catch {
      XCTAssertTrue(Bool(false), "Should have thrown LockmanError")
    }
  }

  func testtestReRegisterSameTypeThrowsError() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    try container.register(strategy1)

    XCTAssertTrue(throws: LockmanError.self) {
      try container.register(strategy2)
    }
  }

  func testtestReRegisterSameTypeThrowsCorrectError() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    try container.register(strategy1)

    do {
      try container.register(strategy2)
      XCTAssertTrue(Bool(false), "Should have thrown an error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        XCTAssertTrue(strategyType.contains("MockLockmanStrategy"))
      default:
        XCTAssertTrue(Bool(false), "Wrong error type")
      }
    } catch {
      XCTAssertTrue(Bool(false), "Should have thrown LockmanError")
    }
  }

  func testtestCleanUpCallsAllStrategies() {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try? container.register(mockStrategy)
    try? container.register(anotherStrategy)

    container.cleanUp()

    XCTAssertEqual(mockStrategy.cleanUpCallCount , 1)
    XCTAssertEqual(anotherStrategy.cleanUpCallCount , 1)
  }

  func testtestCleanUpWithIdCallsAllStrategies() {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")
    let boundaryId = MockBoundaryId(value: "test")

    try? container.register(mockStrategy)
    try? container.register(anotherStrategy)

    container.cleanUp(id: boundaryId)

    XCTAssertEqual(mockStrategy.cleanUpWithIdCallCount , 1)
    XCTAssertEqual(anotherStrategy.cleanUpWithIdCallCount , 1)
    XCTAssertTrue((mockStrategy.lastCleanUpId as? MockBoundaryId)?.value == "test")
    XCTAssertTrue((anotherStrategy.lastCleanUpId as? MockBoundaryId)?.value == "test")
  }

  func testtestCleanUpOnEmptyContainer() {
    let container = LockmanStrategyContainer()

    // Should not crash
    container.cleanUp()
    container.cleanUp(id: MockBoundaryId(value: "test"))
  }

  // MARK: - Type Safety Tests

  func testtestTypeSafetyWithDifferentInfoTypes() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    // Each strategy should be resolved correctly
    let mock = try container.resolve(MockLockmanStrategy.self)
    let another = try container.resolve(AnotherMockLockmanStrategy.self)

    XCTAssertTrue(type(of: mock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    XCTAssertTrue(type(of: another) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  func testtestStrategyTypesAreIsolated() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy(identifier: "mock")
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "another")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    // Should be able to resolve both independently
    let resolvedMock = try container.resolve(MockLockmanStrategy.self)
    let resolvedAnother = try container.resolve(AnotherMockLockmanStrategy.self)

    XCTAssertTrue(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    XCTAssertTrue(type(of: resolvedAnother) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  // MARK: - Concurrent Access Tests

  func testtestConcurrentRegisterOperationsDifferentTypes() async throws {
    let container = LockmanStrategyContainer()

    // Create unique strategy classes to avoid duplicate registration errors
    let strategies = await withTaskGroup(of: (String, Bool).self, returning: [(String, Bool)].self) { group in
      for i in 0 ..< 10 {
        group.addTask {
          let strategy = AnotherMockLockmanStrategy(identifier: "\(i)")
          do {
            try container.register(strategy)
            return ("\(i)", true)
          } catch {
            return ("\(i)", false)
          }
        }
      }

      var results: [(String, Bool)] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    // Only one should succeed due to same type registration
    let successCount = strategies.filter(\.1).count
    XCTAssertEqual(successCount , 1)
  }

  func testtestConcurrentResolveOperations() async throws {
    let container = LockmanStrategyContainer()
    let strategy = MockLockmanStrategy()
    try container.register(strategy)

    let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
      for _ in 0 ..< 100 {
        group.addTask {
          do {
            _ = try container.resolve(MockLockmanStrategy.self)
            return true
          } catch {
            return false
          }
        }
      }

      var successes: [Bool] = []
      for await success in group {
        successes.append(success)
      }
      return successes
    }

    XCTAssertEqual(results.count , 100)
    XCTAssertTrue(results.allSatisfy { $0 }) // All should succeed
  }

  func testtestConcurrentRegisterAndResolve() async throws {
    let container = LockmanStrategyContainer()

    let results = await withTaskGroup(of: String.self, returning: [String].self) { group in
      // Register operation (only first should succeed)
      for i in 0 ..< 5 {
        group.addTask {
          let strategy = AnotherMockLockmanStrategy(identifier: "\(i)")
          do {
            try container.register(strategy)
            return "register_success_\(i)"
          } catch {
            return "register_failed_\(i)"
          }
        }
      }

      // Resolve operations
      for i in 0 ..< 5 {
        group.addTask {
          // Wait a bit to let registration potentially complete
          try? await Task.sleep(for: .milliseconds(10))
          do {
            _ = try container.resolve(AnotherMockLockmanStrategy.self)
            return "resolve_success_\(i)"
          } catch {
            return "resolve_failed_\(i)"
          }
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }
      return results
    }

    let registerSuccesses = results.filter { $0.contains("register_success") }
    let resolveSuccesses = results.filter { $0.contains("resolve_success") }

    XCTAssertEqual(registerSuccesses.count , 1) // Only one registration should succeed
    XCTAssertTrue(resolveSuccesses.count >= 1) // At least some resolves should succeed
  }

  func testtestConcurrentCleanUpOperations() async throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "concurrent")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          container.cleanUp()
        }
      }

      for i in 0 ..< 10 {
        group.addTask {
          container.cleanUp(id: MockBoundaryId(value: "\(i)"))
        }
      }
    }

    // Each strategy should have been cleaned up multiple times
    XCTAssertTrue(mockStrategy.cleanUpCallCount >= 10)
    XCTAssertTrue(anotherStrategy.cleanUpCallCount >= 10)
    XCTAssertTrue(mockStrategy.cleanUpWithIdCallCount >= 10)
    XCTAssertTrue(anotherStrategy.cleanUpWithIdCallCount >= 10)
  }

  // MARK: - Edge Cases

  func testtestMultipleStrategiesOfDifferentConcreteTypes() throws {
    let container = LockmanStrategyContainer()
    let s1 = FirstMockStrategy()
    let s2 = SecondMockStrategy()
    let s3 = ThirdMockStrategy()

    try container.register(s1)
    try container.register(s2)
    try container.register(s3)

    let resolved1 = try container.resolve(FirstMockStrategy.self)
    let resolved2 = try container.resolve(SecondMockStrategy.self)
    let resolved3 = try container.resolve(ThirdMockStrategy.self)

    XCTAssertTrue(type(of: resolved1) == AnyLockmanStrategy<MockLockmanInfo>.self)
    XCTAssertTrue(type(of: resolved2) == AnyLockmanStrategy<MockLockmanInfo>.self)
    XCTAssertTrue(type(of: resolved3) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  func testtestContainerStateConsistencyAfterErrors() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    // First registration should succeed
    try container.register(strategy1)

    // Second registration should fail
    do {
      try container.register(strategy2)
      XCTAssertTrue(Bool(false), "Should have thrown error")
    } catch {
      // Expected
    }

    // Original strategy should still be resolvable
    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  // MARK: - Integration Tests

  func testtestIntegrationWithRealStrategyTypes() throws {
    let container = LockmanStrategyContainer()
    let singleExecution = LockmanSingleExecutionStrategy()
    let priorityBased = LockmanPriorityBasedStrategy()

    try container.register(singleExecution)
    try container.register(priorityBased)

    let resolvedSingle = try container.resolve(LockmanSingleExecutionStrategy.self)
    let resolvedPriority = try container.resolve(LockmanPriorityBasedStrategy.self)

    XCTAssertTrue(type(of: resolvedSingle) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    XCTAssertTrue(type(of: resolvedPriority) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  func testtestContainerWithLockmanFacade() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy(identifier: "facade_test")

    try testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      // Should be able to resolve through the facade
      let resolved: AnyLockmanStrategy<MockLockmanInfo>
      do {
        resolved = try Lockman.container.resolve(MockLockmanStrategy.self)
      } catch {
        XCTAssertTrue(Bool(false), "Unexpected error: \(error)")
        return
      }
      // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
      XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
    }
  }
}

// MARK: - Memory Management Tests

final class LockmanStrategyContainerMemoryTests: XCTestCase {
  func testtestStrategyDeallocationAfterContainerRelease() {
    weak var weakStrategy: MockLockmanStrategy?

    do {
      let container = LockmanStrategyContainer()
      let strategy = MockLockmanStrategy()
      weakStrategy = strategy

      try? container.register(strategy)
      XCTAssertNotNil(weakStrategy)
    }

    // Container is released, strategy should also be released
    XCTAssertNil(weakStrategy)
  }

  func testtestNoRetainCycles() {
    weak var weakContainer: LockmanStrategyContainer?
    weak var weakStrategy: MockLockmanStrategy?

    do {
      let container = LockmanStrategyContainer()
      let strategy = MockLockmanStrategy()

      weakContainer = container
      weakStrategy = strategy

      try? container.register(strategy)
    }

    XCTAssertNil(weakContainer)
    XCTAssertNil(weakStrategy)
  }

  func testtestMultipleStrategyCleanupAfterDeallocation() {
    weak var weakMock: MockLockmanStrategy?
    weak var weakAnother: AnotherMockLockmanStrategy?

    do {
      let container = LockmanStrategyContainer()
      let mockStrategy = MockLockmanStrategy()
      let anotherStrategy = AnotherMockLockmanStrategy(identifier: "memory_test")

      weakMock = mockStrategy
      weakAnother = anotherStrategy

      try? container.register(mockStrategy)
      try? container.register(anotherStrategy)

      XCTAssertNotNil(weakMock)
      XCTAssertNotNil(weakAnother)
    }

    XCTAssertNil(weakMock)
    XCTAssertNil(weakAnother)
  }
}

// MARK: - Performance Tests

final class LockmanStrategyContainerPerformanceTests: XCTestCase {
  func testtestPerformanceWithFrequentResolveOperations() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "performance")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    let iterations = 1000
    let startTime = Date()

    for _ in 0 ..< iterations {
      _ = try container.resolve(MockLockmanStrategy.self)
      _ = try container.resolve(AnotherMockLockmanStrategy.self)
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    // Should complete within reasonable time
    XCTAssertTrue(duration < 1.0)
  }

  func testtestPerformanceWithManyConcurrentResolves() async throws {
    let container = LockmanStrategyContainer()
    let strategy = MockLockmanStrategy()
    try container.register(strategy)

    let startTime = Date()

    await withTaskGroup(of: Void.self) { group in
      for _ in 0 ..< 1000 {
        group.addTask {
          _ = try? container.resolve(MockLockmanStrategy.self)
        }
      }
    }

    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)

    XCTAssertTrue(duration < 2.0 * 5)
  }

  func testtestMemoryEfficiencyWithStrategyTypes() throws {
    let container = LockmanStrategyContainer()

    // Create many different strategy instances of the same type
    // Only the first should be stored due to duplicate registration prevention
    for i in 0 ..< 100 {
      let strategy = MockLockmanStrategy(identifier: "strategy_\(i)")
      if i == 0 {
        try container.register(strategy)
      } else {
        // These should all fail
        XCTAssertTrue(throws: LockmanError.self) {
          try container.register(strategy)
        }
      }
    }

    // Should still be able to resolve the first one
    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    XCTAssertTrue(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }
}
