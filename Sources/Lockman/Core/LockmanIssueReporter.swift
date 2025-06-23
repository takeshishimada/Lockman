import Foundation

/// Protocol for reporting issues in the Lockman framework.
///
/// This abstraction allows the core framework to report issues without
/// depending on external frameworks like TCA.
public protocol LockmanIssueReporter {
  /// Reports an issue with a custom message.
  ///
  /// - Parameters:
  ///   - message: The issue message to report
  ///   - file: The file where the issue occurred
  ///   - line: The line number where the issue occurred
  static func reportIssue(
    _ message: String,
    file: StaticString,
    line: UInt
  )
}

/// Default Lockman issue reporter that prints to console in debug builds.
public enum DefaultLockmanIssueReporter: LockmanIssueReporter {
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    #if DEBUG
      let fileName = "\(file)".split(separator: "/").last ?? "Unknown"
      print("⚠️ Lockman Issue [\(fileName):\(line)]: \(message)")
    #endif
  }
}

/// Global issue reporter configuration.
public enum LockmanIssueReporting {
  /// The current issue reporter. Defaults to `DefaultIssueReporter`.
  private static let _reporter = LockIsolated<any LockmanIssueReporter.Type>(
    DefaultLockmanIssueReporter.self)

  public static var reporter: any LockmanIssueReporter.Type {
    get { _reporter.value }
    set { _reporter.withValue { $0 = newValue } }
  }

  /// Reports an issue using the configured reporter.
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    reporter.reportIssue(message, file: file, line: line)
  }
}

/// A simple lock-isolated wrapper for thread-safe access to values.
private final class LockIsolated<Value>: @unchecked Sendable {
  private var _value: Value
  private let lock = NSLock()

  init(_ value: Value) {
    self._value = value
  }

  var value: Value {
    lock.lock()
    defer { lock.unlock() }
    return _value
  }

  func withValue<T>(_ operation: (inout Value) throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try operation(&_value)
  }
}
