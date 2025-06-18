# Lockman Protocols

Lockmanのプロトコル階層と、それぞれの役割について詳しく説明します。

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
}

## 概要

Lockmanは、シンプルで拡張可能なプロトコル階層を採用しています。各プロトコルは明確な責任を持ち、型安全で柔軟な排他制御を実現します。

> Note: この記事では、Lockmanの内部プロトコル構造について説明します。TCAとの統合において、通常はマクロや`withLock`メソッドを通じて間接的にこれらのプロトコルを使用します。内部動作を理解したい場合や、カスタム戦略を実装する場合に参考にしてください。

## プロトコル階層

### LockmanInfo

最も基本的なプロトコルで、ロック情報の最小要件を定義します：

```swift
public protocol LockmanInfo: Sendable, CustomDebugStringConvertible {
    var actionId: LockmanActionId { get }
    var uniqueId: UUID { get }
}
```

#### 必須プロパティ

- **actionId**: ロック競合検出に使用される主要な識別子
- **uniqueId**: インスタンスごとの一意な識別子（通常は自動生成）

#### 実装例

```swift
// 基本的な実装
struct BasicInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    
    init(actionId: String) {
        self.actionId = LockmanActionId(actionId)
    }
}

// 戦略固有の実装
struct SingleExecutionInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let mode: ExecutionMode  // 戦略固有のプロパティ
}
```

### LockmanAction

Info と戦略を結びつけるプロトコルです：

```swift
public protocol LockmanAction: Sendable {
    associatedtype I: LockmanInfo
    var lockmanInfo: I { get }
    var strategyId: LockmanStrategyId { get }
}
```

#### 必須要素

- **I**: 使用する`LockmanInfo`の具体的な型
- **lockmanInfo**: ロック情報のインスタンス
- **strategyId**: 使用する戦略の識別子

#### TCAでの実装例

```swift
// マクロを使用した実装（推奨）
@LockmanSingleExecution
enum ViewAction {
    case buttonTapped
    
    // 自動生成されるactionNameを使用
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: actionName, mode: .boundary)
    }
}

// TCAのReducerでの使用
return .withLock(
    action: ViewAction.buttonTapped,
    cancelID: CancelID.userAction
)
```

### LockmanStrategy

戦略の基本インターフェースを定義：

```swift
public protocol LockmanStrategy: Sendable {
    func canLock(info: some LockmanInfo) -> LockmanResult
    func lock(info: some LockmanInfo) -> LockmanResult
    func unlock(info: some LockmanInfo) -> LockmanResult
}
```

#### 主要メソッド

- **canLock**: ロック可能かチェック（状態を変更しない）
- **lock**: 実際にロックを取得
- **unlock**: ロックを解放

> Note: TCAとの統合では、これらのメソッドは`withLock`内で自動的に呼び出されます。

## 戦略固有のInfo型

### SingleExecutionInfo

```swift
public struct LockmanSingleExecutionInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId: UUID
    let mode: ExecutionMode
}
```

### PriorityBasedInfo

```swift
public struct LockmanPriorityBasedInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId: UUID
    let priority: LockmanPriorityLevel
    let concurrency: LockmanConcurrency
    let blocksSameAction: Bool
    let allowsPreemption: Bool
}
```

### GroupCoordinatedInfo

```swift
public struct LockmanGroupCoordinatedInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId: UUID
    let groupIds: [LockmanGroupId]
    let role: LockmanGroupRole
}
```

### DynamicConditionInfo

```swift
public struct LockmanDynamicConditionInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId: UUID
    let condition: @Sendable () async -> Bool
}
```

## プロトコルの拡張性

### カスタムInfo型の作成

```swift
struct CustomInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    
    // カスタムプロパティ
    let customProperty: String
    let timestamp: Date
    
    init(actionId: String, customProperty: String) {
        self.actionId = LockmanActionId(actionId)
        self.customProperty = customProperty
        self.timestamp = Date()
    }
}
```

### カスタム戦略の作成

```swift
class CustomStrategy: LockmanStrategy {
    func canLock(info: some LockmanInfo) -> LockmanResult {
        // カスタムロジック
        if let customInfo = info as? CustomInfo {
            // customPropertyに基づく判定
            return customInfo.customProperty == "allowed" ? .success : .failure(.blocked)
        }
        return .failure(.strategyNotFound)
    }
    
    func lock(info: some LockmanInfo) -> LockmanResult {
        // ロック取得ロジック
        return .success
    }
    
    func unlock(info: some LockmanInfo) -> LockmanResult {
        // アンロックロジック
        return .success
    }
}
```

## LockmanBoundaryId

`LockmanBoundaryId`はシンプルな型エイリアスです：

```swift
public typealias LockmanBoundaryId = Hashable & Sendable
```

### TCAでの使用

TCAでは`CancelID`がこの役割を果たします：

```swift
// 一般的なCancelIDの定義
enum CancelID {
    case userProfile
    case dataSync
    case chat(roomId: String)
}

// CancelIDはHashableとSendableに自動的に準拠するので
// LockmanBoundaryIdとして使用可能
return .withLock(
    action: myAction,
    cancelID: CancelID.userAction  // LockmanBoundaryIdとして機能
)
```

### 境界の役割

1. **Effectのキャンセル識別**: TCAの標準機能
2. **排他制御のスコープ**: SingleExecutionStrategyの`.boundary`モードで使用
3. **独立した制御空間**: 異なるCancelIDは互いに影響しない

> Important: TCAでは、`CancelID`がLockmanの境界として自動的に機能します。これにより、キャンセル処理と排他制御が一貫して管理されます。

## 型の関係図

```
LockmanInfo (プロトコル)
    ├── LockmanSingleExecutionInfo
    ├── LockmanPriorityBasedInfo
    ├── LockmanGroupCoordinatedInfo
    ├── LockmanDynamicConditionInfo
    └── カスタムInfo型

LockmanAction (プロトコル)
    ├── @LockmanSingleExecution付きenum
    ├── @LockmanPriorityBased付きenum
    └── 手動実装のstruct/enum

LockmanStrategy (プロトコル)
    ├── LockmanSingleExecutionStrategy
    ├── LockmanPriorityBasedStrategy
    ├── LockmanGroupCoordinationStrategy
    ├── LockmanDynamicConditionStrategy
    ├── LockmanCompositeStrategy
    └── カスタム戦略

LockmanBoundaryId (型エイリアス)
    └── TCAのCancelID (enum)
```

## ベストプラクティス

### 1. Info型の設計

```swift
// 良い例：明確で拡張可能
struct DocumentLockInfo: LockmanInfo {
    let actionId: LockmanActionId
    let uniqueId = UUID()
    let documentId: String
    let operation: DocumentOperation
    
    init(documentId: String, operation: DocumentOperation) {
        self.documentId = documentId
        self.operation = operation
        self.actionId = LockmanActionId("\(operation)_\(documentId)")
    }
}

enum DocumentOperation: String {
    case read, write, delete
}
```

### 2. プロトコル準拠の活用

```swift
// プロトコル準拠を利用した汎用関数
func logLockInfo<T: LockmanInfo>(_ info: T) {
    print("Locking action: \(info.actionId)")
    print("Instance: \(info.uniqueId)")
}
```

### 3. 型安全性の確保

```swift
// 型安全な戦略選択
extension LockmanStrategyId {
    static func forInfo<T: LockmanInfo>(_ info: T) -> LockmanStrategyId {
        switch info {
        case is LockmanSingleExecutionInfo:
            return .singleExecution
        case is LockmanPriorityBasedInfo:
            return .priorityBased
        default:
            return .custom("default")
        }
    }
}
```

## 次のステップ

- <doc:CustomStrategy> - カスタム戦略の実装方法