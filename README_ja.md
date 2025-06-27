<img src="Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

LockmanはThe Composable Architecture（TCA）アプリケーションにおける並行アクションの制御問題を解決するSwiftライブラリです。応答性、透明性、宣言的設計を重視しています。

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
* **Concurrency Limited**: グループごとの並行実行数を制限
* **Composite Strategy**: 複数戦略の組み合わせ

## 基本例

単一実行アクション制御の例：

![01-SingleExecutionStrategy](https://github.com/user-attachments/assets/3f630c51-94c9-4404-b06a-0f565e1bedd3)

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
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)

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
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.5.0")
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
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

## コミュニティ

### 議論とヘルプ

質問や議論は[GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions)で行えます。

### バグ報告

バグを発見した場合は[Issues](https://github.com/takeshishimada/Lockman/issues)で報告してください。

### コントリビューション

ライブラリにコントリビュートしたい場合は、リンク付きのPRを開いてください！

## ライセンス

このライブラリはMITライセンスの下でリリースされています。詳細は[LICENSE](./LICENSE)ファイルをご確認ください。
