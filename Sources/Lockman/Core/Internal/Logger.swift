// https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Internal/Logger.swift

import OSLog

#if swift(<5.10)
  @MainActor(unsafe)
#else
  @preconcurrency @MainActor
#endif
internal final class Logger {
  internal static let shared = Logger()
  internal var isEnabled = false
  @Published internal var logs: [String] = []
  #if DEBUG
    @available(iOS 14, macOS 11, tvOS 14, watchOS 7, *)
    var logger: os.Logger {
      os.Logger(subsystem: "Lockman", category: "events")
    }

    internal func log(level: OSLogType = .default, _ string: @autoclosure () -> String) {
      guard self.isEnabled else {
        return
      }
      let string = string()
      if isRunningForPreviews {
        print("\(string)")
      } else {
        if #available(iOS 14, macOS 11, tvOS 14, watchOS 7, *) {
          self.logger.log(level: level, "\(string)")
        }
      }
      self.logs.append(string)
    }

    internal func clear() {
      self.logs = []
    }
  #else
    @inlinable @inline(__always)
    internal func log(level _: OSLogType = .default, _: @autoclosure () -> String) {}

    @inlinable @inline(__always)
    internal func clear() {}
  #endif
}

private let isRunningForPreviews =
  ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
