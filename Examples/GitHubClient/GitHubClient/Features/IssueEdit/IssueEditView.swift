import ComposableArchitecture
import SwiftUI

struct IssueEditView: View {
    let store: StoreOf<IssueEditFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Issue")
                .font(.largeTitle)
                .bold()
            
            Text("Issue ID: \(store.issueId)")
                .font(.headline)
            
            Text("Edit Form")
                .font(.subheadline)
        }
        .padding()
        .navigationTitle("Edit Issue")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.send(.onAppear)
        }
    }
}