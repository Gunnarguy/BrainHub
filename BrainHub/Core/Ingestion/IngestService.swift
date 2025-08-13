//  IngestService.swift
//  BrainHub
//  Simple one-chunk text ingest.

import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

        try db.query("INSERT INTO document(id, hub_id, source, uri, title, mime, meta_json, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", bind: { stmt in
            sqlite3_bind_text(stmt, 1, docId, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, hubKey, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, escape(source), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, escape(uri), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 5, escape(title), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 6, "text/plain", -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 7, escape(metaJson), -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 8, now, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 9, now, -1, SQLITE_TRANSIENT)
        }, map: { _ in })

        // Naive chunk split on sentence boundaries fallback to fixed window.
        let sentences = splitIntoSentences(trimmed)
        var current = ""
        var ord = 0
        func flush() throws {
            guard !current.isEmpty else { return }
            let chunkId = UUID().uuidString
            try db.query("INSERT INTO chunk(id, document_id, hub_id, ord, text, meta_json) VALUES(?, ?, ?, ?, ?, ?)", bind: { stmt in
                sqlite3_bind_text(stmt, 1, chunkId, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, docId, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 3, hubKey, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int(stmt, 4, Int32(ord))
                sqlite3_bind_text(stmt, 5, escape(current), -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 6, "{}", -1, SQLITE_TRANSIENT)
            }, map: { _ in })
            // Populate FTS index using parameterized SELECT to find the rowid of the inserted chunk
            try db.query("INSERT INTO chunk_fts(rowid, text) SELECT rowid, text FROM chunk WHERE id=?", bind: { stmt in
                sqlite3_bind_text(stmt, 1, chunkId, -1, SQLITE_TRANSIENT)
            }, map: { _ in })
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
