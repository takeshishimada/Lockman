import ComposableArchitecture
import SwiftUI

struct LoginView: View {
    @Bindable var store: StoreOf<LoginFeature>
    
    var body: some View {
        VStack(spacing: 30) {
            VStack(spacing: 10) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                
                Text("GitHub Client")
                    .font(.largeTitle)
                    .bold()
                
                Text("Sign in with your GitHub account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 50)
            
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Personal Access Token")
                        .font(.headline)
                    
                    SecureField("Enter your GitHub token", text: $store.token)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disabled(store.isLoading)
                    
                    Text("You can create a token in GitHub Settings > Developer settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Button(action: {
                    store.send(.loginButtonTapped)
                }) {
                    HStack {
                        if store.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isLoading || store.token.isEmpty)
            }
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("How to get a Personal Access Token:")
                    .font(.footnote)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Go to GitHub Settings")
                    Text("2. Developer settings")
                    Text("3. Personal access tokens > Tokens (classic)")
                    Text("4. Generate new token")
                    Text("5. Select scopes: repo, user")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .navigationBarHidden(true)
        .alert($store.scope(state: \.alert, action: \.alert))
        .onAppear {
            store.send(.onAppear)
        }
    }
}