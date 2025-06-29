# Lock

Understanding the locking mechanism in Lockman.

## Overview

Lockmanにおけるロックは、戦略ベースの排他制御システムです。従来の単純なON/OFF制御とは異なり、選択した戦略によって以下のような多様な制御が可能になります。

- **実行の防止**: 重複実行の阻止（[SingleExecutionStrategy](<doc:SingleExecutionStrategy>)）
- **実行の優先**: 既存処理を中断した新しい処理の優先実行（[PriorityBasedStrategy](<doc:PriorityBasedStrategy>)）
- **実行の協調**: 関連する処理グループの協調的な調整（[GroupCoordinationStrategy](<doc:GroupCoordinationStrategy>)）
- **実行の制限**: 同時実行数の制限（[ConcurrencyLimitedStrategy](<doc:ConcurrencyLimitedStrategy>)）
- **実行の条件付き制御**: カスタムロジックによる動的な条件制御（[DynamicConditionStrategy](<doc:DynamicConditionStrategy>)）

## 仕様

Lockmanは戦略に基づいてロック取得の成否を判定し、その結果に応じて処理を実行します。ロック取得の判定プロセスは、指定された戦略のルールに従って行われ、[CompositeStrategy](<doc:CompositeStrategy>)で複数戦略が指定されている場合は、すべての戦略でロック取得が可能である場合のみ成功となります。

## メソッド

Lockmanは3つの主要なメソッドを提供し、用途に応じて使い分けることができます。

### withLock（自動解除版）

最も基本的で推奨される使用方法です。ロックの取得と解除を自動で管理します。

```swift
.withLock(
  priority: .userInitiated, // オプション: タスク優先度
  unlockOption: .immediate, // オプション: ロック解除タイミング
  operation: { send in /* 処理 */ },
  catch handler: { error, send in /* エラー処理 */ }, // オプション
  lockFailure: { error, send in /* ロック取得失敗処理 */ }, // オプション
  action: action,
  cancelID: cancelID
)
```

**パラメータ:**
- `priority`: タスクの優先度（オプション）
- `unlockOption`: ロック解除のタイミング（オプション、デフォルトは設定値）
- `handleCancellationErrors`: キャンセルエラーの扱い（オプション、デフォルトは設定値）
- `operation`: 排他制御下で実行する処理
- `catch handler`: エラーハンドラー（オプション）
- `lockFailure`: ロック取得失敗時のハンドラー（オプション）
- `action`: 現在のアクション
- `cancelID`: Effectのキャンセル識別子

**特徴:**
- 自動的なロック管理
- 処理の正常終了、例外発生、キャンセル時も確実にロック解除
- エラーハンドリング機能

### withLock（手動解除版）

ロックの解除タイミングを手動で制御したい場合に使用します。

```swift
.withLock(
  priority: .userInitiated, // オプション: タスク優先度
  unlockOption: .immediate, // オプション: ロック解除タイミング
  operation: { send, unlock in 
    /* 処理 */
    unlock() // 手動解除
  },
  catch handler: { error, send, unlock in /* エラー処理 */ }, // オプション
  lockFailure: { error, send in /* ロック取得失敗処理 */ }, // オプション
  action: action,
  cancelID: cancelID
)
```

**特徴:**
- 明示的なロック解除制御
- より細かい制御が可能
- **重要**: 必ず全てのコードパスでunlock()を呼び出す必要があります（詳細は[Unlock](<doc:Unlock>)ページを参照）

### concatenateWithLock

複数のEffectを順次実行する間、同一のロックを保持し続けます。

```swift
.concatenateWithLock(
  unlockOption: .immediate, // オプション: ロック解除タイミング
  operations: [
    .run { send in /* 処理1 */ },
    .run { send in /* 処理2 */ },
    .run { send in /* 処理3 */ }
  ],
  lockFailure: { error, send in /* ロック取得失敗処理 */ }, // オプション
  action: action,
  cancelID: cancelID
)
```

**特徴:**
- 複数のEffect間で同じロックを維持
- トランザクション的な処理に適している
- 一つでも失敗すると全体が中断される

## ガイド

次のステップ <doc:Unlock>

前のステップ <doc:BoundaryOverview>
