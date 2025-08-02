/// TCA integration macros for Lockman framework.
///
/// These macros are designed specifically for use with The Composable Architecture (TCA)
/// and the `Effect.lock()` extensions. They automatically generate the necessary
/// boilerplate code for different locking strategies.

/// A macro that generates protocol conformance and required members for single execution locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanSingleExecutionAction`
/// - `actionName` property that returns the enum case name as a String
/// - Default `strategyId` implementation is provided by the protocol
///
/// **Important**: You must implement the `lockmanInfo` property to specify the execution mode:
/// - `.none`: No exclusive execution (always allows locks)
/// - `.boundary`: Only one action per boundary at a time (default behavior)
/// - `.action`: Only one instance of the same actionId at a time
///
/// Example usage with TCA:
/// ```swift
/// @Reducer
/// struct MyFeature {
///   @LockmanSingleExecution
///   enum Action {
///     case login
///     case logout
///
///     var lockmanInfo: LockmanSingleExecutionInfo {
///       switch self {
///       case .login:
///         return .init(actionId: actionName, mode: .boundary)
///       case .logout:
///         return .init(actionId: actionName, mode: .action)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .login:
///         return .run { send in
///           // async work
///         }
///         .lock(
///           action: .login,
///           boundaryId: "login-operation"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanSingleExecutionAction)
@attached(member, names: named(actionName))
public macro LockmanSingleExecution() =
  #externalMacro(module: "LockmanMacros", type: "LockmanSingleExecutionMacro")

/// A macro that generates protocol conformance and required members for priority-based locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanPriorityBasedAction`
/// - `actionName` property that returns the enum case name as a String
/// - `lockmanInfo` property that provides `LockmanPriorityBasedInfo` (must be implemented by user)
/// - Default `strategyId` implementation is provided by the protocol
///
/// Example usage with TCA:
/// ```swift
/// @Reducer
/// struct MyFeature {
///   @LockmanPriorityBased
///   enum Action {
///     case highPriorityTask
///     case lowPriorityTask
///
///     var lockmanInfo: LockmanPriorityBasedInfo {
///       switch self {
///       case .highPriorityTask:
///         return .init(actionId: actionName, priority: .high(.exclusive))
///       case .lowPriorityTask:
///         return .init(actionId: actionName, priority: .low(.replaceable))
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .highPriorityTask:
///         return .run { send in
///           // async work
///         }
///         .lock(
///           action: .highPriorityTask,
///           boundaryId: "priority-task"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanPriorityBasedAction)
@attached(member, names: named(actionName))
public macro LockmanPriorityBased() =
  #externalMacro(module: "LockmanMacros", type: "LockmanPriorityBasedMacro")

/// A macro that generates protocol conformance and required members for group coordination locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanGroupCoordinatedAction`
/// - `actionName` property that returns the enum case name as a String
/// - Default `strategyId` implementation is provided by the protocol
///
/// **Important**: You must implement the `lockmanInfo` property to specify coordination details:
/// - The group ID(s) this action belongs to
/// - The coordination role (.leader or .member)
///
/// Example usage with TCA:
/// ```swift
/// @Reducer
/// struct NavigationFeature {
///   @LockmanGroupCoordination
///   enum Action {
///     case navigate(to: String)
///     case back
///
///     var lockmanInfo: LockmanGroupCoordinatedInfo {
///       switch self {
///       case .navigate:
///         return LockmanGroupCoordinatedInfo(
///           actionId: actionName,
///           groupId: "navigation",
///           coordinationRole: .leader
///         )
///       case .back:
///         return LockmanGroupCoordinatedInfo(
///           actionId: actionName,
///           groupId: "navigation",
///           coordinationRole: .member
///         )
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .navigate:
///         return .run { send in
///           // navigation logic
///         }
///         .lock(
///           action: .navigate(to: destination),
///           boundaryId: "navigation"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanGroupCoordinatedAction)
@attached(member, names: named(actionName))
public macro LockmanGroupCoordination() =
  #externalMacro(module: "LockmanMacros", type: "LockmanGroupCoordinationMacro")

/// A macro that generates protocol conformance and required members for composite locking behavior with 2 strategies.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanCompositeAction2`
/// - `actionName` property that returns the enum case name as a String
/// - `strategyId` property that returns a unique identifier for the composite strategy
///
/// **Important**: You must implement the `lockmanInfo` property to provide strategy-specific details.
///
/// Example usage with TCA:
/// ```swift
/// @Reducer
/// struct CriticalFeature {
///   @LockmanCompositeStrategy(LockmanSingleExecutionStrategy.self, LockmanPriorityBasedStrategy.self)
///   enum Action {
///     case criticalOperation
///
///     var lockmanInfo: LockmanCompositeInfo2<LockmanSingleExecutionInfo, LockmanPriorityBasedInfo> {
///       LockmanCompositeInfo2(
///         actionId: actionName,
///         lockmanInfoForStrategy1: LockmanSingleExecutionInfo(actionId: actionName, mode: .boundary),
///         lockmanInfoForStrategy2: LockmanPriorityBasedInfo(actionId: actionName, priority: 100)
///       )
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .criticalOperation:
///         return .run { send in
///           // critical work requiring both single execution and high priority
///         }
///         .lock(
///           action: .criticalOperation,
///           boundaryId: "critical-op"
///         )
///       }
///     }
///   }
/// }
/// ```
///
/// - Parameters:
///   - strategy1: The first strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy2: The second strategy type (must be a type that conforms to `LockmanStrategy`)
@attached(extension, conformances: LockmanCompositeAction2)
@attached(
  member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2))
public macro LockmanCompositeStrategy<S1: LockmanStrategy, S2: LockmanStrategy>(
  _ strategy1: S1.Type,
  _ strategy2: S2.Type
) = #externalMacro(module: "LockmanMacros", type: "LockmanCompositeStrategy2Macro")

/// A macro that generates protocol conformance and required members for composite locking behavior with 3 strategies.
///
/// - Parameters:
///   - strategy1: The first strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy2: The second strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy3: The third strategy type (must be a type that conforms to `LockmanStrategy`)
@attached(extension, conformances: LockmanCompositeAction3)
@attached(
  member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2),
  named(I3), named(S3))
public macro LockmanCompositeStrategy<
  S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy
>(
  _ strategy1: S1.Type,
  _ strategy2: S2.Type,
  _ strategy3: S3.Type
) = #externalMacro(module: "LockmanMacros", type: "LockmanCompositeStrategy3Macro")

/// A macro that generates protocol conformance and required members for composite locking behavior with 4 strategies.
///
/// - Parameters:
///   - strategy1: The first strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy2: The second strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy3: The third strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy4: The fourth strategy type (must be a type that conforms to `LockmanStrategy`)
@attached(extension, conformances: LockmanCompositeAction4)
@attached(
  member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2),
  named(I3), named(S3), named(I4), named(S4))
public macro LockmanCompositeStrategy<
  S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy, S4: LockmanStrategy
>(
  _ strategy1: S1.Type,
  _ strategy2: S2.Type,
  _ strategy3: S3.Type,
  _ strategy4: S4.Type
) = #externalMacro(module: "LockmanMacros", type: "LockmanCompositeStrategy4Macro")

/// A macro that generates protocol conformance and required members for composite locking behavior with 5 strategies.
///
/// - Parameters:
///   - strategy1: The first strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy2: The second strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy3: The third strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy4: The fourth strategy type (must be a type that conforms to `LockmanStrategy`)
///   - strategy5: The fifth strategy type (must be a type that conforms to `LockmanStrategy`)
@attached(extension, conformances: LockmanCompositeAction5)
@attached(
  member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2),
  named(I3), named(S3), named(I4), named(S4), named(I5), named(S5))
public macro LockmanCompositeStrategy<
  S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy, S4: LockmanStrategy,
  S5: LockmanStrategy
>(
  _ strategy1: S1.Type,
  _ strategy2: S2.Type,
  _ strategy3: S3.Type,
  _ strategy4: S4.Type,
  _ strategy5: S5.Type
) = #externalMacro(module: "LockmanMacros", type: "LockmanCompositeStrategy5Macro")

/// A macro that generates protocol conformance and required members for concurrency-limited locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanConcurrencyLimitedAction`
/// - `actionName` property that returns the enum case name as a String
/// - Default `strategyId` implementation is provided by the protocol
///
/// **Important**: You must implement the `lockmanInfo` property to specify concurrency limits:
/// - Using a predefined concurrency group: `.init(actionId: actionName, group: MyConcurrencyGroup.apiRequests)`
/// - Using direct limit: `.init(actionId: actionName, .limited(3))`
/// - Using unlimited: `.init(actionId: actionName, .unlimited)`
///
/// Example usage with TCA:
/// ```swift
/// // Define your concurrency groups
/// enum MyConcurrencyGroup: LockmanConcurrencyGroup {
///   case apiRequests
///   case fileOperations
///   case uiUpdates
///
///   var id: String {
///     switch self {
///     case .apiRequests: return "api_requests"
///     case .fileOperations: return "file_operations"
///     case .uiUpdates: return "ui_updates"
///     }
///   }
///
///   var limit: LockmanConcurrencyLimit {
///     switch self {
///     case .apiRequests: return .limited(3)
///     case .fileOperations: return .limited(2)
///     case .uiUpdates: return .unlimited
///     }
///   }
/// }
///
/// @Reducer
/// struct MyFeature {
///   @LockmanConcurrencyLimited
///   enum Action {
///     case fetchUserProfile(User.ID)
///     case uploadFile(File)
///     case refreshUI
///
///     var lockmanInfo: LockmanConcurrencyLimitedInfo {
///       switch self {
///       case .fetchUserProfile:
///         // Use predefined group
///         return .init(actionId: actionName, group: MyConcurrencyGroup.apiRequests)
///       case .uploadFile:
///         // Use predefined group
///         return .init(actionId: actionName, group: MyConcurrencyGroup.fileOperations)
///       case .refreshUI:
///         // Direct unlimited
///         return .init(actionId: actionName, .unlimited)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .fetchUserProfile(let userId):
///         return .run { send in
///           // Only 3 concurrent API requests allowed
///           let profile = try await api.fetchProfile(userId)
///           await send(.profileFetched(profile))
///         }
///         .lock(
///           action: .fetchUserProfile(userId),
///           boundaryId: "fetch-profile-\(userId)"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanConcurrencyLimitedAction)
@attached(member, names: named(actionName))
public macro LockmanConcurrencyLimited() =
  #externalMacro(module: "LockmanMacros", type: "LockmanConcurrencyLimitedMacro")
