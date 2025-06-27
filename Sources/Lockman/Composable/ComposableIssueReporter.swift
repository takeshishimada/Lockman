import ComposableArchitecture

/// Composable Architecture specific implementation of Lockman's LockmanIssueReporter that uses ComposableArchitecture's reportIssue.
public enum ComposableIssueReporter: LockmanIssueReporter {
  public static func reportIssue(
    _ message: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    IssueReporting.reportIssue(message, fileID: file, line: line)
  }
}

/// Configures Lockman to use ComposableArchitecture's issue reporting.
extension LockmanIssueReporting {
  /// Configures Lockman to use ComposableArchitecture's reportIssue function.
  public static func configureComposableReporting() {
    reporter = ComposableIssueReporter.self
  }
}
