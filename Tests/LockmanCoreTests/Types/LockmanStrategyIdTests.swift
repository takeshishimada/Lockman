import XCTest
@testable import LockmanCore

final class LockmanStrategyIdTests: XCTestCase {
  // MARK: - Basic Initialization Tests

  func testtestInitializeWithString() {
    let id = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id.value , "MyStrategy")
    XCTAssertEqual(id.description , "MyStrategy")
  }

  func testtestInitializeWithType() {
    let id = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    XCTAssertTrue(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  func testtestInitializeWithTypeAndIdentifier() {
    let id = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self,
      identifier: "custom-id"
    )
    XCTAssertEqual(id.value , "custom-id")
  }

  func testtestInitializeWithName() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy"
    )
    XCTAssertEqual(id.value , "RateLimitStrategy")
  }

  func testtestInitializeWithNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy",
      configuration: "limit-100"
    )
    XCTAssertEqual(id.value , "RateLimitStrategy:limit-100")
  }

  // MARK: - ExpressibleByStringLiteral Tests

  func testtestStringLiteralInitialization() {
    let id: LockmanStrategyId = "MyApp.CustomStrategy"
    XCTAssertEqual(id.value , "MyApp.CustomStrategy")
  }

  // MARK: - Factory Method Tests

  func testtestFactoryMethodFromType() {
    let id = LockmanStrategyId.from(LockmanPriorityBasedStrategy.self)
    XCTAssertTrue(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  func testtestFactoryMethodFromTypeWithIdentifier() {
    let id = LockmanStrategyId.from(
      LockmanPriorityBasedStrategy.self,
      identifier: "priority-custom"
    )
    XCTAssertEqual(id.value , "priority-custom")
  }

  // MARK: - Static Property Tests

  func testtestStaticSingleExecutionProperty() {
    let id = LockmanStrategyId.singleExecution
    XCTAssertTrue(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  func testtestStaticPriorityBasedProperty() {
    let id = LockmanStrategyId.priorityBased
    XCTAssertTrue(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  // MARK: - Equality and Hashing Tests

  func testtestEqualityWithSameValue() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id1 , id2)
  }

  func testtestInequalityWithDifferentValues() {
    let id1 = LockmanStrategyId("Strategy1")
    let id2 = LockmanStrategyId("Strategy2")
    XCTAssertNotEqual(id1 , id2)
  }

  func testtestHashConsistency() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id1.hashValue , id2.hashValue)
  }

  func testtestUseAsDictionaryKey() {
    var dict: [LockmanStrategyId: String] = [:]
    let id = LockmanStrategyId("TestStrategy")
    dict[id] = "value"
    XCTAssertEqual(dict[id] , "value")
  }

  // MARK: - Edge Case Tests

  func testtestEmptyStringId() {
    let id = LockmanStrategyId("")
    XCTAssertEqual(id.value , "")
  }

  func testtestUnicodeStringId() {
    let id = LockmanStrategyId("策略🎯")
    XCTAssertEqual(id.value , "策略🎯")
  }

  func testtestVeryLongStringId() {
    let longString = String(repeating: "a", count: 1000)
    let id = LockmanStrategyId(longString)
    XCTAssertEqual(id.value , longString)
    XCTAssertEqual(id.value.count , 1000)
  }

  func testtestSpecialCharactersInNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "Rate_Limit_Strategy",
      configuration: "limit:100/timeout:30"
    )
    XCTAssertEqual(id.value , "Rate_Limit_Strategy:limit:100/timeout:30")
  }

  // MARK: - Sendable Conformance Tests

  func testtestSendableAcrossConcurrentContexts() async throws {
    let id = LockmanStrategyId("ConcurrentStrategy")

    await withTaskGroup(of: String.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          // Access the id from concurrent context
          id.value
        }
      }

      for await value in group {
        XCTAssertEqual(value , "ConcurrentStrategy")
      }
    }
  }

  // MARK: - Real-World Usage Pattern Tests

  func testtestConfigurationVariantsOfSameStrategy() {
    let timeout30 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-30"
    )
    let timeout60 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-60"
    )

    XCTAssertNotEqual(timeout30 , timeout60)
    XCTAssertEqual(timeout30.value , "CacheStrategy:timeout-30")
    XCTAssertEqual(timeout60.value , "CacheStrategy:timeout-60")
  }

  func testtestDifferentStrategyNames() {
    let appStrategy = LockmanStrategyId(
      name: "AppUserStrategy"
    )
    let libraryStrategy = LockmanStrategyId(
      name: "LibUserStrategy"
    )

    XCTAssertNotEqual(appStrategy , libraryStrategy)
    XCTAssertEqual(appStrategy.value , "AppUserStrategy")
    XCTAssertEqual(libraryStrategy.value , "LibUserStrategy")
  }
}

// MARK: - Performance Tests

final class LockmanStrategyIdPerformanceTests: XCTestCase {
  func testtestCreationPerformance() async throws {
    let iterations = 10000

    let start = ContinuousClock.now
    for i in 0 ..< iterations {
      _ = LockmanStrategyId("Strategy\(i)")
    }
    let duration = start.duration(to: .now)

    // Should be very fast - under 100ms for 10k creations
    XCTAssertTrue(duration < .milliseconds(100))
  }

  func testtestEqualityComparisonPerformance() async throws {
    let id1 = LockmanStrategyId("TestStrategy")
    let id2 = LockmanStrategyId("TestStrategy")
    let id3 = LockmanStrategyId("DifferentStrategy")
    let iterations = 100000

    let start = ContinuousClock.now
    for _ in 0 ..< iterations {
      _ = id1 == id2
      _ = id1 == id3
    }
    let duration = start.duration(to: .now)

    // Should be very fast - under 50ms for 200k comparisons
    XCTAssertTrue(duration < .milliseconds(50))
  }

  func testtestDictionaryOperationsPerformance() async throws {
    var dict: [LockmanStrategyId: Int] = [:]
    let iterations = 1000

    // Create IDs
    let ids = (0 ..< iterations).map { LockmanStrategyId("Strategy\($0)") }

    // Measure insertions
    let insertStart = ContinuousClock.now
    for (index, id) in ids.enumerated() {
      dict[id] = index
    }
    let insertDuration = insertStart.duration(to: .now)

    // Measure lookups
    let lookupStart = ContinuousClock.now
    for id in ids {
      _ = dict[id]
    }
    let lookupDuration = lookupStart.duration(to: .now)

    // Should be fast
    XCTAssertTrue(insertDuration < .milliseconds(10))
    XCTAssertTrue(lookupDuration < .milliseconds(5))
  }
}
