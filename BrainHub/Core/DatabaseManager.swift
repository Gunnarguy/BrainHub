//  DatabaseManager.swift
//  BrainHub
//  Minimal SQLite wrapper for early development.

import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private init() {}

    func openIfNeeded() throws {
        if db != nil { return }
        let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("brainhub.sqlite")
        if sqlite3_open(url.path, &db) != SQLITE_OK { throw error("Failed to open database") }
        try exec("PRAGMA journal_mode=WAL;")
    }

    func migrateSubstrateIfNeeded() throws {
        // Core tables (no indexes yet)
        let coreTableStmts = [
            "CREATE TABLE IF NOT EXISTS workspace(id TEXT PRIMARY KEY, name TEXT, created_at TEXT)",
            "CREATE TABLE IF NOT EXISTS hub(id TEXT PRIMARY KEY, workspace_id TEXT, key TEXT UNIQUE, title TEXT, manifest_json TEXT)",
            "CREATE TABLE IF NOT EXISTS document(id TEXT PRIMARY KEY, hub_id TEXT, source TEXT, uri TEXT, title TEXT, mime TEXT, created_at TEXT, updated_at TEXT, hash BLOB)",
            "CREATE TABLE IF NOT EXISTS chunk(id TEXT PRIMARY KEY, document_id TEXT, hub_id TEXT, ord INTEGER, text TEXT, meta_json TEXT)",
            "CREATE TABLE IF NOT EXISTS embedding(chunk_id TEXT PRIMARY KEY, vec BLOB)",
            "CREATE TABLE IF NOT EXISTS entity(id TEXT PRIMARY KEY, hub_id TEXT, type TEXT, name TEXT, meta_json TEXT)",
            "CREATE TABLE IF NOT EXISTS relation(id TEXT PRIMARY KEY, hub_id TEXT, head_entity_id TEXT, tail_entity_id TEXT, type TEXT, meta_json TEXT)",
            "CREATE TABLE IF NOT EXISTS event(id TEXT PRIMARY KEY, hub_id TEXT, kind TEXT, payload_json TEXT, created_at TEXT)",
            "CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(text, content='chunk', content_rowid='rowid')"
        ]
        for s in coreTableStmts { try exec(s) }

        // Ensure hub_id column exists on chunk if legacy table lacked it
        do { try exec("ALTER TABLE chunk ADD COLUMN hub_id TEXT") } catch { /* ignore if already present */ }

        // Indexes (safe to run after column ensured)
        let indexStmts = [
            "CREATE INDEX IF NOT EXISTS idx_document_hub ON document(hub_id)",
            "CREATE INDEX IF NOT EXISTS idx_document_hash ON document(hash)",
            "CREATE INDEX IF NOT EXISTS idx_chunk_doc ON chunk(document_id)",
            "CREATE INDEX IF NOT EXISTS idx_chunk_hub ON chunk(hub_id)"
        ]
        for s in indexStmts { try exec(s) }

        // Add meta_json to document for richer metadata (idempotent attempt)
        do { try exec("ALTER TABLE document ADD COLUMN meta_json TEXT") } catch { /* ignore if exists */ }
    }

    func exec(_ sql: String) throws {
        try openIfNeeded()
        var err: UnsafeMutablePointer<Int8>? = nil
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let msg = err.flatMap { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(err)
            throw error("SQL exec failed: \(msg) | SQL=\(sql)")
        }
    }

    func query(_ sql: String, bind: ((OpaquePointer?) -> Void)? = nil, map: (OpaquePointer?) -> Void) throws {
        try openIfNeeded()
        var stmt: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK { throw error("Prepare failed") }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW { map(stmt) }
    }

    private func error(_ msg: String) -> NSError { NSError(domain: "BrainHub.DB", code: 1, userInfo: [NSLocalizedDescriptionKey: msg]) }
}

struct SQLiteExecutor: SQLExecutor { func execute(sql: String) throws { try DatabaseManager.shared.exec(sql) } }
