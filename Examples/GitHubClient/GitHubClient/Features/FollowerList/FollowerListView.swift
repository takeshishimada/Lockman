import ComposableArchitecture
import SwiftUI

struct FollowerListView: View {
    let store: StoreOf<FollowerListFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Followers")
                .font(.largeTitle)
                .bold()
            
            Text("Followers of: \(store.username)")
                .font(.headline)
            
            Button("User Profile") {
                store.send(.userTapped)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}