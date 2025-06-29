# Debugging Guide

Learn how to debug Lockman-related issues in your application.

## Overview

Debugging issues in applications using Lockman requires a different approach from traditional debugging due to the complexity of exclusive control. LockmanManager provides powerful debugging features for developers to monitor lock states and identify problems.

By utilizing appropriate debugging tools, you can efficiently identify and resolve lock conflicts, deadlocks, performance issues, and more.

## LockmanManager Debug Features

### Enabling Debug Logs

Lockman provides detailed lock operation logs:

```swift
// Enable debug logs (only works in DEBUG builds)
LockmanManager.debug.isLoggingEnabled = true
```

**Log output example**:
```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7BFC785A-3D25-4722-B9BC-A3A63A7F49FC, mode: boundary)

❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 1EBA9632-DE39-43B6-BE75-7C754476CD4E, mode: boundary), Reason: Boundary 'process' already has an active lock

⚠️ [Lockman] canLock succeeded with cancellation - Strategy: PriorityBased, BoundaryId: sync, Info: LockmanPriorityBasedInfo(...), Cancelled: 'backgroundSync' (uniqueId: 123e4567-e89b-12d3-a456-426614174000), Error: precedingActionCancelled
```

### Current Lock State Display

You can display lock states in table format:

```swift
// Display current lock state
LockmanManager.debug.printCurrentLocks()
```

**Output example**:
```
┌─────────────────┬──────────────────┬──────────────────────────────────────┬─────────────────┐
│ Strategy        │ BoundaryId       │ ActionId/UniqueId                    │ Additional Info │
├─────────────────┼──────────────────┼──────────────────────────────────────┼─────────────────┤
│ SingleExecution │ CancelID.process │ startProcessButtonTapped             │ mode: boundary  │
│                 │                  │ 08CC1862-136F-4643-A796-F63156D8BF56 │                 │
├─────────────────┼──────────────────┼──────────────────────────────────────┼─────────────────┤
│ PriorityBased   │ CancelID.sync    │ backgroundSync                       │ priority: .low  │
│                 │                  │ 987f6543-a21b-34c5-d678-123456789012 │ behavior: .rep..│
└─────────────────┴──────────────────┴──────────────────────────────────────┴─────────────────┘
```

### Format Options

You can customize the display format:

```swift
// Compact display (for narrow terminals)
LockmanManager.debug.printCurrentLocks(options: .compact)

// Detailed display
LockmanManager.debug.printCurrentLocks(options: .detailed)

// Custom format
let customOptions = LockmanManager.debug.FormatOptions(
    useShortStrategyNames: true,
    simplifyBoundaryIds: true,
    maxStrategyWidth: 15,
    maxBoundaryWidth: 20
)
LockmanManager.debug.printCurrentLocks(options: customOptions)
```

### Cleanup Feature

You can reset problematic lock states:

```swift
// Clean up all locks from all strategies
LockmanManager.cleanup.all()

// Clean up locks only for specific boundary
LockmanManager.cleanup.boundary(CancelID.userAction)
```

