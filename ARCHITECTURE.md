# BrainHub Architecture Overview

This document gives a concise, high–signal map of the system so you (and future you) can instantly answer:

1. Where does a piece of functionality live?
2. What flows when I ingest or search?
3. Where do I add new capabilities (parsers, hubs, search types, embeddings)?

---

## Layered View

```
App /
  App/                  -> Entry point + composition (SwiftUI App struct)
  Views/                -> Pure UI (stateless aside from ViewModel bindings)
  Core/                 -> Business & data layer
    Data/               -> Persistence abstractions (SQLite, hub state)
    Hubs/               -> Manifest models + loader
    Ingestion/          -> Orchestration + parsing + chunking
    Search/             -> Retrieval (lexical for now)
    Utils/              -> Cross‑cutting helpers (hashing, logging, events)
  Resources/            -> Declarative hub manifests
  UI/                   -> Asset catalogs (colors, icons)
  eval/                 -> Offline evaluation harness & gold data
```

---

## Primary Domain Concepts

| Concept                    | Summary                                                           | Backing Storage                 |
| -------------------------- | ----------------------------------------------------------------- | ------------------------------- |
| Hub                        | Logical namespace (topic) with its own content & retrieval config | `hub` table + manifest JSON     |
| Document                   | User‑ingested item (file or manual)                               | `document` table                |
| Chunk                      | Subdivision of a document text for retrieval granularity          | `chunk` + `chunk_fts` (FTS5)    |
| Embedding (future)         | Vector representation for semantic search                         | `embedding` table (placeholder) |
| Entity / Relation (future) | Structured extraction                                             | `entity`, `relation` tables     |

---

## Ingestion Flow

1. UI triggers `ContentViewModel.ingestManual()` or `importFile(...)`.
2. `ContentViewModel` calls `IngestCoordinator`.
3. `IngestCoordinator` parses (file -> `ParsedDocument`) via `ParserRegistry`.
4. Dedup check: SHA256 of normalized text vs existing document `hash`.
5. On miss: `IngestService.ingestDocument` chunks + inserts doc & chunks; FTS5 automatically indexes via content table.
6. Hash written back to `document.hash`.
7. Event emitted (`EventLogger`).

Key extension points:

- Support new file types: add parser to `ParserRegistry`.
- Adjust chunk size: change `targetChunkChars` (propagate from UI if desired).
- Add metadata: extend `ParsedDocument.meta` & serialize to `document.meta_json` (future migration).

---

## Search Flow (Lexical)

1. UI calls `ContentViewModel.runSearch()`.
2. Delegates to `SearchService.search(...)` optionally hub‑scoped.
3. SQL FTS5 query returns chunk rows (id, document_id, hub_id, text).
4. UI highlights term and displays snippet with hub/document scaffolding.
5. Event emitted (query + result count).

Future hybrid search:

- Add an `EmbeddingService` generating vectors at ingest time, store in `embedding`.
- Implement ANN or brute‑force cosine over small corpora.
- Fuse lexical & semantic scores (e.g., reciprocal rank fusion or weighted sum).

---

## Event Logging & Observability

`EventLogger` is a lightweight, in‑memory ring buffer (default 200 events) storing structured events:

```
Event(type: .ingestSuccess, message: "Document added", data: ["hub": "health", "docId": "..."], timestamp: Date())
```

Accessible via the Status sheet (gear icon). Use this to understand real‑time system activity without attaching a debugger.

---

## ViewModel Responsibilities

`ContentViewModel` centralizes orchestrations:

- Bootstraps DB + manifests (`bootstrap()`)
- Ingestion & search triggers + async state flags
- Hub selection state + picker logic
- Emits structured events (search runs, ingestion results, errors)

The ViewModel deliberately avoids persistence of ephemeral UI state to disk (fast iteration). Promote to persisted settings only when stable.

---

## Adding a New Hub

1. Create a new `<hub_key>.json` manifest in `Resources/` following existing ones.
2. Add a descriptor in `bootstrap()` (or future dynamic discovery).
3. Relaunch or add a hot‑reload button (already exists: manifests reload action could be reintroduced into UI).

---

## Safety & Data Integrity Notes

- WAL mode enables concurrent reads during ingestion.
- Deduplication: Based on full text hash (strict). Future: fuzzy / similarity dedup before storage.
- No cascade deletes yet (manual cleanup if needed). Consider foreign keys + `ON DELETE` after schema stabilizes.
- Error surfaces: Currently minimal (`NSError` domains). Future improvement: Strongly typed error enums per subsystem.

---

## Immediate Low‑Risk Enhancements (Next Steps)

- Highlight FTS term fragments (implemented).
- Display doc title in search results (requires join or store in chunk row meta).
- Persist pinned hubs & last used hub in `UserDefaults`.
- Add basic settings sheet (chunk size, max results).
- Integrate evaluation harness into an in‑app diagnostic toggle.

---

## Glossary

- Chunk: Small window of text (improves recall & scoring granularity).
- Manifest: Declarative config describing a hub (schema additions, retrieval strategy, presentation hints; currently minimal).
- Hybrid Search: Combining lexical FTS signals with semantic embedding similarity.

---

## Mental Model TL;DR

"A Hub is a scoped mini‑knowledge base. Ingestion normalizes and shards text into chunks. Search runs fast local FTS over chunks, soon to be augmented with vectors. Everything lives local; manifests declare hub structure; a thin ViewModel wires UI to orchestration services."

---

Feel free to prune or expand sections as complexity evolves. Keep this file current—small edits after each architectural change pay exponential clarity dividends.
