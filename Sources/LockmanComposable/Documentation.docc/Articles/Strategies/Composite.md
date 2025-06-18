# Composite Strategy

複数の戦略を組み合わせて高度な制御を実現する戦略

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`CompositeStrategy`は、複数のLockman戦略を組み合わせて使用できる強力な戦略です。各戦略の特性を活かしながら、複雑なビジネスロジックに対応する柔軟な制御が可能になります。すべての戦略が許可した場合のみアクションが実行されます。

Lockmanは2〜5個の戦略を組み合わせることができ、それぞれに対応する型が用意されています：
- `LockmanCompositeInfo2` - 2つの戦略を組み合わせる
- `LockmanCompositeInfo3` - 3つの戦略を組み合わせる
- `LockmanCompositeInfo4` - 4つの戦略を組み合わせる
- `LockmanCompositeInfo5` - 5つの戦略を組み合わせる

## 動作原理

### 戦略の評価順序

1. 指定された順番通りに各戦略を評価
2. いずれかが`.failure`を返したら即座に中断
3. すべてが`.success`または`.successWithPrecedingCancellation`なら実行
4. キャンセルが必要な場合は自動的に処理

## @LockmanCompositeStrategyマクロ

`@LockmanCompositeStrategy`マクロを使用して、複数の戦略を組み合わせたアクションを定義できます。

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self
)
enum ComplexAction {
    case processPayment(amount: Decimal)
    
    var lockmanInfo: LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> {
        .init(
            actionId: actionName,  // マクロが生成
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        )
    }
}
```

### マクロが生成するもの

1. **適切な`LockmanCompositeActionN`プロトコルへの準拠**（Nは戦略数）
2. **`actionName`プロパティ** - enumのcase名の文字列を返す
3. **戦略IDの自動生成** - 組み合わせた戦略から一意のIDを生成

### 3つ以上の戦略の組み合わせ

```swift
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self,
    LockmanDynamicConditionStrategy.self
)
enum AdvancedAction {
    case complexOperation
    
    var lockmanInfo: LockmanCompositeInfo3<
        LockmanSingleExecutionInfo,
        LockmanPriorityBasedInfo,
        LockmanDynamicConditionInfo
    > {
        .init(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            ),
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: { UserService.shared.isPremium }
            )
        )
    }
}
```

### 基本的な使い方（2つの戦略）

```swift
// プロトコル準拠を使った実装
struct ComplexAction: LockmanCompositeAction2 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    
    let actionName = "complexAction"
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "ComplexActionComposite")
    }
    
    var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
        LockmanCompositeInfo2(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: actionName,
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: actionName,
                priority: .high(.exclusive)
            )
        )
    }
}
```

## TCAでの実装例

### 支払い処理の複合制御

```swift
@Reducer
struct PaymentFeature {
    @ObservableState
    struct State {
        var paymentMethod: PaymentMethod?
        var amount: Decimal
        var isProcessing = false
        var hasValidCard = false
        var userTier: UserTier = .standard
    }
    
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        // マクロを使用して3つの戦略を組み合わせ
        @LockmanCompositeStrategy(
            LockmanSingleExecutionStrategy.self,
            LockmanPriorityBasedStrategy.self,
            LockmanDynamicConditionStrategy.self
        )
        enum ViewAction {
            case payButtonTapped
            
            var lockmanInfo: LockmanCompositeInfo3<
                LockmanSingleExecutionInfo,
                LockmanPriorityBasedInfo,
                LockmanDynamicConditionInfo
            > {
                LockmanCompositeInfo3(
                    actionId: actionName,
                    lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                        actionId: "paymentSingle",
                        mode: .boundary
                    ),
                    lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                        actionId: "paymentPriority",
                        priority: .high(.exclusive)
                    ),
                    lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                        actionId: "paymentCondition",
                        condition: {
                            return true
                        }
                    )
                )
            }
        }
        
        enum InternalAction {
            case paymentValidated
            case paymentProcessed(PaymentResult)
            case paymentFailed(PaymentError)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    // 手動実装の例（3つの戦略）
    struct PaymentAction: LockmanCompositeAction3 {
        typealias I1 = LockmanSingleExecutionInfo
        typealias S1 = LockmanSingleExecutionStrategy
        typealias I2 = LockmanPriorityBasedInfo
        typealias S2 = LockmanPriorityBasedStrategy
        typealias I3 = LockmanDynamicConditionInfo
        typealias S3 = LockmanDynamicConditionStrategy
        
        let amount: Decimal
        let userTier: UserTier
        let hasValidCard: Bool
        
        var strategyId: LockmanStrategyId {
            LockmanStrategyId(name: "PaymentComposite")
        }
        
        var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
            LockmanCompositeInfo3(
                actionId: "processPayment",
                lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                    actionId: "paymentSingle",
                    mode: .boundary
                ),
                lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                    actionId: "paymentPriority",
                    priority: userTier == .vip ? .high(.exclusive) : .low(.exclusive)
                ),
                lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                    actionId: "paymentCondition",
                    condition: { [amount, hasValidCard] in
                        guard hasValidCard else { return false }
                        
                        let limit = await PaymentService.shared.getAvailableLimit()
                        guard amount <= limit else { return false }
                        
                        let fraudCheck = await FraudDetection.shared.analyze(amount: amount)
                        return fraudCheck.isLegitimate
                    }
                )
            )
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                switch viewAction {
                case .payButtonTapped:
                    state.isProcessing = true
                    
                    return .withLock(
                        operation: { [amount = state.amount] send in
                            await send(.internal(.paymentValidated))
                            
                            let result = try await PaymentProcessor.shared.process(
                                amount: amount,
                                method: state.paymentMethod!
                            )
                            
                            await send(.internal(.paymentProcessed(result)))
                        },
                        catch: { error, send in
                            await send(.internal(.paymentFailed(error as? PaymentError ?? .unknown)))
                        },
                        action: PaymentAction(
                            amount: state.amount,
                            userTier: state.userTier,
                            hasValidCard: state.hasValidCard
                        ),
                        cancelID: CancelID.userAction
                    )
                }
                
            case .internal(let internalAction):
                switch internalAction {
                case .paymentValidated:
                return .none
                
            case let .paymentProcessed(result):
                state.isProcessing = false
                // 成功処理
                return .none
                
            case let .paymentFailed(error):
                state.isProcessing = false
                // エラー処理
                return .none
            }
        }
    }
}
```

### ファイルアップロードの高度な制御

```swift
@Reducer
struct FileUploadFeature {
    @ObservableState
    struct State {
        var uploadQueue: IdentifiedArrayOf<FileUpload> = []
        var networkType: NetworkType = .wifi
        var availableStorage: Int64 = 0
        var isPremiumUser = false
        
        struct FileUpload: Identifiable {
            let id = UUID()
            let url: URL
            let size: Int64
            let type: FileType
            var progress: Double = 0
            var status: UploadStatus = .pending
            
            enum FileType {
                case image, video, document, archive
            }
            
            enum UploadStatus {
                case pending, uploading, completed, failed
            }
        }
    }
    
    enum Action {
        case addFile(URL)
        case startUpload(State.FileUpload.ID)
        case uploadProgress(State.FileUpload.ID, Double)
        case uploadCompleted(State.FileUpload.ID)
        case uploadFailed(State.FileUpload.ID, Error)
    }
    
    enum CancelID {
        case userAction
    }
    
    // 動的に戦略数が変わる場合の実装（4つまたは3つの戦略）
    struct FileUploadAction: LockmanAction {
        let file: State.FileUpload
        let networkType: NetworkType
        let availableStorage: Int64
        let isPremium: Bool
        
        var strategyId: LockmanStrategyId {
            LockmanStrategyId(name: "FileUploadComposite")
        }
        
        // Premium ユーザーの場合は4つの戦略
        var lockmanInfoFor4: LockmanCompositeInfo4<
            LockmanSingleExecutionInfo,
            LockmanPriorityBasedInfo,
            LockmanDynamicConditionInfo,
            LockmanGroupCoordinatedInfo
        >? {
            guard !isPremium && file.type == .video else { return nil }
            
            return LockmanCompositeInfo4(
                actionId: "fileUpload",
                lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                    actionId: "upload_\(file.id)",
                    mode: .action
                ),
                lockmanInfoForStrategy2: makePriorityInfo(),
                lockmanInfoForStrategy3: makeConditionInfo(),
                lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
                    actionId: "premiumVideoUpload",
                    groupId: "videoUploads",
                    coordinationRole: .member
                )
            )
        }
        
        // 通常は3つの戦略
        var lockmanInfoFor3: LockmanCompositeInfo3<
            LockmanSingleExecutionInfo,
            LockmanPriorityBasedInfo,
            LockmanDynamicConditionInfo
        > {
            LockmanCompositeInfo3(
                actionId: "fileUpload",
                lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                    actionId: "upload_\(file.id)",
                    mode: .action
                ),
                lockmanInfoForStrategy2: makePriorityInfo(),
                lockmanInfoForStrategy3: makeConditionInfo()
            )
        }
        
        private func makePriorityInfo() -> LockmanPriorityBasedInfo {
            let priority: LockmanPriorityBasedInfo.Priority = {
                switch file.type {
                case .document:
                    return .high(.exclusive)
                case .image:
                    return isPremium ? .high(.replaceable) : .low(.replaceable)
                case .video:
                    return .low(.exclusive)
                case .archive:
                    return .low(.replaceable)
                }
            }()
            
            return LockmanPriorityBasedInfo(
                actionId: "uploadPriority",
                priority: priority,
                blocksSameAction: false,
                allowsPreemption: file.type != .document
            )
        }
        
        private func makeConditionInfo() -> LockmanDynamicConditionInfo {
            LockmanDynamicConditionInfo(
                actionId: "uploadCondition",
                condition: { [file, networkType, availableStorage] in
                    // 大きなファイルはWiFi必須
                    if file.size > 50_000_000 && networkType != .wifi {
                        return false
                    }
                    
                    // ストレージチェック（ファイルサイズの2倍必要）
                    if availableStorage < file.size * 2 {
                        return false
                    }
                    
                    // ビデオは追加制限
                    if file.type == .video {
                        let batteryLevel = await UIDevice.current.batteryLevel
                        return batteryLevel > 0.3 || ProcessInfo.processInfo.isLowPowerModeEnabled == false
                    }
                    
                    return true
                }
            )
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .addFile(url):
                guard let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                      let fileSize = fileAttributes[.size] as? Int64 else {
                    return .none
                }
                
                let file = State.FileUpload(
                    url: url,
                    size: fileSize,
                    type: determineFileType(from: url)
                )
                
                state.uploadQueue.append(file)
                return .send(.startUpload(file.id))
                
            case let .startUpload(fileId):
                guard var file = state.uploadQueue[id: fileId] else { return .none }
                
                file.status = .uploading
                state.uploadQueue[id: fileId] = file
                
                return .withLock(
                    operation: { send in
                        // アップロード前の準備
                        let preprocessed = try await preprocessFile(file.url)
                        
                        // プログレストラッキング付きアップロード
                        try await UploadService.shared.upload(
                            file: preprocessed,
                            progress: { progress in
                                await send(.uploadProgress(fileId, progress))
                            }
                        )
                        
                        await send(.uploadCompleted(fileId))
                    },
                    catch: { error, send in
                        await send(.uploadFailed(fileId, error))
                    },
                    action: FileUploadAction(
                        file: file,
                        networkType: state.networkType,
                        availableStorage: state.availableStorage,
                        isPremium: state.isPremiumUser
                    ),
                    cancelID: CancelID.userAction
                )
                
            case let .uploadProgress(fileId, progress):
                state.uploadQueue[id: fileId]?.progress = progress
                return .none
                
            case let .uploadCompleted(fileId):
                state.uploadQueue[id: fileId]?.status = .completed
                
                // 次のファイルを自動開始
                if let nextFile = state.uploadQueue.first(where: { $0.status == .pending }) {
                    return .send(.startUpload(nextFile.id))
                }
                return .none
                
            case let .uploadFailed(fileId, _):
                state.uploadQueue[id: fileId]?.status = .failed
                return .none
            }
        }
    }
}
```

### 認証フローの複合制御

```swift
@Reducer
struct AuthenticationFeature {
    @ObservableState
    struct State {
        var currentStep: AuthStep = .initial
        var credentials: Credentials?
        var biometricAvailable = false
        var twoFactorRequired = false
        var sessionToken: String?
        
        enum AuthStep {
            case initial
            case credentials
            case biometric
            case twoFactor
            case completed
        }
    }
    
    enum Action {
        case startAuthentication
        case credentialsEntered(Credentials)
        case biometricRequested
        case twoFactorCodeEntered(String)
        case authenticationCompleted(SessionToken)
        case authenticationFailed(AuthError)
    }
    
    enum CancelID {
        case userAction
    }
    
    // 認証ステップごとの複合戦略
    enum AuthStepAction {
        case initialStep
        case credentialsStep(credentials: Credentials)
        case biometricStep(biometricAvailable: Bool)
        case twoFactorStep(credentials: Credentials)
        
        // 初期化ステップ：単一実行のみ
        struct InitialStepAction: LockmanSingleExecutionAction {
            let actionName = "auth_initial"
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                LockmanSingleExecutionInfo(
                    actionId: actionName,
                    mode: .boundary
                )
            }
        }
        
        // 認証情報ステップ：2つの戦略
        struct CredentialsStepAction: LockmanCompositeAction2 {
            typealias I1 = LockmanSingleExecutionInfo
            typealias S1 = LockmanSingleExecutionStrategy
            typealias I2 = LockmanDynamicConditionInfo
            typealias S2 = LockmanDynamicConditionStrategy
            
            let credentials: Credentials
            
            var strategyId: LockmanStrategyId {
                LockmanStrategyId(name: "CredentialsComposite")
            }
            
            var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
                LockmanCompositeInfo2(
                    actionId: "auth_credentials",
                    lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                        actionId: "authSingle",
                        mode: .boundary
                    ),
                    lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
                        actionId: "rateLimitCheck",
                        condition: {
                            let attempts = await AuthService.shared.getRecentAttempts()
                            return attempts < 5  // 5回まで
                        }
                    )
                )
            }
        }
        
        // 生体認証ステップ：3つの戦略
        struct BiometricStepAction: LockmanCompositeAction3 {
            typealias I1 = LockmanSingleExecutionInfo
            typealias S1 = LockmanSingleExecutionStrategy
            typealias I2 = LockmanPriorityBasedInfo
            typealias S2 = LockmanPriorityBasedStrategy
            typealias I3 = LockmanDynamicConditionInfo
            typealias S3 = LockmanDynamicConditionStrategy
            
            let biometricAvailable: Bool
            
            var strategyId: LockmanStrategyId {
                LockmanStrategyId(name: "BiometricComposite")
            }
            
            var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
                LockmanCompositeInfo3(
                    actionId: "auth_biometric",
                    lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                        actionId: "authSingle",
                        mode: .boundary
                    ),
                    lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                        actionId: "biometricPriority",
                        priority: .high(.exclusive)
                    ),
                    lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                        actionId: "biometricAvailable",
                        condition: { [biometricAvailable] in
                            biometricAvailable
                        }
                    )
                )
            }
        }
        
        // 2要素認証ステップ：3つの戦略
        struct TwoFactorStepAction: LockmanCompositeAction3 {
            typealias I1 = LockmanSingleExecutionInfo
            typealias S1 = LockmanSingleExecutionStrategy
            typealias I2 = LockmanGroupCoordinatedInfo
            typealias S2 = LockmanGroupCoordinatedStrategy
            typealias I3 = LockmanDynamicConditionInfo
            typealias S3 = LockmanDynamicConditionStrategy
            
            let credentials: Credentials
            
            var strategyId: LockmanStrategyId {
                LockmanStrategyId(name: "TwoFactorComposite")
            }
            
            var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
                LockmanCompositeInfo3(
                    actionId: "auth_twoFactor",
                    lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                        actionId: "authSingle",
                        mode: .boundary
                    ),
                    lockmanInfoForStrategy2: LockmanGroupCoordinatedInfo(
                        actionId: "twoFactorMember",
                        groupId: "authenticationFlow",
                        coordinationRole: .member
                    ),
                    lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                        actionId: "twoFactorTimeout",
                        condition: { [credentials] in
                            guard let loginTime = await AuthService.shared
                                .getLoginTime(for: credentials.username) else {
                                return false
                            }
                            
                            // 5分以内
                            return Date().timeIntervalSince(loginTime) < 300
                        }
                    )
                )
            }
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startAuthentication:
                state.currentStep = .credentials
                
                // 認証フロー開始（単一実行のみ）
                return .withLock(
                    operation: { send in
                        // 認証準備
                        await AuthService.shared.prepareAuthentication()
                    },
                    action: AuthStepAction.InitialStepAction(),
                    cancelID: CancelID.userAction
                )
                
            case let .credentialsEntered(credentials):
                state.credentials = credentials
                
                return .withLock(
                    operation: { send in
                        // 認証情報検証
                        let result = try await AuthService.shared.validateCredentials(credentials)
                        
                        if result.requiresBiometric && state.biometricAvailable {
                            state.currentStep = .biometric
                            await send(.biometricRequested)
                        } else if result.requiresTwoFactor {
                            state.currentStep = .twoFactor
                            state.twoFactorRequired = true
                        } else {
                            await send(.authenticationCompleted(result.token))
                        }
                    },
                    catch: { error, send in
                        await send(.authenticationFailed(error as? AuthError ?? .unknown))
                    },
                    action: AuthStepAction.CredentialsStepAction(
                        credentials: credentials
                    ),
                    cancelID: CancelID.userAction
                )
                
            case .biometricRequested:
                return .withLock(
                    operation: { send in
                        let biometricResult = try await BiometricService.shared.authenticate()
                        
                        if biometricResult.success {
                            if state.twoFactorRequired {
                                state.currentStep = .twoFactor
                            } else {
                                await send(.authenticationCompleted(biometricResult.token))
                            }
                        }
                    },
                    action: AuthStepAction.BiometricStepAction(
                        biometricAvailable: state.biometricAvailable
                    ),
                    cancelID: CancelID.userAction
                )
                
            case let .twoFactorCodeEntered(code):
                return .withLock(
                    operation: { [credentials = state.credentials] send in
                        let token = try await AuthService.shared.verifyTwoFactorCode(
                            code: code,
                            for: credentials!
                        )
                        await send(.authenticationCompleted(token))
                    },
                    action: AuthStepAction.TwoFactorStepAction(
                        credentials: state.credentials!
                    ),
                    cancelID: CancelID.userAction
                )
                
            case let .authenticationCompleted(token):
                state.sessionToken = token.value
                state.currentStep = .completed
                return .none
                
            case .authenticationFailed:
                // エラー処理
                return .none
            }
        }
    }
}
```

## 実用的なシナリオ

### マルチステップ認証フロー

```swift
// 認証ステップに応じて異なる戦略の組み合わせを使用
enum AuthStep {
    case initial
    case credentials
    case biometric
    case twoFactor
}

// 初期ステップ：2つの戦略
struct InitialAuthAction: LockmanCompositeAction2 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanDynamicConditionInfo
    typealias S2 = LockmanDynamicConditionStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "InitialAuthComposite")
    }
    
    var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
        LockmanCompositeInfo2(
            actionId: "authenticate_initial",
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "authSingle",
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
                actionId: "networkCheck",
                condition: {
                    await NetworkMonitor.shared.isConnected
                }
            )
        )
    }
}

// 2要素認証：3つの戦略
struct TwoFactorAuthAction: LockmanCompositeAction3 {
    typealias I1 = LockmanGroupCoordinatedInfo
    typealias S1 = LockmanGroupCoordinatedStrategy
    typealias I2 = LockmanDynamicConditionInfo
    typealias S2 = LockmanDynamicConditionStrategy
    typealias I3 = LockmanSingleExecutionInfo
    typealias S3 = LockmanSingleExecutionStrategy
    
    let username: String
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "TwoFactorComposite")
    }
    
    var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
        LockmanCompositeInfo3(
            actionId: "authenticate_twoFactor",
            lockmanInfoForStrategy1: LockmanGroupCoordinatedInfo(
                actionId: "twoFactorGroup",
                groupId: "authenticationFlow",
                coordinationRole: .member
            ),
            lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
                actionId: "timeoutCheck",
                condition: { [username] in
                    guard let loginTime = await AuthService.shared
                        .getLoginTime(for: username) else {
                        return false
                    }
                    return Date().timeIntervalSince(loginTime) < 300 // 5分
                }
            ),
            lockmanInfoForStrategy3: LockmanSingleExecutionInfo(
                actionId: "twoFactorSingle",
                mode: .action
            )
        )
    }
}

// CancelIDで境界を定義
enum CancelID {
    case userAction
}
```

### トランザクション処理

```swift
@Reducer
struct TransactionFeature {
    // 転送トランザクション：3つの戦略
    struct TransferAction: LockmanCompositeAction3 {
        typealias I1 = LockmanSingleExecutionInfo
        typealias S1 = LockmanSingleExecutionStrategy
        typealias I2 = LockmanPriorityBasedInfo
        typealias S2 = LockmanPriorityBasedStrategy
        typealias I3 = LockmanDynamicConditionInfo
        typealias S3 = LockmanDynamicConditionStrategy
        
        let amount: Decimal
        let accountId: String
        
        var strategyId: LockmanStrategyId {
            LockmanStrategyId(name: "TransferComposite")
        }
        
        var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
            LockmanCompositeInfo3(
                actionId: "transfer_\(accountId)",
                lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                    actionId: "transferSingle",
                    mode: .boundary
                ),
                lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                    actionId: "transferPriority",
                    priority: amount > 10000 ? .high(.exclusive) : .medium(.exclusive)
                ),
                lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                    actionId: "transferValidation",
                    condition: { [accountId, amount] in
                        // 残高チェック
                        let balance = await AccountService.shared.getBalance(accountId)
                        guard balance >= amount else { return false }
                        
                        // 限度額チェック
                        let limit = await AccountService.shared.getTransferLimit(accountId)
                        guard amount <= limit else { return false }
                        
                        // 不正検知
                        let fraudCheck = await FraudDetection.shared.analyzeTransfer(
                            accountId: accountId,
                            amount: amount
                        )
                        return fraudCheck.isLegitimate
                    }
                )
            )
        }
    }
    
    // 入出金トランザクション：2つの戦略
    struct DepositWithdrawalAction: LockmanCompositeAction2 {
        typealias I1 = LockmanPriorityBasedInfo
        typealias S1 = LockmanPriorityBasedStrategy
        typealias I2 = LockmanDynamicConditionInfo
        typealias S2 = LockmanDynamicConditionStrategy
        
        let transactionType: TransactionType
        let amount: Decimal
        let accountId: String
        
        var strategyId: LockmanStrategyId {
            LockmanStrategyId(name: "DepositWithdrawalComposite")
        }
        
        var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
            LockmanCompositeInfo2(
                actionId: "\(transactionType)_\(accountId)",
                lockmanInfoForStrategy1: LockmanPriorityBasedInfo(
                    actionId: "transactionPriority",
                    priority: amount > 10000 ? .high(.replaceable) : .low(.replaceable),
                    blocksSameAction: false
                ),
                lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
                    actionId: "transactionValidation",
                    condition: { [transactionType, accountId, amount] in
                        // 限度額チェック
                        let limit = await AccountService.shared.getLimit(
                            for: transactionType,
                            accountId: accountId
                        )
                        guard amount <= limit else { return false }
                        
                        // 営業時間チェック
                        let isBusinessHours = await BankingService.shared.isBusinessHours()
                        if amount > 50000 && !isBusinessHours {
                            return false
                        }
                        
                        return true
                    }
                )
            )
        }
    }
}
```

## 高度なパターン

### 動的な戦略構築

```swift
// コンテキストに応じて異なる戦略数を使用
struct ActionContext {
    let isUserInitiated: Bool
    let requiresNetworkValidation: Bool
    let groupId: String?
}

// 基本：単一実行のみ
struct BasicAdaptiveAction: LockmanSingleExecutionAction {
    let actionName = "adaptive"
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        LockmanSingleExecutionInfo(
            actionId: actionName,
            mode: .boundary
        )
    }
}

// ユーザー起動：2つの戦略
struct UserInitiatedAdaptiveAction: LockmanCompositeAction2 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "UserInitiatedAdaptive")
    }
    
    var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
        LockmanCompositeInfo2(
            actionId: "adaptive",
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "base",
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: "userPriority",
                priority: .high(.exclusive)
            )
        )
    }
}

// ネットワーク検証付き：3つの戦略
struct NetworkValidatedAdaptiveAction: LockmanCompositeAction3 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanDynamicConditionInfo
    typealias S3 = LockmanDynamicConditionStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "NetworkValidatedAdaptive")
    }
    
    var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
        LockmanCompositeInfo3(
            actionId: "adaptive",
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "base",
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: "userPriority",
                priority: .high(.exclusive)
            ),
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: "networkCheck",
                condition: {
                    await NetworkMonitor.shared.isConnected
                }
            )
        )
    }
}

// フル機能：4つの戦略
struct FullAdaptiveAction: LockmanCompositeAction4 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanDynamicConditionInfo
    typealias S3 = LockmanDynamicConditionStrategy
    typealias I4 = LockmanGroupCoordinatedInfo
    typealias S4 = LockmanGroupCoordinatedStrategy
    
    let groupId: String
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "FullAdaptive")
    }
    
    var lockmanInfo: LockmanCompositeInfo4<I1, I2, I3, I4> {
        LockmanCompositeInfo4(
            actionId: "adaptive",
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "base",
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: "userPriority",
                priority: .high(.exclusive)
            ),
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: "networkCheck",
                condition: {
                    await NetworkMonitor.shared.isConnected
                }
            ),
            lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
                actionId: "groupMember",
                groupId: groupId,
                coordinationRole: .member
            )
        )
    }
}
```

### マクロを使った実装の簡略化

```swift
// マクロを使用すると、型エイリアスやstrategyIdの生成が自動化される
@Reducer
struct OptimizedFeature {
    // 2つの戦略を組み合わせる場合
    @LockmanCompositeStrategy(
        LockmanSingleExecutionStrategy.self,
        LockmanPriorityBasedStrategy.self
    )
    enum Action {
        case performTask
        
        var lockmanInfo: LockmanCompositeInfo2<
            LockmanSingleExecutionInfo,
            LockmanPriorityBasedInfo
        > {
            LockmanCompositeInfo2(
                actionId: actionName,
                lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                    actionId: "single",
                    mode: .boundary
                ),
                lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                    actionId: "priority",
                    priority: .high(.exclusive)
                )
            )
        }
    }
}

// 5つの戦略を組み合わせる場合
@LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self,
    LockmanPriorityBasedStrategy.self,
    LockmanDynamicConditionStrategy.self,
    LockmanGroupCoordinatedStrategy.self,
    LockmanSingleExecutionStrategy.self
)
enum ComplexAction {
    case execute
    
    var lockmanInfo: LockmanCompositeInfo5<
        LockmanSingleExecutionInfo,
        LockmanPriorityBasedInfo,
        LockmanDynamicConditionInfo,
        LockmanGroupCoordinatedInfo,
        LockmanSingleExecutionInfo
    > {
        LockmanCompositeInfo5(
            actionId: actionName,
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "primary",
                mode: .boundary
            ),
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: "priority",
                priority: .high(.exclusive)
            ),
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: "condition",
                condition: {
                    await checkBusinessRules()
                }
            ),
            lockmanInfoForStrategy4: LockmanGroupCoordinatedInfo(
                actionId: "group",
                groupId: "workflow",
                coordinationRole: .leader
            ),
            lockmanInfoForStrategy5: LockmanSingleExecutionInfo(
                actionId: "secondary",
                mode: .action
            )
        )
    }
}
```

## ベストプラクティス

### 1. 戦略の順序

```swift
// ✅ 良い例：制限的な戦略を先に配置
struct OptimizedAction: LockmanCompositeAction3 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanDynamicConditionInfo
    typealias S3 = LockmanDynamicConditionStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "OptimizedComposite")
    }
    
    var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
        LockmanCompositeInfo3(
            actionId: "optimized",
            // 1. 最も制限的（高速チェック）
            lockmanInfoForStrategy1: LockmanSingleExecutionInfo(
                actionId: "single",
                mode: .boundary
            ),
            // 2. 中程度の制限
            lockmanInfoForStrategy2: LockmanPriorityBasedInfo(
                actionId: "priority",
                priority: .medium(.exclusive)
            ),
            // 3. 最も柔軟（コストが高い可能性）
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: "condition",
                condition: { await expensiveCheck() }
            )
        )
    }
}

// ❌ 悪い例：高コストな処理を先に配置
struct InefficientAction: LockmanCompositeAction2 {
    typealias I1 = LockmanDynamicConditionInfo
    typealias S1 = LockmanDynamicConditionStrategy
    typealias I2 = LockmanSingleExecutionInfo
    typealias S2 = LockmanSingleExecutionStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "InefficientComposite")
    }
    
    var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
        LockmanCompositeInfo2(
            actionId: "inefficient",
            // 高コストな処理を先に実行してしまう
            lockmanInfoForStrategy1: LockmanDynamicConditionInfo(
                actionId: "expensive",
                condition: { await veryExpensiveCheck() }
            ),
            // 単純なチェックが後回し
            lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
                actionId: "single",
                mode: .boundary
            )
        )
    }
}
```

### 2. パフォーマンス考慮

```swift
// 早期失敗のための最適化
struct PerformanceOptimizedAction: LockmanCompositeAction3 {
    typealias I1 = LockmanDynamicConditionInfo  // キャッシュ可能
    typealias S1 = LockmanDynamicConditionStrategy
    typealias I2 = LockmanDynamicConditionInfo  // ローカル
    typealias S2 = LockmanDynamicConditionStrategy
    typealias I3 = LockmanDynamicConditionInfo  // リモート
    typealias S3 = LockmanDynamicConditionStrategy
    
    var strategyId: LockmanStrategyId {
        LockmanStrategyId(name: "PerformanceOptimized")
    }
    
    var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
        LockmanCompositeInfo3(
            actionId: "optimized",
            // キャッシュ可能なチェックを先に
            lockmanInfoForStrategy1: LockmanDynamicConditionInfo(
                actionId: "cached",
                condition: {
                    // メモリキャッシュから即座に返答
                    return await CacheManager.shared.checkCachedPermission()
                }
            ),
            // ローカルチェック
            lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
                actionId: "local",
                condition: {
                    // ローカルデータベースやファイルシステムのチェック
                    return await LocalValidator.shared.validate()
                }
            ),
            // リモートチェック（最後）
            lockmanInfoForStrategy3: LockmanDynamicConditionInfo(
                actionId: "remote",
                condition: {
                    // ネットワークを使う高コストな処理
                    return await RemoteValidator.shared.validate()
                }
            )
        )
    }
}
```

### 3. エラー処理の統一

```swift
// 各戦略のエラーを適切に処理
return .withLock(
    operation: { send in
        // 成功処理
    },
    catch: { error, send in
        switch error {
        case LockmanError.strategyFailed(let strategy):
            // 戦略別のエラーハンドリング
            logger.error("Strategy \(strategy) failed")
            
        case is CancellationError:
            // キャンセル処理
            await send(.operationCancelled)
            
        default:
            // その他のエラー
            await send(.operationFailed(error))
        }
    },
    action: compositeAction,
    cancelID: cancelID
)
```

## 次のステップ

- <doc:Debugging> - 複合戦略のデバッグ方法