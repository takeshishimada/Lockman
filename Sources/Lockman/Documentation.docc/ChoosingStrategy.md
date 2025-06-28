# Choosing a Strategy

Learn how to select the right strategy for your use case.

## Overview

Lockmanの戦略システムは、アノテーションによる宣言的な戦略選択、複数戦略の組み合わせ、カスタム戦略の実装という3つの主要な特徴を持ちます。

### 戦略の選択

開発者はアノテーションを使用して、処理の性質に応じた適切な戦略を選択できます。重複防止が必要な場合は`@LockmanSingleExecution`、優先度制御が必要な場合は`@LockmanPriorityBased`、グループ協調が必要な場合は`@LockmanGroupCoordination`など、目的に応じて戦略を宣言的に指定します。

```swift
@LockmanSingleExecution
enum Action {

@LockmanPriorityBased  
enum Action {

@LockmanGroupCoordination
enum Action {
```

### 戦略の組み合わせ

単一戦略では対応できない複雑な要件に対して、複数の戦略を組み合わせることで、より高度な排他制御を実現できます。`@LockmanCompositeStrategy`アノテーションを使用して、最大5つまでの戦略を組み合わせることが可能です。

```swift
@LockmanCompositeStrategy(
  LockmanSingleExecutionStrategy.self,
  LockmanPriorityBasedStrategy.self
)
enum Action {
```

### カスタム戦略の作成

標準戦略では満たせないプロジェクト固有の要件に対して、独自の戦略を作成できます。これにより、ビジネスロジックに特化した排他制御ルールを定義することが可能です。

