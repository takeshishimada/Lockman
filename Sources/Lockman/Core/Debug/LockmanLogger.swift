import Foundation
import OSLog

/// Debug logger for Lockman output.
///
/// Provides thread-safe logging functionality for lock operations.
/// Optimized for DEBUG builds with fallback functionality in production builds.
@_spi(Logging)
public final class LockmanLogger: @unchecked Sendable {
  // MARK: - Singleton

  /// Shared logger instance
  public static let shared = LockmanLogger()

  // MARK: - Properties

  /// Flag to enable/disable logging
  private let _isEnabled = ManagedCriticalState(false)

  /// Public accessor for logging state
  public var isEnabled: Bool {
    get { _isEnabled.withCriticalRegion { $0 } }
    set {
      _isEnabled.withCriticalRegion { $0 = newValue }
      // Also update the internal Logger state
      Task { @MainActor in
        Logger.shared.isEnabled = newValue
      }
    }
  }

  // MARK: - Initialization

  private init() {}

  // MARK: - Logging Methods

  /// Logs a canLock operation result.
  ///
  /// - Parameters:
  ///   - result: The lock result (.success, .failure, .successWithPrecedingCancellation)
  ///   - strategy: The strategy type name
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock information
  ///   - reason: Optional failure reason
  ///   - cancelledInfo: Optional cancelled action information
  public func logCanLock<I: LockmanInfo>(
    result: LockmanStrategyResult,
    strategy: String,
    boundaryId: String,
    info: I,
    reason: String? = nil,
    cancelledInfo: (actionId: String, uniqueId: UUID)? = nil
  ) {
    #if DEBUG
      guard isEnabled else {
        return
      }

      let message: String
      switch result {
      case .success:
        message =
          "✅ [Lockman] canLock succeeded - Strategy: \(strategy), BoundaryId: \(boundaryId), Info: \(info.debugDescription)"

      case .cancel(_):
        let reasonStr = reason.map { ", Reason: \($0)" } ?? ""
        message =
          "❌ [Lockman] canLock failed - Strategy: \(strategy), BoundaryId: \(boundaryId), Info: \(info.debugDescription)\(reasonStr)"

      case .successWithPrecedingCancellation(let error):
        let cancelledStr =
          cancelledInfo.map { ", Cancelled: '\($0.actionId)' (uniqueId: \($0.uniqueId))" } ?? ""
        message =
          "⚠️ [Lockman] canLock succeeded with cancellation - Strategy: \(strategy), BoundaryId: \(boundaryId), Info: \(info.debugDescription)\(cancelledStr), Error: \(error)"
      }

      // Use Logger from Internal/Logger.swift
      Task { @MainActor in
        Logger.shared.log(message)
      }
    #endif
  }

  /// Logs current lock state information.
  ///
  /// This method is used internally by `printCurrentLocks` to output formatted lock information.
  /// Unlike other logging methods, this always prints to stdout when explicitly requested,
  /// even if debug logging is disabled.
  public func logLockState(_ message: String) {
    #if DEBUG
      guard isEnabled else {
        print(message)  // Always print lock state when explicitly requested
        return
      }
      Task { @MainActor in
        Logger.shared.log(message)
      }
    #else
      // In release builds, we still want to print the lock state when explicitly requested
      print(message)
    #endif
  }
}
