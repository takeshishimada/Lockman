# Choosing a Strategy

Learn how to select the right strategy for your use case.

## Overview

Lockmanの戦略システムは、アノテーションによる宣言的な戦略選択、複数戦略の組み合わせ、カスタム戦略の実装という3つの主要な特徴を持ちます。

## 戦略の選択

開発者はアノテーションを使用して、処理の性質に応じた適切な戦略を選択できます。

```swift
@LockmanSingleExecution
enum Action {

@LockmanPriorityBased  
enum Action {

@LockmanGroupCoordination
enum Action {
```

## 戦略の組み合わせ

単一戦略では対応できない複雑な要件に対して、複数の戦略を組み合わせることで、より高度な排他制御を実現できます。[`@LockmanCompositeStrategy`](<doc:CompositeStrategy>)アノテーションを使用して、最大5つまでの戦略を組み合わせることが可能です。

```swift
@LockmanCompositeStrategy(
  LockmanSingleExecutionStrategy.self,
  LockmanPriorityBasedStrategy.self
)
enum Action {
```

## 提供されている戦略

Lockmanは以下の5つの標準戦略を提供しています：

### [SingleExecutionStrategy](<doc:SingleExecutionStrategy>) - 重複実行の防止

- 同じ処理が重複して実行されることを防ぎます
- ユーザーのボタン連続タップ防止などに適用

### [PriorityBasedStrategy](<doc:PriorityBasedStrategy>) - 優先度ベースの制御

- 優先度の高い処理が低い処理を中断して実行できます
- 緊急処理や重要度に応じた処理制御に適用

### [GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>) - グループ協調制御

- 関連する複数の処理をグループとして協調制御します
- リーダー・メンバー関係での処理管理に適用

### [ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>) - 同時実行数の制限

- 指定した数まで同時実行を許可し、超過分は待機または拒否します
- リソース使用量の制御やパフォーマンス最適化に適用

### [DynamicConditionStrategy](<doc:DynamicConditionStrategy>) - 動的条件制御

- 実行時の条件に基づいて動的に制御を行います
- ビジネスロジックに応じたカスタム制御に適用

各戦略の詳細な仕様と使用方法については、それぞれの専用ページをご参照ください。

## ガイド

次のステップ <doc:Configuration>

前のステップ <doc:Unlock>
