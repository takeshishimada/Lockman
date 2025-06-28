# PriorityBasedStrategy

Control action execution based on priority levels.

## Overview

PriorityBasedStrategyは、優先度に基づく実行制御を行う戦略です。高優先度の処理が低優先度の処理を中断して実行することで、重要な処理を優先的に処理できます。

この戦略は、緊急度の高い処理や重要度に応じた処理制御が必要な場面で使用されます。

## 優先度システム

### 優先度レベル

**high** - 高優先度
- 他の全ての優先度の処理を中断可能
- システムレベルの緊急処理や重要なユーザー操作

**low** - 低優先度  
- none優先度の処理は中断可能
- high優先度には中断される
- 定期的なバックグラウンド処理

**none** - 優先度なし
- 優先度システムをバイパス
- 他の処理に中断されない
- 基本的な処理や一時的な無効化

### 同時実行制御

同一優先度レベル内では、既存処理の同時実行動作設定により制御されます：

**exclusive** - 排他的実行

```swift
LockmanPriorityBasedInfo(
    actionId: "payment",
    priority: .high(.exclusive)
)
```

- 同じ優先度の新しい処理を拒否
- 重要な処理を中断されないよう保護

**replaceable** - 置換可能実行

```swift
LockmanPriorityBasedInfo(
    actionId: "search", 
    priority: .high(.replaceable)
)
```

- 同じ優先度の新しい処理により中断可能
- 検索や更新系の処理に適用

## 使用方法

### 基本的な使用例

```swift
@LockmanPriorityBased
enum Action {
    case emergencySync
    case normalSync
    case backgroundTask
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .emergencySync:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        case .normalSync:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .low(.replaceable)
            )
        case .backgroundTask:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .none
            )
        }
    }
}
```

### 同一アクション阻止の設定

```swift
LockmanPriorityBasedInfo(
    actionId: "criticalUpdate",
    priority: .high(.exclusive),
    blocksSameAction: true  // 同じアクションIDの重複実行を阻止
)
```

## 動作例

### 優先度による中断

```
時刻: 0秒  - low優先度処理開始    → ✅ 実行
時刻: 2秒  - high優先度処理要求   → ✅ 実行（low処理を中断）
時刻: 2秒  - low優先度処理        → 🛑 キャンセル
時刻: 5秒  - high優先度処理完了   → ✅ 完了
```

### 同一優先度での制御

```
// exclusive設定の場合
時刻: 0秒  - high(.exclusive)開始  → ✅ 実行
時刻: 1秒  - high(.exclusive)要求  → ❌ 拒否
時刻: 3秒  - 最初の処理完了       → ✅ 完了
時刻: 4秒  - high(.exclusive)要求  → ✅ 実行

// replaceable設定の場合  
時刻: 0秒  - high(.replaceable)開始 → ✅ 実行
時刻: 1秒  - high(.replaceable)要求 → ✅ 実行（前の処理を中断）
時刻: 1秒  - 最初の処理            → 🛑 キャンセル
```

## エラーハンドリング

### LockmanPriorityBasedError

**higherPriorityExists** - より高い優先度が実行中

```swift
lockFailure: { error, send in
    if case .higherPriorityExists(let requested, let current) = error as? LockmanPriorityBasedError {
        send(.priorityConflict("高優先度処理実行中のため待機中"))
    }
}
```

**samePriorityConflict** - 同一優先度での競合

```swift
lockFailure: { error, send in
    if case .samePriorityConflict(let priority) = error as? LockmanPriorityBasedError {
        send(.busyMessage("同じ優先度の処理が実行中です"))
    }
}
```

**blockedBySameAction** - 同一アクションによる阻止

```swift
lockFailure: { error, send in
    if case .blockedBySameAction(let existingInfo) = error as? LockmanPriorityBasedError {
        send(.duplicateAction("同じ処理が既に実行中です"))
    }
}
```

**precedingActionCancelled** - 先行処理のキャンセル

```swift
catch: { error, send in
    if case .precedingActionCancelled(let cancelledInfo) = error as? LockmanPriorityBasedError {
        send(.processCancelled("高優先度処理により中断されました"))
    }
}
```
