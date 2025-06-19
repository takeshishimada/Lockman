# Single Execution Strategy

最も基本的な戦略：一度に1つのアクションのみ実行を許可

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`SingleExecutionStrategy`は、同じアクションまたは境界内で一度に1つの処理のみ実行を許可する戦略です。

## 実行モード

SingleExecutionStrategyは3つの実行モードをサポートしています：

### .boundary モード

CancelID（境界）内で一度に1つのアクションのみ実行：

> Note: 境界の設計原則については、<doc:CancelIDAndBoundaries>を参照してください。

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

### .action モード

同じactionIdを持つアクションのみブロック：

```swift
var lockmanInfo: LockmanSingleExecutionInfo {
    .init(mode: .action)  // アクション単位で制御
}

// fetchとsaveは並行実行可能（異なるactionId）
// 同じfetchの重複実行のみ防ぐ
```

### .none モード

特定のアクションを他の戦略で制御する場合など

```swift
var lockmanInfo: LockmanSingleExecutionInfo {
    .init(mode: .none)  // 制御なし
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
                actionId: "\(actionName)_\(documentId)",  // ドキュメントごとに別ID
                mode: .boundary
            )
        case .delete(let documentId):
            return .init(
                actionId: "\(actionName)_\(documentId)",
                mode: .boundary
            )
        }
    }
}

```

## 次のステップ

- <doc:EffectWithLock> - withLock APIの詳細な使い方
- <doc:PriorityBased> - 優先度ベースの制御
- <doc:UnlockOptions> - アンロックタイミングの詳細
