import Foundation

// MARK: - LockmanCompositeStrategy2

/// A composite strategy that coordinates locking between 2 different strategies.
///
/// Ensures all component strategies can acquire their locks before proceeding.
/// If any strategy fails, the entire composite operation fails.
public final class LockmanCompositeStrategy2<
  I1: LockmanInfo, S1: LockmanStrategy,
  I2: LockmanInfo, S2: LockmanStrategy
>: LockmanStrategy, @unchecked Sendable
where S1.I == I1, S2.I == I2 {
  public typealias I = LockmanCompositeInfo2<I1, I2>

  /// The first strategy in the composite.
  private let strategy1: S1

  /// The second strategy in the composite.
  private let strategy2: S2

  /// The identifier for this composite strategy.
  public let strategyId: LockmanStrategyId

  /// Creates a new composite strategy with two component strategies.
  ///
  /// - Parameters:
  ///   - strategy1: The first strategy to coordinate with
  ///   - strategy2: The second strategy to coordinate with
  public init(strategy1: S1, strategy2: S2) {
    self.strategy1 = strategy1
    self.strategy2 = strategy2
    self.strategyId = Self.makeStrategyId(strategy1: strategy1, strategy2: strategy2)
  }

  /// Creates a strategy identifier for the composite strategy.
  ///
  /// This method generates a composite strategy ID based on the component strategies.
  /// The resulting ID includes both the composite type and the component strategy IDs.
  ///
  /// - Parameters:
  ///   - strategy1: The first component strategy
  ///   - strategy2: The second component strategy
  /// - Returns: A `LockmanStrategyId` that uniquely identifies this composite configuration
  public static func makeStrategyId(strategy1: S1, strategy2: S2) -> LockmanStrategyId {
    LockmanStrategyId(
      name: "CompositeStrategy2",
      configuration: "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  ///
  /// This parameterless version is required by the protocol but returns a generic
  /// identifier. For actual use, prefer the parameterized version.
  ///
  /// - Returns: A generic `LockmanStrategyId` for composite strategies
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy2")
  }

  /// Checks if locks can be acquired from all component strategies.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for both strategies
  /// - Returns: `.success` if all strategies can acquire locks, `.cancel` if any strategy fails,
  ///   or `.successWithPrecedingCancellation` if locks can be acquired but with prior cancellations
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) -> LockmanResult {
    // Early return pattern for performance optimization
    let result1 = strategy1.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    if case .cancel(let error) = result1 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy1 failed"
      )
      return result
    }

    let result2 = strategy2.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    if case .cancel(let error) = result2 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy2 failed"
      )
      return result
    }

    // Coordinate successful results
    let result = coordinateResults(result1, result2)
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: nil
    )

    return result
  }

  /// Acquires locks from all component strategies in the specified order.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// All strategies will acquire their locks in the order they were specified.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for both strategies
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) {
    strategy1.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    strategy2.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
  }

  /// Releases locks from all component strategies in reverse order (LIFO).
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for both strategies
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) {
    // Release in reverse order (LIFO)
    strategy2.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
  }

  /// Performs cleanup operations on all component strategies.
  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
  }

  /// Performs cleanup operations on all component strategies for a specific boundary.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    strategy1.cleanUp(boundaryId: boundaryId)
    strategy2.cleanUp(boundaryId: boundaryId)
  }

  /// Returns current locks information from all component strategies for debugging.
  ///
  /// This method merges lock information from all component strategies.
  ///
  /// - Returns: A dictionary mapping boundary IDs to arrays of lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Merge locks from all strategies
    let locks1 = strategy1.getCurrentLocks()
    let locks2 = strategy2.getCurrentLocks()

    for (boundaryId, lockInfos) in locks1 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks2 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    return result
  }

  // MARK: - Private Helpers

  /// Coordinates the results from multiple strategies according to composite logic.
  ///
  /// - Parameters:
  ///   - results: Variable number of `LockmanResult` values from component strategies
  /// - Returns: The coordinated result following composite strategy rules
  private func coordinateResults(_ results: LockmanResult...) -> LockmanResult {
    var cancellationError: (any LockmanPrecedingCancellationError)?

    // If any strategy failed, the entire operation fails
    // Return the first failure with its error
    for result in results {
      if case .cancel(let error) = result {
        return .cancel(error)
      }
      // Capture the first cancellation error we encounter
      if case .successWithPrecedingCancellation(let error) = result, cancellationError == nil {
        cancellationError = error
      }
    }

    // If all strategies succeeded without cancellation, operation succeeds
    if results.allSuccessful {
      return .success
    }

    // If any strategy requires cancellation, the operation requires cancellation
    // Use the first cancellation error we found
    if let error = cancellationError {
      return .successWithPrecedingCancellation(error: error)
    }

    // This shouldn't happen if the enum is properly handled
    fatalError("Unexpected state: successWithPrecedingCancellation expected but no error found")
  }
}

// MARK: - LockmanCompositeStrategy3

/// A composite strategy that coordinates locking between 3 different strategies.
public final class LockmanCompositeStrategy3<
  I1: LockmanInfo, S1: LockmanStrategy,
  I2: LockmanInfo, S2: LockmanStrategy,
  I3: LockmanInfo, S3: LockmanStrategy
>: LockmanStrategy, @unchecked Sendable
where S1.I == I1, S2.I == I2, S3.I == I3 {
  public typealias I = LockmanCompositeInfo3<I1, I2, I3>

  private let strategy1: S1
  private let strategy2: S2
  private let strategy3: S3

  /// The identifier for this composite strategy.
  public let strategyId: LockmanStrategyId

  /// Creates a new composite strategy with three component strategies.
  public init(strategy1: S1, strategy2: S2, strategy3: S3) {
    self.strategy1 = strategy1
    self.strategy2 = strategy2
    self.strategy3 = strategy3
    self.strategyId = Self.makeStrategyId(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)
  }

  /// Creates a strategy identifier for the composite strategy.
  ///
  /// - Parameters:
  ///   - strategy1: The first component strategy
  ///   - strategy2: The second component strategy
  ///   - strategy3: The third component strategy
  /// - Returns: A `LockmanStrategyId` that uniquely identifies this composite configuration
  public static func makeStrategyId(strategy1: S1, strategy2: S2, strategy3: S3)
    -> LockmanStrategyId
  {
    LockmanStrategyId(
      name: "CompositeStrategy3",
      configuration:
        "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  ///
  /// - Returns: A generic `LockmanStrategyId` for composite strategies
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy3")
  }

  /// Checks if locks can be acquired from all component strategies.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all three strategies
  /// - Returns: `.success` if all strategies can acquire locks, `.cancel` if any strategy fails,
  ///   or `.successWithPrecedingCancellation` if locks can be acquired but with prior cancellations
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) -> LockmanResult {
    // Early return pattern for performance optimization
    let result1 = strategy1.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    if case .cancel(let error) = result1 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy1 failed"
      )
      return result
    }

    let result2 = strategy2.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    if case .cancel(let error) = result2 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy2 failed"
      )
      return result
    }

    let result3 = strategy3.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    if case .cancel(let error) = result3 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy3 failed"
      )
      return result
    }

    // Coordinate successful results
    let result = coordinateResults(result1, result2, result3)
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: nil
    )

    return result
  }

  /// Acquires locks from all component strategies in the specified order.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// All strategies will acquire their locks in the order they were specified.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) {
    strategy1.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    strategy2.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy3.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
  }

  /// Releases locks from all component strategies in reverse order (LIFO).
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) {
    // Release in reverse order (LIFO)
    strategy3.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
  }

  /// Performs cleanup operations on all component strategies.
  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
  }

  /// Performs cleanup operations on all component strategies for a specific boundary.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    strategy1.cleanUp(boundaryId: boundaryId)
    strategy2.cleanUp(boundaryId: boundaryId)
    strategy3.cleanUp(boundaryId: boundaryId)
  }

  /// Returns current locks information from all component strategies for debugging.
  ///
  /// This method merges lock information from all component strategies.
  ///
  /// - Returns: A dictionary mapping boundary IDs to arrays of lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Merge locks from all strategies
    let locks1 = strategy1.getCurrentLocks()
    let locks2 = strategy2.getCurrentLocks()
    let locks3 = strategy3.getCurrentLocks()

    for (boundaryId, lockInfos) in locks1 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks2 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks3 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    return result
  }

  // MARK: - Private Helpers

  private func coordinateResults(_ results: LockmanResult...) -> LockmanResult {
    var cancellationError: (any LockmanPrecedingCancellationError)?

    // If any strategy failed, return the first failure with its error
    for result in results {
      if case .cancel(let error) = result {
        return .cancel(error)
      }
      // Capture the first cancellation error we encounter
      if case .successWithPrecedingCancellation(let error) = result, cancellationError == nil {
        cancellationError = error
      }
    }

    if results.allSuccessful {
      return .success
    }

    // If any strategy requires cancellation, use the first cancellation error
    // At this point, we know at least one result is not .success, so it must be
    // .successWithPrecedingCancellation, which means cancellationError is set
    return .successWithPrecedingCancellation(error: cancellationError!)
  }
}

// MARK: - LockmanCompositeStrategy4

/// A composite strategy that coordinates locking between 4 different strategies.
public final class LockmanCompositeStrategy4<
  I1: LockmanInfo, S1: LockmanStrategy,
  I2: LockmanInfo, S2: LockmanStrategy,
  I3: LockmanInfo, S3: LockmanStrategy,
  I4: LockmanInfo, S4: LockmanStrategy
>: LockmanStrategy, @unchecked Sendable
where S1.I == I1, S2.I == I2, S3.I == I3, S4.I == I4 {
  public typealias I = LockmanCompositeInfo4<I1, I2, I3, I4>

  private let strategy1: S1
  private let strategy2: S2
  private let strategy3: S3
  private let strategy4: S4

  /// The identifier for this composite strategy.
  public let strategyId: LockmanStrategyId

  public init(strategy1: S1, strategy2: S2, strategy3: S3, strategy4: S4) {
    self.strategy1 = strategy1
    self.strategy2 = strategy2
    self.strategy3 = strategy3
    self.strategy4 = strategy4
    self.strategyId = Self.makeStrategyId(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4)
  }

  /// Creates a strategy identifier for the composite strategy.
  public static func makeStrategyId(strategy1: S1, strategy2: S2, strategy3: S3, strategy4: S4)
    -> LockmanStrategyId
  {
    LockmanStrategyId(
      name: "CompositeStrategy4",
      configuration:
        "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)+\(strategy4.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy4")
  }

  /// Checks if locks can be acquired from all component strategies.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  /// - Returns: `.success` if all strategies can acquire locks, `.cancel` if any strategy fails,
  ///   or `.successWithPrecedingCancellation` if locks can be acquired but with prior cancellations
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) -> LockmanResult {
    // Early return pattern for performance optimization
    let result1 = strategy1.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    if case .cancel(let error) = result1 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy1 failed"
      )
      return result
    }

    let result2 = strategy2.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    if case .cancel(let error) = result2 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy2 failed"
      )
      return result
    }

    let result3 = strategy3.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    if case .cancel(let error) = result3 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy3 failed"
      )
      return result
    }

    let result4 = strategy4.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
    if case .cancel(let error) = result4 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy4 failed"
      )
      return result
    }

    // Coordinate successful results
    let result = coordinateResults(result1, result2, result3, result4)
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: nil
    )

    return result
  }

  /// Acquires locks from all component strategies in the specified order.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// All strategies will acquire their locks in the order they were specified.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) {
    strategy1.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    strategy2.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy3.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    strategy4.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
  }

  /// Releases locks from all component strategies in reverse order (LIFO).
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) {
    // Release in reverse order (LIFO)
    strategy4.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
    strategy3.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
  }

  /// Performs cleanup operations on all component strategies.
  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
    strategy4.cleanUp()
  }

  /// Performs cleanup operations on all component strategies for a specific boundary.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    strategy1.cleanUp(boundaryId: boundaryId)
    strategy2.cleanUp(boundaryId: boundaryId)
    strategy3.cleanUp(boundaryId: boundaryId)
    strategy4.cleanUp(boundaryId: boundaryId)
  }

  /// Returns current locks information from all component strategies for debugging.
  ///
  /// This method merges lock information from all component strategies.
  ///
  /// - Returns: A dictionary mapping boundary IDs to arrays of lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Merge locks from all strategies
    let locks1 = strategy1.getCurrentLocks()
    let locks2 = strategy2.getCurrentLocks()
    let locks3 = strategy3.getCurrentLocks()
    let locks4 = strategy4.getCurrentLocks()

    for (boundaryId, lockInfos) in locks1 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks2 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks3 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks4 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    return result
  }

  // MARK: - Private Helpers

  private func coordinateResults(_ results: LockmanResult...) -> LockmanResult {
    var cancellationError: (any LockmanPrecedingCancellationError)?

    // If any strategy failed, return the first failure with its error
    for result in results {
      if case .cancel(let error) = result {
        return .cancel(error)
      }
      // Capture the first cancellation error we encounter
      if case .successWithPrecedingCancellation(let error) = result, cancellationError == nil {
        cancellationError = error
      }
    }

    if results.allSuccessful {
      return .success
    }

    // If any strategy requires cancellation, use the first cancellation error
    // At this point, we know at least one result is not .success, so it must be
    // .successWithPrecedingCancellation, which means cancellationError is set
    return .successWithPrecedingCancellation(error: cancellationError!)
  }
}

// MARK: - LockmanCompositeStrategy5

/// A composite strategy that coordinates locking between 5 different strategies.
public final class LockmanCompositeStrategy5<
  I1: LockmanInfo, S1: LockmanStrategy,
  I2: LockmanInfo, S2: LockmanStrategy,
  I3: LockmanInfo, S3: LockmanStrategy,
  I4: LockmanInfo, S4: LockmanStrategy,
  I5: LockmanInfo, S5: LockmanStrategy
>: LockmanStrategy, @unchecked Sendable
where S1.I == I1, S2.I == I2, S3.I == I3, S4.I == I4, S5.I == I5 {
  public typealias I = LockmanCompositeInfo5<I1, I2, I3, I4, I5>

  private let strategy1: S1
  private let strategy2: S2
  private let strategy3: S3
  private let strategy4: S4
  private let strategy5: S5

  /// The identifier for this composite strategy.
  public let strategyId: LockmanStrategyId

  public init(
    strategy1: S1,
    strategy2: S2,
    strategy3: S3,
    strategy4: S4,
    strategy5: S5
  ) {
    self.strategy1 = strategy1
    self.strategy2 = strategy2
    self.strategy3 = strategy3
    self.strategy4 = strategy4
    self.strategy5 = strategy5
    self.strategyId = Self.makeStrategyId(
      strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4,
      strategy5: strategy5)
  }

  /// Creates a strategy identifier for the composite strategy.
  public static func makeStrategyId(
    strategy1: S1, strategy2: S2, strategy3: S3, strategy4: S4, strategy5: S5
  ) -> LockmanStrategyId {
    LockmanStrategyId(
      name: "CompositeStrategy5",
      configuration:
        "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)+\(strategy4.strategyId.value)+\(strategy5.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy5")
  }

  /// Checks if locks can be acquired from all component strategies.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  /// - Returns: `.success` if all strategies can acquire locks, `.cancel` if any strategy fails,
  ///   or `.successWithPrecedingCancellation` if locks can be acquired but with prior cancellations
  public func canLock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) -> LockmanResult {
    // Early return pattern for performance optimization
    let result1 = strategy1.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    if case .cancel(let error) = result1 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy1 failed"
      )
      return result
    }

    let result2 = strategy2.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    if case .cancel(let error) = result2 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy2 failed"
      )
      return result
    }

    let result3 = strategy3.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    if case .cancel(let error) = result3 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy3 failed"
      )
      return result
    }

    let result4 = strategy4.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
    if case .cancel(let error) = result4 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy4 failed"
      )
      return result
    }

    let result5 = strategy5.canLock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy5)
    if case .cancel(let error) = result5 {
      let result = LockmanResult.cancel(error)
      LockmanLogger.shared.logCanLock(
        result: result,
        strategy: "Composite",
        boundaryId: String(describing: boundaryId),
        info: info,
        reason: "Strategy5 failed"
      )
      return result
    }

    // Coordinate successful results
    let result = coordinateResults(result1, result2, result3, result4, result5)
    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: boundaryId),
      info: info,
      reason: nil
    )

    return result
  }

  /// Acquires locks from all component strategies in the specified order.
  ///
  /// This method should only be called after `canLock` returns a success result.
  /// All strategies will acquire their locks in the order they were specified.
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func lock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) {
    strategy1.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
    strategy2.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy3.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    strategy4.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
    strategy5.lock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy5)
  }

  /// Releases locks from all component strategies in reverse order (LIFO).
  ///
  /// - Parameters:
  ///   - boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for all strategies
  public func unlock<B: LockmanBoundaryId>(
    boundaryId: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) {
    // Release in reverse order (LIFO)
    strategy5.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy5)
    strategy4.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy4)
    strategy3.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(boundaryId: boundaryId, info: info.lockmanInfoForStrategy1)
  }

  /// Performs cleanup operations on all component strategies.
  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
    strategy4.cleanUp()
    strategy5.cleanUp()
  }

  /// Performs cleanup operations on all component strategies for a specific boundary.
  ///
  /// - Parameter boundaryId: A unique boundary identifier conforming to `LockmanBoundaryId`
  public func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
    strategy1.cleanUp(boundaryId: boundaryId)
    strategy2.cleanUp(boundaryId: boundaryId)
    strategy3.cleanUp(boundaryId: boundaryId)
    strategy4.cleanUp(boundaryId: boundaryId)
    strategy5.cleanUp(boundaryId: boundaryId)
  }

  /// Returns current locks information from all component strategies for debugging.
  ///
  /// This method merges lock information from all component strategies.
  ///
  /// - Returns: A dictionary mapping boundary IDs to arrays of lock information
  public func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
    var result: [AnyLockmanBoundaryId: [any LockmanInfo]] = [:]

    // Merge locks from all strategies
    let locks1 = strategy1.getCurrentLocks()
    let locks2 = strategy2.getCurrentLocks()
    let locks3 = strategy3.getCurrentLocks()
    let locks4 = strategy4.getCurrentLocks()
    let locks5 = strategy5.getCurrentLocks()

    for (boundaryId, lockInfos) in locks1 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks2 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks3 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks4 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    for (boundaryId, lockInfos) in locks5 {
      result[boundaryId, default: []].append(contentsOf: lockInfos)
    }

    return result
  }

  // MARK: - Private Helpers

  private func coordinateResults(_ results: LockmanResult...) -> LockmanResult {
    var cancellationError: (any LockmanPrecedingCancellationError)?

    // If any strategy failed, return the first failure with its error
    for result in results {
      if case .cancel(let error) = result {
        return .cancel(error)
      }
      // Capture the first cancellation error we encounter
      if case .successWithPrecedingCancellation(let error) = result, cancellationError == nil {
        cancellationError = error
      }
    }

    if results.allSuccessful {
      return .success
    }

    // If any strategy requires cancellation, use the first cancellation error
    // At this point, we know at least one result is not .success, so it must be
    // .successWithPrecedingCancellation, which means cancellationError is set
    return .successWithPrecedingCancellation(error: cancellationError!)
  }
}

// MARK: - Private Extensions

private extension Array where Element == LockmanResult {
  /// Returns true if all results are .success
  var allSuccessful: Bool {
    return allSatisfy { result in
      if case .success = result { return true }
      return false
    }
  }
}
