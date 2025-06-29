# ConcurrencyLimitedStrategy

Limit the number of concurrent executions.

## Overview

ConcurrencyLimitedStrategyは、同時実行数を制限する戦略です。指定した数まで同時実行を許可し、制限を超える場合は実行を拒否することで、リソース使用量の制御とパフォーマンスの最適化を実現します。

この戦略は、ネットワークリクエストやファイル処理など、リソース消費の大きい処理の並行度制御に使用されます。

## 同時実行制限システム

### 制限タイプ

**unlimited** - 制限なし

```swift
LockmanConcurrencyLimitedInfo(
    actionId: "backgroundTask",
    concurrencyId: "background",
    limit: .unlimited
)
```

- 同時実行数に制限を設けない
- 一時的に制限を無効化したい場合に使用
- デバッグやテスト時の動作確認に適用

**limited** - 数値制限

```swift
LockmanConcurrencyLimitedInfo(
    actionId: "download",
    concurrencyId: "downloads", 
    limit: .limited(3)
)
```

- 指定した数まで同時実行を許可
- 制限を超える処理は拒否される
- リソース保護とパフォーマンス最適化

### 同時実行グループ

同じ`concurrencyId`を持つ処理が同一グループとして管理され、グループ単位で同時実行数が制限されます。

```swift
// 同じグループ「downloads」として管理
LockmanConcurrencyLimitedInfo(
    actionId: "downloadImage",
    concurrencyId: "downloads",
    limit: .limited(3)
)

LockmanConcurrencyLimitedInfo(
    actionId: "downloadVideo", 
    concurrencyId: "downloads",
    limit: .limited(3)
)
```

## 使用方法

### 基本的な使用例

```swift
@LockmanConcurrencyLimited
enum Action {
    case downloadFile(URL)
    case uploadFile(URL)
    case processImage(UIImage)
    
    var lockmanInfo: LockmanConcurrencyLimitedInfo {
        switch self {
        case .downloadFile:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "network",
                limit: .limited(3)
            )
        case .uploadFile:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "network", 
                limit: .limited(3)
            )
        case .processImage:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "imageProcessing",
                limit: .limited(2)
            )
        }
    }
}
```

### グループ別制限設定

```swift
// ネットワーク関連: 最大3つまで
LockmanConcurrencyLimitedInfo(
    actionId: "apiCall",
    concurrencyId: "network",
    limit: .limited(3)
)

// 画像処理: 最大2つまで  
LockmanConcurrencyLimitedInfo(
    actionId: "imageResize",
    concurrencyId: "imageProcessing", 
    limit: .limited(2)
)

// バックグラウンドタスク: 制限なし
LockmanConcurrencyLimitedInfo(
    actionId: "logging",
    concurrencyId: "background",
    limit: .unlimited
)
```

## 動作例

### 制限による実行制御

```
制限数: 3
同時実行グループ: "downloads"

時刻: 0秒  - download1要求 → ✅ 実行 (1/3)
時刻: 1秒  - download2要求 → ✅ 実行 (2/3)  
時刻: 2秒  - download3要求 → ✅ 実行 (3/3)
時刻: 3秒  - download4要求 → ❌ 拒否 (制限到達)
時刻: 4秒  - download1完了 → ✅ 完了 (2/3)
時刻: 5秒  - download5要求 → ✅ 実行 (3/3)
```

### 異なるグループでの独立制御

```
ネットワークグループ (制限: 3)
時刻: 0秒  - api1実行, api2実行, api3実行 → ✅ (3/3)
時刻: 1秒  - api4要求 → ❌ 拒否

画像処理グループ (制限: 2)  
時刻: 0秒  - resize1実行, resize2実行 → ✅ (2/2)
時刻: 1秒  - resize3要求 → ❌ 拒否

※ 異なるグループは独立して制御される
```

## エラーハンドリング

ConcurrencyLimitedStrategyで発生する可能性のあるエラーと、その対処法については[Error Handling](<doc:ErrorHandling>)ページの共通パターンも参照してください。

### LockmanConcurrencyLimitedError

**concurrencyLimitReached** - 同時実行制限に到達
- `requestedInfo`: 実行要求された処理の情報
- `existingInfos`: 現在実行中の処理一覧  
- `current`: 現在の同時実行数

```swift
lockFailure: { error, send in
    if case .concurrencyLimitReached(let requestedInfo, let existingInfos, let current) = error as? LockmanConcurrencyLimitedError {
        send(.concurrencyLimitReached(
            "同時実行制限に到達しました (\(current)/\(requestedInfo.limit))"
        ))
    }
}
```

