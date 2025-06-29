# Configuration

Configure Lockman for your application's needs.

## Overview

LockmanManagerは、アプリケーション全体で使用されるLockmanの動作を設定するための設定機能を提供します。これらの設定により、デフォルトのロック解除タイミングやエラーハンドリングの動作をカスタマイズできます。

設定は一度行えばアプリケーション全体に適用され、個別の[`withLock`](<doc:Lock>)呼び出し時にオーバーライドすることも可能です。

## 設定項目

### defaultUnlockOption

ロック解除のデフォルトタイミングを設定します。

```swift
// アプリケーション初期化時に設定
LockmanManager.config.defaultUnlockOption = .immediate
```

**設定可能な値**:
- **`.immediate`**: 処理完了と同時に即座に解除（デフォルト）
- **`.mainRunLoop`**: メインループの次のサイクルで解除
- **`.transition`**: プラットフォーム固有の画面遷移アニメーション完了後に解除
- **`.delayed(TimeInterval)`**: 指定した時間間隔後に解除

**用途**:
- UI遷移を考慮した解除タイミングの統一
- アプリケーション全体での一貫した動作設定
- パフォーマンス最適化のための調整

### handleCancellationErrors

キャンセルエラーの処理方法を設定します。

```swift
// キャンセルエラーを無視する（デフォルト）
LockmanManager.config.handleCancellationErrors = false

// キャンセルエラーもエラーハンドラに渡す
LockmanManager.config.handleCancellationErrors = true
```

**設定値**:
- **`false`**: キャンセルエラーを無視し、エラーハンドラに渡さない（デフォルト）
- **`true`**: キャンセルエラーもエラーハンドラに渡す

**用途**:
- キャンセル処理のログ記録
- デバッグ時のキャンセル状況の追跡
- 統計情報の収集

## 設定例

### アプリケーション初期化時の設定

```swift
// AppDelegateまたはApp構造体で設定
func applicationDidFinishLaunching() {
    // UI遷移を考慮した解除タイミングに設定
    LockmanManager.config.defaultUnlockOption = .transition
    
    // 開発時はキャンセルエラーもログに記録
    #if DEBUG
    LockmanManager.config.handleCancellationErrors = true
    #endif
}
```

### 個別オーバーライド

```swift
// グローバル設定を個別にオーバーライド
.withLock(
    unlockOption: .immediate, // グローバル設定をオーバーライド
    operation: { send in
        // 即座に解除が必要な処理
    },
    action: action,
    cancelID: cancelID
)
```

## 注意事項

- 設定変更はアプリケーション全体に影響するため、初期化時に行うことを推奨
- 実行時の設定変更は可能ですが、予期しない動作を避けるため慎重に行ってください
- テスト時は設定をリセットして、テスト間の影響を避けることを推奨

## ガイド

次のステップ [Debugging](<doc:DebuggingGuide>)

前のステップ <doc:ChoosingStrategy>
