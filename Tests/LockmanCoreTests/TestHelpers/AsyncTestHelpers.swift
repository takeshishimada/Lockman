import Foundation
import Testing
@testable import LockmanCore

// MARK: - Async Test Helpers

/// Utilities for async testing patterns
enum AsyncTestHelpers {
  /// Run concurrent operations and collect results
  static func runConcurrentOperations<T: Sendable>(
    count: Int,
    operation: @escaping @Sendable (Int) async throws -> T
  ) async throws -> [T] {
    try await withThrowingTaskGroup(of: T.self) { group in
      for i in 0 ..< count {
        group.addTask {
          try await operation(i)
        }
      }

      var results: [T] = []
      for try await result in group {
        results.append(result)
      }
      return results
    }
  }

  /// Run concurrent operations without collecting results
  static func runConcurrentVoidOperations(
    count: Int,
    operation: @escaping @Sendable (Int) async throws -> Void
  ) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
      for i in 0 ..< count {
        group.addTask {
          try await operation(i)
        }
      }

      // Wait for all to complete
      for try await _ in group {}
    }
  }

  /// Assert that a condition eventually becomes true
  static func assertEventually(
    timeout: TimeInterval = 1.0,
    interval: TimeInterval = 0.01,
    condition: () async -> Bool,
    message: String? = nil
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
      if await condition() {
        return
      }
      try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
    }

    let failureMessage = message ?? "Condition did not become true within \(timeout) seconds"
    #expect(Bool(false), Comment(rawValue: failureMessage))
  }

  /// Wait for a specific duration
  static func wait(seconds: TimeInterval) async throws {
    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
  }

  /// Measure async operation performance
  static func measureAsyncPerformance<T>(
    iterations _: Int = 1,
    operation: () async throws -> T
  ) async throws -> (result: T, duration: TimeInterval) {
    let startTime = Date()
    let result = try await operation()
    let duration = Date().timeIntervalSince(startTime)
    return (result, duration)
  }

  /// Run operations with timeout
  static func withTimeout<T: Sendable>(
    _ timeout: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
  ) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }

      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        throw TimeoutError()
      }

      guard let result = try await group.next() else {
        throw TimeoutError()
      }

      group.cancelAll()
      return result
    }
  }
}

// MARK: - Timeout Error

struct TimeoutError: Error, LocalizedError {
  var errorDescription: String? {
    "Operation timed out"
  }
}

// MARK: - Test Container Helpers

extension Lockman {
  /// Execute test with isolated container and automatic cleanup
  static func withIsolatedTestContainer<T>(
    operation: () async throws -> T
  ) async rethrows -> T {
    let container = LockmanStrategyContainer()
    return try await withTestContainer(container) {
      try await operation()
    }
  }
}

// MARK: - Lock Test Helpers

/// Common lock testing patterns
enum LockTestHelpers {
  /// Perform a standard lock/unlock cycle
  static func performLockUnlockCycle<S: LockmanStrategy, B: LockmanBoundaryId>(
    strategy: S,
    boundaryId: B,
    info: S.I
  ) throws {
    let result = strategy.canLock(id: boundaryId, info: info)
    #expect(result == .success, "Should be able to acquire lock")

    strategy.lock(id: boundaryId, info: info)

    let lockedResult = strategy.canLock(id: boundaryId, info: info)
    #expect(lockedResult == .failure, "Should not be able to acquire locked resource")

    strategy.unlock(id: boundaryId, info: info)

    let unlockedResult = strategy.canLock(id: boundaryId, info: info)
    #expect(unlockedResult == .success, "Should be able to acquire after unlock")
  }

  /// Test concurrent lock attempts
  static func testConcurrentLockAttempts<S: LockmanStrategy, B: LockmanBoundaryId>(
    strategy: S,
    boundaryId: B,
    info: S.I,
    attempts: Int = 5
  ) async throws -> (successful: Int, failed: Int) {
    let results = try await AsyncTestHelpers.runConcurrentOperations(count: attempts) { _ in
      strategy.canLock(id: boundaryId, info: info)
    }

    let successful = results.filter { $0 != .failure }.count
    let failed = results.filter { $0 == .failure }.count

    return (successful, failed)
  }

  /// Verify lock state consistency
  static func verifyLockStateConsistency<S: LockmanStrategy, B: LockmanBoundaryId>(
    strategy: S,
    boundaryId: B,
    info: S.I,
    expectedLocked: Bool
  ) {
    let result = strategy.canLock(id: boundaryId, info: info)

    if expectedLocked {
      #expect(result == .failure, "Resource should be locked")
    } else {
      #expect(result == .success, "Resource should be unlocked")
    }
  }
}

// MARK: - Performance Test Helpers

/// Performance testing utilities
enum PerformanceTestHelpers {
  struct PerformanceResult {
    let totalDuration: TimeInterval
    let averageDuration: TimeInterval
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let iterations: Int
  }

  /// Measure performance of repeated operations
  static func measureRepeatedOperations<T>(
    iterations: Int,
    operation: () async throws -> T
  ) async throws -> PerformanceResult {
    var durations: [TimeInterval] = []
    let totalStart = Date()

    for _ in 0 ..< iterations {
      let (_, duration) = try await AsyncTestHelpers.measureAsyncPerformance {
        try await operation()
      }
      durations.append(duration)
    }

    let totalDuration = Date().timeIntervalSince(totalStart)
    let averageDuration = durations.reduce(0, +) / Double(iterations)
    let minDuration = durations.min() ?? 0
    let maxDuration = durations.max() ?? 0

    return PerformanceResult(
      totalDuration: totalDuration,
      averageDuration: averageDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      iterations: iterations
    )
  }

  /// Assert performance meets expectations
  static func assertPerformance(
    _ result: PerformanceResult,
    averageUnder: TimeInterval? = nil,
    totalUnder: TimeInterval? = nil,
    maxUnder: TimeInterval? = nil
  ) {
    if let averageThreshold = averageUnder {
      #expect(
        result.averageDuration < averageThreshold,
        "Average duration \(result.averageDuration) should be under \(averageThreshold)"
      )
    }

    if let totalThreshold = totalUnder {
      #expect(
        result.totalDuration < totalThreshold,
        "Total duration \(result.totalDuration) should be under \(totalThreshold)"
      )
    }

    if let maxThreshold = maxUnder {
      #expect(
        result.maxDuration < maxThreshold,
        "Max duration \(result.maxDuration) should be under \(maxThreshold)"
      )
    }
  }
}
