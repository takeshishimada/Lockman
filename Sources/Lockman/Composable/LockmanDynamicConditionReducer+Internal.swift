import CasePaths
import ComposableArchitecture
import Foundation

// MARK: - Supporting Data Structures

/// Represents which step failed during condition evaluation
@usableFromInline
enum FailedStep: Sendable {
  case dynamicLockCondition  // Step 1: Reducer-level dynamic condition
  case lockCondition  // Step 2: Individual lock call condition
}

/// Result of evaluating dynamic conditions
@usableFromInline
enum ConditionEvaluationResult: Sendable {
  case success
  case successWithPrecedingCancellation(precedingError: any Error)
  case failure(reason: any Error, step: FailedStep)
}

/// Result of evaluating a single condition
@usableFromInline
enum SingleConditionResult: Sendable {
  case success
  case successWithPrecedingCancellation(any Error)
  case failure(any Error)
}

// MARK: - Lock Implementation Extensions

extension LockmanDynamicConditionReducer {

  // MARK: - Layer 1: Condition Evaluation

  /// Evaluates dynamic conditions for both reducer-level and action-level with proper lock cleanup.
  ///
  /// This method handles the two-stage dynamic lock process:
  /// 1. Reducer-level condition evaluation (dynamic lock condition)
  /// 2. Action-level condition evaluation (lock call condition)
  ///
  /// Important: This method only evaluates conditions and reports which step failed.
  /// The caller is responsible for cleanup based on the failure information.
  ///
  /// - Parameters:
  ///   - dynamicLockCondition: Optional dynamic condition applied to all actions in this reducer
  ///   - lockCondition: Optional condition specific to this lock call
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - dynamicStrategy: Strategy for dynamic condition locks (Step 1)
  ///   - actionStrategy: Strategy for action-specific locks (Step 2)
  ///   - lockmanAction: Action providing lock information
  ///   - actionId: Action identifier for lock management
  ///   - boundaryId: Boundary identifier for lock management
  /// - Returns: Result indicating whether all conditions passed
  @usableFromInline
  func evaluateConditions<B: LockmanBoundaryId, A: LockmanAction>(
    dynamicLockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    state: State,
    action: Action,
    dynamicStrategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionStrategy: AnyLockmanStrategy<A.I>,
    lockmanInfo: A.I,
    lockmanAction: A,
    actionId: LockmanActionId,
    boundaryId: B
  ) -> ConditionEvaluationResult {

    // Step 1: Evaluate dynamic lock condition (reducer-level)
    let dynamicConditionResult = evaluateSingleCondition(
      condition: dynamicLockCondition,
      state: state,
      action: action,
      strategy: dynamicStrategy,
      actionId: actionId,
      boundaryId: boundaryId
    )

    // Track any preceding cancellation errors
    var precedingCancellationError: (any Error)? = nil

    switch dynamicConditionResult {
    case .failure(let error):
      return .failure(reason: error, step: .dynamicLockCondition)
    case .success:
      // No preceding cancellation
      break
    case .successWithPrecedingCancellation(let error):
      // Store the preceding cancellation error
      precedingCancellationError = error
    }

    // Step 2: Evaluate lock call condition
    let lockConditionResult = evaluateSingleCondition(
      condition: lockCondition,
      state: state,
      action: action,
      strategy: actionStrategy,
      lockmanInfo: lockmanInfo,
      lockmanAction: lockmanAction,
      actionId: actionId,
      boundaryId: boundaryId
    )

    switch lockConditionResult {
    case .failure(let error):
      return .failure(reason: error, step: .lockCondition)
    case .success:
      // Check if we have a preceding cancellation error from step 1
      if let precedingError = precedingCancellationError {
        return .successWithPrecedingCancellation(precedingError: precedingError)
      }
      return .success
    case .successWithPrecedingCancellation(let error):
      // Use the most recent preceding cancellation error (step 2 takes precedence)
      return .successWithPrecedingCancellation(precedingError: error)
    }
  }

  /// Evaluates a single dynamic condition and attempts lock acquisition.
  ///
  /// - Parameters:
  ///   - condition: Optional condition to evaluate
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - strategy: Strategy for dynamic condition locks
  ///   - actionId: Action identifier for lock management
  ///   - boundaryId: Boundary identifier for lock management
  /// - Returns: Result indicating success, failure, or success with preceding cancellation
  @usableFromInline
  func evaluateSingleCondition<B: LockmanBoundaryId>(
    condition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    state: State,
    action: Action,
    strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionId: LockmanActionId,
    boundaryId: B
  ) -> SingleConditionResult {

    // If no condition provided, consider it successful
    guard let condition = condition else {
      return .success
    }

    // Create dynamic condition info
    let dynamicInfo = LockmanDynamicConditionInfo(
      actionId: actionId,
      condition: { condition(state, action) }
    )

    // Check condition and acquire lock if successful using direct info overload
    let effectForLock: Effect<Action> = .none

    do {
      let result = try effectForLock.acquireLock(
        lockmanInfo: dynamicInfo,
        strategyId: .dynamicCondition,
        boundaryId: boundaryId
      )

      // Handle result
      switch result {
      case .cancel(let error):
        return .failure(error)
      case .successWithPrecedingCancellation(let error):
        // Lock acquired but with preceding cancellation
        return .successWithPrecedingCancellation(error)
      case .success:
        return .success
      @unknown default:
        return .success
      }
    } catch {
      return .failure(error)
    }
  }

  /// Evaluates a single condition and attempts lock acquisition using a generic strategy.
  ///
  /// This overload allows evaluation with different strategy types beyond just dynamic conditions.
  /// It's designed to work with action-specific strategies that use their own LockmanInfo types.
  ///
  /// - Parameters:
  ///   - condition: Optional condition to evaluate
  ///   - state: Current state for condition evaluation
  ///   - action: Current action for condition evaluation
  ///   - strategy: Strategy for lock management (generic type)
  ///   - lockmanAction: Action providing lock information for the strategy
  ///   - actionId: Action identifier for lock management
  ///   - boundaryId: Boundary identifier for lock management
  /// - Returns: Result indicating success, failure, or success with preceding cancellation
  @usableFromInline
  func evaluateSingleCondition<B: LockmanBoundaryId, A: LockmanAction>(
    condition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    state: State,
    action: Action,
    strategy: AnyLockmanStrategy<A.I>,
    lockmanInfo: A.I,
    lockmanAction: A,
    actionId: LockmanActionId,
    boundaryId: B
  ) -> SingleConditionResult {

    // If no condition provided, consider it successful
    guard let condition = condition else {
      return .success
    }

    // Evaluate condition first
    let conditionResult = condition(state, action)
    switch conditionResult {
    case .cancel(let error):
      return .failure(error)
    case .success:
      // Condition passed, proceed with lock acquisition
      break
    case .successWithPrecedingCancellation:
      // Store the error for later handling, but proceed with lock acquisition
      // This will be properly handled by the lock acquisition result
      break
    @unknown default:
      break
    }

    // Check condition and acquire lock if successful using the provided action
    let effectForLock: Effect<Action> = .none
    do {
      let result = try effectForLock.acquireLock(
        lockmanInfo: lockmanInfo,
        strategyId: lockmanInfo.strategyId,
        boundaryId: boundaryId
      )

      // Handle result
      switch result {
      case .cancel(let error):
        return .failure(error)
      case .successWithPrecedingCancellation(let error):
        // Lock acquired but with preceding cancellation
        return .successWithPrecedingCancellation(error)
      case .success:
        return .success
      @unknown default:
        return .success
      }
    } catch {
      return .failure(error)
    }
  }

  // MARK: - Step 3: Effect Construction with Condition Handling

  /// Builds a lock effect with condition evaluation result handling.
  ///
  /// This method handles Step 3 of the dynamic lock process: creating an effect based on
  /// the condition evaluation results and executing the operation with proper cleanup.
  ///
  /// In Pure Dynamic Condition architecture, both dynamic and action strategies may acquire locks
  /// during condition evaluation, so both need proper cleanup handling.
  ///
  /// - Parameters:
  ///   - conditionResult: Result from Step 2 condition evaluation
  ///   - dynamicStrategy: Strategy for dynamic condition locks (Step 1)
  ///   - actionStrategy: Strategy for action-specific locks (Step 2)
  ///   - actionId: Action identifier for unlock token creation
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - lockAction: LockmanAction providing lock information
  ///   - boundaryId: Boundary identifier for lock management
  ///   - priority: Task priority for the operation
  ///   - operation: Async closure receiving `send` function for dispatching actions
  ///   - handler: Optional error handler receiving error and send function
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - fileID: Source file identifier for debugging
  ///   - filePath: Source file path for debugging
  ///   - line: Source line number for debugging
  ///   - column: Source column number for debugging
  /// - Returns: Effect that executes based on condition evaluation results
  @usableFromInline
  func buildLockEffect<B: LockmanBoundaryId, LA: LockmanAction>(
    conditionResult: ConditionEvaluationResult,
    dynamicStrategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionStrategy: AnyLockmanStrategy<LA.I>,
    actionId: LockmanActionId,
    unlockOption: LockmanUnlockOption,
    lockmanInfo: LA.I,
    lockAction: LA,
    boundaryId: B,
    priority: TaskPriority?,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) -> Effect<Action> {

    // Create unlock tokens for both strategies
    let dynamicUnlockToken = LockmanUnlock(
      id: boundaryId,
      info: LockmanDynamicConditionInfo(actionId: actionId),
      strategy: dynamicStrategy,
      unlockOption: unlockOption
    )

    let actionUnlockToken = LockmanUnlock(
      id: boundaryId,
      info: lockmanInfo,
      strategy: actionStrategy,
      unlockOption: unlockOption
    )

    // Create base effect with conditional cancellation ID based on action design intent
    let shouldBeCancellable = lockmanInfo.isCancellationTarget
    let baseEffect = Effect<Action>.run(
      priority: priority,
      operation: { send in
        // Handle cleanup for both dynamic and action locks
        defer {
          // Clean up both locks when operation completes
          dynamicUnlockToken()
          actionUnlockToken()
        }

        // Execute the operation directly - no business lock management here
        try await withTaskCancellation(id: boundaryId) {
          try await operation(send)
        }
      },
      catch: { error, send in
        // Error handling with cleanup for both locks
        dynamicUnlockToken()
        actionUnlockToken()
        await handler?(error, send)
      },
      fileID: fileID,
      filePath: filePath,
      line: line,
      column: column
    )

    // Apply cancellable modifier conditionally based on action design intent
    let conditionallyLockCancellableEffect =
      shouldBeCancellable
      ? baseEffect.cancellable(id: boundaryId)
      : baseEffect

    // Handle condition evaluation result
    switch conditionResult {
    case .success:
      // Direct execution
      return conditionallyLockCancellableEffect

    case .successWithPrecedingCancellation(let precedingError):
      // Handle preceding cancellation at Dynamic Condition level
      // This is separate from Business Lock level precedingError handling
      let cancellationError = LockmanCancellationError(
        action: lockAction,
        boundaryId: boundaryId,
        reason: precedingError as? any LockmanError
          ?? LockmanRegistrationError.strategyNotRegistered("Unknown error type")
      )

      // Build effects array conditionally
      var effects: [Effect<Action>] = []

      // Add failure handler if provided
      if let lockFailure = lockFailure {
        effects.append(
          .run { send in
            await lockFailure(cancellationError, send)
          })
      }

      // Always add cancellation and main effect
      effects.append(.cancel(id: boundaryId))
      effects.append(conditionallyLockCancellableEffect)

      return .concatenate(effects)

    case .failure(let error, let step):
      // Clean up locks based on which step failed
      // If step 1 (dynamic lock condition) succeeds but step 2 (lock call condition) fails,
      // we need to unlock step 1's locks
      if step == .lockCondition {
        dynamicUnlockToken()
      }
      // Note: If step 2 fails, action lock was never acquired, so no need to unlock it

      if let lockFailure = lockFailure {
        // Wrap the error with action context for better debugging
        let cancellationError = LockmanCancellationError(
          action: lockAction,
          boundaryId: boundaryId,
          reason: error as? any LockmanError
            ?? LockmanRegistrationError.strategyNotRegistered("Unknown error type")
        )
        return .run { send in
          await lockFailure(cancellationError, send)
        }
      }
      return .none
    }
  }

}
