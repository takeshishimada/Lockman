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
  ///   - strategy: Strategy for dynamic condition locks
  ///   - actionId: Action identifier for lock management
  ///   - boundaryId: Boundary identifier for lock management
  /// - Returns: Result indicating whether all conditions passed
  @usableFromInline
  func evaluateConditions<B: LockmanBoundaryId>(
    dynamicLockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    lockCondition: (@Sendable (_ state: State, _ action: Action) -> LockmanResult)?,
    state: State,
    action: Action,
    strategy: AnyLockmanStrategy<LockmanDynamicConditionInfo>,
    actionId: LockmanActionId,
    boundaryId: B
  ) -> ConditionEvaluationResult {

    // Step 1: Evaluate dynamic lock condition (reducer-level)
    let dynamicConditionResult = evaluateSingleCondition(
      condition: dynamicLockCondition,
      state: state,
      action: action,
      strategy: strategy,
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
      strategy: strategy,
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

    // Check condition and acquire lock if successful
    let result = Effect<Action>.acquireLock(
      lockmanInfo: dynamicInfo,
      strategy: strategy,
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
  }

  // MARK: - Step 3: Effect Construction with Condition Handling

  /// Builds a lock effect with condition evaluation result handling.
  ///
  /// This method handles Step 3 of the dynamic lock process: creating an effect based on
  /// the condition evaluation results and executing the operation with proper cleanup.
  ///
  /// - Parameters:
  ///   - conditionResult: Result from Step 2 condition evaluation
  ///   - unlockToken: Unlock token for dynamic condition locks
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
    unlockToken: LockmanUnlock<B, LockmanDynamicConditionInfo>,
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

    // Create base effect with conditional cancellation ID based on action design intent
    let shouldBeCancellable = lockAction.lockmanInfo.isCancellationTarget
    let baseEffect = Effect<Action>.run(
      priority: priority,
      operation: { send in
        // Only handle dynamic condition lock cleanup
        defer { unlockToken() }

        // Execute the operation directly - no business lock management here
        try await withTaskCancellation(id: boundaryId) {
          try await operation(send)
        }
      },
      catch: { error, send in
        // Error handling with dynamic lock cleanup
        unlockToken()
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
      if let lockFailure = lockFailure {
        let cancellationError = LockmanCancellationError(
          action: lockAction,
          boundaryId: boundaryId,
          reason: precedingError as! any LockmanError
        )
        return .concatenate(
          .run { send in
            await lockFailure(cancellationError, send)
          },
          .cancel(id: boundaryId),
          conditionallyLockCancellableEffect
        )
      }

      // No failure handler provided, just cancel and proceed
      return .concatenate(
        .cancel(id: boundaryId),
        conditionallyLockCancellableEffect
      )

    case .failure(let error, let step):
      // Clean up dynamic locks based on which step failed
      // If step 1 (dynamic lock condition) succeeds but step 2 (lock call condition) fails,
      // we need to unlock step 1's locks
      if step == .lockCondition {
        unlockToken()
      }

      if let lockFailure = lockFailure {
        // Wrap the error with action context for better debugging
        let cancellationError = LockmanCancellationError(
          action: lockAction,
          boundaryId: boundaryId,
          reason: error as! any LockmanError
        )
        return .run { send in
          await lockFailure(cancellationError, send)
        }
      }
      return .none
    }
  }

}
