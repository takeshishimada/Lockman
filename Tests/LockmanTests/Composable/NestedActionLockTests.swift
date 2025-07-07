import CasePaths
import ComposableArchitecture
import Testing

@testable import Lockman

// MARK: - Test Reducers

// For testNestedActionWithCasePaths
struct TestReducerWithNestedActions: Reducer {
  let viewActionExecuted: LockActorIsolated<Int>
  let delegateActionExecuted: LockActorIsolated<Int>

  struct State: Equatable {}

  @CasePathable
  enum Action {
    case view(ViewAction)
    case delegate(DelegateAction)
    case other

    enum ViewAction: LockmanAction {
      case buttonTapped

      var lockmanInfo: some LockmanInfo {
        LockmanSingleExecutionInfo(actionId: "view", mode: .boundary)
      }
    }

    enum DelegateAction: LockmanAction {
      case process

      var lockmanInfo: some LockmanInfo {
        LockmanSingleExecutionInfo(actionId: "delegate", mode: .boundary)
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.buttonTapped):
        return .run { [viewActionExecuted] _ in
          await viewActionExecuted.withValue { $0 += 1 }
          try await Task.sleep(for: .milliseconds(50))
        }
      case .delegate(.process):
        return .run { [delegateActionExecuted] _ in
          await delegateActionExecuted.withValue { $0 += 1 }
          try await Task.sleep(for: .milliseconds(50))
        }
      case .other:
        return .none
      }
    }
    .lock(
      boundaryId: CancelID.test,
      for: \.view, \.delegate
    )
  }
}

// For testNoCasePathsIgnoresNested
struct TestReducerWithoutCasePaths: Reducer {
  let actionExecuted: LockActorIsolated<Int>

  struct State: Equatable {}

  @CasePathable
  enum Action {
    case nested(NestedAction)

    enum NestedAction: LockmanAction {
      case test

      var lockmanInfo: some LockmanInfo {
        LockmanSingleExecutionInfo(actionId: "nested", mode: .boundary)
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .nested(.test):
        return .run { [actionExecuted] _ in
          await actionExecuted.withValue { $0 += 1 }
        }
      }
    }
    .lock(boundaryId: CancelID.test)  // No case paths
  }
}

// For testRootActionPriority
struct TestReducerWithRootPriority: Reducer {
  let rootExecuted: LockActorIsolated<Int>
  let nestedExecuted: LockActorIsolated<Int>

  struct State: Equatable {}

  @CasePathable
  enum Action: LockmanAction {
    case root
    case nested(NestedAction)

    var lockmanInfo: some LockmanInfo {
      switch self {
      case .root:
        return LockmanSingleExecutionInfo(actionId: "root", mode: .boundary)
      case .nested:
        return LockmanSingleExecutionInfo(actionId: "nested-parent", mode: .none)
      }
    }

    enum NestedAction: LockmanAction {
      case test

      var lockmanInfo: some LockmanInfo {
        LockmanSingleExecutionInfo(actionId: "nested", mode: .boundary)
      }
    }
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .root:
        return .run { [rootExecuted] _ in
          await rootExecuted.withValue { $0 += 1 }
          try await Task.sleep(for: .milliseconds(50))
        }
      case .nested(.test):
        return .run { [nestedExecuted] _ in
          await nestedExecuted.withValue { $0 += 1 }
          try await Task.sleep(for: .milliseconds(50))
        }
      }
    }
    .lock(
      boundaryId: CancelID.test,
      for: \.nested
    )
  }
}

enum CancelID {
  case test
}

// MARK: - Tests

@Suite("Nested Action Lock Tests")
struct NestedActionLockTests {

  @Test("LockmanReducer handles root-level LockmanAction")
  func testRootLevelLockmanAction() async {
    // Setup test container with single execution strategy
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      // Simple test to verify the basic behavior works
      let lockExecuted = LockActorIsolated(0)

      struct TestReducer: Reducer {
        let lockExecuted: LockActorIsolated<Int>

        struct State: Equatable {}

        enum Action: LockmanAction {
          case test

          var lockmanInfo: some LockmanInfo {
            LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
          }
        }

        var body: some ReducerOf<Self> {
          Reduce { state, action in
            switch action {
            case .test:
              return .run { [lockExecuted] _ in
                await lockExecuted.withValue { $0 += 1 }
                try await Task.sleep(for: .milliseconds(50))
              }
            }
          }
          .lock(boundaryId: CancelID.test)
        }
      }

      let store = await TestStore(initialState: TestReducer.State()) {
        TestReducer(lockExecuted: lockExecuted)
      }

      // Send action - should execute
      await store.send(.test)
      await store.finish()

      // Send again - should execute again (lock already released)
      await store.send(.test)
      await store.finish()

      // Verify both executions happened (lock is released after each effect)
      await lockExecuted.withValue { value in
        #expect(value == 2)
      }
    }
  }

  @Test("LockmanReducer with case paths handles nested actions")
  func testNestedActionWithCasePaths() async {
    // Setup test container with single execution strategy
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let viewActionExecuted = LockActorIsolated(0)
      let delegateActionExecuted = LockActorIsolated(0)

      let store = await TestStore(initialState: TestReducerWithNestedActions.State()) {
        TestReducerWithNestedActions(
          viewActionExecuted: viewActionExecuted,
          delegateActionExecuted: delegateActionExecuted
        )
      }

      // Send view action - should execute
      await store.send(.view(.buttonTapped))
      await store.finish()

      // Send delegate action - should execute (lock already released)
      await store.send(.delegate(.process))
      await store.finish()

      // Send other action - should execute (not lockable)
      await store.send(.other)
      await store.finish()

      // Verify view action executed once
      await viewActionExecuted.withValue { value in
        #expect(value == 1)
      }

      // Verify delegate action executed once
      await delegateActionExecuted.withValue { value in
        #expect(value == 1)
      }
    }
  }

  @Test("LockmanReducer without case paths ignores nested actions")
  func testNoCasePathsIgnoresNested() async {
    // Setup test container with single execution strategy
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let actionExecuted = LockActorIsolated(0)

      let store = await TestStore(initialState: TestReducerWithoutCasePaths.State()) {
        TestReducerWithoutCasePaths(actionExecuted: actionExecuted)
      }

      // Send nested action multiple times - should all execute (no locking)
      await store.send(.nested(.test))
      await store.send(.nested(.test))
      await store.send(.nested(.test))
      await store.finish()

      // All should execute since no case paths are provided
      await actionExecuted.withValue { value in
        #expect(value == 3)
      }
    }
  }

  @Test("LockmanReducer prioritizes root action conformance")
  func testRootActionPriority() async {
    // Setup test container with single execution strategy
    let container = LockmanStrategyContainer()
    let strategy = LockmanSingleExecutionStrategy()
    try? container.register(strategy)

    await LockmanManager.withTestContainer(container) {
      let rootExecuted = LockActorIsolated(0)
      let nestedExecuted = LockActorIsolated(0)

      let store = await TestStore(initialState: TestReducerWithRootPriority.State()) {
        TestReducerWithRootPriority(
          rootExecuted: rootExecuted,
          nestedExecuted: nestedExecuted
        )
      }

      // Send root action - should execute once (boundary mode)
      await store.send(.root)
      await store.finish()

      // Send again - should execute again (lock released)
      await store.send(.root)
      await store.finish()

      // Both root actions should execute
      await rootExecuted.withValue { value in
        #expect(value == 2)
      }

      // Now test nested action
      await store.send(.nested(.test))
      await store.finish()

      // Send again - should execute again (lock released)
      await store.send(.nested(.test))
      await store.finish()

      // Both nested actions should execute
      await nestedExecuted.withValue { value in
        #expect(value == 2)
      }
    }
  }
}

// Helper for actor-isolated state
actor LockActorIsolated<Value> {
  private var value: Value

  init(_ value: Value) {
    self.value = value
  }

  func setValue(_ newValue: Value) {
    self.value = newValue
  }

  func withValue<T>(_ body: (inout Value) -> T) -> T {
    body(&value)
  }
}
