import Foundation

/// Protocol for cancellation errors in Lockman strategies.
///
/// This protocol provides a common interface for all cancellation-related errors
/// across different Lockman strategies. Each strategy can implement this protocol
/// to provide strategy-specific cancellation information while maintaining
/// a consistent error interface.
///
/// ## Topics
/// ### Required Properties
/// - ``lockmanInfo``
/// - ``boundaryId``
/// - ``errorDescription``
/// - ``failureReason``
public protocol LockmanCancellationError: LockmanError {
  /// The lock information that was cancelled.
  var lockmanInfo: any LockmanInfo { get }

  /// The boundary where the cancellation occurred.
  var boundaryId: any LockmanBoundaryId { get }

  /// A localized message describing what error occurred.
  /// Conforming types should provide a user-friendly description of the cancellation.
  var errorDescription: String? { get }

  /// A localized message describing the reason for the failure.
  /// Conforming types should provide detailed information about why the lock was cancelled.
  var failureReason: String? { get }
}
