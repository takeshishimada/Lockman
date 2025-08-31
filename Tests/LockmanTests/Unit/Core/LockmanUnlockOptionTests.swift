import XCTest

@testable import Lockman

// ✅ IMPLEMENTED: Comprehensive LockmanUnlockOption enum tests with 3-phase approach
// ✅ 12 test methods covering all enum cases, equality, and edge conditions
// ✅ Phase 1: Basic enum case testing (immediate, mainRunLoop, transition, delayed)
// ✅ Phase 2: Equality and Sendable conformance testing
// ✅ Phase 3: Documentation examples and edge cases

final class LockmanUnlockOptionTests: XCTestCase {

  override func setUp() {
    super.setUp()
    LockmanManager.cleanup.all()
  }

  override func tearDown() {
    super.tearDown()
    LockmanManager.cleanup.all()
  }

  // MARK: - Phase 1: Basic Enum Cases

  func testLockmanUnlockOptionImmediateCase() {
    // Test .immediate case
    let option = LockmanUnlockOption.immediate

    // Test pattern matching
    switch option {
    case .immediate:
      XCTAssertTrue(true)  // Immediate case matched
    default:
      XCTFail("Should match .immediate case")
    }
  }

  func testLockmanUnlockOptionMainRunLoopCase() {
    // Test .mainRunLoop case
    let option = LockmanUnlockOption.mainRunLoop

    // Test pattern matching
    switch option {
    case .mainRunLoop:
      XCTAssertTrue(true)  // MainRunLoop case matched
    default:
      XCTFail("Should match .mainRunLoop case")
    }
  }

  func testLockmanUnlockOptionTransitionCase() {
    // Test .transition case
    let option = LockmanUnlockOption.transition

    // Test pattern matching
    switch option {
    case .transition:
      XCTAssertTrue(true)  // Transition case matched
    default:
      XCTFail("Should match .transition case")
    }
  }

  func testLockmanUnlockOptionDelayedCase() {
    // Test .delayed case with various intervals
    let delayOptions: [LockmanUnlockOption] = [
      .delayed(0.5),
      .delayed(1.0),
      .delayed(2.5),
      .delayed(0.0),
    ]

    for (index, option) in delayOptions.enumerated() {
      switch option {
      case .delayed(let interval):
        switch index {
        case 0: XCTAssertEqual(interval, 0.5, accuracy: 0.001)
        case 1: XCTAssertEqual(interval, 1.0, accuracy: 0.001)
        case 2: XCTAssertEqual(interval, 2.5, accuracy: 0.001)
        case 3: XCTAssertEqual(interval, 0.0, accuracy: 0.001)
        default: XCTFail("Unexpected index")
        }
      default:
        XCTFail("Should match .delayed case for index \(index)")
      }
    }
  }

  // MARK: - Phase 2: Equatable Conformance

  func testLockmanUnlockOptionEquality() {
    // Test basic case equality
    XCTAssertEqual(LockmanUnlockOption.immediate, LockmanUnlockOption.immediate)
    XCTAssertEqual(LockmanUnlockOption.mainRunLoop, LockmanUnlockOption.mainRunLoop)
    XCTAssertEqual(LockmanUnlockOption.transition, LockmanUnlockOption.transition)

    // Test delayed case equality
    XCTAssertEqual(LockmanUnlockOption.delayed(1.0), LockmanUnlockOption.delayed(1.0))
    XCTAssertEqual(LockmanUnlockOption.delayed(0.5), LockmanUnlockOption.delayed(0.5))
    XCTAssertEqual(LockmanUnlockOption.delayed(0.0), LockmanUnlockOption.delayed(0.0))
  }

  func testLockmanUnlockOptionInequality() {
    // Test basic case inequality
    XCTAssertNotEqual(LockmanUnlockOption.immediate, LockmanUnlockOption.mainRunLoop)
    XCTAssertNotEqual(LockmanUnlockOption.immediate, LockmanUnlockOption.transition)
    XCTAssertNotEqual(LockmanUnlockOption.mainRunLoop, LockmanUnlockOption.transition)

    // Test delayed case inequality with different intervals
    XCTAssertNotEqual(LockmanUnlockOption.delayed(1.0), LockmanUnlockOption.delayed(2.0))
    XCTAssertNotEqual(LockmanUnlockOption.delayed(0.5), LockmanUnlockOption.delayed(1.5))

    // Test delayed vs other cases
    XCTAssertNotEqual(LockmanUnlockOption.delayed(1.0), LockmanUnlockOption.immediate)
    XCTAssertNotEqual(LockmanUnlockOption.delayed(0.5), LockmanUnlockOption.mainRunLoop)
    XCTAssertNotEqual(LockmanUnlockOption.delayed(2.0), LockmanUnlockOption.transition)
  }

  func testLockmanUnlockOptionDelayedFloatingPointEquality() {
    // Test floating-point equality edge cases
    let option1 = LockmanUnlockOption.delayed(0.1)
    let option2 = LockmanUnlockOption.delayed(0.1)
    let option3 = LockmanUnlockOption.delayed(0.10000000001)  // Very close but different

    XCTAssertEqual(option1, option2)
    // Note: Floating point equality in Swift is exact, so these should be different
    XCTAssertNotEqual(option1, option3)
  }

  // MARK: - Phase 3: Sendable Conformance

  func testLockmanUnlockOptionSendableConformance() async {
    // Test Sendable conformance with concurrent access
    let options: [LockmanUnlockOption] = [
      .immediate,
      .mainRunLoop,
      .transition,
      .delayed(1.0),
    ]

    await withTaskGroup(of: String.self) { group in
      for (index, option) in options.enumerated() {
        group.addTask {
          // This compiles without warning = Sendable works
          switch option {
          case .immediate:
            return "Task\(index): immediate"
          case .mainRunLoop:
            return "Task\(index): mainRunLoop"
          case .transition:
            return "Task\(index): transition"
          case .delayed(let interval):
            return "Task\(index): delayed(\(interval))"
          }
        }
      }

      var results: [String] = []
      for await result in group {
        results.append(result)
      }

      XCTAssertEqual(results.count, 4)
      XCTAssertTrue(results.contains("Task0: immediate"))
      XCTAssertTrue(results.contains("Task1: mainRunLoop"))
      XCTAssertTrue(results.contains("Task2: transition"))
      XCTAssertTrue(results.contains("Task3: delayed(1.0)"))
    }
  }

  // MARK: - Phase 4: Documentation Examples Verification

  func testLockmanUnlockOptionDocumentationExamples() {
    // Test examples that match the documentation comments

    // Example 1: Wait for screen transition animation (default)
    let transitionOption = LockmanUnlockOption.transition
    switch transitionOption {
    case .transition:
      XCTAssertTrue(true)  // Expected path for default UI coordination
    default:
      XCTFail("Documentation example should be .transition")
    }

    // Example 2: Immediate unlock when no UI transition
    let immediateOption = LockmanUnlockOption.immediate
    switch immediateOption {
    case .immediate:
      XCTAssertTrue(true)  // Expected path for immediate unlock
    default:
      XCTFail("Documentation example should be .immediate")
    }

    // Example 3: Defer until next main run loop cycle
    let mainRunLoopOption = LockmanUnlockOption.mainRunLoop
    switch mainRunLoopOption {
    case .mainRunLoop:
      XCTAssertTrue(true)  // Expected path for run loop deferral
    default:
      XCTFail("Documentation example should be .mainRunLoop")
    }

    // Example 4: Delay unlock by specific time interval
    let delayedOption = LockmanUnlockOption.delayed(1.5)
    switch delayedOption {
    case .delayed(let interval):
      XCTAssertEqual(interval, 1.5, accuracy: 0.001)
    default:
      XCTFail("Documentation example should be .delayed(1.5)")
    }
  }

  // MARK: - Phase 5: Edge Cases and Special Values

  func testLockmanUnlockOptionDelayedEdgeCases() {
    // Test edge case values for delayed option
    let edgeCases: [(TimeInterval, String)] = [
      (0.0, "zero delay"),
      (-1.0, "negative delay"),  // Swift allows this, implementation may handle
      (Double.infinity, "infinite delay"),
      (TimeInterval.greatestFiniteMagnitude, "maximum finite value"),
      (0.001, "very small positive delay"),
      (3600.0, "one hour delay"),
    ]

    for (interval, description) in edgeCases {
      let option = LockmanUnlockOption.delayed(interval)

      switch option {
      case .delayed(let actualInterval):
        XCTAssertEqual(
          actualInterval, interval, accuracy: 0.0001,
          "Failed for \(description): expected \(interval), got \(actualInterval)")
      default:
        XCTFail("Should be delayed case for \(description)")
      }
    }
  }

  func testLockmanUnlockOptionExhaustivePatternMatching() {
    // Test all cases in a comprehensive function
    let allOptions: [LockmanUnlockOption] = [
      .immediate,
      .mainRunLoop,
      .transition,
      .delayed(0.5),
      .delayed(1.0),
      .delayed(2.5),
    ]

    for (index, option) in allOptions.enumerated() {
      let result = classifyUnlockOption(option)

      switch index {
      case 0:
        XCTAssertEqual(result, "immediate_unlock", "Index 0 should be immediate")
      case 1:
        XCTAssertEqual(result, "main_run_loop_deferred", "Index 1 should be mainRunLoop")
      case 2:
        XCTAssertEqual(result, "transition_coordinated", "Index 2 should be transition")
      case 3, 4, 5:
        XCTAssertTrue(result.hasPrefix("delayed_"), "Index \(index) should be delayed")
      default:
        XCTFail("Unexpected index \(index)")
      }
    }
  }

  // Helper function for pattern matching test
  private func classifyUnlockOption(_ option: LockmanUnlockOption) -> String {
    switch option {
    case .immediate:
      return "immediate_unlock"
    case .mainRunLoop:
      return "main_run_loop_deferred"
    case .transition:
      return "transition_coordinated"
    case .delayed(let interval):
      return "delayed_\(interval)"
    }
  }

  // MARK: - Phase 6: Collection and Hashable Behavior

  func testLockmanUnlockOptionInCollections() {
    // Test behavior in collections (using Equatable conformance)
    let options: [LockmanUnlockOption] = [
      .immediate,
      .mainRunLoop,
      .transition,
      .delayed(1.0),
      .delayed(2.0),
      .immediate,  // duplicate
    ]

    XCTAssertEqual(options.count, 6)

    // Test filtering
    let immediateOptions = options.filter { option in
      if case .immediate = option { return true }
      return false
    }
    XCTAssertEqual(immediateOptions.count, 2)

    let delayedOptions = options.filter { option in
      if case .delayed = option { return true }
      return false
    }
    XCTAssertEqual(delayedOptions.count, 2)

    // Test contains (uses Equatable)
    XCTAssertTrue(options.contains(.immediate))
    XCTAssertTrue(options.contains(.mainRunLoop))
    XCTAssertTrue(options.contains(.transition))
    XCTAssertTrue(options.contains(.delayed(1.0)))
    XCTAssertTrue(options.contains(.delayed(2.0)))
    XCTAssertFalse(options.contains(.delayed(3.0)))
  }

}
