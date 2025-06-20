import ComposableArchitecture
import SwiftUI

@ViewAction(for: IssuesFeature.self)
struct IssuesView: View {
    @Bindable var store: StoreOf<IssuesFeature>
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Segment Control
                Picker("Filter", selection: Binding(
                    get: { store.selectedFilter },
                    set: { send(.filterChanged($0)) }
                )) {
                    ForEach(IssuesFeature.IssueFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Issues List
                if store.isLoading && store.issues.isEmpty {
                    Spacer()
                    ProgressView("Loading issues...")
                    Spacer()
                } else if store.filteredIssues.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)
                        Text("No issues found")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        if store.selectedFilter != .all {
                            Text("Try changing the filter")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(store.filteredIssues) { issue in
                            IssueRow(issue: issue) {
                                send(.issueTapped(issue))
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await store.send(.view(.pullToRefresh)).finish()
                    }
                }
            }
            .navigationTitle("Issues")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        send(.refreshButtonTapped)
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(store.isLoading)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        send(.createIssueButtonTapped)
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .alert($store.scope(state: \.alert, action: \.view.alert))
        .onAppear {
            send(.onAppear)
        }
    }
}

// MARK: - Issue Row
struct IssueRow: View {
    let issue: Issue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Title and Number
                HStack(alignment: .top) {
                    Image(systemName: issue.state == .open ? "circle.circle" : "checkmark.circle.fill")
                        .foregroundStyle(issue.state == .open ? .green : .purple)
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        
                        Text("#\(issue.number) • \(issue.repository.fullName)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Labels
                if !issue.labels.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(issue.labels) { label in
                                LabelBadge(label: label)
                            }
                        }
                    }
                }
                
                // Bottom Info
                HStack(spacing: 12) {
                    // Author
                    HStack(spacing: 4) {
                        AsyncImage(url: URL(string: issue.author.avatarURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.systemGray4)
                        }
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                        
                        Text(issue.author.login)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Comments
                    if issue.commentsCount > 0 {
                        Label("\(issue.commentsCount)", systemImage: "bubble.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Updated time
                    Text(issue.updatedAt.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Label Badge
struct LabelBadge: View {
    let label: IssueLabel
    
    var body: some View {
        Text(label.name)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color(hex: label.color).opacity(0.2))
            .foregroundStyle(Color(hex: label.color))
            .cornerRadius(4)
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Date Extension
extension Date {
    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}