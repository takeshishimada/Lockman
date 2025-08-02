# Lockman Tests

Lockmanライブラリの包括的なテストスイート。排他制御ライブラリとして求められる高い品質基準を満たすテスト体系を提供します。

## 🎯 テスト構成

### テスト実行頻度
- **CI毎実行**: Unit, Integration, Concurrency, StateManagement, ErrorHandling
- **Nightly実行**: Performance  
- **Weekly実行**: Stress

### ディレクトリ構成

```
Tests/
├── LockmanTests/                       # メインテストスイート (CI毎実行)
│   ├── Unit/                          # 単体テスト
│   │   ├── Core/                      # コア機能テスト
│   │   ├── Strategies/                # 戦略別テスト
│   │   └── Composable/                # TCA統合テスト
│   ├── Integration/                   # 統合テスト
│   │   ├── StrategyIntegration/       # 戦略統合
│   │   ├── TCAIntegration/            # TCA統合
│   │   ├── MacroIntegration/          # マクロ統合
│   │   └── SystemIntegration/         # システム統合
│   ├── Concurrency/                   # 並行性テスト
│   │   ├── RaceConditions/            # 競合状態
│   │   ├── DeadlockPrevention/        # デッドロック防止
│   │   ├── HighConcurrency/           # 高並行性
│   │   ├── Synchronization/           # 同期プリミティブ
│   │   └── TimingDependency/          # タイミング依存
│   ├── StateManagement/               # 状態管理テスト
│   │   ├── StateTransition/           # 状態遷移
│   │   ├── Lifecycle/                 # ライフサイクル
│   │   ├── Cleanup/                   # クリーンアップ
│   │   └── Invariants/                # 不変条件
│   └── ErrorHandling/                 # エラーハンドリングテスト
│       ├── ExceptionSafety/           # 例外安全性
│       ├── ErrorPropagation/          # エラー伝播
│       ├── FailureRecovery/           # 障害復旧
│       └── EdgeCases/                 # エッジケース
├── LockmanMacrosTests/                # マクロテスト
├── LockmanPerformanceTests/           # 性能テスト (Nightly実行)
├── LockmanStressTests/                # ストレステスト (Weekly実行)
└── LockmanTestSupport/                # テスト支援ライブラリ
    ├── Fixtures/                      # 共通フィクスチャ
    ├── Helpers/                       # ヘルパー関数
    ├── Assertions/                    # カスタムアサーション
    ├── Coordinators/                  # テスト調整
    ├── Instrumentation/               # 計測・監視
    └── Simulation/                    # シミュレーション
```

## 🚀 テスト実行方法

### 基本実行コマンド

```bash
# 全テスト実行
swift test

# カテゴリ別実行
swift test --filter LockmanTests/Unit
swift test --filter LockmanTests/Integration
swift test --filter LockmanTests/Concurrency
swift test --filter LockmanTests/StateManagement
swift test --filter LockmanTests/ErrorHandling

# 性能・ストレステスト
swift test --filter LockmanPerformanceTests
swift test --filter LockmanStressTests

# 特定戦略のテスト
swift test --filter SingleExecution
swift test --filter PriorityBased
swift test --filter ConcurrencyLimited
```

### macOS推奨実行コマンド
```bash
xcodebuild test \
  -configuration Debug \
  -scheme "Lockman" \
  -destination "platform=macOS,name=My Mac" \
  -workspace .github/package.xcworkspace \
  -skipMacroValidation
```

### iOS実行コマンド  
```bash
# Makefileを使用（推奨）
make xcodebuild

# 直接実行（シミュレータを指定）
xcodebuild test \
  -configuration Debug \
  -scheme "Lockman" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -workspace .github/package.xcworkspace \
  -skipMacroValidation
```

## 📋 新しいテストの追加ガイド

### 1. テストファイルの配置

```
{Component}{TestType}Tests.swift

例:
├── LockmanSingleExecutionStrategyTests.swift     # 単体テスト
├── StrategyContainerIntegrationTests.swift       # 統合テスト  
├── LockRaceConditionTests.swift                  # 並行性テスト
└── LockThroughputPerformanceTests.swift          # 性能テスト
```

### 2. テストクラスの構造

```swift
import XCTest
@testable import Lockman

/// {Component}の{TestType}テスト
///
/// ## テストカバレッジ
/// - 基本機能
/// - エラーハンドリング  
/// - エッジケース
final class LockmanSingleExecutionStrategyTests: XCTestCase {
    
    // MARK: - Properties
    private var strategy: LockmanSingleExecutionStrategy!
    
    // MARK: - Setup & Teardown
    override func setUp() async throws {
        await super.setUp()
        strategy = LockmanSingleExecutionStrategy()
    }
    
    override func tearDown() async throws {
        strategy = nil
        await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    func testBasicOperation_ValidInput_ShouldSucceed() {
        // テスト実装
    }
    
    // MARK: - Error Handling Tests  
    func testErrorCondition_InvalidInput_ShouldFail() {
        // テスト実装
    }
}
```

### 3. テストメソッドの命名

```swift
// パターン: test{Component}_{Scenario}_{ExpectedResult}()

func testSingleExecution_DuplicateLock_ShouldFail()
func testPriorityBased_HighPriorityOverride_ShouldSucceedWithCancellation()
func testConcurrencyLimited_ExceedLimit_ShouldQueue()
```

### 4. 並行性テストの作成

```swift
func testConcurrentOperation_MultipleThreads_MaintainsConsistency() async {
    await withTaskGroup(of: LockmanResult.self) { group in
        for i in 0..<100 {
            group.addTask {
                return strategy.attemptLock(boundaryId: "test", info: createInfo("\(i)"))
            }
        }
        
        // 結果の整合性を検証
        var results: [LockmanResult] = []
        for await result in group {
            results.append(result)
        }
        
        // アサーション
        XCTAssertEqual(results.filter { $0 == .success }.count, 1)
    }
}
```

## 🔧 CI/CD統合

### GitHub Actions設定

```yaml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-latest
    strategy:
      matrix:
        swift-version: [5.9, 5.10, 6.0]
    steps:
      - uses: actions/checkout@v4
      - name: Run Unit Tests
        run: swift test --filter LockmanTests/Unit
        
  integration-tests:
    needs: unit-tests
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Integration Tests  
        run: swift test --filter LockmanTests/Integration
        
  concurrency-tests:
    needs: integration-tests
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run Concurrency Tests
        run: swift test --filter LockmanTests/Concurrency
```

### 品質ゲート

```bash
# コードフォーマット
make format

# テスト実行（必須）
swift test --filter LockmanTests

# 性能テスト（Nightly）
swift test --filter LockmanPerformanceTests

# カバレッジレポート生成
swift test --enable-code-coverage
```

## 📊 テスト品質メトリクス

### カバレッジ目標

| テストタイプ | Line Coverage | Branch Coverage | 重要度 |
|-------------|---------------|-----------------|--------|
| Unit | 95% | 90% | Critical |
| Integration | 90% | 85% | High |
| Concurrency | 100% | 100% | Critical |
| StateManagement | 95% | 90% | High |
| ErrorHandling | 90% | 85% | High |

### 性能要件

| メトリクス | 目標値 | 測定方法 |
|-----------|--------|----------|
| Lock Throughput | >10,000 ops/sec | PerformanceTests |
| Lock Latency (P99) | <1ms | PerformanceTests |
| Memory Baseline | <1MB | MemoryTests |
| Memory Leaks | 0 leaks | LeakDetectionTests |

## 🛠️ テスト支援ツール

### LockmanTestSupport

```swift
import LockmanTestSupport

// 統一フィクスチャ
let testBoundary = TestBoundaryIds.standard
let testStrategy = TestStrategies.singleExecution

// カスタムアサーション
XCTAssertLockSuccess(result)
XCTAssertLockFailure(result)
XCTAssertStateConsistent(strategy.currentState)

// 並行性テストヘルパー
await ConcurrencyTestHelpers.runConcurrentOperations(count: 100) { index in
    strategy.attemptLock(boundaryId: testBoundary, info: createInfo("\(index)"))
}

// 性能測定
let metrics = await PerformanceTestHelpers.measureThroughput {
    strategy.lock(boundaryId: testBoundary, info: testInfo)
    strategy.unlock(boundaryId: testBoundary, info: testInfo)
}
```

## 🐛 トラブルシューティング

### よくある問題

#### 1. 並行性テストが不安定
```swift
// 問題: タイミング依存で結果が変わる
// 解決: TaskCoordinatorを使用した決定論的テスト
await TaskCoordinator.synchronizedExecution {
    // テストコード
}
```

#### 2. メモリリークの検出
```bash
# Instrumentsを使用したリーク検出
xcodebuild test -enableAddressSanitizer YES
```

#### 3. CI実行時間の長期化
```bash
# 段階的実行で早期失敗
swift test --filter "LockmanTests/Unit" --fail-fast
```

#### 4. テスト間の状態汚染
```swift
// 各テストでの完全クリーンアップ
override func tearDown() async throws {
    strategy?.cleanUp()
    LockmanManager.cleanup.all()
    await super.tearDown()
}
```

## 📚 参考資料

- **設計詳細**: [claude_wip.md](../claude_wip.md) - 詳細な設計プロセスと検討内容
- **実装ガイド**: [CLAUDE.md](../CLAUDE.md) - 開発ガイドライン
- **API仕様**: [Documentation.docc](../Sources/Lockman/Documentation.docc/) - API仕様書

## 🤝 コントリビューション

新しいテストを追加する際は：

1. **適切なディレクトリに配置**
2. **命名規則に従う** 
3. **テストドキュメンテーションを追加**
4. **CI実行時間に配慮**
5. **並行性安全性を検証**

質問や提案がある場合は、GitHubのIssueまたはDiscussionをご利用ください。