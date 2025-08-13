# BrainHub

BrainHub is an offline-first iOS app where you create **Hubs** for any topic (Health, Medical Papers, API Docs, Code, etc.). Each Hub is a self-contained package of schema, retrieval configuration, UI views, and automations, designed for powerful, local-first information management.

This repository contains the prototype SwiftUI application and its foundational components.

## Current Status (As of August 13, 2025)

The project is in an early but functional state. The foundational pieces are in place, allowing a user to:

- Launch the app and see a list of default Hubs (`health`, `papers`, `api_docs`).
- Select a Hub for ingestion or search using a scalable picker UI.
- Manually type or paste text into a selected Hub.
- Import any document from the Files app (`.txt`, `.md`, `.pdf`, etc.), with text automatically extracted.
- Perform full-text search (FTS5) across all content or filtered to a specific Hub.
- View search results as context snippets.

### Core Architectural Components Implemented:

- **Database Substrate**: A robust set of SQLite tables for workspaces, hubs, documents, and chunks, managed by `DatabaseManager`.
  - **Safety**: `DatabaseManager` exposes a prepared-statement helper and callers bind parameters with `sqlite3_bind_*` to prevent injection.
- **JSON Manifests**: Hub configurations are loaded from `.json` files located in the `BrainHub/Resources` directory.
- **Scalable Hub Management**: The `HubStore` manages a potentially large number of hubs, with a UI designed for searching and pinning, avoiding cluttered interfaces.
- **Extensible Ingestion Pipeline**:
  - `ParserRegistry`: A modular system that can parse various file types (currently plain text, Markdown, PDF). It's designed to be easily extended with new parsers (e.g., for `.docx`, `.html`).
  - `IngestCoordinator`: Orchestrates the process of parsing, content hashing for deduplication, and chunking.
- **UI**: A basic but functional SwiftUI interface demonstrating ingestion (manual and file-based) and search.

- **Observability**: An in-memory `EventLogger` and `EventsView` capture recent app events for quick diagnostics.
- **Keyboard UX**: Keyboard is now dismissed automatically on tapping or dragging outside text fields; explicit "Hide" buttons were removed.

---

## System at a Glance

```
[iPhone / iPad App (SwiftUI)]
  UI Layer:
    - Scalable Hub Picker (Search, Pin, Recent)
    - Ingest View (Manual text + File Importer)
    - Search View (Global + Hub-scoped)

  Core Logic:
    - HubStore: Manages hub list & selection.
    - IngestCoordinator: Orchestrates parsing & storage.
    - ParserRegistry: Extracts text from different file types.
    - SearchService: Executes lexical queries.

  Persistence Layer (SQLite via DatabaseManager):
    - Documents, Chunks, FTS5 index.
    - Hub definitions (from Resources).
    - Placeholders for embeddings, entities, relations.
```

**Why this design?**

- **Local-first**: Fast, private, and useful on a plane.
- **Extensible Parsers**: New file types can be supported without changing the core ingestion logic.
- **Deduplication**: Content hashing prevents storing the same document multiple times.
- **Scalable UI**: The interface is designed to handle dozens or hundreds of Hubs gracefully.

---

## How to Run

1.  Open `BrainHub.xcodeproj` in Xcode.
2.  Select an iOS Simulator (e.g., iPhone 15 Pro).
3.  Run the `BrainHub` scheme (Product > Run or `⌘R`).

The app will bootstrap its local SQLite database in the simulator's documents directory on the first run.

## Next Steps

The immediate next steps focus on hardening the foundation and moving towards hybrid search. See `NEXT_STEPS.md` for a detailed, up-to-date checklist. Key priorities include:

1.  **Refining Ingestion**: Improving the deduplication and metadata handling.
2.  **Introducing Embeddings**: Adding a service to generate vector embeddings for semantic search.
3.  **Hybrid Search**: Implementing the fusion of lexical (FTS5) and semantic (vector) search scores.
4.  **Evaluation**: Building out the evaluation harness to measure retrieval quality.
