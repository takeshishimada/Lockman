import Foundation
import OrderedCollections

/// A thread-safe container using OrderedDictionary for both O(1) access and guaranteed ordering.
///
/// This implementation uses Swift Collections' OrderedDictionary which provides:
/// - O(1) key-based access (like Dictionary)
/// - Guaranteed insertion order preservation
/// - Both key-based and index-based access patterns
/// - Efficient insertion and removal operations
///
/// ## Generic Key Support
/// The container now supports any hashable key type, allowing strategies to define
/// their own indexing scheme. For example:
/// - SingleExecutionStrategy can use actionId as the key
/// - ConcurrencyLimitedStrategy can use concurrencyId as the key
/// - Custom strategies can define composite keys for complex grouping
///
/// ## Dependencies
/// Requires `swift-collections` package:
/// ```swift
/// .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")
/// ```
///
/// ## Performance Characteristics
/// - **Add**: O(1) - Direct ordered insertion with dual index update
/// - **Remove by UUID**: O(1) - Direct key removal with dual index update
/// - **Query by UUID**: O(1) - Direct key access
/// - **Query by Key**: O(1) - Hash table lookup via key index
/// - **Contains Key**: O(1) - Direct hash table check
/// - **Count by Key**: O(1) - Direct count access via key index
/// - **Currents by Key**: O(k) - Where k is the number of matching locks
/// - **All Currents**: O(k) - Where k is the total number of locks
/// - **Ordered iteration**: O(k) - Natural order preservation
/// - **Latest/Earliest access**: O(1) - Index-based access
final class LockmanState<I: LockmanInfo, K: Hashable & Sendable>: Sendable {
  // MARK: - Private Properties

  /// Storage using OrderedDictionary for optimal performance and ordering
  private let storage = ManagedCriticalState<[AnyLockmanBoundaryId: OrderedDictionary<UUID, I>]>([:]
  )

  /// Secondary index for O(1) key-based lookups.
  /// This index dramatically improves performance for key-based queries,
  /// enabling constant-time contains() and count() operations.
  /// Maps: BoundaryId -> Key -> Set of UUIDs
  private let index = ManagedCriticalState<
    [AnyLockmanBoundaryId: [K: Set<UUID>]]
  >([:])

  /// Function to extract the key from lock info
  private let keyExtractor: @Sendable (I) -> K

  // MARK: - Initialization

  /// Creates a new LockmanState with the specified key extraction function.
  ///
  /// - Parameter keyExtractor: Function that extracts the indexing key from lock info
  init(keyExtractor: @escaping @Sendable (I) -> K) {
    self.keyExtractor = keyExtractor
  }

  // MARK: - Lock Management

  /// Adds new lock info with automatic ordering preservation.
  ///
  /// OrderedDictionary automatically maintains insertion order while providing
  /// O(1) key-based access performance. This method also updates the key index
  /// for efficient key-based lookups.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock info to add
  ///
  /// ## Complexity
  /// O(1) - Direct ordered dictionary insertion and dual index update
  func add<B: LockmanBoundaryId>(boundaryId: B, info: I) {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    let indexKey = keyExtractor(info)

    storage.withCriticalRegion { storage in
      storage[boundaryKey, default: OrderedDictionary<UUID, I>()][info.uniqueId] = info
    }

    index.withCriticalRegion { index in
      index[boundaryKey, default: [:]][indexKey, default: []].insert(info.uniqueId)
    }
  }

  /// Removes all locks with a specific key from the boundary.
  ///
  /// This method removes all locks that match the specified key,
  /// maintaining consistency between both the primary storage and key index.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - key: The key whose locks should be removed
  ///
  /// ## Complexity
  /// O(n) - Where n is the total number of locks in the boundary
  /// However, if k (locks to remove) << n (total locks), this is still efficient
  /// due to O(1) Set lookup for each item
  func removeAll<B: LockmanBoundaryId>(boundaryId: B, key: K) {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)

    // Get all UUIDs for this key
    let uuidsToRemove = index.withCriticalRegion { index in
      index[boundaryKey]?[key] ?? []
    }

    guard !uuidsToRemove.isEmpty else { return }

    // Remove from storage using filter (more efficient for bulk removal)
    storage.withCriticalRegion { storage in
      guard var boundaryDict = storage[boundaryKey] else { return }

      // Filter out all UUIDs in one operation
      boundaryDict = boundaryDict.filter { !uuidsToRemove.contains($0.key) }

      if boundaryDict.isEmpty {
        storage.removeValue(forKey: boundaryKey)
      } else {
        storage[boundaryKey] = boundaryDict
      }
    }

    // Remove from key index
    index.withCriticalRegion { index in
      guard var boundaryIndex = index[boundaryKey] else { return }

      boundaryIndex.removeValue(forKey: key)

      if boundaryIndex.isEmpty {
        index.removeValue(forKey: boundaryKey)
      } else {
        index[boundaryKey] = boundaryIndex
      }
    }
  }

  /// Removes a specific lock by UUID - True O(1) operation.
  ///
  /// This method maintains consistency between both the primary storage and
  /// the key index by removing the lock from both data structures.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - info: The lock info to remove (identified by uniqueId)
  ///
  /// ## Complexity
  /// O(1) - Direct key removal from OrderedDictionary and dual index update
  func remove<B: LockmanBoundaryId>(boundaryId: B, info: any LockmanInfo) {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)

    // First, get the info to access key for index cleanup
    let removedInfo = storage.withCriticalRegion { storage -> I? in
      guard let boundaryDict = storage[boundaryKey],
        let info = boundaryDict[info.uniqueId]
      else {
        return nil
      }
      return info
    }

    guard let removedInfo = removedInfo else {
      return
    }

    let indexKey = keyExtractor(removedInfo)

    storage.withCriticalRegion { storage in
      guard var boundaryDict = storage[boundaryKey] else {
        return
      }

      boundaryDict.removeValue(forKey: info.uniqueId)

      // Clean up empty boundary
      if boundaryDict.isEmpty {
        storage.removeValue(forKey: boundaryKey)
      } else {
        storage[boundaryKey] = boundaryDict
      }
    }

    // Update key index
    index.withCriticalRegion { index in
      guard var boundaryIndex = index[boundaryKey],
        var keySet = boundaryIndex[indexKey]
      else {
        return
      }

      keySet.remove(info.uniqueId)

      if keySet.isEmpty {
        boundaryIndex.removeValue(forKey: indexKey)
      } else {
        boundaryIndex[indexKey] = keySet
      }

      if boundaryIndex.isEmpty {
        index.removeValue(forKey: boundaryKey)
      } else {
        index[boundaryKey] = boundaryIndex
      }
    }
  }

  // MARK: - Query Operations

  /// Returns all locks in guaranteed insertion order.
  ///
  /// OrderedDictionary preserves insertion order, so this method returns
  /// locks in the exact order they were added to the boundary.
  ///
  /// - Parameter boundaryId: The boundary identifier to query
  /// - Returns: Array of locks in insertion order
  func currents<B: LockmanBoundaryId>(boundaryId: B) -> [I] {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    return storage.withCriticalRegion { storage in
      guard let boundaryDict = storage[boundaryKey] else {
        return []
      }
      return Array(boundaryDict.values)
    }
  }

  // MARK: - Key-based Query Operations

  /// Checks if a specific key exists in the boundary - O(1) operation.
  ///
  /// This method provides constant-time lookup for key existence,
  /// making it ideal for strategies that need to check conflicts.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - key: The key to check
  /// - Returns: true if the key exists in the boundary
  ///
  /// ## Complexity
  /// O(1) - Direct hash table lookup
  func contains<B: LockmanBoundaryId>(boundaryId: B, key: K) -> Bool {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    return index.withCriticalRegion { index in
      index[boundaryKey]?[key] != nil
    }
  }

  /// Returns all locks with a specific key in the boundary.
  ///
  /// This method efficiently retrieves all locks matching the given key,
  /// maintaining the original insertion order.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - key: The key to filter by
  /// - Returns: Array of locks with the specified key in insertion order
  func currents<B: LockmanBoundaryId>(boundaryId: B, key: K) -> [I] {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)

    let uuids = index.withCriticalRegion { index in
      index[boundaryKey]?[key] ?? []
    }

    guard !uuids.isEmpty else {
      return []
    }

    return storage.withCriticalRegion { storage in
      guard let boundaryDict = storage[boundaryKey] else {
        return []
      }

      return uuids.compactMap { uuid in
        boundaryDict[uuid]
      }.sorted { first, second in
        if let firstIndex = boundaryDict.index(forKey: first.uniqueId),
          let secondIndex = boundaryDict.index(forKey: second.uniqueId)
        {
          return firstIndex < secondIndex
        }
        return false
      }
    }
  }

  /// Returns the count of locks with a specific key - O(1) operation.
  ///
  /// - Parameters:
  ///   - boundaryId: The boundary identifier
  ///   - key: The key to count
  /// - Returns: Number of locks with the specified key
  func count<B: LockmanBoundaryId>(boundaryId: B, key: K) -> Int {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    return index.withCriticalRegion { index in
      index[boundaryKey]?[key]?.count ?? 0
    }
  }

  /// Returns all unique keys in the boundary - O(1) operation.
  ///
  /// - Parameter boundaryId: The boundary identifier
  /// - Returns: Set of all unique keys in the boundary
  func keys<B: LockmanBoundaryId>(boundaryId: B) -> Set<K> {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    return index.withCriticalRegion { index in
      if let boundaryIndex = index[boundaryKey] {
        return Set(boundaryIndex.keys)
      }
      return Set()
    }
  }

  // MARK: - Bulk Operations

  /// Removes all locks across all boundaries.
  func removeAll() {
    storage.withCriticalRegion { storage in
      storage.removeAll(keepingCapacity: true)
    }
    index.withCriticalRegion { index in
      index.removeAll(keepingCapacity: true)
    }
  }

  /// Removes all locks for a specific boundary.
  func removeAll<B: LockmanBoundaryId>(boundaryId: B) {
    let boundaryKey = AnyLockmanBoundaryId(boundaryId)
    storage.withCriticalRegion { storage in
      storage.removeValue(forKey: boundaryKey)
    }
    index.withCriticalRegion { index in
      index.removeValue(forKey: boundaryKey)
    }
  }

  /// Returns all boundary identifiers that have active locks.
  func allBoundaryIds() -> [AnyLockmanBoundaryId] {
    storage.withCriticalRegion { storage in
      Array(storage.keys)
    }
  }

  /// Returns the total number of locks across all boundaries.
  func totalLockCount() -> Int {
    storage.withCriticalRegion { storage in
      storage.values.reduce(0) { total, boundaryDict in
        total + boundaryDict.count
      }
    }
  }

  /// Returns all locks grouped by boundary for debugging purposes.
  ///
  /// This method provides a complete snapshot of all locks across all boundaries,
  /// suitable for debugging and inspection tools.
  ///
  /// - Returns: Dictionary mapping boundary IDs to arrays of lock information
  func getAllLocks() -> [AnyLockmanBoundaryId: [I]] {
    storage.withCriticalRegion { storage in
      var result: [AnyLockmanBoundaryId: [I]] = [:]
      for (boundaryId, boundaryDict) in storage {
        result[boundaryId] = Array(boundaryDict.values)
      }
      return result
    }
  }
}

// MARK: - Type Alias for ActionId-based State

/// Type alias for LockmanState that uses actionId as the key.
/// This is provided for backward compatibility.
typealias ActionIdLockmanState<I: LockmanInfo> = LockmanState<I, LockmanActionId>

// MARK: - Convenience for ActionId-based State

extension LockmanState where K == LockmanActionId {
  /// Creates a new LockmanState that uses actionId as the key.
  ///
  /// This convenience initializer is provided for backward compatibility
  /// and for the common use case where actions are indexed by their actionId.
  convenience init() {
    self.init(keyExtractor: { $0.actionId })
  }

  // MARK: - ActionId-specific convenience methods

  /// Checks if a specific actionId exists in the boundary.
  ///
  /// Convenience method that calls the generic key-based method.
  func contains<B: LockmanBoundaryId>(boundaryId: B, actionId: LockmanActionId) -> Bool {
    contains(boundaryId: boundaryId, key: actionId)
  }

  /// Returns all locks with a specific actionId in the boundary.
  ///
  /// Convenience method that calls the generic key-based method.
  func currents<B: LockmanBoundaryId>(boundaryId: B, actionId: LockmanActionId) -> [I] {
    currents(boundaryId: boundaryId, key: actionId)
  }

  /// Returns the count of locks with a specific actionId.
  ///
  /// Convenience method that calls the generic key-based method.
  func count<B: LockmanBoundaryId>(boundaryId: B, actionId: LockmanActionId) -> Int {
    count(boundaryId: boundaryId, key: actionId)
  }

  /// Removes all locks with a specific actionId from the boundary.
  ///
  /// Convenience method that calls the generic key-based method.
  func removeAll<B: LockmanBoundaryId>(boundaryId: B, actionId: LockmanActionId) {
    removeAll(boundaryId: boundaryId, key: actionId)
  }

  /// Returns all unique actionIds in the boundary.
  ///
  /// Convenience method that calls the generic key-based method.
  func actionIds<B: LockmanBoundaryId>(boundaryId: B) -> Set<LockmanActionId> {
    keys(boundaryId: boundaryId)
  }
}
