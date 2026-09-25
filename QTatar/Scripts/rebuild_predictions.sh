#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

python3 "$ROOT/build_corpus.py"
python3 "$ROOT/build_ngrams.py" --corpus "$ROOT/corpus/combined_corpus.txt"

echo "Prediction tables rebuilt in Demo/Keyboard/qırım_tatar.db"
