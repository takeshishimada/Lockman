import Foundation

// MARK: - LockmanStrategyError

/// A protocol that all strategy-specific errors must conform to.
///
/// This protocol provides a unified interface for errors that occur within
/// Lockman strategies, ensuring consistent error handling and debugging capabilities
/// across all strategy implementations.
///
/// ## Common Properties
/// All strategy errors provide:
/// - `lockmanInfo`: Information about the action involved in the error
/// - `boundaryId`: The boundary where the error occurred (if applicable)
///
/// ## Usage Example
/// ```swift
/// func handleStrategyError(_ error: any LockmanStrategyError) {
///   print("Strategy error: \(error.localizedDescription)")
///   print("Action: \(error.lockmanInfo.actionId)")
///   if let boundaryId = error.boundaryId {
///     print("Boundary: \(boundaryId)")
///   }
/// }
/// ```
public protocol LockmanStrategyError: LockmanError {
  /// Information about the action involved in the error.
  ///
  /// This typically represents the action that was affected by the error,
  /// such as the action that was rejected, cancelled, or caused a conflict.
  var lockmanInfo: any LockmanInfo { get }

  /// The boundary identifier where the error occurred.
  ///
  /// All strategy errors occur within a specific boundary context,
  /// so this is always available for debugging and error handling.
  var boundaryId: any LockmanBoundaryId { get }
}
