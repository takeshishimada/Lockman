# Quick Start

LockmanをTCAプロジェクトで使い始めるための最短ガイド

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

Lockmanは、TCAのEffect内で発生する非同期処理の競合を制御するライブラリです。このガイドでは、5分でLockmanの基本的な使い方を習得できます。

## インストール

Package.swiftに以下を追加：

```swift
dependencies: [
    .package(url: "https://github.com/kabiroberai/Lockman.git", from: "1.0.0")
]
```

ターゲットに追加：

```swift
.product(name: "LockmanComposable", package: "Lockman")
```

## 基本的な使い方

### 1. インポートとCancelIDの定義

```swift
import ComposableArchitecture
import LockmanComposable

@Reducer
struct CounterFeature {
    @ObservableState
    struct State {
        var count = 0
        var isLoading = false
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case incrementButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(actionId: actionName, mode: .boundary)
            }
        }
        
        enum InternalAction {
            case countUpdated(Int)
        }
    }
    
    enum CancelID {
        case userAction
    }
```


### 2. Effect.withLockの使用

```swift
var body: some Reducer<State, Action> {
    Reduce { state, action in
        switch action {
        case .view(let viewAction):
            switch viewAction {
            case .incrementButtonTapped:
                state.isLoading = true
                
                return .withLock(
                    operation: { send in
                        try await Task.sleep(for: .seconds(2))
                        await send(.internal(.countUpdated(state.count + 1)))
                    },
                    action: viewAction,
                    cancelID: CancelID.userAction
                )
            }
            
        case .internal(let internalAction):
            switch internalAction {
            case let .countUpdated(newCount):
                state.count = newCount
                state.isLoading = false
                return .none
            }
        }
    }
}
```

## よくある質問

### Q: LockmanCoreもインポートする必要はありますか？

A: いいえ、`LockmanComposable`が`LockmanCore`のすべての機能を再エクスポートしています。

### Q: CancelIDとLockmanBoundaryIdの関係は？

A: TCAの`CancelID`がそのまま`LockmanBoundaryId`として機能します。新しい型を定義する必要はありません。

### Q: 戦略はどう選べばいいですか？

A: 一般的なガイドライン：
- **重複防止**: `SingleExecutionStrategy`
- **優先度制御**: `PriorityBasedStrategy`
- **グループ処理**: `GroupCoordinationStrategy`
- **条件付き実行**: `DynamicConditionStrategy`

詳細は戦略ガイドセクションを参照してください。

## 次のステップ

- <doc:EffectWithLock> - Effect.withLockAPIの詳細
- <doc:Debugging> - デバッグとトラブルシューティング