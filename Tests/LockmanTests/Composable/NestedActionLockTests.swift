import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Test Types

@CasePathable
enum NestedLockTestAction: LockmanAction {
  case root
  case nested(NestedAction)
  case other(OtherAction)
  case more(MoreAction)
  case another(AnotherAction)
  case last(LastAction)
  
  var lockmanInfo: some LockmanInfo {
    LockmanSingleExecutionInfo(actionId: "test", mode: .boundary)
  }
  
  enum NestedAction: LockmanAction {
    case test
    
    var lockmanInfo: some LockmanInfo {
      LockmanSingleExecutionInfo(actionId: "nested", mode: .boundary)
    }
  }
  
  enum OtherAction {
    case test
  }
  
  enum MoreAction {
    case test
  }
  
  enum AnotherAction {
    case test
  }
  
  enum LastAction {
    case test
  }
}

// Test reducer for compilation tests
struct TestReducerForNestedActions: Reducer {
  struct State: Equatable {}
  typealias Action = NestedLockTestAction
  
  var body: some ReducerOf<Self> {
    EmptyReducer()
  }
}

// MARK: - Tests

final class NestedActionLockTests: XCTestCase {

  func testLockWithCasePathsCompiles() {
    // This test verifies that the lock() method with CasePaths compiles correctly
    let reducer = TestReducerForNestedActions()
    
    // Test 0 paths (root only)
    _ = reducer.lock(boundaryId: "test")
    
    // Test 1 path
    _ = reducer.lock(boundaryId: "test", for: \.nested)
    
    // Test 2 paths
    _ = reducer.lock(boundaryId: "test", for: \.nested, \.other)
    
    // Test 3 paths
    _ = reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more)
    
    // Test 4 paths
    _ = reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more, \.another)
    
    // Test 5 paths
    _ = reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more, \.another, \.last)
    
    XCTAssertTrue(true)
  }
  
  func testExtractorLogic() {
    // Test the extraction logic works correctly
    let rootAction = NestedLockTestAction.root
    let nestedAction = NestedLockTestAction.nested(.test)
    
    // Test root extraction - root action conforms to LockmanAction
    XCTAssertNotNil(rootAction as? any LockmanAction)
    
    // Test nested extraction
    if case .nested(let nested) = nestedAction {
      XCTAssertNotNil(nested as? any LockmanAction)
    } else {
      XCTFail("Failed to extract nested action")
    }
  }
}