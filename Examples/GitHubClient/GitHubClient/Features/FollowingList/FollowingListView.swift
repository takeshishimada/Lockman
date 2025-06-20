import ComposableArchitecture
import SwiftUI

struct FollowingListView: View {
    let store: StoreOf<FollowingListFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Following")
                .font(.largeTitle)
                .bold()
            
            Text("Following by: \(store.username)")
                .font(.headline)
            
            Button("User Profile") {
                store.send(.userTapped)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .navigationTitle("Following")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}