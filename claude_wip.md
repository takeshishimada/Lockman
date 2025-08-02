# Lockman テスト戦略・設計 Work in Progress

## 🎯 概要

このドキュメントは、Lockmanライブラリのテスト体系刷新における設計プロセスと詳細な検討内容を記録しています。

**設計期間**: 2025年1月  
**目的**: 排他制御ライブラリとして求められる高い品質基準を満たすテスト体系の構築  
**課題**: 既存テストの重複、カバレッジ不足、並行性テストの欠如  

---

## 📋 設計完了項目

### ✅ 1. テスト方針の策定

#### 排他制御ライブラリとしての品質要件
- **Safety (安全性)**: データ競合・競合状態の完全排除
- **Liveness (活性)**: デッドロック・ライブロックの防止
- **Correctness (正確性)**: 排他制御の論理的正確性
- **Exception Safety (例外安全性)**: エラー時の状態整合性保証

#### 品質基準
```
Quality Gates:
├── Code Coverage: 95%以上
├── Branch Coverage: 90%以上  
├── Concurrency Tests: 全パス
├── Memory Leak Tests: 0 leaks
├── Performance Regression: ±5%以内
└── Integration Tests: 全パス
```

### ✅ 2. テストタイプの体系化

#### 4層テストピラミッド
```
Tests/
├── Unit/                    # 単体テスト (70%)
├── Integration/            # 統合テスト (20%)  
├── Concurrency/            # 並行性テスト (7%)
└── Performance/            # 性能テスト (3%)
```

#### テストタイプ詳細
| タイプ | 責務 | 実行頻度 | カバレッジ目標 |
|--------|------|----------|---------------|
| Unit | 個別機能の正確性 | CI毎 | 95% |
| Integration | コンポーネント連携 | CI毎 | 90% |
| Concurrency | 並行安全性 | CI毎 | 100% (Critical Path) |
| StateManagement | 状態整合性 | CI毎 | 95% |
| ErrorHandling | 異常時安全性 | CI毎 | 90% |
| Performance | 性能要件 | Nightly | 100% (Metrics) |
| Stress | 極限状況安定性 | Weekly | 90% |

### ✅ 3. ディレクトリ構成設計

#### Sources構造対応
現在のSources構造に完全対応した階層設計：

```
Tests/
├── LockmanTests/                       # メインテストスイート
│   ├── Unit/                          # 単体テスト
│   │   ├── Core/                      # コア機能
│   │   ├── Strategies/                # 戦略別
│   │   └── Composable/                # TCA統合
│   ├── Integration/                   # 統合テスト
│   ├── Concurrency/                   # 並行性テスト
│   ├── StateManagement/               # 状態管理テスト
│   └── ErrorHandling/                 # エラーハンドリングテスト
├── LockmanMacrosTests/                # マクロテスト
├── LockmanPerformanceTests/           # 性能テスト
├── LockmanStressTests/                # ストレステスト
└── LockmanTestSupport/                # テスト支援
```

### ✅ 4. 実行順序と依存関係

#### CI実行フェーズ
```
Phase 1: Foundation Tests (3-5分)
├── Unit Tests (並列実行)
└── 失敗時即座停止

Phase 2: Integration Tests (5-8分)  
├── Unit完了後実行
└── 部分並列実行

Phase 3: Critical Safety Tests (8-12分)
├── Concurrency Tests (順次実行)
└── 最重要：排他制御の核心

Phase 4: State & Error Tests (6-10分)
├── StateManagement + ErrorHandling
└── 並列実行可能
```

#### 依存関係マップ
- Unit/Core → Integration/StrategyIntegration
- Unit/Strategies → Concurrency/RaceConditions  
- Integration/All → StateManagement/Cleanup
- StateManagement/All → ErrorHandling/ExceptionSafety

### ✅ 5. 命名規則とファイル組織

#### ファイル命名パターン
```
{Component}{TestType}Tests.swift

例:
- LockmanSingleExecutionStrategyTests.swift (単体)
- StrategyContainerIntegrationTests.swift (統合)
- LockRaceConditionTests.swift (並行性)
```

#### テストメソッド命名
```
test{Component}_{Scenario}_{ExpectedResult}()

例:
- testSingleExecution_DuplicateLock_ShouldFail()
- testPriorityBased_HighPriorityOverride_ShouldSucceedWithCancellation()
```

---

## 🚀 実装優先順位

### Phase 1: テストインフラ構築 (Week 1-2)
1. **LockmanTestSupport/** の作成
   - TestFixtures.swift - 統一Mock/Stub定義
   - ConcurrencyTestHelpers.swift - 並行性テスト支援
   - LockmanAssertions.swift - カスタムアサーション

2. **CI/CD基盤整備**
   - GitHub Actions ワークフロー
   - 段階的実行とレポート機能

### Phase 2: 重要度順テスト実装 (Week 3-6)
1. **Concurrency Tests (最優先)**
   - 競合状態検出・防止
   - デッドロック防止
   - 高負荷安定性

2. **Unit Tests (コア機能)**
   - 各Strategy個別動作
   - Core機能単体動作

3. **Integration Tests**  
   - Strategy ↔ Container連携
   - TCA ↔ Lockman統合

### Phase 3: 性能・品質保証 (Week 7-8)
1. **Performance Tests**
   - スループット・レイテンシ測定
   - メモリリーク検出

2. **Stress Tests**
   - 長期安定性検証
   - 極限負荷テスト

---

## 🔍 重要な設計判断

### 1. Swift 5系サポート維持
**判断**: 既存XCTestインフラを継続使用  
**理由**: Swift 5.9, 5.10, 6.0サポートのため新フレームワーク導入リスク回避

### 2. 並行性テストの重視
**判断**: 独立カテゴリとして最優先配置  
**理由**: 排他制御ライブラリの核心機能、致命的バグ防止

### 3. 実行頻度による分離
**判断**: CI毎 / Nightly / Weekly の3段階実行  
**理由**: CI実行時間短縮とリソース効率化

### 4. Sources構造完全対応
**判断**: Sources階層と1:1対応のテスト構造  
**理由**: 保守性向上、新機能追加時の影響最小化

---

## 📊 期待される効果

### 品質向上
- **競合状態の完全検出**: 並行性テストによる安全性保証
- **カバレッジ向上**: 95%以上の包括的テスト
- **回帰防止**: 自動化された性能・品質監視

### 開発効率向上  
- **保守性向上**: 統一された構造・命名規則
- **デバッグ効率**: 明確な責務分割とエラー分離
- **新機能開発**: テンプレート化による高速テスト作成

### CI/CD効率化
- **実行時間短縮**: 22-35分の効率的実行
- **失敗時影響最小化**: 段階的実行による早期発見
- **リソース最適化**: 並列実行とリソース制御

---

## ⚠️ 実装時の注意点

### 1. 開発ルール（重要）
- **既存テストファイル変更禁止**: 既存のテストコードは一切変更しない
- **新旧両方テスト可能**: 開発中は新旧両方の実装がテストできる状態を維持
- **既存テストディレクトリにファイル作成禁止**: 将来の移行準備のため既存ディレクトリは触らない
- **新規テストディレクトリ使用**: 新しいテスト実装は別ディレクトリで行う
- **最終移行時のみクリーンアップ**: 既存テストコードの削除は新実装完了・検証後のみ

### 2. 並行性テストの難しさ
- **非決定論的動作**: タイミング依存の問題
- **対策**: TaskCoordinator, SynchronizationBarrierの活用

### 3. CI実行時間管理
- **目標**: 35分以内の完了
- **対策**: 段階的失敗時停止、リソース制御

### 4. テスト間の分離
- **課題**: テスト間の状態汚染
- **対策**: 各テストでの完全なクリーンアップ

### 5. メモリリーク検出
- **課題**: 非同期処理でのリーク検出困難
- **対策**: 専用ツールと長期実行テスト

---

## 🔮 将来の拡張計画

### 1. プロパティベーステスト
- QuickCheck スタイルのランダムテスト
- 不変条件の自動検証

### 2. Chaos Engineering
- 障害注入による復旧力テスト
- 実運用環境シミュレーション

### 3. AI支援テスト生成
- コード変更に応じた自動テスト生成
- 網羅性向上支援

### 4. 実運用監視連携
- 本番環境メトリクスとの連携
- 性能回帰の早期検出

---

## 📚 参考資料・ベストプラクティス

### 排他制御テストの参考
- [The Art of Multiprocessor Programming](https://www.amazon.com/Art-Multiprocessor-Programming-Revised-Reprint/dp/0123973376)
- [Java Concurrency in Practice](https://www.amazon.com/Java-Concurrency-Practice-Brian-Goetz/dp/0321349601)

### Swift テストベストプラクティス
- [Swift.org Testing Guidelines](https://swift.org/contributing/#testing)
- [XCTest Best Practices](https://developer.apple.com/documentation/xctest)

### TCA テスト戦略
- [The Composable Architecture Testing](https://pointfreeco.github.io/swift-composable-architecture/main/documentation/composablearchitecture/testing)

---

*このドキュメントは継続的に更新され、実装の進行に合わせて詳細化されます。*