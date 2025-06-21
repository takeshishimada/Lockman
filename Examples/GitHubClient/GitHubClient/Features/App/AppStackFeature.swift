import ComposableArchitecture
import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

@Reducer
struct AppStackFeature {
    @Reducer(state: .equatable)
    enum Path {
        case login(LoginFeature)
        case repositoryDetail(RepositoryDetailFeature)
        case userProfile(UserProfileFeature)
        case followerList(FollowerListFeature)
        case followingList(FollowingListFeature)
        case userRepositories(UserRepositoriesFeature)
        case issueDetail(IssueDetailFeature)
        case issueCreate(IssueCreateFeature)
        case issueEdit(IssueEditFeature)
    }
    
    @ObservableState
    struct State: Equatable {
        var isLoggedIn = false
        var path = StackState<Path.State>()
        var tabContainer = TabContainerFeature.State()
        @Presents var settings: SettingsFeature.State?
    }
    
    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case tabContainer(TabContainerFeature.Action)
        case settings(PresentationAction<SettingsFeature.Action>)
        case onAppear
        case authenticationError
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.tabContainer, action: \.tabContainer) {
            TabContainerFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .onAppear:
                // Check if user is already authenticated
                let hasToken = UserDefaults.standard.string(forKey: "github_token") != nil
                let hasUser = UserDefaults.standard.data(forKey: "github_user") != nil
                state.isLoggedIn = hasToken && hasUser
                
                if !state.isLoggedIn {
                    state.path.append(.login(LoginFeature.State()))
                }
                return .none
                
            case .path(.element(id: _, action: .login(.delegate(.loginSuccess)))):
                state.isLoggedIn = true
                state.path.removeAll()
                return .none
                
            case .tabContainer(.delegate(let action)):
                switch action {
                case .repositoryTapped(let id):
                    state.path.append(.repositoryDetail(RepositoryDetailFeature.State(repositoryId: id)))
                    return .none
                    
                case .userTapped(let username):
                    state.path.append(.userProfile(UserProfileFeature.State(username: username)))
                    return .none
                    
                case .issueTapped(let id):
                    state.path.append(.issueDetail(IssueDetailFeature.State(issueId: id)))
                    return .none
                    
                case .createIssueTapped:
                    state.path.append(.issueCreate(IssueCreateFeature.State()))
                    return .none
                    
                case .settingsTapped:
                    state.settings = SettingsFeature.State()
                    return .none
                    
                case .authenticationError:
                    return .send(.authenticationError)
                    
                case .repositoriesTapped:
                    state.path.append(.userRepositories(UserRepositoriesFeature.State()))
                    return .none
                    
                case .followersTapped(let username):
                    state.path.append(.followerList(FollowerListFeature.State(username: username)))
                    return .none
                    
                case .followingTapped(let username):
                    state.path.append(.followingList(FollowingListFeature.State(username: username)))
                    return .none
                }
                
            case .path(.element(id: _, action: .repositoryDetail(.delegate(let action)))):
                switch action {
                case .viewIssuesTapped(_):
                    // Navigate to Issues tab with repository filter
                    return .none
                    
                case .viewOwnerTapped(let username):
                    state.path.append(.userProfile(UserProfileFeature.State(username: username)))
                    return .none
                    
                case .openURL(let url):
                    // Open URL in Safari
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                    return .none
                }
                
            case .path(.element(id: _, action: .userProfile(.delegate(let action)))):
                switch action {
                case .repositoryTapped(let repositoryId):
                    state.path.append(.repositoryDetail(RepositoryDetailFeature.State(repositoryId: repositoryId)))
                    return .none
                    
                case .followersTapped(let username):
                    state.path.append(.followerList(FollowerListFeature.State(username: username)))
                    return .none
                    
                case .followingTapped(let username):
                    state.path.append(.followingList(FollowingListFeature.State(username: username)))
                    return .none
                }
                
            case .path(.element(id: _, action: .followerList(.delegate(let action)))):
                switch action {
                case .userTapped(let username):
                    state.path.append(.userProfile(UserProfileFeature.State(username: username)))
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .path(.element(id: _, action: .followingList(.delegate(let action)))):
                switch action {
                case .userTapped(let username):
                    state.path.append(.userProfile(UserProfileFeature.State(username: username)))
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .path(.element(id: _, action: .userRepositories(.delegate(let action)))):
                switch action {
                case .repositoryTapped(let repositoryId):
                    state.path.append(.repositoryDetail(RepositoryDetailFeature.State(repositoryId: repositoryId)))
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .path(.element(id: _, action: .issueDetail(.delegate(let action)))):
                switch action {
                case .editTapped(let issueId):
                    state.path.append(.issueEdit(IssueEditFeature.State(issueId: issueId)))
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .path(.element(id: _, action: .issueCreate(.delegate(let action)))):
                switch action {
                case .issueCreated(_):
                    // Could navigate to the created issue, but for now just pop
                    return .none
                case .cancelled:
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .path(.element(id: _, action: .issueEdit(.delegate(let action)))):
                switch action {
                case .issueUpdated(_):
                    // Could update the issue in the previous screen
                    return .none
                case .cancelled:
                    return .none
                case .authenticationError:
                    return .send(.authenticationError)
                }
                
            case .settings(.presented(.delegate(let action))):
                switch action {
                case .logout:
                    // Clear auth state
                    UserDefaults.standard.removeObject(forKey: "github_token")
                    UserDefaults.standard.removeObject(forKey: "github_user")
                    state.isLoggedIn = false
                    state.settings = nil
                    state.path.removeAll()
                    state.path.append(.login(LoginFeature.State()))
                    return .none
                    
                case .dismiss:
                    state.settings = nil
                    return .none
                    
                case .openURL(let url):
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #endif
                    return .none
                }
                
            case .path:
                return .none
                
            case .tabContainer:
                return .none
                
            case .settings:
                return .none
                
            case .authenticationError:
                // Handle authentication error
                UserDefaults.standard.removeObject(forKey: "github_token")
                UserDefaults.standard.removeObject(forKey: "github_user")
                state.isLoggedIn = false
                state.settings = nil
                state.path.removeAll()
                state.path.append(.login(LoginFeature.State()))
                return .none
            }
        }
        .forEach(\.path, action: \.path)
        .ifLet(\.$settings, action: \.settings) {
            SettingsFeature()
        }
    }
}