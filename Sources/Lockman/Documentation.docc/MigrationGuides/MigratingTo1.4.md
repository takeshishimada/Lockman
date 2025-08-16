# Migrating to 1.4

Update your code from Lockman 1.3 to take advantage of Lockman 1.4's improved API semantics and enhanced reliability.

## Overview

Lockman 1.4 introduces significant improvements to the `LockmanState` API with more semantic method names and better safety guarantees. The key focus of this release is improving code readability and eliminating potential confusion around method naming while maintaining all existing functionality.

The key improvements include:
- **Semantic method names**: More descriptive and self-documenting method names
- **Consistent parameter labels**: Unified use of `in:` and `matching:` throughout the API  
- **Enhanced safety**: Improved CompositeStrategy reliability and nested action evaluation
- **Better organization**: Cleaner Core directory structure
- **Eliminated redundancy**: Removed duplicate convenience methods that could cause issues

## Updating dependencies

To upgrade to Lockman 1.4, update your `Package.swift` file:

```swift
dependencies: [
  .package(
    url: "https://github.com/takeshishimada/Lockman",
    from: "1.4.0"
  )
]
```

## Breaking changes

### LockmanState method name changes

All `LockmanState` query methods have been renamed with more semantic alternatives. This is the primary breaking change in 1.4.

#### Core Query Methods

| Old Method (1.3) | New Method (1.4) |
|------------------|------------------|
| `currents(boundaryId:)` | `currentLocks(in:)` |
| `currents(boundaryId:key:)` | `currentLocks(in:matching:)` |
| `contains(boundaryId:key:)` | `hasActiveLocks(in:matching:)` |
| `count(boundaryId:key:)` | `activeLockCount(in:matching:)` |
| `keys(boundaryId:)` | `activeKeys(in:)` |

#### State Query Methods

| Old Method (1.3) | New Method (1.4) |
|------------------|------------------|
| `allBoundaryIds()` | `activeBoundaryIds()` |
| `totalLockCount()` | `totalActiveLockCount()` |
| `getAllLocks()` | `allActiveLocks()` |

#### ActionId-Specific Methods

| Old Method (1.3) | New Method (1.4) |
|------------------|------------------|
| `removeAll(boundaryId:actionId:)` | `removeAllLocks(in:matching:)` |

### Parameter label changes

All methods now use consistent parameter labeling:
- Boundary parameters use `in:` label
- Key/ActionId parameters use `matching:` label

🚫 **Before (1.3):**
```swift
let locks = state.currents(boundaryId: .userActions)
let hasLock = state.contains(boundaryId: .userActions, key: "login")
let count = state.count(boundaryId: .userActions, key: "login")
```

✅ **After (1.4):**
```swift
let locks = state.currentLocks(in: .userActions)
let hasLock = state.hasActiveLocks(in: .userActions, matching: "login")
let count = state.activeLockCount(in: .userActions, matching: "login")
```

## Migration guide

### Step 1: Update method names in custom strategies

If you have custom strategies that interact with `LockmanState`, update all method calls:

🚫 **Before (1.3):**
```swift
class CustomStrategy: LockmanStrategy {
  func evaluate(action: LockmanAction, state: LockmanState) -> LockmanResult {
    let currentCount = state.count(boundaryId: action.boundaryId, key: action.key)
    let allBoundaries = state.allBoundaryIds()
    
    if state.contains(boundaryId: action.boundaryId, key: action.key) {
      return .cancel(...)
    }
    
    return .success
  }
}
```

✅ **After (1.4):**
```swift
class CustomStrategy: LockmanStrategy {
  func evaluate(action: LockmanAction, state: LockmanState) -> LockmanResult {
    let currentCount = state.activeLockCount(in: action.boundaryId, matching: action.key)
    let allBoundaries = state.activeBoundaryIds()
    
    if state.hasActiveLocks(in: action.boundaryId, matching: action.key) {
      return .cancel(...)
    }
    
    return .success
  }
}
```

### Step 2: Update test code

Update any test code that directly interacts with `LockmanState`:

🚫 **Before (1.3):**
```swift
func testLockState() {
  let state = LockmanState()
  // ... add some locks
  
  XCTAssertEqual(state.totalLockCount(), 2)
  XCTAssertTrue(state.contains(boundaryId: .test, key: "action1"))
  
  let currentLocks = state.currents(boundaryId: .test)
  XCTAssertEqual(currentLocks.count, 1)
}
```

✅ **After (1.4):**
```swift
func testLockState() {
  let state = LockmanState()
  // ... add some locks
  
  XCTAssertEqual(state.totalActiveLockCount(), 2)
  XCTAssertTrue(state.hasActiveLocks(in: .test, matching: "action1"))
  
  let currentLocks = state.currentLocks(in: .test)
  XCTAssertEqual(currentLocks.count, 1)
}
```

### Step 3: Update debugging and monitoring code

If you have code that monitors lock state for debugging or analytics:

🚫 **Before (1.3):**
```swift
func debugLockState(_ state: LockmanState) {
  print("Total locks: \(state.totalLockCount())")
  
  for boundaryId in state.allBoundaryIds() {
    let locks = state.currents(boundaryId: boundaryId)
    let keys = state.keys(boundaryId: boundaryId)
    print("Boundary \(boundaryId): \(locks.count) locks, keys: \(keys)")
  }
}
```

✅ **After (1.4):**
```swift
func debugLockState(_ state: LockmanState) {
  print("Total locks: \(state.totalActiveLockCount())")
  
  for boundaryId in state.activeBoundaryIds() {
    let locks = state.currentLocks(in: boundaryId)
    let keys = state.activeKeys(in: boundaryId)
    print("Boundary \(boundaryId): \(locks.count) locks, keys: \(keys)")
  }
}
```

## Non-breaking improvements

### Enhanced CompositeStrategy reliability

Version 1.4 includes critical fixes to `CompositeStrategy` that improve reliability without requiring code changes:

- Fixed critical logic error in `coordinateResults` method
- Simplified result coordination logic
- Enhanced safety in concurrent operations

### Improved nested action evaluation

The `Reducer.lock()` method now properly prioritizes nested action evaluation over root actions, providing more predictable behavior in complex reducer hierarchies.

### Better Core directory organization

The Core directory structure has been reorganized for better maintainability:
- Error types moved to `Core/Errors/`
- Protocol definitions moved to `Core/Protocols/`
- Core types moved to appropriate locations

This change doesn't affect public APIs but improves internal organization.

## Complete migration examples

### Custom Strategy Migration

🚫 **Before (1.3):**
```swift
struct ValidationStrategy: LockmanStrategy {
  func evaluate(action: LockmanAction, state: LockmanState) -> LockmanResult {
    // Check if user has too many active operations
    let userBoundary = BoundaryId.user(action.userId)
    let activeOperations = state.count(boundaryId: userBoundary, key: "operation")
    
    if activeOperations >= maxConcurrentOperations {
      return .cancel(TooManyOperationsError())
    }
    
    // Check global system load
    let totalSystemLoad = state.totalLockCount()
    if totalSystemLoad > systemCapacity {
      return .cancel(SystemOverloadError())
    }
    
    return .success
  }
}
```

✅ **After (1.4):**
```swift
struct ValidationStrategy: LockmanStrategy {
  func evaluate(action: LockmanAction, state: LockmanState) -> LockmanResult {
    // Check if user has too many active operations
    let userBoundary = BoundaryId.user(action.userId)
    let activeOperations = state.activeLockCount(in: userBoundary, matching: "operation")
    
    if activeOperations >= maxConcurrentOperations {
      return .cancel(TooManyOperationsError())
    }
    
    // Check global system load
    let totalSystemLoad = state.totalActiveLockCount()
    if totalSystemLoad > systemCapacity {
      return .cancel(SystemOverloadError())
    }
    
    return .success
  }
}
```

### Test Code Migration

🚫 **Before (1.3):**
```swift
func testConcurrentUserActions() {
  let state = LockmanState()
  
  // Simulate some active locks
  state.addLock(boundaryId: .userActions, key: "login", actionId: "action1")
  state.addLock(boundaryId: .userActions, key: "logout", actionId: "action2")
  
  // Verify state
  XCTAssertEqual(state.totalLockCount(), 2)
  XCTAssertTrue(state.contains(boundaryId: .userActions, key: "login"))
  XCTAssertFalse(state.contains(boundaryId: .userActions, key: "register"))
  
  let allKeys = state.keys(boundaryId: .userActions)
  XCTAssertEqual(Set(allKeys), Set(["login", "logout"]))
}
```

✅ **After (1.4):**
```swift
func testConcurrentUserActions() {
  let state = LockmanState()
  
  // Simulate some active locks
  state.addLock(boundaryId: .userActions, key: "login", actionId: "action1")
  state.addLock(boundaryId: .userActions, key: "logout", actionId: "action2")
  
  // Verify state
  XCTAssertEqual(state.totalActiveLockCount(), 2)
  XCTAssertTrue(state.hasActiveLocks(in: .userActions, matching: "login"))
  XCTAssertFalse(state.hasActiveLocks(in: .userActions, matching: "register"))
  
  let allKeys = state.activeKeys(in: .userActions)
  XCTAssertEqual(Set(allKeys), Set(["login", "logout"]))
}
```

## Benefits of upgrading

1. **Improved readability**: Method names are more descriptive and self-documenting
2. **Consistent API**: Unified parameter labeling throughout the LockmanState API
3. **Enhanced reliability**: Critical fixes to CompositeStrategy and nested action evaluation
4. **Better maintenance**: Cleaner code organization and reduced redundancy
5. **Future-proof**: Sets foundation for continued API evolution

## Migration checklist

- [ ] Update `Package.swift` dependency to 1.4.0
- [ ] Search codebase for old `LockmanState` method names
- [ ] Replace method calls using the mapping table above
- [ ] Update parameter labels to use `in:` and `matching:`
- [ ] Run tests to verify migration success
- [ ] Update any documentation referencing old method names

## API mapping reference

### Quick Reference Table

| Old API Pattern | New API Pattern |
|----------------|-----------------|
| `.currents(boundaryId: X)` | `.currentLocks(in: X)` |
| `.currents(boundaryId: X, key: Y)` | `.currentLocks(in: X, matching: Y)` |
| `.contains(boundaryId: X, key: Y)` | `.hasActiveLocks(in: X, matching: Y)` |
| `.count(boundaryId: X, key: Y)` | `.activeLockCount(in: X, matching: Y)` |
| `.keys(boundaryId: X)` | `.activeKeys(in: X)` |
| `.allBoundaryIds()` | `.activeBoundaryIds()` |
| `.totalLockCount()` | `.totalActiveLockCount()` |
| `.getAllLocks()` | `.allActiveLocks()` |

## Testing your migration

After migrating, verify that:

1. **All compilation errors are resolved**: Check that method names and parameter labels are correct
2. **Existing functionality is maintained**: Run your test suite to ensure behavior is unchanged  
3. **Custom strategies work correctly**: Test any custom strategy implementations
4. **Performance is maintained**: Verify no performance regression from the changes

## Summary

Lockman 1.4 focuses on improving API semantics and reliability while maintaining full backward compatibility for the core locking functionality. The primary change involves updating `LockmanState` method names to be more descriptive and consistent.

**Key takeaways:**
- **Method name changes**: All `LockmanState` query methods have semantic replacements
- **Consistent parameters**: Unified use of `in:` and `matching:` parameter labels
- **Enhanced reliability**: Critical fixes for CompositeStrategy and nested action evaluation  
- **No functional changes**: All existing locking behavior is preserved

The migration is straightforward and primarily involves renaming method calls. The new API provides better self-documentation and sets a strong foundation for future enhancements.