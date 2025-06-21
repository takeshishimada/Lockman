
import Foundation
import XCTest
@testable import LockmanCore

/// Tests for LockmanCompositeAction protocols and their implementations
final class LockmanCompositeActionTests: XCTestCase {
  // MARK: - Mock Composite Actions

  struct MockCompositeAction2: LockmanCompositeAction2 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy

    let actionName = "mockComposite2"

    var strategyId: LockmanStrategyId {
      LockmanStrategyId(name: "MockComposite2")
    }

    var lockmanInfo: LockmanCompositeInfo2<I1, I2> {
      LockmanCompositeInfo2(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: actionName, priority: .high(.exclusive))
      )
    }
  }

  struct MockCompositeAction3: LockmanCompositeAction3 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanSingleExecutionInfo
    typealias S3 = LockmanSingleExecutionStrategy

    let actionName = "mockComposite3"

    var strategyId: LockmanStrategyId {
      LockmanStrategyId(name: "MockComposite3")
    }

    var lockmanInfo: LockmanCompositeInfo3<I1, I2, I3> {
      LockmanCompositeInfo3(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "\(actionName)-1", mode: .boundary),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "\(actionName)-2", priority: .low(.replaceable)),
        lockmanInfoForStrategy3: LockmanSingleExecutionInfo(actionId: "\(actionName)-3", mode: .boundary)
      )
    }
  }

  struct MockCompositeAction4: LockmanCompositeAction4 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanSingleExecutionInfo
    typealias S3 = LockmanSingleExecutionStrategy
    typealias I4 = LockmanPriorityBasedInfo
    typealias S4 = LockmanPriorityBasedStrategy

    let actionName = "mockComposite4"

    var strategyId: LockmanStrategyId {
      LockmanStrategyId(name: "MockComposite4")
    }

    var lockmanInfo: LockmanCompositeInfo4<I1, I2, I3, I4> {
      LockmanCompositeInfo4(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "\(actionName)-1", mode: .boundary),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "\(actionName)-2", priority: .none),
        lockmanInfoForStrategy3: LockmanSingleExecutionInfo(actionId: "\(actionName)-3", mode: .boundary),
        lockmanInfoForStrategy4: LockmanPriorityBasedInfo(actionId: "\(actionName)-4", priority: .high(.replaceable))
      )
    }
  }

  struct MockCompositeAction5: LockmanCompositeAction5 {
    typealias I1 = LockmanSingleExecutionInfo
    typealias S1 = LockmanSingleExecutionStrategy
    typealias I2 = LockmanPriorityBasedInfo
    typealias S2 = LockmanPriorityBasedStrategy
    typealias I3 = LockmanSingleExecutionInfo
    typealias S3 = LockmanSingleExecutionStrategy
    typealias I4 = LockmanPriorityBasedInfo
    typealias S4 = LockmanPriorityBasedStrategy
    typealias I5 = LockmanSingleExecutionInfo
    typealias S5 = LockmanSingleExecutionStrategy

    let actionName = "mockComposite5"

    var strategyId: LockmanStrategyId {
      LockmanStrategyId(name: "MockComposite5")
    }

    var lockmanInfo: LockmanCompositeInfo5<I1, I2, I3, I4, I5> {
      LockmanCompositeInfo5(
        actionId: actionName,
        lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: "\(actionName)-1", mode: .boundary),
        lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: "\(actionName)-2", priority: .low(.exclusive)),
        lockmanInfoForStrategy3: LockmanSingleExecutionInfo(actionId: "\(actionName)-3", mode: .boundary),
        lockmanInfoForStrategy4: LockmanPriorityBasedInfo(actionId: "\(actionName)-4", priority: .high(.exclusive)),
        lockmanInfoForStrategy5: LockmanSingleExecutionInfo(actionId: "\(actionName)-5", mode: .boundary)
      )
    }
  }

  // MARK: - CompositeAction2 Tests

  func testcompositeAction2ProtocolConformance() {
    let action = MockCompositeAction2()

    // Test actionName
    XCTAssertEqual(action.actionName, "mockComposite2")

    // Test strategy ID
    XCTAssertEqual(action.strategyId.value, "MockComposite2")

    // Test lockmanInfo
    let lockmanInfo  = action.lockmanInfo
    XCTAssertEqual(lockmanInfo.actionId, "mockComposite2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.priority, .high(.exclusive))

    // Test strategy info via lockmanInfo
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.priority, .high(.exclusive))
  }

  func testcompositeAction2MakeCompositeStrategy() {
    let action  = MockCompositeAction2()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()

    // Test makeCompositeStrategy
    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2
    )

    // Verify it returns an AnyLockmanStrategy
    XCTAssertTrue(type(of: compositeStrategy) == AnyLockmanStrategy<LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo>>.self)

    // Test that the composite strategy works
    let boundaryId = "test-boundary"
    let info = action.lockmanInfo

    XCTAssertEqual(compositeStrategy.canLock(id: boundaryId, info: info), .success)
    compositeStrategy.lock(id: boundaryId, info: info)
    XCTAssertLockFailure(compositeStrategy.canLock(id: boundaryId, info: info))
    compositeStrategy.unlock(id: boundaryId, info: info)
    XCTAssertEqual(compositeStrategy.canLock(id: boundaryId, info: info), .success)
  }

  // MARK: - CompositeAction3 Tests

  func testcompositeAction3ProtocolConformance() {
    let action = MockCompositeAction3()

    // Test actionName
    XCTAssertEqual(action.actionName, "mockComposite3")

    // Test lockmanInfo
    let lockmanInfo  = action.lockmanInfo
    XCTAssertEqual(lockmanInfo.actionId, "mockComposite3")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite3-1")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite3-2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.priority, .low(.replaceable))
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy3.actionId, "mockComposite3-3")

    // Test strategy info via lockmanInfo
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite3-1")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite3-2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy3.actionId, "mockComposite3-3")
  }

  func testcompositeAction3MakeCompositeStrategy() {
    let action  = MockCompositeAction3()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanSingleExecutionStrategy()

    // Test makeCompositeStrategy
    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3
    )

    // Test that the composite strategy works
    let boundaryId = "test-boundary"
    let info = action.lockmanInfo

    XCTAssertEqual(compositeStrategy.canLock(id: boundaryId, info: info), .success)
    compositeStrategy.lock(id: boundaryId, info: info)
    compositeStrategy.cleanUp()
  }

  // MARK: - CompositeAction4 Tests

  func testcompositeAction4ProtocolConformance() {
    let action = MockCompositeAction4()

    // Test actionName
    XCTAssertEqual(action.actionName, "mockComposite4")

    // Test lockmanInfo
    let lockmanInfo  = action.lockmanInfo
    XCTAssertEqual(lockmanInfo.actionId, "mockComposite4")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite4-1")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite4-2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.priority, .none)
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy3.actionId, "mockComposite4-3")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy4.actionId, "mockComposite4-4")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy4.priority, .high(.replaceable))
  }

  func testcompositeAction4MakeCompositeStrategy() {
    let action  = MockCompositeAction4()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanSingleExecutionStrategy()
    let strategy4 = LockmanPriorityBasedStrategy()

    // Test makeCompositeStrategy
    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4
    )

    // Test that the composite strategy works
    let boundaryId = "test-boundary"
    let info = action.lockmanInfo

    XCTAssertEqual(compositeStrategy.canLock(id: boundaryId, info: info), .success)
  }

  // MARK: - CompositeAction5 Tests

  func testcompositeAction5ProtocolConformance() {
    let action = MockCompositeAction5()

    // Test actionName
    XCTAssertEqual(action.actionName, "mockComposite5")

    // Test lockmanInfo
    let lockmanInfo  = action.lockmanInfo
    XCTAssertEqual(lockmanInfo.actionId, "mockComposite5")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy1.actionId, "mockComposite5-1")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.actionId, "mockComposite5-2")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy2.priority, .low(.exclusive))
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy3.actionId, "mockComposite5-3")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy4.actionId, "mockComposite5-4")
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy4.priority, .high(.exclusive))
    XCTAssertEqual(lockmanInfo.lockmanInfoForStrategy5.actionId, "mockComposite5-5")
  }

  func testcompositeAction5MakeCompositeStrategy() {
    let action  = MockCompositeAction5()
    let strategy1 = LockmanSingleExecutionStrategy()
    let strategy2 = LockmanPriorityBasedStrategy()
    let strategy3 = LockmanSingleExecutionStrategy()
    let strategy4 = LockmanPriorityBasedStrategy()
    let strategy5 = LockmanSingleExecutionStrategy()

    // Test makeCompositeStrategy
    let compositeStrategy = action.makeCompositeStrategy(
      strategy1: strategy1,
      strategy2: strategy2,
      strategy3: strategy3,
      strategy4: strategy4,
      strategy5: strategy5
    )

    // Test that the composite strategy works
    let boundaryId = "test-boundary"
    let info = action.lockmanInfo

    let result = compositeStrategy.canLock(id: boundaryId, info: info)
    XCTAssertEqual(result, .success)

    // Cleanup
    compositeStrategy.cleanUp(id: boundaryId)
  }

  // MARK: - LockmanAction Protocol Tests

  func testcompositeActionsConformToLockmanAction() {
    // Test that all composite actions are LockmanAction
    let action2: any LockmanAction  = MockCompositeAction2()
    let action3: any LockmanAction = MockCompositeAction3()
    let action4: any LockmanAction = MockCompositeAction4()
    let action5: any LockmanAction = MockCompositeAction5()

    // Verify they can be stored as LockmanAction protocol type
    let actions: [any LockmanAction] = [action2, action3, action4, action5]
    XCTAssertEqual(actions.count, 4)

    // Verify we can access protocol requirements
    XCTAssertNotNil(action2.lockmanInfo as? LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> )
    XCTAssertNotNil(action3.lockmanInfo as? LockmanCompositeInfo3<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanSingleExecutionInfo> )
    XCTAssertNotNil(action4.lockmanInfo as? LockmanCompositeInfo4<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> )
    XCTAssertNotNil(action5.lockmanInfo as? LockmanCompositeInfo5<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanSingleExecutionInfo, LockmanPriorityBasedInfo, LockmanSingleExecutionInfo> )
  }
}
