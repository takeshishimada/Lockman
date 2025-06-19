# Effect.withLock

LockmanのメインAPIであるEffect.withLockの詳細解説

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`Effect.withLock`は、TCAのEffectに排他制御機能を追加する拡張メソッドです。非同期処理の競合を防ぎ、リソースの一貫性を保ちながら、エラーハンドリングやキャンセレーションも適切に処理します。

## API概要

### 基本形（自動アンロック）

```swift
static func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority? = nil,
    unlockOption: UnlockOption? = nil,
    operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
    catch handler: (@Sendable (_ error: any Error, _ send: Send<Action>) async -> Void)? = nil,
    action: A,
    cancelID: B,
    fileID: StaticString = #fileID,
    filePath: StaticString = #filePath,
    line: UInt = #line,
    column: UInt = #column
) -> Self
```

### 手動アンロック形

```swift
static func withLock<B: LockmanBoundaryId, A: LockmanAction>(
    priority: TaskPriority? = nil,
    unlockOption: UnlockOption? = nil,
    operation: @escaping @Sendable (
        _ send: Send<Action>, 
        _ unlock: LockmanUnlock<B, A.I>
    ) async throws -> Void,
    catch handler: /* ... */,
    action: A,
    cancelID: B,
    /* source location parameters */
) -> Self
```

### 連結実行形

```swift
static func concatenateWithLock<B: LockmanBoundaryId, A: LockmanAction>(
    unlockOption: UnlockOption? = nil,
    operations: [Effect<Action>],
    action: A,
    cancelID: B,
    /* source location parameters */
) -> Effect<Action>
```

## パラメータ詳細

### priority: TaskPriority?

Taskの優先度を指定します。TCAの標準的な`.run`と同じです。

```swift
return .withLock(
    priority: .high,  // 高優先度で実行
    operation: { send in
        // 重要な処理
    },
    action: myAction,
    cancelID: CancelID.userAction
)
```

### unlockOption: UnlockOption?

ロック解放のタイミングを制御します：

```swift
public enum UnlockOption: Sendable, Equatable {
    /// 即座にロックを解放
    case immediate
    
    /// メインランループで次のサイクルに解放
    case mainRunLoop
    
    /// アニメーションなどの遷移時間を考慮して解放
    case transition
    
    /// 指定秒数後に解放
    case delayed(seconds: Double)
}
```

使用例：

```swift
return .withLock(
    unlockOption: .transition(seconds: 0.3),  // アニメーション完了後に解放
    operation: { send in
        await send(.startAnimation)
    },
    action: animationAction,
    cancelID: CancelID.userAction
)
```

### operation: 非同期クロージャ

実際の処理を記述します。`send`関数を使ってアクションを送信：

```swift
return .withLock(
    operation: { send in
        // 非同期処理
        let data = try await api.fetchData()
        
        // アクション送信
        await send(.dataReceived(data))
        
        // エラーは自動的にcatchハンドラに渡される
    },
    action: fetchAction,
    cancelID: CancelID.userAction
)
```

### catch handler: エラーハンドラ

エラー処理をカスタマイズ：

```swift
return .withLock(
    operation: { send in
        try await riskyOperation()
    },
    catch: { error, send in
        // エラーログ
        logger.error("Operation failed: \(error)")
        
        // エラーアクション送信
        await send(.operationFailed(error.localizedDescription))
    },
    action: riskyAction,
    cancelID: CancelID.userAction
)
```

### action: LockmanAction

使用する戦略とロック情報を提供：

```swift
// マクロを使った定義
@LockmanSingleExecution
enum DataAction {
    case save
    case load
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
    }
}

// 使用
return .withLock(
    operation: { send in /* ... */ },
    action: DataAction.save,
    cancelID: CancelID.userAction
)
```

### cancelID: LockmanBoundaryId

TCAのCancelIDが境界として機能します：

```swift
enum CancelID {
    case userAction
}
```

## 実践例

### 1. 自動アンロック制御

```swift
@Reducer
struct ProfileFeature {
    enum CancelID {
        case userAction
    }
    
    @LockmanSingleExecution
    enum ProfileAction {
        case save
        
        var lockmanInfo: LockmanSingleExecutionInfo {
            .init(actionId: actionName, mode: .boundary)
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .saveButtonTapped:
                return .withLock(
                    operation: { send in
                        try await profileAPI.save(state.profile)
                        await send(.saveCompleted)
                    },
                    catch: { error, send in
                        await send(.saveFailed(error))
                    },
                    action: ProfileAction.save,
                    cancelID: CancelID.userAction
                )
            }
        }
    }
}
```

### 2. 手動アンロック制御

```swift
case .startLongOperation:
    return .withLock(
        operation: { send, unlock in
            // Phase 1: 準備
            await send(.phaseStarted(1))
            try await prepareResources()
            
            // Phase 2: メイン処理
            await send(.phaseStarted(2))
            try await performMainOperation()
            
            // ここで手動アンロック（Phase 3の前）
            await unlock()
            
            // Phase 3: 後処理（ロックなし）
            await send(.phaseStarted(3))
            await cleanupResources()
        },
        action: LongOperationAction(),
        cancelID: CancelID.userAction
    )
```

### 3. 複数のEffectを連結

```swift
case .complexOperationStarted:
    return .concatenateWithLock(
        operations: [
            .run { send in
                await send(.step1Started)
                try await performStep1()
            },
            .run { send in
                await send(.step2Started)
                try await performStep2()
            },
            .run { send in
                await send(.step3Started)
                try await performStep3()
            }
        ],
        action: ComplexOperationAction(),
        cancelID: CancelID.complexOperation
    )
```

## エラーハンドリング

### キャンセレーション

```swift
return .withLock(
    operation: { send in
        for item in items {
            try Task.checkCancellation()  // 定期的にチェック
            try await processItem(item)
        }
    },
    catch: { error, send in
        if error is CancellationError {
            await send(.operationCancelled)
        } else {
            await send(.operationFailed(error))
        }
    },
    action: batchAction,
    cancelID: CancelID.batchProcess
)
```

### 戦略エラー

ロックが取得できない場合、`.none`が返されます：

```swift
// SingleExecutionStrategyで既に実行中の場合
let effect = Effect.withLock(
    operation: { send in /* ... */ },
    action: SingleExecutionAction(),
    cancelID: CancelID.single
)
// effect == .none (実行されない)
```

## ベストプラクティス

### エラーハンドリング

```swift
return .withLock(
    operation: { send in
        do {
            try await riskyOperation()
        } catch NetworkError.noConnection {
            // 特定のエラーは内部で処理
            await send(.goOfflineMode)
        }
        // その他のエラーはcatchハンドラへ
    },
    catch: { error, send in
        // 汎用エラーハンドリング
        logger.error("Unexpected error: \(error)")
        await send(.showError(error.localizedDescription))
    },
    action: networkAction,
    cancelID: CancelID.network
)
```

## 次のステップ

- <doc:UnlockOptions> - UnlockOptionの詳細な使い方
- <doc:SingleExecution> - 組み込み戦略の使用例
