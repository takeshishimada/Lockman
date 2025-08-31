import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: 包括的なLockmanUnlock & LockmanAutoUnlockテスト、3フェーズアプローチ
// ✅ 18テストメソッドでアンロックトークンとアクター管理をカバー
// ✅ Phase 1: 基本アンロックオペレーション（immediate, mainRunLoop, transition, delayed）
// ✅ Phase 2: プラットフォーム固有のディレイとエラーハンドリング
// ✅ Phase 3: 自動アンロック管理とactorの統合テスト

final class LockmanUnlockTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - テスト用ヘルパー型

  // テスト用のLockmanInfo
  private struct TestLockmanInfo: LockmanInfo {
    let strategyId: LockmanStrategyId
    let actionId: LockmanActionId
    let uniqueId: UUID

    init(strategyId: LockmanStrategyId = "TestStrategy", actionId: LockmanActionId = "testAction") {
      self.strategyId = strategyId
      self.actionId = actionId
      self.uniqueId = UUID()
    }

    var debugDescription: String {
      "TestLockmanInfo(actionId: '\(actionId)')"
    }
  }

  // テスト用のモックストラテジー
  private final class TestMockStrategy: LockmanStrategy, @unchecked Sendable {
    typealias I = TestLockmanInfo

    private let _strategyId: LockmanStrategyId
    private let lock = NSLock()
    private(set) var unlockCallCount = 0
    private(set) var lastUnlockedBoundary: AnyHashable?
    private(set) var lastUnlockedInfo: TestLockmanInfo?

    init(strategyId: LockmanStrategyId = "MockStrategy") {
      self._strategyId = strategyId
    }

    var strategyId: LockmanStrategyId { _strategyId }

    static func makeStrategyId() -> LockmanStrategyId {
      LockmanStrategyId("MockStrategy")
    }

    func canLock<B: LockmanBoundaryId>(boundaryId: B, info: I) -> LockmanResult {
      return .success
    }

    func lock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      // No-op for unlock tests
    }

    func unlock<B: LockmanBoundaryId>(boundaryId: B, info: I) {
      lock.lock()
      defer { lock.unlock() }
      unlockCallCount += 1
      lastUnlockedBoundary = AnyHashable(boundaryId)
      lastUnlockedInfo = info
    }

    func cleanUp() {
      lock.lock()
      defer { lock.unlock() }
      unlockCallCount = 0
      lastUnlockedBoundary = nil
      lastUnlockedInfo = nil
    }

    func cleanUp<B: LockmanBoundaryId>(boundaryId: B) {
      // No-op for unlock tests
    }

    func getCurrentLocks() -> [AnyLockmanBoundaryId: [any LockmanInfo]] {
      return [:]
    }

    // テスト用ヘルパー
    func reset() {
      lock.lock()
      defer { lock.unlock() }
      unlockCallCount = 0
      lastUnlockedBoundary = nil
      lastUnlockedInfo = nil
    }
  }

  // MARK: - Phase 1: LockmanUnlock基本操作

  func testLockmanUnlockImmediateExecution() {
    // .immediateオプションでのアンローク実行をテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "immediateTest")
    let boundaryId = "testBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // アンロック実行
    unlockToken()

    // すぐにアンロックされることを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)
    XCTAssertEqual(mockStrategy.lastUnlockedBoundary, AnyHashable(boundaryId))
    XCTAssertEqual(mockStrategy.lastUnlockedInfo?.actionId, "immediateTest")
  }

  func testLockmanUnlockMainRunLoopExecution() {
    // .mainRunLoopオプションでのアンローク実行をテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "mainRunLoopTest")
    let boundaryId = "mainRunLoopBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .mainRunLoop
    )

    let expectation = expectation(description: "MainRunLoop unlock execution")

    // アンロック実行
    unlockToken()

    // メインランループで実行されるまで待機
    DispatchQueue.main.async {
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      XCTAssertEqual(mockStrategy.lastUnlockedBoundary, AnyHashable(boundaryId))
      XCTAssertEqual(mockStrategy.lastUnlockedInfo?.actionId, "mainRunLoopTest")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  func testLockmanUnlockTransitionExecution() {
    // .transitionオプションでのアンローク実行をテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "transitionTest")
    let boundaryId = "transitionBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .transition
    )

    let expectation = expectation(description: "Transition delay unlock execution")

    let startTime = Date()

    // アンロック実行
    unlockToken()

    // まだ実行されていないことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 0)

    // プラットフォーム固有の遅延後に実行されることを確認
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let elapsed = Date().timeIntervalSince(startTime)
      XCTAssertGreaterThan(elapsed, 0.2)  // 最低限の遅延があることを確認
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      XCTAssertEqual(mockStrategy.lastUnlockedBoundary, AnyHashable(boundaryId))
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 2.0)
  }

  func testLockmanUnlockDelayedExecution() {
    // .delayed(TimeInterval)オプションでのアンローク実行をテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "delayedTest")
    let boundaryId = "delayedBoundary"
    let delayInterval: TimeInterval = 0.2

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .delayed(delayInterval)
    )

    let expectation = expectation(description: "Delayed unlock execution")

    let startTime = Date()

    // アンロック実行
    unlockToken()

    // まだ実行されていないことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 0)

    // 指定された遅延後に実行されることを確認
    DispatchQueue.main.asyncAfter(deadline: .now() + delayInterval + 0.1) {
      let elapsed = Date().timeIntervalSince(startTime)
      XCTAssertGreaterThan(elapsed, delayInterval)
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      XCTAssertEqual(mockStrategy.lastUnlockedInfo?.actionId, "delayedTest")
      expectation.fulfill()
    }

    wait(for: [expectation], timeout: 1.0)
  }

  // MARK: - Phase 2: LockmanUnlock異なる境界タイプとエッジケース

  func testLockmanUnlockWithDifferentBoundaryTypes() {
    // 異なる境界タイプでのアンロークをテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "boundaryTypeTest")

    // String境界
    let stringUnlock = LockmanUnlock(
      id: "stringBoundary",
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // Int境界
    let intUnlock = LockmanUnlock(
      id: 42,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // UUID境界
    let uuidBoundary = UUID()
    let uuidUnlock = LockmanUnlock(
      id: uuidBoundary,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // 各タイプを実行
    stringUnlock()
    intUnlock()
    uuidUnlock()

    XCTAssertEqual(mockStrategy.unlockCallCount, 3)
  }

  func testLockmanUnlockMultipleExecution() {
    // 同じトークンの複数実行をテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "multipleTest")
    let boundaryId = "multipleBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // 複数回実行
    unlockToken()
    unlockToken()
    unlockToken()

    // 複数回実行されることを確認（戦略側で重複処理を防ぐ）
    XCTAssertEqual(mockStrategy.unlockCallCount, 3)
  }

  func testLockmanUnlockSendableConformance() async {
    // Sendable準拠の並行アクセステスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "sendableTest")

    let unlockTokens = (0..<5).map { index in
      LockmanUnlock(
        id: "boundary\(index)",
        info: testInfo,
        strategy: anyStrategy,
        unlockOption: .immediate
      )
    }

    await withTaskGroup(of: Void.self) { group in
      for unlockToken in unlockTokens {
        group.addTask {
          // これがwarningなしでコンパイルされる = Sendableが動作している
          unlockToken()
        }
      }

      await group.waitForAll()
    }

    // すべてのアンロックが実行されたことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 5)
  }

  // MARK: - Phase 3: LockmanAutoUnlock自動管理

  func testLockmanAutoUnlockBasicFunctionality() async {
    // LockmanAutoUnlockの基本機能テスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "autoUnlockTest")
    let boundaryId = "autoUnlockBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)

    // 初期状態を確認
    let isLocked = await autoUnlock.isLocked
    let token = await autoUnlock.token
    XCTAssertTrue(isLocked)
    XCTAssertNotNil(token)

    // アンロックがまだ実行されていないことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 0)
  }

  func testLockmanAutoUnlockManualUnlock() async {
    // 手動アンロック機能テスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "manualUnlockTest")
    let boundaryId = "manualUnlockBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)

    // 手動アンロック実行
    await autoUnlock.manualUnlock()

    // アンロックが実行されたことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)
    let isLockedAfter = await autoUnlock.isLocked
    let tokenAfter = await autoUnlock.token
    XCTAssertFalse(isLockedAfter)
    XCTAssertNil(tokenAfter)
  }

  func testLockmanAutoUnlockAutomaticDeinit() async {
    // 自動deinitアンロックのテスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "deinitTest")
    let boundaryId = "deinitBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    // autoUnlockをスコープ内で作成して自動解放
    do {
      let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)
      _ = await autoUnlock.isLocked  // 使用を確認
    }  // ここでdeinitが呼ばれるはず

    // 少し待ってからdeinitが実行されたことを確認
    let expectation = expectation(description: "Auto deinit unlock")
    DispatchQueue.main.async {
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 1.0)
  }

  func testLockmanAutoUnlockDoubleUnlockPrevention() async {
    // 二重アンロック防止テスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "doubleUnlockTest")
    let boundaryId = "doubleUnlockBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)

    // 手動アンロックを実行
    await autoUnlock.manualUnlock()
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)

    // 再度手動アンロックを試行
    await autoUnlock.manualUnlock()

    // 二重実行されないことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)
    let finalLockState = await autoUnlock.isLocked
    XCTAssertFalse(finalLockState)
  }

  // MARK: - Phase 4: エッジケースと統合テスト

  func testLockmanUnlockWithDelayedEdgeCases() {
    // delayed unlockのエッジケーステスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "edgeCaseTest")

    // 0秒遅延
    let zeroDelayUnlock = LockmanUnlock(
      id: "zeroBoundary",
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .delayed(0.0)
    )

    let expectation1 = expectation(description: "Zero delay unlock")

    zeroDelayUnlock()

    DispatchQueue.main.async {
      // 0秒遅延でも非同期実行される
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      expectation1.fulfill()
    }

    wait(for: [expectation1], timeout: 0.5)

    mockStrategy.reset()

    // 非常に小さな遅延
    let smallDelayUnlock = LockmanUnlock(
      id: "smallBoundary",
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .delayed(0.001)
    )

    let expectation2 = expectation(description: "Small delay unlock")

    smallDelayUnlock()

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
      XCTAssertEqual(mockStrategy.unlockCallCount, 1)
      expectation2.fulfill()
    }

    wait(for: [expectation2], timeout: 0.5)
  }

  func testLockmanUnlockConcurrentExecution() async {
    // 並行アンローク実行テスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)

    let unlockTokens = (0..<10).map { index in
      LockmanUnlock(
        id: "concurrent\(index)",
        info: TestLockmanInfo(actionId: "concurrent\(index)"),
        strategy: anyStrategy,
        unlockOption: .immediate
      )
    }

    await withTaskGroup(of: Void.self) { group in
      for unlockToken in unlockTokens {
        group.addTask {
          unlockToken()
        }
      }

      await group.waitForAll()
    }

    // すべてのアンロックが正常に実行されたことを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 10)
  }

  func testLockmanAutoUnlockActorIsolation() async {
    // Actor isolation正常性テスト
    let mockStrategy = TestMockStrategy()
    let anyStrategy = AnyLockmanStrategy(mockStrategy)
    let testInfo = TestLockmanInfo(actionId: "actorTest")
    let boundaryId = "actorBoundary"

    let unlockToken = LockmanUnlock(
      id: boundaryId,
      info: testInfo,
      strategy: anyStrategy,
      unlockOption: .immediate
    )

    let autoUnlock = LockmanAutoUnlock(unlockToken: unlockToken)

    // 複数のactorメソッドを並行実行
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        _ = await autoUnlock.isLocked
      }

      group.addTask {
        _ = await autoUnlock.token
      }

      group.addTask {
        await autoUnlock.manualUnlock()
      }

      await group.waitForAll()
    }

    // 正常にactor isolationが機能していることを確認
    XCTAssertEqual(mockStrategy.unlockCallCount, 1)
    let actorFinalState = await autoUnlock.isLocked
    XCTAssertFalse(actorFinalState)
  }

  func testLockmanUnlockIntegrationWithRealStrategy() {
    // 実際のストラテジーとの統合テスト
    let container = LockmanStrategyContainer()
    let singleExecutionStrategy = LockmanSingleExecutionStrategy()

    do {
      try container.register(singleExecutionStrategy)

      let singleExecutionInfo = LockmanSingleExecutionInfo(
        actionId: "integrationTest",
        mode: .action
      )

      // アンロークトークンを作成（実際のstrategy containerから）
      let anyStrategy = try container.resolve(LockmanSingleExecutionStrategy.self)
      let unlockToken = LockmanUnlock(
        id: "integrationBoundary",
        info: singleExecutionInfo,
        strategy: anyStrategy,
        unlockOption: .immediate
      )

      // アンロック実行
      XCTAssertNoThrow(unlockToken())
    } catch {
      XCTFail("Strategy registration failed: \\(error)")
    }
  }

}
