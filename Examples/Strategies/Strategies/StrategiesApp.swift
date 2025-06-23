import ComposableArchitecture
import LockmanComposable
import LockmanCore
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
      Lockman.debug.isLoggingEnabled = true
      print("🔧 Lockman debug logging enabled")
    #endif

    CompositeStrategyInjection.inject()
    return true
  }
}
