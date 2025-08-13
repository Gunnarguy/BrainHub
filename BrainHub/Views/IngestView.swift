import SwiftUI

struct IngestView: View {
    @ObservedObject var viewModel: ContentViewModel
    @FocusState private var focusedField: IngestField?

    private enum IngestField: Hashable { case title, body }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Source Hub").font(.headline)) {
                    HubSelectionRow(
                        label: "Ingest to",
                        selectedHubId: viewModel.ingestionHubKey,
                        allHubs: viewModel.hubStore.descriptors,
                        allowAll: false
                    ) {
                        viewModel.presentHubPicker(for: .ingest)
                    }
                }
                
                Section(header: Text("Content").font(.headline)) {
                    TextField("Document Title (Optional)", text: $viewModel.newDocTitle)
                        .focused($focusedField, equals: .title)
                    
                    TextEditor(text: $viewModel.newDocText)
                        .frame(height: 150)
                        .padding(4)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .focused($focusedField, equals: .body)
                        .onTapGesture {
                            if viewModel.newDocText == "Type or paste content here..." { viewModel.newDocText = "" }
                        }
                }
                
                Section {
                    Button(action: viewModel.ingestManual) {
                        Label("Add Text to Hub", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isIngesting)
                    
                    Button(action: { viewModel.showingFileImporter = true }) {
                        Label("Import File", systemImage: "doc.on.doc.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                }
            }
        .navigationTitle("Ingest")
        // Tap outside to dismiss
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil; hideKeyboard() }
        // Drag to dismiss
        .gesture(DragGesture().onChanged { _ in if focusedField != nil { focusedField = nil; hideKeyboard() } })
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isIngesting {
                        ProgressView()
                    }
                }
            }
        }
    }
}
