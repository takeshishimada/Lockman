import ComposableArchitecture
import SwiftUI

@ViewAction(for: SettingsFeature.self)
struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsFeature>
    
    var body: some View {
        NavigationStack {
            List {
                // User Section
                if let user = store.currentUser {
                    Section {
                        HStack(spacing: 12) {
                            AsyncImage(url: URL(string: user.avatarURL)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Color(.systemGray4)
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                if let name = user.name {
                                    Text(name)
                                        .font(.headline)
                                }
                                Text("@\(user.login)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // App Info Section
                Section("About") {
                    Button(action: {
                        send(.aboutButtonTapped)
                    }) {
                        HStack {
                            Label("About GitHub Client", systemImage: "info.circle")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("v\(store.appVersion)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button(action: {
                        send(.privacyPolicyButtonTapped)
                    }) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: {
                        send(.termsOfServiceButtonTapped)
                    }) {
                        Label("Terms of Service", systemImage: "doc.text")
                            .foregroundStyle(.primary)
                    }
                }
                
                // Cache Section
                Section("Data") {
                    Button(action: {
                        send(.clearCacheButtonTapped)
                    }) {
                        Label("Clear Cache", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
                
                // Account Section
                Section {
                    Button(action: {
                        send(.logoutButtonTapped)
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                                .fontWeight(.medium)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        send(.closeButtonTapped)
                    }
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.view.alert))
        .confirmationDialog($store.scope(state: \.confirmationDialog, action: \.view.confirmationDialog))
        .onAppear {
            send(.onAppear)
        }
    }
}