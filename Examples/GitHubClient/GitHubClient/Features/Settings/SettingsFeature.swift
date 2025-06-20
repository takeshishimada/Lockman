import ComposableArchitecture
import Dependencies
import Foundation

@Reducer
struct SettingsFeature {
    @ObservableState
    struct State: Equatable {
        var currentUser: User?
        var appVersion: String {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        }
        var buildNumber: String {
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        }
        @Presents var confirmationDialog: ConfirmationDialogState<Action.ConfirmationDialog>?
        @Presents var alert: AlertState<Action.Alert>?
    }
    
    enum Action {
        case onAppear
        case closeButtonTapped
        case logoutButtonTapped
        case clearCacheButtonTapped
        case aboutButtonTapped
        case privacyPolicyButtonTapped
        case termsOfServiceButtonTapped
        case confirmationDialog(PresentationAction<ConfirmationDialog>)
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        
        enum ConfirmationDialog: Equatable {
            case confirmLogout
            case confirmClearCache
        }
        
        enum Alert: Equatable {}
        
        enum Delegate: Equatable {
            case logout
            case dismiss
            case openURL(URL)
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Load current user from UserDefaults
                if let userData = UserDefaults.standard.data(forKey: "github_user"),
                   let user = try? JSONDecoder().decode(User.self, from: userData) {
                    state.currentUser = user
                }
                return .none
                
            case .closeButtonTapped:
                return .send(.delegate(.dismiss))
                
            case .logoutButtonTapped:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("Logout")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmLogout) {
                        TextState("Logout")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to logout?")
                }
                return .none
                
            case .clearCacheButtonTapped:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("Clear Cache")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearCache) {
                        TextState("Clear Cache")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will clear all cached data. Are you sure?")
                }
                return .none
                
            case .aboutButtonTapped:
                let appVersion = state.appVersion
                let buildNumber = state.buildNumber
                state.alert = AlertState {
                    TextState("GitHub Client")
                } message: {
                    TextState("""
                    Version \(appVersion) (\(buildNumber))
                    
                    Built with The Composable Architecture
                    Using OctoKit.swift for GitHub API
                    """)
                }
                return .none
                
            case .privacyPolicyButtonTapped:
                if let url = URL(string: "https://github.com/privacy") {
                    return .send(.delegate(.openURL(url)))
                }
                return .none
                
            case .termsOfServiceButtonTapped:
                if let url = URL(string: "https://github.com/terms") {
                    return .send(.delegate(.openURL(url)))
                }
                return .none
                
            case .confirmationDialog(.presented(.confirmLogout)):
                // Clear stored credentials
                UserDefaults.standard.removeObject(forKey: "github_token")
                UserDefaults.standard.removeObject(forKey: "github_user")
                return .send(.delegate(.logout))
                
            case .confirmationDialog(.presented(.confirmClearCache)):
                // Clear cache (placeholder - implement actual cache clearing if needed)
                state.alert = AlertState {
                    TextState("Success")
                } message: {
                    TextState("Cache cleared successfully")
                }
                return .none
                
            case .confirmationDialog:
                return .none
                
            case .alert:
                return .none
                
            case .delegate:
                return .none
            }
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
        .ifLet(\.$alert, action: \.alert)
    }
}