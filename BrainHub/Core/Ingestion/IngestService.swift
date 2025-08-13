//  IngestService.swift
//  BrainHub
//  Simple one-chunk text ingest.

import Foundation

struct IngestService {
    /// Ingest a document: store single document row and split body into fixed-size chunks.
    /// Returns the generated document ID and the number of chunks created.
    func ingestDocument(hubKey: String, title: String, body: String, source: String, uri: String, meta: [String: String], targetChars: Int = 600) throws -> (docId: String, chunkCount: Int) {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", 0) }
        let db = DatabaseManager.shared
        let docId = UUID().uuidString
        let now = ISO8601DateFormatter().string(from: Date())
        let metaJson = (try? String(data: JSONEncoder().encode(meta), encoding: .utf8)) ?? "{}"

        try db.exec("INSERT INTO document(id, hub_id, source, uri, title, mime, meta_json, created_at, updated_at) VALUES('\(docId)', '\(hubKey)', '\(escape(source))', '\(escape(uri))', '\(escape(title))', 'text/plain', '\(escape(metaJson))', '\(now)', '\(now)')")

        // Naive chunk split on sentence boundaries fallback to fixed window.
        let sentences = splitIntoSentences(trimmed)
        var current = ""
        var ord = 0
        func flush() throws {
            guard !current.isEmpty else { return }
            let chunkId = UUID().uuidString
            try db.exec("INSERT INTO chunk(id, document_id, hub_id, ord, text, meta_json) VALUES('\(chunkId)', '\(docId)', '\(hubKey)', \(ord), '\(escape(current))', '{}')")
            try db.exec("INSERT INTO chunk_fts(rowid, text) SELECT rowid, text FROM chunk WHERE id='\(chunkId)'")
            ord += 1
            current = ""
        }
        for s in sentences {
            if current.count + s.count + 1 > targetChars { try flush() }
            current += (current.isEmpty ? "" : " ") + s
        }
        try flush()

        return (docId, ord)
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        // Lightweight heuristic; good enough for prototype.
        let parts = text.split(whereSeparator: { $0 == "." || $0 == "!" || $0 == "?" })
        return parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private func escape(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }
}
