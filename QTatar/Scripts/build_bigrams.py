#!/usr/bin/env python3
"""Backward-compatible entry point. Builds bigrams and trigrams."""

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_ngrams import DB_PATH, build_ngrams


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Dictionary database not found: {DB_PATH}")

    with sqlite3.connect(DB_PATH) as conn:
        bigram_count, trigram_count = build_ngrams(conn, [])

    print(f"Built {bigram_count} bigrams and {trigram_count} trigrams in {DB_PATH}")


if __name__ == "__main__":
    main()
