import Testing
@testable import LockmanCore

@Suite("LockmanStrategyId Tests")
struct LockmanStrategyIdTests {
  // MARK: - Basic Initialization Tests

  @Test("Initialize with string value")
  func testInitializeWithString() {
    let id = LockmanStrategyId("MyStrategy")
    #expect(id.value == "MyStrategy")
    #expect(id.description == "MyStrategy")
  }

  @Test("Initialize with type")
  func testInitializeWithType() {
    let id = LockmanStrategyId(type: LockmanSingleExecutionStrategy.self)
    #expect(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  @Test("Initialize with type and custom identifier")
  func testInitializeWithTypeAndIdentifier() {
    let id = LockmanStrategyId(
      type: LockmanSingleExecutionStrategy.self,
      identifier: "custom-id"
    )
    #expect(id.value == "custom-id")
  }

  @Test("Initialize with name")
  func testInitializeWithName() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy"
    )
    #expect(id.value == "RateLimitStrategy")
  }

  @Test("Initialize with name and configuration")
  func testInitializeWithNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "RateLimitStrategy",
      configuration: "limit-100"
    )
    #expect(id.value == "RateLimitStrategy:limit-100")
  }

  // MARK: - ExpressibleByStringLiteral Tests

  @Test("String literal initialization")
  func testStringLiteralInitialization() {
    let id: LockmanStrategyId = "MyApp.CustomStrategy"
    #expect(id.value == "MyApp.CustomStrategy")
  }

  // MARK: - Factory Method Tests

  @Test("Factory method from type")
  func testFactoryMethodFromType() {
    let id = LockmanStrategyId.from(LockmanPriorityBasedStrategy.self)
    #expect(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  @Test("Factory method from type with identifier")
  func testFactoryMethodFromTypeWithIdentifier() {
    let id = LockmanStrategyId.from(
      LockmanPriorityBasedStrategy.self,
      identifier: "priority-custom"
    )
    #expect(id.value == "priority-custom")
  }

  // MARK: - Static Property Tests

  @Test("Static singleExecution property")
  func testStaticSingleExecutionProperty() {
    let id = LockmanStrategyId.singleExecution
    #expect(id.value.contains("LockmanSingleExecutionStrategy"))
  }

  @Test("Static priorityBased property")
  func testStaticPriorityBasedProperty() {
    let id = LockmanStrategyId.priorityBased
    #expect(id.value.contains("LockmanPriorityBasedStrategy"))
  }

  // MARK: - Equality and Hashing Tests

  @Test("Equality with same value")
  func testEqualityWithSameValue() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    #expect(id1 == id2)
  }

  @Test("Inequality with different values")
  func testInequalityWithDifferentValues() {
    let id1 = LockmanStrategyId("Strategy1")
    let id2 = LockmanStrategyId("Strategy2")
    #expect(id1 != id2)
  }

  @Test("Hash consistency")
  func testHashConsistency() {
    let id1 = LockmanStrategyId("MyStrategy")
    let id2 = LockmanStrategyId("MyStrategy")
    #expect(id1.hashValue == id2.hashValue)
  }

  @Test("Use as dictionary key")
  func testUseAsDictionaryKey() {
    var dict: [LockmanStrategyId: String] = [:]
    let id = LockmanStrategyId("TestStrategy")
    dict[id] = "value"
    #expect(dict[id] == "value")
  }

  // MARK: - Edge Case Tests

  @Test("Empty string ID")
  func testEmptyStringId() {
    let id = LockmanStrategyId("")
    #expect(id.value == "")
  }

  @Test("Unicode string ID")
  func testUnicodeStringId() {
    let id = LockmanStrategyId("策略🎯")
    #expect(id.value == "策略🎯")
  }

  @Test("Very long string ID")
  func testVeryLongStringId() {
    let longString = String(repeating: "a", count: 1000)
    let id = LockmanStrategyId(longString)
    #expect(id.value == longString)
    #expect(id.value.count == 1000)
  }

  @Test("Special characters in name and configuration")
  func testSpecialCharactersInNameAndConfiguration() {
    let id = LockmanStrategyId(
      name: "Rate_Limit_Strategy",
      configuration: "limit:100/timeout:30"
    )
    #expect(id.value == "Rate_Limit_Strategy:limit:100/timeout:30")
  }

  // MARK: - Sendable Conformance Tests

  @Test("Sendable across concurrent contexts")
  func testSendableAcrossConcurrentContexts() async {
    let id = LockmanStrategyId("ConcurrentStrategy")

    await withTaskGroup(of: String.self) { group in
      for _ in 0 ..< 10 {
        group.addTask {
          // Access the id from concurrent context
          id.value
        }
      }

      for await value in group {
        #expect(value == "ConcurrentStrategy")
      }
    }
  }

  // MARK: - Real-World Usage Pattern Tests

  @Test("Configuration variants of same strategy")
  func testConfigurationVariantsOfSameStrategy() {
    let timeout30 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-30"
    )
    let timeout60 = LockmanStrategyId(
      name: "CacheStrategy",
      configuration: "timeout-60"
    )

    #expect(timeout30 != timeout60)
    #expect(timeout30.value == "CacheStrategy:timeout-30")
    #expect(timeout60.value == "CacheStrategy:timeout-60")
  }

  @Test("Different strategy names")
  func testDifferentStrategyNames() {
    let appStrategy = LockmanStrategyId(
      name: "AppUserStrategy"
    )
    let libraryStrategy = LockmanStrategyId(
      name: "LibUserStrategy"
    )

    #expect(appStrategy != libraryStrategy)
    #expect(appStrategy.value == "AppUserStrategy")
    #expect(libraryStrategy.value == "LibUserStrategy")
  }
}

// MARK: - Performance Tests

@Suite("LockmanStrategyId Performance Tests")
struct LockmanStrategyIdPerformanceTests {
  @Test("Creation performance")
  func testCreationPerformance() async {
    let iterations = 10000

    let start = ContinuousClock.now
    for i in 0 ..< iterations {
      _ = LockmanStrategyId("Strategy\(i)")
    }
    let duration = start.duration(to: .now)

    // Should be very fast - under 100ms for 10k creations
    #expect(duration < .milliseconds(100))
  }

  @Test("Equality comparison performance")
  func testEqualityComparisonPerformance() async {
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
    #expect(duration < .milliseconds(50))
  }

  @Test("Dictionary operations performance")
  func testDictionaryOperationsPerformance() async {
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
    #expect(insertDuration < .milliseconds(10))
    #expect(lookupDuration < .milliseconds(5))
  }
}
