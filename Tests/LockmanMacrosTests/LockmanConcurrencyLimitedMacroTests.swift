import MacroTesting
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import XCTest

@testable import LockmanMacros

// MARK: - LockmanConcurrencyLimitedMacro Tests

final class LockmanConcurrencyLimitedMacroTests: XCTestCase {
  override func invokeTest() {
    // Configure macro testing to not record and to show diffs
    withMacroTesting(
      record: false,
      macros: [
        "LockmanConcurrencyLimited": LockmanConcurrencyLimitedMacro.self
      ]
    ) {
      super.invokeTest()
    }
  }

  // MARK: - Basic Expansion Tests

  func testBasicEnumExpansion() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum ViewAction {
        case fetchUserProfile
        case uploadFile
      }
      """
    } expansion: {
      """
      enum ViewAction {
        case fetchUserProfile
        case uploadFile

        internal var actionName: String {
          switch self {
          case .fetchUserProfile:
            return "fetchUserProfile"
          case .uploadFile:
            return "uploadFile"
          }
        }
      }

      extension ViewAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  func testEnumWithAssociatedValues() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum ViewAction {
        case fetchUserProfile(userId: String)
        case uploadFile(name: String, size: Int)
        case processData
      }
      """
    } expansion: {
      """
      enum ViewAction {
        case fetchUserProfile(userId: String)
        case uploadFile(name: String, size: Int)
        case processData

        internal var actionName: String {
          switch self {
          case .fetchUserProfile(_):
            return "fetchUserProfile"
          case .uploadFile(_, _):
            return "uploadFile"
          case .processData:
            return "processData"
          }
        }
      }

      extension ViewAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  // MARK: - Access Level Tests

  func testPublicEnumExpansion() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      public enum ViewAction {
        case fetchData
        case saveData
      }
      """
    } expansion: {
      """
      public enum ViewAction {
        case fetchData
        case saveData

        public var actionName: String {
          switch self {
          case .fetchData:
            return "fetchData"
          case .saveData:
            return "saveData"
          }
        }
      }

      extension ViewAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  func testInternalEnumExpansion() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      internal enum ViewAction {
        case action1
        case action2
      }
      """
    } expansion: {
      """
      internal enum ViewAction {
        case action1
        case action2

        internal var actionName: String {
          switch self {
          case .action1:
            return "action1"
          case .action2:
            return "action2"
          }
        }
      }

      extension ViewAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  // MARK: - Edge Case Tests

  func testEmptyEnum() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum EmptyAction {
      }
      """
    } expansion: {
      """
      enum EmptyAction {
      }

      extension EmptyAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  func testSingleCaseEnum() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum SingleAction {
        case onlyAction
      }
      """
    } expansion: {
      """
      enum SingleAction {
        case onlyAction

        internal var actionName: String {
          switch self {
          case .onlyAction:
            return "onlyAction"
          }
        }
      }

      extension SingleAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  func testComplexAssociatedValues() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum ComplexAction {
        case simple
        case withTuple((Int, String))
        case withClosure(() -> Void)
        case withOptional(String?)
        case withMultiple(a: Int, b: String, c: Bool)
      }
      """
    } expansion: {
      """
      enum ComplexAction {
        case simple
        case withTuple((Int, String))
        case withClosure(() -> Void)
        case withOptional(String?)
        case withMultiple(a: Int, b: String, c: Bool)

        internal var actionName: String {
          switch self {
          case .simple:
            return "simple"
          case .withTuple(_):
            return "withTuple"
          case .withClosure(_):
            return "withClosure"
          case .withOptional(_):
            return "withOptional"
          case .withMultiple(_, _, _):
            return "withMultiple"
          }
        }
      }

      extension ComplexAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  // MARK: - Error Cases

  func testMacroOnStruct() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      struct ViewAction {
        let name: String
      }
      """
    } diagnostics: {
      """
      @LockmanConcurrencyLimited
      ┬─────────────────────────
      ╰─ 🛑 @LockmanConcurrencyLimited can only be attached to an enum declaration.
      struct ViewAction {
        let name: String
      }
      """
    }
  }

  func testMacroOnClass() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      class ViewAction {
        var name: String = ""
      }
      """
    } diagnostics: {
      """
      @LockmanConcurrencyLimited
      ┬─────────────────────────
      ╰─ 🛑 @LockmanConcurrencyLimited can only be attached to an enum declaration.
      class ViewAction {
        var name: String = ""
      }
      """
    }
  }

  func testMacroOnProtocol() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      protocol ViewAction {
        var name: String { get }
      }
      """
    } diagnostics: {
      """
      @LockmanConcurrencyLimited
      ┬─────────────────────────
      ╰─ 🛑 @LockmanConcurrencyLimited can only be attached to an enum declaration.
      protocol ViewAction {
        var name: String { get }
      }
      """
    }
  }

  // MARK: - Integration Tests

  func testRealWorldExample() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      public enum FeatureAction {
        case fetchUserProfile(userId: String)
        case fetchUserPosts(userId: String, page: Int)
        case uploadImage(data: Data, metadata: [String: Any])
        case deletePost(postId: String)
        case refreshFeed
      }
      """
    } expansion: {
      """
      public enum FeatureAction {
        case fetchUserProfile(userId: String)
        case fetchUserPosts(userId: String, page: Int)
        case uploadImage(data: Data, metadata: [String: Any])
        case deletePost(postId: String)
        case refreshFeed

        public var actionName: String {
          switch self {
          case .fetchUserProfile(_):
            return "fetchUserProfile"
          case .fetchUserPosts(_, _):
            return "fetchUserPosts"
          case .uploadImage(_, _):
            return "uploadImage"
          case .deletePost(_):
            return "deletePost"
          case .refreshFeed:
            return "refreshFeed"
          }
        }
      }

      extension FeatureAction: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }

  // MARK: - Multi-case Declaration Tests

  func testMultipleCasesInOneDeclaration() {
    assertMacro {
      """
      @LockmanConcurrencyLimited
      enum Action {
        case a, b, c
        case d(Int), e(String)
      }
      """
    } expansion: {
      """
      enum Action {
        case a, b, c
        case d(Int), e(String)

        internal var actionName: String {
          switch self {
          case .a:
            return "a"
          case .b:
            return "b"
          case .c:
            return "c"
          case .d(_):
            return "d"
          case .e(_):
            return "e"
          }
        }
      }

      extension Action: LockmanConcurrencyLimitedAction {
      }
      """
    }
  }
}
