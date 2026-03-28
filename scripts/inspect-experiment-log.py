#!/usr/bin/env python3
"""
Sanity-check script for Hypothesis AI Search experiment logs.

Usage:
    python scripts/inspect-experiment-log.py experiment-log-2026-03-27.json
    python scripts/inspect-experiment-log.py log1.json log2.json   # merge multiple logs
"""

import json
import sys
from collections import Counter


def load_and_merge(paths: list[str]) -> dict:
    merged: dict = {"positive": [], "negative": [], "pending": []}
    for path in paths:
        with open(path) as f:
            log = json.load(f)
        for key in ("positive", "negative", "pending"):
            merged[key].extend(log.get(key, []))
    return merged


def print_section(title: str):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print(f"{'=' * 60}")


def inspect(log: dict):
    exported_at = log.get("exportedAt")
    if exported_at:
        print(f"Exported at: {exported_at}")

    for key in ("positive", "negative", "pending"):
        examples = log.get(key, [])
        print_section(f"{key.capitalize()} examples: {len(examples)}")

        if not examples:
            print("    (none)")
            continue

        tags = Counter(e.get("schemaTag", "") for e in examples)
        print(f"\n  By schema tag:")
        for tag, count in tags.most_common():
            print(f"    {tag or '(empty)':30s} {count}")

        docs = Counter(e.get("documentUri", "") for e in examples)
        if len(docs) > 1:
            print(f"\n  By document:")
            for uri, count in docs.most_common():
                short = uri if len(uri) <= 50 else "..." + uri[-47:]
                print(f"    {short:50s} {count}")

        print(f"\n  Quotes:")
        for e in examples:
            quote = e.get("quote", "")
            short = (quote[:60] + "...") if len(quote) > 60 else quote
            print(f'    [{e.get("schemaTag", "")}] "{short}"')

    total = sum(len(log.get(k, [])) for k in ("positive", "negative", "pending"))
    print_section("Summary")
    print(f"    {'positive':20s} {len(log.get('positive', []))}")
    print(f"    {'negative':20s} {len(log.get('negative', []))}")
    print(f"    {'pending':20s} {len(log.get('pending', []))}")
    print(f"    {'TOTAL':20s} {total}")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <log.json> [log2.json ...]")
        sys.exit(1)

    log = load_and_merge(sys.argv[1:])
    inspect(log)


if __name__ == "__main__":
    main()
