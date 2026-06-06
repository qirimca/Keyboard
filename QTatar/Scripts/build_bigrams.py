#!/usr/bin/env python3
"""Build the bigrams table used for next-word prediction in QırımKey."""

from __future__ import annotations

import collections
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "Demo" / "Keyboard" / "qırım_tatar.db"


def build_bigrams(conn: sqlite3.Connection) -> int:
    cursor = conn.cursor()
    unigrams = {
        word.lower(): freq
        for word, freq in cursor.execute(
            'SELECT word, freq FROM words WHERE instr(word, " ") = 0'
        )
    }
    phrases = cursor.execute(
        "SELECT word, freq FROM words WHERE instr(word, ' ') > 0"
    ).fetchall()

    bigrams: collections.Counter[tuple[str, str]] = collections.Counter()
    for phrase, freq in phrases:
        parts = [part.lower() for part in phrase.split()]
        for index in range(len(parts) - 1):
            bigrams[(parts[index], parts[index + 1])] += freq

    top = sorted(unigrams.items(), key=lambda item: -item[1])[:200]
    for word1, freq1 in top[:120]:
        outgoing = sum(1 for left, _ in bigrams if left == word1)
        if outgoing >= 8:
            continue
        for word2, freq2 in top[:60]:
            if word1 == word2:
                continue
            synthetic = int((freq1 * freq2) ** 0.5 / 100)
            if synthetic <= 0:
                continue
            key = (word1, word2)
            bigrams[key] = bigrams.get(key, 0) + (synthetic // 4 if key in bigrams else synthetic)

    cursor.execute("DROP TABLE IF EXISTS bigrams")
    cursor.execute(
        """
        CREATE TABLE bigrams (
            word1 TEXT NOT NULL,
            word2 TEXT NOT NULL,
            freq INTEGER NOT NULL,
            PRIMARY KEY (word1, word2)
        )
        """
    )
    cursor.execute("CREATE INDEX idx_bigrams_word1 ON bigrams(word1)")
    cursor.executemany(
        "INSERT INTO bigrams(word1, word2, freq) VALUES (?, ?, ?)",
        [(left, right, freq) for (left, right), freq in bigrams.items()],
    )
    conn.commit()
    return len(bigrams)


def main() -> None:
    if not DB_PATH.exists():
        raise SystemExit(f"Dictionary database not found: {DB_PATH}")

    with sqlite3.connect(DB_PATH) as conn:
        count = build_bigrams(conn)

    print(f"Built {count} bigrams in {DB_PATH}")


if __name__ == "__main__":
    main()
