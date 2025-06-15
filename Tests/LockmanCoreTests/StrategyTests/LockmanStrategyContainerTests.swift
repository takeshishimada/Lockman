import Foundation
import Testing
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

@Suite("LockmanStrategyContainer Tests")
struct LockmanStrategyContainerTests {
  // MARK: - Basic Operations

  @Test("Register and resolve single strategy")
  func testRegisterAndResolveSingleStrategy() throws {
    let container = LockmanStrategyContainer()
    let strategy = MockLockmanStrategy()

    try container.register(strategy)

    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    #expect(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  @Test("Register and resolve multiple different strategies")
  func testRegisterAndResolveMultipleDifferentStrategies() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    let resolvedMock = try container.resolve(MockLockmanStrategy.self)
    let resolvedAnother = try container.resolve(AnotherMockLockmanStrategy.self)

    #expect(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    #expect(type(of: resolvedAnother) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  @Test("Resolve unregistered strategy throws error")
  func testResolveUnregisteredStrategyThrowsError() {
    let container = LockmanStrategyContainer()

    #expect(throws: LockmanError.self) {
      _ = try container.resolve(MockLockmanStrategy.self)
    }
  }

  @Test("Resolve unregistered strategy throws correct error")
  func testResolveUnregisteredStrategyThrowsCorrectError() {
    let container = LockmanStrategyContainer()

    do {
      _ = try container.resolve(MockLockmanStrategy.self)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyNotRegistered(strategyType):
        #expect(strategyType.contains("MockLockmanStrategy"))
      default:
        #expect(Bool(false), "Wrong error type")
      }
    } catch {
      #expect(Bool(false), "Should have thrown LockmanError")
    }
  }

  @Test("Re-register same type throws error")
  func testReRegisterSameTypeThrowsError() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    try container.register(strategy1)

    #expect(throws: LockmanError.self) {
      try container.register(strategy2)
    }
  }

  @Test("Re-register same type throws correct error")
  func testReRegisterSameTypeThrowsCorrectError() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    try container.register(strategy1)

    do {
      try container.register(strategy2)
      #expect(Bool(false), "Should have thrown an error")
    } catch let error as LockmanError {
      switch error {
      case let .strategyAlreadyRegistered(strategyType):
        #expect(strategyType.contains("MockLockmanStrategy"))
      default:
        #expect(Bool(false), "Wrong error type")
      }
    } catch {
      #expect(Bool(false), "Should have thrown LockmanError")
    }
  }

  @Test("Clean up calls all strategies")
  func testCleanUpCallsAllStrategies() {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try? container.register(mockStrategy)
    try? container.register(anotherStrategy)

    container.cleanUp()

    #expect(mockStrategy.cleanUpCallCount == 1)
    #expect(anotherStrategy.cleanUpCallCount == 1)
  }

  @Test("Clean up with id calls all strategies")
  func testCleanUpWithIdCallsAllStrategies() {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")
    let boundaryId = MockBoundaryId(value: "test")

    try? container.register(mockStrategy)
    try? container.register(anotherStrategy)

    container.cleanUp(id: boundaryId)

    #expect(mockStrategy.cleanUpWithIdCallCount == 1)
    #expect(anotherStrategy.cleanUpWithIdCallCount == 1)
    #expect((mockStrategy.lastCleanUpId as? MockBoundaryId)?.value == "test")
    #expect((anotherStrategy.lastCleanUpId as? MockBoundaryId)?.value == "test")
  }

  @Test("Clean up on empty container")
  func testCleanUpOnEmptyContainer() {
    let container = LockmanStrategyContainer()

    // Should not crash
    container.cleanUp()
    container.cleanUp(id: MockBoundaryId(value: "test"))
  }

  // MARK: - Type Safety Tests

  @Test("Type safety with different info types")
  func testTypeSafetyWithDifferentInfoTypes() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy()
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "test")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    // Each strategy should be resolved correctly
    let mock = try container.resolve(MockLockmanStrategy.self)
    let another = try container.resolve(AnotherMockLockmanStrategy.self)

    #expect(type(of: mock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    #expect(type(of: another) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  @Test("Strategy types are isolated")
  func testStrategyTypesAreIsolated() throws {
    let container = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy(identifier: "mock")
    let anotherStrategy = AnotherMockLockmanStrategy(identifier: "another")

    try container.register(mockStrategy)
    try container.register(anotherStrategy)

    // Should be able to resolve both independently
    let resolvedMock = try container.resolve(MockLockmanStrategy.self)
    let resolvedAnother = try container.resolve(AnotherMockLockmanStrategy.self)

    #expect(type(of: resolvedMock) == AnyLockmanStrategy<MockLockmanInfo>.self)
    #expect(type(of: resolvedAnother) == AnyLockmanStrategy<AnotherMockLockmanInfo>.self)
  }

  // MARK: - Concurrent Access Tests

  @Test("Concurrent register operations (different types)")
  func testConcurrentRegisterOperationsDifferentTypes() async throws {
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
    #expect(successCount == 1)
  }

  @Test("Concurrent resolve operations")
  func testConcurrentResolveOperations() async throws {
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

    #expect(results.count == 100)
    #expect(results.allSatisfy { $0 }) // All should succeed
  }

  @Test("Concurrent register and resolve")
  func testConcurrentRegisterAndResolve() async throws {
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

    #expect(registerSuccesses.count == 1) // Only one registration should succeed
    #expect(resolveSuccesses.count >= 1) // At least some resolves should succeed
  }

  @Test("Concurrent clean up operations")
  func testConcurrentCleanUpOperations() async throws {
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
    #expect(mockStrategy.cleanUpCallCount >= 10)
    #expect(anotherStrategy.cleanUpCallCount >= 10)
    #expect(mockStrategy.cleanUpWithIdCallCount >= 10)
    #expect(anotherStrategy.cleanUpWithIdCallCount >= 10)
  }

  // MARK: - Edge Cases

  @Test("Multiple strategies of different concrete types")
  func testMultipleStrategiesOfDifferentConcreteTypes() throws {
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

    #expect(type(of: resolved1) == AnyLockmanStrategy<MockLockmanInfo>.self)
    #expect(type(of: resolved2) == AnyLockmanStrategy<MockLockmanInfo>.self)
    #expect(type(of: resolved3) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  @Test("Container state consistency after errors")
  func testContainerStateConsistencyAfterErrors() throws {
    let container = LockmanStrategyContainer()
    let strategy1 = MockLockmanStrategy(identifier: "first")
    let strategy2 = MockLockmanStrategy(identifier: "second")

    // First registration should succeed
    try container.register(strategy1)

    // Second registration should fail
    do {
      try container.register(strategy2)
      #expect(Bool(false), "Should have thrown error")
    } catch {
      // Expected
    }

    // Original strategy should still be resolvable
    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    #expect(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }

  // MARK: - Integration Tests

  @Test("Integration with real strategy types")
  func testIntegrationWithRealStrategyTypes() throws {
    let container = LockmanStrategyContainer()
    let singleExecution = LockmanSingleExecutionStrategy()
    let priorityBased = LockmanPriorityBasedStrategy()

    try container.register(singleExecution)
    try container.register(priorityBased)

    let resolvedSingle = try container.resolve(LockmanSingleExecutionStrategy.self)
    let resolvedPriority = try container.resolve(LockmanPriorityBasedStrategy.self)

    #expect(type(of: resolvedSingle) == AnyLockmanStrategy<LockmanSingleExecutionInfo>.self)
    #expect(type(of: resolvedPriority) == AnyLockmanStrategy<LockmanPriorityBasedInfo>.self)
  }

  @Test("Container with Lockman facade")
  func testContainerWithLockmanFacade() async throws {
    let testContainer = LockmanStrategyContainer()
    let mockStrategy = MockLockmanStrategy(identifier: "facade_test")

    try testContainer.register(mockStrategy)

    await Lockman.withTestContainer(testContainer) {
      // Should be able to resolve through the facade
      let resolved: AnyLockmanStrategy<MockLockmanInfo>
      do {
        resolved = try Lockman.container.resolve(MockLockmanStrategy.self)
      } catch {
        #expect(Bool(false), "Unexpected error: \(error)")
        return
      }
      // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
      #expect(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
    }
  }
}

// MARK: - Memory Management Tests

@Suite("LockmanStrategyContainer Memory Tests")
struct LockmanStrategyContainerMemoryTests {
  @Test("Strategy deallocation after container release")
  func testStrategyDeallocationAfterContainerRelease() {
    weak var weakStrategy: MockLockmanStrategy?

    do {
      let container = LockmanStrategyContainer()
      let strategy = MockLockmanStrategy()
      weakStrategy = strategy

      try? container.register(strategy)
      #expect(weakStrategy != nil)
    }

    // Container is released, strategy should also be released
    #expect(weakStrategy == nil)
  }

  @Test("No retain cycles")
  func testNoRetainCycles() {
    weak var weakContainer: LockmanStrategyContainer?
    weak var weakStrategy: MockLockmanStrategy?

    do {
      let container = LockmanStrategyContainer()
      let strategy = MockLockmanStrategy()

      weakContainer = container
      weakStrategy = strategy

      try? container.register(strategy)
    }

    #expect(weakContainer == nil)
    #expect(weakStrategy == nil)
  }

  @Test("Multiple strategy cleanup after deallocation")
  func testMultipleStrategyCleanupAfterDeallocation() {
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

      #expect(weakMock != nil)
      #expect(weakAnother != nil)
    }

    #expect(weakMock == nil)
    #expect(weakAnother == nil)
  }
}

// MARK: - Performance Tests

@Suite("LockmanStrategyContainer Performance Tests")
struct LockmanStrategyContainerPerformanceTests {
  @Test("Performance with frequent resolve operations")
  func testPerformanceWithFrequentResolveOperations() throws {
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
    #expect(duration < 1.0)
  }

  @Test("Performance with many concurrent resolves")
  func testPerformanceWithManyConcurrentResolves() async throws {
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

    #expect(duration < 2.0 * 5)
  }

  @Test("Memory efficiency with strategy types")
  func testMemoryEfficiencyWithStrategyTypes() throws {
    let container = LockmanStrategyContainer()

    // Create many different strategy instances of the same type
    // Only the first should be stored due to duplicate registration prevention
    for i in 0 ..< 100 {
      let strategy = MockLockmanStrategy(identifier: "strategy_\(i)")
      if i == 0 {
        try container.register(strategy)
      } else {
        // These should all fail
        #expect(throws: LockmanError.self) {
          try container.register(strategy)
        }
      }
    }

    // Should still be able to resolve the first one
    let resolved = try container.resolve(MockLockmanStrategy.self)
    // Resolved type is AnyLockmanStrategy<MockLockmanInfo>
    #expect(type(of: resolved) == AnyLockmanStrategy<MockLockmanInfo>.self)
  }
}
