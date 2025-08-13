# Copilot instructions for BrainHub

Purpose: help an AI coding assistant be productive immediately in this repository. Keep edits small, safe, and aligned with existing patterns.

Quick facts

- Platform: iOS SwiftUI app (single Xcode project: `BrainHub.xcodeproj`).
- DB: Local SQLite managed by `BrainHub/Core/Data/DatabaseManager.swift` (WAL mode enabled).
- Hub manifests: JSON files in `BrainHub/Resources/` (`health.json`, `papers.json`, `api_docs.json`) and embedded fallbacks in `ManifestLoader`.

What to change and how

- Small, focused PRs only. Prefer changes under 200 lines unless adding new feature modules (then split into multiple PRs).
- Preserve public APIs and on-disk schema unless migration steps are included. Schema changes must be idempotent and use `migrateSubstrateIfNeeded()` (see `DatabaseManager`).

Key locations (examples)

- App entry: `BrainHub/App/BrainHubApp.swift` — keep simple composition; avoid adding heavy sync logic here.
- Boot/VM: `BrainHub/UI/ContentViewModel.swift` — coordinates DB bootstrap, manifest loading, ingestion, search. Mirror its async patterns when adding orchestration.
- Database layer: `BrainHub/Core/Data/DatabaseManager.swift` — use prepared statements and the `query(bind:map:)` contract when interacting with SQLite. Follow the binding examples in comments.
- Hub manifests & loader: `BrainHub/Core/Hubs/ManifestLoader.swift` and `BrainHub/Resources/*.json` — add hub configs here; `ManifestLoader.load(...)` supports embedded fallbacks used in development.
- FTS index: `chunk_fts` is expected; adding text columns should consider the FTS relationship (see `migrateSubstrateIfNeeded`).
- Event logging: `BrainHub/Utils/EventLogger.swift` and `BrainHub/UI/EventsView.swift` — append short structured events (type, message, data) rather than freeform strings.

Patterns & conventions

- Threading: follow existing async / DispatchQueue usage in ViewModels — UI updates must happen on the main thread.
- Error handling: repository uses lightweight NSError domains (e.g., `BrainHub.DB`). New subsystems may follow this pattern for interoperability.
- Idempotent migrations: migrations may run on every bootstrap; write `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE ...` guarded in `do/catch` blocks.
- Parsers: the ingestion pipeline is modular. Add new parsers to the `ParserRegistry` (see `Ingestion/Parsing/*`) and keep parsing pure (string in/out) so dedup/hash logic remains unchanged.

Build & run notes

- Open `BrainHub.xcodeproj` in Xcode and run on a simulator. The DB initializes in the simulator's Documents directory.
- No CI or test runner configured in repo root; unit tests are in `BrainHubTests/`. Run tests from Xcode or `xcodebuild` if needed.

Safety & data considerations

- The app is local-first. Avoid adding external network calls without a feature flag and clear opt-in UX.
- Deduplication is strict SHA256 on normalized text — new ingestion features must call existing hash paths to avoid duplicates.

When adding features

- For new database tables/views: add JSON manifest entry if hub-scoped, or modify `migrateSubstrateIfNeeded()` if global. Keep SQL idempotent.
- For automations (summaries, tagging): manifests declare `automations` (see `Resources/*.json`); implement new action types in the ingestion/automation subsystem.

Tests & validation

- Small unit tests are preferred. Tests live in `BrainHubTests/`.
- When touching DB code, add a smoke test that runs `migrateSubstrateIfNeeded()` and a basic insert/query to avoid regressions.

Common pitfalls to avoid

- Do not assume manifest JSON will always be present on disk — `ManifestLoader` has embedded fallbacks.
- Avoid changing FTS column names or removing `chunk_fts` without a clear migration path; search depends on it.

If you need clarification

- Ask for the intended user-visible behavior and whether changes should run in background or block the UI.

---

Would you like this expanded with a short PR template for AI agents (commits, changelog notes, tests to include)?
