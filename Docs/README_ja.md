<img src="../Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [Español](README_es.md) | [Français](README_fr.md) | [Deutsch](README_de.md) | [한국어](README_ko.md) | [Português](README_pt-BR.md) | [Italiano](README_it.md)

LockmanはThe Composable Architecture（TCA）アプリケーションにおける排他アクションの制御問題を解決するSwiftライブラリです。応答性、透明性、宣言的設計を重視しています。

* [設計思想](#設計思想)
* [概要](#概要)
* [基本例](#基本例)
* [インストール](#インストール)
* [コミュニティ](#コミュニティ)

## 設計思想

### Designing Fluid Interfacesの原則

WWDC18「Designing Fluid Interfaces」では、優れたインターフェースの原則が示されました：

* **即座の応答と継続的なリダイレクション** - 10msの遅延も感じさせない応答性
* **タッチとコンテンツの1対1の動き** - ドラッグ時にコンテンツが指に追従
* **継続的なフィードバック** - すべてのインタラクションに対する即座の反応
* **複数ジェスチャーの並列検出** - 同時に複数のジェスチャーを認識
* **空間的な一貫性の維持** - アニメーション中の位置の一貫性
* **軽量なインタラクション、増幅された出力** - 小さな入力から大きな効果

### 従来の課題

従来のUI開発では、ボタンの同時押しや重複実行を単純に禁止することで問題を解決してきました。これらのアプローチは現代の流動的なインターフェース設計において、ユーザー体験を阻害する要因となっています。

ユーザーは押下可能なボタンに対して、同時押しの場合でも何らかのフィードバックを期待します。UI層での即座の応答と、ビジネスロジック層での適切な排他制御を明確に分離することが重要です。

## 概要

Lockmanは以下の制御戦略を提供し、実際のアプリ開発で頻繁に発生する問題に対処します：

* **Single Execution**: 同じアクションの重複実行を防止
* **Priority Based**: 優先度に基づくアクションの制御とキャンセル
* **Group Coordination**: リーダー/メンバーの役割によるグループ制御
* **Dynamic Condition**: 実行時条件による動的制御
* **Concurrency Limited**: グループごとの同時実行数を制限
* **Composite Strategy**: 複数戦略の組み合わせ

## 例

| Single Execution Strategy | Priority Based Strategy | Concurrency Limited Strategy |
|--------------------------|------------------------|------------------------------|
| ![Single Execution Strategy](../Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Priority Based Strategy](../Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Concurrency Limited Strategy](../Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## コード例

`@LockmanSingleExecution`マクロを使用して、処理の重複実行を防ぐ機能を実装する方法：

```swift
import CasePaths
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
    @CasePathable
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case startProcessButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(actionId: actionName, mode: .boundary)
            }
        }
        
        enum InternalAction {
            case processStart
            case processCompleted
            case updateMessage(String)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .startProcessButtonTapped:
                    return .run { send in
                        await send(.internal(.processStart))
                        // 重い処理をシミュレート
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.internal(.processCompleted))
                    }
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "処理を開始しました..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "処理が完了しました"
                    return .none
                    
                case .updateMessage(let message):
                    state.message = message
                    return .none
                }
            }
        }
        .lock(
            boundaryId: CancelID.userAction,
            lockFailure: { error, send in
                // すでに処理が実行中の場合
                if error is LockmanSingleExecutionError {
                    // アクションを通じてメッセージを更新
                    await send(.internal(.updateMessage("処理は既に実行中です")))
                }
            },
            for: \.view
        )
    }
}
```

`Reducer.lock`モディファイアは`LockmanAction`に準拠するアクションに対して自動的にロック管理を適用します。`ViewAction`列挙型が`@LockmanSingleExecution`でマークされているため、`startProcessButtonTapped`アクションは処理中に再実行されません。`for: \.view`パラメータはLockmanに`view`ケースにネストされたアクションの`LockmanAction`準拠性をチェックするよう指示します。

### デバッグ出力例

```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7BFC785A-3D25-4722-B9BC-A3A63A7F49FC, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 1EBA9632-DE39-43B6-BE75-7C754476CD4E, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 6C5C569F-4534-40D7-98F6-B4F4B0EE1293, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: C6779CD1-F8FE-46EB-8605-109F7C8DCEA8, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: A54E7748-A3DE-451A-BF06-56224A5C94DA, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7D4D67A7-1A8C-4521-BB16-92E0D551451A, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 08CC1862-136F-4643-A796-F63156D8BF56, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: DED418D1-4A10-4EF8-A5BC-9E93D04188CA, mode: boundary), Reason: Boundary 'process' already has an active lock

📊 Current Lock State (SingleExecutionStrategy):
┌─────────────────┬──────────────────┬──────────────────────────────────────┬─────────────────┐
│ Strategy        │ BoundaryId       │ ActionId/UniqueId                    │ Additional Info │
├─────────────────┼──────────────────┼──────────────────────────────────────┼─────────────────┤
│ SingleExecution │ CancelID.process │ startProcessButtonTapped             │ mode: boundary  │
│                 │                  │ 08CC1862-136F-4643-A796-F63156D8BF56 │                 │
└─────────────────┴──────────────────┴──────────────────────────────────────┴─────────────────┘
```

## ドキュメント

リリース版とmainのドキュメントはこちらで利用できます：

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [1.0.0](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/) ([マイグレーションガイド](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/migrationguides/migratingto1.0))

<details>
<summary>その他のバージョン</summary>

* [0.13.0](https://takeshishimada.github.io/Lockman/0.13.0/documentation/lockman/)
* [0.12.0](https://takeshishimada.github.io/Lockman/0.12.0/documentation/lockman/)
* [0.11.0](https://takeshishimada.github.io/Lockman/0.11.0/documentation/lockman/)
* [0.10.0](https://takeshishimada.github.io/Lockman/0.10.0/documentation/lockman/)
* [0.9.0](https://takeshishimada.github.io/Lockman/0.9.0/documentation/lockman/)
* [0.8.0](https://takeshishimada.github.io/Lockman/0.8.0/documentation/lockman/)
* [0.7.0](https://takeshishimada.github.io/Lockman/0.7.0/documentation/lockman/)
* [0.6.0](https://takeshishimada.github.io/Lockman/0.6.0/documentation/lockman/)
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)
* [0.4.0](https://takeshishimada.github.io/Lockman/0.4.0/documentation/lockman/)
* [0.3.0](https://takeshishimada.github.io/Lockman/0.3.0/documentation/lockman/)

</details>

ライブラリをより深く理解するために、以下のドキュメントが役立つでしょう：

### Essentials
* [Getting Started](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - LockmanをTCAアプリケーションに統合する方法
* [Boundary Overview](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Lockmanにおける境界の概念を理解する
* [Lock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - ロック機構の理解
* [Unlock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - アンロック機構の理解
* [Choosing a Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - ユースケースに適した戦略を選択する
* [Configuration](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - アプリケーションのニーズに合わせてLockmanを設定する
* [Error Handling](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - 一般的なエラーハンドリングパターンを学ぶ
* [Debugging Guide](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - アプリケーションのLockman関連の問題をデバッグする

### 戦略
* [Single Execution Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - 重複実行を防止
* [Priority Based Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - 優先度に基づく制御
* [Concurrency Limited Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - 同時実行数を制限
* [Group Coordination Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - 関連するアクションを協調
* [Dynamic Condition Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - 動的なランタイム制御
* [Composite Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - 複数の戦略を組み合わせる

## インストール

Lockmanは[Swift Package Manager](https://swift.org/package-manager/)でインストールできます。

### Xcode

Xcodeで File → Add Package Dependencies を選択し、以下のURLを入力：

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Package.swiftファイルに依存関係を追加：

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "1.0.0")
]
```

ターゲットに依存関係を追加：

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### 動作要件

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 13.0           |
| macOS    | 10.15          |
| tvOS     | 13.0           |
| watchOS  | 6.0            |

### バージョン互換性

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.0.0   | 1.20.2                     |
| 0.13.4  | 1.20.2                     |
| 0.13.3  | 1.20.2                     |
| 0.13.2  | 1.20.2                     |
| 0.13.1  | 1.20.2                     |
| 0.13.0  | 1.20.2                     |
| 0.12.0  | 1.20.1                     |
| 0.11.0  | 1.19.1                     |
| 0.10.0  | 1.19.0                     |
| 0.9.0   | 1.18.0                     |
| 0.8.0   | 1.17.1                     |

<details>
<summary>その他のバージョン</summary>

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.7.0   | 1.17.1                     |
| 0.6.0   | 1.17.1                     |
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

</details>

## コミュニティ

### 議論とヘルプ

質問や議論は[GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions)で行えます。

### バグ報告

バグを発見した場合は[Issues](https://github.com/takeshishimada/Lockman/issues)で報告してください。

### コントリビューション

ライブラリにコントリビュートしたい場合は、リンク付きのPRを開いてください！

## ライセンス

このライブラリはMITライセンスの下でリリースされています。詳細は[LICENSE](./LICENSE)ファイルをご確認ください。
