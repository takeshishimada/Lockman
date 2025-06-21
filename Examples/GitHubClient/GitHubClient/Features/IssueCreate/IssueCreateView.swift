import ComposableArchitecture
import SwiftUI

struct IssueCreateView: View {
    @Bindable var store: StoreOf<IssueCreateFeature>
    @FocusState private var focusedField: Field?
    
    enum Field {
        case title
        case body
    }
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Repository Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Repository")
                                .font(.headline)
                            
                            if viewStore.isLoadingRepositories {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading repositories...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            } else {
                                Menu {
                                    ForEach(viewStore.repositories) { repository in
                                        Button {
                                            store.send(.view(.repositorySelected(repository)))
                                        } label: {
                                            HStack {
                                                Text(repository.fullName)
                                                if repository.isPrivate {
                                                    Image(systemName: "lock.fill")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack {
                                        if let selectedRepo = viewStore.selectedRepository {
                                            Text(selectedRepo.fullName)
                                                .foregroundColor(.primary)
                                            if selectedRepo.isPrivate {
                                                Image(systemName: "lock.fill")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        } else {
                                            Text("Select a repository")
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Title Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(.headline)
                            
                            TextField("Issue title", text: .init(
                                get: { viewStore.title },
                                set: { store.send(.view(.titleChanged($0))) }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .focused($focusedField, equals: .title)
                        }
                        
                        // Body Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                            
                            TextEditor(text: .init(
                                get: { viewStore.body },
                                set: { store.send(.view(.bodyChanged($0))) }
                            ))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .focused($focusedField, equals: .body)
                        }
                        
                        // Labels
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Labels")
                                .font(.headline)
                            
                            FlowLayout(spacing: 8) {
                                ForEach(viewStore.availableLabels, id: \.self) { label in
                                    Button {
                                        store.send(.view(.labelToggled(label)))
                                    } label: {
                                        HStack(spacing: 4) {
                                            if viewStore.selectedLabels.contains(label) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.caption)
                                            }
                                            Text(label)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewStore.selectedLabels.contains(label) ?
                                            Color.accentColor.opacity(0.2) :
                                            Color(.systemGray6)
                                        )
                                        .foregroundColor(
                                            viewStore.selectedLabels.contains(label) ?
                                            Color.accentColor :
                                            Color.primary
                                        )
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("New Issue")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            store.send(.view(.cancelButtonTapped))
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Create") {
                            store.send(.view(.createButtonTapped))
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewStore.isValid || viewStore.isLoading)
                    }
                }
                .onAppear {
                    store.send(.view(.onAppear))
                    focusedField = .title
                }
                .alert($store.scope(state: \.alert, action: \.view.alert))
                .overlay {
                    if viewStore.isLoading {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                            .overlay {
                                VStack(spacing: 16) {
                                    ProgressView()
                                    Text("Creating issue...")
                                        .font(.subheadline)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 4)
                            }
                    }
                }
            }
        }
    }
}