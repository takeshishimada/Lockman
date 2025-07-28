// https://github.com/sideeffect-io/AsyncExtensions/blob/main/Sources/Supporting/ManagedCriticalState.swift

import Darwin

/// A managed buffer that safely wraps state with an unfair lock for synchronization.
final class LockedBuffer<State>: ManagedBuffer<State, os_unfair_lock> {
  deinit {
    _ = self.withUnsafeMutablePointerToElements { lock in
      lock.deinitialize(count: 1)
    }
  }
}

/// A thread-safe wrapper for mutable state using os_unfair_lock for synchronization.
///
/// This structure provides safe concurrent access to mutable state by protecting
/// all mutations and reads with an unfair lock.
struct ManagedCriticalState<State> {
  let buffer: ManagedBuffer<State, os_unfair_lock>

  init(_ initial: State) {
    buffer = LockedBuffer.create(minimumCapacity: 1) { buffer in
      buffer.withUnsafeMutablePointerToElements { lock in
        lock.initialize(to: os_unfair_lock())
      }
      return initial
    }
  }

  /// Executes a closure with exclusive access to the protected state.
  ///
  /// - Parameter critical: A closure that receives mutable access to the state
  /// - Returns: The value returned by the critical closure
  @discardableResult
  func withCriticalRegion<R>(
    _ critical: (inout State) throws -> R
  ) rethrows -> R {
    try buffer.withUnsafeMutablePointers { header, lock in
      os_unfair_lock_lock(lock)
      defer { os_unfair_lock_unlock(lock) }
      return try critical(&header.pointee)
    }
  }

  func apply(criticalState newState: State) {
    withCriticalRegion { actual in actual = newState }
  }

  var criticalState: State { withCriticalRegion { $0 } }
}

extension ManagedCriticalState: @unchecked Sendable where State: Sendable {}
