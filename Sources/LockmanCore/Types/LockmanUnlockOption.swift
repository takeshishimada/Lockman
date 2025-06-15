import Foundation

/// Controls when unlock operations are executed.
///
/// This enum provides different options for releasing locks, allowing
/// developers to coordinate unlock behavior with UI operations like screen transitions.
///
/// ## Usage Examples
/// ```swift
/// // Wait for screen transition animation (default)
/// .withLock(unlockOption: .transition, ...)
///
/// // Immediate unlock when no UI transition
/// .withLock(unlockOption: .immediate, ...)
///
/// // Defer until next main run loop cycle
/// .withLock(unlockOption: .mainRunLoop, ...)
///
/// // Delay unlock by specific time interval
/// .withLock(unlockOption: .delayed(1.5), ...)
/// ```
public enum UnlockOption: Sendable, Equatable {
  /// Unlock immediately when called (current behavior).
  ///
  /// The unlock operation executes synchronously without any delay.
  /// Use this for operations that don't involve UI transitions or when
  /// immediate unlock is specifically required.
  case immediate

  /// Defer unlock until the next main run loop cycle.
  ///
  /// The unlock will be deferred using `RunLoop.main.perform`, providing
  /// minimal delay while ensuring the current execution context completes.
  ///
  /// ## Use Cases
  /// - Lightweight UI updates
  /// - State synchronization
  /// - Minimal coordination needs
  case mainRunLoop

  /// Wait for screen transition animation to complete (default).
  ///
  /// The unlock operation will be delayed by a platform-specific duration
  /// that matches standard screen transition animations. This is the default
  /// option to ensure safe coordination with UI transitions.
  ///
  /// ## Platform-Specific Durations
  /// - iOS: 0.35 seconds (UINavigationController push/pop)
  /// - macOS: 0.25 seconds (window animations)
  /// - tvOS: 0.4 seconds (focus-driven transitions)
  /// - watchOS: 0.3 seconds (page-based navigation)
  ///
  /// ## UI Coordination Benefits
  /// - Prevents duplicate actions during navigation animations
  /// - Allows modal presentation/dismissal to complete
  /// - Ensures smooth user experience during screen transitions
  case transition

  /// Delay unlock by the specified time interval.
  ///
  /// The unlock operation will be executed after the specified number of seconds
  /// using `DispatchQueue.main.asyncAfter`. This provides precise control over
  /// unlock behavior for custom coordination scenarios.
  ///
  /// - Parameter TimeInterval: Number of seconds to delay the unlock operation
  ///
  /// ## Use Cases
  /// - Custom animation durations
  /// - Network operation timeouts
  /// - User-defined delay periods
  case delayed(TimeInterval)
}
