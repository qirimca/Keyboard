#!/usr/bin/env python3
"""Build unigram, bigram, trigram, and typo_corrections tables for QırımKey from NKKM Lemmatization assets."""

from __future__ import annotations

import argparse
import collections
import csv
import re
import sqlite3
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

DB_PATH = Path(__file__).resolve().parents[1] / "Demo" / "Keyboard" / "qırım_tatar.db"
NKKM_DIR = Path(
    "$HOME/Library/CloudStorage/GoogleDrive-131195550+ebeva@users.noreply.github.com/Shared drives/books/НККМ/Lemmatization"
)

TOKEN_SPLIT_PATTERN = re.compile(r"[^\wğüşıöçñâîûĞÜŞİÖÇÑÂÎÛıİ-]+", re.UNICODE)
VALID_WORD_RE = re.compile(
    r"^[a-zğüşıöçñâîû]+(?:-[a-zğüşıöçñâîû]+)?$", re.UNICODE
)

SEED_TRIGRAMS: dict[tuple[str, str, str], int] = {
    ("bir", "şey", "yoq"): 620,
    ("bir", "şey", "bar"): 540,
    ("bir", "şey", "de"): 480,
    ("bir", "şey", "içün"): 430,
    ("bir", "şey", "edi"): 390,
    ("bir", "şey", "olğan"): 260,
    ("bir", "şey", "yasa"): 220,
    ("bir", "şey", "qıldı"): 200,
    ("men", "de", "öyle"): 180,
    ("o", "da", "öyle"): 170,
    ("ve", "soñra", "bu"): 160,
}

SEED_BIGRAMS: dict[tuple[str, str], int] = {
    ("ve", "soñra"): 160,
}

# Essential reduplicated / paired hyphenated words from grammar.xml (NOUN_DOUBLING) & corpora_lugat_found.csv
SEED_HYPHENATED_WORDS: dict[str, int] = {
    "yavaş-yavaş": 250,
    "tez-tez": 220,
    "sıq-sıq": 190,
    "bir-eki": 175,
    "sağ-selâmet": 140,
    "aman-aman": 135,
    "gece-kündüz": 135,
    "alel-acele": 120,
    "ana-baba": 180,
    "bala-çağa": 165,
    "ağa-qardaş": 160,
    "apte-qardaş": 120,
    "soy-sop": 145,
    "alış-veriş": 150,
    "ara-sıra": 145,
    "çalğı-çağana": 110,
}

# Syncope / middle vowel elision corrections from grammar.xml (MIDDLE_VOWEL_EXCLUSIOON)
SEED_SYNCOPE_CORRECTIONS: dict[str, str] = {
    "ağızı": "ağzı",
    "ağızım": "ağzım",
    "ağızıñ": "ağzıñ",
    "ağızında": "ağzında",
    "ağızından": "ağzından",
    "ağızına": "ağzına",
    "vaqıtı": "vaqtı",
    "vaqıtım": "vaqtım",
    "vaqıtıñ": "vaqtıñ",
    "vaqıtında": "vaqtında",
    "vaqıtından": "vaqtından",
    "vaqıtına": "vaqtına",
    "oğulu": "oğlu",
    "oğlusı": "oğlu",
    "oğulum": "oğlum",
    "oğuluñ": "oğluñ",
    "oğuluna": "oğluna",
    "ömürü": "ömrü",
    "ömürüm": "ömrüm",
    "ömürüñ": "ömrüñ",
    "ömüründe": "ömründe",
    "ilimi": "ilmi",
    "ilimim": "ilmim",
    "ilimiñ": "ilmiñ",
    "şekili": "şekli",
    "şekilinde": "şeklinde",
    "fikiri": "fikri",
    "fikirim": "fikrim",
    "fikiriñ": "fikriñ",
    "fikirince": "fikrince",
    "burunı": "burnu",
    "burunım": "burnum",
    "burunıñ": "burnuñ",
}


def crh_lower(text: str) -> str:
    return (
        text.replace("İ", "i")
        .replace("I", "ı")
        .lower()
        .strip()
    )


def is_clean_token(token: str) -> bool:
    if not token or len(token) > 36:
        return False
    if token.startswith("-") or token.endswith("-"):
        return False
    # Exclude Ukrainian/Cyrillic OCR contamination (і, ї, є, а..я) inside Latin tokens
    return bool(VALID_WORD_RE.match(token))


def tokenize(text: str) -> list[str]:
    parts = [crh_lower(part) for part in TOKEN_SPLIT_PATTERN.split(text)]
    return [part for part in parts if is_clean_token(part)]


def _xml_ns(elem: ET.Element) -> str:
    return elem.tag.split("}")[0] + "}" if "}" in elem.tag else ""


def read_xlsx_rows(xlsx_path: Path) -> list[list[str]]:
    with zipfile.ZipFile(xlsx_path) as zf:
        shared: list[str] = []
        ss_names = [n for n in zf.namelist() if n.lower() == "xl/sharedstrings.xml"]
        if ss_names:
            root = ET.fromstring(zf.read(ss_names[0]))
            ns = _xml_ns(root)
            t_tag = ns + "t"
            shared = [
                "".join(t.text or "" for t in si.iter(t_tag))
                for si in root.findall(ns + "si")
            ]
        sheet_names = [
            name for name in zf.namelist() if name.lower().startswith("xl/worksheets/sheet")
        ]
        if not sheet_names:
            return []
        sheet = ET.fromstring(zf.read(sorted(sheet_names)[0]))
        ns = _xml_ns(sheet)
        row_tag = ns + "row"
        c_tag = ns + "c"
        v_tag = ns + "v"
        t_tag = ns + "t"
        rows: list[list[str]] = []
        for row in sheet.iter(row_tag):
            vals: list[str] = []
            for cell in row.findall(c_tag):
                ctype = cell.attrib.get("t")
                if ctype == "inlineStr":
                    val = "".join(t.text or "" for t in cell.iter(t_tag))
                else:
                    v = cell.find(v_tag)
                    val = v.text if v is not None and v.text is not None else ""
                    if ctype == "s" and val:
                        idx = int(val)
                        if 0 <= idx < len(shared):
                            val = shared[idx]
                vals.append(val or "")
            if vals:
                rows.append(vals)
        return rows


def collect_ngrams_from_phrases(
    phrases: list[tuple[str, int]],
) -> tuple[
    collections.Counter[tuple[str, str]],
    collections.Counter[tuple[str, str, str]],
]:
    bigrams: collections.Counter[tuple[str, str]] = collections.Counter()
    trigrams: collections.Counter[tuple[str, str, str]] = collections.Counter()

    for phrase, freq in phrases:
        parts = [crh_lower(part) for part in phrase.split() if is_clean_token(crh_lower(part))]
        for index in range(len(parts) - 1):
            bigrams[(parts[index], parts[index + 1])] += freq
        for index in range(len(parts) - 2):
            trigrams[(parts[index], parts[index + 1], parts[index + 2])] += freq

    return bigrams, trigrams


def is_local_file(path: Path) -> bool:
    try:
        return path.exists() and path.stat().st_size > 0
    except OSError:
        return False


def ingest_nkkm_xlsx_ngrams(
    nkkm_dir: Path,
    bigrams: collections.Counter[tuple[str, str]],
    trigrams: collections.Counter[tuple[str, str, str]],
    phrases_to_add: collections.Counter[str],
) -> None:
    ngrams_dir = nkkm_dir / "n-grams"
    if not ngrams_dir.exists():
        return

    # 1. 2-grams (2025-03-08)
    for fname in [
        "2grams_user_qirim_crimean_tatar_national_corpora_crimean_tatar_20250308084842.xlsx",
    ]:
        fpath = ngrams_dir / fname
        if is_local_file(fpath):
            try:
                rows = read_xlsx_rows(fpath)
            except (OSError, zipfile.BadZipFile) as exc:
                print(f"Skipping {fname}: {exc}", flush=True)
                continue
            added = 0
            for r in rows[3:]:
                if len(r) < 2:
                    continue
                tokens = [crh_lower(t) for t in r[0].split()]
                if len(tokens) == 2 and all(is_clean_token(t) for t in tokens):
                    try:
                        freq = int(float(r[1]))
                    except ValueError:
                        continue
                    arf = 0
                    if len(r) >= 6:
                        try:
                            arf = int(round(float(r[5])))
                        except ValueError:
                            arf = 0
                    score = max(freq, freq + arf)
                    key = (tokens[0], tokens[1])
                    bigrams[key] = max(bigrams[key], score)
                    added += 1
            print(f"Ingested {added} clean 2-grams from {fname}", flush=True)

    # 2. 3-grams (2025-03-08)
    for fname in [
        "3grams_user_qirim_crimean_tatar_national_corpora_crimean_tatar_20250308085146.xlsx",
    ]:
        fpath = ngrams_dir / fname
        if is_local_file(fpath):
            try:
                rows = read_xlsx_rows(fpath)
            except (OSError, zipfile.BadZipFile) as exc:
                print(f"Skipping {fname}: {exc}", flush=True)
                continue
            added = 0
            for r in rows[3:]:
                if len(r) < 2:
                    continue
                tokens = [crh_lower(t) for t in r[0].split()]
                if len(tokens) == 3 and all(is_clean_token(t) for t in tokens):
                    try:
                        freq = int(float(r[1]))
                    except ValueError:
                        continue
                    key3 = (tokens[0], tokens[1], tokens[2])
                    trigrams[key3] = max(trigrams[key3], freq)
                    bigrams[(tokens[0], tokens[1])] = max(
                        bigrams[(tokens[0], tokens[1])], freq
                    )
                    bigrams[(tokens[1], tokens[2])] = max(
                        bigrams[(tokens[1], tokens[2])], freq
                    )
                    added += 1
            print(f"Ingested {added} clean 3-grams from {fname}", flush=True)


def ingest_crh_vert(
    nkkm_dir: Path,
    unigram_boosts: collections.Counter[str],
    bigrams: collections.Counter[tuple[str, str]],
    trigrams: collections.Counter[tuple[str, str, str]],
) -> None:
    vert_path = nkkm_dir / "Language Tools" / "vertical" / "crh.vert"
    if not is_local_file(vert_path):
        return
    vert_bigrams: collections.Counter[tuple[str, str]] = collections.Counter()
    vert_trigrams: collections.Counter[tuple[str, str, str]] = collections.Counter()
    sent_tokens: list[str] = []
    sentences = 0

    for line in vert_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        s = line.strip()
        if not s:
            continue
        if s.startswith("<"):
            if s.startswith("</s>") and sent_tokens:
                sentences += 1
                for i in range(len(sent_tokens) - 1):
                    vert_bigrams[(sent_tokens[i], sent_tokens[i + 1])] += 1
                for i in range(len(sent_tokens) - 2):
                    vert_trigrams[
                        (sent_tokens[i], sent_tokens[i + 1], sent_tokens[i + 2])
                    ] += 1
                sent_tokens.clear()
            continue
        tok = crh_lower(s.split("\t")[0])
        if is_clean_token(tok):
            unigram_boosts[tok] += 1
            sent_tokens.append(tok)
        else:
            if len(sent_tokens) >= 2:
                for i in range(len(sent_tokens) - 1):
                    vert_bigrams[(sent_tokens[i], sent_tokens[i + 1])] += 1
                for i in range(len(sent_tokens) - 2):
                    vert_trigrams[
                        (sent_tokens[i], sent_tokens[i + 1], sent_tokens[i + 2])
                    ] += 1
            sent_tokens.clear()

    kept_bi = 0
    for k, v in vert_bigrams.items():
        if v >= 2:
            bigrams[k] = max(bigrams[k], v * 2)
            kept_bi += 1
    kept_tri = 0
    for k, v in vert_trigrams.items():
        if v >= 2:
            trigrams[k] = max(trigrams[k], v * 2)
            kept_tri += 1
    print(
        f"Ingested crh.vert ({sentences} sentences): {kept_bi} bigrams (freq>=2), {kept_tri} trigrams (freq>=2)",
        flush=True,
    )


def ingest_corpora_lugat(
    nkkm_dir: Path,
    unigram_boosts: collections.Counter[str],
) -> None:
    found_csv = nkkm_dir / "corpora_lugat_found.csv"
    if is_local_file(found_csv):
        count = 0
        with found_csv.open(encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f, delimiter="\t")
            next(reader, None)
            for row in reader:
                if len(row) >= 4:
                    w = crh_lower(row[1])
                    if is_clean_token(w):
                        try:
                            freq = int(row[3])
                        except ValueError:
                            continue
                        if freq > unigram_boosts[w]:
                            unigram_boosts[w] = freq
                            count += 1
        print(f"Ingested {count} verified wordforms from corpora_lugat_found.csv", flush=True)


def ingest_lat_diff(
    nkkm_dir: Path,
) -> dict[str, str]:
    corrections = dict(SEED_SYNCOPE_CORRECTIONS)
    lat_diff_path = nkkm_dir / "Language Tools" / "lemma enhancement" / "lat_diff.csv"
    if is_local_file(lat_diff_path):
        with lat_diff_path.open(encoding="utf-8", errors="ignore") as f:
            reader = csv.reader(f)
            next(reader, None)
            for row in reader:
                if len(row) >= 2 and "," in row[1]:
                    std_raw, alt_raw = row[1].split(",", 1)
                    std = crh_lower(std_raw)
                    alt = crh_lower(alt_raw)
                    if std and alt and std != alt and " " not in alt and " " not in std:
                        corrections[alt] = std
        print(f"Ingested {len(corrections)} orthographic corrections from lat_diff.csv & grammar.xml", flush=True)
    return corrections


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


def update_words_and_typos(
    conn: sqlite3.Connection,
    unigram_boosts: collections.Counter[str],
    phrases_to_add: collections.Counter[str],
    typo_corrections: dict[str, str],
) -> None:
    cursor = conn.cursor()
    ocr_contaminants = set("іїєґІЇЄҐ")
    existing: dict[str, int] = {}
    for w_raw, f_raw in cursor.execute("SELECT word, freq FROM words"):
        if not w_raw:
            continue
        w = crh_lower(w_raw)
        if (
            "." in w
            or "oırım" in w
            or any(ch in ocr_contaminants or ("\u0400" <= ch <= "\u04ff") for ch in w)
        ):
            continue
        freq = int(f_raw or 0)
        if freq > existing.get(w, -1):
            existing[w] = freq

    added_words = 0
    updated_words = 0

    for w, freq in SEED_HYPHENATED_WORDS.items():
        unigram_boosts[w] = max(unigram_boosts[w], freq)

    for w, boost in unigram_boosts.items():
        if w not in existing:
            if boost >= 2 or "-" in w:
                existing[w] = boost
                added_words += 1
        else:
            if boost > existing[w]:
                existing[w] = boost
                updated_words += 1

    for phrase, freq in phrases_to_add.items():
        if phrase not in existing:
            existing[phrase] = freq
            added_words += 1

    cursor.execute("DROP TABLE IF EXISTS words")
    cursor.execute('CREATE TABLE "words" ("word" TEXT, "freq" INTEGER)')
    cursor.executemany(
        "INSERT INTO words(word, freq) VALUES (?, ?)",
        list(existing.items()),
    )
    cursor.execute("CREATE INDEX idx_words_word_freq ON words(word, freq DESC)")
    cursor.execute("CREATE INDEX idx_words_freq ON words(freq DESC)")

    cursor.execute("DROP TABLE IF EXISTS typo_corrections")
    cursor.execute(
        """
        CREATE TABLE typo_corrections (
            typo TEXT PRIMARY KEY,
            correction TEXT NOT NULL
        )
        """
    )
    cursor.executemany(
        "INSERT OR REPLACE INTO typo_corrections(typo, correction) VALUES (?, ?)",
        list(typo_corrections.items()),
    )
    print(
        f"Updated words table (+{added_words} new words, {updated_words} freq updates, {len(existing)} total) and {len(typo_corrections)} typo_corrections",
        flush=True,
    )


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
    cursor.execute("CREATE INDEX idx_bigrams_word1 ON bigrams(word1, freq DESC)")
    items = [
        (left, right, freq)
        for (left, right), freq in bigrams.items()
        if left != right or "-" in left
    ]
    cursor.executemany(
        "INSERT INTO bigrams(word1, word2, freq) VALUES (?, ?, ?)",
        items,
    )
    return len(items)


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
    cursor.execute("CREATE INDEX idx_trigrams_context ON trigrams(word1, word2, freq DESC)")
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
    nkkm_dir: Path,
) -> tuple[int, int]:
    cursor = conn.cursor()
    phrases = cursor.execute(
        "SELECT word, freq FROM words WHERE instr(word, ' ') > 0"
    ).fetchall()

    bigrams, trigrams = collect_ngrams_from_phrases(phrases)
    unigram_boosts: collections.Counter[str] = collections.Counter()
    phrases_to_add: collections.Counter[str] = collections.Counter()

    if nkkm_dir.exists():
        ingest_nkkm_xlsx_ngrams(nkkm_dir, bigrams, trigrams, phrases_to_add)
        ingest_crh_vert(nkkm_dir, unigram_boosts, bigrams, trigrams)
        ingest_corpora_lugat(nkkm_dir, unigram_boosts)
        typo_corrections = ingest_lat_diff(nkkm_dir)
    else:
        typo_corrections = dict(SEED_SYNCOPE_CORRECTIONS)

    for key, freq in SEED_BIGRAMS.items():
        bigrams[key] = max(bigrams.get(key, 0), freq)
    for key, freq in SEED_TRIGRAMS.items():
        trigrams[key] = max(trigrams.get(key, 0), freq)

    for corpus_path in corpus_paths:
        lines = ingest_corpus_file(corpus_path, bigrams, trigrams)
        print(f"Ingested {lines} lines from {corpus_path}")

    update_words_and_typos(conn, unigram_boosts, phrases_to_add, typo_corrections)
    bigram_count = write_bigrams(conn, bigrams)
    trigram_count = write_trigrams(conn, trigrams)
    conn.commit()
    cursor.execute("VACUUM")
    return bigram_count, trigram_count


def main() -> None:
    import os
    try:
        os.nice(15)
    except OSError:
        pass
    parser = argparse.ArgumentParser(description="Build QırımKey n-gram tables")
    parser.add_argument(
        "--db",
        type=Path,
        default=DB_PATH,
        help="Path to qırım_tatar.db",
    )
    parser.add_argument(
        "--nkkm",
        type=Path,
        default=NKKM_DIR,
        help="Path to NKKM/Lemmatization directory",
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
        bigram_count, trigram_count = build_ngrams(conn, args.corpus, args.nkkm)

    print(f"Built {bigram_count} bigrams and {trigram_count} trigrams in {args.db}", flush=True)


if __name__ == "__main__":
    main()
