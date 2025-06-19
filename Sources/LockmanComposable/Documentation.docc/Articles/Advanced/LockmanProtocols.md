# Lockman Protocols

Lockmanのプロトコル階層と、それぞれの役割について詳しく説明します。

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
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


### LockmanStrategy

戦略の基本インターフェースを定義：

```swift
public protocol LockmanStrategy: Sendable {
    func canLock(info: some LockmanInfo) -> LockResult
    func lock(info: some LockmanInfo) -> LockResult
    func unlock(info: some LockmanInfo) -> LockResult
}
```

#### 主要メソッド

- **canLock**: ロック可能かチェック（状態を変更しない）
- **lock**: 実際にロックを取得
- **unlock**: ロックを解放

> Note: TCAとの統合では、これらのメソッドは`withLock`内で自動的に呼び出されます。



## LockmanBoundaryId

境界を識別するための型エイリアスです：

```swift
public typealias LockmanBoundaryId = Hashable & Sendable
```

この型は、Lockmanがロックの範囲（境界）を識別するために使用します。TCAでは`CancelID`がこの要件を満たすため、追加の型定義なしに使用できます。

> Note: 境界の設計原則と使い方については、<doc:CancelIDAndBoundaries>を参照してください。

## 型の関係図

```
┌─────────────────────────────────────────────────────────────┐
│                     Lockmanの型階層                          │
└─────────────────────────────────────────────────────────────┘

【プロトコル層】
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│ LockmanInfo  │◀───│LockmanAction │───▶│ LockmanStrategy  │
└──────────────┘    └──────────────┘    └──────────────────┘
       △                    △                      △
       │                    │                      │
【実装層】              【TCAアクション】        【戦略実装】
       │                    │                      │
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│SingleExecInfo│    │ @Lockman〜   │    │SingleExecStrategy│
│PriorityInfo  │    │ 付きのenum   │    │PriorityStrategy  │
│GroupInfo     │    │              │    │GroupStrategy     │
│DynamicInfo   │    │              │    │DynamicStrategy   │
│カスタムInfo  │    │              │    │CompositeStrategy │
└──────────────┘    └──────────────┘    └──────────────────┘

【境界識別子】
┌────────────────────────┐
│ LockmanBoundaryId      │ ← TCAのCancelIDが準拠
│ (Hashable & Sendable)  │
└────────────────────────┘

関係性：
• LockmanAction は LockmanInfo を保持 (lockmanInfo プロパティ)
• LockmanAction は使用する LockmanStrategy を指定 (strategyId プロパティ)
• LockmanStrategy は LockmanInfo を受け取って動作する
• すべての操作は LockmanBoundaryId によってスコープ化される
```


## 次のステップ

- <doc:CustomStrategy> - カスタム戦略の実装方法
- <doc:QuickStart> - 基本的な使い方
- <doc:SingleExecution> - 組み込み戦略の例
