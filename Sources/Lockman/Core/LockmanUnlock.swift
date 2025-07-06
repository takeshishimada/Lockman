import Foundation

// MARK: - LockmanUnlock

/// A closure-like type that encapsulates the unlock operation for a specific boundary and strategy.
///
/// Serves as an "unlock token" that captures all necessary information to release
/// a previously acquired lock. Can be called like a closure with `unlockToken()`.
public struct LockmanUnlock<B: LockmanBoundaryId, I: LockmanInfo>: Sendable {
  /// The boundary identifier whose lock will be released.
  private let id: B

  /// The lock information that was used when acquiring the lock.
  ///
  /// This contains both the action identifier for conflict detection and a unique
  /// instance identifier for precise lock tracking. The strategy uses the unique ID
  /// to identify exactly which lock instance to release.
  fileprivate let info: I

  /// The type-erased strategy responsible for performing the unlock operation.
  ///
  /// This strategy instance must be the same one that was used to acquire the lock.
  /// The type erasure allows this token to work with any concrete strategy type
  /// while maintaining type safety for the lock information.
  private let strategy: AnyLockmanStrategy<I>

  /// The unlock option configuration for when the unlock operation should be executed.
  ///
  /// Controls whether the unlock happens immediately, on the next run loop cycle,
  /// or after a specified delay. This enables coordination with UI operations
  /// like screen transitions.
  private let unlockOption: LockmanUnlockOption

  /// Creates a new unlock token with the specified components and unlock option.
  public init(
    id: B,
    info: I,
    strategy: AnyLockmanStrategy<I>,
    unlockOption: LockmanUnlockOption
  ) {
    self.id = id
    self.info = info
    self.strategy = strategy
    self.unlockOption = unlockOption
  }

  /// Executes the unlock operation with the configured unlock option.
  public func callAsFunction() {
    switch unlockOption {
    case .immediate:
      performUnlockImmediately()

    case .mainRunLoop:
      RunLoop.main.perform {
        self.performUnlockImmediately()
      }

    case .transition:
      let delay = transitionDelay
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        self.performUnlockImmediately()
      }

    case .delayed(let interval):
      DispatchQueue.main.asyncAfter(deadline: .now() + interval) {
        self.performUnlockImmediately()
      }
    }
  }

  /// Returns the platform-specific transition delay duration.
  private var transitionDelay: TimeInterval {
    #if os(iOS)
      return 0.35  // UINavigationController push/pop animation
    #elseif os(macOS)
      return 0.25  // Window and view animations
    #elseif os(tvOS)
      return 0.4  // Focus-driven transitions
    #elseif os(watchOS)
      return 0.3  // Page-based navigation
    #else
      return 0.35  // Default fallback
    #endif
  }

  /// Performs the actual unlock operation immediately.
  private func performUnlockImmediately() {
    LockmanManager.withBoundaryLock(for: id) {
      strategy.unlock(boundaryId: id, info: info)
    }
  }
}

// MARK: - LockmanAutoUnlock

/// Automatic unlock manager that ensures proper cleanup of Lockman locks through
/// memory management and provides manual unlock capabilities.
///
/// Implemented as an `actor` to provide thread-safe access to the unlock token.
public actor LockmanAutoUnlock<B: LockmanBoundaryId, I: LockmanInfo>: Sendable {
  /// The unlock token that will be automatically unlocked when this instance is deallocated.
  ///
  /// This property is mutable to allow setting it to `nil` after manual unlock,
  /// preventing double unlocking. The actor isolation ensures thread-safe access
  /// to this property.
  private var unlockToken: LockmanUnlock<B, I>?

  /// Creates a new auto-unlock manager with the specified unlock token.
  public init(unlockToken: LockmanUnlock<B, I>) {
    self.unlockToken = unlockToken
  }

  /// Automatically unlocks the token when this instance is deallocated.
  deinit {
    if let unlockToken {
      unlockToken()  // Uses the token's configured unlock option
    }
  }

  /// Manually unlocks the token before deallocation.
  public func manualUnlock() {
    if let unlockToken {
      unlockToken()  // Uses the token's configured unlock option
      self.unlockToken = nil
    }
  }

  /// Provides access to the underlying unlock token.
  public var token: LockmanUnlock<B, I>? {
    unlockToken
  }

  /// Indicates whether the lock is still active.
  public var isLocked: Bool {
    unlockToken != nil
  }
}
