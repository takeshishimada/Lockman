# Custom Strategy Implementation

独自の戦略を実装してLockmanを拡張する方法

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

Lockmanは5つの組み込み戦略を提供していますが、特殊なビジネスロジックや要件に対応するために独自の戦略を実装することができます。この記事では、カスタム戦略の実装方法とベストプラクティスを解説します。

## 前提知識

カスタム戦略の実装には、Lockmanのプロトコル階層の理解が必要です。詳細は<doc:LockmanProtocols>を参照してください。

## 実装すべき要素

カスタム戦略を作成するには、以下の3つの要素を実装する必要があります：

1. **Info型**（`LockmanInfo`プロトコルに準拠）
   - `actionId`: ロック競合検出用の識別子
   - `uniqueId`: インスタンスの一意識別子
   - カスタムプロパティ（戦略固有のパラメータ）

2. **Strategy型**（`LockmanStrategy`プロトコルに準拠）
   - `canLock`: ロック可能かチェック（状態を変更しない）
   - `lock`: 実際にロックを取得
   - `unlock`: ロックを解放

3. **Action型**（`LockmanAction`プロトコルに準拠）
   - `lockmanInfo`: 戦略に渡すInfo型のインスタンス
   - `strategyId`: カスタム戦略のID

## 実装例：営業時間制限戦略

営業時間内のみアクションを許可する戦略を実装してみましょう。

### Step 1: カスタムエラーの定義

```swift
extension LockmanError {
    static let outsideBusinessHours = LockmanError("outside_business_hours")
}
```

### Step 2: Info型の実装

```swift
struct BusinessHoursInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let allowedHours: ClosedRange<Int>  // 例: 9...18
    let allowedDays: Set<Int>  // 1=日曜...7=土曜
    let timezone: TimeZone
    
    init(actionId: String, allowedHours: ClosedRange<Int>, allowedDays: Set<Int>, timezone: TimeZone = .current) {
        self.actionId = LockmanActionId(actionId)
        self.allowedHours = allowedHours
        self.allowedDays = allowedDays
        self.timezone = timezone
    }
    
    var debugDescription: String {
        "BusinessHours(\(actionId), hours: \(allowedHours), days: \(allowedDays))"
    }
}

```

### Step 3: Strategy型の実装

```swift
final class BusinessHoursStrategy: LockmanStrategy {
    func canLock(info: some LockmanInfo) -> LockResult {
        guard let bhInfo = info as? BusinessHoursInfo else {
            return .failure()
        }
        
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = bhInfo.timezone
        
        let components = calendar.dateComponents([.weekday, .hour], from: now)
        
        // 曜日チェック（1=日曜...7=土曜）
        if let weekday = components.weekday,
           !bhInfo.allowedDays.contains(weekday) {
            return .failure()
        }
        
        // 時間チェック
        if let hour = components.hour,
           !bhInfo.allowedHours.contains(hour) {
            return .failure()
        }
        
        return .success
    }
    
    func lock(info: some LockmanInfo) -> LockResult {
        // 時間帯制限戦略では、canLockと同じチェックを行う
        return canLock(info: info)
    }
    
    func unlock(info: some LockmanInfo) -> LockResult {
        // 時間帯制限は状態を持たないため、常に成功
        return .success
    }
}

```

### Step 4: Action型の実装

```swift
enum BusinessAction: LockmanAction {
    case submitOrder
    case processPayment
    case updateInventory
    
    var lockmanInfo: BusinessHoursInfo {
        BusinessHoursInfo(
            actionId: "\(self)",
            allowedHours: 9...18,
            allowedDays: [2, 3, 4, 5, 6], // 月曜〜金曜
            timezone: .current
        )
    }
    
    var strategyId: LockmanStrategyId {
        .custom("businessHours")
    }
}
```

### Step 5: 戦略の登録

```swift
// App.swift または初期化コード
let lockman = Lockman.shared
lockman.registerStrategy(
    id: .custom("businessHours"),
    strategy: BusinessHoursStrategy()
)
```

### Step 6: TCAでの使用

```swift
@Reducer
struct OrderFeature {
    enum CancelID {
        case submitOrder
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .submitOrderTapped:
                return .withLock(
                    action: BusinessAction.submitOrder,
                    cancelID: CancelID.submitOrder
                ) {
                    // 営業時間内のみ実行される
                    try await submitOrder()
                }
                .catch { error in
                    // エラーハンドリング
                    if error.localizedDescription.contains("outside_business_hours") {
                        print("営業時間外です")
                    }
                    return .none
                }
            }
        }
    }
}
```

## ベストプラクティス

### 1. エラー処理

カスタムエラーは意味のある名前を使用し、エラーメッセージで判別できるようにします：

```swift
extension LockmanError {
    static let quotaExceeded = LockmanError("quota_exceeded")
    static let maintenanceMode = LockmanError("maintenance_mode")
}
```

### 2. 戦略IDの命名

カスタム戦略IDは、他の戦略と競合しないよう明確な名前を使用します：

```swift
// 良い例
.custom("com.myapp.businessHours")
.custom("rateLimiter_v2")

// 避けるべき例
.custom("strategy1")
.custom("custom")
```

### 3. 状態の管理

戦略が状態を持つ場合は、Lockmanが提供する`LockmanState`を使用します：

```swift
final class StatefulStrategy: LockmanStrategy {
    // LockmanStateでスレッドセーフな状態管理
    private let state = LockmanState<YourCustomInfo>()
    
    func canLock(info: some LockmanInfo) -> LockResult {
        // state.contains() - アクションの存在確認（O(1)）
        // state.count() - アクション数の取得（O(1)）
        // state.currents() - 現在のロック一覧取得
        return .success
    }
    
    func lock(info: some LockmanInfo) -> LockResult {
        // state.add() - ロック情報を追加
        return .success
    }
    
    func unlock(info: some LockmanInfo) -> LockResult {
        // state.remove() - ロック情報を削除
        return .success
    }
}
```

`LockmanState`の主要メソッド：
- `add(id:info:)` - ロック情報を追加
- `remove(id:info:)` - ロック情報を削除
- `contains(id:actionId:)` - 特定アクションの存在確認（O(1)）
- `count(id:actionId:)` - 特定アクションの数を取得（O(1)）
- `currents(id:)` - 境界内の全ロック情報を取得

> Note: 詳細な実装例は[Lockman Examples](https://github.com/kabiroberai/Lockman/tree/main/Examples)を参照してください。

## 次のステップ

- <doc:LockmanProtocols> - プロトコル階層の詳細
- <doc:Composite> - 複数の戦略を組み合わせる方法
- <doc:Debugging> - カスタム戦略のデバッグ方法
