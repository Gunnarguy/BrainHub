//  SearchService.swift
//  BrainHub
//  Basic FTS5 search.

import Foundation
import SQLite3

// SQLite helper: Swift doesn't expose SQLITE_TRANSIENT directly.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct ChunkHit: Identifiable { let id: String; let documentId: String; let text: String }

struct SearchService {
    func search(term: String, limit: Int = 20) throws -> [ChunkHit] {
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let db = DatabaseManager.shared
        var results: [ChunkHit] = []
        let sql = "SELECT c.id, c.document_id, c.text FROM chunk_fts f JOIN chunk c ON c.rowid=f.rowid WHERE chunk_fts MATCH ? LIMIT ?";
        try db.query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, term, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        }, map: { stmt in
            if let idC = sqlite3_column_text(stmt, 0), let docC = sqlite3_column_text(stmt, 1), let textC = sqlite3_column_text(stmt, 2) {
                results.append(ChunkHit(id: String(cString: idC), documentId: String(cString: docC), text: String(cString: textC)))
            }
        })
        return results
    }

    /// Hub-scoped lexical search (uses denormalized chunk.hub_id index).
    func search(hubKey: String, term: String, limit: Int = 20) throws -> [ChunkHit] {
        guard !hubKey.isEmpty else { return try search(term: term, limit: limit) }
        guard !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let db = DatabaseManager.shared
        var results: [ChunkHit] = []
        let sql = "SELECT c.id, c.document_id, c.text FROM chunk_fts f JOIN chunk c ON c.rowid=f.rowid WHERE c.hub_id = ? AND chunk_fts MATCH ? LIMIT ?";
        try db.query(sql, bind: { stmt in
            sqlite3_bind_text(stmt, 1, hubKey, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, term, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 3, Int32(limit))
        }, map: { stmt in
            if let idC = sqlite3_column_text(stmt, 0), let docC = sqlite3_column_text(stmt, 1), let textC = sqlite3_column_text(stmt, 2) {
                results.append(ChunkHit(id: String(cString: idC), documentId: String(cString: docC), text: String(cString: textC)))
            }
        })
        return results
    }
}
