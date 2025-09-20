import ComposableArchitecture

/// Composable Architecture specific implementation of LockmanIssueReporter that uses ComposableArchitecture's reportIssue.
public enum LockmanComposableIssueReporter: LockmanIssueReporter {
  public static func reportIssue(
    _ message: String,
    file: StaticString = #fileID,
    line: UInt = #line
  ) {
    IssueReporting.reportIssue(message, fileID: file, line: line)
  }
}

/// Configures Lockman to use ComposableArchitecture's issue reporting.
extension LockmanManager.config {
  /// Configures Lockman to use ComposableArchitecture's issue reporting system.
  ///
  /// This sets the global issue reporter to use TCA's `IssueReporting.reportIssue`
  /// for consistent error reporting integration with ComposableArchitecture.
  ///
  /// ```swift
  /// // In App initialization
  /// LockmanManager.config.configureComposableReporting()
  /// ```
  public static func configureComposableReporting() {
    issueReporter = LockmanComposableIssueReporter.self
  }
}
