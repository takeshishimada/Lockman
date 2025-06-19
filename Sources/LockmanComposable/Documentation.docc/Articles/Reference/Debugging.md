# Debugging

Lockmanのデバッグ機能を使用してロック状態を監視・分析する方法

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

Lockmanは、非同期アクションの排他制御をデバッグするための組み込み機能を提供しています。これらの機能により、ロックの取得・解放の流れを追跡し、予期しない動作の原因を特定できます。

## デバッグログの有効化

### Lockman.debug.isLoggingEnabled

デバッグログを有効にすると、すべての`canLock`操作とその結果が自動的にログ出力されます。

```swift
#if DEBUG
// デバッグビルドでのみログを有効化
Lockman.debug.isLoggingEnabled = true
#endif
```

#### ログ出力の例

ログが有効な状態で`withLock`を実行すると、以下のような出力が得られます：

```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: mainScreen, Info: LockmanSingleExecutionInfo(actionId: "fetchData", uniqueId: 123e4567-e89b-12d3-a456-426614174000, mode: .boundary)

❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: mainScreen, Info: LockmanSingleExecutionInfo(actionId: "fetchData", uniqueId: 987f6543-a21b-34c5-d678-123456789012, mode: .boundary), Reason: Lock already held

⚠️ [Lockman] canLock succeeded with cancellation - Strategy: PriorityBased, BoundaryId: payment, Info: LockmanPriorityBasedInfo(actionId: "urgentPayment", priority: .high(.exclusive)), Cancelled: 'normalPayment' (uniqueId: abc12345-6789-def0-1234-567890abcdef)
```

### ログの意味

- **✅ 成功**: ロックの取得に成功
- **❌ 失敗**: ロックの取得に失敗（既存のロックがあるなど）
- **⚠️ キャンセルを伴う成功**: 優先度の高いアクションが低優先度のアクションをキャンセル

## 現在のロック状態の確認

### Lockman.debug.printCurrentLocks()

アプリケーション内のすべてのアクティブなロックを表形式で表示します。

```swift
// 基本的な使用方法
Lockman.debug.printCurrentLocks()

// フォーマットオプションを指定
Lockman.debug.printCurrentLocks(options: .compact)  // 狭い画面用
Lockman.debug.printCurrentLocks(options: .detailed) // 詳細表示
```

#### 出力例

```
┌──────────────────┬────────────┬──────────────────────────────────────┬───────────────────┐
│ Strategy         │ BoundaryId │ ActionId/UniqueId                    │ Additional Info   │
├──────────────────┼────────────┼──────────────────────────────────────┼───────────────────┤
│ SingleExecution  │ mainScreen │ fetchData                            │ mode: .boundary   │
│                  │            │ 123e4567-e89b-12d3-a456-426614174000 │                   │
├──────────────────┼────────────┼──────────────────────────────────────┼───────────────────┤
│ PriorityBased    │ payment    │ processPayment                       │ priority: .high   │
│                  │            │ 987f6543-a21b-34c5-d678-123456789012 │ b: .exclusive     │
└──────────────────┴────────────┴──────────────────────────────────────┴───────────────────┘
```

#### 表示される情報

- **Strategy**: 使用されている戦略（SingleExecution、PriorityBasedなど）
- **BoundaryId**: ロックの境界識別子（CancelIDなど）
- **ActionId/UniqueId**: アクションの識別子とユニークID
- **Additional Info**: 戦略固有の追加情報
  - SingleExecution: `mode`（.boundaryまたは.action）
  - PriorityBased: `priority`と`behavior`
  - DynamicCondition: `condition: <closure>`
  - GroupCoordination: `groups`と`coordinationRole`

### フォーマットオプション

```swift
// デフォルト: バランスの取れた表示
Lockman.debug.printCurrentLocks(options: .default)

// コンパクト: 狭い画面向け（列幅制限なし）
Lockman.debug.printCurrentLocks(options: .compact)

// 詳細: より多くの情報を表示
Lockman.debug.printCurrentLocks(options: .detailed)
```

## トラブルシューティング

### ロックが解放されない場合

```swift
// デバッグ手順
1. Lockman.debug.printCurrentLocks() を実行
2. 該当するActionIdとBoundaryIdを確認
3. ログを有効にして操作を再実行
4. ログから失敗の原因を特定
```

### 期待したアクションが実行されない場合

```swift
// ログを有効にして原因を調査
Lockman.debug.isLoggingEnabled = true

// アクションを実行
store.send(.myAction)

// ログを確認：
// ❌ [Lockman] canLock failed - ... Reason: Lock already held
// → 既存のロックが原因
```


## 次のステップ

- <doc:QuickStart> - 基本的な使い方を確認
- <doc:SingleExecution> - 最も一般的な戦略の詳細
- <doc:PriorityBased> - 優先度ベースの制御について
