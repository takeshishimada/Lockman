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
/// - **Query by ActionId**: O(1) - Hash table lookup via action index
/// - **Contains ActionId**: O(1) - Direct hash table check
/// - **Count by ActionId**: O(1) - Direct count access via action index
/// - **Currents by ActionId**: O(k) - Where k is the number of matching locks
/// - **All Currents**: O(k) - Where k is the total number of locks
/// - **Ordered iteration**: O(k) - Natural order preservation
/// - **Latest/Earliest access**: O(1) - Index-based access
final class LockmanState<I: LockmanInfo>: Sendable {
  // MARK: - Private Properties

  /// Storage using OrderedDictionary for optimal performance and ordering
  private let storage = ManagedCriticalState<[AnyLockmanBoundaryId: OrderedDictionary<UUID, I>]>([:])

  /// Secondary index for O(1) actionId-based lookups.
  /// This index dramatically improves performance for action-based queries,
  /// enabling constant-time contains() and count() operations.
  /// Maps: BoundaryId -> ActionId -> Set of UUIDs
  private let actionIndex = ManagedCriticalState<[AnyLockmanBoundaryId: [LockmanActionId: Set<UUID>]]>([:])

  // MARK: - Initialization

  init() {}

  // MARK: - Lock Management

  /// Adds new lock info with automatic ordering preservation.
  ///
  /// OrderedDictionary automatically maintains insertion order while providing
  /// O(1) key-based access performance. This method also updates the action index
  /// for efficient actionId-based lookups.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier
  ///   - info: The lock info to add
  ///
  /// ## Complexity
  /// O(1) - Direct ordered dictionary insertion and dual index update
  func add<B: LockmanBoundaryId>(id: B, info: I) {
    let boundaryKey = AnyLockmanBoundaryId(id)

    storage.withCriticalRegion { storage in
      storage[boundaryKey, default: OrderedDictionary<UUID, I>()][info.uniqueId] = info
    }

    actionIndex.withCriticalRegion { index in
      index[boundaryKey, default: [:]][info.actionId, default: []].insert(info.uniqueId)
    }
  }

  /// Removes a specific lock by UUID - True O(1) operation.
  ///
  /// This method maintains consistency between both the primary storage and
  /// the action index by removing the lock from both data structures.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier
  ///   - info: The lock info to remove (identified by uniqueId)
  ///
  /// ## Complexity
  /// O(1) - Direct key removal from OrderedDictionary and dual index update
  func remove<B: LockmanBoundaryId>(id: B, info: any LockmanInfo) {
    let boundaryKey = AnyLockmanBoundaryId(id)

    // First, get the info to access actionId for index cleanup
    let removedInfo = storage.withCriticalRegion { storage -> I? in
      guard let boundaryDict = storage[boundaryKey],
            let info = boundaryDict[info.uniqueId] else
      {
        return nil
      }
      return info
    }

    guard let removedInfo = removedInfo else {
      return
    }

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

    // Update action index
    actionIndex.withCriticalRegion { index in
      guard var boundaryIndex = index[boundaryKey],
            var actionSet = boundaryIndex[removedInfo.actionId] else
      {
        return
      }

      actionSet.remove(info.uniqueId)

      if actionSet.isEmpty {
        boundaryIndex.removeValue(forKey: removedInfo.actionId)
      } else {
        boundaryIndex[removedInfo.actionId] = actionSet
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
  /// - Parameter id: The boundary identifier to query
  /// - Returns: Array of locks in insertion order
  func currents<B: LockmanBoundaryId>(id: B) -> [I] {
    let boundaryKey = AnyLockmanBoundaryId(id)
    return storage.withCriticalRegion { storage in
      guard let boundaryDict = storage[boundaryKey] else {
        return []
      }
      return Array(boundaryDict.values)
    }
  }

  // MARK: - ActionId-based Query Operations

  /// Checks if a specific actionId exists in the boundary - O(1) operation.
  ///
  /// This method provides constant-time lookup for action existence,
  /// making it ideal for strategies that need to check action conflicts.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier
  ///   - actionId: The action ID to check
  /// - Returns: true if the action exists in the boundary
  ///
  /// ## Complexity
  /// O(1) - Direct hash table lookup
  func contains<B: LockmanBoundaryId>(id: B, actionId: LockmanActionId) -> Bool {
    let boundaryKey = AnyLockmanBoundaryId(id)
    return actionIndex.withCriticalRegion { index in
      index[boundaryKey]?[actionId] != nil
    }
  }

  /// Returns all locks with a specific actionId in the boundary.
  ///
  /// This method efficiently retrieves all locks matching the given actionId,
  /// maintaining the original insertion order.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier
  ///   - actionId: The action ID to filter by
  /// - Returns: Array of locks with the specified actionId in insertion order
  func currents<B: LockmanBoundaryId>(id: B, actionId: LockmanActionId) -> [I] {
    let boundaryKey = AnyLockmanBoundaryId(id)

    let uuids = actionIndex.withCriticalRegion { index in
      index[boundaryKey]?[actionId] ?? []
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

  /// Returns the count of locks with a specific actionId - O(1) operation.
  ///
  /// - Parameters:
  ///   - id: The boundary identifier
  ///   - actionId: The action ID to count
  /// - Returns: Number of locks with the specified actionId
  func count<B: LockmanBoundaryId>(id: B, actionId: LockmanActionId) -> Int {
    let boundaryKey = AnyLockmanBoundaryId(id)
    return actionIndex.withCriticalRegion { index in
      index[boundaryKey]?[actionId]?.count ?? 0
    }
  }

  /// Returns all unique actionIds in the boundary - O(1) operation.
  ///
  /// - Parameter id: The boundary identifier
  /// - Returns: Set of all unique actionIds in the boundary
  func actionIds<B: LockmanBoundaryId>(id: B) -> Set<LockmanActionId> {
    let boundaryKey = AnyLockmanBoundaryId(id)
    return actionIndex.withCriticalRegion { index in
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
    actionIndex.withCriticalRegion { index in
      index.removeAll(keepingCapacity: true)
    }
  }

  /// Removes all locks for a specific boundary.
  func removeAll<B: LockmanBoundaryId>(id: B) {
    let boundaryKey = AnyLockmanBoundaryId(id)
    storage.withCriticalRegion { storage in
      storage.removeValue(forKey: boundaryKey)
    }
    actionIndex.withCriticalRegion { index in
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
