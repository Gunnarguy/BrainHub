# BrainHub Case Study & Project Plan

> **Last Updated: August 12, 2025**
> This document outlines the project's goals, current status, and the plan for moving forward. It serves as a reference for both the case study evaluation and the development roadmap.

## 1. Project Vision & Success Metrics

BrainHub is an offline-first iOS application designed for powerful, local information management. Users can create "Hubs" for any topic, each with its own schema and retrieval configuration. The ultimate goal is to provide a tool that is fast, private, and intelligent, enabling users to find information within their own data corpus with high precision and trust.

### Core Success Metrics (Targets for Beta)

| Metric                | Target             | Status         | Notes                                                                                 |
| --------------------- | ------------------ | -------------- | ------------------------------------------------------------------------------------- |
| **Recall@10**         | ≥ 0.85             | To Be Measured | Requires evaluation harness and golden set.                                           |
| **NDCG@10**           | ≥ 0.75             | To Be Measured | The most relevant results must be ranked highest.                                     |
| **Offline Query P95** | ≤ 300 ms           | To Be Measured | Lexical search is fast; this will be tracked as hybrid search is implemented.         |
| **NL→SQL Success**    | ≥ 95 %             | Deferred       | A key feature for structured data hubs like Health.                                   |
| **Battery Usage**     | ≤ 3% per 1k chunks | To Be Measured | Will be measured once background processing and embedding generation are implemented. |

---

## 2. Current Implementation Status

The project has a solid architectural foundation. The focus has been on creating a robust and extensible system for data ingestion and lexical search.

### Key Implemented Features:

- **Universal File Ingestion**: Users can import any file type via the system's file picker. A `ParserRegistry` extracts text from common formats (TXT, MD, PDF) and has a fallback for others. This system is designed to be easily extended with more specialized parsers.
- **Content Deduplication**: All ingested content is hashed (SHA256). The `IngestCoordinator` now reliably checks this hash against the database to prevent storing duplicate documents within the same hub.
- **Scalable Hub Management**: The `HubStore` and a dedicated hub picker UI allow the application to manage a large number of hubs without performance degradation or a cluttered interface. Users can search, pin, and quickly access their most-used hubs.
- **Lexical Search**: A fast, FTS5-based search is fully operational. It supports both global and hub-scoped queries.
- **Data Model**: The SQLite database schema is well-defined, with tables for documents, chunks, and hubs, and includes appropriate indexes for efficient querying.

### Architectural Diagram (Current):

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

  Persistence Layer (DatabaseManager -> SQLite):
    - Tables: document, chunk, hub, etc.
    - Indexes: on hub_id, hash for performance.
    - FTS5 virtual table for search.
```

---

## 3. Solo Developer Project Plan & Workflow

This project is managed with a focus on clear, iterative progress.

### Development Workflow:

- **Source Control**: Git, with a `main` branch and feature branches.
- **IDE & Tooling**: Xcode for Swift/SwiftUI, VS Code for Markdown documentation.
- **Task Management**: The primary guide for development is `NEXT_STEPS.md`, which provides a prioritized list of tasks.

### Testing Strategy:

- **Unit & UI Testing**: To be added for key business logic (e.g., parsing, fusion logic) and critical UI flows.
- **Retrieval Quality Testing**: The `eval/` directory contains the skeleton for a Python-based evaluation harness. The immediate next step is to populate this with a golden set of queries and a `RunExporter` to generate results, allowing for programmatic tracking of `Recall` and `NDCG`.
- **Manual Testing**: Ongoing manual testing on a physical device ensures the user experience remains high quality.

### Deployment & Release Plan:

This is deferred until the application is closer to a feature-complete beta. The plan includes standard App Store submission steps, including setting up App Store Connect, creating assets, writing a privacy policy, and beta testing via TestFlight.

---

## 4. Analysis Plan & Next Steps

The immediate future of the project is focused on evolving from a simple lexical search tool to a true hybrid retrieval system.

### Analysis Plan:

1.  **Establish Lexical Baseline**: The very next step is to generate the first `lexical_only.json` metrics report. This will serve as the benchmark against which all future improvements (like hybrid search) will be measured.
2.  **Measure Hybrid Improvement**: Once vector search and fusion are implemented, new metrics reports will be generated to quantify the improvement in `Recall` and `NDCG`.
3.  **Performance Profiling**: Use Xcode's Instruments to measure query latency and battery usage as new features are added.

### Immediate Development Roadmap:

The detailed, up-to-the-minute roadmap is maintained in **`NEXT_STEPS.md`**. The key priorities are:

1.  **Refine the Ingestion Pipeline**: Improve the data flow to ensure reliable hash and metadata updates.
2.  **Implement Embedding Generation**: Start with a stubbed service to build out the pipeline, then integrate a real model.
3.  **Build the Hybrid Search Logic**: Implement vector search and the fusion of lexical and vector scores.
4.  **Operationalize the Evaluation Harness**: Create the `RunExporter` and the first golden set of queries.

This structured approach ensures that every major architectural change is guided by and validated against clear quality metrics.
