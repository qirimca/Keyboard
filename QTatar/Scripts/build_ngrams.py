#!/usr/bin/env python3
"""Build bigram and trigram tables for QırımKey next-word prediction."""

from __future__ import annotations

import argparse
import collections
import re
import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "Demo" / "Keyboard" / "qırım_tatar.db"

WORD_DELIMITERS = "!.?,;:()[]{}<> \n\t\r"
TOKEN_SPLIT_PATTERN = re.compile(r"[^\wğüşıöçñĞÜŞİÖÇÑıİ]+", re.UNICODE)

# High-value continuations that are missing from the dictionary phrase list.
SEED_TRIGRAMS: dict[tuple[str, str, str], int] = {
    ("bir", "şey", "yok"): 620,
    ("bir", "şey", "bar"): 540,
    ("bir", "şey", "de"): 480,
    ("bir", "şey", "içün"): 430,
    ("bir", "şey", "edi"): 390,
    ("bir", "şey", "bolğan"): 260,
    ("bir", "şey", "yasa"): 220,
    ("bir", "şey", "qıldı"): 200,
    ("men", "de", "öyle"): 180,
    ("o", "da", "öyle"): 170,
    ("ve", "son", "ra"): 160,
}

SEED_BIGRAMS: dict[tuple[str, str], int] = {}


def tokenize(text: str) -> list[str]:
    parts = [part.strip() for part in TOKEN_SPLIT_PATTERN.split(text.lower())]
    return [part for part in parts if part]


def collect_ngrams_from_phrases(
    phrases: list[tuple[str, int]],
) -> tuple[
    collections.Counter[tuple[str, str]],
    collections.Counter[tuple[str, str, str]],
]:
    bigrams: collections.Counter[tuple[str, str]] = collections.Counter()
    trigrams: collections.Counter[tuple[str, str, str]] = collections.Counter()

    for phrase, freq in phrases:
        parts = [part.lower() for part in phrase.split()]
        for index in range(len(parts) - 1):
            bigrams[(parts[index], parts[index + 1])] += freq
        for index in range(len(parts) - 2):
            trigrams[(parts[index], parts[index + 1], parts[index + 2])] += freq

    return bigrams, trigrams


def augment_bigrams(
    bigrams: collections.Counter[tuple[str, str]],
    unigrams: dict[str, int],
) -> None:
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
            bigrams[key] = bigrams.get(key, 0) + (
                synthetic // 4 if key in bigrams else synthetic
            )


def ingest_corpus_file(
    path: Path,
    bigrams: collections.Counter[tuple[str, str]],
    trigrams: collections.Counter[tuple[str, str, str]],
) -> int:
    lines = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        tokens = tokenize(line)
        if len(tokens) < 2:
            continue
        lines += 1
        for index in range(len(tokens) - 1):
            bigrams[(tokens[index], tokens[index + 1])] += 1
        for index in range(len(tokens) - 2):
            trigrams[(tokens[index], tokens[index + 1], tokens[index + 2])] += 1
    return lines


def write_bigrams(
    conn: sqlite3.Connection,
    bigrams: collections.Counter[tuple[str, str]],
) -> int:
    cursor = conn.cursor()
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
    return len(bigrams)


def write_trigrams(
    conn: sqlite3.Connection,
    trigrams: collections.Counter[tuple[str, str, str]],
) -> int:
    cursor = conn.cursor()
    cursor.execute("DROP TABLE IF EXISTS trigrams")
    cursor.execute(
        """
        CREATE TABLE trigrams (
            word1 TEXT NOT NULL,
            word2 TEXT NOT NULL,
            word3 TEXT NOT NULL,
            freq INTEGER NOT NULL,
            PRIMARY KEY (word1, word2, word3)
        )
        """
    )
    cursor.execute("CREATE INDEX idx_trigrams_context ON trigrams(word1, word2)")
    cursor.executemany(
        "INSERT INTO trigrams(word1, word2, word3, freq) VALUES (?, ?, ?, ?)",
        [
            (word1, word2, word3, freq)
            for (word1, word2, word3), freq in trigrams.items()
        ],
    )
    return len(trigrams)


def build_ngrams(
    conn: sqlite3.Connection,
    corpus_paths: list[Path],
) -> tuple[int, int]:
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

    bigrams, trigrams = collect_ngrams_from_phrases(phrases)
    augment_bigrams(bigrams, unigrams)

    for key, freq in SEED_BIGRAMS.items():
        bigrams[key] = max(bigrams.get(key, 0), freq)
    for key, freq in SEED_TRIGRAMS.items():
        trigrams[key] = max(trigrams.get(key, 0), freq)

    for corpus_path in corpus_paths:
        lines = ingest_corpus_file(corpus_path, bigrams, trigrams)
        print(f"Ingested {lines} lines from {corpus_path}")

    bigram_count = write_bigrams(conn, bigrams)
    trigram_count = write_trigrams(conn, trigrams)
    conn.commit()
    return bigram_count, trigram_count


def main() -> None:
    parser = argparse.ArgumentParser(description="Build QırımKey n-gram tables")
    parser.add_argument(
        "--db",
        type=Path,
        default=DB_PATH,
        help="Path to qırım_tatar.db",
    )
    parser.add_argument(
        "--corpus",
        type=Path,
        action="append",
        default=[],
        help="Optional UTF-8 corpus text file (can be passed multiple times)",
    )
    args = parser.parse_args()

    if not args.db.exists():
        raise SystemExit(f"Dictionary database not found: {args.db}")

    with sqlite3.connect(args.db) as conn:
        bigram_count, trigram_count = build_ngrams(conn, args.corpus)

    print(f"Built {bigram_count} bigrams and {trigram_count} trigrams in {args.db}")


if __name__ == "__main__":
    main()
