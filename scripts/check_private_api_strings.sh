#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-QTatar}"
PATTERN='UIKeyboardImpl|UIPeripheralHost|TIPreferencesController|UIKeyboardPreferencesController|keyboardScreenReferenceBounds'

matches="$(
  grep -RInE \
    --exclude-dir=.git \
    --exclude-dir=.build \
    --exclude-dir=ШІ \
    --exclude='*.md' \
    --exclude='*.json' \
    --exclude='check_private_api_strings.sh' \
    "$PATTERN" "$ROOT" || true
)"

if [[ -n "$matches" ]]; then
  echo "ERROR: private Apple API identifiers found:"
  echo "$matches"
  exit 1
fi

echo "OK: no prohibited private API identifiers found in $ROOT."
