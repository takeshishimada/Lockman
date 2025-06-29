# Debugging Guide

Learn how to debug Lockman-related issues in your application.

## Overview

Lockmanを使用したアプリケーションで発生する問題のデバッグは、排他制御の複雑さから従来のデバッグとは異なるアプローチが必要です。LockmanManagerは、開発者がロック状態を監視し、問題を特定するための強力なデバッグ機能を提供しています。

適切なデバッグツールの活用により、ロックの競合、デッドロック、パフォーマンス問題などを効率的に特定し、解決できます。

## LockmanManagerデバッグ機能

### デバッグログの有効化

Lockmanは詳細なロック操作ログを提供します：

```swift
// デバッグログを有効化（DEBUGビルドでのみ動作）
LockmanManager.debug.isLoggingEnabled = true
```

**ログ出力例**:
```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7BFC785A-3D25-4722-B9BC-A3A63A7F49FC, mode: boundary)

❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 1EBA9632-DE39-43B6-BE75-7C754476CD4E, mode: boundary), Reason: Boundary 'process' already has an active lock

⚠️ [Lockman] canLock succeeded with cancellation - Strategy: PriorityBased, BoundaryId: sync, Info: LockmanPriorityBasedInfo(...), Cancelled: 'backgroundSync' (uniqueId: 123e4567-e89b-12d3-a456-426614174000), Error: precedingActionCancelled
```

### 現在のロック状態表示

テーブル形式でロック状態を表示できます：

```swift
// 現在のロック状態を表示
LockmanManager.debug.printCurrentLocks()
```

**出力例**:
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

### フォーマットオプション

表示形式をカスタマイズできます：

```swift
// コンパクト表示（狭いターミナル用）
LockmanManager.debug.printCurrentLocks(options: .compact)

// 詳細表示
LockmanManager.debug.printCurrentLocks(options: .detailed)

// カスタムフォーマット
let customOptions = LockmanManager.debug.FormatOptions(
    useShortStrategyNames: true,
    simplifyBoundaryIds: true,
    maxStrategyWidth: 15,
    maxBoundaryWidth: 20
)
LockmanManager.debug.printCurrentLocks(options: customOptions)
```

### cleanup機能

問題のあるロック状態をリセットできます：

```swift
// 全戦略の全ロックをクリーンアップ
LockmanManager.cleanup.all()

// 特定境界のロックのみクリーンアップ
LockmanManager.cleanup.boundary(CancelID.userAction)
```

## ガイド

次のステップ <doc:SingleExecutionStrategy>

前のステップ [Error Handling](<doc:ErrorHandling>)
