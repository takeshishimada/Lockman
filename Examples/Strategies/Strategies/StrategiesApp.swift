import ComposableArchitecture
import Lockman
import SwiftUI
import UIKit

@main
struct StrategiesApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  var body: some Scene {
    WindowGroup {
      ExamplesView(
        store: Store(initialState: ExamplesFeature.State()) {
          ExamplesFeature()
        }
      )
    }
  }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // Enable debug logging for Lockman
    #if DEBUG
      LockmanManager.debug.isLoggingEnabled = true
      print("🔧 Lockman debug logging enabled")
    #endif

    // Register strategies used in examples
    registerConcurrencyLimitedStrategies()
    registerGroupCoordinationStrategy()
    registerPriorityBasedStrategy()

    return true
  }

  private func registerConcurrencyLimitedStrategies() {
    // Register individual strategies safely (they might already be registered)
    do {
      try LockmanManager.container.register(LockmanConcurrencyLimitedStrategy.shared)
      print("✅ Registered LockmanConcurrencyLimitedStrategy")
    } catch {
      print("⚠️ LockmanConcurrencyLimitedStrategy already registered or error: \(error)")
    }

    do {
      try LockmanManager.container.register(LockmanSingleExecutionStrategy.shared)
      print("✅ Registered LockmanSingleExecutionStrategy")
    } catch {
      print("⚠️ LockmanSingleExecutionStrategy already registered or error: \(error)")
    }

    // Register the composite strategy used in ConcurrencyLimitedStrategy example
    let compositeStrategy = LockmanCompositeStrategy2(
      strategy1: LockmanSingleExecutionStrategy.shared,
      strategy2: LockmanConcurrencyLimitedStrategy.shared
    )

    // Debug: Print the strategy ID being registered
    print("📝 Registering CompositeStrategy2 with ID: \(compositeStrategy.strategyId)")

    do {
      try LockmanManager.container.register(compositeStrategy)
      print("✅ Registered CompositeStrategy2 for ConcurrencyLimitedStrategy")
    } catch {
      print("⚠️ CompositeStrategy2 already registered or error: \(error)")
    }
  }

  private func registerGroupCoordinationStrategy() {
    do {
      try LockmanManager.container.register(LockmanGroupCoordinationStrategy.shared)
      print("✅ Registered LockmanGroupCoordinationStrategy")
    } catch {
      print("⚠️ LockmanGroupCoordinationStrategy already registered or error: \(error)")
    }
  }

  private func registerPriorityBasedStrategy() {
    // Register individual strategies safely (they might already be registered)
    do {
      try LockmanManager.container.register(LockmanPriorityBasedStrategy.shared)
      print("✅ Registered LockmanPriorityBasedStrategy")
    } catch {
      print("⚠️ LockmanPriorityBasedStrategy already registered or error: \(error)")
    }

    // SingleExecutionStrategy is already registered in registerConcurrencyLimitedStrategies()

    // Register the composite strategy used in PriorityBasedStrategy example
    let compositeStrategy = LockmanCompositeStrategy2(
      strategy1: LockmanSingleExecutionStrategy.shared,
      strategy2: LockmanPriorityBasedStrategy.shared
    )

    // Debug: Print the strategy ID being registered
    print(
      "📝 Registering CompositeStrategy2 for PriorityBased with ID: \(compositeStrategy.strategyId)")

    do {
      try LockmanManager.container.register(compositeStrategy)
      print("✅ Registered CompositeStrategy2 for PriorityBasedStrategy")
    } catch {
      print("⚠️ CompositeStrategy2 for PriorityBased already registered or error: \(error)")
    }
  }
}
