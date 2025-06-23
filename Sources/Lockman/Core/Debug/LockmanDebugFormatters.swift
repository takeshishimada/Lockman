import Foundation

/// Formatters for debug output
extension LockmanManager.debug {
  /// Options for formatting debug output
  public struct FormatOptions: Sendable {
    /// Whether to use short names for strategies
    public var useShortStrategyNames: Bool = true

    /// Whether to simplify boundary IDs
    public var simplifyBoundaryIds: Bool = true

    /// Maximum width for each column
    public var maxStrategyWidth: Int = 20
    public var maxBoundaryWidth: Int = 25
    public var maxActionIdWidth: Int = 36
    public var maxAdditionalWidth: Int = 20

    /// Default formatting options
    public static let `default` = FormatOptions()

    /// Compact formatting options for narrow terminals
    public static let compact = FormatOptions(
      useShortStrategyNames: true,
      simplifyBoundaryIds: true,
      maxStrategyWidth: 0,  // 0 means no limit
      maxBoundaryWidth: 0,
      maxActionIdWidth: 0,
      maxAdditionalWidth: 0
    )

    /// Detailed formatting options
    public static let detailed = FormatOptions(
      useShortStrategyNames: false,
      simplifyBoundaryIds: false,
      maxStrategyWidth: 40,
      maxBoundaryWidth: 50,
      maxActionIdWidth: 40,
      maxAdditionalWidth: 25
    )
  }

  /// Formats a strategy name according to options
  static func formatStrategyName(_ fullName: String, options: FormatOptions) -> String {
    guard options.useShortStrategyNames else {
      return fullName
    }

    // Remove module prefix
    let withoutModule = fullName.split(separator: ".").last.map(String.init) ?? fullName

    // Common strategy name mappings
    switch withoutModule {
    case "LockmanSingleExecutionStrategy":
      return "SingleExecution"
    case "LockmanPriorityBasedStrategy":
      return "PriorityBased"
    case "LockmanDynamicConditionStrategy":
      return "DynamicCondition"
    case "LockmanGroupCoordinatedStrategy":
      return "GroupCoordinated"
    default:
      // For other strategies, remove "Lockman" prefix and "Strategy" suffix
      var result = withoutModule
      if result.hasPrefix("Lockman") {
        result = String(result.dropFirst(7))
      }
      if result.hasSuffix("Strategy") {
        result = String(result.dropLast(8))
      }
      return result.isEmpty ? withoutModule : result
    }
  }

  /// Formats a boundary ID according to options
  static func formatBoundaryId(_ boundaryId: String, options: FormatOptions) -> String {
    // Always clean up the raw boundary ID format first
    var cleaned = boundaryId

    // Debug: print the input
    // print("DEBUG formatBoundaryId input: '\(boundaryId)'")

    // Handle AnyLockmanBoundaryId wrapper
    if cleaned.hasPrefix("AnyLockmanBoundaryId(base: "), cleaned.hasSuffix(")") {
      let content = String(cleaned.dropFirst(27).dropLast(1))
      // print("DEBUG after removing wrapper: '\(content)'")

      // Handle nested AnyHashable wrapper
      if content.hasPrefix("AnyHashable(") {
        // Extract content between AnyHashable( and the last )
        let innerStart = content.index(content.startIndex, offsetBy: 12)
        if let lastParen = content.lastIndex(of: ")") {
          let innerContent = String(content[innerStart..<lastParen])
          cleaned = innerContent
          // print("DEBUG after removing AnyHashable: '\(cleaned)'")
        }
      } else {
        cleaned = content
      }
    }

    // If not simplifying, return the cleaned version
    guard options.simplifyBoundaryIds else {
      return cleaned
    }

    // Apply simplification
    return formatBoundaryContent(cleaned, options: options)
  }

  /// Formats the inner content of a boundary ID
  private static func formatBoundaryContent(_ content: String, options _: FormatOptions) -> String {
    // Remove trailing parenthesis if present (common with enum cases)
    let cleanContent = content

    // Debug
    // print("DEBUG formatBoundaryContent input: '\(content)'")

    // Extract the meaningful part from enum cases
    // e.g., "Strategies.SingleExecutionStrategyFeature.CancelID.userAction" -> "CancelID.userAction"
    let components = cleanContent.split(separator: ".")

    if components.count >= 2 {
      // Take the last two components for enum cases
      let lastTwo = components.suffix(2).joined(separator: ".")

      // Special handling for common patterns
      if lastTwo.contains("CancelID") {
        return lastTwo
      }

      // For other cases, try to find the most meaningful part
      if let cancelIndex = components.firstIndex(where: { $0.contains("Cancel") }) {
        return components.suffix(from: cancelIndex).joined(separator: ".")
      }

      // Default: return last two components
      return lastTwo
    }

    return cleanContent
  }

  /// Prints current locks with custom formatting options
  public static func printCurrentLocks(options: FormatOptions = .default) {
    let container = LockmanManager.container
    var allLocks: [(strategy: String, boundaryId: String, info: any LockmanInfo)] = []

    // Collect all locks from all strategies
    for (strategyId, strategy) in container.getAllStrategies() {
      let currentLocks = strategy.getCurrentLocks()
      for (boundaryId, lockInfos) in currentLocks {
        for lockInfo in lockInfos {
          let boundaryIdString = String(describing: boundaryId)
          // Debug: print raw boundary ID
          // print("DEBUG: Raw boundaryId: '\(boundaryIdString)'")
          allLocks.append(
            (
              strategy: formatStrategyName(strategyId.value, options: options),
              boundaryId: formatBoundaryId(boundaryIdString, options: options),
              info: lockInfo
            ))
        }
      }
    }

    // If no locks, print a simple message
    if allLocks.isEmpty {
      print("No active locks")
      return
    }

    // Calculate column widths based on actual content
    // Header widths
    let strategyHeaderWidth = "Strategy".count
    let boundaryHeaderWidth = "BoundaryId".count
    let actionIdHeaderWidth = "ActionId/UniqueId".count
    let additionalHeaderWidth = "Additional Info".count

    // Content widths
    let maxStrategyContentWidth = allLocks.map(\.strategy.count).max() ?? 0
    let maxBoundaryContentWidth = allLocks.map(\.boundaryId.count).max() ?? 0
    let maxActionIdContentWidth = max(
      allLocks.map(\.info.actionId.count).max() ?? 0,
      36  // UUID width
    )
    let maxAdditionalContentWidth =
      allLocks.map { extractAdditionalInfo(from: $0.info).count }.max() ?? 0

    // Use the larger of header or content width, with optional max limits
    let strategyWidth: Int
    let boundaryWidth: Int
    let actionIdWidth: Int
    let additionalWidth: Int

    if options.maxStrategyWidth > 0 {
      strategyWidth = min(
        options.maxStrategyWidth, max(strategyHeaderWidth, maxStrategyContentWidth))
    } else {
      strategyWidth = max(strategyHeaderWidth, maxStrategyContentWidth)
    }

    if options.maxBoundaryWidth > 0 {
      boundaryWidth = min(
        options.maxBoundaryWidth, max(boundaryHeaderWidth, maxBoundaryContentWidth))
    } else {
      boundaryWidth = max(boundaryHeaderWidth, maxBoundaryContentWidth)
    }

    if options.maxActionIdWidth > 0 {
      actionIdWidth = min(
        options.maxActionIdWidth, max(actionIdHeaderWidth, maxActionIdContentWidth))
    } else {
      actionIdWidth = max(actionIdHeaderWidth, maxActionIdContentWidth)
    }

    if options.maxAdditionalWidth > 0 {
      additionalWidth = min(
        options.maxAdditionalWidth, max(additionalHeaderWidth, maxAdditionalContentWidth))
    } else {
      additionalWidth = max(additionalHeaderWidth, maxAdditionalContentWidth)
    }

    // Print table header
    let horizontalLine =
      "┌" + String(repeating: "─", count: strategyWidth + 2) + "┬"
      + String(repeating: "─", count: boundaryWidth + 2) + "┬"
      + String(repeating: "─", count: actionIdWidth + 2) + "┬"
      + String(repeating: "─", count: additionalWidth + 2) + "┐"

    let headerSeparator =
      "├" + String(repeating: "─", count: strategyWidth + 2) + "┼"
      + String(repeating: "─", count: boundaryWidth + 2) + "┼"
      + String(repeating: "─", count: actionIdWidth + 2) + "┼"
      + String(repeating: "─", count: additionalWidth + 2) + "┤"

    let rowSeparator =
      "├" + String(repeating: "─", count: strategyWidth + 2) + "┼"
      + String(repeating: "─", count: boundaryWidth + 2) + "┼"
      + String(repeating: "─", count: actionIdWidth + 2) + "┼"
      + String(repeating: "─", count: additionalWidth + 2) + "┤"

    let bottomLine =
      "└" + String(repeating: "─", count: strategyWidth + 2) + "┴"
      + String(repeating: "─", count: boundaryWidth + 2) + "┴"
      + String(repeating: "─", count: actionIdWidth + 2) + "┴"
      + String(repeating: "─", count: additionalWidth + 2) + "┘"

    print(horizontalLine)
    print(
      "│ \(pad("Strategy", to: strategyWidth)) │ \(pad("BoundaryId", to: boundaryWidth)) │ \(pad("ActionId/UniqueId", to: actionIdWidth)) │ \(pad("Additional Info", to: additionalWidth)) │"
    )
    print(headerSeparator)

    // Print each lock
    for (index, lock) in allLocks.enumerated() {
      let info = lock.info
      let actionId = info.actionId
      let uniqueId = info.uniqueId.uuidString

      // Extract additional info based on lock type
      let additionalInfo = extractAdditionalInfo(from: info)

      // Handle composite info display
      if let compositeInfo = info as? any LockmanCompositeInfo {
        // First line: strategy and boundary with action ID
        print(
          "│ \(pad(lock.strategy, to: strategyWidth)) │ \(pad(lock.boundaryId, to: boundaryWidth)) │ \(pad(actionId, to: actionIdWidth)) │ \(pad("Composite", to: additionalWidth)) │"
        )
        // Second line: unique ID
        print(
          "│ \(pad("", to: strategyWidth)) │ \(pad("", to: boundaryWidth)) │ \(pad(uniqueId, to: actionIdWidth)) │ \(pad("", to: additionalWidth)) │"
        )

        // Print sub-strategies info
        let subInfos = compositeInfo.allInfos()
        for (_, subInfo) in subInfos.enumerated() {
          let subStrategy = formatStrategyName(getStrategyName(for: subInfo), options: options)
          let subActionId = subInfo.actionId
          let subUniqueId = subInfo.uniqueId.uuidString
          let subAdditionalInfo = extractAdditionalInfo(from: subInfo)

          // Sub-strategy first line with indentation
          print(
            "│ \(pad("  " + subStrategy, to: strategyWidth)) │ \(pad("", to: boundaryWidth)) │ \(pad(subActionId, to: actionIdWidth)) │ \(pad(subAdditionalInfo, to: additionalWidth)) │"
          )
          // Sub-strategy second line
          print(
            "│ \(pad("", to: strategyWidth)) │ \(pad("", to: boundaryWidth)) │ \(pad(subUniqueId, to: actionIdWidth)) │ \(pad("", to: additionalWidth)) │"
          )
        }
      } else {
        // Regular info display
        // First line: strategy and boundary with action ID
        print(
          "│ \(pad(lock.strategy, to: strategyWidth)) │ \(pad(lock.boundaryId, to: boundaryWidth)) │ \(pad(actionId, to: actionIdWidth)) │ \(pad(additionalInfo, to: additionalWidth)) │"
        )
        // Second line: unique ID
        print(
          "│ \(pad("", to: strategyWidth)) │ \(pad("", to: boundaryWidth)) │ \(pad(uniqueId, to: actionIdWidth)) │ \(pad("", to: additionalWidth)) │"
        )
      }

      // Add separator between entries (except for the last one)
      if index < allLocks.count - 1 {
        print(rowSeparator)
      }
    }

    print(bottomLine)
  }

  // MARK: - Private Helpers

  /// Pads a string to the specified width.
  private static func pad(_ string: String, to width: Int) -> String {
    if string.count >= width {
      return String(string.prefix(width))
    }
    return string + String(repeating: " ", count: width - string.count)
  }

  /// Extracts additional information from lock info based on its type.
  private static func extractAdditionalInfo(from info: any LockmanInfo) -> String {
    switch info {
    case let singleExecution as LockmanSingleExecutionInfo:
      return "mode: \(singleExecution.mode)"

    case let priorityBased as LockmanPriorityBasedInfo:
      let priority = priorityBased.priority
      var result = "priority: \(priority)"
      if let behavior = priority.behavior {
        let behaviorStr = behavior == .exclusive ? ".exclusive" : ".replaceable"
        result = String(result.prefix(20 - 13)) + " b: " + behaviorStr
      }
      return result

    case is LockmanDynamicConditionInfo:
      return "condition: <closure>"

    case let groupCoordinated as LockmanGroupCoordinatedInfo:
      let groupsStr = groupCoordinated.groupIds.map { "\($0)" }.sorted().joined(separator: ",")
      return "groups: \(groupsStr) r: \(groupCoordinated.coordinationRole)"

    case is any LockmanCompositeInfo:
      return "Composite"

    default:
      return ""
    }
  }

  /// Gets the strategy name for a given lock info type.
  private static func getStrategyName(for info: any LockmanInfo) -> String {
    switch info {
    case is LockmanSingleExecutionInfo:
      return "SingleExecution"
    case is LockmanPriorityBasedInfo:
      return "PriorityBased"
    case is LockmanDynamicConditionInfo:
      return "DynamicCondition"
    case is LockmanGroupCoordinatedInfo:
      return "GroupCoordination"
    default:
      return "Unknown"
    }
  }
}
