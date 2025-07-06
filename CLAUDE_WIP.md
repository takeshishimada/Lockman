# CLAUDE_WIP.md - Work In Progress Tasks

## Lockman v1.0 Roadmap

### Feature 1: Add unlockOption to LockmanAction
- Add `unlockOption` property to LockmanAction protocol
- Use action's setting when not specified in withLock/lock()
- Default value is `.immediate` (from `LockmanManager.config.defaultUnlockOption`)
- Priority order:
  1. Explicitly specified in withLock/lock() → Highest priority
  2. Action's unlockOption → Next priority
  3. config.defaultUnlockOption → Lowest priority

### Feature 2: Argument Label Change (Breaking Change)
- Change `id` → `boundaryId` in all Lockman APIs
- Affected: withLock, lock(), and related methods
- Acceptable as breaking change for v1.0

### Feature 3: Reducer-level Locking (.lock() method)
- Enable using existing `run` methods without modification
- Only actions implementing LockmanAction protocol are locked

**Interface Specification:**
```swift
public extension Reducer {
    func lock(
        boundaryId: any LockmanBoundaryId,
        cancelIDs: [any LockmanBoundaryId] = [],
        unlockOption: UnlockOption = .immediate,
        onLockFailed: (@Sendable (Action) -> Void)? = nil,
        onDynamicCondition: (@Sendable (State, Action, Set<LockmanBoundaryId>) -> LockingStrategy)? = nil
    ) -> LockmanReducer<Self>
}
```

### Feature 4: Effect-level .lock() method
- Method chain alternative to withLock
- Strategy is obtained from LockmanAction (no need to specify)

**Interface Specification:**
```swift
extension Effect {
    func lock(
        boundaryId: any LockmanBoundaryId,
        unlockOption: UnlockOption? = nil,
        handleCancellationErrors: Bool = true
    ) -> Effect<Action>
}
```

## Implementation Order
1. Feature 2 (argument label change) - Foundation for other features
2. Feature 1 (add unlockOption) - Used by features 3 and 4
3. Feature 3 (Reducer.lock())
4. Feature 4 (Effect.lock())

## Notes
- All features target v1.0 release
- Feature 2 is a breaking change, acceptable for major version
- Features 3 and 4 provide more ergonomic APIs while maintaining compatibility with existing withLock