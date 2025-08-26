import ComposableArchitecture

// MARK: - Internal Implementation for Lockman Effects

extension Effect {
  /// Attempts to acquire a lock using pre-captured lockmanInfo for consistent uniqueId handling.
  ///
  /// ## Lock Acquisition Protocol with UniqueId Consistency
  /// This method implements the core lock acquisition logic with guaranteed uniqueId consistency:
  /// 1. **Pre-captured LockmanInfo**: Uses lockmanInfo captured once at entry points
  /// 2. **Feasibility Check**: Call `canLock` to determine if lock can be acquired
  /// 3. **Early Exit**: Return appropriate result if lock acquisition is not possible
  /// 4. **Lock Acquisition**: Call `lock` to actually acquire the lock
  /// 5. **Consistent UniqueId**: Same lockmanInfo instance ensures unlock will succeed
  ///
  /// ## Boundary Lock Protection
  /// The entire lock acquisition process is protected by a boundary-specific lock
  /// to ensure atomicity and prevent race conditions between:
  /// - Multiple lock acquisition attempts
  /// - Lock acquisition and release operations
  /// - Cleanup and acquisition operations
  ///
  /// ## Cancellation Strategy
  /// When `canLock` returns `.successWithPrecedingCancellation`:
  /// 1. A cancellation effect is created for the specified boundaryId
  /// 2. The cancellation effect is concatenated BEFORE the main effect
  /// 3. This ensures proper ordering: cancel existing → execute new
  ///
  /// ## Performance Notes
  /// - Lock feasibility check is typically O(1) hash lookup
  /// - Boundary lock acquisition is brief (microseconds)
  /// - Effect concatenation has minimal overhead
  ///
  /// - Parameters:
  ///   - lockmanInfo: Pre-captured lock information ensuring consistent uniqueId throughout lifecycle
  ///   - boundaryId: Boundary identifier for this lock and cancellation
  /// - Returns: LockmanResult indicating lock acquisition status
  func acquireLock<B: LockmanBoundaryId, I: LockmanInfo>(
    lockmanInfo: I,
    boundaryId: B
  ) throws -> LockmanResult {
    // Resolve the strategy from the container using lockmanInfo.strategyId
    let strategy: AnyLockmanStrategy<I> = try LockmanManager.container.resolve(
      id: lockmanInfo.strategyId,
      expecting: I.self
    )

    // Acquire lock with boundary protection
    return LockmanManager.withBoundaryLock(for: boundaryId) {
      // Check if lock can be acquired
      let result = strategy.canLock(
        boundaryId: boundaryId,
        info: lockmanInfo
      )

      // Handle immediate unlock for preceding cancellation
      if case .successWithPrecedingCancellation(let cancellationError) = result {
        // Immediately unlock the cancelled action to prevent resource leaks
        // Only unlock if the cancelled action has compatible lock info type
        if let cancelledInfo = cancellationError.lockmanInfo as? I {
          strategy.unlock(boundaryId: cancellationError.boundaryId, info: cancelledInfo)
        }
      }

      // Early exit if lock cannot be acquired
      if case .cancel = result {
        return result
      }

      // Actually acquire the lock
      strategy.lock(
        boundaryId: boundaryId,
        info: lockmanInfo
      )

      // Return the result
      return result
    }
  }

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
            .run { send in await handler(cancellationError, send) },
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
        if let handler = handler {
          return .run { send in
            await handler(cancellationError, send)
          }
        }
        return .none
      @unknown default:
        return .none
      }

    } catch {
      // Handle and report strategy resolution errors
      Effect.handleError(
        error: error,
        fileID: fileID,
        filePath: filePath,
        line: line,
        column: column
      )
      if let handler = handler {
        return .run { send in
          await handler(error, send)
        }
      }
      return .none
    }
  }

  /// Handles errors that occur during lock operations and provides appropriate diagnostic messages.
  ///
  /// ## Error Analysis and Reporting
  /// This method examines the error type and generates context-aware diagnostic messages
  /// that help developers identify and resolve issues with lock management operations.
  /// The diagnostics include:
  /// - **Source Location**: Exact file, line, and column where error occurred
  /// - **Error Context**: Specific action type and strategy type involved
  /// - **Resolution Guidance**: Concrete steps to fix the issue
  /// - **Code Examples**: Sample code showing correct usage
  ///
  /// ## Supported Error Types
  /// Currently handles `LockmanError` types with specific guidance:
  /// - **Strategy Not Registered**: Provides registration example
  /// - **Strategy Already Registered**: Explains registration constraints
  /// - **Future Extensions**: Framework for additional error types
  ///
  /// ## Development vs Production
  /// In development builds, detailed diagnostics are provided to help developers
  /// identify and fix issues quickly. In production, error handling is minimal
  /// to avoid exposing internal details.
  ///
  /// ## Integration with Xcode
  /// The `reportIssue` function integrates with Xcode's issue navigator,
  /// providing clickable error messages that jump directly to the problematic code.
  ///
  /// - Parameters:
  ///   - error: Error that was thrown during lock operation
  ///   - fileID: File identifier where error originated (auto-populated)
  ///   - filePath: Full file path where error originated (auto-populated)
  ///   - line: Line number where error originated (auto-populated)
  ///   - column: Column number where error originated (auto-populated)
  ///   - reporter: Issue reporter to use (defaults to LockmanManager.config.issueReporter)
  static func handleError(
    error: any Error,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt,
    reporter: any LockmanIssueReporter.Type = LockmanManager.config.issueReporter
  ) {
    // Check if the error is a known LockmanRegistrationError type
    if let error = error as? LockmanRegistrationError {
      switch error {
      case .strategyNotRegistered(let strategyType):
        reporter.reportIssue(
          "Effect.lock strategy '\(strategyType)' not registered. Register before use.",
          file: fileID,
          line: line
        )

      case .strategyAlreadyRegistered(let strategyType):
        reporter.reportIssue(
          "Effect.lock strategy '\(strategyType)' already registered.",
          file: fileID,
          line: line
        )
      @unknown default:
        break
      }
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
      let lockResult = try effect.acquireLock(
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
      handleError(
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

      // Create a dummy effect for lock acquisition (we don't use it for actual execution)
      let dummyEffect: Effect<Action> = .none

      // Acquire lock using the captured lockmanInfo (consistent uniqueId)
      let lockResult = try dummyEffect.acquireLock(
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
        if let lockFailure = lockFailure {
          return .run { send in
            await lockFailure(error, send)
          }
        } else {
          // No lock failure handler - return .none (effect is cancelled)
          return .none
        }
      }
    } catch {
      // Handle and report strategy resolution errors
      Effect.handleError(
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
  }

}
