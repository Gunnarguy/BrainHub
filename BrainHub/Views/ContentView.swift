import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showingEvents = false

    var body: some View {
        TabView(selection: $viewModel.selectedScreen) {
            IngestView(viewModel: viewModel)
                .tabItem {
                    Label("Ingest", systemImage: "plus.circle.fill")
                }
                .tag(AppScreen.ingest)

                SearchView(viewModel: viewModel)
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(AppScreen.search)
    }
        .sheet(isPresented: $viewModel.showingHubPicker) {
            HubPickerView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingEvents) { EventsView() }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEvents = true } label: { Image(systemName: "waveform.circle") }
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: [.data, .content, .item],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result: result)
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.importFile(url)
        case .failure(let error):
            viewModel.status = "Import error"
            viewModel.fileImportError = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
}
