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

/// Backward compatibility typealias.
@available(
  *, deprecated, renamed: "ComposableIssueReporter", message: "Use ComposableIssueReporter instead"
)
public typealias TCAIssueReporter = ComposableIssueReporter

/// Configures Lockman to use ComposableArchitecture's issue reporting.
extension LockmanIssueReporting {
  /// Configures Lockman to use ComposableArchitecture's reportIssue function.
  public static func configureComposableReporting() {
    reporter = ComposableIssueReporter.self
  }

  /// Backward compatibility method.
  @available(
    *, deprecated, renamed: "configureComposableReporting",
    message: "Use configureComposableReporting() instead"
  )
  public static func configureTCAReporting() {
    configureComposableReporting()
  }
}
