import XCTest
import ComposableArchitecture
@testable import Lockman

/// SingleExecutionStrategy ExecutionMode.boundary 統合テスト
/// 
/// テスト対象：
/// - ExecutionMode.boundary での境界レベル排他制御
/// - TestStoreとSingleExecutionStrategyの統合
/// - マクロ処理(`@LockmanSingleExecution`)の実動作
/// - Effect+LockmanInternalの実行パス
/// - 非同期unlock処理の完全なライフサイクル
final class SingleExecutionStrategy_BoundaryMode_IntegrationTests: XCTestCase {
  
  
  // MARK: - Setup & Teardown
  
  override func setUp() async throws {
    try await super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() async throws {
    LockmanManager.cleanup.all()
    try await super.tearDown()
  }
  
  // MARK: - Phase 1: Basic Integration Tests
  
  /// Phase 1: 基本的なアクション実行テスト
  /// TestStoreとSingleExecutionStrategyが正しく連携し、
  /// アクションが正常に実行→完了することを検証
  @MainActor
  func testPhase1_BasicSingleExecutionIntegration_SuccessfulExecution() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
      }
      
      // 正常なプロセス実行（状態変化なし：Effect実行のみ）
      await store.send(.view(.startProcess))
      
      // 内部アクション受信と状態変化の検証
      await store.receive(\.internal.processStart) {
        $0.isProcessing = true
      }
      
      await store.receive(\.internal.processCompleted) {
        $0.isProcessing = false
        $0.result = "success"
      }
      
      // すべてのEffect（unlock処理含む）の完了を待機
      await store.finish()
      
      // 最終状態の確認
      XCTAssertFalse(store.state.isProcessing)
      XCTAssertEqual(store.state.result, "success")
      XCTAssertNil(store.state.error)
    }
  }
  
  // MARK: - Phase 2: Lock Failure Tests
  
  /// Phase 2: ロック失敗テスト（事前ロック状態版）
  /// 実際のSingleExecutionStrategyで事前にロックを獲得しておき、
  /// 2回目のアクション実行時にロック失敗が発生することを検証
  @MainActor
  func testPhase2_LockFailure_WithPreLockedState() async throws {
    // 1. 実際のSingleExecutionStrategyインスタンスを準備
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    // 2. 事前にロックを獲得しておく（実際の戦略を使用）
    let boundaryId = TestSingleExecutionFeature.CancelID.process
    let preLockedInfo = LockmanSingleExecutionInfo(actionId: "prelock", mode: .boundary)
    strategy.lock(boundaryId: boundaryId, info: preLockedInfo)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
      }
      
      // 3. アクション送信 → 事前ロック状態により確実にlockFailure発生！
      await store.send(.view(.startProcess))
      
      // 4. lockFailureハンドラーからの内部アクションを明示的に受信
      await store.receive(\.internal.handleLockFailure) {
        $0.error = "lock_failed"
      }
      
      // 5. store完了まで待機
      await store.finish()
      
      // 6. lockFailureが発生したことを確認
      XCTAssertEqual(store.state.error, "lock_failed", "Pre-locked state should trigger lock failure")
    }
    
    // 7. テスト完了後にクリーンアップ（事前ロックを解除）
    strategy.unlock(boundaryId: boundaryId, info: preLockedInfo)
  }
  
  /// Phase 2: ロック失敗ハンドラー実行テスト
  /// Phase 2テストの別パターン。事前ロック状態により
  /// lockFailureハンドラーが確実に実行されることを検証
  @MainActor
  func testPhase2_LockFailure_HandleLockFailureExecution() async throws {
    // 1. 実際のSingleExecutionStrategyインスタンスを準備
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    // 2. 事前にロックを獲得しておく（決定論的手法）
    let boundaryId = TestSingleExecutionFeature.CancelID.process
    let preLockedInfo = LockmanSingleExecutionInfo(actionId: "prelock_alt", mode: .boundary)
    strategy.lock(boundaryId: boundaryId, info: preLockedInfo)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
      }
      
      // 3. アクション送信 → 事前ロック状態により確実にlockFailure発生！
      await store.send(.view(.startQuickProcess))
      
      // 4. lockFailureハンドラーからの内部アクションを明示的に受信
      await store.receive(\.internal.handleLockFailure) {
        $0.error = "lock_failed"
      }
      
      // 5. store完了まで待機
      await store.finish()
      
      // 6. lockFailureが発生したことを確認
      XCTAssertEqual(store.state.error, "lock_failed", "Pre-locked state should trigger lock failure")
    }
    
    // 7. テスト完了後にクリーンアップ（事前ロックを解除）
    strategy.unlock(boundaryId: boundaryId, info: preLockedInfo)
  }
  
  
  /// Phase 2: アクション順次実行・回復テスト
  /// 1つのアクション完了後、同じFeature内で次のアクションが
  /// 正常に実行できること（unlock→lock成功）を検証
  @MainActor
  func testPhase2_SequentialExecution_RecoveryAfterCompletion() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
      }
      
      // 1回目の完全な実行サイクル
      await store.send(.view(.startQuickProcess))
      
      await store.receive(\.internal.processStart) {
        $0.isProcessing = true
      }
      
      await store.receive(\.internal.processCompleted) {
        $0.isProcessing = false
        $0.result = "quick_process"
      }
      
      // 1回目完了後、2回目のアクションを送信（unlock後なので正常に実行されるはず）
      await store.send(.view(.startProcess))
      
      // 2回目の実行サイクル - 状態が適切に更新される
      await store.receive(\.internal.processStart) {
        $0.isProcessing = true
      }
      
      await store.receive(\.internal.processCompleted) {
        $0.isProcessing = false
        $0.result = "success"  // 2回目の結果で上書き
      }
      
      await store.finish()
      
      // 2回目も正常に実行できたことを確認
      XCTAssertEqual(store.state.result, "success")
      XCTAssertNil(store.state.error)
      XCTAssertFalse(store.state.isProcessing)
    }
  }
  
  // MARK: - Phase 3: Exception and Unlock Tests
  
  /// Phase 3: 例外発生時の自動unlock検証テスト
  /// アクション実行中に例外が発生した場合、自動的にunlockされ、
  /// その後のアクションが正常に実行できることを検証
  @MainActor
  func testPhase3_ExceptionDuringAction_AutoUnlock() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      // 例外発生用のアクション付きReducer
      let store = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
          .transformDependency(\.self) { _ in }
      }
      
      store.exhaustivity = .off
      
      // 最初に正常なアクションでロックが機能することを確認
      await store.send(.view(.startProcess))
      await store.finish()
      
      // 例外処理用の新しいReducerを作成
      let throwingStore = TestStore(initialState: TestThrowingFeature.State()) {
        TestThrowingFeature()
      }
      
      throwingStore.exhaustivity = .off
      
      // 例外を発生させるアクション
      await throwingStore.send(.view(.throwingProcess))
      
      // Effect完了まで待機（unlock処理含む）
      await throwingStore.finish()
      
      // 例外後に再度正常なアクションが実行できることを確認（unlock確認）
      let recoveryStore = TestStore(initialState: TestSingleExecutionFeature.State()) {
        TestSingleExecutionFeature()
      }
      
      recoveryStore.exhaustivity = .off
      
      // 回復テスト
      await recoveryStore.send(.view(.startProcess))
      await recoveryStore.finish()
      
      // 正常に実行完了できればunlockが機能している
      XCTAssertNil(recoveryStore.state.error, "Recovery action should succeed after exception, indicating unlock worked")
    }
  }
  
  
  // MARK: - Test Support Types
  
  /// テスト用Reducer - Examples/01-SingleExecutionStrategy.swiftを簡素化
  @Reducer
  struct TestSingleExecutionFeature {
    @ObservableState
    struct State: Equatable {
      var isProcessing = false
      var result: String?
      var error: String?
    }
    
    @CasePathable
    enum Action: ViewAction {
      case view(ViewAction)
      case `internal`(InternalAction)
      
      @LockmanSingleExecution
      enum ViewAction {
        case startProcess
        case startLongRunningProcess
        case startQuickProcess
        
        func createLockmanInfo() -> LockmanSingleExecutionInfo {
          return .init(actionId: actionName, mode: .boundary)
        }
      }
      
      @CasePathable
      enum InternalAction {
        case processStart
        case processCompleted(String)
        case handleError(any Error)
        case handleLockFailure(any Error)
      }
    }
    
    enum CancelID {
      case process
    }
    
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(viewAction, state: &state)
          
        case .internal(let internalAction):
          return handleInternalAction(internalAction, state: &state)
        }
      }
      .lock(
        boundaryId: CancelID.process,
        lockFailure: { error, send in
          await send(.internal(.handleLockFailure(error)))
        },
        for: \.view
      )
    }
    
    // MARK: - Action Handlers
    
    private func handleViewAction(
      _ action: Action.ViewAction,
      state: inout State
    ) -> Effect<Action> {
      switch action {
      case .startProcess:
        return .run { send in
          await send(.internal(.processStart))
          try await Task.sleep(nanoseconds: 100_000_000) // 100ms
          await send(.internal(.processCompleted("success")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: CancelID.process)
        
      case .startLongRunningProcess:
        return .run { _ in
          // Pure sleep to ensure lock is held for 2 seconds
          try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: CancelID.process)
        
      case .startQuickProcess:
        return .run { send in
          await send(.internal(.processStart))
          await send(.internal(.processCompleted("quick_process")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: CancelID.process)
      }
    }
    
    private func handleInternalAction(
      _ action: Action.InternalAction,
      state: inout State
    ) -> Effect<Action> {
      switch action {
      case .processStart:
        state.isProcessing = true
        return .none
        
      case .processCompleted(let result):
        state.isProcessing = false
        state.result = result
        return .none
        
      case .handleError(let error):
        state.isProcessing = false
        state.error = error.localizedDescription
        return .none
        
      case .handleLockFailure(_):
        state.error = "lock_failed"
        return .none
      }
    }
  }
  
  /// 例外発生用テストReducer
  @Reducer
  struct TestThrowingFeature {
    @ObservableState
    struct State: Equatable {
      var isProcessing = false
      var result: String?
      var error: String?
    }
    
    @CasePathable
    enum Action: ViewAction {
      case view(ViewAction)
      case `internal`(InternalAction)
      
      @LockmanSingleExecution
      enum ViewAction {
        case throwingProcess
        
        func createLockmanInfo() -> LockmanSingleExecutionInfo {
          return .init(actionId: actionName, mode: .boundary)
        }
      }
      
      @CasePathable
      enum InternalAction {
        case handleError(any Error)
        case handleLockFailure(any Error)
      }
    }
    
    enum CancelID {
      case process
    }
    
    var body: some Reducer<State, Action> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          return handleViewAction(viewAction, state: &state)
          
        case .internal(let internalAction):
          return handleInternalAction(internalAction, state: &state)
        }
      }
      .lock(
        boundaryId: CancelID.process,
        lockFailure: { error, send in
          await send(.internal(.handleLockFailure(error)))
        },
        for: \.view
      )
    }
    
    private func handleViewAction(
      _ action: Action.ViewAction,
      state: inout State
    ) -> Effect<Action> {
      switch action {
      case .throwingProcess:
        return .run { _ in
          throw IntegrationTestError.intentionalFailure
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: CancelID.process)
      }
    }
    
    private func handleInternalAction(
      _ action: Action.InternalAction,
      state: inout State
    ) -> Effect<Action> {
      switch action {
      case .handleError(let error):
        state.error = error.localizedDescription
        return .none
        
      case .handleLockFailure(_):
        state.error = "lock_failed"
        return .none
      }
    }
  }
  
  /// テスト用エラー
  enum IntegrationTestError: Error, LocalizedError {
    case intentionalFailure
    
    var errorDescription: String? {
      switch self {
      case .intentionalFailure:
        return "Intentional test failure"
      }
    }
  }
}
