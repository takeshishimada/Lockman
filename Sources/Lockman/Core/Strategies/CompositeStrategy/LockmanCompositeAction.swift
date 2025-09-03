/// Protocol for actions that use composite locking behavior with 2 strategies.
///
/// This protocol extends the base `LockmanAction` to support composite locking
/// where multiple strategies work together to coordinate access to shared resources.
/// Conforming types must provide strategy type information and composite lock info.
///
/// ## Usage Example
/// ```swift
/// struct MyCompositeAction: LockmanCompositeAction2 {
///   typealias I1 = LockmanSingleExecutionInfo
///   typealias S1 = LockmanSingleExecutionStrategy
///   typealias I2 = LockmanPriorityBasedInfo
///   typealias S2 = LockmanPriorityBasedStrategy
///
///   let actionName = "myCompositeAction"
///
///   func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2> {
///     LockmanCompositeInfo2(
///       actionId: actionName,
///       lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary),
///       lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: actionName, priority: .high(.exclusive))
///     )
///   }
/// }
/// ```
public protocol LockmanCompositeAction2: LockmanAction {
  /// The first strategy's info type.
  associatedtype I1: LockmanInfo

  /// The first strategy type used in the composite strategy.
  associatedtype S1: LockmanStrategy where S1.I == I1

  /// The second strategy's info type.
  associatedtype I2: LockmanInfo

  /// The second strategy type used in the composite strategy.
  associatedtype S2: LockmanStrategy where S2.I == I2

  /// Creates composite lock information containing details for both strategies.
  /// This includes action identifiers and strategy-specific information.
  func createLockmanInfo() -> LockmanCompositeInfo2<I1, I2>
}

/// Protocol for actions that use composite locking behavior with 3 strategies.
///
/// Extends composite locking to coordinate between three different strategies,
/// ensuring all strategies can acquire their locks before proceeding.
public protocol LockmanCompositeAction3: LockmanAction {
  /// The first strategy's info type.
  associatedtype I1: LockmanInfo

  /// The first strategy type used in the composite strategy.
  associatedtype S1: LockmanStrategy where S1.I == I1

  /// The second strategy's info type.
  associatedtype I2: LockmanInfo

  /// The second strategy type used in the composite strategy.
  associatedtype S2: LockmanStrategy where S2.I == I2

  /// The third strategy's info type.
  associatedtype I3: LockmanInfo

  /// The third strategy type used in the composite strategy.
  associatedtype S3: LockmanStrategy where S3.I == I3

  /// Creates composite lock information containing details for all three strategies.
  /// This includes action identifiers and strategy-specific information.
  func createLockmanInfo() -> LockmanCompositeInfo3<I1, I2, I3>
}

/// Protocol for actions that use composite locking behavior with 4 strategies.
///
/// Extends composite locking to coordinate between four different strategies,
/// ensuring all strategies can acquire their locks before proceeding.
public protocol LockmanCompositeAction4: LockmanAction {
  /// The first strategy's info type.
  associatedtype I1: LockmanInfo

  /// The first strategy type used in the composite strategy.
  associatedtype S1: LockmanStrategy where S1.I == I1

  /// The second strategy's info type.
  associatedtype I2: LockmanInfo

  /// The second strategy type used in the composite strategy.
  associatedtype S2: LockmanStrategy where S2.I == I2

  /// The third strategy's info type.
  associatedtype I3: LockmanInfo

  /// The third strategy type used in the composite strategy.
  associatedtype S3: LockmanStrategy where S3.I == I3

  /// The fourth strategy's info type.
  associatedtype I4: LockmanInfo

  /// The fourth strategy type used in the composite strategy.
  associatedtype S4: LockmanStrategy where S4.I == I4

  /// Creates composite lock information containing details for all four strategies.
  /// This includes action identifiers and strategy-specific information.
  func createLockmanInfo() -> LockmanCompositeInfo4<I1, I2, I3, I4>
}

/// Protocol for actions that use composite locking behavior with 5 strategies.
///
/// Extends composite locking to coordinate between five different strategies,
/// ensuring all strategies can acquire their locks before proceeding.
public protocol LockmanCompositeAction5: LockmanAction {
  /// The first strategy's info type.
  associatedtype I1: LockmanInfo

  /// The first strategy type used in the composite strategy.
  associatedtype S1: LockmanStrategy where S1.I == I1

  /// The second strategy's info type.
  associatedtype I2: LockmanInfo

  /// The second strategy type used in the composite strategy.
  associatedtype S2: LockmanStrategy where S2.I == I2

  /// The third strategy's info type.
  associatedtype I3: LockmanInfo

  /// The third strategy type used in the composite strategy.
  associatedtype S3: LockmanStrategy where S3.I == I3

  /// The fourth strategy's info type.
  associatedtype I4: LockmanInfo

  /// The fourth strategy type used in the composite strategy.
  associatedtype S4: LockmanStrategy where S4.I == I4

  /// The fifth strategy's info type.
  associatedtype I5: LockmanInfo

  /// The fifth strategy type used in the composite strategy.
  associatedtype S5: LockmanStrategy where S5.I == I5

  /// Creates composite lock information containing details for all five strategies.
  /// This includes action identifiers and strategy-specific information.
  func createLockmanInfo() -> LockmanCompositeInfo5<I1, I2, I3, I4, I5>
}

// MARK: - Default Implementations

extension LockmanCompositeAction2 {
  /// Creates a type-erased composite strategy instance.
  ///
  /// This helper method constructs a composite strategy from the individual
  /// strategy instances and wraps it in `AnyLockmanStrategy` for type erasure.
  ///
  /// - Parameters:
  ///   - strategy1: The first strategy instance
  ///   - strategy2: The second strategy instance
  /// - Returns: A type-erased composite strategy instance
  public func makeCompositeStrategy(
    strategy1: S1,
    strategy2: S2
  ) -> AnyLockmanStrategy<LockmanCompositeInfo2<I1, I2>> {
    let compositeStrategy = LockmanCompositeStrategy2(
      strategy1: strategy1,
      strategy2: strategy2
    )
    return AnyLockmanStrategy(compositeStrategy)
  }
}

extension LockmanCompositeAction3 {
  /// Creates a type-erased composite strategy instance.
  ///
  /// - Parameters:
  ///   - strategy1: The first strategy instance
  ///   - strategy2: The second strategy instance
  ///   - strategy3: The third strategy instance
  /// - Returns: A type-erased composite strategy instance
  public func makeCompositeStrategy(
    strategy1: S1,
    strategy2: S2,
    strategy3: S3
  ) -> AnyLockmanStrategy<LockmanCompositeInfo3<I1, I2, I3>> {
    let compositeStrategy = LockmanCompositeStrategy3(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )
    return AnyLockmanStrategy(compositeStrategy)
  }
}

extension LockmanCompositeAction4 {
  /// Creates a type-erased composite strategy instance.
  ///
  /// - Parameters:
  ///   - strategy1: The first strategy instance
  ///   - strategy2: The second strategy instance
  ///   - strategy3: The third strategy instance
  ///   - strategy4: The fourth strategy instance
  /// - Returns: A type-erased composite strategy instance
  public func makeCompositeStrategy(
    strategy1: S1,
    strategy2: S2,
    strategy3: S3,
    strategy4: S4
  ) -> AnyLockmanStrategy<LockmanCompositeInfo4<I1, I2, I3, I4>> {
    let compositeStrategy = LockmanCompositeStrategy4(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )
    return AnyLockmanStrategy(compositeStrategy)
  }
}

extension LockmanCompositeAction5 {
  /// Creates a type-erased composite strategy instance.
  ///
  /// - Parameters:
  ///   - strategy1: The first strategy instance
  ///   - strategy2: The second strategy instance
  ///   - strategy3: The third strategy instance
  ///   - strategy4: The fourth strategy instance
  ///   - strategy5: The fifth strategy instance
  /// - Returns: A type-erased composite strategy instance
  public func makeCompositeStrategy(
    strategy1: S1,
    strategy2: S2,
    strategy3: S3,
    strategy4: S4,
    strategy5: S5
  ) -> AnyLockmanStrategy<LockmanCompositeInfo5<I1, I2, I3, I4, I5>> {
    let compositeStrategy = LockmanCompositeStrategy5(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4,
      strategy5: strategy5
    )
    return AnyLockmanStrategy(compositeStrategy)
  }
}
