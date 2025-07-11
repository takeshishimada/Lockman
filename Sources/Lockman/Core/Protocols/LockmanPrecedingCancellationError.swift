import Foundation

/// Protocol for errors that provide information about preceding actions being cancelled.
///
/// This protocol enables standardized access to `LockmanInfo` and boundary information
/// from errors that occur in `successWithPrecedingCancellation` scenarios. It supports
/// immediate unlock operations for cancelled preceding actions.
///
/// ## Purpose
/// When a new action causes existing preceding actions to be cancelled, this protocol
/// provides a unified way to:
/// - Access the `LockmanInfo` of the cancelled preceding action
/// - Retrieve the boundary identifier where the cancellation occurred
/// - Enable immediate unlock operations without `UnlockOption` delays
///
/// ## Usage
/// ```swift
/// if case .successWithPrecedingCancellation(let error) = result,
///    let cancellationError = error as? LockmanPrecedingCancellationError,
///    let cancelledInfo = cancellationError.lockmanInfo as? I {
///     strategy.unlock(boundaryId: cancellationError.boundaryId, info: cancelledInfo)
/// }
/// ```
///
/// ## Implementation Requirements
/// Types conforming to this protocol must:
/// - Provide access to the `LockmanInfo` of the cancelled preceding action
/// - Provide the boundary identifier where the cancellation occurred
/// - Be used only in `successWithPrecedingCancellation` contexts
///
/// ## Design Principle
/// This protocol uses simple property access rather than complex methods,
/// making the interface clear and implementation straightforward.
public protocol LockmanPrecedingCancellationError: LockmanError {
  /// The LockmanInfo of the preceding action being cancelled.
  ///
  /// This property provides access to the lock information of the action
  /// that is being cancelled due to the new action's precedence. This
  /// information is used for immediate unlock operations.
  ///
  /// ## Usage
  /// ```swift
  /// let cancelledInfo = cancellationError.lockmanInfo
  /// if let specificInfo = cancelledInfo as? LockmanPriorityBasedInfo {
  ///   // Use the specific lock information for unlock
  ///   strategy.unlock(boundaryId: boundaryId, info: specificInfo)
  /// }
  /// ```
  var lockmanInfo: any LockmanInfo { get }

  /// The boundary identifier where the cancellation occurred.
  ///
  /// This property provides the boundary context for the cancellation,
  /// enabling precise unlock operations. The boundary identifier
  /// corresponds to the scope where the preceding action was cancelled.
  ///
  /// ## Usage
  /// ```swift
  /// let boundaryId = cancellationError.boundaryId
  /// strategy.unlock(boundaryId: boundaryId, info: lockmanInfo)
  /// ```
  var boundaryId: any LockmanBoundaryId { get }
}
