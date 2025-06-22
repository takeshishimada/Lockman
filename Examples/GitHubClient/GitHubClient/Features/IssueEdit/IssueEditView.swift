import ComposableArchitecture
import SwiftUI

struct IssueEditView: View {
  @Bindable var store: StoreOf<IssueEditFeature>
  @FocusState private var focusedField: Field?

  enum Field {
    case title
    case body
  }

  var body: some View {
    WithViewStore(store, observe: { $0 }) { viewStore in
      NavigationStack {
        if viewStore.isLoadingIssue {
          ProgressView("Loading issue...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewStore.originalIssue != nil {
          ScrollView {
            VStack(alignment: .leading, spacing: 20) {
              // Issue Info
              HStack {
                Text("#\(viewStore.originalIssue?.number ?? 0)")
                  .font(.caption)
                  .foregroundColor(.secondary)

                Spacer()

                if let repository = viewStore.originalIssue?.repository {
                  HStack(spacing: 4) {
                    Image(systemName: "folder")
                      .font(.caption)
                    Text(repository.fullName)
                      .font(.caption)
                  }
                  .foregroundColor(.secondary)
                }
              }
              .padding(.horizontal)

              // Title Field
              VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                  .font(.headline)

                TextField(
                  "Issue title",
                  text: .init(
                    get: { viewStore.title },
                    set: { store.send(.view(.titleChanged($0))) }
                  )
                )
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title)
              }
              .padding(.horizontal)

              // Body Field
              VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                  .font(.headline)

                TextEditor(
                  text: .init(
                    get: { viewStore.body },
                    set: { store.send(.view(.bodyChanged($0))) }
                  )
                )
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .focused($focusedField, equals: .body)
              }
              .padding(.horizontal)

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
                        viewStore.selectedLabels.contains(label)
                          ? Color.accentColor.opacity(0.2) : Color(.systemGray6)
                      )
                      .foregroundColor(
                        viewStore.selectedLabels.contains(label) ? Color.accentColor : Color.primary
                      )
                      .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                  }
                }
              }
              .padding(.horizontal)

              // Changes indicator
              if viewStore.hasChanges {
                HStack {
                  Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                  Text("You have unsaved changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
              }
            }
            .padding(.vertical)
          }
        } else {
          ContentUnavailableView(
            "Issue Not Found",
            systemImage: "exclamationmark.circle",
            description: Text("The issue could not be loaded")
          )
        }
      }
      .navigationTitle("Edit Issue")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            store.send(.view(.cancelButtonTapped))
          }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Save") {
            store.send(.view(.saveButtonTapped))
          }
          .fontWeight(.semibold)
          .disabled(!viewStore.isValid || !viewStore.hasChanges || viewStore.isLoading)
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .alert($store.scope(state: \.alert, action: \.view.alert))
      .overlay {
        if viewStore.isLoading {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay {
              VStack(spacing: 16) {
                ProgressView()
                Text("Saving changes...")
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
