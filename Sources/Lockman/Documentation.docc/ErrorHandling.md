# Error Handling

Learn about common error handling patterns in Lockman.

## Overview

Lockmanでは、各戦略に応じた詳細なエラー情報を提供します。このページでは、すべての戦略に共通するエラーハンドリングパターンと、効果的なエラー処理の実装方法について説明します。

## 共通エラーハンドリングパターン

### lockFailureハンドラー

すべての戦略で使用される基本的なlockFailureハンドラーの構造：

```swift
.withLock(
    operation: { send in
        // 処理実行
    },
    lockFailure: { error, send in
        // エラーハンドリング
        if case .specificError(let info) = error as? StrategySpecificError {
            send(.userFriendlyMessage("エラーメッセージ"))
        }
    },
    action: action,
    cancelID: cancelID
)
```

**パラメータ:**
- `error`: 発生したエラー（戦略固有のエラー型）
- `send`: ユーザーへのフィードバック送信用の関数

### catch handlerパターン

処理中に発生した一般的なエラーを処理する場合：

```swift
catch handler: { error, send in
    send(.operationError(error.localizedDescription))
}
```

このハンドラーは、operation内でスローされたエラーをキャッチし、適切にユーザーに通知します。

## エラーの種類と対処法

### 1. ロック取得失敗（Already Locked）

**概念**: 同じ処理や境界が既に実行中の場合に発生

**共通の対処法**:
```swift
lockFailure: { error, send in
    // ユーザーに処理中であることを通知
    send(.showMessage("処理が実行中です"))
    
    // または、UIで視覚的にフィードバック
    send(.setButtonState(.loading))
}
```

### 2. 権限・優先度の競合（Permission/Priority Conflicts）

**概念**: より高い優先度の処理や、グループルールによる制約で発生

**共通の対処法**:
```swift
lockFailure: { error, send in
    // 詳細情報を含むエラーから状況を把握
    if let conflictInfo = extractConflictInfo(from: error) {
        send(.showMessage("他の重要な処理を実行中です: \(conflictInfo.description)"))
    }
}
```

### 3. キャンセル通知（Cancellation）

**概念**: 高優先度の処理によって既存処理がキャンセルされた場合

**共通の対処法**:
```swift
catch handler: { error, send in
    if error is CancellationError {
        send(.processCancelled("より重要な処理により中断されました"))
    } else {
        send(.processError(error.localizedDescription))
    }
}
```

## ベストプラクティス

### 1. エラー型の適切なキャスト

```swift
// ✅ 良い例：戦略固有のエラー型にキャスト
if case .actionAlreadyRunning(let existingInfo) = error as? LockmanSingleExecutionError {
    // existingInfoを使用して詳細な情報を提供
}

// ❌ 悪い例：エラーを文字列として扱う
send(.showError(error.localizedDescription))
```

### 2. ユーザーフレンドリーなメッセージ

```swift
// ✅ 良い例：具体的で理解しやすいメッセージ
send(.showMessage("データの保存中です。しばらくお待ちください。"))

// ❌ 悪い例：技術的なエラーメッセージ
send(.showMessage("LockmanError: boundary locked"))
```

### 3. 追加情報の活用

多くのエラーは追加情報を含んでいます：

```swift
lockFailure: { error, send in
    switch error as? LockmanConcurrencyLimitedError {
    case .concurrencyLimitReached(let current, let limit, _):
        send(.showMessage("同時実行数が上限(\(limit))に達しています（現在: \(current)）"))
    default:
        send(.showMessage("処理を開始できません"))
    }
}
```

## 戦略固有のエラー

各戦略の詳細なエラー情報については、それぞれのドキュメントを参照してください：

- [SingleExecutionStrategy](<doc:SingleExecutionStrategy>) - 重複実行エラー
- [PriorityBasedStrategy](<doc:PriorityBasedStrategy>) - 優先度競合エラー
- [GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>) - グループルール違反エラー
- [ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>) - 同時実行数超過エラー
- [DynamicConditionStrategy](<doc:DynamicConditionStrategy>) - 条件不一致エラー
- [CompositeStrategy](<doc:CompositeStrategy>) - 複合戦略エラー

## ガイド

次のステップ [Debugging](<doc:DebuggingGuide>)

前のステップ <doc:Configuration>