import Foundation

/// Debug utilities for LockmanManager.
///
/// Provides methods for debugging lock state and enabling/disabling debug logging.
extension LockmanManager {
  /// Debug utilities namespace.
  public enum debug {
    // MARK: - Logging Control

    /// Controls whether debug logging is enabled.
    ///
    /// When enabled (DEBUG builds only), Lockman will log all canLock operations
    /// with their results, strategies, boundary IDs, and lock information.
    ///
    /// ## Example
    /// ```swift
    /// // Enable debug logging
    /// LockmanManager.debug.isLoggingEnabled = true
    ///
    /// // Your lock operations will now be logged
    /// let result = strategy.canLock(id: boundaryId, info: lockInfo)
    /// // Logs: ✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: mainScreen, Info: ...
    /// ```
    public static var isLoggingEnabled: Bool {
      get { LockmanLogger.shared.isEnabled }
      set { LockmanLogger.shared.isEnabled = newValue }
    }

    // MARK: - Lock State Inspection

    /// Prints the current lock state for all registered strategies.
    ///
    /// This method displays a formatted table showing all active locks across
    /// all strategies and boundaries. The output includes detailed information
    /// about each lock, making it easy to debug lock-related issues.
    ///
    /// ## Output Format
    /// The method prints a table with the following columns:
    /// - Strategy: The strategy type (e.g., SingleExecution, PriorityBased)
    /// - BoundaryId: The boundary identifier where the lock is held
    /// - ActionId/UniqueId: The action identifier and unique ID of the lock
    /// - Additional Info: Strategy-specific information (e.g., priority, mode)
    ///
    /// ## Example Output
    /// ```
    /// ┌──────────────────┬────────────┬──────────────────────────────────────┬───────────────────┐
    /// │ Strategy         │ BoundaryId │ ActionId/UniqueId                    │ Additional Info   │
    /// ├──────────────────┼────────────┼──────────────────────────────────────┼───────────────────┤
    /// │ SingleExecution  │ mainScreen │ fetchData                            │ mode: .boundary   │
    /// │                  │            │ 123e4567-e89b-12d3-a456-426614174000 │                   │
    /// ├──────────────────┼────────────┼──────────────────────────────────────┼───────────────────┤
    /// │ PriorityBased    │ payment    │ processPayment                       │ priority: .high   │
    /// │                  │            │ 987f6543-a21b-34c5-d678-123456789012 │ behavior: .exc... │
    /// └──────────────────┴────────────┴──────────────────────────────────────┴───────────────────┘
    /// ```
    ///
    /// ## Usage
    /// ```swift
    /// // Print current lock state with default formatting
    /// LockmanManager.debug.printCurrentLocks()
    ///
    /// // Print with compact formatting for narrow terminals
    /// LockmanManager.debug.printCurrentLocks(options: .compact)
    ///
    /// // Print with detailed formatting
    /// LockmanManager.debug.printCurrentLocks(options: .detailed)
    /// ```
    ///
    /// ## Availability
    /// This method is available in both Debug and Release builds, allowing
    /// production debugging when needed.
    public static func printCurrentLocks() {
      printCurrentLocks(options: .default)
    }
  }
}

// MARK: - Protocol for Composite Info Introspection

/// Protocol for composite info types to expose their sub-infos.
/// Internal protocol used only for debug introspection of composite strategies.
/// Not part of the public API to avoid exposing implementation details.
internal protocol LockmanCompositeInfo {
  func allInfos() -> [any LockmanInfo]
}

extension LockmanCompositeInfo2: LockmanCompositeInfo {
  func allInfos() -> [any LockmanInfo] {
    [lockmanInfoForStrategy1, lockmanInfoForStrategy2]
  }
}

extension LockmanCompositeInfo3: LockmanCompositeInfo {
  func allInfos() -> [any LockmanInfo] {
    [lockmanInfoForStrategy1, lockmanInfoForStrategy2, lockmanInfoForStrategy3]
  }
}

extension LockmanCompositeInfo4: LockmanCompositeInfo {
  func allInfos() -> [any LockmanInfo] {
    [
      lockmanInfoForStrategy1, lockmanInfoForStrategy2, lockmanInfoForStrategy3,
      lockmanInfoForStrategy4,
    ]
  }
}

extension LockmanCompositeInfo5: LockmanCompositeInfo {
  func allInfos() -> [any LockmanInfo] {
    [
      lockmanInfoForStrategy1, lockmanInfoForStrategy2, lockmanInfoForStrategy3,
      lockmanInfoForStrategy4, lockmanInfoForStrategy5,
    ]
  }
}
