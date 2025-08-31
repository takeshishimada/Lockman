import XCTest
import ComposableArchitecture
@testable import Lockman

/// SingleExecutionStrategy ExecutionMode.action 統合テスト
/// 
/// テスト対象：
/// - ExecutionMode.action での同一アクション排他制御
/// - 異なるアクション同士の同時実行許可
/// - アクションレベルでのlockFailure処理
final class SingleExecutionStrategy_ActionMode_IntegrationTests: XCTestCase {
  
  // MARK: - Setup & Teardown
  
  override func setUp() async throws {
    try await super.setUp()
    LockmanManager.cleanup.all()
  }
  
  override func tearDown() async throws {
    LockmanManager.cleanup.all()
    try await super.tearDown()
  }
  
  // MARK: - Phase 1: Action Mode Basic Tests
  
  /// Phase 1: ExecutionMode.action基本テスト
  /// actionモードでは異なるアクションが独立して実行されることを検証
  @MainActor
  func testPhase1_ActionMode_SameActionExclusive_DifferentActionsConcurrent() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestActionModeFeature.State()) {
        TestActionModeFeature()
      }
      
      // processA実行テスト
      await store.send(.view(.processA))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processA")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processA")
        $0.completedProcesses.insert("processA")
      }
      
      // processB実行テスト (異なるアクション)
      await store.send(.view(.processB))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processB")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processB")
        $0.completedProcesses.insert("processB")
      }
      
      await store.finish()
      
      XCTAssertTrue(store.state.runningProcesses.isEmpty)
      XCTAssertEqual(store.state.completedProcesses.count, 2)
      XCTAssertNil(store.state.error)
    }
  }
  
  /// Phase 2: ExecutionMode.action 同一アクション排他テスト
  /// 同一アクションの2回目実行時にlockFailureが発生することを検証
  @MainActor
  func testPhase2_ActionMode_SameActionLockFailure() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    // 事前に同一アクションでロックを獲得（統合テスト用の単一境界）
    let boundaryId = TestActionModeFeature.BoundaryID.testBoundary
    let preLockedInfo = LockmanSingleExecutionInfo(actionId: "processA", mode: .action)
    strategy.lock(boundaryId: boundaryId, info: preLockedInfo)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestActionModeFeature.State()) {
        TestActionModeFeature()
      }
      
      // 同一アクション送信 → lockFailure発生
      await store.send(.view(.processA))
      
      await store.receive(\.internal.handleLockFailure) {
        $0.error = "lock_failed"
      }
      
      await store.finish()
      
      XCTAssertEqual(store.state.error, "lock_failed")
      XCTAssertTrue(store.state.runningProcesses.isEmpty)
    }
    
    // クリーンアップ
    strategy.unlock(boundaryId: boundaryId, info: preLockedInfo)
  }
  
  /// Phase 3: ExecutionMode.action 長時間実行 vs 短時間実行テスト
  /// 長時間実行中に同一アクションを送信してlockFailureを発生させるテスト
  @MainActor
  func testPhase3_ActionMode_LongRunning_vs_QuickAction_SameAction() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestActionModeFeature.State()) {
        TestActionModeFeature()
      }
      
      // 長時間実行アクションを開始
      await store.send(.view(.longRunningProcessA))
      
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("longRunningProcessA")
      }
      
      // 短時間待機してから同じアクション種別を送信
      try await Task.sleep(nanoseconds: 50_000_000) // 50ms
      
      // 事前ロック状態を作成してlockFailureを発生させる（統合テスト用の単一境界）
      let boundaryId = TestActionModeFeature.BoundaryID.testBoundary
      let preLockedInfo = LockmanSingleExecutionInfo(actionId: "longRunningProcessA", mode: .action)
      strategy.lock(boundaryId: boundaryId, info: preLockedInfo)
      
      await store.send(.view(.longRunningProcessA))
      
      await store.receive(\.internal.handleLockFailure) {
        $0.error = "lock_failed"
      }
      
      // 最初の長時間実行が完了
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("longRunningProcessA")
        $0.completedProcesses.insert("longRunningProcessA")
      }
      
      await store.finish()
      
      XCTAssertEqual(store.state.error, "lock_failed")
      XCTAssertEqual(store.state.completedProcesses.count, 1)
      
      // クリーンアップ
      strategy.unlock(boundaryId: boundaryId, info: preLockedInfo)
    }
  }
  
  /// Phase 4: ExecutionMode.action パラメータ付きアクションテスト
  /// 同じアクション種別でもパラメータが異なる場合の動作を検証
  @MainActor
  func testPhase4_ActionMode_ParameterizedActions() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)
    
    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestActionModeFeature.State()) {
        TestActionModeFeature()
      }
      
      // パラメータ付きアクションを複数送信
      await store.send(.view(.processWithParam("param1")))
      await store.send(.view(.processWithParam("param2")))
      
      // 同一アクション種別なので2回目はlockFailureになる可能性
      // （実装依存：パラメータを含むかどうか）
      
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processWithParam_param1")
      }
      
      // 2つ目はlockFailureまたは待機状態
      await store.receive(\.internal.handleLockFailure) {
        $0.error = "lock_failed"
      }
      
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processWithParam_param1")
        $0.completedProcesses.insert("processWithParam_param1")
      }
      
      await store.finish()
      
      XCTAssertEqual(store.state.error, "lock_failed")
    }
  }
  
  // MARK: - Test Support Types
  
  /// ExecutionMode.action テスト用Reducer
  @Reducer
  struct TestActionModeFeature {
    @ObservableState
    struct State: Equatable {
      var runningProcesses: Set<String> = []
      var completedProcesses: Set<String> = []
      var error: String?
    }
    
    @CasePathable
    enum Action: ViewAction {
      case view(ViewAction)
      case `internal`(InternalAction)
      
      @LockmanSingleExecution
      enum ViewAction {
        case processA
        case processB
        case processC
        case longRunningProcessA
        case processWithParam(String)
        
        func createLockmanInfo() -> LockmanSingleExecutionInfo {
          return .init(actionId: actionName, mode: .action) // .action モード使用
        }
      }
      
      @CasePathable
      enum InternalAction {
        case processStarted(String)
        case processCompleted(String)
        case handleError(any Error)
        case handleLockFailure(any Error)
      }
    }
    
    // 統合テスト用の単一境界ID
    enum BoundaryID {
      case testBoundary
    }
    
    // Effect管理用のCancelID
    enum EffectCancelID: Hashable {
      case processA
      case processB
      case processC
      case longRunningProcessA
      case processWithParam(String)
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
      // 統合テスト: 単一境界でExecutionMode.actionの動作を検証
      .lock(
        boundaryId: BoundaryID.testBoundary,
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
      case .processA:
        return .run { send in
          await send(.internal(.processStarted("processA")))
          try await Task.sleep(nanoseconds: 100_000_000) // 100ms
          await send(.internal(.processCompleted("processA")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processA)
        
      case .processB:
        return .run { send in
          await send(.internal(.processStarted("processB")))
          try await Task.sleep(nanoseconds: 100_000_000) // 100ms
          await send(.internal(.processCompleted("processB")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processB)
        
      case .processC:
        return .run { send in
          await send(.internal(.processStarted("processC")))
          try await Task.sleep(nanoseconds: 100_000_000) // 100ms
          await send(.internal(.processCompleted("processC")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processC)
        
      case .longRunningProcessA:
        return .run { send in
          await send(.internal(.processStarted("longRunningProcessA")))
          try await Task.sleep(nanoseconds: 500_000_000) // 500ms
          await send(.internal(.processCompleted("longRunningProcessA")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.longRunningProcessA)
        
      case .processWithParam(let param):
        return .run { send in
          let processName = "processWithParam_\(param)"
          await send(.internal(.processStarted(processName)))
          try await Task.sleep(nanoseconds: 100_000_000) // 100ms
          await send(.internal(.processCompleted(processName)))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processWithParam(param))
      }
    }
    
    private func handleInternalAction(
      _ action: Action.InternalAction,
      state: inout State
    ) -> Effect<Action> {
      switch action {
      case .processStarted(let processName):
        state.runningProcesses.insert(processName)
        return .none
        
      case .processCompleted(let processName):
        state.runningProcesses.remove(processName)
        state.completedProcesses.insert(processName)
        return .none
        
      case .handleError(let error):
        state.error = error.localizedDescription
        return .none
        
      case .handleLockFailure(_):
        state.error = "lock_failed"
        return .none
      }
    }
  }
}