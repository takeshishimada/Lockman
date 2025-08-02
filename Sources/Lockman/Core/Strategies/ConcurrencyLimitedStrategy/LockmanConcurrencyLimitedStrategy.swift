import Foundation

/// Strategy that limits the number of concurrent executions per concurrency group.
public final class LockmanConcurrencyLimitedStrategy: LockmanStrategy, @unchecked Sendable {
  /// The type of lock info used by this strategy.
  public typealias I = LockmanConcurrencyLimitedInfo

  /// Shared instance of the strategy.
  public static let shared = LockmanConcurrencyLimitedStrategy()

  /// The strategy identifier.
  public let strategyId: LockmanStrategyId

  /// Creates the strategy identifier.
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "concurrencyLimited")
  }

  /// Thread-safe state management.
  /// Uses concurrencyId as the key for indexing locks.
  private let state = LockmanState<LockmanConcurrencyLimitedInfo, String>(
    keyExtractor: { $0.concurrencyId }
  )

  /// Private initializer to ensure singleton usage.
  private init() {
    self.strategyId = Self.makeStrategyId()
  }

  /// Checks if a lock can be acquired based on concurrency limits.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Concurrency limited lock information containing concurrency group and limit details
  /// - Returns: `.success` if the lock can be acquired, `.cancel` if concurrency limit is exceeded
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) -> LockmanResult {
    // Use the key-based query for efficient lookup
    let currentCount = state.activeLockCount(in: boundaryId, matching: info.concurrencyId)

    let result: LockmanResult
    var failureReason: String?

    if info.limit.isExceeded(currentCount: currentCount) {
      if case .limited(let limit) = info.limit {
        result = .cancel(
          LockmanConcurrencyLimitedError.concurrencyLimitReached(
            lockmanInfo: info,
            boundaryId: boundaryId,
            currentCount: currentCount
          )
        )
        failureReason =
          "Concurrency limit exceeded for '\(info.concurrencyId)': \(currentCount)/\(limit)"
      } else {
        result = .success
      }
    } else {
      result = .success
    }

    // Log the result
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "ConcurrencyLimited",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: failureReason
    )

    return result
  }

  /// Acquires a lock by adding it to the concurrency tracking state.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// The lock will be tracked within the specified concurrency group.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Concurrency limited lock information containing concurrency group and limit details
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) {
    state.add(boundaryId: boundaryId, info: info)
  }

  /// Releases a lock by removing it from the concurrency tracking state.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Concurrency limited lock information containing concurrency group and limit details
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) {
    state.remove(boundaryId: boundaryId, info: info)
  }

  /// Removes all locks for a specific boundary across all concurrency groups.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(
    boundaryId: B
  ) {
    state.removeAll(boundaryId: boundaryId)
  }

  /// Removes all locks across all boundaries and concurrency groups.
  public func cleanUp() {
    state.removeAll()
  }

  /// Returns current locks information for debugging purposes.
  ///
  /// - Returns: A dictionary mapping boundary identifiers to their associated lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Get all boundaries and their locks from the state
    let allLocks = state.allActiveLocks()

    for (boundaryId, lockInfos) in allLocks {
      result[boundaryId] = lockInfos.map { $0 as any LockmanInfo }
    }

    return result
  }
}
