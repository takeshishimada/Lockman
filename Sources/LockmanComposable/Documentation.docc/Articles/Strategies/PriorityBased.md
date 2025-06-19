# Priority Based Strategy

優先度に基づいてアクションの実行を制御する高度な戦略

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`PriorityBasedStrategy`は、アクションに優先度を設定し、高優先度のアクションが低優先度のアクションを置き換えたり、実行をブロックしたりできる戦略です。

## 優先度システム

### 優先度レベル

```swift
public enum Priority {
    case none                           // 優先度制御なし
    case high(ConcurrencyBehavior)     // 高優先度
    case low(ConcurrencyBehavior)      // 低優先度
}

public enum ConcurrencyBehavior {
    case exclusive      // 排他的実行（新しいアクションをブロック）
    case replaceable    // 置換可能（新しいアクションが古いものを置き換え）
}
```

### 動作原理

1. **高優先度 > 低優先度**: 高優先度アクションは常に低優先度より優先
2. **同じ優先度**: ConcurrencyBehaviorで動作を決定
3. **none**: 優先度による制御を行わない

## @LockmanPriorityBasedマクロ

`@LockmanPriorityBased`マクロを使用して、優先度ベースのアクションを簡潔に定義できます。

```swift
@LockmanPriorityBased
enum SearchAction {
    case searchUsers(query: String)
    case searchPosts(query: String)
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,  // マクロが生成
            priority: .high(.replaceable),
            blocksSameAction: false
        )
    }
}
```

### マクロが生成するもの

1. **`LockmanPriorityBasedAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

## 高度な機能

### blocksSameAction

同じactionIdの実行をブロック：

```swift
struct CriticalSaveAction: LockmanPriorityBasedAction {
    let actionName = "criticalSave"
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .high(.exclusive),
            blocksSameAction: true  // 同じ保存操作は1つのみ
        )
    }
}
```

このオプションにより、<doc:SingleExecution>との組み合わせを省略できます。

## 次のステップ

- <doc:EffectWithLock> - withLock APIの詳細な使い方
- <doc:GroupCoordination> - グループベースの協調制御
- <doc:Composite> - 優先度と他の戦略の組み合わせ
