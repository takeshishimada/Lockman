import CasePaths
import ComposableArchitecture
import Lockman
import SwiftUI

// MARK: - Feature
@Reducer
struct DynamicConditionStrategyFeature {
  @ObservableState
  struct State: Equatable {
    // Pattern 1: Login state
    @Shared(.appStorage("isLoggedIn")) var isLoggedIn = false
    var syncResult: String = ""

    // Pattern 2: Time-based control
    var currentHour: Int = Calendar.current.component(.hour, from: Date())
    var isMaintenanceMode: Bool { currentHour < 9 || currentHour >= 18 }
    var maintenanceResult: String = ""

    // Pattern 3: Day-based control
    var selectedDay: Weekday = Weekday.current
    var reportResult: String = ""

    enum Weekday: Int, CaseIterable {
      case sunday = 1
      case monday, tuesday, wednesday, thursday, friday, saturday

      var name: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
      }

      var isWeekday: Bool {
        switch self {
        case .monday, .tuesday, .wednesday, .thursday, .friday:
          return true
        case .saturday, .sunday:
          return false
        }
      }

      static var current: Weekday {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return Weekday(rawValue: weekday) ?? .monday
      }
    }
  }

  @CasePathable
  enum Action: ViewAction {
    case view(ViewAction)
    case `internal`(InternalAction)

    enum ViewAction {
      // Pattern 1: Login-based
      case syncDataTapped
      case toggleLoginTapped

      // Pattern 2: Time-based
      case performMaintenanceTapped
      case setHour(Int)

      // Pattern 3: Day-based
      case generateReportTapped
      case selectDay(State.Weekday)
    }

    enum InternalAction {
      case syncStarted
      case syncCompleted
      case maintenanceStarted
      case maintenanceCompleted
      case reportStarted
      case reportCompleted
      case operationFailed(operation: String, error: String)
    }
  }

  enum CancelID: Hashable {
    case sync
    case maintenance
    case report
    case auth
  }

  // Custom error for dynamic conditions
  struct DynamicConditionError: LockmanError, LocalizedError {
    let message: String
    var errorDescription: String? { message }
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
      condition: { state, action in
        // Reducer-level condition: Only apply locks for certain view actions
        switch action {
        case .view(.syncDataTapped):
          return state.isLoggedIn
            ? .success : .cancel(DynamicConditionError(message: "Please login to sync data"))
        case .view(.performMaintenanceTapped):
          return state.currentHour >= 2 && state.currentHour <= 4
            ? .success : .cancel(DynamicConditionError(message: "Maintenance only allowed 2-4 AM"))
        case .view(.generateReportTapped):
          return state.selectedDay.isWeekday
            ? .success
            : .cancel(DynamicConditionError(message: "Reports can only be generated on weekdays"))
        default:
          return .cancel(DynamicConditionError(message: "No lock required for this action"))
        }
      },
      boundaryId: CancelID.auth,
      lockFailure: { error, send in
        // Handle condition evaluation failures
        await send(
          .internal(.operationFailed(operation: "Operation", error: error.localizedDescription)))
      }
    )
  }

  // MARK: - View Action Handler
  private func handleViewAction(
    _ action: Action.ViewAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    // Pattern 1: Login-based - condition handled by reducer-level
    case .syncDataTapped:
      return .run { send in
        await send(.internal(.syncStarted))
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        await send(.internal(.syncCompleted))
      } catch: { error, send in
        await send(
          .internal(
            .operationFailed(
              operation: "Sync",
              error: error.localizedDescription
            )))
      }

    case .toggleLoginTapped:
      state.$isLoggedIn.withLock { $0.toggle() }
      return .none

    // Pattern 2: Time-based - condition handled by reducer-level
    case .performMaintenanceTapped:
      return .run { send in
        await send(.internal(.maintenanceStarted))
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
        await send(.internal(.maintenanceCompleted))
      } catch: { error, send in
        await send(
          .internal(
            .operationFailed(
              operation: "Maintenance",
              error: error.localizedDescription
            )))
      }

    case .setHour(let hour):
      state.currentHour = hour
      return .none

    // Pattern 3: Day-based - condition handled by reducer-level
    case .generateReportTapped:
      return .run { send in
        await send(.internal(.reportStarted))
        try await Task.sleep(nanoseconds: 3_000_000_000)  // 3 seconds
        await send(.internal(.reportCompleted))
      } catch: { error, send in
        await send(
          .internal(
            .operationFailed(
              operation: "Report",
              error: error.localizedDescription
            )))
      }

    case .selectDay(let day):
      state.selectedDay = day
      return .none
    }
  }

  // MARK: - Internal Action Handler
  private func handleInternalAction(
    _ action: Action.InternalAction,
    state: inout State
  ) -> Effect<Action> {
    switch action {
    case .syncStarted:
      state.syncResult = "Syncing data..."
      return .none

    case .syncCompleted:
      state.syncResult = "✅ Data synced successfully"
      return .none

    case .maintenanceStarted:
      state.maintenanceResult = "Performing maintenance..."
      return .none

    case .maintenanceCompleted:
      state.maintenanceResult = "✅ Maintenance completed"
      return .none

    case .reportStarted:
      state.reportResult = "Generating report..."
      return .none

    case .reportCompleted:
      state.reportResult = "✅ Report generated for \(state.selectedDay.name)"
      return .none

    case .operationFailed(let operation, let error):
      switch operation {
      case "Sync":
        state.syncResult = "❌ \(error)"
      case "Maintenance":
        state.maintenanceResult = "❌ \(error)"
      case "Report":
        state.reportResult = "❌ \(error)"
      default:
        break
      }
      return .none
    }
  }
}

// MARK: - View
@ViewAction(for: DynamicConditionStrategyFeature.self)
struct DynamicConditionStrategyView: View {
  let store: StoreOf<DynamicConditionStrategyFeature>

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Header
        VStack(alignment: .leading, spacing: 10) {
          Text("Dynamic Condition Strategy")
            .font(.title2)
            .fontWeight(.bold)

          Text("Control action execution based on dynamic conditions")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(10)

        // Pattern 1: Login-based
        VStack(alignment: .leading, spacing: 15) {
          Label("Pattern 1: Login State (@Shared)", systemImage: "person.circle")
            .font(.headline)

          HStack {
            Text("Login Status:")
            Spacer()
            Toggle(
              "",
              isOn: Binding(
                get: { store.isLoggedIn },
                set: { _ in send(.toggleLoginTapped) }
              )
            )
            .labelsHidden()
          }

          Button(action: { send(.syncDataTapped) }) {
            HStack {
              Image(systemName: "arrow.triangle.2.circlepath")
              Text("Sync Data")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(store.isLoggedIn ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.syncResult.isEmpty {
            Text(store.syncResult)
              .font(.caption)
              .foregroundColor(store.syncResult.contains("✅") ? .green : .red)
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)

        // Pattern 2: Time-based
        VStack(alignment: .leading, spacing: 15) {
          Label("Pattern 2: Time Control (Dynamic Condition)", systemImage: "clock")
            .font(.headline)

          HStack {
            Text("Current Hour:")
            Spacer()
            Picker(
              "Hour",
              selection: Binding(
                get: { store.currentHour },
                set: { send(.setHour($0)) }
              )
            ) {
              ForEach(0..<24) { hour in
                Text("\(hour):00").tag(hour)
              }
            }
            .pickerStyle(.menu)
          }

          HStack {
            Text("Status:")
            Spacer()
            if store.isMaintenanceMode {
              Label("Outside Business Hours", systemImage: "moon.fill")
                .foregroundColor(.orange)
            } else {
              Label("Business Hours", systemImage: "sun.max.fill")
                .foregroundColor(.green)
            }
          }
          .font(.caption)

          Button(action: { send(.performMaintenanceTapped) }) {
            HStack {
              Image(systemName: "wrench.and.screwdriver")
              Text("Perform Maintenance")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(!store.isMaintenanceMode ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.maintenanceResult.isEmpty {
            Text(store.maintenanceResult)
              .font(.caption)
              .foregroundColor(store.maintenanceResult.contains("✅") ? .green : .red)
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)

        // Pattern 3: Day-based
        VStack(alignment: .leading, spacing: 15) {
          Label("Pattern 3: Day Control (Dynamic Condition)", systemImage: "calendar")
            .font(.headline)

          HStack {
            Text("Selected Day:")
            Spacer()
            Picker(
              "Day",
              selection: Binding(
                get: { store.selectedDay },
                set: { send(.selectDay($0)) }
              )
            ) {
              ForEach(DynamicConditionStrategyFeature.State.Weekday.allCases, id: \.self) { day in
                Text(day.name).tag(day)
              }
            }
            .pickerStyle(.menu)
          }

          HStack {
            Text("Type:")
            Spacer()
            if store.selectedDay.isWeekday {
              Label("Weekday", systemImage: "briefcase.fill")
                .foregroundColor(.green)
            } else {
              Label("Weekend", systemImage: "house.fill")
                .foregroundColor(.orange)
            }
          }
          .font(.caption)

          Button(action: { send(.generateReportTapped) }) {
            HStack {
              Image(systemName: "doc.text")
              Text("Generate Report")
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(store.selectedDay.isWeekday ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(10)
          }

          if !store.reportResult.isEmpty {
            Text(store.reportResult)
              .font(.caption)
              .foregroundColor(store.reportResult.contains("✅") ? .green : .red)
          }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)

        // Debug button
        Button(action: {
          print("\n📊 Current Lock State (DynamicConditionStrategy):")
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
    }
    .navigationTitle("Dynamic Conditions")
    .navigationBarTitleDisplayMode(.inline)
  }
}

// MARK: - Preview
#Preview {
  NavigationStack {
    DynamicConditionStrategyView(
      store: Store(
        initialState: DynamicConditionStrategyFeature.State()
      ) {
        DynamicConditionStrategyFeature()
      }
    )
  }
}
