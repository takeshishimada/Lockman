# Single Execution Strategy

最も基本的な戦略：一度に1つのアクションのみ実行を許可

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`SingleExecutionStrategy`は、同じアクションまたは境界内で一度に1つの処理のみ実行を許可する戦略です。二重送信の防止、データの整合性保持、UI操作の競合回避など、TCAアプリケーションで頻繁に必要となる制御を提供します。

## 実行モード

SingleExecutionStrategyは3つの実行モードをサポートしています：

### 1. .boundary モード

CancelID（境界）内で一度に1つのアクションのみ実行：

```swift
@LockmanSingleExecution
enum DataAction {
    case fetch
    case save
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(mode: .boundary)  // 境界単位で制御
    }
}

// CancelID.userActionの境界内で排他制御
return .withLock(
    operation: { send in
        try await fetchUserData()
    },
    action: DataAction.fetch,
    cancelID: CancelID.userAction
)

// 上記が完了するまで待機（同じ境界）
return .withLock(
    operation: { send in
        try await saveUserData()
    },
    action: DataAction.save,
    cancelID: CancelID.userAction
)
```

### 2. .action モード

同じactionIdを持つアクションのみブロック：

```swift
var lockmanInfo: LockmanSingleExecutionInfo {
    .init(mode: .action)  // アクション単位で制御
}

// fetchとsaveは並行実行可能（異なるactionId）
// 同じfetchの重複実行のみ防ぐ
```

### 3. .none モード

制御を無効化（テストやデバッグ用）：

```swift
var lockmanInfo: LockmanSingleExecutionInfo {
    .init(mode: .none)  // 制御なし
}
```

## TCAでの実装例

### 基本的な使用方法

```swift
@Reducer
struct CounterFeature {
    @ObservableState
    struct State {
        var count = 0
        var isIncrementing = false
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case incrementButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(
                    actionId: actionName,  // マクロが生成
                    mode: .boundary
                )
            }
        }
        
        enum InternalAction {
            case incrementCompleted(Int)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .incrementButtonTapped:
                    state.isIncrementing = true
                    
                    return .withLock(
                        operation: { send in
                            try await Task.sleep(for: .seconds(1))
                            let newCount = state.count + 1
                            await send(.internal(.incrementCompleted(newCount)))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case let .incrementCompleted(newCount):
                    state.count = newCount
                    state.isIncrementing = false
                    return .none
                }
            }
        }
    }
}
```

### @LockmanSingleExecutionマクロ

`@LockmanSingleExecution`マクロを使用することで、ボイラープレートコードを削減し、より簡潔にアクションを定義できます。

```swift
@LockmanSingleExecution
enum ViewAction {
    case fetchUserData
    case saveUserData
    
    // lockmanInfoは自分で実装する必要がある
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(
            actionId: actionName,  // マクロが生成する "fetchUserData" または "saveUserData"
            mode: .boundary
        )
    }
}
```

#### マクロが生成するもの

1. **`LockmanSingleExecutionAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

#### 動的な値の使用

enumの関連値を活用した動的なactionId：

```swift
@LockmanSingleExecution
enum DocumentAction {
    case edit(documentId: String)
    case delete(documentId: String)
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .edit(let documentId):
            return .init(
                actionId: "edit_\(documentId)",  // ドキュメントごとに別ID
                mode: .action
            )
        case .delete(let documentId):
            return .init(
                actionId: "delete_\(documentId)",
                mode: .boundary  // 削除は境界全体をロック
            )
        }
    }
}

// 使用例
return .withLock(
    action: DocumentAction.edit(documentId: "doc123"),
    cancelID: CancelID.userAction
)
```

## 実用的なシナリオ

### APIリクエストの重複防止

```swift
@LockmanSingleExecution
enum APIAction {
    case fetchUserList
    case fetchUserDetail(userId: String)
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .fetchUserList:
            // リスト取得は1つのみ
            return .init(mode: .action)
        case .fetchUserDetail(let userId):
            // ユーザーごとに別々に実行可能
            return .init(actionId: "fetchUser_\(userId)", mode: .action)
        }
    }
}

// 使用例
case .refreshButtonTapped:
    return .withLock(
        operation: { send in
            let users = try await apiClient.fetchUsers()
            await send(.usersLoaded(users))
        },
        action: APIAction.fetchUserList,
        cancelID: CancelID.userAction
    )
```

### 画面遷移の制御

```swift
@Reducer
struct NavigationFeature {
    @ObservableState
    struct State {
        var path = StackState<Path.State>()
        var isNavigating = false
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        case path(StackAction<Path.State, Path.Action>)
        
        @LockmanSingleExecution
        enum ViewAction {
            case itemTapped(Item)
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(mode: .boundary)
            }
        }
        
        enum InternalAction {
            case detailLoaded(DetailState)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case let .itemTapped(item):
                    guard !state.isNavigating else { return .none }
                    state.isNavigating = true
                    
                    return .withLock(
                        unlockOption: .transition(seconds: 0.3),
                        operation: { send in
                            let detail = try await loadDetail(item.id)
                            state.path.append(.detail(detail))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal:
                return .none
                
            case .path:
                return .none
            }
        }
    }
}
```

### データ保存の競合防止

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State {
        var profile: Profile
        var isSaving = false
        var lastSaveError: String?
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case saveButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(mode: .boundary)
            }
        }
        
        enum InternalAction {
            case saveCompleted
            case saveFailed(String)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .saveButtonTapped:
                    state.isSaving = true
                    state.lastSaveError = nil
                    
                    return .withLock(
                        operation: { [profile = state.profile] send in
                            try await profileAPI.save(profile)
                            await send(.internal(.saveCompleted))
                        },
                        catch: { error, send in
                            await send(.internal(.saveFailed(error.localizedDescription)))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case .saveCompleted:
                    state.isSaving = false
                    return .none
                    
                case let .saveFailed(error):
                    state.isSaving = false
                    state.lastSaveError = error
                    return .none
                }
            }
        }
    }
}
```

### フォーム送信の保護

```swift
@LockmanSingleExecution
enum FormAction {
    case submitRegistration
    case validateForm
    case clearForm
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        // boundaryモードでフォーム操作を排他制御
        .init(actionId: actionName, mode: .boundary)
    }
}

// 1画面1境界の原則
enum CancelID {
    case userAction
}

// フォーム送信中は同じ境界内の他の操作を防ぐ
case .submitButtonTapped:
    return .withLock(
        operation: { [formData = state.formData] send in
            try await registrationService.submit(formData)
            await send(.registrationCompleted)
        },
        action: FormAction.submitRegistration,
        cancelID: CancelID.userAction  // この境界内で排他制御
    )
```

## 高度な使用パターン

### 動的な境界

```swift
enum CancelID {
    case userAction
}

@LockmanSingleExecution
enum DocumentAction {
    case save(documentId: String)
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case let .save(id):
            return .init(
                actionId: "saveDocument_\(id)",
                mode: .boundary
            )
        }
    }
}

// 異なるドキュメントは並行保存可能
return .withLock(
    operation: { send in
        try await saveDocument(doc1)
    },
    action: DocumentAction.save(documentId: doc1.id),
    cancelID: CancelID.userAction
)
```

### ファイルアップロードの制御

```swift
// actionモードとboundaryモードの使い分け
@LockmanSingleExecution
enum UploadAction {
    case uploadDocument(documentId: String)
    case uploadImage(imageId: String)
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        switch self {
        case .uploadDocument(let id):
            // ドキュメントごとに別々にアップロード可能
            return .init(actionId: "upload_\(id)", mode: .action)
        case .uploadImage:
            // 画像は境界内で1つのみ
            return .init(mode: .boundary)
        }
    }
}

// 1画面1境界の原則
enum CancelID {
    case userAction
}

// 使用時
return .withLock(
    action: UploadAction.uploadDocument(documentId: "doc123"),
    cancelID: CancelID.userAction  // アップロードの境界
)
```

### 条件付き実行

```swift
case .refreshButtonTapped:
    // 既に実行中なら何もしない
    let lockResult = Lockman.container.canLock(
        action: RefreshAction.refresh,
        cancelID: CancelID.userAction
    )
    
    guard lockResult != .failure else {
        // 既に実行中
        return .send(.showRefreshInProgress)
    }
    
    return .withLock(
        operation: { send in
            try await refreshData()
        },
        action: RefreshAction.refresh,
        cancelID: CancelID.userAction
    )
```

## ベストプラクティス

### 1. 適切なモードの選択

- **`.none`**: 排他制御が不要な場合（ほとんど使われない）
- **`.boundary`**: 境界（cancelID）内で1つの操作に制限したい場合
- **`.action`**: 同じactionIdの重複のみを防ぐ場合

```swift
// ✅ 境界モード：関連する操作をまとめて制御
@LockmanSingleExecution
enum UserDataAction {
    case fetch, save, delete
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
    }
}

// ✅ アクションモード：個別に制御
@LockmanSingleExecution
enum IndependentAction {
    case uploadPhoto, uploadVideo
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(mode: .action)
    }
}
```

### 2. UnlockOptionの活用

```swift
// UI遷移を伴う場合
return .withLock(
    unlockOption: .transition(seconds: 0.3),
    operation: { send in
        await send(.navigate)
    },
    action: NavigationAction.push,
    cancelID: CancelID.userAction
)

// 即座に次の操作を許可
return .withLock(
    unlockOption: .immediate,
    operation: { send in
        await quickOperation()
    },
    action: QuickAction.execute,
    cancelID: CancelID.userAction
)
```

### 3. エラーハンドリング

```swift
return .withLock(
    operation: { send in
        do {
            try await riskyOperation()
            await send(.success)
        } catch {
            // 特定のエラーは内部で処理
            if error.isRetryable {
                try await Task.sleep(for: .seconds(1))
                try await riskyOperation()  // リトライ
                await send(.success)
            } else {
                throw error  // catchハンドラへ
            }
        }
    },
    catch: { error, send in
        await send(.failure(error))
    },
    action: RiskyAction.execute,
    cancelID: CancelID.userAction
)
```

### 4. UI フィードバック

```swift
case .saveButtonTapped:
    // 即座にUIを更新
    state.isSaving = true
    
    return .withLock(
        operation: { send in
            // 実際の処理
            await saveData()
            await send(.saveCompleted)
        },
        action: SaveAction.save,
        cancelID: CancelID.userAction
    )
```

## デバッグ

### ロック状態の確認

```swift
// すべてのロック状態を出力
Lockman.debug.printCurrentLocks()
// 出力例:
// ┌──────────────────┬────────────┬──────────────────────────────────────┬───────────────────┐
// │ Strategy         │ BoundaryId │ ActionId/UniqueId                    │ Additional Info   │
// ├──────────────────┼────────────┼──────────────────────────────────────┼───────────────────┤
// │ SingleExecution  │ mainScreen │ fetchData                            │ mode: .boundary   │
// │                  │            │ 123e4567-e89b-12d3-a456-426614174000 │                   │
// └──────────────────┴────────────┴──────────────────────────────────────┴───────────────────┘
```

### ログ出力

```swift
// ログ出力を有効化
Lockman.debug.isLoggingEnabled = true
// ログ出力例:
// ✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: mainScreen, Info: ...
```

## 完全な実装例

```swift
@Reducer
struct SingleExecutionExample {
    @ObservableState
    struct State {
        var count = 0
        var isProcessing = false
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case incrementTapped
            case decrementTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(mode: .boundary)
            }
        }
        
        enum InternalAction {
            case countUpdated(Int)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .incrementTapped:
                    state.isProcessing = true
                    return .withLock(
                        operation: { send in
                            try await Task.sleep(for: .seconds(2))
                            await send(.internal(.countUpdated(1)))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                    
                case .decrementTapped:
                    state.isProcessing = true
                    return .withLock(
                        operation: { send in
                            try await Task.sleep(for: .seconds(2))
                            await send(.internal(.countUpdated(-1)))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case let .countUpdated(delta):
                    state.count += delta
                    state.isProcessing = false
                    return .none
                }
            }
        }
    }
}
```

## よくある質問

### Q: 二重タップ防止にはどのモードを使うべき？

A: `.boundary`モードが推奨です。同じ画面内のすべてのアクションを制御できます。

### Q: ロックが解放されない場合は？

A: Effect.withLockは自動的にロックを解放します。手動制御が必要な場合は、手動アンロック形式を使用してください。

### Q: パフォーマンスへの影響は？

A: SingleExecutionStrategyはO(1)のハッシュ検索で動作し、オーバーヘッドは最小限です。

## 次のステップ

- <doc:PriorityBased> - 優先度ベースの制御
- <doc:UnlockOptions> - アンロックタイミングの詳細