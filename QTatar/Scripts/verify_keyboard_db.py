#!/usr/bin/env python3
"""Read-only integrity and schema smoke checks for the bundled QırımKey database.

No external dependencies. Intended for CI and local development:
    python3 QTatar/Scripts/verify_keyboard_db.py
"""
from __future__ import annotations

import hashlib
import sqlite3
import sys
from pathlib import Path
from urllib.parse import quote

DB_PATH = Path(__file__).resolve().parents[1] / "Demo" / "Keyboard" / "qırım_tatar.db"
REQUIRED_TABLES = {"words", "bigrams", "trigrams", "typo_corrections"}
REQUIRED_WORD_COLUMNS = {"word", "freq", "skeleton"}
REQUIRED_INDICES = {"idx_words_first_last_freq", "idx_words_skeleton_freq"}


def verify() -> None:
    if not DB_PATH.is_file():
        raise AssertionError(f"Missing bundled database: {DB_PATH}")

    readonly_uri = f"file:{quote(str(DB_PATH))}?mode=ro"
    with sqlite3.connect(readonly_uri, uri=True, timeout=5) as conn:
        result = conn.execute("PRAGMA integrity_check").fetchone()
        assert result == ("ok",), f"SQLite integrity_check failed: {result}"

        tables = {row[0] for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        )}
        assert REQUIRED_TABLES <= tables, f"Missing tables: {REQUIRED_TABLES - tables}"

        columns = {row[1] for row in conn.execute("PRAGMA table_info(words)")}
        assert REQUIRED_WORD_COLUMNS <= columns, (
            f"Missing words columns: {REQUIRED_WORD_COLUMNS - columns}"
        )
        indices = {row[1] for row in conn.execute("PRAGMA index_list(words)")}
        assert REQUIRED_INDICES <= indices, (
            f"Missing performance indices: {REQUIRED_INDICES - indices}"
        )

        counts = {}
        for table in sorted(REQUIRED_TABLES):
            counts[table] = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            assert counts[table] > 0, f"Unexpectedly empty table: {table}"

        empty_or_negative = conn.execute(
            "SELECT COUNT(*) FROM words WHERE trim(word)='' OR freq < 0"
        ).fetchone()[0]
        assert empty_or_negative == 0, (
            f"Invalid word or negative frequency entries: {empty_or_negative}"
        )

        repeated_words = conn.execute(
            "SELECT COUNT(*) FROM "
            "(SELECT word FROM words GROUP BY word HAVING COUNT(*) > 1)"
        ).fetchone()[0]
        assert repeated_words == 0, f"Duplicate word entries: {repeated_words}"

        sample = conn.execute(
            "SELECT substr(word,1,1), substr(word,-1,1) "
            "FROM words WHERE freq>=2 AND instr(word,' ')=0 LIMIT 1"
        ).fetchone()
        assert sample is not None, "No words suitable for swipe candidate search"
        query = (
            "SELECT word, freq FROM words "
            "WHERE substr(word,1,1)=?1 AND substr(word,-1,1)=?2 "
            "AND freq>=2 AND length(word) BETWEEN 1 AND 128 "
            "AND instr(word,' ')=0 ORDER BY freq DESC LIMIT 10"
        )
        candidates = conn.execute(query, sample).fetchall()
        assert candidates, "Swipe candidate query returned no results"
        plan = " | ".join(str(row[3]) for row in conn.execute(
            "EXPLAIN QUERY PLAN " + query, sample
        ))
        print(f"SQLite version: {sqlite3.sqlite_version}; swipe query plan: {plan}")
        print(f"Table counts: {counts}; words columns: {sorted(columns)}")

    digest = hashlib.sha256(DB_PATH.read_bytes()).hexdigest()
    print(f"Database: {DB_PATH.name} ({DB_PATH.stat().st_size} bytes)")
    print(f"SHA256: {digest}")
    print("PASS: database integrity, structure, indices, duplicates, swipe query")


if __name__ == "__main__":
    try:
        verify()
    except (AssertionError, sqlite3.DatabaseError) as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
