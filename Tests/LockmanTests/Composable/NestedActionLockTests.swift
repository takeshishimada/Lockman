import CasePaths
import ComposableArchitecture
import XCTest

@testable import Lockman

// MARK: - Tests

final class NestedActionLockTests: XCTestCase {

  func testLockWithCasePathsCompiles() {
    // This test verifies that the lock() method with CasePaths compiles correctly
    // The actual functionality is tested through integration tests
    
    // Test 1 path
    _ = { (reducer: some Reducer<TestState, TestAction>) in
      reducer.lock(boundaryId: "test", for: \.nested)
    }
    
    // Test 2 paths
    _ = { (reducer: some Reducer<TestState, TestAction>) in
      reducer.lock(boundaryId: "test", for: \.nested, \.other)
    }
    
    // Test 3 paths
    _ = { (reducer: some Reducer<TestState, TestAction>) in
      reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more)
    }
    
    // Test 4 paths
    _ = { (reducer: some Reducer<TestState, TestAction>) in
      reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more, \.another)
    }
    
    // Test 5 paths
    _ = { (reducer: some Reducer<TestState, TestAction>) in
      reducer.lock(boundaryId: "test", for: \.nested, \.other, \.more, \.another, \.last)
    }
    
    XCTAssertTrue(true)
  }
  
  func testExtractorLogic() {
    // Test the extraction logic works correctly
    let rootAction = TestAction.root
    let nestedAction = TestAction.nested(.test)
    
    // Test root extraction
    let rootExtractor: (TestAction) -> (any LockmanAction)? = { action in
      action as? any LockmanAction
    }
    
    XCTAssertNotNil(rootExtractor(rootAction))
    XCTAssertNotNil(rootExtractor(nestedAction)) // Root action conforms
    
    // Test nested extraction
    let nestedExtractor: (TestAction) -> (any LockmanAction)? = { action in
      if let lockmanAction = action as? any LockmanAction {
        return lockmanAction
      }
      if case .nested(let nested) = action {
        return nested as? any LockmanAction
      }
      return nil
    }
    
    XCTAssertNotNil(nestedExtractor(nestedAction))
  }
}

// MARK: - Test Types

struct TestState: Equatable {}

@CasePathable
enum TestAction: LockmanAction {
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