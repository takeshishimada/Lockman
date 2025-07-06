import Benchmark
import ComposableArchitecture
import Foundation
import Lockman

// MARK: - Store Creation

@MainActor
private func singleExecutionRootStore() -> StoreOf<SingleExecutionFeature> {
  Store(initialState: SingleExecutionFeature.State()) { SingleExecutionFeature() }
}

@MainActor
private func priorityBasedRootStore() -> StoreOf<PriorityBasedFeature> {
  Store(initialState: PriorityBasedFeature.State()) { PriorityBasedFeature() }
}

@MainActor
private func compositeStrategyRootStore() -> StoreOf<CompositeStrategyFeature> {
  Store(initialState: CompositeStrategyFeature.State()) { CompositeStrategyFeature() }
}

@MainActor
private func dynamicConditionRootStore() -> StoreOf<DynamicConditionFeature> {
  Store(initialState: DynamicConditionFeature.State()) { DynamicConditionFeature() }
}

// MARK: - Burst Load Store Creation

@MainActor
private func singleExecutionBurstStore() -> StoreOf<SingleExecutionBurstFeature> {
  Store(initialState: SingleExecutionBurstFeature.State()) { SingleExecutionBurstFeature() }
}

@MainActor
private func priorityBasedBurstStore() -> StoreOf<PriorityBasedBurstFeature> {
  Store(initialState: PriorityBasedBurstFeature.State()) { PriorityBasedBurstFeature() }
}

// MARK: - Benchmarks

let benchmarks = { @Sendable in
  // Basic benchmarks
  Benchmark(".run") { @MainActor benchmark async in
    let store = singleExecutionRootStore()
    benchmark.startMeasurement()
    blackHole(store.send(.tap))
  }

  Benchmark(".withLock SingleExecution") { @MainActor benchmark async in
    let store = singleExecutionRootStore()
    benchmark.startMeasurement()
    blackHole(store.send(.tapWithLock))
  }

  Benchmark(".withLock PriorityBased") { @MainActor benchmark async in
    let store = priorityBasedRootStore()
    benchmark.startMeasurement()
    blackHole(store.send(.tapWithLock))
  }

  Benchmark(".withLock CompositeStrategy") { @MainActor benchmark async in
    let store = compositeStrategyRootStore()
    benchmark.startMeasurement()
    blackHole(store.send(.tapWithLock))
  }

  Benchmark(".withLock DynamicCondition") { @MainActor benchmark async in
    let store = dynamicConditionRootStore()
    benchmark.startMeasurement()
    blackHole(store.send(.tapWithLock))
  }

  // Burst load benchmarks
  Benchmark("Burst: SingleExecution (100 concurrent)") { @MainActor benchmark async in
    let store = singleExecutionBurstStore()

    benchmark.startMeasurement()

    // Fire 100 concurrent actions with mixed pattern (10 types x 10 instances)
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<100 {
        let actionId = i / 10  // 10 instances per action ID
        group.addTask {
          await store.send(.burst(id: actionId)).finish()
        }
      }
    }
  }

  Benchmark("Burst: PriorityBased (100 concurrent)") { @MainActor benchmark async in
    let store = priorityBasedBurstStore()

    benchmark.startMeasurement()

    // Fire 100 concurrent actions with priority distribution
    await withTaskGroup(of: Void.self) { group in
      for i in 0..<100 {
        let actionId = i / 10  // 10 instances per action ID
        let priority: PriorityLevel

        // Priority distribution: High 20%, Low 50%, None 30%
        if i < 20 {
          priority = .high
        } else if i < 70 {
          priority = .low
        } else {
          priority = .none
        }

        group.addTask {
          await store.send(.burst(id: actionId, priority: priority)).finish()
        }
      }
    }
  }
}

// MARK: - Basic Test Features

@Reducer
private struct SingleExecutionFeature {
  @ObservableState
  struct State {
    var count = 0
  }

  @LockmanSingleExecution
  enum Action {
    case tap
    case tapWithLock
    case increment

    var lockmanInfo: LockmanSingleExecutionInfo {
      .init(actionId: actionName, mode: .boundary)
    }
  }

  enum CancelID {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.increment)
        }

      case .tapWithLock:
        return .withLock(
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}

@Reducer
private struct PriorityBasedFeature {
  @ObservableState
  struct State {
    var count = 0
  }

  @LockmanPriorityBased
  enum Action {
    case tap
    case tapWithLock
    case increment

    var lockmanInfo: LockmanPriorityBasedInfo {
      .init(actionId: actionName, priority: .high(.exclusive))
    }
  }

  enum CancelID {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.increment)
        }

      case .tapWithLock:
        return .withLock(
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}

@Reducer
private struct CompositeStrategyFeature {
  @ObservableState
  struct State {
    var count = 0
    var isEnabled = true
  }

  @LockmanCompositeStrategy(
    LockmanSingleExecutionStrategy.self, LockmanDynamicConditionStrategy.self)
  enum Action {
    case tap
    case tapWithLock
    case increment

    var lockmanInfo:
      LockmanCompositeInfo2<LockmanSingleExecutionStrategy.I, LockmanDynamicConditionStrategy.I>
    {
      LockmanCompositeInfo2(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary),
        lockmanInfoForStrategy2: LockmanDynamicConditionInfo(
          actionId: actionName, condition: { .success })
      )
    }
  }

  enum CancelID {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.increment)
        }

      case .tapWithLock:
        return .withLock(
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}

@Reducer
private struct DynamicConditionFeature {
  @ObservableState
  struct State {
    var count = 0
    var isEnabled = true
  }

  @LockmanDynamicCondition
  enum Action {
    case tap
    case tapWithLock
    case increment
  }

  enum CancelID {
    case userAction
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .tap:
        return .run { send in
          await send(.increment)
        }

      case .tapWithLock:
        return .withLock(
          operation: { send in
            await send(.increment)
          },
          action: action,
          cancelID: CancelID.userAction
        )

      case .increment:
        state.count += 1
        return .none
      }
    }
  }
}

// MARK: - Burst Load Test Features

enum PriorityLevel {
  case high
  case low
  case none
}

@Reducer
private struct SingleExecutionBurstFeature {
  @ObservableState
  struct State {
    var completedCount = 0
    var activeCount = 0
    var results: [Int: Date] = [:]  // Track completion times for latency measurement
  }

  @LockmanSingleExecution
  enum Action {
    case burst(id: Int)
    case process(id: Int, startTime: Date)
    case complete(id: Int, startTime: Date)

    var lockmanInfo: LockmanSingleExecutionInfo {
      switch self {
      case .burst(let id), .process(let id, _), .complete(let id, _):
        // Use action ID to create competition
        return .init(actionId: "action-\(id)", mode: .boundary)
      }
    }
  }

  enum CancelID {
    case burst
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .burst(let id):
        state.activeCount += 1
        let startTime = Date()

        return .withLock(
          operation: { send in
            await send(.process(id: id, startTime: startTime))
          },
          action: action,
          cancelID: CancelID.burst
        )

      case .process(let id, let startTime):
        // Simulate some work (5-10ms)
        return .run { send in
          try? await Task.sleep(nanoseconds: UInt64.random(in: 5_000_000...10_000_000))
          await send(.complete(id: id, startTime: startTime))
        }

      case .complete(let id, _):
        state.completedCount += 1
        state.activeCount -= 1
        state.results[id] = Date()
        return .none
      }
    }
  }
}

@Reducer
private struct PriorityBasedBurstFeature {
  @ObservableState
  struct State {
    var completedCount = 0
    var activeCount = 0
    var results: [Int: Date] = [:]
  }

  @LockmanPriorityBased
  enum Action {
    case burst(id: Int, priority: PriorityLevel)
    case process(id: Int, startTime: Date)
    case complete(id: Int, startTime: Date)

    var lockmanInfo: LockmanPriorityBasedInfo {
      switch self {
      case .burst(let id, let priority):
        let lockmanPriority: LockmanPriorityBasedInfo.Priority
        switch priority {
        case .high:
          lockmanPriority = .high(.exclusive)
        case .low:
          lockmanPriority = .low(.replaceable)
        case .none:
          lockmanPriority = .none
        }
        return .init(actionId: "action-\(id)", priority: lockmanPriority)

      case .process(let id, _), .complete(let id, _):
        // Default to low for internal actions
        return .init(actionId: "action-\(id)", priority: .low(.replaceable))
      }
    }
  }

  enum CancelID {
    case burst
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .burst(let id, _):
        state.activeCount += 1
        let startTime = Date()

        return .withLock(
          operation: { send in
            await send(.process(id: id, startTime: startTime))
          },
          action: action,
          cancelID: CancelID.burst
        )

      case .process(let id, let startTime):
        // Simulate some work (5-10ms)
        return .run { send in
          try? await Task.sleep(nanoseconds: UInt64.random(in: 5_000_000...10_000_000))
          await send(.complete(id: id, startTime: startTime))
        }

      case .complete(let id, _):
        state.completedCount += 1
        state.activeCount -= 1
        state.results[id] = Date()
        return .none
      }
    }
  }
}
