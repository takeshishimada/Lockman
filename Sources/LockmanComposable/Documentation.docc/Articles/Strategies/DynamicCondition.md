# Dynamic Condition Strategy

実行時の条件に基づいて動的にアクションを制御する戦略

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`DynamicConditionStrategy`は、実行時に評価される条件に基づいてアクションの実行可否を決定する戦略です。権限チェック、ネットワーク状態、アプリの状態、ユーザーのサブスクリプション状況など、動的な条件に応じた柔軟な制御がTCAアプリケーションで可能になります。

アプリケーションの状態、ユーザーの権限、ネットワーク状況など、動的な条件に応じた柔軟な制御が可能です。

## 条件関数の仕組み

### 基本構造

```swift
// The condition closure signature is:
// @Sendable () -> Bool  // Note: NOT async

struct ConditionalAction: LockmanDynamicConditionAction {
    let actionName = "conditionalAction"
    
    // Using the protocol's default implementation
    // which provides lockmanInfo with always-true condition
    // and strategyId = .dynamicCondition
}
```

### 条件評価のタイミング

1. `Effect.withLock`呼び出し時
2. ロック取得前に条件を評価
3. `true`の場合のみロック取得・実行
4. `false`の場合は`.none`を返す

## @LockmanDynamicConditionマクロ

`@LockmanDynamicCondition`マクロを使用して、条件付きアクションを簡潔に定義できます。

```swift
@LockmanDynamicCondition
enum PremiumAction {
    case exportData
    case advancedAnalytics
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        .init(
            actionId: actionName,  // マクロが生成
            condition: { 
                // 実行時に評価される条件
                UserService.shared.isPremiumUser
            }
        )
    }
}
```

### マクロが生成するもの

1. **`LockmanDynamicConditionAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

### 動的な条件の設定

状態に基づく条件やパラメータに基づく条件を定義：

```swift
@LockmanDynamicCondition
enum ConditionalAction {
    case processLargeFile(size: Int64)
    case syncData(force: Bool)
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        switch self {
        case .processLargeFile(let size):
            return .init(
                actionId: "processFile",
                condition: {
                    // 大きいファイルは空き容量をチェック
                    size < 100_000_000 || StorageManager.hasSpace(for: size)
                }
            )
        case .syncData(let force):
            return .init(
                actionId: "syncData",
                condition: {
                    // 強制同期またはWiFi接続時のみ
                    force || NetworkMonitor.isWiFiConnected
                }
            )
        }
    }
}
```

## TCAでの実装例

### プレミアム機能の制御

```swift
@Reducer
struct PremiumFeature {
    @ObservableState
    struct State {
        var isPremiumUser = false
        var premiumFeatures: [Feature] = []
        var showUpgradePrompt = false
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        enum ViewAction {
            case premiumFeatureTapped(FeatureID)
            case checkPremiumStatus
        }
        
        enum InternalAction {
            case featureExecuted(FeatureID)
            case showUpgradePrompt
            case premiumStatusUpdated(Bool)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    struct PremiumOnlyAction: LockmanAction {
        let featureId: FeatureID
        let isPremium: Bool
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "premium_\(featureId)",
                condition: { [isPremium] in
                    isPremium
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    struct ServerValidatedAction: LockmanAction {
        let userId: String
        let featureId: FeatureID
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "serverValidated_\(featureId)",
                condition: { [userId, featureId] in
                    // For async operations, you'll need to handle them differently
                    // Consider caching permissions or using a synchronous check
                    PermissionCache.shared.hasPermission(
                        userId: userId,
                        featureId: featureId
                    )
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case let .premiumFeatureTapped(featureId):
                    let effect1 = Effect<Action>.withLock(
                        operation: { send in
                            await send(.internal(.featureExecuted(featureId)))
                        },
                        action: PremiumOnlyAction(
                            featureId: featureId,
                            isPremium: state.isPremiumUser
                        ),
                        cancelID: CancelID.userAction
                    )
                    
                    if !state.isPremiumUser {
                        return .merge(
                            effect1,
                            .send(.internal(.showUpgradePrompt))
                        )
                    }
                    
                    return effect1
                    
                case .checkPremiumStatus:
                    return .run { send in
                        let isPremium = try await api.checkPremiumStatus()
                        await send(.internal(.premiumStatusUpdated(isPremium)))
                    }
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case let .featureExecuted(featureId):
                    switch featureId {
                    case .advancedAnalytics:
                        return .run { send in
                            let analytics = try await analyticsService.generateAdvanced()
                        }
                    default:
                        return .none
                    }
                    
                case .showUpgradePrompt:
                state.showUpgradePrompt = true
                return .none
                
            case .checkPremiumStatus:
                return .run { send in
                    let isPremium = try await subscriptionService.checkStatus()
                    await send(.premiumStatusUpdated(isPremium))
                }
                
            case let .premiumStatusUpdated(isPremium):
                state.isPremiumUser = isPremium
                return .none
            }
        }
    }
}
```

### ネットワーク状態による制御

```swift
@Reducer
struct OfflineCapableFeature {
    @ObservableState
    struct State {
        var items: [Item] = []
        var pendingSyncItems: [Item] = []
        var isOnline = true
        var lastSync: Date?
    }
    
    enum Action {
        case refreshButtonTapped
        case saveItem(Item)
        case itemSaved(Item)
        case itemQueuedForSync(Item)
        case syncCompleted
        case networkStatusChanged(Bool)
    }
    
    enum CancelID {
        case userAction
    }
    
    // オンライン時のみ実行
    struct OnlineSyncAction: LockmanDynamicConditionAction {
        let actionName = "onlineSync"
        
        func with(condition: @escaping @Sendable () -> Bool) -> LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: condition
            )
        }
    }
    
    // WiFi接続時のみ実行（大容量データ）
    struct WiFiOnlyAction: LockmanAction {
        let dataSize: Int64
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "wifiOnlySync",
                condition: { [dataSize] in
                    let isWiFi = NetworkMonitor.shared.isWiFiConnectedSync
                    let isLargeData = dataSize > 10_000_000 // 10MB以上
                    
                    // 小さいデータまたはWiFi接続時のみ
                    return !isLargeData || isWiFi
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .refreshButtonTapped:
                // オンライン時のみ同期
                return .withLock(
                    operation: { send in
                        let items = try await api.fetchLatestItems()
                        state.items = items
                        state.lastSync = Date()
                        await send(.syncCompleted)
                    },
                    action: OnlineSyncAction().with {
                        // Synchronous condition check
                        NetworkMonitor.shared.isConnectedSync
                    },
                    cancelID: CancelID.userAction
                )
                
            case let .saveItem(item):
                // オンライン/オフラインで処理を分岐
                let onlineSave = Effect<Action>.withLock(
                    operation: { send in
                        try await api.saveItem(item)
                        await send(.itemSaved(item))
                    },
                    action: OnlineSyncAction().with {
                        NetworkMonitor.shared.isConnectedSync
                    },
                    cancelID: CancelID.userAction
                )
                
                let offlineSave = Effect<Action>.run { send in
                    // ローカルに保存し、同期キューに追加
                    await localStore.save(item)
                    await send(.itemQueuedForSync(item))
                }
                
                // オンラインなら即座に保存、オフラインならキューに追加
                return state.isOnline ? onlineSave : offlineSave
                
            case let .itemSaved(item):
                state.items.append(item)
                return .none
                
            case let .itemQueuedForSync(item):
                state.pendingSyncItems.append(item)
                return .none
                
            case .syncCompleted:
                // 保留中のアイテムを同期
                guard !state.pendingSyncItems.isEmpty else { return .none }
                
                return .run { [items = state.pendingSyncItems] send in
                    for item in items {
                        _ = await Effect<Action>.withLock(
                            operation: { _ in
                                try await api.saveItem(item)
                            },
                            action: OnlineSyncAction().with {
                                NetworkMonitor.shared.isConnectedSync
                            },
                            cancelID: CancelID.userAction
                        )
                    }
                    state.pendingSyncItems.removeAll()
                }
                
            case let .networkStatusChanged(isOnline):
                state.isOnline = isOnline
                if isOnline && !state.pendingSyncItems.isEmpty {
                    // オンラインに戻ったら自動同期
                    return .send(.syncCompleted)
                }
                return .none
            }
        }
    }
}
```

### リソース使用量による制御

```swift
@Reducer
struct ResourceAwareFeature {
    @ObservableState
    struct State {
        var processingQueue: [ProcessingTask] = []
        var activeProcessing: Set<ProcessingTask.ID> = []
        var batteryLevel: Float = 1.0
        var thermalState: ProcessInfo.ThermalState = .nominal
    }
    
    enum Action {
        case addProcessingTask(ProcessingTask)
        case processTask(ProcessingTask)
        case taskCompleted(ProcessingTask.ID)
        case updateSystemStatus
        case systemStatusUpdated(batteryLevel: Float, thermalState: ProcessInfo.ThermalState)
    }
    
    enum CancelID {
        case userAction
    }
    
    // バッテリーとCPU温度を考慮した処理
    struct ResourceAwareAction: LockmanAction {
        let task: ProcessingTask
        let batteryLevel: Float
        let thermalState: ProcessInfo.ThermalState
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "resourceAware_\(task.id)",
                condition: { [batteryLevel, thermalState, task] in
                    // 条件1: バッテリー残量チェック
                    let sufficientBattery = batteryLevel > 0.2 || 
                                          ProcessInfo.processInfo.isLowPowerModeEnabled == false
                    
                    // 条件2: CPU温度チェック
                    let acceptableThermal = thermalState != .critical
                    
                    // 条件3: タスクの優先度
                    let isHighPriority = task.priority == .high
                    
                    // 高優先度タスクは条件を緩和
                    if isHighPriority {
                        return batteryLevel > 0.05 && thermalState != .critical
                    }
                    
                    return sufficientBattery && acceptableThermal
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    // メモリ使用量をチェック
    struct MemoryAwareAction: LockmanAction {
        let requiredMemory: Int64  // bytes
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "memoryAware",
                condition: { [requiredMemory] in
                    let availableMemory = await SystemMonitor.shared.availableMemory()
                    let memoryPressure = await SystemMonitor.shared.memoryPressure()
                    
                    // 必要なメモリ + バッファ（20%）が利用可能
                    let hasEnoughMemory = availableMemory > requiredMemory * 1.2
                    
                    // メモリプレッシャーが高くない
                    let acceptablePressure = memoryPressure < .warning
                    
                    return hasEnoughMemory && acceptablePressure
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .addProcessingTask(task):
                state.processingQueue.append(task)
                return .send(.processTask(task))
                
            case let .processTask(task):
                state.activeProcessing.insert(task.id)
                
                return .withLock(
                    operation: { send in
                        // リソース集約的な処理
                        switch task.type {
                        case .imageProcessing:
                            try await processImage(task.data)
                        case .videoEncoding:
                            try await encodeVideo(task.data)
                        case .dataAnalysis:
                            try await analyzeData(task.data)
                        }
                        
                        await send(.taskCompleted(task.id))
                    },
                    action: ResourceAwareAction(
                        task: task,
                        batteryLevel: state.batteryLevel,
                        thermalState: state.thermalState
                    ),
                    cancelID: CancelID.userAction
                )
                
            case let .taskCompleted(taskId):
                state.activeProcessing.remove(taskId)
                state.processingQueue.removeAll { $0.id == taskId }
                
                // 次のタスクを処理
                if let nextTask = state.processingQueue.first(
                    where: { !state.activeProcessing.contains($0.id) }
                ) {
                    return .send(.processTask(nextTask))
                }
                return .none
                
            case .updateSystemStatus:
                return .run { send in
                    let battery = await UIDevice.current.batteryLevel
                    let thermal = ProcessInfo.processInfo.thermalState
                    await send(.systemStatusUpdated(
                        batteryLevel: battery,
                        thermalState: thermal
                    ))
                }
                
            case let .systemStatusUpdated(batteryLevel, thermalState):
                state.batteryLevel = batteryLevel
                state.thermalState = thermalState
                return .none
            }
        }
    }
}
```

### 時間帯による制御

```swift
@Reducer
struct ScheduledFeature {
    @ObservableState
    struct State {
        var scheduledTasks: [ScheduledTask] = []
        var businessHoursOnly = true
    }
    
    enum Action {
        case executeTask(ScheduledTask)
        case taskExecuted(ScheduledTask.ID)
        case scheduleNextExecution
    }
    
    // 営業時間内のみ実行
    struct BusinessHoursAction: LockmanDynamicConditionAction {
        let actionName = "businessHours"
        
        // Using the default with(condition:) method from protocol
        // We'll create the condition when calling the action
    
    // カスタムスケジュール
    struct ScheduledAction: LockmanAction {
        let schedule: Schedule
        
        var lockmanInfo: LockmanDynamicConditionInfo {
            .init(
                actionId: "scheduled_\(schedule.id)",
                condition: { [schedule] in
                    let now = Date()
                    
                    // 時間帯チェック
                    if let allowedHours = schedule.allowedHours {
                        let hour = Calendar.current.component(.hour, from: now)
                        guard allowedHours.contains(hour) else { return false }
                    }
                    
                    // 曜日チェック
                    if let allowedWeekdays = schedule.allowedWeekdays {
                        let weekday = Calendar.current.component(.weekday, from: now)
                        guard allowedWeekdays.contains(weekday) else { return false }
                    }
                    
                    // レート制限チェック
                    if let rateLimit = schedule.rateLimit {
                        let recentExecutions = TaskHistory.shared
                            .getExecutionsSync(for: schedule.id, since: now.addingTimeInterval(-rateLimit.window))
                        guard recentExecutions.count < rateLimit.maxExecutions else { return false }
                    }
                    
                    return true
                }
            )
        }
        
        let strategyId = LockmanStrategyId.dynamicCondition
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .executeTask(task):
                if state.businessHoursOnly {
                    // 営業時間内のみ
                    return .withLock(
                        operation: { send in
                            try await executeScheduledTask(task)
                            await send(.taskExecuted(task.id))
                        },
                        action: BusinessHoursAction().with {
                            let now = Date()
                            let calendar = Calendar.current
                            let hour = calendar.component(.hour, from: now)
                            let weekday = calendar.component(.weekday, from: now)
                            
                            // 平日の9時から18時
                            let isWeekday = (2...6).contains(weekday)
                            let isBusinessHours = (9..<18).contains(hour)
                            
                            return isWeekday && isBusinessHours
                        },
                        cancelID: .scheduledTask(id: task.id)
                    )
                } else {
                    // カスタムスケジュール
                    return .withLock(
                        operation: { send in
                            try await executeScheduledTask(task)
                            await send(.taskExecuted(task.id))
                        },
                        action: ScheduledAction(schedule: task.schedule),
                        cancelID: .scheduledTask(id: task.id)
                    )
                }
                
            case let .taskExecuted(taskId):
                // 実行履歴を記録
                return .run { _ in
                    await TaskHistory.shared.recordExecution(taskId: taskId)
                }
                
            case .scheduleNextExecution:
                // 次の実行をスケジュール
                return .none
            }
        }
    }
}
```

## 実用的なシナリオ

### 権限ベースのアクセス制御

```swift
struct AdminAction: LockmanDynamicConditionAction {
    let actionName: String
    let userId: String
    
    init(action: String, userId: String) {
        self.actionName = action
        self.userId = userId
    }
    
    // Custom implementation of with(condition:) for admin check
    func with(condition: @escaping @Sendable () -> Bool) -> LockmanDynamicConditionInfo {
        LockmanDynamicConditionInfo(
            actionId: actionName,
            condition: condition
        )
    }
}

// CancelIDで境界を定義
enum CancelID {
    case userAction
}

// 使用例
case .deleteAllData:
    return .withLock(
        operation: { send in
            await dataService.deleteAll()
            await send(.dataDeleted)
        },
        action: AdminAction(action: "deleteAll", userId: currentUserId).with {
            // Synchronous permission check
            UserService.shared.checkPermissionSync(userId: currentUserId)
        },
        cancelID: CancelID.userAction
    )
```

## 高度なパターン

### 複合条件

```swift
struct ComplexConditionAction: LockmanAction {
    let userId: String
    let featureFlags: FeatureFlags
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        .init(
            actionId: "complexFeature",
            condition: { [userId, featureFlags] in
                // 並行して複数の条件をチェック
                // All checks must be synchronous
                let hasPermission = PermissionService.shared.checkSync(userId: userId)
                let isFeatureEnabled = featureFlags.isEnabled(.advancedFeature)
                let hasQuota = QuotaService.shared.hasAvailableSync(userId: userId)
                let isNotRateLimited = RateLimiter.shared.canProceedSync(userId: userId)
                
                return hasPermission && isFeatureEnabled && hasQuota && isNotRateLimited
            }
        )
    }
    
    let strategyId = LockmanStrategyId.dynamicCondition
}
```

### 条件のキャッシング

```swift
class ConditionCache {
    private var cache: [String: (result: Bool, expiry: Date)] = [:]
    private let lock = NSLock()
    
    func evaluate(
        key: String,
        ttl: TimeInterval,
        condition: @Sendable () -> Bool
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        
        // キャッシュチェック
        if let cached = cache[key], cached.expiry > Date() {
            return cached.result
        }
        
        // 新規評価
        let result = condition()
        cache[key] = (result, Date().addingTimeInterval(ttl))
        return result
    }
}

struct CachedConditionAction: LockmanAction {
    let userId: String
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        .init(
            actionId: "cachedPermission",
            condition: { [userId] in
                ConditionCache.shared.evaluate(
                    key: "permission_\(userId)",
                    ttl: 300  // 5分間キャッシュ
                ) {
                    // Synchronous permission check from cache
                    PermissionCache.shared.hasDetailedPermissions(userId: userId)
                }
            }
        )
    }
    
    let strategyId = LockmanStrategyId.dynamicCondition
}
```

### 条件の変更通知

```swift
@Observable
class ConditionMonitor {
    var canExecute = false
    
    func startMonitoring() {
        Task {
            for await status in NetworkMonitor.shared.statusUpdates {
                canExecute = status == .connected
            }
        }
    }
}

struct ReactiveConditionAction: LockmanDynamicConditionAction {
    let actionName = "realtimeSync"
    let monitor: ConditionMonitor
    
    func with(condition: @escaping @Sendable () -> Bool) -> LockmanDynamicConditionInfo {
        LockmanDynamicConditionInfo(
            actionId: actionName,
            condition: { [monitor] in monitor.canExecute }
        )
    }
}
```

## ベストプラクティス

### 1. 条件関数の設計

- **高速評価**: 条件関数は素早く結果を返すべき
- **副作用なし**: 条件評価で状態を変更しない
- **明確な意味**: 条件が何を表すか明確に

```swift
// ✅ 良い例：高速で副作用なし
let condition: @Sendable () -> Bool = {
    let hasPermission = PermissionCache.shared.checkSync()
    return hasPermission
}

// ❌ 悪い例：副作用あり
let condition: @Sendable () -> Bool = {
    modifyGlobalState()  // 副作用
    return true
}
```

### 2. エラーハンドリング

```swift
let condition: @Sendable () -> Bool = {
    do {
        return try riskyCheckSync()
    } catch {
        // エラー時はデフォルトで拒否
        logger.error("Condition check failed: \(error)")
        return false
    }
}
```

### 3. パフォーマンス最適化

```swift
// 軽量なチェックを先に
let condition: @Sendable () -> Bool = {
    // ローカルチェック（高速）
    guard LocalSettings.isEnabled else { return false }
    
    // キャッシュされた権限チェック（同期的）
    return PermissionCache.shared.hasPermission()
}
```

### 4. テスタビリティ

```swift
// テスト可能な条件の設計
struct TestableConditionAction: LockmanDynamicConditionAction {
    let actionName = "testable"
    let conditionProvider: @Sendable () -> Bool
    
    func with(condition: @escaping @Sendable () -> Bool) -> LockmanDynamicConditionInfo {
        LockmanDynamicConditionInfo(
            actionId: actionName,
            condition: condition
        )
    }
    
    // テスト用イニシャライザ
    init(condition: @escaping @Sendable () -> Bool = { true }) {
        self.conditionProvider = condition
    }
}
```

## デバッグとモニタリング

```swift
// 条件評価のログ
struct LoggedConditionAction: LockmanDynamicConditionAction {
    let actionName: String
    let baseCondition: @Sendable () -> Bool
    
    func with(condition: @escaping @Sendable () -> Bool) -> LockmanDynamicConditionInfo {
        LockmanDynamicConditionInfo(
            actionId: actionName,
            condition: {
                let start = Date()
                let result = condition()
                let duration = Date().timeIntervalSince(start)
                
                #if DEBUG
                print("Condition '\(self.actionName)' evaluated to \(result) in \(duration)s")
                #endif
                
                return result
            }
        )
    }
}
```

## 次のステップ

- <doc:Composite> - 条件付き実行と他の戦略の組み合わせ
- <doc:Debugging> - 条件評価のデバッグ方法