import Foundation

// MARK: - LockmanCompositeInfo2

/// Information for composite locking behavior with 2 strategies.
///
/// Contains action identifiers and strategy-specific information for coordinated locking
/// between two different strategies. Each strategy must successfully acquire its lock
/// for the composite operation to proceed.
///
/// ## Usage Example
/// ```swift
/// let compositeInfo = LockmanCompositeInfo2(
///   actionId: "userLogin",
///   lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "userLogin", mode: .boundary),
///   lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "userLogin", priority: .high(.exclusive))
/// )
/// ```
///
/// ## Thread Safety
/// This struct is `Sendable` and can be safely passed across concurrent contexts.
/// All properties are immutable after initialization.
public struct LockmanCompositeInfo2<I1: LockmanInfo, I2: LockmanInfo>: LockmanInfo, Sendable {
  // MARK: - LockmanInfo Protocol Properties

  /// The strategy identifier for this composite lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier for this composite action.
  ///
  /// This identifier represents the overall composite operation and should typically
  /// match the action IDs of the individual strategy infos to ensure consistent
  /// lock conflict detection.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific composite info instance.
  ///
  /// Used for equality comparison and instance tracking within the locking system.
  /// Each instance gets a unique UUID regardless of shared action IDs.
  public let uniqueId: UUID

  // MARK: - Composite-Specific Properties

  /// Lock information for the first strategy.
  ///
  /// This information will be passed to the first strategy when determining
  /// lock acquisition feasibility and when actually acquiring the lock.
  public let lockmanInfoForStrategy1: I1

  /// Lock information for the second strategy.
  ///
  /// This information will be passed to the second strategy when determining
  /// lock acquisition feasibility and when actually acquiring the lock.
  public let lockmanInfoForStrategy2: I2

  // MARK: - Initialization

  /// Creates a new composite info instance with user-specified action ID.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this composite lock (defaults to "Lockman.CompositeStrategy2")
  ///   - actionId: User-specified action identifier for the composite operation
  ///   - lockmanInfoForStrategy1: Lock information for the first strategy
  ///   - lockmanInfoForStrategy2: Lock information for the second strategy
  ///
  /// ## Design Note
  /// The `uniqueId` is automatically generated to ensure each instance has
  /// a distinct identity, even when multiple instances share the same `actionId`.
  public init(
    strategyId: LockmanStrategyId = .init("Lockman.CompositeStrategy2"),
    actionId: LockmanActionId,
    lockmanInfoForStrategy1: I1,
    lockmanInfoForStrategy2: I2
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.lockmanInfoForStrategy1 = lockmanInfoForStrategy1
    self.lockmanInfoForStrategy2 = lockmanInfoForStrategy2
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanCompositeInfo2: CustomDebugStringConvertible {
  public var debugDescription: String {
    "LockmanCompositeInfo2(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), info1: \(lockmanInfoForStrategy1.debugDescription), info2: \(lockmanInfoForStrategy2.debugDescription))"
  }

  public var debugAdditionalInfo: String {
    "Composite"
  }
}

// MARK: - LockmanCompositeInfo3

/// Information for composite locking behavior with 3 strategies.
///
/// Contains action identifiers and strategy-specific information for coordinated locking
/// between three different strategies. All strategies must successfully acquire their locks
/// for the composite operation to proceed.
public struct LockmanCompositeInfo3<I1: LockmanInfo, I2: LockmanInfo, I3: LockmanInfo>: LockmanInfo,
  Sendable
{
  // MARK: - LockmanInfo Protocol Properties

  /// The strategy identifier for this composite lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier for this composite action.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific composite info instance.
  public let uniqueId: UUID

  // MARK: - Composite-Specific Properties

  /// Lock information for the first strategy.
  public let lockmanInfoForStrategy1: I1

  /// Lock information for the second strategy.
  public let lockmanInfoForStrategy2: I2

  /// Lock information for the third strategy.
  public let lockmanInfoForStrategy3: I3

  // MARK: - Initialization

  /// Creates a new composite info instance with user-specified action ID.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this composite lock (defaults to "Lockman.CompositeStrategy3")
  ///   - actionId: User-specified action identifier for the composite operation
  ///   - lockmanInfoForStrategy1: Lock information for the first strategy
  ///   - lockmanInfoForStrategy2: Lock information for the second strategy
  ///   - lockmanInfoForStrategy3: Lock information for the third strategy
  public init(
    strategyId: LockmanStrategyId = .init("Lockman.CompositeStrategy3"),
    actionId: LockmanActionId,
    lockmanInfoForStrategy1: I1,
    lockmanInfoForStrategy2: I2,
    lockmanInfoForStrategy3: I3
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.lockmanInfoForStrategy1 = lockmanInfoForStrategy1
    self.lockmanInfoForStrategy2 = lockmanInfoForStrategy2
    self.lockmanInfoForStrategy3 = lockmanInfoForStrategy3
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanCompositeInfo3: CustomDebugStringConvertible {
  public var debugDescription: String {
    "LockmanCompositeInfo3(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), info1: \(lockmanInfoForStrategy1.debugDescription), info2: \(lockmanInfoForStrategy2.debugDescription), info3: \(lockmanInfoForStrategy3.debugDescription))"
  }

  public var debugAdditionalInfo: String {
    "Composite"
  }
}

// MARK: - LockmanCompositeInfo4

/// Information for composite locking behavior with 4 strategies.
///
/// Contains action identifiers and strategy-specific information for coordinated locking
/// between four different strategies. All strategies must successfully acquire their locks
/// for the composite operation to proceed.
public struct LockmanCompositeInfo4<
  I1: LockmanInfo, I2: LockmanInfo, I3: LockmanInfo, I4: LockmanInfo
>: LockmanInfo, Sendable {
  // MARK: - LockmanInfo Protocol Properties

  /// The strategy identifier for this composite lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier for this composite action.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific composite info instance.
  public let uniqueId: UUID

  // MARK: - Composite-Specific Properties

  /// Lock information for the first strategy.
  public let lockmanInfoForStrategy1: I1

  /// Lock information for the second strategy.
  public let lockmanInfoForStrategy2: I2

  /// Lock information for the third strategy.
  public let lockmanInfoForStrategy3: I3

  /// Lock information for the fourth strategy.
  public let lockmanInfoForStrategy4: I4

  // MARK: - Initialization

  /// Creates a new composite info instance with user-specified action ID.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this composite lock (defaults to "Lockman.CompositeStrategy4")
  ///   - actionId: User-specified action identifier for the composite operation
  ///   - lockmanInfoForStrategy1: Lock information for the first strategy
  ///   - lockmanInfoForStrategy2: Lock information for the second strategy
  ///   - lockmanInfoForStrategy3: Lock information for the third strategy
  ///   - lockmanInfoForStrategy4: Lock information for the fourth strategy
  public init(
    strategyId: LockmanStrategyId = .init("Lockman.CompositeStrategy4"),
    actionId: LockmanActionId,
    lockmanInfoForStrategy1: I1,
    lockmanInfoForStrategy2: I2,
    lockmanInfoForStrategy3: I3,
    lockmanInfoForStrategy4: I4
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.lockmanInfoForStrategy1 = lockmanInfoForStrategy1
    self.lockmanInfoForStrategy2 = lockmanInfoForStrategy2
    self.lockmanInfoForStrategy3 = lockmanInfoForStrategy3
    self.lockmanInfoForStrategy4 = lockmanInfoForStrategy4
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanCompositeInfo4: CustomDebugStringConvertible {
  public var debugDescription: String {
    "LockmanCompositeInfo4(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), info1: \(lockmanInfoForStrategy1.debugDescription), info2: \(lockmanInfoForStrategy2.debugDescription), info3: \(lockmanInfoForStrategy3.debugDescription), info4: \(lockmanInfoForStrategy4.debugDescription))"
  }

  public var debugAdditionalInfo: String {
    "Composite"
  }
}

// MARK: - LockmanCompositeInfo5

/// Information for composite locking behavior with 5 strategies.
///
/// Contains action identifiers and strategy-specific information for coordinated locking
/// between five different strategies. All strategies must successfully acquire their locks
/// for the composite operation to proceed.
public struct LockmanCompositeInfo5<
  I1: LockmanInfo, I2: LockmanInfo, I3: LockmanInfo, I4: LockmanInfo, I5: LockmanInfo
>: LockmanInfo, Sendable {
  // MARK: - LockmanInfo Protocol Properties

  /// The strategy identifier for this composite lock info.
  public let strategyId: LockmanStrategyId

  /// The action identifier for this composite action.
  public let actionId: LockmanActionId

  /// A unique identifier for this specific composite info instance.
  public let uniqueId: UUID

  // MARK: - Composite-Specific Properties

  /// Lock information for the first strategy.
  public let lockmanInfoForStrategy1: I1

  /// Lock information for the second strategy.
  public let lockmanInfoForStrategy2: I2

  /// Lock information for the third strategy.
  public let lockmanInfoForStrategy3: I3

  /// Lock information for the fourth strategy.
  public let lockmanInfoForStrategy4: I4

  /// Lock information for the fifth strategy.
  public let lockmanInfoForStrategy5: I5

  // MARK: - Initialization

  /// Creates a new composite info instance with user-specified action ID.
  ///
  /// - Parameters:
  ///   - strategyId: The strategy identifier for this composite lock (defaults to "Lockman.CompositeStrategy5")
  ///   - actionId: User-specified action identifier for the composite operation
  ///   - lockmanInfoForStrategy1: Lock information for the first strategy
  ///   - lockmanInfoForStrategy2: Lock information for the second strategy
  ///   - lockmanInfoForStrategy3: Lock information for the third strategy
  ///   - lockmanInfoForStrategy4: Lock information for the fourth strategy
  ///   - lockmanInfoForStrategy5: Lock information for the fifth strategy
  public init(
    strategyId: LockmanStrategyId = .init("Lockman.CompositeStrategy5"),
    actionId: LockmanActionId,
    lockmanInfoForStrategy1: I1,
    lockmanInfoForStrategy2: I2,
    lockmanInfoForStrategy3: I3,
    lockmanInfoForStrategy4: I4,
    lockmanInfoForStrategy5: I5
  ) {
    self.strategyId = strategyId
    self.actionId = actionId
    self.uniqueId = UUID()
    self.lockmanInfoForStrategy1 = lockmanInfoForStrategy1
    self.lockmanInfoForStrategy2 = lockmanInfoForStrategy2
    self.lockmanInfoForStrategy3 = lockmanInfoForStrategy3
    self.lockmanInfoForStrategy4 = lockmanInfoForStrategy4
    self.lockmanInfoForStrategy5 = lockmanInfoForStrategy5
  }
}

// MARK: - CustomDebugStringConvertible

extension LockmanCompositeInfo5: CustomDebugStringConvertible {
  public var debugDescription: String {
    "LockmanCompositeInfo5(strategyId: '\(strategyId)', actionId: '\(actionId)', uniqueId: \(uniqueId), info1: \(lockmanInfoForStrategy1.debugDescription), info2: \(lockmanInfoForStrategy2.debugDescription), info3: \(lockmanInfoForStrategy3.debugDescription), info4: \(lockmanInfoForStrategy4.debugDescription), info5: \(lockmanInfoForStrategy5.debugDescription))"
  }

  public var debugAdditionalInfo: String {
    "Composite"
  }
}
