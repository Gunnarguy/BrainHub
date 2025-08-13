# Evaluation Harness (Initial Skeleton)

This folder will hold the golden query sets and scripts to compute retrieval metrics.

## Structure

```
/tools/eval
  README.md
  gold/
    health_seed.jsonl
    papers_seed.jsonl
    api_docs_seed.jsonl
  scripts/
    evaluate.py
```

## Metrics

- Recall@k, NDCG@k, MRR.
- Default k values: 5,10.

## Workflow (Early Stage)

1. Populate seed gold files (≈10 queries each hub) with positive chunk IDs (once chunks exist).
2. Run `evaluate.py --gold tools/eval/gold/*.jsonl --results run.jsonl` after producing a retrieval run file.
3. Inspect JSON summary; update baseline if metrics improved without regressions elsewhere.

## Gold JSONL Record Format (Proposed)

```json
{
  "id": "uuid",
  "hub": "health",
  "query": "average resting heart rate last 30 days",
  "positive_chunk_ids": ["chunk_123", "chunk_456"],
  "difficulty": "medium"
}
```

## Run File Format (run.jsonl)

```json
{
  "query_id": "uuid",
  "ranked_chunk_ids": ["chunk_456", "chunk_789", "chunk_123"],
  "scores": [12.3, 11.1, 10.9]
}
```

## Next

- Add `evaluate.py` once chunking + retrieval pipeline is in place so we can output run files.
