#!/usr/bin/env python3
"""Minimal evaluation script skeleton for BrainHub retrieval.

Usage:
  python evaluate.py --gold tools/eval/gold/*.jsonl --run run.jsonl --k 10

Generates a JSON summary to stdout.

Notes:
- Assumes gold file lines are JSON objects with fields: id, positive_chunk_ids (list)
- Run file lines: query_id, ranked_chunk_ids (ordered list)
"""
from __future__ import annotations
import argparse, json, glob, math, sys
from pathlib import Path
from statistics import mean


def load_jsonl(path: str):
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            yield json.loads(line)


def ndcg_at_k(pred_ids, gold_ids, k):
    dcg = 0.0
    idcg = 0.0
    gold_list = list(gold_ids)[:k]
    for i in range(k):
        if i < len(pred_ids) and pred_ids[i] in gold_ids:
            dcg += 1.0 / math.log2(i + 2)
        if i < len(gold_list):
            idcg += 1.0 / math.log2(i + 2)
    return dcg / idcg if idcg > 0 else 0.0


def recall_at_k(pred_ids, gold_ids, k):
    if not gold_ids:
        return 0.0
    return len(set(pred_ids[:k]) & gold_ids) / len(gold_ids)


def mrr_at_k(pred_ids, gold_ids, k):
    for i, pid in enumerate(pred_ids[:k]):
        if pid in gold_ids:
            return 1.0 / (i + 1)
    return 0.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--gold', nargs='+', required=True, help='Gold JSONL file(s) glob')
    ap.add_argument('--run', required=True, help='Run JSONL file produced by retrieval pipeline')
    ap.add_argument('--k', type=int, default=10)
    args = ap.parse_args()

    # Load gold set
    gold = {}
    for pattern in args.gold:
        for path in glob.glob(pattern):
            for obj in load_jsonl(path):
                gold[obj['id']] = set(obj.get('positive_chunk_ids', []))

    # Load run results
    metrics = {'recall': [], 'ndcg': [], 'mrr': []}
    covered = 0
    for obj in load_jsonl(args.run):
        qid = obj['query_id']
        ranked = obj.get('ranked_chunk_ids', [])
        gold_ids = gold.get(qid)
        if gold_ids is None:
            continue
        covered += 1
        metrics['recall'].append(recall_at_k(ranked, gold_ids, args.k))
        metrics['ndcg'].append(ndcg_at_k(ranked, gold_ids, args.k))
        metrics['mrr'].append(mrr_at_k(ranked, gold_ids, args.k))

    summary = {
        'k': args.k,
        'queries_with_gold': covered,
        'recall_at_k': round(mean(metrics['recall']), 4) if metrics['recall'] else 0.0,
        'ndcg_at_k': round(mean(metrics['ndcg']), 4) if metrics['ndcg'] else 0.0,
        'mrr_at_k': round(mean(metrics['mrr']), 4) if metrics['mrr'] else 0.0,
    }
    json.dump(summary, sys.stdout, indent=2)
    print()


if __name__ == '__main__':
    main()
