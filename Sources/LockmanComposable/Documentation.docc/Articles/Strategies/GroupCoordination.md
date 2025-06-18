# Group Coordination Strategy

関連するアクションをグループとして協調制御する戦略

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`GroupCoordinationStrategy`は、複数の関連するアクションをグループとして管理し、リーダー/メンバーの役割に基づいて実行を制御する戦略です。マルチステップの処理フロー、依存関係のある非同期処理、データの読み込みとUI更新など、TCAアプリケーションでよく見られるパターンに最適です。

## グループの概念

### 役割（Role）

```swift
public enum GroupCoordinationRole {
    case leader   // グループを開始し、メンバーの実行を可能にする
    case member   // リーダーが存在する時のみ実行可能
}
```

### グループのライフサイクル

1. **開始**: リーダーアクションの実行でグループが開始
2. **参加**: メンバーアクションが実行可能になる
3. **並行実行**: 複数のメンバーが同時実行可能
4. **終了**: すべてのアクション完了でグループが終了
5. **再開**: 新しいリーダーで新たなグループを開始可能

## @LockmanGroupCoordinationマクロ

`@LockmanGroupCoordination`マクロを使用して、グループ協調アクションを簡潔に定義できます。

```swift
@LockmanGroupCoordination
enum DashboardAction {
    case loadData      // リーダー
    case updateCharts  // メンバー
    case refreshStats  // メンバー
    
    var lockmanInfo: LockmanGroupCoordinatedInfo {
        let role: GroupCoordinationRole = self == .loadData ? .leader : .member
        return .init(
            actionId: actionName,  // マクロが生成
            groupId: "dashboardRefresh",
            coordinationRole: role
        )
    }
}
```

### マクロが生成するもの

1. **`LockmanGroupCoordinatedAction`プロトコルへの準拠**
2. **`actionName`プロパティ** - enumのcase名の文字列を返す

### 複数グループの管理

```swift
@LockmanGroupCoordination
enum FileAction {
    case upload(fileId: String)
    case compress(fileId: String)
    case generateThumbnail(fileId: String)
    
    var lockmanInfo: LockmanGroupCoordinatedInfo {
        switch self {
        case .upload(let fileId):
            return .init(
                actionId: "upload_\(fileId)",
                groupId: "file_process_\(fileId)",  // ファイルごとのグループ
                coordinationRole: .leader
            )
        case .compress(let fileId):
            return .init(
                actionId: "compress_\(fileId)",
                groupId: "file_process_\(fileId)",
                coordinationRole: .member
            )
        case .generateThumbnail(let fileId):
            return .init(
                actionId: "thumbnail_\(fileId)",
                groupId: "file_process_\(fileId)",
                coordinationRole: .member
            )
        }
    }
}
```

## TCAでの実装例

### 基本的なデータ読み込みパターン

```swift
@Reducer
struct DashboardFeature {
    @ObservableState
    struct State {
        var userData: UserData?
        var statistics: Statistics?
        var recommendations: [Recommendation] = []
        var isLoading = false
        var loadingSteps: Set<LoadingStep> = []
        
        enum LoadingStep {
            case fetchingUser
            case calculatingStats  
            case loadingRecommendations
        }
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanGroupCoordination
        enum ViewAction {
            case refreshButtonTapped
            
            var lockmanInfo: LockmanGroupCoordinatedInfo {
                .init(
                    actionId: actionName,
                    groupId: "dashboardRefresh",
                    coordinationRole: .leader
                )
            }
        }
        
        enum InternalAction {
            case userDataLoaded(UserData)
            case statisticsCalculated(Statistics)
            case recommendationsLoaded([Recommendation])
            case loadingStepCompleted(State.LoadingStep)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    @LockmanGroupCoordination
    struct CalculateStatsAction: LockmanAction {
        var lockmanInfo: LockmanGroupCoordinatedInfo {
            .init(
                actionId: "calculateStatistics",
                groupId: "dashboardRefresh",
                coordinationRole: .member
            )
        }
    }
    
    @LockmanGroupCoordination
    struct LoadRecommendationsAction: LockmanAction {
        var lockmanInfo: LockmanGroupCoordinatedInfo {
            .init(
                actionId: "loadRecommendations",
                groupId: "dashboardRefresh",
                coordinationRole: .member
            )
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .refreshButtonTapped:
                    state.isLoading = true
                    state.loadingSteps = [.fetchingUser]
                    
                    return .withLock(
                        operation: { send in
                            let userData = try await userAPI.fetchCurrentUser()
                            await send(.internal(.userDataLoaded(userData)))
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case let .userDataLoaded(userData):
                    state.userData = userData
                    state.loadingSteps.remove(.fetchingUser)
                    state.loadingSteps.formUnion([.calculatingStats, .loadingRecommendations])
                    
                    return .merge(
                        .withLock(
                            operation: { [userId = userData.id] send in
                                let stats = try await statsService.calculate(for: userId)
                                await send(.internal(.statisticsCalculated(stats)))
                                await send(.internal(.loadingStepCompleted(.calculatingStats)))
                            },
                            action: CalculateStatsAction(),
                            cancelID: CancelID.userAction
                        ),
                        
                        .withLock(
                            operation: { [preferences = userData.preferences] send in
                                let recommendations = try await recommendationAPI.fetch(
                                    basedOn: preferences
                                )
                                await send(.internal(.recommendationsLoaded(recommendations)))
                                await send(.internal(.loadingStepCompleted(.loadingRecommendations)))
                            },
                            action: LoadRecommendationsAction(),
                            cancelID: CancelID.userAction
                        )
                    )
                    
                case let .statisticsCalculated(statistics):
                    state.statistics = statistics
                    return .none
                    
                case let .recommendationsLoaded(recommendations):
                    state.recommendations = recommendations
                    return .none
                    
                case let .loadingStepCompleted(step):
                    state.loadingSteps.remove(step)
                    if state.loadingSteps.isEmpty {
                        state.isLoading = false
                }
                return .none
            }
        }
    }
}
```

### マルチステップフォーム処理

```swift
@Reducer
struct CheckoutFeature {
    @ObservableState
    struct State {
        var cart: Cart
        var shippingInfo: ShippingInfo?
        var paymentMethod: PaymentMethod?
        var orderConfirmation: OrderConfirmation?
        var currentStep: CheckoutStep = .validateCart
        
        enum CheckoutStep {
            case validateCart
            case calculateShipping
            case processPayment
            case confirmOrder
        }
    }
    
    enum Action {
        case startCheckout
        case cartValidated
        case shippingCalculated(ShippingInfo)
        case paymentProcessed(PaymentConfirmation)
        case orderConfirmed(OrderConfirmation)
        case checkoutFailed(CheckoutError)
    }
    
    enum CancelID {
        case userAction
    }
    
    // リーダー：カート検証
    @LockmanGroupCoordination(
        actionId: "validateCart",
        groupId: "checkoutFlow",
        role: .leader
    )
    struct ValidateCartAction: LockmanAction {}
    
    // メンバー：送料計算
    @LockmanGroupCoordination(
        actionId: "calculateShipping",
        groupId: "checkoutFlow",
        role: .member
    )
    struct CalculateShippingAction: LockmanAction {}
    
    // メンバー：支払い処理
    @LockmanGroupCoordination(
        actionId: "processPayment",
        groupId: "checkoutFlow",
        role: .member
    )
    struct ProcessPaymentAction: LockmanAction {}
    
    // メンバー：注文確定
    @LockmanGroupCoordination(
        actionId: "confirmOrder",
        groupId: "checkoutFlow",
        role: .member
    )
    struct ConfirmOrderAction: LockmanAction {}
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startCheckout:
                state.currentStep = .validateCart
                
                // ステップ1：カート検証（リーダー）
                return .withLock(
                    operation: { [cart = state.cart] send in
                        // 在庫確認、価格検証など
                        try await checkoutAPI.validateCart(cart)
                        await send(.cartValidated)
                    },
                    catch: { error, send in
                        await send(.checkoutFailed(.cartValidation(error)))
                    },
                    action: ValidateCartAction(),
                    cancelID: CancelID.userAction
                )
                
            case .cartValidated:
                state.currentStep = .calculateShipping
                
                // ステップ2：送料計算（メンバー）
                return .withLock(
                    operation: { [cart = state.cart] send in
                        let shippingInfo = try await shippingAPI.calculate(for: cart)
                        await send(.shippingCalculated(shippingInfo))
                    },
                    catch: { error, send in
                        await send(.checkoutFailed(.shippingCalculation(error)))
                    },
                    action: CalculateShippingAction(),
                    cancelID: CancelID.userAction
                )
                
            case let .shippingCalculated(shippingInfo):
                state.shippingInfo = shippingInfo
                state.currentStep = .processPayment
                
                // ステップ3：支払い処理（メンバー）
                return .withLock(
                    operation: { [cart = state.cart, shipping = shippingInfo] send in
                        let total = cart.subtotal + shipping.cost
                        let confirmation = try await paymentAPI.process(
                            amount: total,
                            method: state.paymentMethod!
                        )
                        await send(.paymentProcessed(confirmation))
                    },
                    catch: { error, send in
                        await send(.checkoutFailed(.paymentProcessing(error)))
                    },
                    action: ProcessPaymentAction(),
                    cancelID: CancelID.userAction
                )
                
            case let .paymentProcessed(confirmation):
                state.currentStep = .confirmOrder
                
                // ステップ4：注文確定（メンバー）
                return .withLock(
                    operation: { send in
                        let order = try await orderAPI.confirm(
                            cart: state.cart,
                            shipping: state.shippingInfo!,
                            payment: confirmation
                        )
                        await send(.orderConfirmed(order))
                    },
                    catch: { error, send in
                        await send(.checkoutFailed(.orderConfirmation(error)))
                    },
                    action: ConfirmOrderAction(),
                    cancelID: CancelID.userAction
                )
                
            case let .orderConfirmed(confirmation):
                state.orderConfirmation = confirmation
                return .none
                
            case let .checkoutFailed(error):
                // エラーハンドリング
                return .none
            }
        }
    }
}
```

### 複雑なメディア処理パイプライン

```swift
@Reducer
struct VideoProcessingFeature {
    @ObservableState
    struct State {
        var videoURL: URL?
        var processingSteps: Set<ProcessingStep> = []
        var thumbnail: UIImage?
        var audioTrack: AudioFile?
        var subtitles: SubtitleFile?
        var metadata: VideoMetadata?
        
        enum ProcessingStep: String, CaseIterable {
            case loadingVideo = "動画を読み込み中"
            case extractingAudio = "音声を抽出中"
            case generatingThumbnails = "サムネイルを生成中"
            case extractingSubtitles = "字幕を抽出中"
            case analyzingMetadata = "メタデータを解析中"
        }
    }
    
    enum Action {
        case processVideo(URL)
        case videoLoaded
        case audioExtracted(AudioFile)
        case thumbnailGenerated(UIImage)
        case subtitlesExtracted(SubtitleFile)
        case metadataAnalyzed(VideoMetadata)
        case processingCompleted
    }
    
    enum CancelID {
        case userAction
    }
    
    // 動的にグループIDを生成
    struct VideoProcessingGroup {
        let videoId: String
        
        var groupId: String {
            "videoProcessing_\(videoId)"
        }
    }
    
    // リーダー：動画読み込み
    struct LoadVideoAction: LockmanAction {
        let group: VideoProcessingGroup
        
        var lockmanInfo: LockmanGroupCoordinatedInfo {
            .init(
                actionId: "loadVideo",
                groupId: group.groupId,
                coordinationRole: .leader
            )
        }
        
        let strategyId = LockmanStrategyId.groupCoordination
    }
    
    // メンバーアクションを生成するヘルパー
    func createMemberAction(
        actionId: String,
        group: VideoProcessingGroup
    ) -> some LockmanAction {
        struct MemberAction: LockmanAction {
            let info: LockmanGroupCoordinatedInfo
            let strategyId = LockmanStrategyId.groupCoordination
            
            var lockmanInfo: LockmanGroupCoordinatedInfo { info }
        }
        
        return MemberAction(
            info: .init(
                actionId: actionId,
                groupId: group.groupId,
                coordinationRole: .member
            )
        )
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .processVideo(url):
                state.videoURL = url
                state.processingSteps = [.loadingVideo]
                
                let group = VideoProcessingGroup(
                    videoId: url.lastPathComponent
                )
                
                // リーダー：動画を読み込む
                return .withLock(
                    operation: { send in
                        try await videoService.loadVideo(from: url)
                        await send(.videoLoaded)
                    },
                    action: LoadVideoAction(group: group),
                    cancelID: CancelID.userAction
                )
                
            case .videoLoaded:
                state.processingSteps.remove(.loadingVideo)
                state.processingSteps.formUnion([
                    .extractingAudio,
                    .generatingThumbnails,
                    .extractingSubtitles,
                    .analyzingMetadata
                ])
                
                guard let url = state.videoURL else { return .none }
                let group = VideoProcessingGroup(videoId: url.lastPathComponent)
                
                // 並行してメンバータスクを実行
                return .merge(
                    // 音声抽出
                    .withLock(
                        operation: { send in
                            let audio = try await videoService.extractAudio()
                            await send(.audioExtracted(audio))
                        },
                        action: createMemberAction(
                            actionId: "extractAudio",
                            group: group
                        ),
                        cancelID: CancelID.userAction
                    ),
                    
                    // サムネイル生成
                    .withLock(
                        operation: { send in
                            let thumbnail = try await videoService.generateThumbnail()
                            await send(.thumbnailGenerated(thumbnail))
                        },
                        action: createMemberAction(
                            actionId: "generateThumbnail",
                            group: group
                        ),
                        cancelID: CancelID.userAction
                    ),
                    
                    // 字幕抽出
                    .withLock(
                        operation: { send in
                            if let subtitles = try await videoService.extractSubtitles() {
                                await send(.subtitlesExtracted(subtitles))
                            }
                        },
                        action: createMemberAction(
                            actionId: "extractSubtitles",
                            group: group
                        ),
                        cancelID: CancelID.userAction
                    ),
                    
                    // メタデータ解析
                    .withLock(
                        operation: { send in
                            let metadata = try await videoService.analyzeMetadata()
                            await send(.metadataAnalyzed(metadata))
                        },
                        action: createMemberAction(
                            actionId: "analyzeMetadata",
                            group: group
                        ),
                        cancelID: CancelID.userAction
                    )
                )
                
            case let .audioExtracted(audio):
                state.audioTrack = audio
                state.processingSteps.remove(.extractingAudio)
                return checkCompletion(state: &state)
                
            case let .thumbnailGenerated(thumbnail):
                state.thumbnail = thumbnail
                state.processingSteps.remove(.generatingThumbnails)
                return checkCompletion(state: &state)
                
            case let .subtitlesExtracted(subtitles):
                state.subtitles = subtitles
                state.processingSteps.remove(.extractingSubtitles)
                return checkCompletion(state: &state)
                
            case let .metadataAnalyzed(metadata):
                state.metadata = metadata
                state.processingSteps.remove(.analyzingMetadata)
                return checkCompletion(state: &state)
                
            case .processingCompleted:
                // すべての処理が完了
                return .none
            }
        }
    }
    
    func checkCompletion(state: inout State) -> Effect<Action> {
        if state.processingSteps.isEmpty {
            return .send(.processingCompleted)
        }
        return .none
    }
}
```

## 実用的なシナリオ

### マルチステップのデータ処理

```swift
// マルチステップ処理をマクロで定義
@LockmanGroupCoordination
enum OrderProcessingAction {
    case fetchOrders        // リーダー
    case validateOrders     // メンバー
    case aggregateOrders    // メンバー
    
    var lockmanInfo: LockmanGroupCoordinatedInfo {
        switch self {
        case .fetchOrders:
            return .init(
                actionId: "fetchOrders",
                groupId: "orderProcessingGroup",
                coordinationRole: .leader
            )
        case .validateOrders:
            return .init(
                actionId: "validateOrders",
                groupId: "orderProcessingGroup",
                coordinationRole: .member
            )
        case .aggregateOrders:
            return .init(
                actionId: "aggregateOrders",
                groupId: "orderProcessingGroup",
                coordinationRole: .member
            )
        }
    }
}

// CancelIDで境界を定義
enum CancelID {
    case userAction
}

// 使用例
return .withLock(
    action: OrderProcessingAction.fetchOrders,
    cancelID: CancelID.userAction
)
```

### フォームの段階的送信

```swift
// ステップ1: バリデーション（リーダー）
@LockmanGroupCoordination(
    actionId: "validateForm",
    groupId: "registrationFlow",
    role: .leader
)
struct ValidateFormInfo: LockmanInfo {}

// ステップ2: データ送信（メンバー）
@LockmanGroupCoordination(
    actionId: "submitForm",
    groupId: "registrationFlow",
    role: .member
)
struct SubmitFormInfo: LockmanInfo {}

// ステップ3: 確認メール送信（メンバー）
@LockmanGroupCoordination(
    actionId: "sendConfirmation",
    groupId: "registrationFlow",
    role: .member
)
struct SendConfirmationInfo: LockmanInfo {}
```

## 高度な使用パターン

### 複数グループへの参加

```swift
struct MultiGroupAction: LockmanAction {
    let lockmanInfo = LockmanGroupCoordinatedInfo(
        actionId: "multiGroup",
        groupIds: ["dataLoading", "uiUpdate", "analytics"],
        coordinationRole: .member
    )
    let strategyId = LockmanStrategyId.groupCoordination
}
```

### 条件付きグループ参加

```swift
struct ConditionalMemberAction: LockmanGroupCoordinatedAction, LockmanSingleGroupAction {
    let actionName = "conditionalAction"
    let groupId = "conditionalGroup"
    let coordinationRole: GroupCoordinationRole = .member
}

case .conditionalAction:
    let shouldJoinGroup = state.hasPermission && state.isNetworkAvailable
    
    if shouldJoinGroup {
        return .withLock(
            operation: { send in
                // グループメンバーとして実行
            },
            action: ConditionalMemberAction(),
            cancelID: CancelID.userAction
        )
    } else {
        // 独立して実行
        return .run { send in
            // 通常の処理
        }
    }
```

### 動的なグループID

```swift
struct DynamicGroupInfo: LockmanGroupCoordinatedInfo {
    let actionId: LockmanActionId
    let groupId: LockmanGroupId
    let role: LockmanGroupRole
    
    init(sessionId: String, role: LockmanGroupRole) {
        self.actionId = LockmanActionId("process-\(role)")
        self.groupId = LockmanGroupId("session-\(sessionId)")
        self.role = role
    }
}
```

## ベストプラクティス

### 1. グループ設計の指針

- **明確な依存関係**: リーダーとメンバーの関係を明確に
- **適切な粒度**: グループが大きすぎず、小さすぎない
- **単一責任**: 各アクションは明確な役割を持つ

```swift
// ✅ 良い例：明確な依存関係
// データ取得（リーダー） → UI更新（メンバー）
// 認証（リーダー） → ユーザー情報取得（メンバー）

// ❌ 悪い例：循環依存
// A（リーダー） → B（メンバー） → A（メンバー）
```

### 2. エラーハンドリング

```swift
// リーダーのエラーでグループ全体が終了
struct CriticalLeaderAction: LockmanGroupCoordinatedAction, LockmanSingleGroupAction {
    let actionName = "criticalOperation"
    let groupId = "criticalGroup"
    let coordinationRole: GroupCoordinationRole = .leader
}

return .withLock(
    operation: { send in
        do {
            try await criticalOperation()
        } catch {
            // グループが終了し、メンバーは実行されない
            throw error
        }
    },
    action: CriticalLeaderAction(),
    cancelID: CancelID.userAction
)

// リーダーのエラーでグループ全体を終了
case .loadDataFailed(let error):
    state.error = error
    // グループが自動的に終了し、メンバーは実行されない
    return .none
```

### 3. パフォーマンス最適化

```swift
// メンバータスクは並行実行可能
return .merge(
    memberTasks.map { task in
        .withLock(
            operation: task.operation,
            action: task.action,
            cancelID: task.cancelID
        )
    }
)
```

### 4. デバッグとモニタリング

```swift
// 現在のグループ状態を確認
#if DEBUG
extension Lockman.Debug {
    func printGroupStatus() {
        let groups = activeGroups()
        groups.forEach { group in
            print("Group: \(group.id)")
            print("Leader: \(group.leader)")
            print("Members: \(group.members)")
        }
    }
}
#endif
```

## 次のステップ

- <doc:DynamicCondition> - 条件付き実行の制御
- <doc:Composite> - グループ協調と他の戦略の組み合わせ