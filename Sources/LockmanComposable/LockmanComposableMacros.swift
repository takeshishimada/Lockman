/// TCA integration macros for Lockman framework.
///
/// These macros are designed specifically for use with The Composable Architecture (TCA)
/// and the `Effect.withLock()` extensions. They automatically generate the necessary
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
///         return .withLock(
///           operation: { send in
///             // async work
///           },
///           action: .login,
///           cancelID: "login-operation"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanSingleExecutionAction)
@attached(member, names: named(actionName))
public macro LockmanSingleExecution() = #externalMacro(module: "LockmanMacros", type: "LockmanSingleExecutionMacro")

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
///         return .init(priority: 100, perBoundary: false, blocksSameAction: false)
///       case .lowPriorityTask:
///         return .init(priority: 10, perBoundary: false, blocksSameAction: false)
///       }
///     }
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .highPriorityTask:
///         return .withLock(
///           operation: { send in
///             // async work
///           },
///           action: .highPriorityTask,
///           cancelID: "priority-task"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanPriorityBasedAction)
@attached(member, names: named(actionName))
public macro LockmanPriorityBased() = #externalMacro(module: "LockmanMacros", type: "LockmanPriorityBasedMacro")

/// A macro that generates protocol conformance and required members for group coordination locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanGroupCoordinatedAction`
/// - `actionName` property that returns the enum case name as a String
/// - `coordinationRole` property with the specified role
/// - `groupId` or `groupIds` property with the specified group identifiers
/// - Default `strategyId` implementation is provided by the protocol
///
/// Example usage with TCA (single group):
/// ```swift
/// @Reducer
/// struct NavigationFeature {
///   @LockmanGroupCoordination(groupId: "navigation", role: .leader)
///   enum Action {
///     case navigate(to: String)
///     case back
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .navigate:
///         return .withLock(
///           operation: { send in
///             // navigation logic
///           },
///           action: .navigate(to: destination),
///           cancelID: "navigation"
///         )
///       // ...
///       }
///     }
///   }
/// }
/// ```
///
/// - Parameters:
///   - groupId: The single group identifier for coordination
///   - role: The coordination role (.leader or .member)
@attached(extension, conformances: LockmanGroupCoordinatedAction)
@attached(member, names: named(actionName), named(coordinationRole), named(groupId))
public macro LockmanGroupCoordination(groupId: String, role: GroupCoordinationRole) = #externalMacro(module: "LockmanMacros", type: "LockmanGroupCoordinationMacro")

/// A macro that generates protocol conformance and required members for group coordination locking behavior with multiple groups.
///
/// - Parameters:
///   - groupIds: Multiple group identifiers for coordination (maximum 5)
///   - role: The coordination role (.leader or .member)
@attached(extension, conformances: LockmanGroupCoordinatedAction)
@attached(member, names: named(actionName), named(coordinationRole), named(groupIds))
public macro LockmanGroupCoordination(groupIds: [String], role: GroupCoordinationRole) = #externalMacro(module: "LockmanMacros", type: "LockmanGroupCoordinationMacro")

/// A macro that generates protocol conformance and required members for composite locking behavior with 2 strategies.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanCompositeAction2`
/// - `actionName` property that returns the enum case name as a String
/// - `strategyId` property that returns a unique identifier for the composite strategy
///
/// **Important**: You must implement the `lockmanInfo` property to provide strategy-specific details
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
///         return .withLock(
///           operation: { send in
///             // critical work requiring both single execution and high priority
///           },
///           action: .criticalOperation,
///           cancelID: "critical-op"
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
@attached(member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2))
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
@attached(member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2), named(I3), named(S3))
public macro LockmanCompositeStrategy<S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy>(
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
@attached(member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2), named(I3), named(S3), named(I4), named(S4))
public macro LockmanCompositeStrategy<S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy, S4: LockmanStrategy>(
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
@attached(member, names: named(actionName), named(strategyId), named(I1), named(S1), named(I2), named(S2), named(I3), named(S3), named(I4), named(S4), named(I5), named(S5))
public macro LockmanCompositeStrategy<S1: LockmanStrategy, S2: LockmanStrategy, S3: LockmanStrategy, S4: LockmanStrategy, S5: LockmanStrategy>(
  _ strategy1: S1.Type,
  _ strategy2: S2.Type,
  _ strategy3: S3.Type,
  _ strategy4: S4.Type,
  _ strategy5: S5.Type
) = #externalMacro(module: "LockmanMacros", type: "LockmanCompositeStrategy5Macro")

/// A macro that generates protocol conformance and required members for dynamic condition-based locking behavior.
///
/// Apply this macro to an enum declaration to automatically generate:
/// - Protocol conformance to `LockmanDynamicConditionAction`
/// - `actionName` property that returns the enum case name as a String
/// - `lockmanInfo` property with default condition (always success)
/// - Default `strategyId` implementation is provided by the protocol
///
/// The macro enables you to define custom locking conditions at runtime based on:
/// - Current state values
/// - Other locks in the same boundary
/// - Time-based conditions
/// - Any custom logic
///
/// Example usage with TCA:
/// ```swift
/// @Reducer
/// struct AdvancedFeature {
///   @LockmanDynamicCondition
///   enum Action {
///     case fetchData(userId: String, priority: Int)
///     case processTask(size: Int)
///   }
///
///   var body: some ReducerOf<Self> {
///     Reduce { state, action in
///       switch action {
///       case .fetchData(let userId, let priority):
///         return .run { send in
///           // Define condition based on state and action parameters
///           let lockInfo = action.with(condition: { existingInfos in
///             // High priority always runs
///             if priority >= 10 { return true }
///
///             // Check user-specific limits
///             let userCount = existingInfos.filter { info in
///               info.metadata["userId"] as? String == userId
///             }.count
///
///             // Allow max 3 concurrent requests per user
///             return userCount < 3 && existingInfos.count < state.concurrentLimit
///           })
///
///           await withLock(lockInfo, strategy: .dynamicCondition) {
///             let data = try await api.fetchData(userId: userId)
///             await send(.dataFetched(data))
///           }
///         }
///
///       case .processTask(let size):
///         return .run { send in
///           // Size-based dynamic limits
///           let lockInfo = action.with(condition: { existingInfos in
///             let maxConcurrent = size > 1000 ? 1 : 5
///             return existingInfos.count < maxConcurrent
///           })
///
///           await withLock(lockInfo, strategy: .dynamicCondition) {
///             try await processTask(size: size)
///             await send(.taskCompleted)
///           }
///         }
///       }
///     }
///   }
/// }
/// ```
@attached(extension, conformances: LockmanDynamicConditionAction)
@attached(member, names: named(actionName), named(lockmanInfo))
public macro LockmanDynamicCondition() = #externalMacro(
  module: "LockmanMacros",
  type: "LockmanDynamicConditionMacro"
)
