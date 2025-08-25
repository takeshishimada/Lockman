import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Types that caused crash in Swift 5.9

@CasePathable
private enum FiveNestedAction: Equatable {
  case root
  case nested(NestedAction)
  case other(OtherAction)
  case more(MoreAction)
  case another(AnotherAction)
  case last(LastAction)

  enum NestedAction: LockmanAction, Equatable {
    case test

    func createLockmanInfo() -> some LockmanInfo {
      LockmanSingleExecutionInfo(actionId: "nested", mode: .boundary)
    }
  }

  enum OtherAction: Equatable {
    case test
  }

  enum MoreAction: Equatable {
    case test
  }

  enum AnotherAction: Equatable {
    case test
  }

  enum LastAction: Equatable {
    case test
  }
}

// Root action that conforms to LockmanAction (original crash case)
@CasePathable
private enum RootLockmanAction: LockmanAction, Equatable {
  case root
  case nested(NestedAction)
  case other(OtherAction)
  case more(MoreAction)
  case another(AnotherAction)
  case last(LastAction)

  func createLockmanInfo() -> some LockmanInfo {
    LockmanSingleExecutionInfo(actionId: "root", mode: .boundary)
  }

  enum NestedAction: LockmanAction, Equatable {
    case test

    func createLockmanInfo() -> some LockmanInfo {
      LockmanSingleExecutionInfo(actionId: "nested", mode: .boundary)
    }
  }

  enum OtherAction: Equatable {
    case test
  }

  enum MoreAction: Equatable {
    case test
  }

  enum AnotherAction: Equatable {
    case test
  }

  enum LastAction: Equatable {
    case test
  }
}

private struct TestState: Equatable {
  var count = 0
}

@Reducer
private struct FiveNestedReducer {
  typealias State = TestState
  typealias Action = FiveNestedAction

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}

@Reducer
private struct RootLockmanReducer {
  typealias State = TestState
  typealias Action = RootLockmanAction

  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}

// MARK: - Tests

final class Swift59CrashInvestigationTests: XCTestCase {

  // Test with 5 paths that caused crash in CI
  func testFivePathsCompilation() {
    let reducer = FiveNestedReducer()

    // This compilation test verifies the 5-path overload works
    _ = reducer.lock(
      boundaryId: "test",
      for: \.nested,
      \.other,
      \.more,
      \.another,
      \.last
    )

    XCTAssertTrue(true, "5-path compilation succeeded")
  }

  // Test with root action conforming to LockmanAction
  func testRootLockmanActionWithFivePaths() {
    let reducer = RootLockmanReducer()

    // This was the original crash case
    _ = reducer.lock(
      boundaryId: "test",
      for: \.nested,
      \.other,
      \.more,
      \.another,
      \.last
    )

    XCTAssertTrue(true, "Root LockmanAction with 5 paths compilation succeeded")
  }

  // Test actual usage with TestStore
  func testFivePathsWithTestStore() async {
    let store = await TestStore(initialState: TestState()) {
      FiveNestedReducer()
        .lock(
          boundaryId: "test",
          for: \.nested,
          \.other,
          \.more,
          \.another,
          \.last
        )
    }

    // Send various actions
    await store.send(.root)
    await store.send(.other(.test))
    await store.send(.more(.test))

    XCTAssertTrue(true, "TestStore with 5 paths succeeded")
  }

  // Test with explicit type annotations (Swift 5.9 workaround)
  func testFivePathsWithExplicitTypes() {
    let reducer = FiveNestedReducer()

    let path1: CaseKeyPath<FiveNestedAction, FiveNestedAction.NestedAction> = \.nested
    let path2: CaseKeyPath<FiveNestedAction, FiveNestedAction.OtherAction> = \.other
    let path3: CaseKeyPath<FiveNestedAction, FiveNestedAction.MoreAction> = \.more
    let path4: CaseKeyPath<FiveNestedAction, FiveNestedAction.AnotherAction> = \.another
    let path5: CaseKeyPath<FiveNestedAction, FiveNestedAction.LastAction> = \.last

    _ = reducer.lock(
      boundaryId: "test",
      for: path1,
      path2,
      path3,
      path4,
      path5
    )

    XCTAssertTrue(true, "Explicit types compilation succeeded")
  }

  // Test with actual behavior similar to original crash
  func testComplexNestedBehavior() async {
    let store = await TestStore(initialState: TestState()) {
      RootLockmanReducer()
        .lock(
          boundaryId: "test",
          for: \.nested,
          \.other,
          \.more,
          \.another,
          \.last
        )
    }

    // Just test that the store can be created without crashing
    await store.send(.root)

    XCTAssertTrue(true, "Complex nested behavior test succeeded")
  }
}
