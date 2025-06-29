# SingleExecutionStrategy

Prevent duplicate execution of the same action.

## Overview

SingleExecutionStrategyは、重複実行を防止するための戦略です。同じ処理が重複して実行されることを防ぎ、データの整合性とアプリケーションの安定性を保ちます。

この戦略は、ユーザーの連続的な操作や自動処理の重複実行を防ぐために最も頻繁に使用される基本的な戦略です。

## 実行モード

SingleExecutionStrategyは3つの実行モードをサポートしています：

### none - 制御なし

```swift
LockmanSingleExecutionInfo(
    actionId: "save",
    mode: .none
)
```

- 排他制御を行わず、全ての処理を同時実行
- 一時的にロック機能を無効化したい場合に使用
- デバッグやテスト時の動作確認に適用

### boundary - 境界単位の排他制御

```swift
LockmanSingleExecutionInfo(
    actionId: "save", 
    mode: .boundary
)
```

- 同一境界内で1つの処理のみ実行可能
- 画面やコンポーネント単位での排他制御
- UIの操作全体を制御したい場合に適用

### action - アクション単位の排他制御

```swift
LockmanSingleExecutionInfo(
    actionId: "save",
    mode: .action  
)
```

- 同一アクションの重複実行のみ防止
- 異なるアクションは同時実行可能
- 特定の処理のみを制御したい場合に適用

## 使用方法

### 基本的な使用例

```swift
@LockmanSingleExecution
enum Action {
    case save
    case load
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .save:
            return LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action
            )
        case .load:
            return LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .action
            )
        }
    }
}
```

### Effect内での使用

```swift
case .saveButtonTapped:
    return .withLock(
        operation: { send in
            try await saveUserData()
            send(.saveCompleted)
        },
        catch handler: { error, send in
            send(.saveError(error.localizedDescription))
        },
        lockFailure: { error, send in
            send(.saveBusy("保存処理が実行中です"))
        },
        action: .save,
        cancelID: CancelID.userAction
    )
```

## 動作例

### action モードの場合

```
時刻: 0秒  - saveアクション開始 → ✅ 実行
時刻: 1秒  - saveアクション要求 → ❌ 拒否（同じアクション実行中）
時刻: 1秒  - loadアクション要求 → ✅ 実行（異なるアクション）
時刻: 3秒  - saveアクション完了 → 🔓 ロック解除
時刻: 4秒  - saveアクション要求 → ✅ 実行（前回処理完了済み）
```

### boundary モードの場合

```
時刻: 0秒  - saveアクション開始 → ✅ 実行
時刻: 1秒  - saveアクション要求 → ❌ 拒否（境界内で実行中）
時刻: 1秒  - loadアクション要求 → ❌ 拒否（境界内で実行中）
時刻: 3秒  - saveアクション完了 → 🔓 ロック解除
時刻: 4秒  - loadアクション要求 → ✅ 実行（境界内の処理完了済み）
```

## エラーハンドリング

SingleExecutionStrategyで発生する可能性のあるエラーと、その対処法については[Error Handling](<doc:ErrorHandling>)ページの共通パターンも参照してください。

### LockmanSingleExecutionError

**boundaryAlreadyLocked** - 境界が既にロックされている
- `boundaryId`: ロックされている境界のID
- `existingInfo`: 既存のロック情報

**actionAlreadyRunning** - 同じアクションが既に実行中  
- `existingInfo`: 実行中のアクション情報

```swift
lockFailure: { error, send in
    switch error as? LockmanSingleExecutionError {
    case .boundaryAlreadyLocked(_, let existingInfo):
        send(.showBusyMessage("他の処理が実行中です: \(existingInfo.actionId)"))
    case .actionAlreadyRunning(let existingInfo):
        send(.showBusyMessage("\(existingInfo.actionId)が実行中です"))
    default:
        send(.showBusyMessage("処理を開始できません"))
    }
}
```

