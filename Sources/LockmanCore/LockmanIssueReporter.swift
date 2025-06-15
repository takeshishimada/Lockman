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
  public nonisolated(unsafe) static var reporter: any LockmanIssueReporter.Type = DefaultLockmanIssueReporter.self

  /// Reports an issue using the configured reporter.
  @inlinable
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    reporter.reportIssue(message, file: file, line: line)
  }
}
