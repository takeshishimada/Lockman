import ComposableArchitecture
import Lockman
import SwiftUI

// MARK: - Feature
@Reducer
struct ConcurrencyLimitedStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var downloads: IdentifiedArrayOf<Download> = [
      Download(id: 1, name: "File 1"),
      Download(id: 2, name: "File 2"),
      Download(id: 3, name: "File 3"),
      Download(id: 4, name: "File 4"),
      Download(id: 5, name: "File 5"),
    ]
    var currentExecutionCount = 0
    let maxConcurrency = 3
  }
  
  struct Download: Equatable, Identifiable {
    let id: Int
    let name: String
    var status: DownloadStatus = .idle
    var progress: Double = 0.0
  }
  
  enum DownloadStatus: Equatable {
    case idle
    case downloading
    case completed
    case failed(String)
    case rejected(String)
  }

  // MARK: - Concurrency Group
  private enum ConcurrencyGroup: LockmanConcurrencyGroup {
    case downloads
    
    var id: String {
      "downloads"
    }
    
    var limit: LockmanConcurrencyLimit {
      .limited(3)
    }
  }

  enum CancelID: Hashable {
    case downloads  // Use single boundary for all downloads
  }
  
  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)
    
    @LockmanCompositeStrategy(
      LockmanConcurrencyLimitedStrategy.self,
      LockmanSingleExecutionStrategy.self
    )
    enum ViewAction {
      case downloadButtonTapped(Int)
    
      var actionId: String {
        switch self {
        case .downloadButtonTapped(let id):
          return "download-\(id)"
        }
      }
    
      var lockmanInfo: LockmanCompositeInfo2<LockmanConcurrencyLimitedInfo, LockmanSingleExecutionInfo> {
        LockmanCompositeInfo2(
          strategyId: strategyId,  // Use macro-generated strategyId
          actionId: actionId,
          lockmanInfoForStrategy1: LockmanConcurrencyLimitedInfo(
            actionId: actionId,
            group: ConcurrencyGroup.downloads
          ),
          lockmanInfoForStrategy2: LockmanSingleExecutionInfo(
            actionId: actionId,
            mode: .action  // Prevent duplicate execution of same download
          )
        )
      }
    }
    
    enum InternalAction {
      case downloadStarted(Int)
      case downloadProgress(id: Int, progress: Double)
      case downloadCompleted(Int)
      case downloadFailed(id: Int, error: String)
      case downloadRejected(id: Int, reason: String)
      case handleLockFailure(id: Int, error: Error)
    }
  }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .view(viewAction):
        return handleViewAction(viewAction, state: &state)
        
      case let .internal(internalAction):
        return handleInternalAction(internalAction, state: &state)
      }
    }
  }
  
  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case let .downloadButtonTapped(id):
      guard state.downloads[id: id] != nil else { return .none }
      
      // SingleExecutionStrategy will handle duplicate prevention
      
      return .withLock(
        operation: { send in
          await send(.internal(.downloadStarted(id)))
          
          // Simulate download with progress updates
          for i in 1...10 {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            await send(.internal(.downloadProgress(id: id, progress: Double(i) / 10.0)))
          }
          
          await send(.internal(.downloadCompleted(id)))
        },
        catch: { error, send in
          await send(.internal(.downloadFailed(id: id, error: error.localizedDescription)))
        },
        lockFailure: { error, send in
          await send(.internal(.handleLockFailure(id: id, error: error)))
        },
        action: Action.ViewAction.downloadButtonTapped(id),
        cancelID: CancelID.downloads
      )
    }
  }
  
  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case let .downloadStarted(id):
      state.downloads[id: id]?.status = .downloading
      state.downloads[id: id]?.progress = 0
      state.currentExecutionCount += 1
      return .none
      
    case let .downloadProgress(id: id, progress: progress):
      state.downloads[id: id]?.progress = progress
      return .none
      
    case let .downloadCompleted(id):
      state.downloads[id: id]?.status = .completed
      state.downloads[id: id]?.progress = 1.0
      state.currentExecutionCount -= 1
      return .none
      
    case let .downloadFailed(id: id, error: error):
      state.downloads[id: id]?.status = .failed(error)
      state.currentExecutionCount -= 1
      return .none
      
    case let .downloadRejected(id: id, reason: reason):
      // Reset progress if was previously downloading/completed
      if state.downloads[id: id] != nil {
        state.downloads[id: id]?.status = .rejected(reason)
        state.downloads[id: id]?.progress = 0
      }
      return .none
      
    case let .handleLockFailure(id: id, error: error):
      // Handle errors from both strategies
      let reason: String
      if let concurrencyError = error as? LockmanConcurrencyLimitedError,
         case .concurrencyLimitReached(let requestedInfo, _, let current) = concurrencyError {
        reason = "Download limit reached (\(current)/\(requestedInfo.limit))"
      } else if let singleExecutionError = error as? LockmanSingleExecutionError,
                case .actionAlreadyRunning = singleExecutionError {
        reason = "This download is already in progress"
      } else {
        reason = "Cannot start download"
      }
      return .send(.internal(.downloadRejected(id: id, reason: reason)))
    }
  }
}

// MARK: - View
struct ConcurrencyLimitedStrategyView: View {
  let store: StoreOf<ConcurrencyLimitedStrategyFeature>
  
  var body: some View {
    VStack(spacing: 20) {
      // Header with current status
      VStack(spacing: 10) {
        Text("Maximum 3 concurrent downloads allowed")
          .font(.headline)
        
        HStack {
          Text("Current Downloads:")
          Text("\(store.currentExecutionCount) / \(store.maxConcurrency)")
            .fontWeight(.bold)
            .foregroundColor(store.currentExecutionCount >= store.maxConcurrency ? .red : .green)
        }
        .font(.subheadline)
      }
      .padding()
      .background(Color(.systemGray6))
      .cornerRadius(10)
      
      // Download list
      List {
        ForEach(store.downloads) { download in
          HStack {
            // Download button (left column)
            Button(action: {
              store.send(.view(.downloadButtonTapped(download.id)))
            }) {
              HStack {
                Image(systemName: iconName(for: download.status))
                  .foregroundColor(iconColor(for: download.status))
                Text(download.name)
              }
            }
            .disabled(download.status == .downloading)
            .frame(width: 120, alignment: .leading)
            
            Spacer()
            
            // Status display (right column)
            VStack(alignment: .trailing, spacing: 4) {
              Text(statusText(for: download.status))
                .font(.caption)
                .foregroundColor(statusColor(for: download.status))
              
              if download.status == .downloading {
                ProgressView(value: download.progress)
                  .frame(width: 100)
              }
            }
          }
          .padding(.vertical, 8)
        }
      }
      .listStyle(.insetGrouped)
    }
    .navigationTitle("ConcurrencyLimitedStrategy")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private func iconName(for status: ConcurrencyLimitedStrategyFeature.DownloadStatus) -> String {
    switch status {
    case .idle:
      return "arrow.down.circle"
    case .downloading:
      return "arrow.down.circle.fill"
    case .completed:
      return "checkmark.circle.fill"
    case .failed:
      return "xmark.circle.fill"
    case .rejected:
      return "exclamationmark.circle.fill"
    }
  }
  
  private func iconColor(for status: ConcurrencyLimitedStrategyFeature.DownloadStatus) -> Color {
    switch status {
    case .idle:
      return .blue
    case .downloading:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .rejected:
      return .yellow
    }
  }
  
  private func statusText(for status: ConcurrencyLimitedStrategyFeature.DownloadStatus) -> String {
    switch status {
    case .idle:
      return "Ready to download"
    case .downloading:
      return "Downloading..."
    case .completed:
      return "Completed"
    case .failed(let error):
      return "Failed: \(error)"
    case .rejected(let reason):
      return reason
    }
  }
  
  private func statusColor(for status: ConcurrencyLimitedStrategyFeature.DownloadStatus) -> Color {
    switch status {
    case .idle:
      return .secondary
    case .downloading:
      return .orange
    case .completed:
      return .green
    case .failed:
      return .red
    case .rejected:
      return .orange
    }
  }
}

// MARK: - Preview
#Preview {
  NavigationStack {
    ConcurrencyLimitedStrategyView(
      store: Store(
        initialState: ConcurrencyLimitedStrategyFeature.State()
      ) {
        ConcurrencyLimitedStrategyFeature()
      }
    )
  }
}
