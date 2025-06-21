import ComposableArchitecture
import SwiftUI

struct IssueDetailView: View {
    @Bindable var store: StoreOf<IssueDetailFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            ScrollView {
                if viewStore.isLoading && viewStore.issue == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                } else if let issue = viewStore.issue {
                    VStack(alignment: .leading, spacing: 20) {
                        // Issue Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(issue.state == .open ? "Open" : "Closed", 
                                      systemImage: issue.state == .open ? "circle" : "checkmark.circle")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(issue.state == .open ? Color.green : Color.purple)
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Text("#\(issue.number)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(issue.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack {
                                AsyncImage(url: URL(string: issue.author.avatarURL)) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                }
                                .frame(width: 20, height: 20)
                                .clipShape(Circle())
                                
                                Text(issue.author.login)
                                    .font(.subheadline)
                                
                                Text("opened \(issue.createdAt, style: .relative)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Issue Body
                        if let body = issue.body, !body.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Description")
                                    .font(.headline)
                                
                                Text(body)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Labels
                        if !issue.labels.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Labels")
                                    .font(.headline)
                                
                                FlowLayout(spacing: 8) {
                                    ForEach(issue.labels) { label in
                                        HStack(spacing: 4) {
                                            Circle()
                                                .fill(Color(hex: label.color))
                                                .frame(width: 12, height: 12)
                                            
                                            Text(label.name)
                                                .font(.caption)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(hex: label.color).opacity(0.2))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Metadata
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "bubble.left")
                                Text("\(issue.commentsCount) comments")
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            HStack {
                                Image(systemName: "folder")
                                Text(issue.repository.fullName)
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            
                            if let closedAt = issue.closedAt {
                                HStack {
                                    Image(systemName: "xmark.circle")
                                    Text("Closed \(closedAt, style: .relative)")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .padding()
                }
            }
            .navigationTitle("Issue #\(viewStore.issue?.number ?? 0)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if let issue = viewStore.issue {
                            if issue.state == .open {
                                Button {
                                    store.send(.view(.closeIssueButtonTapped))
                                } label: {
                                    Label("Close Issue", systemImage: "xmark.circle")
                                }
                            } else {
                                Button {
                                    store.send(.view(.reopenIssueButtonTapped))
                                } label: {
                                    Label("Reopen Issue", systemImage: "arrow.clockwise.circle")
                                }
                            }
                            
                            Button {
                                store.send(.view(.editButtonTapped))
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        
                        Button {
                            store.send(.view(.refreshButtonTapped))
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(viewStore.isLoading)
                }
            }
            .onAppear {
                store.send(.view(.onAppear))
            }
            .alert($store.scope(state: \.alert, action: \.view.alert))
        }
    }
}

// Simple FlowLayout for labels
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: result.positions[index].x + bounds.minX,
                                     y: result.positions[index].y + bounds.minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth, x > 0 {
                    x = 0
                    y += maxHeight + spacing
                    maxHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                x += size.width + spacing
                maxHeight = max(maxHeight, size.height)
            }
            
            self.size = CGSize(width: maxWidth, height: y + maxHeight)
        }
    }
}

