# Priority Based Strategy

優先度に基づいてアクションの実行を制御する高度な戦略

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`PriorityBasedStrategy`は、アクションに優先度を設定し、高優先度のアクションが低優先度のアクションを置き換えたり、実行をブロックしたりできる戦略です。リアルタイム検索、ユーザー操作とバックグラウンド処理の調整など、TCAアプリケーションでよく必要となる制御を提供します。

## 優先度システム

### 優先度レベル

```swift
public enum Priority {
    case none                           // 優先度制御なし
    case high(ConcurrencyBehavior)     // 高優先度
    case low(ConcurrencyBehavior)      // 低優先度
}

public enum ConcurrencyBehavior {
    case exclusive      // 排他的実行（新しいアクションをブロック）
    case replaceable    // 置換可能（新しいアクションが古いものを置き換え）
}
```

### 動作原理

1. **高優先度 > 低優先度**: 高優先度アクションは常に低優先度より優先
2. **同じ優先度**: ConcurrencyBehaviorで動作を決定
3. **none**: 優先度による制御を行わない

## @LockmanPriorityBasedマクロ

`@LockmanPriorityBased`マクロを使用して、優先度ベースのアクションを簡潔に定義できます。

```swift
@LockmanPriorityBased
enum SearchAction {
    case searchUsers(query: String)
    case searchPosts(query: String)
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,  // マクロが生成
            priority: .high(.replaceable),
            blocksSameAction: false
        )
    }
}
```

### マクロが生成するもの

1. **`LockmanPriorityBasedAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

### 動的な優先度設定

enumの関連値を使った柔軟な優先度制御：

```swift
@LockmanPriorityBased
enum DataAction {
    case fetch(isUrgent: Bool = false)
    case update(data: Data, isHighPriority: Bool = true)
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .fetch(let isUrgent):
            return .init(
                actionId: "fetchData",
                priority: isUrgent ? .high(.replaceable) : .low(.replaceable),
                blocksSameAction: false
            )
        case .update(_, let isHighPriority):
            return .init(
                actionId: "updateData",
                priority: isHighPriority ? .high(.exclusive) : .low(.exclusive),
                blocksSameAction: true
            )
        }
    }
}

// 使用例
return .withLock(
    action: DataAction.fetch(isUrgent: true),  // 緊急フェッチ
    cancelID: CancelID.userAction
)
```

## TCAでの実装例

### リアルタイム検索

最も一般的な使用例 - 新しい検索が古い検索を自動的にキャンセル：

```swift
@Reducer
struct SearchFeature {
    @ObservableState
    struct State {
        var searchText = ""
        var results: IdentifiedArrayOf<SearchResult> = []
        var isSearching = false
        var suggestions: [String] = []
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanPriorityBased
        enum ViewAction {
            case searchTextChanged(String)
            case suggestionTapped(String)
            
            var lockmanInfo: LockmanPriorityBasedInfo {
                switch self {
                case .searchTextChanged:
                    return .init(
                        actionId: actionName,
                        priority: .low(.replaceable)
                    )
                case .suggestionTapped:
                    return .init(
                        actionId: actionName,
                        priority: .high(.exclusive)
                    )
                }
            }
        }
        
        enum InternalAction {
            case searchResponse(TaskResult<[SearchResult]>)
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
                case let .searchTextChanged(text):
                    state.searchText = text
                    state.isSearching = true
                    
                    return .withLock(
                        operation: { send in
                            try await Task.sleep(for: .milliseconds(300))
                            
                            guard !text.isEmpty else {
                                await send(.internal(.searchResponse(.success([]))))
                                return
                            }
                            
                            await send(
                                .internal(.searchResponse(
                                    await TaskResult {
                                        try await searchAPI.search(text)
                                    }
                                ))
                            )
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                    
                case let .suggestionTapped(suggestion):
                    state.searchText = suggestion
                    
                    return .withLock(
                        operation: { send in
                            let results = try await searchAPI.search(suggestion)
                            await send(.internal(.searchResponse(.success(results))))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case let .searchResponse(.success(results)):
                    state.results = IdentifiedArray(uniqueElements: results)
                    state.isSearching = false
                    return .none
                    
                case let .searchResponse(.failure(error)):
                    state.isSearching = false
                    return .none
                }
            }
        }
    }
}
```

### バックグラウンド同期 vs ユーザー操作

```swift
@Reducer
struct SyncFeature {
    @ObservableState
    struct State {
        var items: [Item] = []
        var lastSync: Date?
        var isSyncing = false
        var syncSource: SyncSource?
        
        enum SyncSource {
            case automatic
            case userTriggered
        }
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        enum ViewAction {
            case startAutoSync
            case syncButtonTapped
        }
        
        enum InternalAction {
            case syncCompleted([Item])
            case syncFailed(Error)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    struct AutoSyncAction: LockmanPriorityBasedAction {
        let actionName = "autoSync"
        
        var lockmanInfo: LockmanPriorityBasedInfo {
            .init(
                actionId: actionName,
                priority: .low(.replaceable)
            )
        }
    }
    
    struct UserSyncAction: LockmanPriorityBasedAction {
        let actionName = "userSync"
        
        var lockmanInfo: LockmanPriorityBasedInfo {
            .init(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.startAutoSync):
                guard state.syncSource == nil else { return .none }
                
                state.syncSource = .automatic
                
                // 低優先度の自動同期
                return .withLock(
                    operation: { send in
                        // 定期的にキャンセルをチェック
                        for page in 1...10 {
                            try Task.checkCancellation()
                            
                            let items = try await syncAPI.fetchPage(page)
                            if page == 10 {
                                await send(.internal(.syncCompleted(items)))
                            }
                            
                            // ページ間で少し待機
                            try await Task.sleep(for: .seconds(1))
                        }
                    },
                    catch: { error, send in
                        if error is CancellationError {
                            // ユーザー同期によってキャンセルされた
                            print("Auto sync cancelled by user sync")
                        } else {
                            await send(.internal(.syncFailed(error)))
                        }
                    },
                    action: AutoSyncAction(),
                    cancelID: CancelID.userAction
                )
                
            case .view(.syncButtonTapped):
                state.isSyncing = true
                state.syncSource = .userTriggered
                
                // 高優先度のユーザー同期（自動同期をキャンセル）
                return .withLock(
                    operation: { send in
                        let items = try await syncAPI.fullSync()
                        await send(.internal(.syncCompleted(items)))
                    },
                    catch: { error, send in
                        await send(.internal(.syncFailed(error)))
                    },
                    action: UserSyncAction(),
                    cancelID: CancelID.userAction
                )
                
            case let .internal(.syncCompleted(items)):
                state.items = items
                state.lastSync = Date()
                state.isSyncing = false
                state.syncSource = nil
                return .none
                
            case .internal(.syncFailed):
                state.isSyncing = false
                state.syncSource = nil
                return .none
            }
        }
    }
}
```

### メディア処理の優先度制御

```swift
@Reducer
struct MediaUploadFeature {
    @ObservableState
    struct State {
        var uploadQueue: IdentifiedArrayOf<MediaUpload> = []
        var activeUploads: Set<MediaUpload.ID> = []
        
        struct MediaUpload: Identifiable {
            let id = UUID()
            let url: URL
            let type: MediaType
            let size: Int64
            var progress: Double = 0
            
            enum MediaType {
                case photo
                case video
                case document
            }
        }
    }
    
    enum Action {
        case addMedia(URL, State.MediaUpload.MediaType)
        case uploadProgress(State.MediaUpload.ID, Double)
        case uploadCompleted(State.MediaUpload.ID)
        case uploadFailed(State.MediaUpload.ID, Error)
        case prioritizeUpload(State.MediaUpload.ID)
    }
    
    enum CancelID {
        case userAction
    }
    
    // 動的な優先度を持つアップロードアクション
    struct UploadAction: LockmanPriorityBasedAction {
        let media: State.MediaUpload
        
        var actionName: String {
            "upload_\(media.id)"
        }
        
        var lockmanInfo: LockmanPriorityBasedInfo {
            let priority: LockmanPriorityBasedInfo.Priority
            
            switch media.type {
            case .photo:
                // 写真は中優先度、置換可能
                priority = media.size < 5_000_000 
                    ? .high(.replaceable)
                    : .low(.replaceable)
                    
            case .video:
                // ビデオは常に低優先度
                priority = .low(.exclusive)
                
            case .document:
                // ドキュメントは高優先度
                priority = .high(.exclusive)
            }
            
            return .init(
                actionId: actionName,
                priority: priority,
                blocksSameAction: true
            )
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .addMedia(url, type):
                let media = State.MediaUpload(
                    url: url,
                    type: type,
                    size: getFileSize(url)
                )
                state.uploadQueue.append(media)
                state.activeUploads.insert(media.id)
                
                return .withLock(
                    operation: { send in
                        await uploadService.upload(media.url) { progress in
                            await send(.uploadProgress(media.id, progress))
                        }
                        await send(.uploadCompleted(media.id))
                    },
                    catch: { error, send in
                        await send(.uploadFailed(media.id, error))
                    },
                    action: UploadAction(media: media),
                    cancelID: CancelID.userAction
                )
                
            case let .uploadProgress(id, progress):
                state.uploadQueue[id: id]?.progress = progress
                return .none
                
            case let .uploadCompleted(id):
                state.uploadQueue.remove(id: id)
                state.activeUploads.remove(id)
                return .none
                
            case let .uploadFailed(id, _):
                state.activeUploads.remove(id)
                return .none
                
            case let .prioritizeUpload(id):
                guard let media = state.uploadQueue[id: id] else { return .none }
                
                // 優先度を一時的に高める
                let prioritizedMedia = State.MediaUpload(
                    url: media.url,
                    type: .document,  // 最高優先度として扱う
                    size: media.size
                )
                
                return .concatenate(
                    // 既存のアップロードをキャンセル
                    .cancel(id: CancelID.userAction),
                    
                    // 高優先度で再開始
                    .withLock(
                        operation: { send in
                            await uploadService.upload(media.url) { progress in
                                await send(.uploadProgress(id, progress))
                            }
                            await send(.uploadCompleted(id))
                        },
                        action: UploadAction(media: prioritizedMedia),
                        cancelID: CancelID.userAction
                    )
                )
            }
        }
    }
}
```

## 高度な機能

### blocksSameAction

同じactionIdの実行をブロック：

```swift
struct CriticalSaveAction: LockmanPriorityBasedAction {
    let actionName = "criticalSave"
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .high(.exclusive),
            blocksSameAction: true  // 同じ保存操作は1つのみ
        )
    }
}
```

### プリオリティベースのキャンセレーション

高優先度タスクによる低優先度タスクの自動キャンセル：

```swift
struct PreemptibleAction: LockmanPriorityBasedAction {
    let actionName = "backgroundTask"
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .low(.replaceable),
            blocksSameAction: false
        )
    }
}

// 使用例
return .withLock(
    operation: { send in
        for item in largeDataset {
            try Task.checkCancellation()  // 定期的にチェック
            await processItem(item)
        }
    },
    action: PreemptibleAction(),
    cancelID: CancelID.userAction
)
```

## 実用的なシナリオ

### プロフィール画像選択の例

```swift
// CancelIDで境界を定義
enum CancelID {
    case userAction
}

// カメラ撮影 - 高優先度
@LockmanPriorityBased
enum ImagePickerAction {
    case pickFromCamera
    case pickFromGallery
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .pickFromCamera:
            return .init(
                actionId: actionName,
                priority: .high(.exclusive),
                blocksSameAction: false  // カメラは複数起動を許可
            )
        case .pickFromGallery:
            return .init(
                actionId: actionName,
                priority: .low(.replaceable)  // カメラ起動で中断可能
            )
        }
    }
}
```

### データ同期の優先度管理

```swift
// バックグラウンド同期 - 低優先度
struct BackgroundSyncAction: LockmanPriorityBasedAction {
    let actionName = "backgroundSync"
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .low(.replaceable),
            blocksSameAction: false
        )
    }
}

// ユーザー起動の同期 - 高優先度
struct UserSyncAction: LockmanPriorityBasedAction {
    let actionName = "userSync"
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .high(.exclusive),
            blocksSameAction: true
        )
    }
}

// 使用時にCancelIDで境界を指定
enum CancelID {
    case userAction
}

return .withLock(
    action: syncAction,
    cancelID: CancelID.userAction  // この境界内で優先度制御
)
```

## ベストプラクティス

### 1. 優先度の設計指針

- **高優先度**: ユーザーが直接起動した操作
- **低優先度**: バックグラウンド処理、自動更新
- **none**: 優先度制御が不要な独立した処理

```swift
// ✅ 良い例：明確な優先度階層
// ユーザー操作 = 高優先度
@LockmanPriorityBased
enum UserAction {
    case save
    case load
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .high(.exclusive)
        )
    }
}

// バックグラウンド = 低優先度
@LockmanPriorityBased
enum BackgroundAction {
    case sync
    case cache
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .low(.replaceable)
        )
    }
}
```

### 2. ConcurrencyBehaviorの選択

```swift
// Exclusive: 完了が必要な重要な操作
// - 支払い処理
// - データ保存
// - 認証フロー

// Replaceable: 最新の結果が重要な操作
// - 検索
// - フィルタリング
// - リアルタイムデータ取得
```

### 3. キャンセレーション対応

```swift
return .withLock(
    operation: { send in
        // 長時間実行される処理では定期的にチェック
        for (index, item) in items.enumerated() {
            if index % 10 == 0 {
                try Task.checkCancellation()
            }
            
            await processItem(item)
        }
    },
    catch: { error, send in
        if error is CancellationError {
            // 高優先度タスクによってキャンセルされた
            await send(.processingInterrupted)
        }
    },
    action: LongRunningAction(),
    cancelID: CancelID.userAction
)
```

### 4. 優先度ベースの置換

```swift
// 中断可能な長時間処理
@LockmanPriorityBased
enum BackgroundAction {
    case processLargeData
    case syncDatabase
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        .init(
            actionId: actionName,
            priority: .low(.replaceable),
            blocksSameAction: false
        )
    }
}

// タスク内で定期的にキャンセルをチェック
return .withLock(
    operation: { send in
        for item in items {
            try Task.checkCancellation()
            await processItem(item)
        }
    },
    action: BackgroundAction.processLargeData,
    cancelID: CancelID.userAction
)
```

## デバッグとモニタリング

```swift
// 優先度による実行状況を確認
extension Lockman.Debug {
    func printPriorityStatus() {
        let locks = currentLocks()
        locks.forEach { lock in
            if let info = lock as? LockmanPriorityBasedInfo {
                print("Action: \(info.actionId), Priority: \(info.priority)")
            }
        }
    }
}

#if DEBUG
// 現在のロック状態を確認
let locks = Lockman.Debug.currentLocks(for: CancelID.userAction)
print("Active locks: \(locks)")
#endif
```

## パフォーマンス考慮事項

- 優先度比較は O(1) で高速
- 適切なCancelIDの分離で並行性を最大化
- 頻繁なキャンセルチェックで応答性を向上

## 次のステップ

- <doc:GroupCoordination> - グループベースの協調制御
- <doc:Composite> - 優先度と他の戦略の組み合わせ