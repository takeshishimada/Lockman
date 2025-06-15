# Lockman パフォーマンスベンチマークレポート

## エグゼクティブサマリー

本ライブラリでは、基本的な操作と100個の並行アクションを使用した高負荷バーストシナリオの両方を含む包括的なパフォーマンスベンチマークを実施しました。測定結果は、異なる戦略と様々な負荷条件下でのパフォーマンス特性を示しています。

## ベンチマーク構成

### テスト環境
- **プラットフォーム**: macOS, Darwin Kernel Version 24.3.0
- **アーキテクチャ**: arm64 (Apple Silicon M3 Max)
- **プロセッサ**: 14コア
- **メモリ**: 36 GB
- **測定日**: 2025年6月15日

### テストシナリオ

#### 1. 基本パフォーマンステスト
- 最小負荷での単一アクション実行
- ベースラインに対する4つの戦略すべての比較

#### 2. バーストロードテスト（新規）
- **並行アクション数**: 100個の同時アクション
- **競合パターン**: 中程度の競合（10種類のアクションタイプ × 各10インスタンス）
- **作業シミュレーション**: アクションごとに5-10msのランダム遅延
- **優先度分布**（PriorityBasedのみ）:
  - High (exclusive): 20%
  - Low (replaceable): 50%
  - None: 30%

## パフォーマンス結果

### 📊 基本操作パフォーマンス（中央値）

| 戦略 | Wall Clock Time | ベースライン比 | スループット | 命令数 | メモリ |
|------|-----------------|----------------|--------------|--------|--------|
| **.run (ベースライン)** | 16μs | - | 62K ops/s | 207K | 12MB |
| **SingleExecution** | 13μs | -18.8% ⚡ | 79K ops/s | 134K | 13MB |
| **PriorityBased** | 13μs | -18.8% ⚡ | 78K ops/s | 132K | 13MB |
| **DynamicCondition** | 32μs | +100% | 31K ops/s | 590K | 12MB |
| **CompositeStrategy** | 33μs | +106% | 31K ops/s | 596K | 12MB |

### 🚀 バーストロードパフォーマンス（100並行アクション）

| メトリック | SingleExecution | PriorityBased | 比率 |
|-----------|-----------------|---------------|------|
| **Wall Clock Time（中央値）** | 537μs | 15ms | 28倍高速 |
| **スループット** | 1,863 ops/s | 68 ops/s | 27倍高い |
| **総CPU時間** | 801μs | 8,266μs | 10倍少ない |
| **メモリ割り当て** | 954バイト | 39KB | 41倍少ない |
| **ピークメモリ** | 14MB | 23MB | 1.6倍少ない |

### 📈 レイテンシ分布分析

#### SingleExecutionバースト（マイクロ秒）
```
パーセンタイル: p50    p75    p90    p99    p100
Wall Clock:     537    545    557    613    9,278
```

#### PriorityBasedバースト（ミリ秒）
```
パーセンタイル: p50    p75    p90    p99    p100
Wall Clock:     15     15     15     16     16
```

## パフォーマンス測定結果

### 1. **高負荷下でのSingleExecution**
- 100個の並行アクションを**0.5ms**で処理
- 線形スケーラビリティを示す
- メモリフットプリント：<1KB

### 2. **PriorityBasedのパフォーマンス**
- SingleExecutionより28倍遅い
- 100アクションの処理時間：15ms
- メモリ使用量：39KB（優先度キュー管理）

### 3. **競合処理**
- **中程度の競合シナリオ**（10タイプ × 10インスタンス）：
  - SingleExecution：最小限のロック競合を観測
  - PriorityBased：設計通りに優先度競合を解決

### 4. **スケーラビリティの洞察**
- **SingleExecution**：ほぼ線形スケーリング
  - 単一アクション：13μs
  - 100アクション：537μs（アクションあたり5.4μsに償却）
  
- **PriorityBased**：キュー管理による準線形スケーリング
  - 単一アクション：13μs
  - 100アクション：15ms（アクションあたり150μsに償却）

## 戦略別パフォーマンス特性

### 🎖️ SingleExecution

**測定パフォーマンス**
- 並行負荷下でのパフォーマンス：0.5ms/100アクション
- メモリフットプリント：<1KB
- レイテンシ分布：p50=537μs、p99=613μs
- スケーリング：線形

**特性**
- 優先度制御なし
- FIFO順序

**バーストロード結果**
- 100アクション：0.5ms
- メモリ：合計<1KB
- CPU時間：801μs

### 🏆 PriorityBased

**測定パフォーマンス**
- 並行負荷下でのパフォーマンス：15ms/100アクション
- メモリフットプリント：39KB
- レイテンシ分布：p50=15ms、p99=16ms
- CPU時間：8,266μs

**特性**
- 優先度ベースの実行制御
- 優先度キュースケジューリング
- 優先度逆転防止

**SingleExecutionとの比較**
- 高負荷下で28倍遅い
- 41倍のメモリ使用量

### 🔧 DynamicCondition

**測定パフォーマンス**
- Wall Clock Time：32μs（ベースラインの2倍）
- メモリ割り当て：0バイト
- 命令数：590K

**特性**
- ランタイム条件評価
- 条件付き実行ロジック

### 🔗 CompositeStrategy

**測定パフォーマンス**
- Wall Clock Time：33μs（ベースラインの2.06倍）
- メモリ：12MB
- 命令数：596K

**特性**
- 複数の戦略を組み合わせ
- 設定可能な戦略構成

## 使用例

### 高頻度操作
```swift
// SingleExecutionは79K ops/sで測定
@LockmanSingleExecution
enum Action {
    case processRequest(id: String)
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: "process-\(id)", mode: .boundary)
    }
}
```

### 優先度ベースシステム
```swift
// 優先度制御を持つPriorityBased
@LockmanPriorityBased
enum Action {
    case urgentTask
    case backgroundTask
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .urgentTask:
            return .init(actionId: actionName, priority: .high(.exclusive))
        case .backgroundTask:
            return .init(actionId: actionName, priority: .low(.replaceable))
        }
    }
}
```

### 負荷パターン設定
```swift
// 測定されたパフォーマンスに基づく設定
if expectedConcurrency > 50 && !needsPriority {
    // SingleExecution：100アクションを0.5ms
    useSingleExecutionStrategy()
} else if needsPriorityControl {
    // PriorityBased：100アクションを15ms
    usePriorityBasedStrategy()
}
```

## パフォーマンスリファレンス

### レイテンシ測定（100アクション）

| 戦略 | 測定レイテンシ | スループット |
|------|----------------|------------|
| SingleExecution | 537μs | 1,863 ops/s |
| PriorityBased | 15ms | 68 ops/s |
| DynamicCondition | バースト未測定 | 31K ops/s（単一） |
| CompositeStrategy | バースト未測定 | 31K ops/s（単一） |

### メモリ使用量

| 戦略 | 100アクションあたりメモリ | ピークメモリ |
|------|------------------------|-------------|
| SingleExecution | 954バイト | 14MB |
| PriorityBased | 39KB | 23MB |
| DynamicCondition | 0バイト（割り当て） | 12MB |
| CompositeStrategy | 未測定 | 12MB |

## ベンチマーク方法論

### テスト実装
- 正確な測定のためにSwift Benchmarkパッケージを使用しています
- 複数の反復でウォームアップを実施しています
- パーセンタイル（p50、p75、p90、p99、p100）を測定しています
- 隔離されたテスト環境で実行しています

### バーストテスト設計
```swift
// 中程度の競合を持つ100個の並行アクション
await withTaskGroup(of: Void.self) { group in
    for i in 0..<100 {
        let actionId = i / 10  // アクションタイプごとに10インスタンス
        group.addTask {
            await store.send(.burst(id: actionId)).finish()
        }
    }
}
```

### 統計的信頼性
- サンプルサイズ：テストあたり68-9,134回の反復
- 複数の実行で一貫した結果
- 外れ値検出のためのパーセンタイル分析

## サマリー

以下のパフォーマンス特性が測定されました：

1. **SingleExecution**は100個の並行アクションを0.5msで処理し、メモリ使用量は<1KBです。

2. **PriorityBased**は100個の並行アクションを15msで処理し、メモリ使用量は39KBで、優先度ベースの実行制御を提供します。

3. **基本操作**はSingleExecutionとPriorityBasedがベースラインより18.8%高速に動作します。

4. **スケーラビリティ**測定では、SingleExecutionが線形スケーリング、PriorityBasedが準線形スケーリングを示しました。

### ユースケースリファレンス

| ユースケース | 戦略 | 測定パフォーマンス |
|----------|------|---------------------|
| 高頻度操作 | SingleExecution | 0.5ms/100操作 |
| 条件付き実行 | DynamicCondition | 32μs/操作 |
| 優先度ベースキューイング | PriorityBased | 15ms/100操作 |
| 統合戦略 | CompositeStrategy | 33μs/操作 |

---

*ベンチマークは2025年6月15日、macOS 24.3.0上でLockman v1.0を使用して実施*