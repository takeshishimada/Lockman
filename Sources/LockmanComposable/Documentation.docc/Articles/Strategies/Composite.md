# Composite Strategy

複数の戦略を組み合わせて高度な制御を実現する戦略

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`CompositeStrategy`は、複数のLockman戦略を組み合わせて使用できる強力な戦略です。

Lockmanは2〜5個の戦略を組み合わせることができ、それぞれに対応する型が用意されています：
- `LockmanCompositeInfo2` - 2つの戦略を組み合わせる
- `LockmanCompositeInfo3` - 3つの戦略を組み合わせる
- `LockmanCompositeInfo4` - 4つの戦略を組み合わせる
- `LockmanCompositeInfo5` - 5つの戦略を組み合わせる

## 動作原理

### 戦略の評価順序

1. 指定された順番通りに各戦略を評価
2. いずれかが`.failure`を返したら即座に中断
3. すべてが`.success`または`.successWithPrecedingCancellation`なら実行
4. キャンセルが必要な場合は自動的に処理

## @LockmanCompositeStrategyマクロ

`@LockmanCompositeStrategy`マクロを使用して、複数の戦略を組み合わせたアクションを定義できます。

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self
)
enum ComplexAction {
    case processPayment(amount: Decimal)
    
    var lockmanInfo: LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> {
        .init(
            actionId: actionName,  // マクロが生成
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        )
    }
}
```

### マクロが生成するもの

1. **適切な`LockmanCompositeActionN`プロトコルへの準拠**（Nは戦略数）
2. **`actionName`プロパティ** - enumのcase名の文字列を返す
3. **戦略IDの自動生成** - 組み合わせた戦略から一意のIDを生成

### 3つ以上の戦略の組み合わせ

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self,
    LockmanDynamicConditionStrategy.self
)
enum AdvancedAction {
    case complexOperation
    
    var lockmanInfo: LockmanCompositeInfo3<
        LockmanSingleExecutionInfo,
        LockmanPriorityBasedInfo,
        LockmanDynamicConditionInfo
    > {
        .init(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            ),
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: { UserService.shared.isPremium }
            )
        )
    }
}
```

## 次のステップ

- <doc:EffectWithLock> - withLock APIの詳細な使い方
- <doc:CustomStrategy> - カスタム戦略を組み合わせる方法
- <doc:Debugging> - 複合戦略のデバッグ方法
