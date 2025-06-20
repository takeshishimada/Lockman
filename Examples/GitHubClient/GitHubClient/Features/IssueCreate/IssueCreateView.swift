import ComposableArchitecture
import SwiftUI

struct IssueCreateView: View {
    let store: StoreOf<IssueCreateFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Issue")
                .font(.largeTitle)
                .bold()
            
            Text("New Issue Form")
                .font(.headline)
        }
        .padding()
        .navigationTitle("New Issue")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}