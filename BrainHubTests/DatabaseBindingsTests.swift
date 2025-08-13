import XCTest
@testable import BrainHub

final class DatabaseBindingsTests: XCTestCase {
    override func setUpWithError() throws {
        // For tests, ensure we start with a clean in-memory DB if supported or a temp file.
        // DatabaseManager currently opens a file in documents; to avoid test side-effects,
        // we rely on the existing DatabaseManager but ensure migrations run.
        try DatabaseManager.shared.openIfNeeded()
        try DatabaseManager.shared.migrateSubstrateIfNeeded()
    }

    func testInsertAndQueryWithQuotesAndNewlines() throws {
        let db = DatabaseManager.shared
        let docId = UUID().uuidString
        let hubKey = "test_hub"
        let title = "Quote \"and\" Newline"
        let body = "Line1\nLine2 with 'single' and \"double\" quotes"
        let now = ISO8601DateFormatter().string(from: Date())
        let metaJson = "{}"

        // Insert document using parameterized query
        try db.query("INSERT INTO document(id, hub_id, source, uri, title, mime, meta_json, created_at, updated_at) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?)", bind: { stmt in
            sqlite3_bind_text(stmt, 1, docId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 2, hubKey, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 3, "test", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 4, "", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 5, title, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 6, "text/plain", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 7, metaJson, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 8, now, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_bind_text(stmt, 9, now, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }, map: { _ in })

        // Query back the document title
        var fetchedTitle: String? = nil
        try db.query("SELECT title FROM document WHERE id=? LIMIT 1", bind: { stmt in
            sqlite3_bind_text(stmt, 1, docId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }, map: { stmt in
            if let t = sqlite3_column_text(stmt, 0) { fetchedTitle = String(cString: t) }
        })

        XCTAssertEqual(fetchedTitle, title)
    }
}
