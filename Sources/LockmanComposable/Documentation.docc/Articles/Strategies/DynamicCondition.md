# Dynamic Condition Strategy

実行時の条件に基づいて動的にアクションを制御する戦略

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`DynamicConditionStrategy`は、実行時に評価される条件に基づいてアクションの実行可否を決定する戦略です。

## 条件関数の仕組み

### 基本構造

```swift
// The condition closure signature is:
// @Sendable () -> Bool  // Note: NOT async

struct ConditionalAction: LockmanDynamicConditionAction {
    let actionName = "conditionalAction"
    
    // Using the protocol's default implementation
    // which provides lockmanInfo with always-true condition
    // and strategyId = .dynamicCondition
}
```

### 条件評価のタイミング

1. `Effect.withLock`呼び出し時
2. ロック取得前に条件を評価
3. `true`の場合のみロック取得・実行
4. `false`の場合は`.none`を返す

## @LockmanDynamicConditionマクロ

`@LockmanDynamicCondition`マクロを使用して、条件付きアクションを簡潔に定義できます。

```swift
@LockmanDynamicCondition
enum PremiumAction {
    case exportData
    case advancedAnalytics
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        .init(
            actionId: actionName,  // マクロが生成
            condition: { 
                // 実行時に評価される条件
                UserService.shared.isPremiumUser
            }
        )
    }
}
```

### マクロが生成するもの

1. **`LockmanDynamicConditionAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

### 動的な条件の設定

状態に基づく条件やパラメータに基づく条件を定義：

```swift
@LockmanDynamicCondition
enum ConditionalAction {
    case processLargeFile(size: Int64)
    case syncData(force: Bool)
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        switch self {
        case .processLargeFile(let size):
            return .init(
                actionId: "processFile",
                condition: {
                    // 大きいファイルは空き容量をチェック
                    size < 100_000_000 || StorageManager.hasSpace(for: size)
                }
            )
        case .syncData(let force):
            return .init(
                actionId: "syncData",
                condition: {
                    // 強制同期またはWiFi接続時のみ
                    force || NetworkMonitor.isWiFiConnected
                }
            )
        }
    }
}
```

## 次のステップ

- <doc:EffectWithLock> - withLock APIの詳細な使い方
- <doc:Composite> - 条件付き実行と他の戦略の組み合わせ
- <doc:CustomStrategy> - 独自の条件ロジックの実装
- <doc:Debugging> - 条件評価のデバッグ方法
