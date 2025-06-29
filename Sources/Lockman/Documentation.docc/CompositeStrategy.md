# CompositeStrategy

Combine multiple strategies for complex control scenarios.

## Overview

CompositeStrategyは、複数の戦略を組み合わせて、より複雑で高度な排他制御を実現する戦略です。単一戦略では対応できない複雑な要件に対して、2つから5つまでの戦略を組み合わせることで、柔軟で強力な制御ロジックを構築できます。

この戦略は、複数の制御条件を同時に満たす必要がある高度なユースケースで使用されます。

## 組み合わせシステム

### 戦略の組み合わせ数

Lockmanは2つから5つまでの戦略組み合わせをサポートしています：

### 組み合わせ制御ロジック

**すべての戦略で成功が必要**:
- 全ての構成戦略でロック取得が可能な場合のみ成功
- 一つでも失敗すると全体が失敗

**先行キャンセルの協調**:
- いずれかの戦略で先行キャンセルが必要な場合、全体で先行キャンセルを実行
- 最初に見つかったキャンセルエラーを使用

**LIFO（後入れ先出し）解除**:
- ロック解除は取得の逆順で実行
- 最後に取得したロックから順に解除

## 使用方法

### 基本的な使用例

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self
)
enum Action {
    case criticalSave
    case normalSave
    
    var lockmanInfoForStrategy1: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
            actionId: actionName,
            mode: .action
        )
    }
    
    var lockmanInfoForStrategy2: LockmanPriorityBasedInfo {
        switch self {
        case .criticalSave:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        case .normalSave:
            return LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .low(.replaceable)
            )
        }
    }
}
```

### 3つの戦略組み合わせ

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self,
    LockmanConcurrencyLimitedStrategy.self
)
enum Action {
    case downloadFile
    
    var lockmanInfoForStrategy1: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
            actionId: actionName,
            mode: .action // 重複防止
        )
    }
    
    var lockmanInfoForStrategy2: LockmanPriorityBasedInfo {
        LockmanPriorityBasedInfo(
            actionId: actionName,
            priority: .low(.replaceable) // 優先度制御
        )
    }
    
    var lockmanInfoForStrategy3: LockmanConcurrencyLimitedInfo {
        LockmanConcurrencyLimitedInfo(
            actionId: actionName,
            concurrencyId: "downloads",
            limit: .limited(3) // 同時実行制限
        )
    }
}
```

## 動作例

### 2戦略組み合わせの動作

```
戦略1: SingleExecution(.action)
戦略2: PriorityBased(.high(.exclusive))

時刻: 0秒  - normalSave要求
  戦略1: ✅ 成功（重複なし）
  戦略2: ✅ 成功（優先度問題なし）
  結果: ✅ 実行開始

時刻: 1秒  - normalSave要求（重複）
  戦略1: ❌ 失敗（同じアクション実行中）
  戦略2: チェックなし（戦略1で失敗）
  結果: ❌ 全体失敗

時刻: 2秒  - criticalSave要求（高優先度）
  戦略1: ✅ 成功（異なるアクション）
  戦略2: ✅ 成功（先行キャンセル付き）
  結果: ✅ 実行開始（normalSaveをキャンセル）
```

### 3戦略組み合わせの動作

```
戦略1: SingleExecution(.action)
戦略2: PriorityBased(.low(.replaceable))  
戦略3: ConcurrencyLimited(.limited(2))

現在の状況: download処理が2つ実行中

時刻: 0秒  - 新しいdownload要求
  戦略1: ✅ 成功（異なるファイル）
  戦略2: ✅ 成功（優先度問題なし）
  戦略3: ❌ 失敗（同時実行制限到達）
  結果: ❌ 全体失敗
```

## エラーハンドリング

CompositeStrategyで発生する可能性のあるエラーと、その対処法については[Error Handling](<doc:ErrorHandling>)ページの共通パターンも参照してください。

### 複合戦略でのエラー処理

複合戦略では、各構成戦略からのエラーが統合されて報告されます。最初に失敗した戦略のエラーが返されるため、エラーの型を確認して適切に処理します：

```swift
lockFailure: { error, send in
    switch error {
    case let singleError as LockmanSingleExecutionError:
        send(.singleExecutionConflict("重複実行が検出されました"))
        
    case let priorityError as LockmanPriorityBasedError:
        send(.priorityConflict("優先度の競合が発生しました"))
        
    case let concurrencyError as LockmanConcurrencyLimitedError:
        send(.concurrencyLimitReached("同時実行制限に到達しました"))
        
    default:
        send(.unknownLockFailure("ロック取得に失敗しました"))
    }
}
```

## 設計指針

### 戦略選択の順序

1. **基本制御から開始**: SingleExecutionから始める
2. **優先度が必要なら追加**: PriorityBasedを組み合わせ
3. **リソース制御が必要なら追加**: ConcurrencyLimitedを組み合わせ
4. **協調制御が必要なら追加**: GroupCoordinationを組み合わせ
5. **カスタムロジックが必要なら追加**: DynamicConditionを組み合わせ

## ガイド

前のステップ <doc:DynamicConditionStrategy>
