# BrainHub Beta Blueprint (Live Document)

> **Last Updated: August 12, 2025**
> This document is the architectural north star and reflects the current state of the prototype. It evolves as the implementation progresses.

## 0. Current Implementation Status

The project has successfully completed the initial phase of foundational work. The current prototype is a runnable SwiftUI application with the following core capabilities:

- **Database & Schema**: A comprehensive SQLite database schema has been established using raw `sqlite3` calls managed by `DatabaseManager`. This includes tables for workspaces, hubs, documents, chunks, and placeholders for future features like embeddings and a knowledge graph. Migrations are designed to be idempotent.
- **Ingestion Pipeline**: A sophisticated, extensible ingestion system is in place.
  - **`IngestCoordinator`**: Orchestrates the entire process. The data flow has been refined to ensure reliable hash updates for deduplication.
  - **`ParserRegistry`**: A modular system that can parse various file types. It currently supports plain text, Markdown, and PDFs (via `PDFKit`). It is designed for easy extension with new parsers.
  - **Content Hashing & Deduplication**: `HashUtil` provides SHA256 hashing to prevent ingesting duplicate content into the same hub. The hash is now reliably stored after ingestion.
- **Hub Management**: The `HubStore` provides a scalable solution for managing a large number of hubs. It uses lightweight `HubDescriptor` objects to populate the UI, enabling features like searching, pinning, and viewing recent hubs without loading all hub manifests into memory.
- **User Interface (SwiftUI)**:
  - A scalable hub picker allows users to select a target hub for ingestion or a filter for searching.
  - The UI supports both manual text entry and file-based ingestion using the system's `fileImporter`.
  - Search results are displayed in a simple list view.
- **Lexical Search**: `SearchService` implements FTS5-based full-text search, which can be performed globally or scoped to a specific hub.

---

## 1. Scope (Beta)

Core Hubs:

1.  **Health Data Hub** – wearable exports, manual logs, sleep, workouts, mood.
2.  **Medical Papers Hub** – PDFs (RCTs, reviews), metadata (DOI, year, authors), citation graph.
3.  **API Documentation Hub** – Markdown docs, endpoint specs, code snippets, change logs.

Functional Pillars:

- **[✓] Ingest any document**: A flexible parser system is implemented.
- **[ ] Hybrid Retrieval**: The foundation is laid, but vector generation and fusion logic are next.
- **[ ] Citations**: The data model supports this, but UI integration is pending.
- **[ ] NL→SQL**: Deferred.
- **[ ] Sync & Cloud Assist**: Deferred.
- **[ ] Automations**: Deferred.
- **[ ] Diagnostics HUD**: Deferred.

Non-Functional:

- **[✓] Privacy-first**: The app is currently 100% offline.
- **[ ] Energy & Storage Budgets**: Not yet measured.
- **[✓] Evaluation Harness**: Skeleton is in place (`eval/`).

---

## 2. High-Level Architecture (Current)

```
[iOS App (SwiftUI)]
  UI Layer (ContentView):
    - Scalable Hub Picker (Search, Pin, Recent)
    - Ingest View (Manual text + File Importer)
    - Search View (Global + Hub-scoped)

  Core Logic:
    - HubStore: Manages hub list & selection.
    - IngestCoordinator: Orchestrates parsing, hashing, and storage.
    - ParserRegistry: Extracts text from different file types.
    - SearchService: Executes FTS5 lexical queries.
    - ManifestLoader: Loads hub configurations from JSON.

  Persistence Layer (DatabaseManager -> SQLite):
    - Substrate tables (Document, Chunk, etc.)
    - FTS5 virtual table for search.
    - Indexes for performance (e.g., on hub_id, hash).
```

---

## 3. Data Model (Implemented)

The following tables are actively used in the prototype:

```sql
-- Manages user workspaces (currently single, implicit)
CREATE TABLE IF NOT EXISTS workspace(...);

-- Defines the hubs available to the user
CREATE TABLE IF NOT EXISTS hub(...);

-- Stores metadata about each ingested item
CREATE TABLE IF NOT EXISTS document(
  id TEXT PRIMARY KEY,
  hub_id TEXT,
  source TEXT, -- e.g., 'manual', 'pdf', 'md'
  uri TEXT, -- filename or original URL
  title TEXT,
  mime TEXT,
  created_at TEXT,
  updated_at TEXT,
  hash BLOB, -- SHA256 hash of content for deduplication
  meta_json TEXT -- For extra parser-specific metadata
);

-- Stores the text chunks of a document
CREATE TABLE IF NOT EXISTS chunk(
  id TEXT PRIMARY KEY,
  document_id TEXT,
  hub_id TEXT, -- Denormalized for efficient filtering
  ord INTEGER,
  text TEXT,
  meta_json TEXT
);

-- FTS5 virtual table for fast lexical search
CREATE VIRTUAL TABLE IF NOT EXISTS chunk_fts USING fts5(text, content='chunk', content_rowid='rowid');
```

The following tables are created but **not yet populated**: `embedding`, `entity`, `relation`, `event`.

---

## 4. Hub Manifest DSL

The `ManifestModels.swift` and `ManifestLoader.swift` files define the structure for hub configuration. While the loader and models are in place, the application currently uses a static set of three hubs (`health`, `papers`, `api_docs`) and does not yet leverage custom tables or views defined in the manifests. This remains a powerful, unimplemented feature for future expansion.

---

## 5. Retrieval Pipeline (Current vs. Target)

**Current (Lexical Only):**

1.  User enters a search term.
2.  `SearchService` executes an FTS5 `MATCH` query against the `chunk_fts` table.
3.  If a `hubKey` is provided, the query is filtered using the denormalized `hub_id` on the `chunk` table.
4.  Results are returned as a list of `ChunkHit` objects.

**Target (Hybrid):**

1.  Tokenize query (stoplist, synonyms).
2.  **[Current]** Local lexical search via FTS5.
3.  **[Next]** Query embedding + cosine similarity search over chunk vectors.
4.  **[Next]** Z-score normalization and fusion of lexical and dense scores.
5.  **[Next]** Optional server-side reranking.
6.  **[Next]** Assemble results with citation data.

---

## 11. Phased Implementation (Updated)

| Phase                      | Status       | Key Outputs & Next Steps                                                                                        |
| -------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------- |
| **0. Foundations**         | **✓ Done**   | **Outputs**: DB schema, FTS5 search, scalable hub picker, extensible ingestion pipeline. **Exit Criteria Met**. |
| **1. Hybrid Local**        | **In Prog.** | **Next**: Implement `EmbeddingService` (stub first), store vectors, add fusion logic to `SearchService`.        |
| **2. Manifests & Schemas** | To Do        | **Next**: Implement `plannedSQL()` execution from manifests to create custom tables/views.                      |
| **3. Server + Sync**       | To Do        | Deferred.                                                                                                       |
| **4. NL→SQL Safety**       | To Do        | Deferred.                                                                                                       |
| **5. Automations**         | To Do        | Deferred.                                                                                                       |
| **6. Eval + CI**           | To Do        | **Next**: Implement `RunExporter` to generate `run.jsonl` and get first baseline metrics from `evaluate.py`.    |

---

## 21. Immediate Next Steps (Revised)

1.  **Implement Parameterized Queries**:
    - **Task**: Enhance `DatabaseManager` to support `sqlite3_bind_*` functions to prevent SQL injection vulnerabilities. This is the highest priority technical debt.
2.  **Implement Embedding Stub**:
    - **Task**: Create an `EmbeddingService` protocol and a stub that generates deterministic, pseudo-random vectors.
    - **Why**: This allows the entire hybrid search pipeline to be built and tested without a dependency on a live model API.
3.  **Establish Evaluation Baseline**:
    - **Task**: Create a `RunExporter` class that can write search results to a `run.jsonl` file.
    - **Why**: This makes the `evaluate.py` script operational, allowing us to get the first `lexical_only.json` baseline metrics.
4.  **Implement Hybrid Search**:
    - **Task**: Add a vector search method to `SearchService` and implement the Z-score fusion logic.
    - **Why**: This is the core of the hybrid retrieval system.

---

_The rest of the document (sections on NL->SQL, Sync, etc.) remains as the forward-looking plan._
