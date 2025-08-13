import SwiftUI
import Combine

enum AppScreen {
    case ingest
    case search
}

enum HubPickerMode {
    case ingest
    case search
}

@MainActor
class ContentViewModel: ObservableObject {
    // Core Services
    private let loader: ManifestLoader
    let hubStore: HubStore
    private let searchService = SearchService()
    private let ingestCoordinator = IngestCoordinator()
    private let logger = EventLogger.shared

    // UI State
    @Published var selectedScreen: AppScreen = .search
    @Published var showingHubPicker = false
    @Published var hubPickerMode: HubPickerMode = .ingest
    @Published var showingFileImporter = false
    
    // Status & Errors
    @Published var status: String = "Ready"
    @Published var fileImportError: String? = nil
    @Published var isIngesting = false
    @Published var isSearching = false

    // Ingest Form State
    @Published var ingestionHubKey: String = "health"
    @Published var newDocTitle: String = ""
    @Published var newDocText: String = "Type or paste content here..."

    // Search State
    @Published var searchTerm: String = ""
    @Published var searchHubFilter: String = "" // empty = all
    @Published var hits: [ChunkHit] = []
    @Published var hubSearch = ""

    init() {
        let l = ManifestLoader(executor: SQLiteExecutor())
        self.loader = l
        self.hubStore = HubStore(manifestLoader: l)
        
        bootstrap()
    }

    // MARK: - Bootstrap
    private func bootstrap() {
        do {
            try DatabaseManager.shared.openIfNeeded()
            try DatabaseManager.shared.migrateSubstrateIfNeeded()
            hubStore.register([
                HubDescriptor(id: "health", title: "Health Data"),
                HubDescriptor(id: "papers", title: "Medical Papers"),
                HubDescriptor(id: "api_docs", title: "API Docs")
            ])
            loader.load(hubStore.descriptors.map { $0.id })
            loader.applyMigrations()
            print("[Bootstrap] Loaded manifests count: \(loader.manifests.count)")
            status = "Ready"
        } catch {
            status = "DB error: \(error.localizedDescription)"
            print("DB error: \(error)")
        }
    }

    // MARK: - Ingestion Logic
    func ingestManual() {
        guard !newDocTitle.trimmingCharacters(in: .whitespaces).isEmpty || !newDocText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Nothing to ingest"; return
        }
        isIngesting = true
        Task {
            do {
                let res = try ingestCoordinator.ingestRawText(newDocText, title: newDocTitle.isEmpty ? "Untitled" : newDocTitle, hubKey: ingestionHubKey)
                status = res.deduped ? "Duplicate skipped" : "Document added"
                newDocTitle = ""
                newDocText = ""
                logger.record(AppEvent(kind: res.deduped ? .ingestDuplicate : .ingestSuccess, message: status, data: ["hub": ingestionHubKey]))
            } catch {
                status = "Ingest error: \(error.localizedDescription)"
                print("Ingest error: \(error)")
                logger.record(AppEvent(kind: .ingestError, message: status, data: ["hub": ingestionHubKey]))
            }
            isIngesting = false
        }
    }

    func importFile(_ url: URL) {
        isIngesting = true
        Task {
            var released = false
            if url.startAccessingSecurityScopedResource() { released = true }
            defer { if released { url.stopAccessingSecurityScopedResource() } }
            
            do {
                let res = try ingestCoordinator.ingestFile(url: url, hubKey: ingestionHubKey)
                status = res.deduped ? "Duplicate file skipped" : "Imported: \(res.documentId ?? "–")"
                fileImportError = nil
                logger.record(AppEvent(kind: res.deduped ? .ingestDuplicate : .ingestSuccess, message: status, data: ["hub": ingestionHubKey]))
            } catch {
                status = "Import error"
                fileImportError = error.localizedDescription
                print("File import error: \(error)")
                logger.record(AppEvent(kind: .ingestError, message: status, data: ["hub": ingestionHubKey]))
            }
            isIngesting = false
        }
    }

    // MARK: - Search Logic
    func runSearch() {
        guard !searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            hits = []
            return
        }
        isSearching = true
        Task {
            do {
                if searchHubFilter.isEmpty {
                    hits = try searchService.search(term: searchTerm)
                } else {
                    hits = try searchService.search(hubKey: searchHubFilter, term: searchTerm)
                }
                status = "Found \(hits.count) results"
                logger.record(AppEvent(kind: .searchRun, message: status, data: ["hubFilter": searchHubFilter, "term": searchTerm, "count": String(hits.count)]))
            } catch {
                status = "Search error: \(error.localizedDescription)"
                print("Search error: \(error)")
                logger.record(AppEvent(kind: .searchError, message: status, data: ["hubFilter": searchHubFilter, "term": searchTerm]))
            }
            isSearching = false
        }
    }

    // MARK: - Hub Picker Logic
    func presentHubPicker(for mode: HubPickerMode) {
        hubPickerMode = mode
        hubSearch = ""
        showingHubPicker = true
    }
    
    func visibleDescriptors() -> [HubDescriptor] {
        if hubSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hubStore.orderedForPicker()
        } else {
            return hubStore.searchDescriptors(hubSearch)
        }
    }

    func assignHub(_ id: String) {
        switch hubPickerMode {
        case .ingest: ingestionHubKey = id
        case .search: searchHubFilter = id
        }
        _ = loader.manifest(key: id) // Touch manifest lazily
    }

    func isCurrent(_ id: String) -> Bool {
        switch hubPickerMode {
        case .ingest: return ingestionHubKey == id
        case .search: return searchHubFilter == id
        }
    }
}
