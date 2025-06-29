# Unlock

Understanding the unlocking mechanism in Lockman.

## Overview

Lockmanにおけるアンロックは、取得したロックを適切に解除するメカニズムです。ロック取得後の処理完了時、エラー発生時、キャンセル時など、あらゆる状況において確実にリソースを解放し、システムの整合性を維持します。

## 仕様

### 自動解除

[withLock](<doc:Lock>)の自動解除版では、以下のタイミングで自動的にロックが解除されます：

- **正常終了時**: 処理が正常に完了した場合
- **例外発生時**: エラーが発生した場合
- **キャンセル時**: 処理がキャンセルされた場合
- **早期リターン時**: 処理が途中で終了した場合

自動解除はdeferブロックを使用して実装されており、どのような終了パターンでも確実にロックが解除されることが保証されています。

### 手動解除

[withLock](<doc:Lock>)の手動解除版では、開発者がunlock()関数を明示的に呼び出してロックを解除します。

**重要な制約:**
- 全てのコードパスでunlock()を呼び出す必要があります
- unlock()の呼び忘れは永続的なロック取得状態を引き起こします
- 条件分岐やエラーハンドリングにおいても適切な解除が必要です

**unlockオブジェクトの特徴:**
- Sendableプロトコルに準拠しているため、別のアクション呼び出し時に渡すことが可能
- 複数の画面やアクションでの利用を想定した設計
- アクション間でのロック状態の共有と協調的な解除が可能

### 解除オプション

アンロックの実行タイミングはLockmanUnlockOptionで制御できます：

- **immediate**: 処理完了と同時に即座に解除
- **mainRunLoop**: 次のメインランループサイクルで解除
- **transition**: プラットフォーム固有の画面遷移アニメーション完了後に解除
  - iOS: 0.35秒（プッシュ/ポップアニメーション）
  - macOS: 0.25秒（ウィンドウとビューのアニメーション）
  - tvOS: 0.4秒（フォーカス駆動の遷移）
  - watchOS: 0.3秒（ページベースのナビゲーション）
- **delayed(TimeInterval)**: 指定した時間後に解除

## メソッド

### 自動解除の使用例

```swift
.withLock(
  operation: { send in
    // 処理実行
    try await someAsyncWork()
    send(.completed)
    // ここで自動的にロック解除
  },
  catch: { error, send in
    // エラー処理後に自動解除
    send(.failed(error))
  },
  action: action,
  cancelID: cancelID
)
```

### 手動解除の使用例

基本的な使用例:

```swift
.withLock(
  operation: { send, unlock in
    try await firstOperation()
    
    if shouldEarlyReturn {
      unlock() // 早期解除
      return
    }
    
    try await secondOperation()
    unlock() // 必須: 最終解除
  },
  catch: { error, send, unlock in
    // エラー処理
    unlock() // エラー時も解除
    send(.failed(error))
  },
  action: action,
  cancelID: cancelID
)
```

別画面のdelegateでの解除例:

```swift
.withLock(
  operation: { send, unlock in
    // 別画面にunlockオブジェクトを渡して画面遷移
    send(.delegate(unlock: unlock))
  },
  action: action,
  cancelID: cancelID
)

// Delegate側で受け取って解除
case .modal(.delegate(let unlock)):
  return .run { send in
    // モーダル処理完了後に解除
    unlock()
  }
```

## ガイド

次のステップ <doc:ChoosingStrategy>

前のステップ <doc:Lock>
