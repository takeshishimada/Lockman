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
  where S1.I == I1, S2.I == I2
{
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
  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) -> LockResult {
    let result1 = strategy1.canLock(id: id, info: info.lockmanInfoForStrategy1)
    let result2 = strategy2.canLock(id: id, info: info.lockmanInfoForStrategy2)

    let result = coordinateResults(result1, result2)

    let failureReason: String?
    if result == .failure {
      var failedStrategies: [String] = []
      if result1 == .failure {
        failedStrategies.append("Strategy1")
      }
      if result2 == .failure {
        failedStrategies.append("Strategy2")
      }
      failureReason = "Failed strategies: \(failedStrategies.joined(separator: ", "))"
    } else {
      failureReason = nil
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason
    )

    return result
  }

  ///
  /// This method should only be called after `canLock` returns a success result.
  /// All strategies will acquire their locks in the order they were specified.
  ///
  /// - Parameters:
  ///   - id: A unique boundary identifier conforming to `LockmanBoundaryId`
  ///   - info: Composite lock information containing details for both strategies
  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) {
    strategy1.lock(id: id, info: info.lockmanInfoForStrategy1)
    strategy2.lock(id: id, info: info.lockmanInfoForStrategy2)
  }

  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo2<I1, I2>
  ) {
    // Release in reverse order (LIFO)
    strategy2.unlock(id: id, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(id: id, info: info.lockmanInfoForStrategy1)
  }

  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
  }

  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    strategy1.cleanUp(id: id)
    strategy2.cleanUp(id: id)
  }

  /// Returns current locks information for debugging.
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
  ///   - results: Variable number of `LockResult` values from component strategies
  /// - Returns: The coordinated result following composite strategy rules
  private func coordinateResults(_ results: LockResult...) -> LockResult {
    // If any strategy failed, the entire operation fails
    if results.contains(.failure) {
      return .failure
    }

    // If all strategies succeeded without cancellation, operation succeeds
    if results.allSatisfy({ $0 == .success }) {
      return .success
    }

    // If any strategy requires cancellation, the operation requires cancellation
    return .successWithPrecedingCancellation
  }
}

// MARK: - LockmanCompositeStrategy3

/// A composite strategy that coordinates locking between 3 different strategies.
public final class LockmanCompositeStrategy3<
  I1: LockmanInfo, S1: LockmanStrategy,
  I2: LockmanInfo, S2: LockmanStrategy,
  I3: LockmanInfo, S3: LockmanStrategy
>: LockmanStrategy, @unchecked Sendable
  where S1.I == I1, S2.I == I2, S3.I == I3
{
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
    self.strategyId = Self.makeStrategyId(strategy1: strategy1, strategy2: strategy2, strategy3: strategy3)
  }

  /// Creates a strategy identifier for the composite strategy.
  ///
  /// - Parameters:
  ///   - strategy1: The first component strategy
  ///   - strategy2: The second component strategy
  ///   - strategy3: The third component strategy
  /// - Returns: A `LockmanStrategyId` that uniquely identifies this composite configuration
  public static func makeStrategyId(strategy1: S1, strategy2: S2, strategy3: S3) -> LockmanStrategyId {
    LockmanStrategyId(
      name: "CompositeStrategy3",
      configuration: "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  ///
  /// - Returns: A generic `LockmanStrategyId` for composite strategies
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy3")
  }

  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) -> LockResult {
    let result1 = strategy1.canLock(id: id, info: info.lockmanInfoForStrategy1)
    let result2 = strategy2.canLock(id: id, info: info.lockmanInfoForStrategy2)
    let result3 = strategy3.canLock(id: id, info: info.lockmanInfoForStrategy3)

    let result = coordinateResults(result1, result2, result3)

    let failureReason: String?
    if result == .failure {
      var failedStrategies: [String] = []
      if result1 == .failure {
        failedStrategies.append("Strategy1")
      }
      if result2 == .failure {
        failedStrategies.append("Strategy2")
      }
      if result3 == .failure {
        failedStrategies.append("Strategy3")
      }
      failureReason = "Failed strategies: \(failedStrategies.joined(separator: ", "))"
    } else {
      failureReason = nil
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason
    )

    return result
  }

  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) {
    strategy1.lock(id: id, info: info.lockmanInfoForStrategy1)
    strategy2.lock(id: id, info: info.lockmanInfoForStrategy2)
    strategy3.lock(id: id, info: info.lockmanInfoForStrategy3)
  }

  /// Releases locks from all component strategies in reverse order.
  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo3<I1, I2, I3>
  ) {
    // Release in reverse order (LIFO)
    strategy3.unlock(id: id, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(id: id, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(id: id, info: info.lockmanInfoForStrategy1)
  }

  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
  }

  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    strategy1.cleanUp(id: id)
    strategy2.cleanUp(id: id)
    strategy3.cleanUp(id: id)
  }

  /// Returns current locks information for debugging.
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

  private func coordinateResults(_ results: LockResult...) -> LockResult {
    if results.contains(.failure) {
      return .failure
    }

    if results.allSatisfy({ $0 == .success }) {
      return .success
    }

    return .successWithPrecedingCancellation
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
  where S1.I == I1, S2.I == I2, S3.I == I3, S4.I == I4
{
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
    self.strategyId = Self.makeStrategyId(strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4)
  }

  /// Creates a strategy identifier for the composite strategy.
  public static func makeStrategyId(strategy1: S1, strategy2: S2, strategy3: S3, strategy4: S4) -> LockmanStrategyId {
    LockmanStrategyId(
      name: "CompositeStrategy4",
      configuration: "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)+\(strategy4.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy4")
  }

  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) -> LockResult {
    let result1 = strategy1.canLock(id: id, info: info.lockmanInfoForStrategy1)
    let result2 = strategy2.canLock(id: id, info: info.lockmanInfoForStrategy2)
    let result3 = strategy3.canLock(id: id, info: info.lockmanInfoForStrategy3)
    let result4 = strategy4.canLock(id: id, info: info.lockmanInfoForStrategy4)

    let result = coordinateResults(result1, result2, result3, result4)

    let failureReason: String?
    if result == .failure {
      var failedStrategies: [String] = []
      if result1 == .failure {
        failedStrategies.append("Strategy1")
      }
      if result2 == .failure {
        failedStrategies.append("Strategy2")
      }
      if result3 == .failure {
        failedStrategies.append("Strategy3")
      }
      if result4 == .failure {
        failedStrategies.append("Strategy4")
      }
      failureReason = "Failed strategies: \(failedStrategies.joined(separator: ", "))"
    } else {
      failureReason = nil
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason
    )

    return result
  }

  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) {
    strategy1.lock(id: id, info: info.lockmanInfoForStrategy1)
    strategy2.lock(id: id, info: info.lockmanInfoForStrategy2)
    strategy3.lock(id: id, info: info.lockmanInfoForStrategy3)
    strategy4.lock(id: id, info: info.lockmanInfoForStrategy4)
  }

  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo4<I1, I2, I3, I4>
  ) {
    // Release in reverse order (LIFO)
    strategy4.unlock(id: id, info: info.lockmanInfoForStrategy4)
    strategy3.unlock(id: id, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(id: id, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(id: id, info: info.lockmanInfoForStrategy1)
  }

  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
    strategy4.cleanUp()
  }

  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    strategy1.cleanUp(id: id)
    strategy2.cleanUp(id: id)
    strategy3.cleanUp(id: id)
    strategy4.cleanUp(id: id)
  }

  /// Returns current locks information for debugging.
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

  private func coordinateResults(_ results: LockResult...) -> LockResult {
    if results.contains(.failure) {
      return .failure
    }

    if results.allSatisfy({ $0 == .success }) {
      return .success
    }

    return .successWithPrecedingCancellation
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
  where S1.I == I1, S2.I == I2, S3.I == I3, S4.I == I4, S5.I == I5
{
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
    self.strategyId = Self.makeStrategyId(strategy1: strategy1, strategy2: strategy2, strategy3: strategy3, strategy4: strategy4, strategy5: strategy5)
  }

  /// Creates a strategy identifier for the composite strategy.
  public static func makeStrategyId(strategy1: S1, strategy2: S2, strategy3: S3, strategy4: S4, strategy5: S5) -> LockmanStrategyId {
    LockmanStrategyId(
      name: "CompositeStrategy5",
      configuration: "\(strategy1.strategyId.value)+\(strategy2.strategyId.value)+\(strategy3.strategyId.value)+\(strategy4.strategyId.value)+\(strategy5.strategyId.value)"
    )
  }

  /// Creates a strategy identifier for the composite strategy type.
  public static func makeStrategyId() -> LockmanStrategyId {
    LockmanStrategyId(name: "CompositeStrategy5")
  }

  public func canLock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) -> LockResult {
    let result1 = strategy1.canLock(id: id, info: info.lockmanInfoForStrategy1)
    let result2 = strategy2.canLock(id: id, info: info.lockmanInfoForStrategy2)
    let result3 = strategy3.canLock(id: id, info: info.lockmanInfoForStrategy3)
    let result4 = strategy4.canLock(id: id, info: info.lockmanInfoForStrategy4)
    let result5 = strategy5.canLock(id: id, info: info.lockmanInfoForStrategy5)

    let result = coordinateResults(result1, result2, result3, result4, result5)

    let failureReason: String?
    if result == .failure {
      var failedStrategies: [String] = []
      if result1 == .failure {
        failedStrategies.append("Strategy1")
      }
      if result2 == .failure {
        failedStrategies.append("Strategy2")
      }
      if result3 == .failure {
        failedStrategies.append("Strategy3")
      }
      if result4 == .failure {
        failedStrategies.append("Strategy4")
      }
      if result5 == .failure {
        failedStrategies.append("Strategy5")
      }
      failureReason = "Failed strategies: \(failedStrategies.joined(separator: ", "))"
    } else {
      failureReason = nil
    }

    LockmanLogger.shared.logCanLock(
      result: result,
      strategy: "Composite",
      boundaryId: String(describing: id),
      info: info,
      reason: failureReason
    )

    return result
  }

  public func lock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) {
    strategy1.lock(id: id, info: info.lockmanInfoForStrategy1)
    strategy2.lock(id: id, info: info.lockmanInfoForStrategy2)
    strategy3.lock(id: id, info: info.lockmanInfoForStrategy3)
    strategy4.lock(id: id, info: info.lockmanInfoForStrategy4)
    strategy5.lock(id: id, info: info.lockmanInfoForStrategy5)
  }

  public func unlock<B: LockmanBoundaryId>(
    id: B,
    info: LockmanCompositeInfo5<I1, I2, I3, I4, I5>
  ) {
    // Release in reverse order (LIFO)
    strategy5.unlock(id: id, info: info.lockmanInfoForStrategy5)
    strategy4.unlock(id: id, info: info.lockmanInfoForStrategy4)
    strategy3.unlock(id: id, info: info.lockmanInfoForStrategy3)
    strategy2.unlock(id: id, info: info.lockmanInfoForStrategy2)
    strategy1.unlock(id: id, info: info.lockmanInfoForStrategy1)
  }

  public func cleanUp() {
    strategy1.cleanUp()
    strategy2.cleanUp()
    strategy3.cleanUp()
    strategy4.cleanUp()
    strategy5.cleanUp()
  }

  public func cleanUp<B: LockmanBoundaryId>(id: B) {
    strategy1.cleanUp(id: id)
    strategy2.cleanUp(id: id)
    strategy3.cleanUp(id: id)
    strategy4.cleanUp(id: id)
    strategy5.cleanUp(id: id)
  }

  /// Returns current locks information for debugging.
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

  private func coordinateResults(_ results: LockResult...) -> LockResult {
    if results.contains(.failure) {
      return .failure
    }

    if results.allSatisfy({ $0 == .success }) {
      return .success
    }

    return .successWithPrecedingCancellation
  }
}
