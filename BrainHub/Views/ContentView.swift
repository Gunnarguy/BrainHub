//
//  ContentView.swift
//  BrainHub
//
//  Minimal prototype UI: lists manifests, allows sample ingest & FTS5 search.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    // Core loaders / stores
    @StateObject private var loader: ManifestLoader
    @StateObject private var hubStore: HubStore
    @State private var initialized = false

    // Ingest form state
    @State private var ingestionHubKey: String = "health"
    @State private var newDocTitle: String = ""
    @State private var newDocText: String = ""

    // Search state
    @State private var searchTerm: String = ""
    @State private var searchHubFilter: String = "" // empty = all
    @State private var hits: [ChunkHit] = []
    @State private var status: String = ""

    private let searchService = SearchService()
    private let ingestCoordinator = IngestCoordinator()

    init() {
        let l = ManifestLoader(executor: SQLiteExecutor())
        _loader = StateObject(wrappedValue: l)
        _hubStore = StateObject(wrappedValue: HubStore(manifestLoader: l))
    }

    // Hub picker sheet state
    @State private var showingHubPicker = false
    @State private var hubSearch = ""
    @State private var hubPickerMode: HubPickerMode = .ingest
    @State private var showingFileImporter = false
    @State private var fileImportError: String? = nil

    private enum HubPickerMode { case ingest, search }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("Ingest Document").font(.headline)
                        hubSelectRow(current: ingestionHubKey, label: "Target Hub", mode: .ingest)
                        TextField("Title", text: $newDocTitle)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $newDocText)
                            .frame(minHeight: 120)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                        HStack(spacing: 12) {
                            Button(action: ingestManual) {
                                Label("Add Text", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            Button(action: { showingFileImporter = true }) {
                                Label("Import", systemImage: "doc.badge.plus")
                                    .labelStyle(.iconOnly)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.bordered)
                            .help("Import from Files app")
                        }
                        if let fileImportError { Text(fileImportError).font(.caption).foregroundColor(.red) }
                        Text(status).font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    Group {
                        Text("Search").font(.headline)
                        HStack(spacing: 8) {
                            TextField("Query text…", text: $searchTerm)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { runSearch() }
                            Button("Go") { runSearch() }
                        }
                        hubSelectRow(current: searchHubFilter, label: "Filter Hub", mode: .search, allowAll: true)
                        if hits.isEmpty {
                            Text("No results yet").foregroundStyle(.secondary).font(.caption)
                        } else {
                            ForEach(hits) { hit in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hit.text).font(.body).lineLimit(4)
                                    Text(hit.id).font(.caption2).foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(Color.blue.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("BrainHub")
            .toolbar { Button("Reload Manifests") { reloadManifests() } }
            .onAppear { if !initialized { bootstrap() } }
        }
    .sheet(isPresented: $showingHubPicker) { hubPickerSheet() }
    .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.data, .content, .item], allowsMultipleSelection: false) { result in
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFile(url)
        case .failure(let error):
            status = "Import error"; fileImportError = error.localizedDescription
        }
    }
    }

    private func bootstrap() {
        do {
            try DatabaseManager.shared.openIfNeeded()
            try DatabaseManager.shared.migrateSubstrateIfNeeded()
            // Register hub descriptors (lightweight). Titles can evolve independent of manifest load.
            hubStore.register([
                HubDescriptor(id: "health", title: "Health Data"),
                HubDescriptor(id: "papers", title: "Medical Papers"),
                HubDescriptor(id: "api_docs", title: "API Docs")
            ])
            print("[Bootstrap] Registered hub descriptors: \(hubStore.descriptors.map{ $0.id })")
            // Optionally eager-load all current manifests (still fast at small scale);
            // future: remove for true lazy behavior.
            loader.load(hubStore.descriptors.map { $0.id })
            loader.applyMigrations()
            print("[Bootstrap] Loaded manifests count: \(loader.manifests.count)")
            status = "Ready"
            initialized = true
        } catch { status = "DB error"; print("DB error: \(error)") }
    }

    private func reloadManifests() {
    loader.load(hubStore.descriptors.map { $0.id })
    loader.applyMigrations()
    print("[Reload] Manifests reloaded: \(loader.manifests.count)")
    }

    private func ingestManual() {
        guard !newDocTitle.trimmingCharacters(in: .whitespaces).isEmpty || !newDocText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "Nothing to ingest"; return
        }
        do {
            let res = try ingestCoordinator.ingestRawText(newDocText, title: newDocTitle.isEmpty ? "Untitled" : newDocTitle, hubKey: ingestionHubKey)
            status = res.deduped ? "Duplicate skipped" : "Document added"
            newDocTitle = ""
            newDocText = ""
        } catch { status = "Ingest error"; print("Ingest error: \(error)") }
    }

    private func runSearch() {
        do {
            if searchHubFilter.isEmpty {
                hits = try searchService.search(term: searchTerm)
            } else {
                hits = try searchService.search(hubKey: searchHubFilter, term: searchTerm)
            }
            status = "Results: \(hits.count)"
        } catch { status = "Search error"; print("Search error: \(error)") }
    }

    private func importFile(_ url: URL) {
        var released = false
        if url.startAccessingSecurityScopedResource() { released = true }
        defer { if released { url.stopAccessingSecurityScopedResource() } }
        do {
            let res = try ingestCoordinator.ingestFile(url: url, hubKey: ingestionHubKey)
            status = res.deduped ? "Duplicate file skipped" : "Imported: \(res.documentId ?? "–")"
            fileImportError = nil
        } catch {
            status = "Import error"
            fileImportError = error.localizedDescription
            print("File import error: \(error)")
        }
    }
}

// MARK: - Hub Picker UI
extension ContentView {
    @ViewBuilder private func hubSelectRow(current: String, label: String, mode: HubPickerMode, allowAll: Bool = false) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Button(action: { hubPickerMode = mode; hubSearch = ""; showingHubPicker = true }) {
                HStack(spacing: 4) {
                    if allowAll && current.isEmpty { Text("All").font(.callout).bold() }
                    else { Text(current.isEmpty ? "Select" : current).font(.callout).bold() }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    @ViewBuilder private func hubPickerSheet() -> some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Search hubs…", text: $hubSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if hubPickerMode == .search {
                            if hubSearch.isEmpty {
                                Button(action: { searchHubFilter = ""; showingHubPicker = false }) {
                                    labelRow(id: "", title: "All Hubs", pinned: false, isCurrent: searchHubFilter.isEmpty)
                                }
                            }
                        }
                        let visible = visibleDescriptors()
                        ForEach(visible, id: \.id) { d in
                            Button(action: { assignHub(d.id); showingHubPicker = false }) {
                                labelRow(id: d.id, title: d.title, pinned: hubStore.pinned.contains(d.id), isCurrent: isCurrent(d.id))
                            }
                            .contextMenu {
                                Button(hubStore.pinned.contains(d.id) ? "Unpin" : "Pin") { hubStore.togglePin(d.id) }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle(hubPickerMode == .ingest ? "Select Ingest Hub" : "Select Search Hub")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { showingHubPicker = false } }
            }
        }
    }

    private func visibleDescriptors() -> [HubDescriptor] {
        let source: [HubDescriptor]
        if hubSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            source = hubStore.orderedForPicker()
        } else {
            source = hubStore.searchDescriptors(hubSearch)
        }
        return source
    }

    private func assignHub(_ id: String) {
        switch hubPickerMode {
        case .ingest: ingestionHubKey = id
        case .search: searchHubFilter = id
        }
        // Touch manifest lazily to ensure it's available later.
        _ = loader.manifest(key: id)
    }

    private func isCurrent(_ id: String) -> Bool {
        switch hubPickerMode {
        case .ingest: return ingestionHubKey == id
        case .search: return searchHubFilter == id
        }
    }

    @ViewBuilder private func labelRow(id: String, title: String, pinned: Bool, isCurrent: Bool) -> some View {
        HStack(spacing: 8) {
            if pinned { Image(systemName: "pin.fill").foregroundColor(.yellow) }
            Text(id).font(.caption).foregroundColor(.secondary)
            Text(title).font(.body)
            Spacer()
            if isCurrent { Image(systemName: "checkmark.circle.fill").foregroundColor(.accentColor) }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .overlay(Divider(), alignment: .bottom)
    }
}

// HubBadge removed in simplified UI (kept here commented if needed later)
// private struct HubBadge: View { ... }

#Preview {
    ContentView()
}
