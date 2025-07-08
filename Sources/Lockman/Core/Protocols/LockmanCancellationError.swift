import Foundation

// MARK: - LockmanCancellationError

/// A unified error structure that wraps strategy-specific errors with action context.
///
/// This structure provides a consistent way to handle cancellation scenarios across
/// different strategies, while preserving access to the original action that was
/// cancelled and the specific strategy error that caused the cancellation.
///
/// ## Purpose
/// When a lock acquisition fails or an existing action needs to be cancelled,
/// this error provides:
/// - The actual action instance that was cancelled (not just its ID)
/// - The boundary where the cancellation occurred
/// - The underlying strategy-specific error with detailed reason
///
/// ## Usage in Error Handlers
/// ```swift
/// lockFailure: { error, send in
///     if let cancellation = error as? LockmanCancellationError {
///         // Access the actual action that was cancelled
///         let action = cancellation.action
///
///         // Check the underlying strategy error
///         switch cancellation.reason {
///         case let singleError as LockmanSingleExecutionError:
///             // Handle single execution conflicts
///         case let priorityError as LockmanPriorityBasedError:
///             // Handle priority conflicts
///         default:
///             // Handle other errors
///         }
///     }
/// }
/// ```
public struct LockmanCancellationError: LockmanError {
  /// The action that was cancelled.
  ///
  /// This provides access to the full action instance, allowing error handlers
  /// to inspect the action type and properties to make informed decisions
  /// about how to handle the cancellation.
  public let action: any LockmanAction

  /// The boundary identifier where the cancellation occurred.
  ///
  /// This identifies the specific boundary context in which the action
  /// was cancelled, useful for debugging and scoped error handling.
  public let boundaryId: any LockmanBoundaryId

  /// The underlying strategy-specific error.
  ///
  /// This contains the detailed reason for cancellation as determined by
  /// the specific strategy (e.g., LockmanSingleExecutionError,
  /// LockmanPriorityBasedError, etc.)
  public let reason: any LockmanError

  /// Creates a new cancellation error.
  ///
  /// - Parameters:
  ///   - action: The action that was cancelled
  ///   - boundaryId: The boundary where cancellation occurred
  ///   - reason: The strategy-specific error explaining why
  public init(
    action: any LockmanAction,
    boundaryId: any LockmanBoundaryId,
    reason: any LockmanError
  ) {
    self.action = action
    self.boundaryId = boundaryId
    self.reason = reason
  }
}

// MARK: - LocalizedError Conformance

extension LockmanCancellationError: LocalizedError {
  public var errorDescription: String? {
    // Delegate to the underlying error's description
    reason.errorDescription
  }

  public var failureReason: String? {
    // Delegate to the underlying error's failure reason
    (reason as? LocalizedError)?.failureReason
  }
}
