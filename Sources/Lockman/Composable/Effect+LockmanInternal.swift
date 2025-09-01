import ComposableArchitecture

// MARK: - Internal Error Types

/// Internal errors that can occur during Effect lock management.
internal enum LockmanInternalError: Error, CustomStringConvertible {
  case missingUnlockToken(action: any LockmanAction, boundaryId: any LockmanBoundaryId)
  
  var description: String {
    switch self {
    case .missingUnlockToken(let action, let boundaryId):
      return "Missing unlock token for successful lock result. Action: \(action), BoundaryId: \(boundaryId)"
    }
  }
}

// MARK: - Internal Implementation for Lockman Effects

extension Effect {


  // MARK: - Shared Lock Implementation

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
  /// Effect.lock(effectBuilder: { concatenatedEffect }, ...)
  ///
  /// // Dynamic effect creation
  /// Effect.lock(effectBuilder: { .run { ... } }, ...)
  ///
  /// // Reducer with inout state
  /// Effect.lock(effectBuilder: { self.base.reduce(into: &state, action: action) }, ...)
  /// ```
  ///
  /// - Parameters:
  ///   - effectBuilder: Non-escaping closure that creates the effect (only called on lock success)
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
    effectBuilder: () -> Effect<Action>,
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

      // Acquire lock with integrated unlock token (type-safe design)
      let result = try LockmanManager.acquireLock(
        lockmanInfo: lockmanInfo,
        boundaryId: boundaryId,
        unlockOption: unlockOption ?? action.unlockOption
      )

      // Handle lock result with type-safe pattern matching
      switch result {
      case .success(let unlockToken):
        // Lock acquired successfully - execute effect with unlock
        // No guard statement needed - unlockToken guaranteed by type system
        let baseEffect = effectBuilder()
        let unlockEffect = Effect<Action>.run { _ in unlockToken() }
        let shouldBeCancellable = lockmanInfo.isCancellationTarget
        let cancellableEffect = shouldBeCancellable ? baseEffect.cancellable(id: boundaryId) : baseEffect
        return Effect<Action>.concatenate([cancellableEffect, unlockEffect])

      case .successWithPrecedingCancellation(let unlockToken, let error):
        // Lock acquired with cancellation - execute effect with cancellation handling
        // Both unlockToken and error guaranteed by type system
        let baseEffect = effectBuilder()
        let unlockEffect = Effect<Action>.run { _ in unlockToken() }
        let shouldBeCancellable = lockmanInfo.isCancellationTarget
        let cancellableEffect = shouldBeCancellable ? baseEffect.cancellable(id: boundaryId) : baseEffect
        let completeEffect = Effect<Action>.concatenate([cancellableEffect, unlockEffect])
        
        let cancellationError = LockmanCancellationError(action: action, boundaryId: boundaryId, reason: error)
        if let lockFailure = lockFailure {
          return .concatenate([
            Effect.createHandlerEffect(handler: lockFailure, error: cancellationError),
            .cancel(id: boundaryId),
            completeEffect,
          ])
        }
        return .concatenate([.cancel(id: boundaryId), completeEffect])

      case .cancel(let error):
        // Lock failed - do NOT execute effect builder (lock-first behavior)
        // No unlockToken exists - guaranteed by type system
        let cancellationError = LockmanCancellationError(action: action, boundaryId: boundaryId, reason: error)
        return Effect.createHandlerEffect(handler: lockFailure, error: cancellationError)
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
