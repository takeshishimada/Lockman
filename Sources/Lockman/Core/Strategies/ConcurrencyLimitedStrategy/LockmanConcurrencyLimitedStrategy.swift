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
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) -> LockmanResult {
    // Use the key-based query for efficient lookup
    let currentCount = state.count(id: boundaryId, key: info.concurrencyId)

    let result: LockmanResult
    var failureReason: String?

    if info.limit.isExceeded(currentCount: currentCount) {
      if case .limited(let limit) = info.limit {
        // Get existing infos in the same concurrency group
        let existingInfos = state.currents(id: boundaryId, key: info.concurrencyId)

        result = .cancel(
          LockmanConcurrencyLimitedCancellationError(
            cancelledInfo: info,
            boundaryId: boundaryId,
            existingInfos: existingInfos,
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

  /// Adds the lock to the state.
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) {
    state.add(id: boundaryId, info: info)
  }

  /// Removes the lock from the state.
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanConcurrencyLimitedInfo
  ) {
    state.remove(id: boundaryId, info: info)
  }

  /// Removes all locks for a specific boundary.
  public func cleanUp<B: LockmanBoundaryId>(
    boundaryId: B
  ) {
    // Get all locks for this boundary and remove them one by one
    let currentLocks = state.currents(id: boundaryId)
    for info in currentLocks {
      state.remove(id: boundaryId, info: info)
    }
  }

  /// Removes all locks across all boundaries.
  public func cleanUp() {
    state.removeAll()
  }

  /// Returns current locks information for debugging purposes.
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Get all boundaries and their locks from the state
    let allLocks = state.getAllLocks()

    for (boundaryId, lockInfos) in allLocks {
      result[boundaryId] = lockInfos.map { $0 as any LockmanInfo }
    }

    return result
  }
}
