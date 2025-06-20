import ComposableArchitecture
import SwiftUI

struct IssueDetailView: View {
    let store: StoreOf<IssueDetailFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Issue Detail")
                .font(.largeTitle)
                .bold()
            
            Text("Issue ID: \(store.issueId)")
                .font(.headline)
            
            Button("Edit Issue") {
                store.send(.editButtonTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Issue")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}