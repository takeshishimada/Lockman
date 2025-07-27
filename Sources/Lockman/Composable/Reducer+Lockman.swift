import CasePaths
import ComposableArchitecture
import Foundation

// MARK: - Reducer Extension

extension Reducer {
  /// Applies dynamic lock management to this reducer with conditional evaluation.
  ///
  /// This method enables dynamic lock condition evaluation based on the current state and action,
  /// allowing for fine-grained control over when locks should be acquired.
  ///
  /// ## Overview
  /// This method wraps the reducer with a `LockmanDynamicConditionReducer` that provides two levels of lock condition control:
  /// - **Reducer-level**: Condition specified in this method that applies to all actions
  /// - **Action-level**: Condition specified per `lock` call for specific actions within the reducer
  ///
  /// ## Example
  /// ```swift
  /// var body: some ReducerOf<Self> {
  ///   Reduce { state, action in
  ///     switch action {
  ///     case .purchase(let amount):
  ///       return self.lock(
  ///         state: state,
  ///         action: action,
  ///         operation: { send in
  ///           // Purchase operation
  ///         },
  ///         lockAction: PurchaseAction(),
  ///         boundaryId: CancelID.payment,
  ///         lockCondition: { state, _ in
  ///           // Action-level condition
  ///           guard state.balance >= amount else {
  ///             return .cancel(InsufficientFundsError())
  ///           }
  ///           return .success
  ///         }
  ///       )
  ///     }
  ///   }
  ///   .lock { state, _ in
  ///     // Reducer-level condition
  ///     guard state.isAuthenticated else {
  ///       return .cancel(NotAuthenticatedError())
  ///     }
  ///     return .success
  ///   }
  /// }
  /// ```
  ///
  /// - Parameter condition: Function that evaluates the current state and action
  ///                       to determine if a lock should be acquired.
  /// - Returns: A `LockmanDynamicConditionReducer` reducer that evaluates conditions before acquiring locks
  public func lock(
    condition: @escaping @Sendable (_ state: State, _ action: Action) -> LockmanResult
  ) -> LockmanDynamicConditionReducer<State, Action> where State: Sendable, Action: Sendable {
    LockmanDynamicConditionReducer(
      base: Reduce { state, action in
        self.reduce(into: &state, action: action)
      },
      lockCondition: condition
    )
  }

  /// Applies Lockman locking to effects produced by this reducer.
  ///
  /// This method wraps the reducer to automatically apply locking to any effects
  /// produced by actions that conform to `LockmanAction`. Actions that don't
  /// conform to `LockmanAction` pass through unchanged.
  ///
  /// The locking behavior is determined by the `lockmanInfo` property of each action.
  /// When an effect is locked:
  /// - If the lock is acquired successfully, the effect executes normally
  /// - If the lock fails, the `lockFailure` callback is invoked (if provided)
  /// - The lock is automatically released based on the `unlockOption`
  ///
  /// ## Usage
  /// ```swift
  /// // For root-level LockmanAction
  /// var body: some ReducerOf<Self> {
  ///   Reduce { state, action in
  ///     // Your reducer logic
  ///   }
  ///   .lock(boundaryId: CancelID.feature)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking. All actions within this
  ///     boundary will be subject to the locking rules defined in their `lockmanInfo`.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///     Receives the error and a send function to dispatch actions.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) -> LockmanReducer<Self> {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // Only check root action
        action as? any LockmanAction
      }
    )
  }

  /// Applies Lockman locking to effects with support for nested actions (1 path).
  ///
  /// This overload supports the ViewAction pattern in TCA where actions may be nested
  /// within enum cases. It checks both the root action and the specified nested path.
  ///
  /// ## Usage
  /// ```swift
  /// var body: some ReducerOf<Self> {
  ///   Reduce { state, action in
  ///     // Your reducer logic
  ///   }
  ///   .lock(
  ///     boundaryId: CancelID.feature,
  ///     for: \.view
  ///   )
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///   - path1: A case path to extract a nested action that may conform to `LockmanAction`.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock<Value1>(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    for path1: CaseKeyPath<Action, Value1>
  ) -> LockmanReducer<Self> where Action: CasePathable {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // First check if root action conforms to LockmanAction
        if let lockmanAction = action as? any LockmanAction {
          return lockmanAction
        }
        // Then check the provided path
        if let value = action[case: path1] {
          return value as? any LockmanAction
        }
        return nil
      }
    )
  }

  /// Applies Lockman locking to effects with support for nested actions (2 paths).
  ///
  /// This overload supports the ViewAction pattern in TCA where actions may be nested
  /// within enum cases. It checks the root action and the specified nested paths.
  ///
  /// ## Usage
  /// ```swift
  /// var body: some ReducerOf<Self> {
  ///   Reduce { state, action in
  ///     // Your reducer logic
  ///   }
  ///   .lock(
  ///     boundaryId: CancelID.feature,
  ///     for: \.view, \.delegate
  ///   )
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///   - path1: First case path to extract a nested action.
  ///   - path2: Second case path to extract a nested action.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock<Value1, Value2>(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    for path1: CaseKeyPath<Action, Value1>,
    _ path2: CaseKeyPath<Action, Value2>
  ) -> LockmanReducer<Self> where Action: CasePathable {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // First check if root action conforms to LockmanAction
        if let lockmanAction = action as? any LockmanAction {
          return lockmanAction
        }
        // Then check the provided paths
        let paths: [(Action) -> Any?] = [
          { $0[case: path1] },
          { $0[case: path2] },
        ]
        for path in paths {
          if let value = path(action) {
            if let lockmanAction = value as? any LockmanAction {
              return lockmanAction
            }
          }
        }
        return nil
      }
    )
  }

  /// Applies Lockman locking to effects with support for nested actions (3 paths).
  ///
  /// This overload supports the ViewAction pattern in TCA where actions may be nested
  /// within enum cases. It checks the root action and the specified nested paths.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///   - path1: First case path to extract a nested action.
  ///   - path2: Second case path to extract a nested action.
  ///   - path3: Third case path to extract a nested action.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock<Value1, Value2, Value3>(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    for path1: CaseKeyPath<Action, Value1>,
    _ path2: CaseKeyPath<Action, Value2>,
    _ path3: CaseKeyPath<Action, Value3>
  ) -> LockmanReducer<Self> where Action: CasePathable {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // First check if root action conforms to LockmanAction
        if let lockmanAction = action as? any LockmanAction {
          return lockmanAction
        }
        // Then check the provided paths
        let paths: [(Action) -> Any?] = [
          { $0[case: path1] },
          { $0[case: path2] },
          { $0[case: path3] },
        ]
        for path in paths {
          if let value = path(action) {
            if let lockmanAction = value as? any LockmanAction {
              return lockmanAction
            }
          }
        }
        return nil
      }
    )
  }

  /// Applies Lockman locking to effects with support for nested actions (4 paths).
  ///
  /// This overload supports the ViewAction pattern in TCA where actions may be nested
  /// within enum cases. It checks the root action and the specified nested paths.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///   - path1: First case path to extract a nested action.
  ///   - path2: Second case path to extract a nested action.
  ///   - path3: Third case path to extract a nested action.
  ///   - path4: Fourth case path to extract a nested action.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock<Value1, Value2, Value3, Value4>(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    for path1: CaseKeyPath<Action, Value1>,
    _ path2: CaseKeyPath<Action, Value2>,
    _ path3: CaseKeyPath<Action, Value3>,
    _ path4: CaseKeyPath<Action, Value4>
  ) -> LockmanReducer<Self> where Action: CasePathable {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // First check if root action conforms to LockmanAction
        if let lockmanAction = action as? any LockmanAction {
          return lockmanAction
        }
        // Then check the provided paths
        let paths: [(Action) -> Any?] = [
          { $0[case: path1] },
          { $0[case: path2] },
          { $0[case: path3] },
          { $0[case: path4] },
        ]
        for path in paths {
          if let value = path(action) {
            if let lockmanAction = value as? any LockmanAction {
              return lockmanAction
            }
          }
        }
        return nil
      }
    )
  }

  /// Applies Lockman locking to effects with support for nested actions (5 paths).
  ///
  /// This overload supports the ViewAction pattern in TCA where actions may be nested
  /// within enum cases. It checks the root action and the specified nested paths.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier for locking.
  ///   - unlockOption: When to release the lock. Defaults to `.immediate`.
  ///   - lockFailure: Optional callback invoked when lock acquisition fails.
  ///   - path1: First case path to extract a nested action.
  ///   - path2: Second case path to extract a nested action.
  ///   - path3: Third case path to extract a nested action.
  ///   - path4: Fourth case path to extract a nested action.
  ///   - path5: Fifth case path to extract a nested action.
  /// - Returns: A `LockmanReducer` that wraps this reducer with locking behavior.
  public func lock<Value1, Value2, Value3, Value4, Value5>(
    boundaryId: any LockmanBoundaryId,
    unlockOption: LockmanUnlockOption = .immediate,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    for path1: CaseKeyPath<Action, Value1>,
    _ path2: CaseKeyPath<Action, Value2>,
    _ path3: CaseKeyPath<Action, Value3>,
    _ path4: CaseKeyPath<Action, Value4>,
    _ path5: CaseKeyPath<Action, Value5>
  ) -> LockmanReducer<Self> where Action: CasePathable {
    LockmanReducer(
      base: self,
      boundaryId: boundaryId,
      unlockOption: unlockOption,
      lockFailure: lockFailure,
      extractLockmanAction: { action in
        // First check if root action conforms to LockmanAction
        if let lockmanAction = action as? any LockmanAction {
          return lockmanAction
        }
        // Then check the provided paths
        let paths: [(Action) -> Any?] = [
          { $0[case: path1] },
          { $0[case: path2] },
          { $0[case: path3] },
          { $0[case: path4] },
          { $0[case: path5] },
        ]
        for path in paths {
          if let value = path(action) {
            if let lockmanAction = value as? any LockmanAction {
              return lockmanAction
            }
          }
        }
        return nil
      }
    )
  }
}
