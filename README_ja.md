<img src="Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift 5.9](https://img.shields.io/badge/swift-5.9-ED523F.svg?style=flat)](https://swift.org/download/)
[![@takeshishimada](https://img.shields.io/badge/contact-@takeshishimada-1DA1F2.svg?style=flat&logo=twitter)](https://twitter.com/takeshishimada)

The Composable Architectureアプリケーション向けのアクション排他制御ライブラリ

* [概要](#概要)
* [基本例](#基本例)
* [インストール](#インストール)
* [コミュニティ](#コミュニティ)

## 概要

LockmanはThe Composable Architecture（TCA）アプリケーションにおける並行アクションの制御問題を解決するSwiftライブラリです。ユーザーがボタンを連続してタップした際の重複API呼び出しの防止、優先度に基づくタスクのキャンセル、グループ内での協調制御など、実際のアプリ開発で頻繁に発生する問題に対処します。

Lockmanは以下の制御戦略を提供します：

* **Single Execution**: 同じアクションの重複実行を防止
* **Priority Based**: 優先度に基づくアクションの制御とキャンセル
* **Group Coordination**: リーダー/メンバーの役割によるグループ制御
* **Dynamic Condition**: 実行時条件による動的制御
* **Composite Strategy**: 複数戦略の組み合わせ

## 基本例

ボタンの連続タップによるAPI重複呼び出しを防ぐ例：

```swift
import ComposableArchitecture
import LockmanComposable

@Reducer
struct UserFeature {
  @ObservableState
  struct State {
    var user: User?
  }
  
  @LockmanSingleExecution
  enum Action {
    case fetchUserTapped
    case userResponse(Result<User, Error>)
  }
  
  enum CancelID {
    case userFetch
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .fetchUserTapped:
        return .withLock(
          operation: { send in
            let user = try await userAPIClient.fetchUser()
            await send(.userResponse(.success(user)))
          },
          catch: { error, send in
            await send(.userResponse(.failure(error)))
          },
          action: action,
          cancelID: CancelID.userFetch
        )
        
      case let .userResponse(result):
        switch result {
        case let .success(user):
          state.user = user
        case .failure:
          break
        }
        return .none
      }
    }
  }
}
```

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
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.1.0")
]
```

ターゲットに依存関係を追加：

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "LockmanComposable", package: "Lockman"),
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
| 0.1.0   | 1.7.1                      |

## コミュニティ

### 議論とヘルプ

質問や議論は[GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions)で行えます。

### バグ報告

バグを発見した場合は[Issues](https://github.com/takeshishimada/Lockman/issues)で報告してください。

### コントリビューション

ライブラリにコントリビュートしたい場合は、リンク付きのPRを開いてください！

## ライセンス

このライブラリはMITライセンスの下でリリースされています。詳細は[LICENSE](./LICENSE)ファイルをご確認ください。