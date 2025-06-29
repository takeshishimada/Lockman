import ComposableArchitecture
import Lockman
import SwiftUI

@Reducer
struct SingleExecutionStrategyFeature {
  @ObservableState
  struct State: Equatable {
    var isProcessing = false
    var message: String = ""
    var messageType: MessageType = .none
    var previousMessage: String = ""

    enum MessageType: Equatable {
      case none
      case error
      case success
    }
  }

  @Dependency(\.sampleProcessUseCase) var useCase

  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    @LockmanSingleExecution
    enum ViewAction {
      case startProcessButtonTapped

      var lockmanInfo: LockmanSingleExecutionInfo {
        return .init(actionId: actionName, mode: .boundary)
      }
    }

    enum InternalAction {
      case processStart
      case processCompleted
      case handleError(Error)
    }
  }

  enum CancelID {
    case process
  }

  var body: some Reducer<State, Action> {
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
    case .startProcessButtonTapped:
      return .withLock(
        operation: { send in
          await send(.internal(.processStart))
          try await useCase.execute()
          await send(.internal(.processCompleted))
        },
        catch: { error, send in
          await send(.internal(.handleError(error)))
        },
        lockFailure: { error, send in
          await send(.internal(.handleError(error)))
        },
        action: action,
        cancelID: CancelID.process
      )
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .processStart:
      state.isProcessing = true
      state.message = ""
      state.messageType = .none
      return .none

    case .processCompleted:
      state.isProcessing = false
      state.message = "Process completed successfully"
      state.messageType = .success
      return .none

    case .handleError(let error):
      state.messageType = .error

      if error is LockmanSingleExecutionError {
        state.previousMessage = state.message
        state.message = "Process is already running"
      } else {
        state.isProcessing = false
        if error is ProcessError {
          state.message = "Process failed"
        } else {
          state.message = "Unknown error occurred"
        }
      }

      return .none
    }
  }
}

@ViewAction(for: SingleExecutionStrategyFeature.self)
struct SingleExecutionStrategyView: View {
  @Bindable var store: StoreOf<SingleExecutionStrategyFeature>

  var body: some View {
    VStack(spacing: 30) {
      // Overview
      VStack(alignment: .leading, spacing: 10) {
        Text("SingleExecutionStrategy")
          .font(.title2)
          .fontWeight(.bold)

        Text(
          "Example of exclusive control using @LockmanSingleExecution.\nDuplicate executions are blocked while processing."
        )
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.leading)
      }
      .padding()
      .background(Color.gray.opacity(0.1))
      .cornerRadius(10)

      Spacer()

      // Main content
      VStack(spacing: 20) {
        // Process execution button
        Button(action: {
          send(.startProcessButtonTapped)
        }) {
          HStack(spacing: 10) {
            if store.isProcessing {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.9)
              Text("Processing...")
                .fontWeight(.medium)
            } else {
              Image(systemName: "play.fill")
                .font(.system(size: 16))
              Text("Start Process")
                .fontWeight(.semibold)
            }
          }
          .frame(minWidth: 200)
          .padding(.horizontal, 24)
          .padding(.vertical, 14)
          .background(
            Group {
              if store.isProcessing {
                Color.gray.opacity(0.7)
              } else {
                LinearGradient(
                  gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                  startPoint: .top,
                  endPoint: .bottom
                )
              }
            }
          )
          .foregroundColor(.white)
          .cornerRadius(12)
          .shadow(color: store.isProcessing ? .clear : .blue.opacity(0.3), radius: 8, x: 0, y: 4)
          .scaleEffect(store.isProcessing ? 0.98 : 1.0)
          .animation(.easeInOut(duration: 0.1), value: store.isProcessing)
        }

        // Message label
        Text(store.message)
          .font(.body)
          .foregroundColor(messageColor(for: store.messageType))
          .padding(.horizontal)
          .frame(height: 20)
          .opacity(store.message.isEmpty ? 0 : 1)
          .animation(
            store.message == "Process is already running"
              && store.previousMessage == "Process is already running"
              ? .none
              : .easeInOut(duration: 0.3),
            value: store.message
          )
      }

      Spacer()

      // Debug Button
      Button(action: {
        print("\n📊 Current Lock State (SingleExecutionStrategy):")
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
      .padding(.top, 20)
    }
    .padding()
    .navigationTitle("Single Execution")
  }

  private func messageColor(for type: SingleExecutionStrategyFeature.State.MessageType) -> Color {
    switch type {
    case .none:
      return .primary
    case .error:
      return .red
    case .success:
      return .green
    }
  }
}


// MARK: - Errors

enum ProcessError: Error, Equatable {
  case processFailed
}

// MARK: - Use Case

struct SampleProcessUseCase {
  private var executionCount = 0

  mutating func execute() async throws {
    // Wait for 5 seconds
    try await Task.sleep(nanoseconds: 5_000_000_000)

    // Increment execution count
    executionCount += 1

    // Odd number = success, even number = failure
    if executionCount % 2 == 0 {
      throw ProcessError.processFailed
    }
  }
}

// MARK: - Dependency

// Wrap the use case in a class to maintain state
final class SampleProcessUseCaseWrapper {
  private var useCase = SampleProcessUseCase()

  func execute() async throws {
    try await useCase.execute()
  }
}

extension DependencyValues {
  var sampleProcessUseCase: SampleProcessUseCaseWrapper {
    get { self[SampleProcessUseCaseWrapper.self] }
    set { self[SampleProcessUseCaseWrapper.self] = newValue }
  }
}

extension SampleProcessUseCaseWrapper: DependencyKey {
  static let liveValue = SampleProcessUseCaseWrapper()
}
