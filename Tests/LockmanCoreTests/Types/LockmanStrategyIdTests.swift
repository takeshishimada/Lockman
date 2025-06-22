import XCTest

@testable import LockmanCore

final class LockmanStrategyIdTests: XCTestCase {
  // MARK: - Basic Initialization Tests

  func testInitializeWithString() {
    let id = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id.value, "MyStrategy")
    XCTAssertEqual(id.description, "MyStrategy")
  }

  func testInitializeWithType() {
    let id = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    XCTAssertTrue(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  func testInitializeWithTypeAndIdentifier() {
    let id = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self,
      identifier: "custom-id"
    )
    XCTAssertEqual(id.value, "custom-id")
  }

  func testInitializeWithName() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy"
    )
    XCTAssertEqual(id.value, "RateLimitStrategy")
  }

  func testInitializeWithNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy",
      configuration: "limit-100"
    )
    XCTAssertEqual(id.value, "RateLimitStrategy:limit-100")
  }

  // MARK: - ExpressibleByStringLiteral Tests

  func testStringLiteralInitialization() {
    let id: LockmanStrategyId = "MyApp.CustomStrategy"
    XCTAssertEqual(id.value, "MyApp.CustomStrategy")
  }

  // MARK: - Factory Method Tests

  func testFactoryMethodFromType() {
    let id = LockmanStrategyId.from(LockmanPriorityBasedStrategy.self)
    XCTAssertTrue(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  func testFactoryMethodFromTypeWithIdentifier() {
    let id = LockmanStrategyId.from(
      LockmanPriorityBasedStrategy.self,
      identifier: "priority-custom"
    )
    XCTAssertEqual(id.value, "priority-custom")
  }

  // MARK: - Static Property Tests

  func testStaticSingleExecutionProperty() {
    let id = LockmanStrategyId.singleExecution
    XCTAssertTrue(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  func testStaticPriorityBasedProperty() {
    let id = LockmanStrategyId.priorityBased
    XCTAssertTrue(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  // MARK: - Equality and Hashing Tests

  func testEqualityWithSameValue() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id1, id2)
  }

  func testInequalityWithDifferentValues() {
    let id1 = LockmanStrategyId("Strategy1")
    let id2 = LockmanStrategyId("Strategy2")
    XCTAssertNotEqual(id1, id2)
  }

  func testHashConsistency() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    XCTAssertEqual(id1.hashValue, id2.hashValue)
  }

  func testUseAsDictionaryKey() {
    var dict: [LockmanStrategyId: String] = [:]
    let id = LockmanStrategyId("TestStrategy")
    dict[id] = "value"
    XCTAssertEqual(dict[id], "value")
  }

  // MARK: - Edge Case Tests

  func testEmptyStringId() {
    let id = LockmanStrategyId("")
    XCTAssertEqual(id.value, "")
  }

  func testUnicodeStringId() {
    let id = LockmanStrategyId("策略🎯")
    XCTAssertEqual(id.value, "策略🎯")
  }

  func testVeryLongStringId() {
    let longString = String(repeating: "a", count: 1000)
    let id = LockmanStrategyId(longString)
    XCTAssertEqual(id.value, longString)
    XCTAssertEqual(id.value.count, 1000)
  }

  func testSpecialCharactersInNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "Rate_Limit_Strategy",
      configuration: "limit:100/timeout:30"
    )
    XCTAssertEqual(id.value, "Rate_Limit_Strategy:limit:100/timeout:30")
  }

  // MARK: - Sendable Conformance Tests

  func testSendableAcrossConcurrentContexts() async {
    let id = LockmanStrategyId("ConcurrentStrategy")

    await withTaskGroup(of: String.self) { group in
      for _ in 0..<10 {
        group.addTask {
          // Access the id from concurrent context
          id.value
        }
      }

      for await value in group {
        XCTAssertEqual(value, "ConcurrentStrategy")
      }
    }
  }

  // MARK: - Real-World Usage Pattern Tests

  func testConfigurationVariantsOfSameStrategy() {
    let timeout30 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-30"
    )
    let timeout60 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-60"
    )

    XCTAssertNotEqual(timeout30, timeout60)
    XCTAssertEqual(timeout30.value, "CacheStrategy:timeout-30")
    XCTAssertEqual(timeout60.value, "CacheStrategy:timeout-60")
  }

  func testDifferentStrategyNames() {
    let appStrategy = LockmanStrategyId(
      name: "AppUserStrategy"
    )
    let libraryStrategy = LockmanStrategyId(
      name: "LibUserStrategy"
    )

    XCTAssertNotEqual(appStrategy, libraryStrategy)
    XCTAssertEqual(appStrategy.value, "AppUserStrategy")
    XCTAssertEqual(libraryStrategy.value, "LibUserStrategy")
  }
}

// MARK: - Performance Tests

final class LockmanStrategyIdPerformanceTests: XCTestCase {
  func testCreationPerformance() async {
    let iterations = 10000

    let start = Date()
    for i in 0..<iterations {
      _ = LockmanStrategyId("Strategy\(i)")
    }
    let duration = Date().timeIntervalSince(start)

    // Should be very fast - under 100ms for 10k creations
    XCTAssertLessThan(duration, 100.0 / 1000.0)
  }

  func testEqualityComparisonPerformance() async {
    let id1 = LockmanStrategyId("TestStrategy")
    let id2 = LockmanStrategyId("TestStrategy")
    let id3 = LockmanStrategyId("DifferentStrategy")
    let iterations = 100000

    let start = Date()
    for _ in 0..<iterations {
      _ = id1 == id2
      _ = id1 == id3
    }
    let duration = Date().timeIntervalSince(start)

    // Should be very fast - under 100ms for 200k comparisons (increased for CI stability)
    XCTAssertLessThan(duration, 100.0 / 1000.0)
  }

  func testDictionaryOperationsPerformance() async {
    var dict: [LockmanStrategyId: Int] = [:]
    let iterations = 1000

    // Create IDs
    let ids = (0..<iterations).map { LockmanStrategyId("Strategy\($0)") }

    // Measure insertions
    let insertStart = Date()
    for (index, id) in ids.enumerated() {
      dict[id] = index
    }
    let insertDuration = Date().timeIntervalSince(insertStart)

    // Measure lookups
    let lookupStart = Date()
    for id in ids {
      _ = dict[id]
    }
    let lookupDuration = Date().timeIntervalSince(lookupStart)

    // Should be fast (converting milliseconds to seconds)
    XCTAssertLessThan(insertDuration, 0.01)  // 10ms
    XCTAssertLessThan(lookupDuration, 0.005)  // 5ms
  }
}
