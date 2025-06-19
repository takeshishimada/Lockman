import ComposableArchitecture
import LockmanCore

/// Composable Architecture-specific implementation of Lockman's LockmanIssueReporter that uses TCA's reportIssue.
public enum ComposableIssueReporter: LockmanCore.LockmanIssueReporter {
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    IssueReporting.reportIssue(message, fileID: file, line: line)
  }
}

/// Configures Lockman to use The Composable Architecture's issue reporting.
public extension LockmanIssueReporting {
  /// Configures Lockman to use The Composable Architecture's reportIssue function.
  static func configureComposableReporting() {
    reporter = ComposableIssueReporter.self
  }
}
