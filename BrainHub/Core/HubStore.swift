//  HubStore.swift
//  BrainHub
//  Scalable hub management for large numbers of hubs (lazy manifest load, search, pinning).
//  This is a forward-looking scaffold; current UI does not yet integrate it.

import Foundation
import Combine

/// High-level hub descriptor kept lightweight before full manifest load.
public struct HubDescriptor: Identifiable, Hashable {
    public let id: String  // hub_key
    public let title: String
    public let group: String?
    public let tags: [String]
    public init(id: String, title: String, group: String? = nil, tags: [String] = []) {
        self.id = id; self.title = title; self.group = group; self.tags = tags
    }
}

/// HubStore orchestrates many hubs: lazy manifest loading, search, pinning, recents.
/// Scale Goals:
/// - O(1) lookup by hub key.
/// - Lazy decode only when a hub is opened / queried.
/// - Provide filtered descriptors without loading full manifest array.
final class HubStore: ObservableObject {
    @Published private(set) var descriptors: [HubDescriptor] = []
    @Published private(set) var pinned: Set<String> = []
    @Published private(set) var recent: [String] = []  // MRU order

    private var manifestCache: [String: HubManifest] = [:]
    private let manifestLoader: ManifestLoader
    private let maxRecent = 12

    init(manifestLoader: ManifestLoader) { self.manifestLoader = manifestLoader }

    /// Register a list of hubs (lightweight meta) without loading full manifest bodies yet.
    func register(_ list: [HubDescriptor]) {
        descriptors = list.sorted { $0.title.lowercased() < $1.title.lowercased() }
    }

    /// Returns manifest, loading it if necessary.
    func manifest(for hubKey: String) -> HubManifest? {
        if let m = manifestCache[hubKey] { return m }
        // Attempt to load single manifest via underlying loader.
        manifestLoader.load([hubKey])
        if let m = manifestLoader.manifest(key: hubKey) {
            manifestCache[hubKey] = m
            touchRecent(hubKey)
            return m
        }
        return nil
    }

    /// Search descriptors by title, id, or tags (case-insensitive, simple contains).
    func searchDescriptors(_ q: String) -> [HubDescriptor] {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return descriptors }
        let lower = trimmed.lowercased()
        return descriptors.filter { d in
            if d.id.lowercased().contains(lower) { return true }
            if d.title.lowercased().contains(lower) { return true }
            if d.tags.contains(where: { $0.lowercased().contains(lower) }) { return true }
            return false
        }
    }

    func pin(_ hubKey: String) { pinned.insert(hubKey) }
    func unpin(_ hubKey: String) { pinned.remove(hubKey) }
    func togglePin(_ hubKey: String) { if pinned.contains(hubKey) { pinned.remove(hubKey) } else { pinned.insert(hubKey) } }

    /// Ordered list: pinned first (descriptor order), then recents (excluding pinned), then remaining.
    func orderedForPicker() -> [HubDescriptor] {
        let pinnedList = descriptors.filter { pinned.contains($0.id) }
        let recentList = descriptors.filter { recent.contains($0.id) && !pinned.contains($0.id) }
        var remainingSet = Set(descriptors.map { $0.id })
        pinnedList.forEach { remainingSet.remove($0.id) }
        recentList.forEach { remainingSet.remove($0.id) }
        let remaining = descriptors.filter { remainingSet.contains($0.id) }
        return pinnedList + recentList + remaining
    }

    private func touchRecent(_ hubKey: String) {
        recent.removeAll { $0 == hubKey }
        recent.insert(hubKey, at: 0)
        if recent.count > maxRecent { recent.removeLast() }
    }
}
