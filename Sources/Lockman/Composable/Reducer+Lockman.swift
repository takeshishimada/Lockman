import CasePaths
import ComposableArchitecture
import Foundation

/// A reducer wrapper that applies Lockman locking to effects produced by actions conforming to `LockmanAction`.
///
/// `LockmanReducer` intercepts effects from the base reducer and automatically applies
/// locking behavior to actions that implement the `LockmanAction` protocol. Actions that
/// don't conform to `LockmanAction` pass through unchanged.
///
/// ## Example
/// ```swift
/// @Reducer
/// struct Feature {
///   struct State: Equatable { }
///
///   enum Action: LockmanAction {
///     case fetch
///     case fetchResponse(Result<Data, Error>)
///
///     var lockmanInfo: LockmanSingleExecutionInfo {
///       switch self {
///       case .fetch:
///         return LockmanSingleExecutionInfo(actionId: "fetch", mode: .boundary)
///       default:
///         return LockmanSingleExecutionInfo(actionId: "other", mode: .none)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .fetch:
///         return .run { send in
///           // This effect will be automatically locked
///           let data = try await fetchData()
///           await send(.fetchResponse(.success(data)))
///         }
///       case .fetchResponse:
///         return .none
///       }
///     }
///     .lock(boundaryId: CancelID.feature)
///   }
/// }
/// ```
public struct LockmanReducer<Base: Reducer>: Reducer {
  public typealias State = Base.State
  public typealias Action = Base.Action

  let base: Base
  let boundaryId: any LockmanBoundaryId
  let unlockOption: LockmanUnlockOption
  let lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?
  let extractLockmanAction: (Action) -> (any LockmanAction)?

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Get the base effect
      let baseEffect = self.base.reduce(into: &state, action: action)

      // Extract LockmanAction using the provided extractor
      guard let lockmanAction = self.extractLockmanAction(action) else {
        // Not a LockmanAction, return effect as-is
        return baseEffect
      }

      // Apply lock to the effect using Effect.lock()
      return baseEffect.lock(
        action: lockmanAction,
        boundaryId: boundaryId,
        unlockOption: unlockOption,
        lockFailure: lockFailure
      )
    }
  }
}

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
  ///             return .failure(InsufficientFundsError())
  ///           }
  ///           return .success
  ///         }
  ///       )
  ///     }
  ///   }
  ///   .lock { state, _ in
  ///     // Reducer-level condition
  ///     guard state.isAuthenticated else {
  ///       return .failure(NotAuthenticatedError())
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

// MARK: - LockmanDynamicConditionReducer

/// A reducer that wraps another reducer with dynamic lock evaluation capabilities.
///
/// `LockmanDynamicConditionReducer` enables dynamic lock condition evaluation based on the current state and action,
/// allowing for fine-grained control over when locks should be acquired.
///
/// ## Overview
/// This reducer provides two levels of lock condition control:
/// - **Reducer-level**: Optional condition specified at initialization that applies to all actions
/// - **Action-level**: Optional condition specified per `lock` call for specific actions
///
/// ## Usage Examples
///
/// ### With method chain API
/// ```swift
/// var body: some ReducerOf<Self> {
///   Reduce { state, action in
///     switch action {
///     case .fetchData:
///       return self.lock(
///         state: state,
///         action: action,
///         operation: { send in
///           // Async operation
///         },
///         lockAction: FetchAction(),
///         boundaryId: CancelID.fetch
///       )
///     default:
///       return .none
///     }
///   }
///   .lock { state, action in
///     // Evaluate state to determine if lock should be acquired
///     guard state.isEnabled else {
///       return .failure(MyError.featureDisabled)
///     }
///     return .success
///   }
/// }
/// ```
///
/// ### Combined conditions with method chain
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
///             return .failure(MyError.insufficientBalance(required: amount, available: state.balance))
///           }
///           return .success
///         }
///       )
///     default:
///       return .none
///     }
///   }
///   .lock { state, _ in
///     // Reducer-level condition
///     guard state.isLoggedIn else {
///       return .failure(MyError.notAuthenticated)
///     }
///     return .success
///   }
/// }
/// ```
public struct LockmanDynamicConditionReducer<State: Sendable, Action: Sendable>: Reducer {
  @usableFromInline
  internal let _base: Reduce<State, Action>

  /// The lock condition that will be evaluated for all actions in this reducer.
  /// This is made internal to allow the extension methods to access it.
  @usableFromInline
  internal let _lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?

  @usableFromInline
  var base: Reduce<State, Action> { _base }

  @usableFromInline
  var lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? {
    _lockCondition
  }

  /// Initializes a reducer with optional lock condition evaluation.
  ///
  /// - Parameters:
  ///   - reduce: The base reducer function to be executed.
  ///   - lockCondition: Optional function that evaluates the current state and action
  ///                    to determine if a lock should be acquired. If nil, no reducer-level
  ///                    condition is applied.
  public init(
    _ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil
  ) {
    self._base = Reduce { state, action in
      reduce(&state, action)
    }
    self._lockCondition = lockCondition
  }

  /// Initializes with an existing Reduce instance.
  ///
  /// - Parameters:
  ///   - base: An existing Reduce instance.
  ///   - lockCondition: Optional function that evaluates the current state and action
  ///                    to determine if a lock should be acquired.
  public init(
    base: Reduce<State, Action>,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil
  ) {
    self._base = base
    self._lockCondition = lockCondition
  }

  @inlinable
  public func reduce(into state: inout State, action: Action) -> Effect<Action> {
    // Simply execute the base reducer
    // Lock evaluation happens in lock methods
    self.base.reduce(into: &state, action: action)
  }
}

// MARK: - WithLock Extensions

extension LockmanDynamicConditionReducer {
  /// Executes Step 1 and Step 2: Dynamic condition evaluation for action-level and reducer-level conditions
  @usableFromInline
  func withLockStep1Step2<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    actionId: LockmanActionId,
    boundaryId: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    reducerCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    executeStep3: (LockmanUnlock<B, LockmanDynamicConditionInfo>) -> Effect<Action>
  ) -> Effect<Action> {
    // Create dynamic strategy and unlock token first
    let strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>
    let unlockToken: LockmanUnlock<B, LockmanDynamicConditionInfo>
    do {
      strategy = try LockmanManager.container.resolve(
        id: .dynamicCondition,
        expecting: LockmanDynamicConditionInfo.self
      )
      // Create unlock token inline
      unlockToken = LockmanUnlock(
        id: boundaryId,
        info: LockmanDynamicConditionInfo(actionId: actionId),
        strategy: strategy,
        unlockOption: .immediate
      )
    } catch {
      // If we can't create unlock token, report error
      Effect<Action>.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      if let lockFailure = lockFailure {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }

    // Step 1: Action-level dynamic condition (if provided)
    let (step1Success, step1Error) = lock(
      state: state,
      action: action,
      condition: lockCondition,
      strategy: strategy,
      actionId: actionId,
      boundaryId: boundaryId
    )

    if !step1Success {
      // Step 1 failed - return without unlocking
      if let lockFailure = lockFailure, let error = step1Error {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }

    // Step 2: Reducer-level dynamic condition (if exists)
    let (step2Success, step2Error) = lock(
      state: state,
      action: action,
      condition: reducerCondition,
      strategy: strategy,
      actionId: actionId,
      boundaryId: boundaryId
    )

    if !step2Success {
      // Step 2 failed - unlock Step 1 if it was acquired
      unlockToken()
      if let lockFailure = lockFailure, let error = step2Error {
        return .run { send in
          await lockFailure(error, send)
        }
      }
      return .none
    }

    // Step 3: Execute the provided closure with the unlock token
    return executeStep3(unlockToken)
  }

  /// Executes Step 3: Traditional withLock (automatic or manual unlock)
  @usableFromInline
  func withLockStep3<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority?,
    unlockOption: LockmanUnlockOption?,
    handleCancellationErrors: Bool?,
    action: A,
    boundaryId: B,
    unlockToken: LockmanUnlock<B, LockmanDynamicConditionInfo>,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    automaticUnlock: Bool,
    operation: Any,
    handler: Any?
  ) -> Effect<Action> {
    // Wrap the lockFailure handler to clean up dynamic locks if step 3 fails
    let wrappedLockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void) = {
      error, send in
      // Clean up all dynamic condition locks if step 3 lock acquisition fails
      unlockToken()

      // Call original handler if provided
      if let lockFailure = lockFailure {
        await lockFailure(error, send)
      }
    }

    let lockAction = action

    if automaticUnlock {
      // Automatic unlock case
      let operation = operation as! @Sendable (Send<Action>) async throws -> Void
      let handler = handler as? @Sendable (any Error, Send<Action>) async -> Void

      // Create wrapped operation that cleans up dynamic locks after completion
      let wrappedOperation: @Sendable (Send<Action>) async throws -> Void = { send in
        defer {
          // Clean up dynamic locks after operation completes (success or failure)
          unlockToken()
        }
        try await operation(send)
      }

      return Effect<Action>.withLock(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        operation: wrappedOperation,
        catch: handler,
        lockFailure: wrappedLockFailure,
        action: lockAction,
        boundaryId: boundaryId,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    } else {
      // Manual unlock case
      let operation =
        operation as! @Sendable (Send<Action>, LockmanUnlock<B, A.I>) async throws -> Void
      let handler =
        handler as? @Sendable (any Error, Send<Action>, LockmanUnlock<B, A.I>) async -> Void

      // Create wrapped operation that manages dynamic locks and provides manual unlock
      let wrappedOperation: @Sendable (Send<Action>, LockmanUnlock<B, A.I>) async throws -> Void = {
        send, unlock in
        do {
          try await operation(send, unlock)
          // Clean up dynamic locks after successful operation
          unlockToken()
        } catch {
          // Clean up dynamic locks on error
          unlockToken()
          throw error
        }
      }

      return Effect<Action>.withLock(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        operation: wrappedOperation,
        catch: handler,
        lockFailure: wrappedLockFailure,
        action: lockAction,
        boundaryId: boundaryId,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
    }
  }

  /// Helper function to evaluate a dynamic condition and acquire lock if successful
  @usableFromInline
  func lock<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    condition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionId: LockmanActionId,
    boundaryId: B
  ) -> (success: Bool, error: (any Error)?) {
    // If no condition provided, consider it successful
    guard let condition = condition else {
      return (true, nil)
    }

    // Create dynamic condition info
    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: actionId,
      condition: { condition(state, action) }
    )

    // Check condition and acquire lock if successful
    let result = Effect<Action>.lock(
      lockmanInfo: dynamicInfo,
      strategy: strategy,
      boundaryId: boundaryId
    )

    // Handle result
    switch result {
    case .failure(let error):
      return (false, error)
    case .successWithPrecedingCancellation(let error):
      // Lock acquired but with preceding cancellation - return success with error
      return (true, error)
    case .success:
      return (true, nil)
    @unknown default:
      return (true, nil)
    }
  }

  /// Creates an effect with automatic lock management and dynamic condition evaluation.
  ///
  /// This method implements a multi-stage locking mechanism:
  /// 1. Action-level condition (if specified in this call)
  /// 2. Reducer-level condition (if specified at initialization)
  /// 3. Traditional lock strategy (specified by lockAction)
  ///
  /// All conditions must pass for the operation to execute. Locks are automatically
  /// released when the operation completes.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - lockAction: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - lockCondition: Optional action-level condition that supplements the reducer-level condition
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate locking based on all conditions
  public func lock<B: LockmanBoundaryId>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockAction: some LockmanAction,
    boundaryId: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    let actionId = lockAction.lockmanInfo.actionId
    // Capture the reducer-level condition to avoid type inference issues
    let reducerLevelCondition = self.lockCondition

    return withLockStep1Step2(
      state: state,
      action: action,
      actionId: actionId,
      boundaryId: boundaryId,
      lockCondition: lockCondition,
      reducerCondition: reducerLevelCondition,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    ) { unlockToken in
      // Step 3: Traditional withLock using the specified strategy
      return withLockStep3(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        action: lockAction,
        boundaryId: boundaryId,
        unlockToken: unlockToken,
        lockFailure: lockFailure,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        automaticUnlock: true,
        operation: operation,
        handler: handler
      )
    }
  }

  /// Creates an effect with manual unlock control and dynamic condition evaluation.
  ///
  /// This method provides explicit control over when locks are released, giving you
  /// flexibility for complex scenarios where automatic unlock isn't sufficient.
  ///
  /// **Warning**: The caller MUST call `unlock()` in ALL code paths to avoid
  /// permanent lock acquisition. Consider using the automatic version unless you
  /// specifically need manual control.
  ///
  /// This method implements a multi-stage locking mechanism:
  /// 1. Action-level condition (if specified in this call)
  /// 2. Reducer-level condition (if specified at initialization)
  /// 3. Traditional lock strategy (specified by lockAction)
  ///
  /// All conditions must pass for the operation to execute. Once passed, the final
  /// unlock token is provided to the operation and error handlers.
  ///
  /// - Parameters:
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - priority: Task priority for the underlying `.run` effect (optional)
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - handleCancellationErrors: Whether to pass CancellationError to catch handler
  ///   - operation: Async closure receiving `send` and `unlock` functions
  ///   - handler: Optional error handler (`catch` parameter) receiving error, send, and unlock functions
  ///   - lockFailure: Optional handler for lock acquisition failures (no unlock token)
  ///   - lockAction: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - lockCondition: Optional action-level condition that supplements the reducer-level condition
  ///   - fileID: Source file identifier for debugging (auto-populated)
  ///   - filePath: Source file path for debugging (auto-populated)
  ///   - line: Source line number for debugging (auto-populated)
  ///   - column: Source column number for debugging (auto-populated)
  /// - Returns: Effect that executes with appropriate locking based on all conditions
  public func lock<B: LockmanBoundaryId, A: LockmanAction>(
    state: State,
    action: Action,
    priority: TaskPriority? = nil,
    unlockOption: LockmanUnlockOption? = nil,
    handleCancellationErrors: Bool? = nil,
    operation: @escaping @Sendable (
      _ send: Send<Action>, _ unlock: LockmanUnlock<B, A.I>
    ) async throws -> Void,
    catch handler: (
      @Sendable (
        _ error: any Error, _ send: Send<Action>,
        _ unlock: LockmanUnlock<B, A.I>
      ) async -> Void
    )? = nil,
    lockFailure: (
      @Sendable (_ error: any Error, _ send: Send<Action>) async -> Void
    )? = nil,
    lockAction: A,
    boundaryId: B,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)? = nil,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
  ) -> Effect<Action> {
    let actionId = lockAction.lockmanInfo.actionId
    // Capture the reducer-level condition to avoid type inference issues
    let reducerLevelCondition = self.lockCondition

    return withLockStep1Step2(
      state: state,
      action: action,
      actionId: actionId,
      boundaryId: boundaryId,
      lockCondition: lockCondition,
      reducerCondition: reducerLevelCondition,
      lockFailure: lockFailure,
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    ) { unlockToken in
      // Step 3: Traditional withLock using the specified strategy with manual unlock
      return withLockStep3(
        priority: priority,
        unlockOption: unlockOption,
        handleCancellationErrors: handleCancellationErrors,
        action: lockAction,
        boundaryId: boundaryId,
        unlockToken: unlockToken,
        lockFailure: lockFailure,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        automaticUnlock: false,
        operation: operation,
        handler: handler
      )
    }
  }
}
