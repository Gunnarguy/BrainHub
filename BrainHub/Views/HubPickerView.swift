import SwiftUI

struct HubPickerView: View {
    @ObservedObject var viewModel: ContentViewModel
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search hubs...", text: $viewModel.hubSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                List(viewModel.visibleDescriptors(), id: \.id) { descriptor in
                    Button(action: {
                        viewModel.assignHub(descriptor.id)
                        dismiss()
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(descriptor.title).font(.headline)
                                Text(descriptor.id).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if viewModel.isCurrent(descriptor.id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .contextMenu {
                        Button(viewModel.hubStore.pinned.contains(descriptor.id) ? "Unpin" : "Pin") {
                            viewModel.hubStore.togglePin(descriptor.id)
                        }
                    }
                }
            }
            .navigationTitle(viewModel.hubPickerMode == .ingest ? "Select Ingest Hub" : "Filter Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
