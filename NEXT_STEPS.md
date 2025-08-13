# BrainHub – Quick Resume & Next Steps

> **Last Updated: August 13, 2025**
> This document provides a snapshot of the current project state and a clear, actionable plan for what to do next.

## Current State: Foundational Ingestion Pipeline Complete & Refined

The project has a solid, extensible foundation. The core achievement is a flexible ingestion pipeline that can handle arbitrary file types, is managed by a scalable UI, and now has a reliable data flow for deduplication.

### Key Implemented Components:

- **Runnable SwiftUI App**: The app launches, presents a scalable hub picker, and allows users to ingest content and perform lexical searches.
- **Reliable Ingestion Pipeline**:
  - `IngestService` now correctly returns the `documentId` of newly created documents.
  - `IngestCoordinator` uses this ID to perform a precise `UPDATE` of the document's hash, making the deduplication feature robust.
- **Scalable Hub Management (`HubStore`)**: The UI is driven by a `HubStore` that manages a list of lightweight `HubDescriptor` objects. This allows the app to handle a large number of hubs efficiently, with UI components for searching, pinning, and viewing recent hubs.
- **Extensible Parsing (`ParserRegistry`)**:
  - A coordinated process handles file parsing, content hashing for deduplication, and chunking.
  - The parser registry is designed to be easily extended. It currently supports plain text, Markdown, and basic PDF text extraction.
- **File Importer**: Users can select any document from the Files app. The system automatically extracts the text content for ingestion.
- **Database & Search (`DatabaseManager`, `SearchService`)**:
  - A robust SQLite schema is in place with tables for documents, chunks, and hubs.
  - Indexes on `hub_id` and `hash` are implemented for efficient filtering and deduplication.
  - Full-text search (FTS5) is operational and can be scoped to a specific hub.

---

## Immediate Next Steps: From Lexical to Hybrid Search

The next phase focuses on building out the "hybrid" part of the retrieval system and establishing a rigorous evaluation baseline. The ingestion data flow is now secure, so we can proceed.

1.  **Implement Parameterized Queries**:

- **Status**: Implemented. `DatabaseManager` provides a prepared-statement helper `query(_:bind:map:)` and code paths in `SearchService` demonstrate safe `sqlite3_bind_*` usage.
- **Why**: This reduces SQL injection risk and improves robustness; remaining work is broader use coverage and tests.

2.  **Introduce a Stubbed Embedding Service**:

    - **Task**: Create an `EmbeddingService` protocol and a first implementation that generates deterministic, pseudo-random vectors (e.g., by hashing the chunk's text).
    - **Why**: This allows the entire hybrid search pipeline to be built and tested without a dependency on a live model API. It ensures the data flow for storing and retrieving vectors is correct.

3.  **Establish the Evaluation Baseline**:

    - **Task**: Create a `RunExporter` that can generate a `run.jsonl` file from search results.
    - **Why**: This is the final piece needed to make the evaluation harness (`eval/evaluate.py`) operational. The first run will produce `lexical_only.json`, our baseline for all future improvements.

4.  **Implement Hybrid Search Logic**:
    - **Task**: Add a vector search method to `SearchService` (e.g., brute-force cosine similarity). Implement the Z-score fusion logic to combine lexical and vector scores.
    - **Why**: This is the core of the hybrid retrieval system.

---

## Short-Term Backlog (Post-Hybrid)

- **[ ] Real Embedding Provider**: Replace the stubbed `EmbeddingService` with a real implementation that calls a model API (e.g., OpenAI, a local model).
- **[ ] Diagnostics HUD**: Build the UI to visualize search timings, fusion alpha, and other key metrics.
- **[ ] Manifest-Driven Schemas**: Implement the `plannedSQL()` execution from manifests to allow hubs to create their own custom tables and views.
- **[ ] fp16 Vector Storage**: Implement a utility to convert and store vectors as half-precision floats to save space.
- **[ ] UI Polish**: Improve the search results display, add progress indicators for large file imports, etc.

## How to Contribute (A Note to Future You)

1.  **Pick a task** from the "Immediate Next Steps" list.
2.  **Create a new branch** in Git (e.g., `feature/refine-ingestion`).
3.  **Implement the changes**. Focus on keeping components decoupled and testable.
4.  **Update this document** and any other relevant documentation.
5.  **Merge back to main** once the feature is stable.
