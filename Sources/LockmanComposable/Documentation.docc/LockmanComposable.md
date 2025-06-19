# ``LockmanComposable``

The Composable Architecture向け並行アクション制御ライブラリ

@Metadata {
    @DisplayName("Lockman")
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
    @PageColor(blue)
    @TitleHeading("Welcome to")
}

## 概要

LockmanはThe Composable Architectureアプリケーションにおける並行アクション制御の課題を解決するSwiftライブラリです。レスポンシブで透明性の高い、宣言的な設計により、シンプルかつ型安全に制御できます。

### なぜLockmanが必要か

TCAアプリケーションでは、以下のような課題がよく発生します：

- 同じAPIへの重複リクエストの防止
- 画面の二重遷移防止
- 複数の非同期処理の適切な順序制御
- リソースアクセスの排他制御

Lockmanは、これらの課題をTCAの設計思想に沿って解決します。

### 主な特徴

- **TCAネイティブ統合**: Effect拡張として自然に組み込まれ、既存のTCAパターンを活用
- **CancelIDベースの境界管理**: TCAの既存のキャンセレーション機能と完全に統合
- **ロック管理**: ロックの取得・解放を自動化し、デッドロックを防止
- **5つの制御戦略**: 一般的なユースケースに対応する組み込み戦略
- **型安全**: Swiftの型システムを最大限活用した安全な設計


## トピックス

### Getting Started

まずはLockmanの基本を学びましょう。

- <doc:QuickStart> - 5分で始めるLockman

### 戦略ガイド

用途に応じた5つの制御戦略を提供しています。

- <doc:SingleExecution> - 重複実行を防ぐ基本戦略
- <doc:PriorityBased> - 優先度に基づく実行制御
- <doc:GroupCoordination> - 複数の処理をグループで管理
- <doc:DynamicCondition> - 動的な条件による制御
- <doc:Composite> - 戦略の組み合わせ

### Core Concepts

Lockmanの中核となる概念を理解しましょう。

- <doc:EffectWithLock> - withLock APIの詳細
- <doc:CancelIDAndBoundaries> - 境界とキャンセレーション
- <doc:UnlockOptions> - ロック解放オプション

### Advanced Topics

より深い理解のための詳細情報です。

- <doc:CustomStrategy> - カスタム戦略の実装
- <doc:LockmanProtocols> - プロトコル階層の詳細

### リファレンス

- <doc:Debugging> - デバッグとトラブルシューティング


## インストール

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/kabiroberai/Lockman.git", from: "1.0.0")
]
```

```swift
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "LockmanComposable", package: "Lockman")
        ]
    )
]
```

## 要件

- Swift 5.9+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- The Composable Architecture 1.17.1+

## 次のステップ

Lockmanを使い始める準備ができました！

1. **初めての方**: <doc:QuickStart> で基本的な使い方を5分で学びましょう
2. **戦略を選ぶ**: 戦略ガイドセクションで最適な戦略を見つけましょう

## サポート

- **Issues**: [GitHub Issues](https://github.com/kabiroberai/Lockman/issues)
- **Discussions**: [GitHub Discussions](https://github.com/kabiroberai/Lockman/discussions)
- **Contributing**: プルリクエストを歓迎します！
