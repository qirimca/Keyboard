#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_PATH="$SCRIPT_DIR/../Demo/Keyboard/qırım_tatar.db"
CORPUS_DIR="$SCRIPT_DIR/corpus"
COMBINED_CORPUS="$CORPUS_DIR/combined_corpus.txt"

needs_rebuild() {
    if [[ ! -f "$DB_PATH" ]]; then
        return 0
    fi

    local marker
    for marker in \
        "$SCRIPT_DIR/build_corpus.py" \
        "$SCRIPT_DIR/build_ngrams.py" \
        "$CORPUS_DIR/seed_sentences.txt" \
        "$CORPUS_DIR/nkkcm_export.txt" \
        "$CORPUS_DIR/crh_wikipedia_sample.txt" \
        "$COMBINED_CORPUS"
    do
        if [[ -f "$marker" && "$marker" -nt "$DB_PATH" ]]; then
            return 0
        fi
    done

    return 1
}

if ! needs_rebuild; then
    echo "note: qırım_tatar.db is up to date"
    exit 0
fi

python3 "$SCRIPT_DIR/build_corpus.py"
python3 "$SCRIPT_DIR/build_ngrams.py" --corpus "$COMBINED_CORPUS"
echo "note: rebuilt prediction tables in qırım_tatar.db"
