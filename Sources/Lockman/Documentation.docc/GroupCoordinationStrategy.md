# GroupCoordinationStrategy

Coordinate actions through leader/member group roles.

## Overview

GroupCoordinationStrategyは、関連する処理をグループとして協調制御する戦略です。リーダー・メンバーの役割分担により、複数の処理が適切な順序と条件で実行されることを保証します。

この戦略は、複数の関連処理が協調して動作する必要がある場面で使用されます。

## グループシステム

### 協調役割

**none** - 非排他的参加者

```swift
LockmanGroupCoordinatedInfo(
    actionId: "showProgress",
    groupIds: ["dataLoading"],
    coordinationRole: .none
)
```

- グループの状態に関係なく参加可能
- 他の参加者の実行を妨げない
- UI更新やログ記録などの補助的処理

**leader** - グループリーダー

```swift
LockmanGroupCoordinatedInfo(
    actionId: "startSync",
    groupIds: ["syncGroup"],
    coordinationRole: .leader(.emptyGroup)
)
```

- グループの活動を開始する役割
- エントリーポリシーに従って参加条件を制御
- メンバーの参加を可能にする

**member** - グループメンバー

```swift
LockmanGroupCoordinatedInfo(
    actionId: "processData", 
    groupIds: ["syncGroup"],
    coordinationRole: .member
)
```

- アクティブなグループにのみ参加可能
- リーダーまたは他の参加者がいる場合に実行
- 協調的な処理を担当

### リーダーエントリーポリシー

**emptyGroup** - 空グループでのみ開始

```swift
.leader(.emptyGroup)
```

- グループが完全に空の場合のみ参加可能
- 新しい活動サイクルを開始
- 最も厳格な制御

**withoutMembers** - メンバーなしで開始

```swift
.leader(.withoutMembers)
```

- メンバーがいない場合に参加可能
- 他のリーダーは許可
- リーダー間の協調を可能

**withoutLeader** - リーダーなしで開始

```swift
.leader(.withoutLeader)
```

- 他のリーダーがいない場合に参加可能
- メンバーは許可
- リーダー権限の排他制御

## 使用方法

### 基本的な使用例

```swift
@LockmanGroupCoordination
enum Action {
    case startDataSync
    case processChunk
    case showProgress
    
    var lockmanInfo: LockmanGroupCoordinatedInfo {
        switch self {
        case .startDataSync:
            return LockmanGroupCoordinatedInfo(
                actionId: actionName,
                groupIds: ["dataSync"],
                coordinationRole: .leader(.emptyGroup)
            )
        case .processChunk:
            return LockmanGroupCoordinatedInfo(
                actionId: actionName,
                groupIds: ["dataSync"],
                coordinationRole: .member
            )
        case .showProgress:
            return LockmanGroupCoordinatedInfo(
                actionId: actionName,
                groupIds: ["dataSync"],
                coordinationRole: .none
            )
        }
    }
}
```

### 複数グループでの協調

```swift
LockmanGroupCoordinatedInfo(
    actionId: "crossGroupOperation",
    groupIds: ["group1", "group2", "group3"],
    coordinationRole: .leader(.emptyGroup)
)
```

## 動作例

### リーダー・メンバー協調

```
時刻: 0秒  - leader(.emptyGroup)開始     → ✅ 実行（グループ空）
時刻: 1秒  - member参加要求             → ✅ 実行（リーダー存在）
時刻: 1秒  - member参加要求             → ✅ 実行（グループアクティブ）
時刻: 2秒  - leader(.emptyGroup)要求    → ❌ 拒否（グループアクティブ）
時刻: 5秒  - 全参加者完了               → 🔓 グループ解散
時刻: 6秒  - leader(.emptyGroup)要求    → ✅ 実行（グループ空）
```

### エントリーポリシーの違い

```
// .emptyGroup の場合
グループ状態: [空] → leader要求 → ✅ 許可
グループ状態: [member] → leader要求 → ❌ 拒否

// .withoutMembers の場合  
グループ状態: [leader] → leader要求 → ✅ 許可
グループ状態: [member] → leader要求 → ❌ 拒否

// .withoutLeader の場合
グループ状態: [member] → leader要求 → ✅ 許可
グループ状態: [leader] → leader要求 → ❌ 拒否
```

## エラーハンドリング

### LockmanGroupCoordinationError

**actionAlreadyInGroup** - アクションが既にグループに参加

```swift
lockFailure: { error, send in
    if case .actionAlreadyInGroup(let existingInfo, let groupIds) = error as? LockmanGroupCoordinationError {
        send(.alreadyActive("処理が既に実行中です"))
    }
}
```

**leaderCannotJoinNonEmptyGroup** - リーダーが空でないグループに参加拒否

```swift
lockFailure: { error, send in
    if case .leaderCannotJoinNonEmptyGroup(let groupIds) = error as? LockmanGroupCoordinationError {
        send(.groupBusy("他の処理が実行中のため開始できません"))
    }
}
```

**memberCannotJoinEmptyGroup** - メンバーが空グループに参加拒否

```swift
lockFailure: { error, send in
    if case .memberCannotJoinEmptyGroup(let groupIds) = error as? LockmanGroupCoordinationError {
        send(.noActiveGroup("アクティブなグループがありません"))
    }
}
```

## ガイド

次のステップ <doc:DynamicConditionStrategy>

前のステップ <doc:ConcurrencyLimitedStrategy>
