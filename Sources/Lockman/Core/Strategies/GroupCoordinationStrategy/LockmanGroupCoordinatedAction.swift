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
///   let coordinationRole = GroupCoordinationRole.leader(.none)
///
///   var actionName: String { "navigateToDetail" }
/// }
///
/// // Exclusive navigation that blocks other actions
/// struct ExclusiveNavigationAction: LockmanGroupCoordinatedAction {
///   let groupId = "navigation"
///   let coordinationRole = GroupCoordinationRole.leader(.all)
///
///   var actionName: String { "exclusiveNavigate" }
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
///       return .leader(.none)
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
public protocol LockmanGroupCoordinatedAction: LockmanAction
where I == LockmanGroupCoordinatedInfo {
  /// The name identifier for this action.
  ///
  /// Used as the `actionId` in the lock information.
  /// Actions with the same name within the same group cannot execute concurrently.
  var actionName: String { get }

  /// Lock information that provides group coordination details.
  ///
  /// This property must be implemented to specify:
  /// - The group ID(s) this action belongs to
  /// - The coordination role (leader or member)
  var lockmanInfo: LockmanGroupCoordinatedInfo { get }
}

// MARK: - Default Implementations

extension LockmanGroupCoordinatedAction {
  /// The strategy identifier for group coordination.
  public var strategyId: LockmanStrategyId {
    .groupCoordination
  }
}
