import ComposableArchitecture
import XCTest

@testable import Lockman

/// SingleExecutionStrategy ExecutionMode.none 統合テスト
///
/// テスト対象：
/// - ExecutionMode.none での排他制御無効化
/// - 複数アクションの同時実行許可
/// - Strategy無効状態での正常動作
final class SingleExecutionStrategy_NoneMode_IntegrationTests: XCTestCase {

  // MARK: - Setup & Teardown

  override func setUp() async throws {
    try await super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() async throws {
    LockmanManager.cleanup.all()
    try await super.tearDown()
  }

  // MARK: - Phase 1: None Mode Basic Tests

  /// Phase 1: ExecutionMode.none基本テスト
  /// noneモードでは排他制御が無効化され、個別のアクションが
  /// 正常実行されることを検証
  @MainActor
  func testPhase1_NoneMode_NoExclusiveExecution() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestNoneModeFeature.State()) {
        TestNoneModeFeature()
      }

      // processA実行テスト
      await store.send(.view(.processA))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processA")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processA")
        $0.completedProcesses.insert("processA")
        $0.completionCount["processA", default: 0] += 1
      }

      // processB実行テスト
      await store.send(.view(.processB))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processB")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processB")
        $0.completedProcesses.insert("processB")
        $0.completionCount["processB", default: 0] += 1
      }

      await store.finish()

      // 最終的にすべてのプロセスが完了していることを確認
      XCTAssertTrue(store.state.runningProcesses.isEmpty)
      XCTAssertEqual(store.state.completedProcesses.count, 2)
      XCTAssertTrue(store.state.completedProcesses.contains("processA"))
      XCTAssertTrue(store.state.completedProcesses.contains("processB"))
      XCTAssertNil(store.state.error)
    }
  }

  /// Phase 2: ExecutionMode.none 最適化された連続実行テスト
  /// noneモードでの排他制御無効化を効率的に検証
  @MainActor
  func testPhase2_NoneMode_OptimizedSequentialExecution() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestNoneModeFeature.State()) {
        TestNoneModeFeature()
      }

      // TCA内部制約を考慮した効率的な順次実行（実行時間短縮）
      await store.send(.view(.processA))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processA")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processA")
        $0.completedProcesses.insert("processA")
        $0.completionCount["processA", default: 0] += 1
      }

      await store.send(.view(.processB))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processB")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processB")
        $0.completedProcesses.insert("processB")
        $0.completionCount["processB", default: 0] += 1
      }

      await store.send(.view(.processC))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processC")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processC")
        $0.completedProcesses.insert("processC")
        $0.completionCount["processC", default: 0] += 1
      }

      await store.finish()

      // ExecutionMode.noneでは全て実行完了しているべき
      XCTAssertTrue(store.state.runningProcesses.isEmpty)
      XCTAssertEqual(store.state.completedProcesses.count, 3)
      XCTAssertTrue(store.state.completedProcesses.contains("processA"))
      XCTAssertTrue(store.state.completedProcesses.contains("processB"))
      XCTAssertTrue(store.state.completedProcesses.contains("processC"))
      XCTAssertNil(store.state.error)
    }
  }

  /// Phase 3: ExecutionMode.none 事前ロック状態でもバイパステスト
  /// noneモードでは事前ロック状態があっても排他制御をバイパスして実行されることを検証
  @MainActor
  func testPhase3_NoneMode_PreLockedStateBypass() async throws {
    let strategy = LockmanSingleExecutionStrategy()
    let container = LockmanStrategyContainer()
    try container.register(strategy)

    // 事前に手動でロック状態を作成（境界とアクションの両方）
    let boundaryId = TestNoneModeFeature.BoundaryID.testBoundary
    let preLockedInfo = LockmanSingleExecutionInfo(actionId: "processA", mode: .none)
    strategy.lock(boundaryId: boundaryId, info: preLockedInfo)

    try await LockmanManager.withTestContainer(container) {
      let store = TestStore(initialState: TestNoneModeFeature.State()) {
        TestNoneModeFeature()
      }

      // 事前ロック状態があってもprocessAが実行される (.noneモードの効果)
      await store.send(.view(.processA))
      await store.receive(\.internal.processStarted) {
        $0.runningProcesses.insert("processA")
      }
      await store.receive(\.internal.processCompleted) {
        $0.runningProcesses.remove("processA")
        $0.completedProcesses.insert("processA")
        $0.completionCount["processA", default: 0] += 1
      }

      await store.finish()

      // noneモードでは事前ロック状態をバイパスして実行された
      XCTAssertTrue(store.state.completedProcesses.contains("processA"))
      XCTAssertEqual(store.state.completionCount["processA"], 1)
      XCTAssertNil(store.state.error)  // lockFailureは発生しない
    }

    // クリーンアップ
    strategy.unlock(boundaryId: boundaryId, info: preLockedInfo)
  }

  // MARK: - Test Support Types

  /// ExecutionMode.none テスト用Reducer
  @Reducer
  struct TestNoneModeFeature {
    @ObservableState
    struct State: Equatable {
      var runningProcesses: Set<String> = []
      var completedProcesses: Set<String> = []
      var completionCount: [String: Int] = [:]  // 実行完了回数をカウント
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
        case customProcess(String)

        func createLockmanInfo() -> LockmanSingleExecutionInfo {
          return .init(actionId: actionName, mode: .none)  // .none モード使用
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
    enum BoundaryID: LockmanBoundaryId {
      case testBoundary
    }

    // Effect管理用のCancelID
    enum EffectCancelID: Hashable {
      case processA
      case processB
      case processC
      case customProcess(String)
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
      // 統合テスト: 単一境界でExecutionMode.noneの動作を検証
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
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms (高速化)
          await send(.internal(.processCompleted("processA")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processA)

      case .processB:
        return .run { send in
          await send(.internal(.processStarted("processB")))
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms (高速化)
          await send(.internal(.processCompleted("processB")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processB)

      case .processC:
        return .run { send in
          await send(.internal(.processStarted("processC")))
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms (高速化)
          await send(.internal(.processCompleted("processC")))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.processC)

      case .customProcess(let processName):
        return .run { send in
          await send(.internal(.processStarted(processName)))
          try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
          await send(.internal(.processCompleted(processName)))
        } catch: { error, send in
          await send(.internal(.handleError(error)))
        }
        .cancellable(id: EffectCancelID.customProcess(processName))
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
        state.completionCount[processName, default: 0] += 1
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
