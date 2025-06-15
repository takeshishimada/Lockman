import Foundation

/// Protocol for actions that use group coordination locking behavior.
///
/// This protocol extends `LockmanAction` to provide convenient support for
/// group-coordinated locking. Actions conforming to this protocol automatically
/// use the `LockmanGroupCoordinationStrategy` and provide group-specific information.
///
/// ## Single Group Example
/// ```swift
/// // Navigation leader action
/// struct NavigateToDetailAction: LockmanGroupCoordinatedAction {
///   let groupId = "navigation"
///   let coordinationRole = GroupCoordinationRole.leader
///
///   var actionName: String { "navigateToDetail" }
/// }
/// ```
///
/// ## Multiple Groups Example
/// ```swift
/// // Complex action belonging to multiple groups
/// struct ComplexDataLoadAction: LockmanGroupCoordinatedAction {
///   let groupIds: Set<String> = ["navigation", "dataLoading", "ui"]
///   let coordinationRole = GroupCoordinationRole.member
///
///   var actionName: String { "complexDataLoad" }
/// }
/// ```
///
/// ## Parameterized Actions
/// ```swift
/// enum DataLoadingAction: LockmanGroupCoordinatedAction {
///   case startLoading(dataId: String)
///   case updateProgress(dataId: String, progress: Double)
///   case showError(dataId: String, error: Error)
///
///   var groupId: String {
///     switch self {
///     case .startLoading(let dataId),
///          .updateProgress(let dataId, _),
///          .showError(let dataId, _):
///       return "dataLoading-\(dataId)"
///     }
///   }
///
///   var coordinationRole: GroupCoordinationRole {
///     switch self {
///     case .startLoading:
///       return .leader
///     case .updateProgress, .showError:
///       return .member
///     }
///   }
///
///   var actionName: String {
///     switch self {
///     case .startLoading:
///       return "startLoading"
///     case .updateProgress:
///       return "updateProgress"
///     case .showError:
///       return "showError"
///     }
///   }
/// }
/// ```
public protocol LockmanGroupCoordinatedAction: LockmanAction where I == LockmanGroupCoordinatedInfo {
  /// The name identifier for this action.
  ///
  /// Used as the `actionId` in the lock information.
  /// Actions with the same name within the same group cannot execute concurrently.
  var actionName: String { get }

  /// The coordination role of this action.
  ///
  /// Determines when this action can execute relative to the group's state:
  /// - `.leader`: Can only execute when the group is empty
  /// - `.member`: Can only execute when the group has active participants
  var coordinationRole: GroupCoordinationRole { get }
}

// MARK: - Default Implementations

public extension LockmanGroupCoordinatedAction {
  /// The strategy identifier for group coordination.
  var strategyId: LockmanStrategyId {
    .groupCoordination
  }
}

// MARK: - Single Group Support

/// Extension for actions that belong to a single group.
public extension LockmanGroupCoordinatedAction where Self: LockmanSingleGroupAction {
  var lockmanInfo: LockmanGroupCoordinatedInfo {
    LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(actionName),
      groupId: groupId,
      coordinationRole: coordinationRole
    )
  }
}

/// Protocol for actions that belong to a single group.
public protocol LockmanSingleGroupAction {
  /// The group identifier this action belongs to.
  var groupId: String { get }
}

// MARK: - Multiple Groups Support

/// Extension for actions that belong to multiple groups.
public extension LockmanGroupCoordinatedAction where Self: LockmanMultipleGroupsAction {
  var lockmanInfo: LockmanGroupCoordinatedInfo {
    LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(actionName),
      groupIds: groupIds,
      coordinationRole: coordinationRole
    )
  }
}

/// Protocol for actions that belong to multiple groups.
public protocol LockmanMultipleGroupsAction {
  /// The group identifiers this action belongs to.
  var groupIds: Set<String> { get }
}

// MARK: - Dynamic Property Detection

extension LockmanGroupCoordinatedAction {
  /// Attempts to dynamically retrieve a property value using reflection.
  ///
  /// This method is used internally for fallback behavior when explicit protocol
  /// conformance is not detected. It attempts to find properties named `groupId`
  /// or `groupIds` using Swift's Mirror API.
  ///
  /// - Note: This is a fallback mechanism and may have performance implications.
  ///         Prefer explicit protocol conformance (LockmanSingleGroupAction or
  ///         LockmanMultipleGroupsAction) for better performance and type safety.
  ///
  /// - Parameters:
  ///   - keyPath: The property name to search for.
  ///   - type: The expected type of the property.
  /// - Returns: The property value if found and castable to the expected type, otherwise nil.
  private func getDynamicProperty<T>(_ keyPath: String, type _: T.Type) -> T? {
    let mirror = Mirror(reflecting: self)

    // Search through stored properties using Mirror
    for child in mirror.children {
      if child.label == keyPath {
        return child.value as? T
      }
    }

    // Fallback: Attempt to use key-value coding for NSObject subclasses
    // This enables support for computed properties in Objective-C compatible classes
    if let nsObject = self as? NSObject {
      return nsObject.value(forKey: keyPath) as? T
    }

    return nil
  }
}

// MARK: - Default Implementation

public extension LockmanGroupCoordinatedAction {
  /// Default implementation that creates LockmanGroupCoordinatedInfo.
  ///
  /// This implementation uses the following priority order to determine group membership:
  /// 1. Explicit protocol conformance (LockmanMultipleGroupsAction or LockmanSingleGroupAction)
  /// 2. Reflection-based property detection for `groupIds` or `groupId`
  /// 3. Fallback to a default group ID based on the action name
  ///
  /// - Note: For best performance and type safety, implement either
  ///         `LockmanSingleGroupAction` or `LockmanMultipleGroupsAction` protocol.
  var lockmanInfo: LockmanGroupCoordinatedInfo {
    // Priority 1: Check for explicit protocol conformance (most efficient)
    if let multiGroupAction = self as? any LockmanMultipleGroupsAction {
      return LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId(actionName),
        groupIds: multiGroupAction.groupIds,
        coordinationRole: coordinationRole
      )
    }

    if let singleGroupAction = self as? any LockmanSingleGroupAction {
      return LockmanGroupCoordinatedInfo(
        actionId: LockmanActionId(actionName),
        groupId: singleGroupAction.groupId,
        coordinationRole: coordinationRole
      )
    }

    // Priority 2: Use reflection to find properties (less efficient fallback)
    let mirror = Mirror(reflecting: self)

    // Check for groupIds property (multiple groups)
    for child in mirror.children {
      if child.label == "groupIds" {
        if let groupIds = child.value as? Set<String>, !groupIds.isEmpty {
          return LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupIds: groupIds,
            coordinationRole: coordinationRole
          )
        }
      }
    }

    // Check for groupId property (single group)
    for child in mirror.children {
      if child.label == "groupId" {
        if let groupId = child.value as? String {
          return LockmanGroupCoordinatedInfo(
            actionId: LockmanActionId(actionName),
            groupId: groupId,
            coordinationRole: coordinationRole
          )
        }
      }
    }

    // Priority 3: Fallback - use the action name as group ID
    // This ensures the action still functions even without explicit group configuration
    return LockmanGroupCoordinatedInfo(
      actionId: LockmanActionId(actionName),
      groupId: "default-\(actionName)",
      coordinationRole: coordinationRole
    )
  }
}
