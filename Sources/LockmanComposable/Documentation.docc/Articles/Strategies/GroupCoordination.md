# Group Coordination Strategy

関連するアクションをグループとして協調制御する戦略

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`GroupCoordinationStrategy`は、複数の関連するアクションをグループとして管理し、リーダー/メンバーの役割に基づいて実行を制御する戦略です。

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

## 次のステップ

- <doc:EffectWithLock> - withLock APIの詳細な使い方
- <doc:DynamicCondition> - 条件付き実行の制御
- <doc:Composite> - グループ協調と他の戦略の組み合わせ
