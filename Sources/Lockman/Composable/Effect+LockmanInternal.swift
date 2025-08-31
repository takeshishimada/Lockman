import ComposableArchitecture

// MARK: - Internal Implementation for Lockman Effects

extension Effect {

  /// Builds an effect with lock acquisition and automatic unlock using pre-captured lockmanInfo.
  ///
  /// ## Purpose & UniqueId Consistency
  /// This internal method contains the common logic shared by all lock variants:
  /// 1. Strategy resolution from the container
  /// 2. Use of pre-captured lockmanInfo to ensure consistent uniqueId
  /// 3. Lock acquisition and result handling with guaranteed unlock capability
  /// 4. Direct effect concatenation with unlock effect using same lockmanInfo instance
  ///
  /// ## Simplified Architecture
  /// This method directly creates the unlock effect and concatenates it with the operations,
  /// eliminating the need for complex closure patterns and intermediate wrappers.
  ///
  /// ## Error Handling Strategy
  /// This method uses a do-catch pattern to handle strategy resolution errors.
  /// If strategy resolution fails, it calls `handleError` to provide detailed
  /// diagnostic information and optionally calls the provided handler before
  /// returning `.none` to prevent effect execution.
  ///
  /// ## Type Safety
  /// The method maintains type safety through generic constraints:
  /// - `B: LockmanBoundaryId`: Ensures valid boundary identifier
  /// - `A: LockmanAction`: Ensures valid action with lock information
  /// - `A.I`: Preserves lock information type relationship
  ///
  /// ## Effect Execution Order
  /// The returned effect executes in this order:
  /// 1. Operations (cancellable as a group)
  /// 2. Unlock effect (non-cancellable, always executes)
  ///
  /// - Parameters:
  ///   - lockResult: Result from prior lock acquisition attempt (must be provided)
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - lockmanInfo: Pre-captured lock information ensuring consistent uniqueId for unlock operations
  ///   - boundaryId: Unique identifier for cancellation and lock boundary
  ///   - unlockOption: Unlock option configuration for when to execute the unlock
  ///   - fileID: Source file ID for error reporting
  ///   - filePath: Source file path for error reporting
  ///   - line: Source line number for error reporting
  ///   - column: Source column number for error reporting
  ///   - handler: Optional error handler for lock acquisition failures
  /// - Returns: Built effect with lock management, or `.none` if setup fails
  func buildLockEffect<B: LockmanBoundaryId, A: LockmanAction, I: LockmanInfo>(
    lockResult: LockmanResult,
    action: A,
    lockmanInfo: I,
    boundaryId: B,
    unlockOption: LockmanUnlockOption,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil
  ) -> Effect<Action> {
    do {
      // Resolve the strategy from the container using strategyId
      let strategy: AnyLockmanStrategy<I> = try LockmanManager.container.resolve(
        id: lockmanInfo.strategyId,
        expecting: I.self
      )
      // Note: lockmanInfo parameter is the pre-captured instance ensuring consistent uniqueId

      // Create unlock token using the same lockmanInfo instance (guaranteed successful unlock)
      let unlockToken = LockmanUnlock(
        id: boundaryId,
        info: lockmanInfo,
        strategy: strategy,
        unlockOption: unlockOption
      )

      // Create unlock effect that executes the unlock operation
      let unlockEffect = Effect<Action>.run { _ in
        unlockToken()  // Execute unlock with configured option
      }

      // Create complete effect with conditional cancellation for operations only
      let shouldBeCancellable = lockmanInfo.isCancellationTarget
      let cancellableEffect = shouldBeCancellable ? self.cancellable(id: boundaryId) : self
      let completeEffect = Effect<Action>.concatenate([cancellableEffect, unlockEffect])

      // Handle lock acquisition result
      switch lockResult {
      case .success:
        // Lock acquired successfully, execute complete effect immediately
        return completeEffect

      case .successWithPrecedingCancellation(let error):
        // Lock acquired but need to cancel existing operation first
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        if let handler = handler {
          return .concatenate([
            Effect.createHandlerEffect(handler: handler, error: cancellationError),
            .cancel(id: boundaryId),
            completeEffect,
          ])
        }

        return .concatenate([.cancel(id: boundaryId), completeEffect])

      case .cancel(let error):
        // Lock acquisition failed
        // Wrap the strategy error with action context
        let cancellationError = LockmanCancellationError(
          action: action,
          boundaryId: boundaryId,
          reason: error
        )
        return Effect.createHandlerEffect(handler: handler, error: cancellationError)
      @unknown default:
        return .none
      }

    } catch {
      // Handle and report strategy resolution errors
      LockmanManager.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return Effect.createHandlerEffect(handler: handler, error: error)
    }
  }

  // MARK: - Shared Lock Implementation

  /// Internal shared implementation for applying lock management to effects.
  ///
  /// This method consolidates the common lock management logic used by both
  /// the static `lock(concatenating:)` method, the static `lock(operation:)` method,
  /// and LockmanReducer. By using a static method with an effect builder closure,
  /// we achieve true code reuse while maintaining flexibility for different use cases.
  ///
  /// ## Design Rationale
  /// This internal method serves as the single source of truth for lock management logic:
  /// - **Centralized Logic**: All lock acquisition, effect building, and error handling in one place
  /// - **Parameter Consistency**: All lock-related parameters are handled uniformly
  /// - **Maintenance Efficiency**: Bug fixes and enhancements only need to be made once
  /// - **Testing Focus**: Core logic can be tested through a single implementation path
  /// - **Flexibility**: Effect builder allows for conditional effect creation (used by LockmanReducer)
  ///
  /// ## Usage Pattern
  /// This method is called by various lock management components:
  /// ```swift
  /// // From Effect static methods
  /// Effect.lock(
  ///   effectBuilder: { Effect.concatenate(operations) },
  ///   action: action, boundaryId: boundaryId, ...
  /// )
  ///
  /// // From LockmanReducer (conditional effect creation)
  /// Effect.lock(
  ///   effectBuilder: {
  ///     lockResult.canProceed ? baseReducer.reduce() : Effect.none
  ///   },
  ///   action: action, boundaryId: boundaryId, ...
  /// )
  /// ```
  ///
  /// - Parameters:
  ///   - effectBuilder: Closure that creates the effect to be managed (called only if lock is successful)
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - fileID: Source file ID for debugging
  ///   - filePath: Source file path for debugging
  ///   - line: Source line number for debugging
  ///   - column: Source column number for debugging
  /// - Returns: Effect with automatic lock management
  internal static func lock<B: LockmanBoundaryId, A: LockmanAction>(
    effectBuilder: @escaping () -> Effect<Action>,
    action: A,
    boundaryId: B,
    unlockOption: LockmanUnlockOption?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) -> Effect<Action> {
    do {
      // ✨ CRITICAL: Create lockmanInfo once to ensure consistent uniqueId throughout lock lifecycle
      // This prevents lock/unlock mismatches that occur when methods are called multiple times
      let lockmanInfo = action.createLockmanInfo()

      // Create the effect that will be used for lock acquisition
      let effect = effectBuilder()

      // Acquire lock using the captured lockmanInfo (consistent uniqueId)
      let lockResult = try LockmanManager.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )

      // Build lock effect using the same lockmanInfo instance (guaranteed unlock)
      return effect.buildLockEffect(
        lockResult: lockResult,
        action: action,
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: unlockOption ?? action.unlockOption,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column,
        handler: lockFailure
      )
    } catch {
      // Handle and report strategy resolution errors
      LockmanManager.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return createHandlerEffect(handler: lockFailure, error: error)
    }
  }

  /// Unified internal implementation for all lock management scenarios.
  ///
  /// This method handles all lock management cases including:
  /// - Regular Effect operations (concatenating, single operation)
  /// - LockmanReducer with inout state parameters
  /// - Any custom effect creation scenarios
  ///
  /// By using a non-escaping closure, this implementation works with both
  /// pre-built effects and inout state parameters, providing a single
  /// unified lock management solution.
  ///
  /// ## Design Rationale
  /// - **Universal Compatibility**: Works with all effect creation patterns
  /// - **Non-escaping Safety**: Compatible with inout parameters and pre-built effects
  /// - **Lock-First Guarantee**: Effect creation only occurs after successful lock acquisition
  /// - **Centralized Logic**: Single implementation for all lock management needs
  ///
  /// ## Lock-First Behavior
  /// This implementation maintains true lock-first behavior:
  /// - Lock feasibility is checked BEFORE effect creation
  /// - Effects are created ONLY after successful lock acquisition
  /// - Lock failures prevent any effect creation or state changes
  ///
  /// ## Usage Patterns
  /// ```swift
  /// // Pre-built effects
  /// Effect.lock(reducer: { concatenatedEffect }, ...)
  ///
  /// // Dynamic effect creation
  /// Effect.lock(reducer: { .run { ... } }, ...)
  ///
  /// // Reducer with inout state
  /// Effect.lock(reducer: { self.base.reduce(into: &state, action: action) }, ...)
  /// ```
  ///
  /// - Parameters:
  ///   - reducer: Non-escaping closure that creates the effect (only called on lock success)
  ///   - action: LockmanAction providing lock information and strategy type
  ///   - boundaryId: Unique identifier for effect cancellation and lock boundary
  ///   - unlockOption: Controls when the unlock operation is executed
  ///   - lockFailure: Optional handler for lock acquisition failures
  ///   - fileID: Source file ID for debugging
  ///   - filePath: Source file path for debugging
  ///   - line: Source line number for debugging
  ///   - column: Source column number for debugging
  /// - Returns: Effect with automatic lock management
  internal static func lock<B: LockmanBoundaryId, A: LockmanAction>(
    reducer: () -> Effect<Action>,
    action: A,
    boundaryId: B,
    unlockOption: LockmanUnlockOption?,
    lockFailure: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) -> Effect<Action> {
    do {
      // ✨ CRITICAL: Create lockmanInfo once to ensure consistent uniqueId throughout lock lifecycle
      // This prevents lock/unlock mismatches that occur when methods are called multiple times
      let lockmanInfo = action.createLockmanInfo()

      // Note: We don't need a dummy effect for lock acquisition since we call LockmanManager directly

      // Acquire lock using the captured lockmanInfo (consistent uniqueId)
      let lockResult = try LockmanManager.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId
      )

      // Make decision based on lock result BEFORE executing reducer
      switch lockResult {
      case .success, .successWithPrecedingCancellation:
        // ✅ Lock can be acquired - proceed with reducer execution
        let baseEffect = reducer()  // Execute reducer with inout state access

        // Build effect with the existing lock result using same lockmanInfo (guaranteed unlock)
        return baseEffect.buildLockEffect(
          lockResult: lockResult,
          action: action,
          lockmanInfo: lockmanInfo,
          boundaryId: boundaryId,
          unlockOption: unlockOption ?? action.unlockOption,
          fileID: fileID,
          filePath: filePath,
          line: line,
          column: column,
          handler: lockFailure
        )

      case .cancel(let error):
        // ❌ Lock cannot be acquired - do NOT execute reducer
        // State mutations are prevented, achieving true lock-first behavior
        return Effect.createHandlerEffect(handler: lockFailure, error: error)
      }
    } catch {
      // Handle and report strategy resolution errors
      LockmanManager.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      return createHandlerEffect(handler: lockFailure, error: error)
    }
  }

  // MARK: - Private Helper Methods

  /// Creates an effect that calls the provided handler with the given error.
  /// Returns .none if handler is nil.
  private static func createHandlerEffect<T>(
    handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)?,
    error: T
  ) -> Effect<Action> where T: Error {
    guard let handler = handler else {
      return .none
    }
    return .run { send in
      await handler(error, send)
    }
  }

}
