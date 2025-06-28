# Getting Started

Learn how to integrate Lockman into your TCA application.

## Overview

このガイドでは、LockmanをThe Composable Architecture (TCA)プロジェクトに統合し、最初の機能を実装する方法を学びます。

Lockmanは、TCAアプリケーションでユーザーアクションの排他制御を簡単に実現するためのライブラリです。ボタンの連打防止やAPIリクエストの重複実行防止など、一般的な排他制御のニーズに対応します。

## Adding Lockman as a dependency

プロジェクトにLockmanを追加するには、Xcodeのパッケージ依存関係に以下を追加します：

```
https://github.com/takeshishimada/Lockman
```

そして、Lockmanを使用するファイルでインポートします：

```swift
import Lockman
import ComposableArchitecture
```

## Writing your first feature

`@LockmanSingleExecution`マクロを使用して、処理の重複実行を防ぐ機能を実装してみましょう。

### Step 1: Reducerを定義する

まず、基本的なReducerの構造を定義します：

```swift
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
}
```

### Step 2: StateとActionを定義する

処理状態を管理するStateと、実行可能なアクションを定義します：

```swift
@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
    @LockmanSingleExecution
    enum Action {
        case startProcessButtonTapped
        case processStart
        case processCompleted
        
        var lockmanInfo: LockmanSingleExecutionInfo {
            switch self {
            case .startProcessButtonTapped:
                return .init(actionId: actionName, mode: .boundary)
            case .processStart, .processCompleted:
                return .init(actionId: actionName, mode: .none)
            }
        }
    }
}
```

ここで重要なのは：

- `@LockmanSingleExecution`マクロをAction enumに適用することで、このenumが`LockmanSingleExecutionAction`プロトコルに準拠します
- `lockmanInfo`プロパティは各アクションのロック制御方法を定義します
  - `mode: .boundary`：このアクションがロックの境界となり、処理の開始と終了を管理します
  - `mode: .none`：ロック制御に関与しない内部アクションです

### Step 3: Reducer本体を実装する

`withLock`メソッドを使用して、排他制御を伴う処理を実装します：

```swift
var body: some Reducer<State, Action> {
    Reduce { state, action in
        switch action {
        case .startProcessButtonTapped:
            return .withLock(
                operation: { send in
                    await send(.processStart)
                    // 重い処理をシミュレート
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await send(.processCompleted)
                },
                lockFailure: { error, send in
                    // すでに処理が実行中の場合
                    state.message = "処理は既に実行中です"
                },
                action: action
            )
            
        case .processStart:
            state.isProcessing = true
            state.message = "処理を開始しました..."
            return .none
            
        case .processCompleted:
            state.isProcessing = false
            state.message = "処理が完了しました"
            return .none
        }
    }
}
```

`withLock`メソッドの重要なポイント：

- `operation`：排他制御下で実行される処理を定義します
- `lockFailure`：すでに同じ処理が実行中の場合に呼ばれるハンドラーです
- `action`：現在処理中のアクションを渡します

これで、`startProcessButtonTapped`アクションは処理中に再度実行されることがなくなり、ユーザーが誤って複数回ボタンをタップしても安全です。

次のステップとして、より高度な排他制御戦略について学ぶには、[Advanced Features](<doc:AdvancedFeatures>)セクションを参照してください。