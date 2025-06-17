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
* **Composite Strategy**: 複数戦略の組み合わせ

## 基本例

プロフィール写真選択における優先度ベースのアクション制御の例：

```swift
import ComposableArchitecture
import LockmanComposable

@Reducer
struct ProfilePhotoFeature {
  @ObservableState
  struct State {
    var photos: [Photo] = []
    var selectedPhotoId: Photo.ID?
  }
  
  enum Action {
    case view(ViewAction)
    case `internal`(InternalAction)
    
    @LockmanPriorityBased
    enum ViewAction {
      case thumbnailTapped(Photo.ID)
      case updateProfilePhoto(Photo.ID)
      
      var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .thumbnailTapped:
          .init(actionId: actionName, priority: .low(.replaceable))
        case .updateProfilePhoto:
          .init(actionId: actionName, priority: .high(.exclusive))
        }
      }
    }
    
    enum InternalAction {
      case photoPreviewLoaded(Photo.ID, UIImage)
      case profilePhotoUpdated(Result<Photo, Error>)
    }
  }
  
  enum CancelID {
    case userAction
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        switch viewAction {
        case let .thumbnailTapped(photoId):
          // 低優先度：選択を即座に表示し、プレビューを読み込み
          state.selectedPhotoId = photoId
          return .withLock(
            operation: { send in
              let image = try await photoClient.loadPreview(photoId)
              await send(.internal(.photoPreviewLoaded(photoId, image)))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
          
        case let .updateProfilePhoto(photoId):
          // 高優先度（排他的）：他の全ての操作をブロック
          return .withLock(
            operation: { send in
              let updatedPhoto = try await profileAPI.updatePhoto(photoId)
              await send(.internal(.profilePhotoUpdated(.success(updatedPhoto))))
            },
            action: viewAction,
            cancelID: CancelID.userAction
          )
        }
        
      case let .internal(internalAction):
        switch internalAction {
        case let .photoPreviewLoaded(photoId, image):
          // プレビューでUIを更新
          return .none
          
        case let .profilePhotoUpdated(.success(photo)):
          // 更新成功
          return .none
          
        case .profilePhotoUpdated(.failure):
          // エラー処理
          return .none
        }
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