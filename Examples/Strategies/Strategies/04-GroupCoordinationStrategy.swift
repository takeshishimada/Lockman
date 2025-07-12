import CasePaths
import ComposableArchitecture
import Lockman
import SwiftUI

// MARK: - Feature
@Reducer
struct GroupCoordinationStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var syncStatus: SyncStatus = .idle
    var uploadProgress: Double = 0
    var downloadProgress: Double = 0
    var processingProgress: Double = 0
    var currentGroup: String = ""
    var activeOperations: Set<String> = []
  }

  enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(String)
  }

  @CasePathable
  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanGroupCoordination
    enum ViewAction {
      case startSyncTapped  // Leader - starts sync group
      case uploadDataTapped  // Member - can only run during sync
      case downloadDataTapped  // Member - can only run during sync
      case processDataTapped  // Member - can only run during sync
      case cancelSyncTapped  // None - can always run

      var lockmanInfo: LockmanGroupCoordinatedInfo {
        switch self {
        case .startSyncTapped:
          return LockmanGroupCoordinatedInfo(
            actionId: actionName,
            groupId: "sync",
            coordinationRole: .leader(.emptyGroup)
          )
        case .uploadDataTapped:
          return LockmanGroupCoordinatedInfo(
            actionId: actionName,
            groupId: "sync",
            coordinationRole: .member
          )
        case .downloadDataTapped:
          return LockmanGroupCoordinatedInfo(
            actionId: actionName,
            groupId: "sync",
            coordinationRole: .member
          )
        case .processDataTapped:
          return LockmanGroupCoordinatedInfo(
            actionId: actionName,
            groupId: "sync",
            coordinationRole: .member
          )
        case .cancelSyncTapped:
          return LockmanGroupCoordinatedInfo(
            actionId: actionName,
            groupId: "sync",
            coordinationRole: .none
          )
        }
      }
    }

    enum InternalAction {
      case syncStarted
      case syncCompleted
      case syncFailed(String)
      case operationStarted(String)
      case operationCompleted(String)
      case operationFailed(operation: String, error: String)
      case updateProgress(operation: String, progress: Double)
    }
  }

  enum CancelID: Hashable {
    case sync
    case upload
    case download
    case process
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(let viewAction):
        return handleViewAction(viewAction, state: &state)

      case .internal(let internalAction):
        return handleInternalAction(internalAction, state: &state)
      }
    }
    .lock(
      boundaryId: CancelID.sync,
      lockFailure: { error, send in
        // Handle group coordination errors using simplified error messages
        if let cancellationError = error as? LockmanCancellationError {
          // Handle cancellation errors that contain the actual strategy errors
          let simpleMessage = getSimpleErrorMessage(for: cancellationError.reason)
          await send(.internal(.syncFailed(simpleMessage)))
        } else if let groupError = error as? LockmanGroupCoordinationError {
          let simpleMessage = getSimpleErrorMessage(for: groupError)
          await send(.internal(.syncFailed(simpleMessage)))
        }
      },
      for: \.view
    )
  }

  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .startSyncTapped:
      return .run { send in
        await send(.internal(.syncStarted))

        // Simulate sync process
        try await Task.sleep(nanoseconds: 5_000_000_000)  // 5 seconds

        await send(.internal(.syncCompleted))
      } catch: { error, send in
        await send(.internal(.syncFailed(error.localizedDescription)))
      }
      .cancellable(id: CancelID.sync)

    case .uploadDataTapped:
      return .run { send in
        await send(.internal(.operationStarted("Upload")))

        // Simulate upload with progress
        for i in 1...10 {
          try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
          await send(.internal(.updateProgress(operation: "Upload", progress: Double(i) / 10.0)))
        }

        await send(.internal(.operationCompleted("Upload")))
      } catch: { error, send in
        await send(
          .internal(.operationFailed(operation: "Upload", error: error.localizedDescription)))
      }
      .cancellable(id: CancelID.upload)

    case .downloadDataTapped:
      return .run { send in
        await send(.internal(.operationStarted("Download")))

        // Simulate download with progress
        for i in 1...10 {
          try await Task.sleep(nanoseconds: 200_000_000)  // 0.2 seconds
          await send(
            .internal(.updateProgress(operation: "Download", progress: Double(i) / 10.0)))
        }

        await send(.internal(.operationCompleted("Download")))
      } catch: { error, send in
        await send(
          .internal(.operationFailed(operation: "Download", error: error.localizedDescription)))
      }
      .cancellable(id: CancelID.download)

    case .processDataTapped:
      return .run { send in
        await send(.internal(.operationStarted("Process")))

        // Simulate processing with progress
        for i in 1...10 {
          try await Task.sleep(nanoseconds: 400_000_000)  // 0.4 seconds
          await send(.internal(.updateProgress(operation: "Process", progress: Double(i) / 10.0)))
        }

        await send(.internal(.operationCompleted("Process")))
      } catch: { error, send in
        await send(
          .internal(.operationFailed(operation: "Process", error: error.localizedDescription)))
      }
      .cancellable(id: CancelID.process)

    case .cancelSyncTapped:
      // Cancel all operations
      return .concatenate(
        .cancel(id: CancelID.sync),
        .cancel(id: CancelID.upload),
        .cancel(id: CancelID.download),
        .cancel(id: CancelID.process),
        .send(.internal(.syncFailed("Sync cancelled by user")))
      )
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .syncStarted:
      updateSyncState(.syncing, group: "sync", state: &state)
      state.activeOperations.insert("Sync")
      return .none

    case .syncCompleted:
      updateSyncState(.completed, state: &state)
      state.activeOperations.remove("Sync")
      clearGroupIfEmpty(state: &state)
      return .none

    case .syncFailed(let error):
      updateSyncState(.failed(error), state: &state)
      state.activeOperations.remove("Sync")
      clearGroupIfEmpty(state: &state)
      resetAllProgress(state: &state)
      return .none

    case .operationStarted(let operation):
      state.activeOperations.insert(operation)
      return .none

    case .operationCompleted(let operation):
      state.activeOperations.remove(operation)
      return .none

    case .operationFailed(let operation, let error):
      state.activeOperations.remove(operation)
      state.syncStatus = .failed("\(operation) failed: \(error)")
      return .none

    case .updateProgress(let operation, let progress):
      updateOperationProgress(operation: operation, progress: progress, state: &state)
      return .none
    }
  }

  // MARK: - Helper Methods
  private func getSimpleErrorMessage(for error: Error) -> String {
    if error is LockmanGroupCoordinationError {
      return "Group coordination failed"
    } else {
      return "Operation failed"
    }
  }

  private func updateSyncState(
    _ status: SyncStatus,
    group: String? = nil,
    state: inout State
  ) {
    state.syncStatus = status
    if let group = group {
      state.currentGroup = group
    }
  }

  private func clearGroupIfEmpty(state: inout State) {
    if state.activeOperations.isEmpty {
      state.currentGroup = ""
    }
  }

  private func resetAllProgress(state: inout State) {
    state.uploadProgress = 0
    state.downloadProgress = 0
    state.processingProgress = 0
  }

  private func updateOperationProgress(
    operation: String,
    progress: Double,
    state: inout State
  ) {
    switch operation {
    case "Upload":
      state.uploadProgress = progress
    case "Download":
      state.downloadProgress = progress
    case "Process":
      state.processingProgress = progress
    default:
      break
    }
  }
}

// MARK: - View
@ViewAction(for: GroupCoordinationStrategyFeature.self)
struct GroupCoordinationStrategyView: View {
  let store: StoreOf<GroupCoordinationStrategyFeature>

  var body: some View {
    VStack(spacing: 20) {
      // Header
      VStack(alignment: .leading, spacing: 10) {
        Text("Group Coordination Strategy")
          .font(.title2)
          .fontWeight(.bold)

        Text("Leader starts sync, members can only join active sync sessions")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(10)

      // Status Display
      VStack(spacing: 10) {
        HStack {
          Text("Status:")
          Spacer()
          statusLabel
        }

        if !store.currentGroup.isEmpty {
          HStack {
            Text("Active Group:")
            Spacer()
            Text(store.currentGroup)
              .fontWeight(.semibold)
              .foregroundColor(.blue)
          }
        }

        if !store.activeOperations.isEmpty {
          HStack {
            Text("Active Operations:")
            Spacer()
            Text(store.activeOperations.sorted().joined(separator: ", "))
              .font(.caption)
              .foregroundColor(.orange)
          }
        }
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(10)

      // Control Buttons
      VStack(spacing: 15) {
        // Leader button
        Button(action: { send(.startSyncTapped) }) {
          HStack {
            Image(systemName: "arrow.triangle.2.circlepath")
            Text("Start Sync (Leader)")
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(store.syncStatus == .syncing ? Color.gray : Color.blue)
          .foregroundColor(.white)
          .cornerRadius(10)
        }

        // Member buttons
        HStack(spacing: 10) {
          memberButton(
            title: "Upload",
            icon: "arrow.up.circle",
            progress: store.uploadProgress,
            isActive: store.activeOperations.contains("Upload"),
            action: { send(.uploadDataTapped) }
          )

          memberButton(
            title: "Download",
            icon: "arrow.down.circle",
            progress: store.downloadProgress,
            isActive: store.activeOperations.contains("Download"),
            action: { send(.downloadDataTapped) }
          )

          memberButton(
            title: "Process",
            icon: "gearshape",
            progress: store.processingProgress,
            isActive: store.activeOperations.contains("Process"),
            action: { send(.processDataTapped) }
          )
        }

        // Cancel button
        if store.syncStatus == .syncing {
          Button(action: { send(.cancelSyncTapped) }) {
            HStack {
              Image(systemName: "xmark.circle")
              Text("Cancel Sync")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(10)
          }
        }
      }

      Spacer()

      // Debug button
      Button(action: {
        print("\n📊 Current Lock State (GroupCoordinationStrategy):")
        LockmanManager.debug.printCurrentLocks(options: .compact)
        print("")
      }) {
        HStack {
          Image(systemName: "lock.doc")
          Text("Show Current Locks in Console")
        }
        .font(.footnote)
        .foregroundColor(.blue)
      }
    }
    .padding()
    .navigationTitle("Group Coordination")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private var statusLabel: some View {
    switch store.syncStatus {
    case .idle:
      Text("Ready")
        .foregroundColor(.secondary)
    case .syncing:
      HStack {
        ProgressView()
          .scaleEffect(0.8)
        Text("Syncing...")
      }
      .foregroundColor(.orange)
    case .completed:
      Label("Completed", systemImage: "checkmark.circle.fill")
        .foregroundColor(.green)
    case .failed(let error):
      Text(error)
        .foregroundColor(.red)
        .font(.caption)
    }
  }

  @ViewBuilder
  private func memberButton(
    title: String,
    icon: String,
    progress: Double,
    isActive: Bool,
    action: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 5) {
      Button(action: action) {
        VStack(spacing: 8) {
          Image(systemName: icon)
            .font(.title2)
          Text(title)
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .background(
          isActive
            ? Color.orange.opacity(0.3)
            : store.syncStatus == .syncing ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(
              isActive ? Color.orange : store.syncStatus == .syncing ? Color.green : Color.gray,
              lineWidth: 2
            )
        )
        .cornerRadius(10)
      }

      if progress > 0 {
        ProgressView(value: progress)
          .progressViewStyle(.linear)
          .frame(height: 4)
      }
    }
  }
}

// MARK: - Preview
#Preview {
  NavigationStack {
    GroupCoordinationStrategyView(
      store: Store(
        initialState: GroupCoordinationStrategyFeature.State()
      ) {
        GroupCoordinationStrategyFeature()
      }
    )
  }
}
