# Custom Strategy Implementation

独自の戦略を実装してLockmanを拡張する方法

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

Lockmanは5つの組み込み戦略を提供していますが、特殊なビジネスロジックや要件に対応するために独自の戦略を実装することができます。この記事では、カスタム戦略の実装方法とベストプラクティスを解説します。

## なぜカスタム戦略が必要か

### 既存戦略でカバーできないケース

- **複雑なレート制限**: API呼び出しの頻度を時間窓で制御
- **リトライロジック**: 失敗時の自動リトライと指数バックオフ
- **外部システム連携**: 外部のロックサービスとの統合
- **ビジネス固有のルール**: 営業時間、承認フローなど

## 必要なプロトコル

### LockmanStrategy プロトコル

すべてのカスタム戦略は`LockmanStrategy`プロトコルに準拠する必要があります：

```swift
public protocol LockmanStrategy: Sendable {
    func canLock(info: some LockmanInfo) -> LockmanResult
    func lock(info: some LockmanInfo) -> LockmanResult
    func unlock(info: some LockmanInfo) -> LockmanResult
}
```

各メソッドの役割：
- **canLock**: ロック可能かチェック（状態を変更しない）
- **lock**: 実際にロックを取得
- **unlock**: ロックを解放

### LockmanInfo プロトコル

カスタム戦略用の情報型を定義：

```swift
public protocol LockmanInfo: Sendable, CustomDebugStringConvertible {
    var actionId: LockmanActionId { get }
    var uniqueId: UUID { get }
}
```

## 基本的な実装例

### シンプルなレート制限戦略

```swift
// 1. Info型の定義
struct RateLimitInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let maxRequests: Int
    let timeWindow: TimeInterval
    
    var debugDescription: String {
        "RateLimit(\(actionId): \(maxRequests) per \(timeWindow)s)"
    }
}

// 2. 戦略の実装
actor RateLimitStrategy: LockmanStrategy {
    private var requestHistory: [LockmanActionId: [Date]] = [:]
    
    func canLock(info: some LockmanInfo) -> LockmanResult {
        guard let rateLimitInfo = info as? RateLimitInfo else {
            return .failure(.invalidInfo)
        }
        
        let now = Date()
        let history = requestHistory[rateLimitInfo.actionId, default: []]
        
        // 時間窓内のリクエスト数をカウント
        let recentRequests = history.filter { requestTime in
            now.timeIntervalSince(requestTime) < rateLimitInfo.timeWindow
        }
        
        if recentRequests.count >= rateLimitInfo.maxRequests {
            return .failure(.rateLimitExceeded)
        }
        
        return .success
    }
    
    func lock(info: some LockmanInfo) -> LockmanResult {
        guard let rateLimitInfo = info as? RateLimitInfo else {
            return .failure(.invalidInfo)
        }
        
        // リクエスト履歴に追加
        var history = requestHistory[rateLimitInfo.actionId, default: []]
        history.append(Date())
        
        // 古い履歴を削除
        let cutoff = Date().addingTimeInterval(-rateLimitInfo.timeWindow * 2)
        history.removeAll { $0 < cutoff }
        
        requestHistory[rateLimitInfo.actionId] = history
        return .success
    }
    
    func unlock(info: some LockmanInfo) -> LockmanResult {
        // レート制限ではアンロック不要
        return .success
    }
}

// 3. 戦略の登録
extension LockmanStrategyId {
    static let rateLimit = LockmanStrategyId("rateLimit")
}

// 初期化時に登録
LockmanContainer.shared.registerStrategy(
    RateLimitStrategy(),
    for: .rateLimit
)
```

## TCAでの使用方法

### Action定義

```swift
// レート制限付きアクション
struct APICallAction: LockmanAction {
    let endpoint: String
    
    var lockmanInfo: RateLimitInfo {
        RateLimitInfo(
            actionId: "api_\(endpoint)",
            maxRequests: 10,
            timeWindow: 60  // 1分間に10リクエストまで
        )
    }
    
    let strategyId = LockmanStrategyId.rateLimit
}

// Reducerでの使用
case .fetchUserData:
    return .withLock(
        operation: { send in
            let userData = try await api.fetchUser()
            await send(.userDataReceived(userData))
        },
        action: APICallAction(endpoint: "users"),
        cancelID: CancelID.userAction
    )
```

## 高度な実装例

### リトライ可能な戦略

```swift
// リトライ設定を持つInfo型
struct RetryableInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let maxRetries: Int
    let backoffStrategy: BackoffStrategy
    
    enum BackoffStrategy {
        case constant(TimeInterval)
        case exponential(base: TimeInterval, multiplier: Double)
        case custom((Int) -> TimeInterval)
    }
    
    var debugDescription: String {
        "Retryable(\(actionId): max \(maxRetries) retries)"
    }
}

// リトライ管理戦略
actor RetryableStrategy: LockmanStrategy {
    private var retryCount: [LockmanActionId: Int] = [:]
    private var lastAttempt: [LockmanActionId: Date] = [:]
    
    func canLock(info: some LockmanInfo) -> LockmanResult {
        guard let retryInfo = info as? RetryableInfo else {
            return .failure(.invalidInfo)
        }
        
        let currentRetries = retryCount[retryInfo.actionId, default: 0]
        
        // リトライ上限チェック
        if currentRetries >= retryInfo.maxRetries {
            return .failure(.maxRetriesExceeded)
        }
        
        // バックオフ時間チェック
        if let lastTime = lastAttempt[retryInfo.actionId] {
            let backoffTime = calculateBackoff(
                retryInfo.backoffStrategy,
                attempt: currentRetries
            )
            
            if Date().timeIntervalSince(lastTime) < backoffTime {
                return .failure(.inBackoffPeriod)
            }
        }
        
        return .success
    }
    
    func lock(info: some LockmanInfo) -> LockmanResult {
        guard let retryInfo = info as? RetryableInfo else {
            return .failure(.invalidInfo)
        }
        
        retryCount[retryInfo.actionId, default: 0] += 1
        lastAttempt[retryInfo.actionId] = Date()
        
        return .success
    }
    
    func unlock(info: some LockmanInfo) -> LockmanResult {
        guard let retryInfo = info as? RetryableInfo else {
            return .failure(.invalidInfo)
        }
        
        // 成功時はカウントをリセット
        retryCount[retryInfo.actionId] = 0
        lastAttempt[retryInfo.actionId] = nil
        
        return .success
    }
    
    private func calculateBackoff(
        _ strategy: RetryableInfo.BackoffStrategy,
        attempt: Int
    ) -> TimeInterval {
        switch strategy {
        case .constant(let interval):
            return interval
        case .exponential(let base, let multiplier):
            return base * pow(multiplier, Double(attempt))
        case .custom(let calculator):
            return calculator(attempt)
        }
    }
}
```

### 時間帯制限戦略

```swift
// 営業時間チェック戦略
struct BusinessHoursInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let allowedHours: ClosedRange<Int>  // 例: 9...18
    let allowedDays: Set<Int>  // 1=日曜...7=土曜
    let timezone: TimeZone
    
    var debugDescription: String {
        "BusinessHours(\(actionId))"
    }
}

actor BusinessHoursStrategy: LockmanStrategy {
    func canLock(info: some LockmanInfo) -> LockmanResult {
        guard let bhInfo = info as? BusinessHoursInfo else {
            return .failure(.invalidInfo)
        }
        
        let now = Date()
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            in: bhInfo.timezone,
            from: now
        )
        
        // 曜日チェック
        if let weekday = components.weekday,
           !bhInfo.allowedDays.contains(weekday) {
            return .failure(.outsideBusinessHours)
        }
        
        // 時間チェック
        if let hour = components.hour,
           !bhInfo.allowedHours.contains(hour) {
            return .failure(.outsideBusinessHours)
        }
        
        return .success
    }
    
    func lock(info: some LockmanInfo) -> LockmanResult {
        // 時間帯制限は状態を持たない
        return .success
    }
    
    func unlock(info: some LockmanInfo) -> LockmanResult {
        return .success
    }
}

## ベストプラクティス

### 1. 状態管理

```swift
// ✅ 良い例：Actorで安全に状態を管理
actor StatefulStrategy: LockmanStrategy {
    private var state: [String: Any] = [:]
    
    func updateState(key: String, value: Any) {
        state[key] = value
    }
}

// ❌ 悪い例：非安全な状態管理
class UnsafeStrategy: LockmanStrategy {
    var state: [String: Any] = [:]  // 競合状態の可能性
}
```

### 2. エラーハンドリング

```swift
enum CustomLockmanError: Error {
    case rateLimitExceeded
    case invalidInfo
    case outsideBusinessHours
    case maxRetriesExceeded
    case inBackoffPeriod
}

// LockmanResultでエラーを返す
func canLock(info: some LockmanInfo) -> LockmanResult {
    guard let customInfo = info as? CustomInfo else {
        return .failure(.invalidInfo)
    }
    
    // カスタムロジック
    if !checkCondition(customInfo) {
        return .failure(.customError(CustomLockmanError.conditionNotMet))
    }
    
    return .success
}
```

### 3. パフォーマンス考慮

```swift
actor EfficientStrategy: LockmanStrategy {
    // インデックスを使用して高速検索
    private var actionIndex: [LockmanActionId: Set<UUID>] = [:]
    
    // 定期的なクリーンアップ
    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-3600)
        // 古いエントリを削除
    }
}
```

## テストとデバッグ

### カスタム戦略のテスト

```swift
@MainActor
final class CustomStrategyTests: XCTestCase {
    func testRateLimitStrategy() async throws {
        let strategy = RateLimitStrategy()
        
        let info = RateLimitInfo(
            actionId: "test",
            maxRequests: 2,
            timeWindow: 1.0
        )
        
        // 最初の2つは成功
        XCTAssertEqual(await strategy.canLock(info: info), .success)
        XCTAssertEqual(await strategy.lock(info: info), .success)
        
        XCTAssertEqual(await strategy.canLock(info: info), .success)
        XCTAssertEqual(await strategy.lock(info: info), .success)
        
        // 3つ目は失敗
        XCTAssertEqual(
            await strategy.canLock(info: info),
            .failure(.rateLimitExceeded)
        )
        
        // 1秒待機後は成功
        try await Task.sleep(for: .seconds(1.1))
        XCTAssertEqual(await strategy.canLock(info: info), .success)
    }
}
```

### デバッグヘルパー

```swift
extension LockmanStrategy {
    // デバッグ用の状態出力
    func debugState() async -> String {
        "Strategy: \(Self.self)"
    }
}

// 使用例
#if DEBUG
let state = await strategy.debugState()
print("Current state: \(state)")
#endif
```

## まとめ

カスタム戦略実装のポイント：

1. **必要なプロトコルに準拠**（LockmanStrategy, LockmanInfo）
2. **Actorを使用した安全な状態管理**
3. **適切なエラーハンドリング**
4. **TCAとの統合を考慮した設計**
5. **テスタブルな実装**

これらのガイドラインに従うことで、Lockmanの柔軟性を活かしたカスタム戦略を実装できます。

## 実装例のリポジトリ

より多くのカスタム戦略の実装例は、[Lockman Examples](https://github.com/kabiroberai/Lockman/tree/main/Examples)を参照してください。

## 次のステップ

- <doc:LockmanProtocols> - プロトコル階層の詳細
- <doc:Debugging> - カスタム戦略のデバッグ方法