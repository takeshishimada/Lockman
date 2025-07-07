import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Types for nested action support

@CasePathable
private enum TestAction: Equatable {
  case root
  case view(ViewAction)
  case other(OtherAction)
  
  enum ViewAction: LockmanAction {
    case tap
    
    var lockmanInfo: some LockmanInfo {
      LockmanSingleExecutionInfo(actionId: "tap", mode: .boundary)
    }
  }
  
  enum OtherAction: Equatable {
    case test
  }
}

private struct TestState: Equatable {
  var count = 0
}

@Reducer
private struct TestFeature {
  typealias State = TestState
  typealias Action = TestAction
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .root:
        return .none
      case .view(.tap):
        state.count += 1
        return .none
      case .other:
        return .none
      }
    }
  }
}

// MARK: - Tests

final class NestedActionLockTests: XCTestCase {
  
  func testBasicLockWithoutPaths() async {
    // Test basic lock creation without any paths
    let store = TestStore(initialState: TestState()) {
      TestFeature()
        .lock(boundaryId: "test")
    }
    
    // This should work fine as no action conforms to LockmanAction at root
    await store.send(.root)
    await store.send(.other(.test))
  }
  
  func testLockWithSinglePath() async {
    // Test lock with a single path for nested actions
    let store = TestStore(initialState: TestState()) {
      TestFeature()
        .lock(boundaryId: "test", for: \.view)
    }
    
    // The nested view action should be locked
    await store.send(.view(.tap)) {
      $0.count = 1
    }
  }
  
  func testMultiplePaths() async {
    // Test lock with multiple paths
    let store = TestStore(initialState: TestState()) {
      TestFeature()
        .lock(boundaryId: "test", for: \.view, \.other)
    }
    
    // View action should be locked
    await store.send(.view(.tap)) {
      $0.count = 1
    }
    
    // Other action should not be locked (doesn't conform to LockmanAction)
    await store.send(.other(.test))
  }
}