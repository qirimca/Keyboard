#!/usr/bin/env python3
"""Assemble the local corpus used for n-gram generation."""

from __future__ import annotations

import argparse
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT.parent / "Demo" / "Keyboard" / "qırım_tatar.db"
CORPUS_DIR = ROOT / "corpus"
DEFAULT_OUTPUT = CORPUS_DIR / "combined_corpus.txt"


def read_optional(path: Path) -> str:
    return path.read_text(encoding="utf-8").strip() if path.exists() else ""


def export_dictionary_phrases(conn: sqlite3.Connection) -> list[str]:
    rows = conn.execute(
        "SELECT word FROM words WHERE instr(word, ' ') > 0 ORDER BY freq DESC"
    ).fetchall()
    return [row[0] for row in rows]


def main() -> None:
    parser = argparse.ArgumentParser(description="Build combined QırımKey corpus")
    parser.add_argument("--db", type=Path, default=DB_PATH)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    if not args.db.exists():
        raise SystemExit(f"Dictionary database not found: {args.db}")

    CORPUS_DIR.mkdir(parents=True, exist_ok=True)

    with sqlite3.connect(args.db) as conn:
        phrases = export_dictionary_phrases(conn)

    dictionary_path = CORPUS_DIR / "dictionary_phrases.txt"
    dictionary_path.write_text("\n".join(phrases), encoding="utf-8")

    chunks = [
        read_optional(CORPUS_DIR / "seed_sentences.txt"),
        dictionary_path.read_text(encoding="utf-8"),
        read_optional(CORPUS_DIR / "crh_wikipedia_sample.txt"),
        read_optional(CORPUS_DIR / "nkkcm_export.txt"),
    ]
    combined = "\n\n".join(chunk for chunk in chunks if chunk)

    args.output.write_text(combined, encoding="utf-8")
    print(f"Wrote {args.output} ({len(combined)} chars, {len(phrases)} dictionary phrases)")


if __name__ == "__main__":
    main()
