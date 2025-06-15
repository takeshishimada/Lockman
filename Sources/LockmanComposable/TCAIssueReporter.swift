import ComposableArchitecture
import LockmanCore

/// TCA-specific implementation of Lockman's LockmanIssueReporter that uses TCA's reportIssue.
public enum TCAIssueReporter: LockmanCore.LockmanIssueReporter {
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    IssueReporting.reportIssue(message, fileID: file, line: line)
  }
}

/// Configures Lockman to use TCA's issue reporting.
public extension LockmanIssueReporting {
  /// Configures Lockman to use TCA's reportIssue function.
  static func configureTCAReporting() {
    reporter = TCAIssueReporter.self
  }
}
